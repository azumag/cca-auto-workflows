#!/bin/bash

# Common functions for Claude Code Auto Workflows scripts
# This library provides shared functionality to reduce code duplication

# Constants
readonly SHA256_HASH_LENGTH=64
readonly DEFAULT_MEMORY_PER_JOB_MB=100

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
    
    # Validate resource monitoring configuration
    if [[ ! "$MEMORY_LIMIT_PERCENT" =~ ^[0-9]+$ ]] || [[ "$MEMORY_LIMIT_PERCENT" -lt 1 ]] || [[ "$MEMORY_LIMIT_PERCENT" -gt 100 ]]; then
        log_error "Invalid MEMORY_LIMIT_PERCENT value: $MEMORY_LIMIT_PERCENT (must be 1-100)"
        return 1
    fi
    
    if [[ ! "$CPU_LIMIT_PERCENT" =~ ^[0-9]+$ ]] || [[ "$CPU_LIMIT_PERCENT" -lt 1 ]] || [[ "$CPU_LIMIT_PERCENT" -gt 100 ]]; then
        log_error "Invalid CPU_LIMIT_PERCENT value: $CPU_LIMIT_PERCENT (must be 1-100)"
        return 1
    fi
    
    if [[ ! "$MIN_PARALLEL_JOBS" =~ ^[0-9]+$ ]] || [[ "$MIN_PARALLEL_JOBS" -lt 1 ]]; then
        log_error "Invalid MIN_PARALLEL_JOBS value: $MIN_PARALLEL_JOBS (must be >= 1)"
        return 1
    fi
    
    if [[ ! "$MAX_SYSTEM_PARALLEL_JOBS" =~ ^[0-9]+$ ]] || [[ "$MAX_SYSTEM_PARALLEL_JOBS" -lt 1 ]]; then
        log_error "Invalid MAX_SYSTEM_PARALLEL_JOBS value: $MAX_SYSTEM_PARALLEL_JOBS (must be >= 1)"
        return 1
    fi
    
    if [[ ! "$RESOURCE_CHECK_INTERVAL" =~ ^[0-9]+$ ]] || [[ "$RESOURCE_CHECK_INTERVAL" -lt 1 ]]; then
        log_error "Invalid RESOURCE_CHECK_INTERVAL value: $RESOURCE_CHECK_INTERVAL (must be >= 1)"
        return 1
    fi
    
    if [[ ! "$PARALLEL_JOB_TIMEOUT" =~ ^[0-9]+$ ]] || [[ "$PARALLEL_JOB_TIMEOUT" -lt 1 ]]; then
        log_error "Invalid PARALLEL_JOB_TIMEOUT value: $PARALLEL_JOB_TIMEOUT (must be >= 1)"
        return 1
    fi
    
    # Validate boolean values
    case "$ENABLE_CACHE" in
        true|false) ;;
        *) log_error "Invalid ENABLE_CACHE value: $ENABLE_CACHE (must be true or false)"; return 1 ;;
    esac
    
    case "$RESOURCE_MONITOR_ENABLED" in
        true|false) ;;
        *) log_error "Invalid RESOURCE_MONITOR_ENABLED value: $RESOURCE_MONITOR_ENABLED (must be true or false)"; return 1 ;;
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
    exit "$exit_code"
}

setup_signal_handling() {
    trap 'cleanup_and_exit 130' SIGINT
    trap 'cleanup_and_exit 143' SIGTERM
}

# Improved cache key generation with full file paths and content checksums
get_enhanced_cache_key() {
    local file="$1"
    local additional_context="${2:-}"
    
    # Input validation to prevent path traversal
    if [[ -z "$file" ]]; then
        log_error "get_enhanced_cache_key: file parameter is required"
        return 1
    fi
    
    # Validate file path doesn't contain dangerous sequences
    if [[ "$file" =~ \.\./|/\.\. ]]; then
        log_error "get_enhanced_cache_key: path traversal detected in file: $file"
        return 1
    fi
    
    # Get absolute path to avoid collisions with same filenames in different directories
    local abs_path
    abs_path=$(realpath "$file" 2>/dev/null || echo "$file")
    
    # Get file content hash and modification time in one operation
    local file_info
    if [[ -f "$file" ]]; then
        local content_hash mtime
        content_hash=$(sha256sum "$file" 2>/dev/null | cut -d' ' -f1)
        mtime=$(stat -c %Y "$file" 2>/dev/null || echo 0)
        file_info="${abs_path}:${content_hash}:${mtime}:${additional_context}"
    else
        file_info="${abs_path}:missing:0:${additional_context}"
    fi
    
    # Single hash operation instead of double hashing
    echo -n "$file_info" | sha256sum | cut -d' ' -f1
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
    local cache_perms="${2:-700}"
    
    if [[ -z "$cache_dir" ]]; then
        log_error "Cache directory not specified"
        return 1
    fi
    
    # Validate cache directory path
    if [[ "$cache_dir" =~ \.\./|/\.\. ]]; then
        log_error "Path traversal detected in cache directory: $cache_dir"
        return 1
    fi
    
    # Create cache directory with configurable permissions
    mkdir -p "$cache_dir"
    chmod "$cache_perms" "$cache_dir"
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
    
    # Input validation
    if [[ -z "$cache_key" || -z "$cache_dir" ]]; then
        log_error "save_to_cache: cache_key and cache_dir are required"
        return 1
    fi
    
    # Validate cache key doesn't contain path traversal
    if [[ "$cache_key" =~ \.\./|/\.\.|/ ]]; then
        log_error "save_to_cache: invalid cache key: $cache_key"
        return 1
    fi
    
    local cache_file="$cache_dir/$cache_key"
    local temp_file
    
    # Use mktemp for secure temporary file creation
    temp_file=$(mktemp "${cache_file}.tmp.XXXXXX" 2>/dev/null) || {
        log_error "save_to_cache: failed to create temporary file for $cache_file"
        return 1
    }
    
    # Write to temporary file first, then atomically move
    if echo "$data" > "$temp_file" && mv "$temp_file" "$cache_file"; then
        return 0
    else
        # Clean up temp file if operation failed
        rm -f "$temp_file" 2>/dev/null || true
        log_error "save_to_cache: failed to save cache for key: $cache_key"
        return 1
    fi
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

# Progress display with input validation
show_progress() {
    local current=$1
    local total=$2
    local operation=$3
    
    # Input validation
    if [[ ! "$current" =~ ^[0-9]+$ ]] || [[ ! "$total" =~ ^[0-9]+$ ]]; then
        log_error "show_progress: current and total must be numeric"
        return 1
    fi
    
    if [[ $total -eq 0 ]]; then
        log_error "show_progress: total cannot be zero"
        return 1
    fi
    
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

# Resource monitoring and limits for parallel operations
# Configuration for resource monitoring
RESOURCE_MONITOR_ENABLED=${RESOURCE_MONITOR_ENABLED:-true}
MEMORY_LIMIT_PERCENT=${MEMORY_LIMIT_PERCENT:-80}
CPU_LIMIT_PERCENT=${CPU_LIMIT_PERCENT:-90}
MIN_PARALLEL_JOBS=${MIN_PARALLEL_JOBS:-1}
MAX_SYSTEM_PARALLEL_JOBS=${MAX_SYSTEM_PARALLEL_JOBS:-16}
RESOURCE_CHECK_INTERVAL=${RESOURCE_CHECK_INTERVAL:-5}
PARALLEL_JOB_TIMEOUT=${PARALLEL_JOB_TIMEOUT:-300}

# Global resource monitoring variables
CURRENT_MEMORY_USAGE=0
CURRENT_CPU_USAGE=0
RESOURCE_MONITOR_PID=0

# Get current system memory usage in percentage
get_memory_usage() {
    if command -v free >/dev/null 2>&1; then
        local total_mem used_mem
        read -r total_mem used_mem < <(free -m | awk 'NR==2{printf "%d %d", $2, $3}')
        
        if [[ $total_mem -gt 0 ]]; then
            echo $((used_mem * 100 / total_mem))
        else
            echo 0
        fi
    else
        echo 0
    fi
}

# Get available memory in MB
get_available_memory() {
    if command -v free >/dev/null 2>&1; then
        free -m | awk 'NR==2{print $7}' 2>/dev/null || echo 0
    else
        echo 0
    fi
}

# Get current CPU usage percentage
get_cpu_usage() {
    local cpu_usage=0
    
    # Try multiple methods with better parsing
    if command -v sar >/dev/null 2>&1; then
        cpu_usage=$(sar -u 1 1 2>/dev/null | tail -1 | awk '{print int(100-$8)}' 2>/dev/null || echo 0)
    elif command -v vmstat >/dev/null 2>&1; then
        cpu_usage=$(vmstat 1 2 2>/dev/null | tail -1 | awk '{print int(100-$15)}' 2>/dev/null || echo 0)
    elif command -v top >/dev/null 2>&1; then
        cpu_usage=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' 2>/dev/null | cut -d. -f1 || echo 0)
    elif command -v iostat >/dev/null 2>&1; then
        cpu_usage=$(iostat -c 1 1 2>/dev/null | tail -1 | awk '{print int(100-$6)}' 2>/dev/null || echo 0)
    fi
    
    # Validate result is numeric and within valid range
    if [[ ! "$cpu_usage" =~ ^[0-9]+$ ]] || [[ "$cpu_usage" -lt 0 ]] || [[ "$cpu_usage" -gt 100 ]]; then
        cpu_usage=0
    fi
    
    echo "$cpu_usage"
}

# Get system load average
get_load_average() {
    if [[ -f /proc/loadavg ]]; then
        cut -d' ' -f1 /proc/loadavg 2>/dev/null || echo 0
    else
        uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | xargs 2>/dev/null || echo 0
    fi
}

# Get number of CPU cores
get_cpu_cores() {
    if [[ -f /proc/cpuinfo ]]; then
        grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo 1
    else
        echo 1
    fi
}

# Check if system resources are within acceptable limits
check_system_resources() {
    local memory_usage cpu_usage load_avg cpu_cores
    
    memory_usage=$(get_memory_usage)
    cpu_usage=$(get_cpu_usage)
    load_avg=$(get_load_average)
    cpu_cores=$(get_cpu_cores)
    
    # Update global variables for monitoring
    CURRENT_MEMORY_USAGE=$memory_usage
    CURRENT_CPU_USAGE=$cpu_usage
    
    # Check if resources are within limits
    if [[ $memory_usage -gt $MEMORY_LIMIT_PERCENT ]]; then
        log_warn "Memory usage high: ${memory_usage}% (limit: ${MEMORY_LIMIT_PERCENT}%)"
        return 1
    fi
    
    if [[ $cpu_usage -gt $CPU_LIMIT_PERCENT ]]; then
        log_warn "CPU usage high: ${cpu_usage}% (limit: ${CPU_LIMIT_PERCENT}%)"
        return 1
    fi
    
    # Check load average (should not exceed number of cores by much)
    local load_threshold
    load_threshold=$(echo "$cpu_cores * 1.5" | bc -l 2>/dev/null | cut -d. -f1 || echo $((cpu_cores + 1)))
    local load_int
    load_int=$(echo "$load_avg" | cut -d. -f1)
    
    if [[ ${load_int:-0} -gt $load_threshold ]]; then
        log_warn "System load high: $load_avg (threshold: $load_threshold)"
        return 1
    fi
    
    return 0
}

# Calculate optimal number of parallel jobs based on available resources
calculate_optimal_parallel_jobs() {
    local base_jobs="${1:-$MAX_PARALLEL_JOBS}"
    
    # Validate input
    if [[ ! "$base_jobs" =~ ^[0-9]+$ ]] || [[ "$base_jobs" -lt 1 ]]; then
        log_error "Invalid base_jobs: $base_jobs (must be positive integer)"
        return 1
    fi
    
    local memory_usage cpu_usage available_memory cpu_cores
    
    memory_usage=$(get_memory_usage)
    cpu_usage=$(get_cpu_usage)
    available_memory=$(get_available_memory)
    cpu_cores=$(get_cpu_cores)
    
    local optimal_jobs=$base_jobs
    
    # Adjust based on memory usage
    if [[ $memory_usage -gt 70 ]]; then
        optimal_jobs=$((optimal_jobs * (100 - memory_usage + 30) / 100))
    fi
    
    # Adjust based on CPU usage
    if [[ $cpu_usage -gt 60 ]]; then
        optimal_jobs=$((optimal_jobs * (100 - cpu_usage + 40) / 100))
    fi
    
    # Adjust based on available memory (assume each job needs ~100MB)
    local memory_based_jobs
    memory_based_jobs=$((available_memory / DEFAULT_MEMORY_PER_JOB_MB))
    # Ensure minimum of 1 job to prevent division by zero
    if [[ $memory_based_jobs -lt 1 ]]; then
        memory_based_jobs=1
    fi
    if [[ $memory_based_jobs -lt $optimal_jobs ]]; then
        optimal_jobs=$memory_based_jobs
    fi
    
    # Ensure we don't exceed CPU cores too much
    if [[ $optimal_jobs -gt $((cpu_cores * 2)) ]]; then
        optimal_jobs=$((cpu_cores * 2))
    fi
    
    # Apply system limits
    if [[ $optimal_jobs -lt $MIN_PARALLEL_JOBS ]]; then
        optimal_jobs=$MIN_PARALLEL_JOBS
    elif [[ $optimal_jobs -gt $MAX_SYSTEM_PARALLEL_JOBS ]]; then
        optimal_jobs=$MAX_SYSTEM_PARALLEL_JOBS
    fi
    
    echo "$optimal_jobs"
}

# Adaptive parallel job execution with resource monitoring
run_parallel_with_resource_limits() {
    local function_name="$1"
    local input_files=("${@:2}")
    local optimal_jobs
    
    # Validate function name to prevent command injection
    if [[ ! "$function_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        log_error "Invalid function name: $function_name (contains unsafe characters)"
        return 1
    fi
    
    if [[ ! "$RESOURCE_MONITOR_ENABLED" == "true" ]]; then
        # Fall back to standard parallel execution
        run_parallel_function "$function_name" "$MAX_PARALLEL_JOBS" "${input_files[@]}"
        return $?
    fi
    
    # Calculate optimal number of jobs
    optimal_jobs=$(calculate_optimal_parallel_jobs)
    
    log_info "🔧 Adaptive parallelism: using $optimal_jobs jobs (memory: ${CURRENT_MEMORY_USAGE}%, CPU: ${CURRENT_CPU_USAGE}%)"
    
    # Check if function exists
    if ! declare -F "$function_name" > /dev/null; then
        log_error "Function $function_name not found"
        return 1
    fi
    
    # Export necessary functions and variables
    export -f "$function_name"
    export -f log_info log_warn log_error log_header
    export RED YELLOW GREEN BLUE NC
    
    # Start resource monitoring in background
    start_resource_monitor
    
    # Run with timeout and resource monitoring
    local exit_code=0
    if ! timeout "$PARALLEL_JOB_TIMEOUT" bash -c '
        printf "%s\0" "$@" | xargs -0 -P '"$optimal_jobs"' -I {} bash -c "'"$function_name"' \"\$1\"" _ {}
    ' _ "${input_files[@]}"; then
        exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            log_error "Parallel job execution timed out after ${PARALLEL_JOB_TIMEOUT}s"
        else
            log_error "Parallel job execution failed with exit code $exit_code"
        fi
    fi
    
    # Stop resource monitoring
    stop_resource_monitor
    
    return $exit_code
}

# Start background resource monitoring
start_resource_monitor() {
    if [[ "$RESOURCE_MONITOR_ENABLED" != "true" ]]; then
        return 0
    fi
    
    # Stop any existing monitor
    stop_resource_monitor
    
    # Start background monitoring process
    (
        while true; do
            if ! check_system_resources; then
                log_warn "⚠️  System resources are constrained - consider reducing parallel jobs"
            fi
            sleep "$RESOURCE_CHECK_INTERVAL"
        done
    ) &
    
    RESOURCE_MONITOR_PID=$!
    add_cleanup_function "stop_resource_monitor"
}

# Stop background resource monitoring  
stop_resource_monitor() {
    if [[ $RESOURCE_MONITOR_PID -gt 0 ]]; then
        # Validate that the PID belongs to our process
        if kill -0 $RESOURCE_MONITOR_PID 2>/dev/null; then
            kill $RESOURCE_MONITOR_PID 2>/dev/null || true
            # Give it a moment to terminate gracefully
            sleep 0.1
            # Force kill if still running
            kill -KILL $RESOURCE_MONITOR_PID 2>/dev/null || true
        fi
        wait $RESOURCE_MONITOR_PID 2>/dev/null || true
        RESOURCE_MONITOR_PID=0
    fi
}

# Monitor and limit memory usage for a command
run_with_memory_limit() {
    local memory_limit_mb="$1"
    local command="$2"
    shift 2
    local args=("$@")
    
    if ! command -v timeout >/dev/null 2>&1; then
        log_warn "timeout command not available, running without memory limit"
        "$command" "${args[@]}"
        return $?
    fi
    
    # Use ulimit to set memory limit (in KB)
    local memory_limit_kb=$((memory_limit_mb * 1024))
    
    (
        # Set memory limit for the subshell
        ulimit -v $memory_limit_kb 2>/dev/null || true
        ulimit -m $memory_limit_kb 2>/dev/null || true
        
        # Run the command with timeout
        timeout "$PARALLEL_JOB_TIMEOUT" "$command" "${args[@]}"
    )
    
    local exit_code=$?
    if [[ $exit_code -eq 124 ]]; then
        log_error "Command timed out after ${PARALLEL_JOB_TIMEOUT}s: $command"
    elif [[ $exit_code -ne 0 ]]; then
        log_warn "Command failed (possibly due to memory limit): $command"
    fi
    
    return $exit_code
}

# Get resource usage statistics
get_resource_stats() {
    local output_format="${1:-text}"
    local memory_usage cpu_usage load_avg available_memory cpu_cores
    
    memory_usage=$(get_memory_usage)
    cpu_usage=$(get_cpu_usage)
    load_avg=$(get_load_average)
    available_memory=$(get_available_memory)
    cpu_cores=$(get_cpu_cores)
    
    case "$output_format" in
        "json")
            cat << EOF
{
    "memory_usage_percent": $memory_usage,
    "cpu_usage_percent": $cpu_usage,
    "load_average": $load_avg,
    "available_memory_mb": $available_memory,
    "cpu_cores": $cpu_cores,
    "optimal_parallel_jobs": $(calculate_optimal_parallel_jobs),
    "resource_limits": {
        "memory_limit_percent": $MEMORY_LIMIT_PERCENT,
        "cpu_limit_percent": $CPU_LIMIT_PERCENT,
        "min_parallel_jobs": $MIN_PARALLEL_JOBS,
        "max_parallel_jobs": $MAX_SYSTEM_PARALLEL_JOBS
    }
}
EOF
            ;;
        *)
            echo "📊 System Resource Statistics:"
            echo "  💾 Memory usage: ${memory_usage}% (available: ${available_memory}MB)"
            echo "  🖥️  CPU usage: ${cpu_usage}%"
            echo "  ⚖️  Load average: $load_avg"
            echo "  🔧 CPU cores: $cpu_cores" 
            echo "  🚀 Optimal parallel jobs: $(calculate_optimal_parallel_jobs)"
            echo "  ⚠️  Resource limits: Memory ${MEMORY_LIMIT_PERCENT}%, CPU ${CPU_LIMIT_PERCENT}%"
            ;;
    esac
}

# Cleanup function for resource monitoring
cleanup_resource_monitor() {
    stop_resource_monitor
    
    # Clean up any remaining background processes
    jobs -p | xargs -r kill 2>/dev/null || true
    
    # Reset global variables
    CURRENT_MEMORY_USAGE=0
    CURRENT_CPU_USAGE=0
    RESOURCE_MONITOR_PID=0
}