#!/bin/bash

# Performance Analysis Script for Claude Code Auto Workflows
# This script analyzes workflow performance and provides optimization suggestions

set -euo pipefail

# Source common library
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib/common.sh"

# Cache configuration
CACHE_DIR="${TMPDIR:-/tmp}/analyze-performance-cache"
CACHE_TTL=300  # 5 minutes cache TTL

# Override log_header for this script's specific purpose
log_header() {
    echo -e "${BLUE}[ANALYSIS]${NC} $*"
}

cached_gh_api_call() {
    local endpoint="$1"
    local cache_key
    cache_key=$(get_cache_key "$endpoint")
    
    if get_from_cache "$cache_key" "$CACHE_DIR" "$CACHE_TTL"; then
        return 0
    fi
    
    local result
    if result=$(gh api "$endpoint" 2>/dev/null); then
        save_to_cache "$cache_key" "$result" "$CACHE_DIR"
        echo "$result"
        return 0
    fi
    return 1
}

cached_gh_run_list() {
    local args="$*"
    local cache_key
    cache_key=$(get_cache_key "run_list_$args")
    
    if get_from_cache "$cache_key" "$CACHE_DIR" "$CACHE_TTL"; then
        return 0
    fi
    
    local result
    if result=$(gh run list $args 2>/dev/null); then
        save_to_cache "$cache_key" "$result" "$CACHE_DIR"
        echo "$result"
        return 0
    fi
    return 1
}


analyze_workflow_runtime() {
    log_header "Analyzing workflow runtime performance..."
    
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) is required for performance analysis"
        return 1
    fi
    
    # Get recent workflow runs with timing data (with caching)
    local runs_data
    runs_data=$(cached_gh_run_list "--limit 50 --json name,status,conclusion,createdAt,updatedAt,databaseId" || echo "[]")
    
    if [[ "$runs_data" == "[]" ]]; then
        log_warn "No workflow run data available"
        return 0
    fi
    
    # Calculate average runtime by workflow
    log_info "Recent workflow performance (last 50 runs):"
    echo "$runs_data" | jq -r '
        group_by(.name) | 
        map({
            name: .[0].name,
            count: length,
            avg_duration: (
                map(
                    if .updatedAt and .createdAt then
                        (((.updatedAt | fromdateiso8601) - (.createdAt | fromdateiso8601)) / 60) | floor
                    else 0 end
                ) | add / length
            ),
            success_rate: (
                map(select(.conclusion == "success")) | length
            ) * 100 / length
        }) | 
        sort_by(.avg_duration) | 
        reverse |
        .[] | 
        "  📊 \(.name): \(.avg_duration)min avg, \(.success_rate | floor)% success rate (\(.count) runs)"
    '
}

analyze_api_usage() {
    log_header "Analyzing GitHub API usage..."
    
    if ! gh api rate_limit &>/dev/null; then
        log_error "Cannot access GitHub API rate limit information"
        return 1
    fi
    
    local rate_limit_info
    rate_limit_info=$(cached_gh_api_call "rate_limit")
    
    local core_used core_limit core_remaining
    core_used=$(echo "$rate_limit_info" | jq -r '.rate.used')
    core_limit=$(echo "$rate_limit_info" | jq -r '.rate.limit')
    core_remaining=$(echo "$rate_limit_info" | jq -r '.rate.remaining')
    
    local usage_percent
    usage_percent=$((core_used * 100 / core_limit))
    
    log_info "GitHub API Usage:"
    log_info "  📈 Core API: $core_used/$core_limit used ($usage_percent%)"
    log_info "  🔄 Remaining: $core_remaining requests until reset"
    
    if [[ $usage_percent -gt 80 ]]; then
        log_warn "⚠️  High API usage detected ($usage_percent%) - consider optimizing workflows"
        suggest_api_optimizations
    elif [[ $usage_percent -gt 60 ]]; then
        log_warn "⚠️  Moderate API usage ($usage_percent%) - monitor closely"
    else
        log_info "✅ API usage is within healthy limits"
    fi
}

suggest_api_optimizations() {
    log_info "💡 API Optimization Suggestions:"
    log_info "   • Use GitHub App tokens for higher rate limits"
    log_info "   • Implement caching for repeated API calls"
    log_info "   • Batch API operations where possible"
    log_info "   • Consider reducing workflow trigger frequency"
}

analyze_workflow_efficiency() {
    log_header "Analyzing workflow efficiency..."
    
    local workflow_dir=".github/workflows"
    if [[ ! -d "$workflow_dir" ]]; then
        log_warn "No workflow directory found"
        return 0
    fi
    
    local workflow_count
    workflow_count=$(find "$workflow_dir" -name "*.yml" -o -name "*.yaml" | wc -l)
    
    log_info "Workflow Configuration Analysis:"
    log_info "  📁 Total workflows: $workflow_count"
    
    # Check for potential optimizations
    local caching_workflows=0
    local conditional_workflows=0
    local matrix_workflows=0
    
    while IFS= read -r -d '' file; do
        if grep -q "cache:" "$file" || grep -q "actions/cache" "$file"; then
            ((caching_workflows++))
        fi
        
        if grep -q "if:" "$file"; then
            ((conditional_workflows++))
        fi
        
        if grep -q "strategy:" "$file" && grep -q "matrix:" "$file"; then
            ((matrix_workflows++))
        fi
    done < <(find "$workflow_dir" -name "*.yml" -o -name "*.yaml" -print0)
    
    log_info "  🚀 Using caching: $caching_workflows/$workflow_count workflows"
    log_info "  🎯 Using conditionals: $conditional_workflows/$workflow_count workflows"
    log_info "  ⚡ Using matrix builds: $matrix_workflows/$workflow_count workflows"
    
    if [[ $caching_workflows -lt $((workflow_count / 2)) ]]; then
        log_warn "⚠️  Consider adding caching to more workflows for better performance"
    fi
}

generate_performance_report() {
    log_header "Generating performance recommendations..."
    
    log_info "💡 Performance Optimization Recommendations:"
    log_info "   1. 🚀 Enable dependency caching in workflows that install packages"
    log_info "   2. 🎯 Use conditional job execution to skip unnecessary work"
    log_info "   3. ⚡ Implement matrix strategies for parallel execution"
    log_info "   4. 📦 Use smaller, specific action versions instead of @latest"
    log_info "   5. 🔄 Consider workflow_dispatch for manual triggers to reduce automatic runs"
    log_info "   6. 📊 Monitor and clean up old workflow runs regularly"
    log_info "   7. 🏷️  Use labels efficiently to control workflow triggers"
}

main() {
    log_info "📊 Starting performance analysis for Claude Code Auto Workflows..."
    
    # Initialize cache and cleanup old entries
    setup_cache "$CACHE_DIR"
    cleanup_cache "$CACHE_DIR" "$CACHE_TTL"
    show_cache_stats "$CACHE_DIR" "data"
    
    echo
    
    analyze_workflow_runtime
    echo
    
    analyze_api_usage
    echo
    
    analyze_workflow_efficiency
    echo
    
    generate_performance_report
    echo
    
    log_info "🎉 Performance analysis completed!"
    log_info "   Use the recommendations above to optimize your workflow performance."
}

main "$@"