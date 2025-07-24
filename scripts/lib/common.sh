#!/bin/bash

# Common functions for Claude Code Auto Workflows scripts
# This library provides shared functionality to reduce code duplication

# Configuration loading
load_config() {
    local config_file="${1:-}"
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    local default_config="$script_dir/config/default.conf"
    
    # Load default configuration first
    if [[ -f "$default_config" ]]; then
        source "$default_config"
    fi
    
    # Load custom config if specified
    if [[ -n "$config_file" && -f "$config_file" ]]; then
        source "$config_file"
    fi
    
    # Validate required configuration
    validate_config
}

validate_config() {
    # Validate numeric values
    if [[ ! "$MAX_PARALLEL_JOBS" =~ ^[0-9]+$ ]] || [[ "$MAX_PARALLEL_JOBS" -lt 1 ]]; then
        log_error "Invalid MAX_PARALLEL_JOBS value: $MAX_PARALLEL_JOBS"
        return 1
    fi
    
    if [[ ! "$CACHE_TTL" =~ ^[0-9]+$ ]] || [[ "$CACHE_TTL" -lt 60 ]]; then
        log_error "Invalid CACHE_TTL value: $CACHE_TTL (minimum 60 seconds)"
        return 1
    fi
    
    # Validate boolean values
    case "$ENABLE_CACHE" in
        true|false) ;;
        *) log_error "Invalid ENABLE_CACHE value: $ENABLE_CACHE (must be true or false)"; return 1 ;;
    esac
}

# Signal handling for graceful shutdown
CLEANUP_FUNCTIONS=()
INTERRUPTED=false

add_cleanup_function() {
    CLEANUP_FUNCTIONS+=("$1")
}

cleanup_and_exit() {
    local exit_code=${1:-130}
    INTERRUPTED=true
    
    log_warn "Received interrupt signal, cleaning up..."
    
    # Run cleanup functions in reverse order
    for ((i=${#CLEANUP_FUNCTIONS[@]}-1; i>=0; i--)); do
        local cleanup_func="${CLEANUP_FUNCTIONS[i]}"
        if declare -F "$cleanup_func" > /dev/null; then
            log_info "Running cleanup: $cleanup_func"
            "$cleanup_func" || log_warn "Cleanup function $cleanup_func failed"
        fi
    done
    
    log_info "Cleanup completed, exiting..."
    exit $exit_code
}

setup_signal_handling() {
    trap 'cleanup_and_exit 130' SIGINT
    trap 'cleanup_and_exit 143' SIGTERM
}

# Improved cache key generation with full file paths and content checksums
get_enhanced_cache_key() {
    local file="$1"
    local additional_context="${2:-}"
    
    # Get absolute path to avoid collisions with same filenames in different directories
    local abs_path
    abs_path=$(realpath "$file" 2>/dev/null || echo "$file")
    
    # Get file content hash
    local content_hash
    content_hash=$(sha256sum "$file" 2>/dev/null | cut -d' ' -f1)
    
    # Get file modification time
    local mtime
    mtime=$(stat -c %Y "$file" 2>/dev/null || echo 0)
    
    # Combine path, content, modification time, and additional context
    local combined="${abs_path}:${content_hash}:${mtime}:${additional_context}"
    echo -n "$combined" | sha256sum | cut -d' ' -f1
}

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

# Simplified parallel processing using xargs -P
run_parallel_function() {
    local function_name="$1"
    local max_jobs="${2:-$XARGS_PARALLEL_JOBS}"
    local input_files=("${@:3}")
    
    # Check if function exists
    if ! declare -F "$function_name" > /dev/null; then
        log_error "Function $function_name not found"
        return 1
    fi
    
    # Export the function so it's available to subshells
    export -f "$function_name"
    export -f log_info log_warn log_error log_header
    export RED YELLOW GREEN BLUE NC
    
    # Use printf to handle filenames with spaces properly
    printf '%s\0' "${input_files[@]}" | xargs -0 -P "$max_jobs" -I {} bash -c "$function_name \"\$1\"" _ {}
}

# Alternative parallel processing for when function export isn't suitable
run_parallel_command() {
    local command_template="$1"
    local max_jobs="${2:-$XARGS_PARALLEL_JOBS}"
    local input_files=("${@:3}")
    
    # Use printf to handle filenames with spaces properly
    printf '%s\0' "${input_files[@]}" | xargs -0 -P "$max_jobs" -I {} bash -c "$command_template" _ {}
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