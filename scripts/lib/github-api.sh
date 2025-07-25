#!/bin/bash

# GitHub API interaction module for Claude Code Auto Workflows
# This module provides centralized GitHub API functionality with caching and rate limiting

# Source common utilities
github_api_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$github_api_script_dir/common.sh"

# GitHub API configuration
GITHUB_API_CACHE_DIR="${TMPDIR:-/tmp}/github-api-cache"
GITHUB_API_CACHE_TTL=300  # 5 minutes cache TTL
GITHUB_API_RATE_LIMIT_BUFFER=100  # Keep 100 requests as buffer

# Performance metrics for API calls
API_CALL_COUNT=0
API_CACHE_HITS=0
API_RATE_LIMIT_WARNINGS=0

# Initialize GitHub API module
github_api_init() {
    setup_cache "$GITHUB_API_CACHE_DIR"
    cleanup_cache "$GITHUB_API_CACHE_DIR" "$GITHUB_API_CACHE_TTL"
    
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) is required for API operations"
        return 1
    fi
    
    # Verify authentication
    if ! gh auth status &>/dev/null; then
        log_error "GitHub CLI authentication required. Run 'gh auth login'"
        return 1
    fi
    
    log_info "GitHub API module initialized with caching enabled"
}

# Make cached GitHub API call with rate limiting
github_api_call() {
    local endpoint="$1"
    local cache_key
    cache_key=$(get_cache_key "api_$endpoint")
    
    ((API_CALL_COUNT++))
    
    # Try to get from cache first
    if get_from_cache "$cache_key" "$GITHUB_API_CACHE_DIR" "$GITHUB_API_CACHE_TTL"; then
        ((API_CACHE_HITS++))
        return 0
    fi
    
    # Check rate limiting before making API call
    if ! _check_rate_limit; then
        log_error "GitHub API rate limit exceeded or approaching limit"
        return 1
    fi
    
    local result
    if result=$(gh api "$endpoint" 2>/dev/null); then
        save_to_cache "$cache_key" "$result" "$GITHUB_API_CACHE_DIR"
        echo "$result"
        return 0
    else
        log_error "Failed to call GitHub API endpoint: $endpoint"
        return 1
    fi
}

# Make cached GitHub CLI run command
github_run_list() {
    local args="$*"
    local cache_key
    cache_key=$(get_cache_key "run_list_$args")
    
    ((API_CALL_COUNT++))
    
    # Try to get from cache first
    if get_from_cache "$cache_key" "$GITHUB_API_CACHE_DIR" "$GITHUB_API_CACHE_TTL"; then
        ((API_CACHE_HITS++))
        return 0
    fi
    
    # Check rate limiting
    if ! _check_rate_limit; then
        log_error "GitHub API rate limit exceeded"
        return 1
    fi
    
    local result
    if result=$(gh run list $args 2>/dev/null); then
        save_to_cache "$cache_key" "$result" "$GITHUB_API_CACHE_DIR"
        echo "$result"
        return 0
    else
        log_error "Failed to list GitHub workflow runs"
        return 1
    fi
}

# Get GitHub API rate limit information
github_get_rate_limit() {
    github_api_call "rate_limit"
}

# Check if we're approaching rate limit
_check_rate_limit() {
    local rate_limit_info
    if ! rate_limit_info=$(github_api_call "rate_limit"); then
        return 1
    fi
    
    local remaining
    remaining=$(echo "$rate_limit_info" | jq -r '.rate.remaining // 0')
    
    if [[ $remaining -lt $GITHUB_API_RATE_LIMIT_BUFFER ]]; then
        ((API_RATE_LIMIT_WARNINGS++))
        log_warn "GitHub API rate limit approaching: $remaining requests remaining"
        
        if [[ $remaining -lt 10 ]]; then
            local reset_time
            reset_time=$(echo "$rate_limit_info" | jq -r '.rate.reset // 0')
            local current_time
            current_time=$(date +%s)
            local wait_time=$((reset_time - current_time))
            
            if [[ $wait_time -gt 0 && $wait_time -lt 3600 ]]; then
                log_warn "Rate limit almost exhausted. Waiting ${wait_time}s for reset..."
                sleep "$wait_time"
            else
                return 1
            fi
        fi
    fi
    
    return 0
}

# Get API performance metrics
github_api_get_metrics() {
    local cache_hit_rate=0
    if [[ $API_CALL_COUNT -gt 0 ]]; then
        cache_hit_rate=$((API_CACHE_HITS * 100 / API_CALL_COUNT))
    fi
    
    cat << EOF
{
  "api_calls_total": $API_CALL_COUNT,
  "cache_hits": $API_CACHE_HITS,
  "cache_hit_rate_percent": $cache_hit_rate,
  "rate_limit_warnings": $API_RATE_LIMIT_WARNINGS
}
EOF
}

# Clean up GitHub API module
github_api_cleanup() {
    cleanup_cache "$GITHUB_API_CACHE_DIR" 0  # Clean all cache entries
    log_info "GitHub API module cleanup completed"
}

# Reset performance metrics
github_api_reset_metrics() {
    API_CALL_COUNT=0
    API_CACHE_HITS=0
    API_RATE_LIMIT_WARNINGS=0
}

# Display API usage statistics
github_api_show_stats() {
    local stats
    stats=$(github_api_get_metrics)
    
    local total_calls cache_hits hit_rate warnings
    total_calls=$(echo "$stats" | jq -r '.api_calls_total')
    cache_hits=$(echo "$stats" | jq -r '.cache_hits')
    hit_rate=$(echo "$stats" | jq -r '.cache_hit_rate_percent')
    warnings=$(echo "$stats" | jq -r '.rate_limit_warnings')
    
    log_info "📊 GitHub API Statistics:"
    log_info "  🔌 Total API calls: $total_calls"
    log_info "  💾 Cache hits: $cache_hits ($hit_rate%)"
    log_info "  ⚠️  Rate limit warnings: $warnings"
    
    show_cache_stats "$GITHUB_API_CACHE_DIR" "GitHub API responses"
}