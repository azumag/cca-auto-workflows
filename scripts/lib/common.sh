#!/bin/bash

# Common functions for Claude Code Auto Workflows scripts
# This library provides shared functionality to reduce code duplication

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_header() {
    echo -e "${BLUE}[HEADER]${NC} $*"
}

# Cache management functions
setup_cache() {
    local cache_dir="$1"
    if [[ -z "$cache_dir" ]]; then
        log_error "Cache directory not specified"
        return 1
    fi
    
    # Create cache directory with secure permissions
    mkdir -p "$cache_dir"
    chmod 700 "$cache_dir"
}

get_cache_key() {
    local input="$1"
    echo -n "$input" | sha256sum | cut -d' ' -f1
}

is_cache_valid() {
    local cache_file="$1"
    local cache_ttl="$2"
    
    if [[ ! -f "$cache_file" ]]; then
        return 1
    fi
    
    local cache_time
    cache_time=$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)
    local current_time
    current_time=$(date +%s)
    
    [[ $((current_time - cache_time)) -lt $cache_ttl ]]
}

get_from_cache() {
    local cache_key="$1"
    local cache_dir="$2"
    local cache_ttl="$3"
    local cache_file="$cache_dir/$cache_key"
    
    if is_cache_valid "$cache_file" "$cache_ttl"; then
        cat "$cache_file"
        return 0
    fi
    return 1
}

# Atomic cache save to prevent race conditions
save_to_cache() {
    local cache_key="$1"
    local data="$2"
    local cache_dir="$3"
    local cache_file="$cache_dir/$cache_key"
    local temp_file="${cache_file}.tmp.$$"
    
    # Write to temporary file first, then atomically move
    echo "$data" > "$temp_file" && mv "$temp_file" "$cache_file"
    
    # Clean up temp file if move failed
    rm -f "$temp_file" 2>/dev/null || true
}

cleanup_cache() {
    local cache_dir="$1"
    local cache_ttl="$2"
    
    if [[ -d "$cache_dir" ]]; then
        find "$cache_dir" -type f -mmin +$((cache_ttl / 60)) -delete 2>/dev/null || true
    fi
}

show_cache_stats() {
    local cache_dir="$1"
    local label="$2"
    
    if [[ -d "$cache_dir" ]]; then
        local cache_files
        cache_files=$(find "$cache_dir" -type f 2>/dev/null | wc -l)
        if [[ $cache_files -gt 0 ]]; then
            log_info "💾 Using cached ${label:-data} ($cache_files cached entries)"
        fi
    fi
}

# Error handling utilities
check_command() {
    local cmd="$1"
    local error_msg="$2"
    
    if ! command -v "$cmd" &> /dev/null; then
        log_error "${error_msg:-Command '$cmd' is required but not found}"
        return 1
    fi
}

# Wait for background processes with error handling
wait_for_jobs() {
    local pids=("$@")
    local failed_count=0
    
    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            log_error "Background job failed (PID: $pid)"
            ((failed_count++))
        fi
    done
    
    return $failed_count
}

# Progress display
show_progress() {
    local current=$1
    local total=$2
    local operation=$3
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\r${BLUE}[PROGRESS]${NC} %s: [" "$operation"
    printf "%*s" $filled | tr ' ' '█'
    printf "%*s" $empty | tr ' ' '░'
    printf "] %d/%d (%d%%)" "$current" "$total" "$percent"
    
    if [[ $current -eq $total ]]; then
        echo
    fi
}