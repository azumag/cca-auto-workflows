#!/bin/bash

# Performance metrics collection module for Claude Code Auto Workflows
# This module provides comprehensive performance monitoring and benchmarking

# Source dependencies
performance_metrics_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$performance_metrics_script_dir/common.sh"
source "$performance_metrics_script_dir/github-api.sh"

# Performance metrics configuration
METRICS_DIR="${TMPDIR:-/tmp}/performance-metrics"
METRICS_RETENTION_DAYS=30
BENCHMARK_ITERATIONS=5

# Global performance counters
SCRIPT_START_TIME=0
SCRIPT_END_TIME=0
TOTAL_OPERATIONS=0
SUCCESSFUL_OPERATIONS=0
CACHE_OPERATIONS=0
API_OPERATIONS=0

# Initialize performance metrics module
performance_metrics_init() {
    setup_cache "$METRICS_DIR"
    cleanup_cache "$METRICS_DIR" $((METRICS_RETENTION_DAYS * 24 * 60 * 60))
    
    SCRIPT_START_TIME=$(date +%s.%N)
    log_info "Performance metrics collection initialized"
}

# Start timing an operation
start_timer() {
    local operation_name="$1"
    local timestamp
    timestamp=$(date +%s.%N)
    echo "$timestamp" > "${METRICS_DIR}/${operation_name}_start.tmp"
}

# End timing an operation and record metrics
end_timer() {
    local operation_name="$1"
    local success="${2:-true}"
    local end_time
    end_time=$(date +%s.%N)
    
    local start_file="${METRICS_DIR}/${operation_name}_start.tmp"
    if [[ ! -f "$start_file" ]]; then
        log_warn "No start time found for operation: $operation_name"
        return 1
    fi
    
    local start_time
    start_time=$(cat "$start_file")
    rm -f "$start_file"
    
    local duration
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    
    # Record operation metrics
    local metrics_file="${METRICS_DIR}/operations.log"
    echo "$(date -Iseconds),${operation_name},${duration},${success}" >> "$metrics_file"
    
    ((TOTAL_OPERATIONS++))
    if [[ "$success" == "true" ]]; then
        ((SUCCESSFUL_OPERATIONS++))
    fi
    
    # Log if operation took longer than expected
    local duration_int
    duration_int=$(echo "$duration" | cut -d. -f1)
    if [[ ${duration_int:-0} -gt 5 ]]; then
        log_warn "⏱️  Slow operation detected: $operation_name took ${duration}s"
    fi
    
    echo "$duration"
}

# Record cache hit/miss
record_cache_operation() {
    local operation_type="$1"  # "hit" or "miss"
    local cache_name="$2"
    
    ((CACHE_OPERATIONS++))
    
    local cache_metrics_file="${METRICS_DIR}/cache.log"
    echo "$(date -Iseconds),${cache_name},${operation_type}" >> "$cache_metrics_file"
}

# Record API operation
record_api_operation() {
    local endpoint="$1"
    local status_code="$2"
    local response_time="$3"
    
    ((API_OPERATIONS++))
    
    local api_metrics_file="${METRICS_DIR}/api.log"
    echo "$(date -Iseconds),${endpoint},${status_code},${response_time}" >> "$api_metrics_file"
}

# Record resource usage metrics
record_resource_usage() {
    local operation_name="$1"
    local parallel_jobs="${2:-1}"
    
    if [[ "$RESOURCE_MONITOR_ENABLED" != "true" ]]; then
        return 0
    fi
    
    local memory_usage cpu_usage load_avg available_memory
    memory_usage=$(get_memory_usage)
    cpu_usage=$(get_cpu_usage)
    load_avg=$(get_load_average)
    available_memory=$(get_available_memory)
    
    local resource_metrics_file="${METRICS_DIR}/resources.log"
    echo "$(date -Iseconds),${operation_name},${parallel_jobs},${memory_usage},${cpu_usage},${load_avg},${available_memory}" >> "$resource_metrics_file"
}

# Get resource usage trends
get_resource_trends() {
    local operation_name="${1:-*}"
    local resource_file="${METRICS_DIR}/resources.log"
    
    if [[ ! -f "$resource_file" ]]; then
        echo "No resource metrics available"
        return 1
    fi
    
    local avg_memory avg_cpu max_memory max_cpu
    if [[ "$operation_name" == "*" ]]; then
        read avg_memory avg_cpu max_memory max_cpu < <(awk -F, '
            { 
                mem_sum += $4; cpu_sum += $5; count++; 
                if ($4 > max_mem) max_mem = $4;
                if ($5 > max_cpu) max_cpu = $5;
            } 
            END { 
                if (count > 0) 
                    printf "%.1f %.1f %.1f %.1f", mem_sum/count, cpu_sum/count, max_mem, max_cpu;
                else 
                    print "0 0 0 0"
            }' "$resource_file")
    else
        read avg_memory avg_cpu max_memory max_cpu < <(grep ",$operation_name," "$resource_file" | awk -F, '
            { 
                mem_sum += $4; cpu_sum += $5; count++; 
                if ($4 > max_mem) max_mem = $4;
                if ($5 > max_cpu) max_cpu = $5;
            } 
            END { 
                if (count > 0) 
                    printf "%.1f %.1f %.1f %.1f", mem_sum/count, cpu_sum/count, max_mem, max_cpu;
                else 
                    print "0 0 0 0"
            }')
    fi
    
    echo "📊 Resource Usage Trends for ${operation_name}:"
    echo "  💾 Average memory: ${avg_memory:-0}% (peak: ${max_memory:-0}%)"
    echo "  🖥️  Average CPU: ${avg_cpu:-0}% (peak: ${max_cpu:-0}%)"
}

# Calculate cache hit rate
get_cache_hit_rate() {
    local cache_name="${1:-*}"
    local cache_file="${METRICS_DIR}/cache.log"
    
    if [[ ! -f "$cache_file" ]]; then
        echo "0"
        return
    fi
    
    local total_ops hits
    if [[ "$cache_name" == "*" ]]; then
        total_ops=$(wc -l < "$cache_file")
        hits=$(grep -c ",hit$" "$cache_file" 2>/dev/null || echo 0)
    else
        total_ops=$(grep -c ",$cache_name," "$cache_file" 2>/dev/null || echo 0)
        hits=$(grep ",$cache_name,hit$" "$cache_file" | wc -l 2>/dev/null || echo 0)
    fi
    
    if [[ $total_ops -eq 0 ]]; then
        echo "0"
    else
        echo $((hits * 100 / total_ops))
    fi
}

# Get average operation time
get_average_operation_time() {
    local operation_name="${1:-*}"
    local ops_file="${METRICS_DIR}/operations.log"
    
    if [[ ! -f "$ops_file" ]]; then
        echo "0"
        return
    fi
    
    local avg_time
    if [[ "$operation_name" == "*" ]]; then
        avg_time=$(awk -F, '{sum+=$3; count++} END {if(count>0) print sum/count; else print 0}' "$ops_file")
    else
        avg_time=$(grep ",$operation_name," "$ops_file" | awk -F, '{sum+=$3; count++} END {if(count>0) print sum/count; else print 0}')
    fi
    
    printf "%.3f" "${avg_time:-0}"
}

# Get operation success rate
get_operation_success_rate() {
    local operation_name="${1:-*}"
    local ops_file="${METRICS_DIR}/operations.log"
    
    if [[ ! -f "$ops_file" ]]; then
        echo "100"
        return
    fi
    
    local total_ops successful_ops
    if [[ "$operation_name" == "*" ]]; then
        total_ops=$(wc -l < "$ops_file")
        successful_ops=$(grep -c ",true$" "$ops_file" 2>/dev/null || echo 0)
    else
        total_ops=$(grep -c ",$operation_name," "$ops_file" 2>/dev/null || echo 0)
        successful_ops=$(grep ",$operation_name,.*,true$" "$ops_file" | wc -l 2>/dev/null || echo 0)
    fi
    
    if [[ $total_ops -eq 0 ]]; then
        echo "100"
    else
        echo $((successful_ops * 100 / total_ops))
    fi
}

# Run performance benchmark
run_performance_benchmark() {
    local benchmark_name="$1"
    local benchmark_command="$2"
    
    log_info "🏃 Running performance benchmark: $benchmark_name"
    
    local total_time=0
    local successful_runs=0
    local benchmark_results=()
    
    for ((i=1; i<=BENCHMARK_ITERATIONS; i++)); do
        log_info "  📊 Benchmark iteration $i/$BENCHMARK_ITERATIONS"
        
        start_timer "benchmark_${benchmark_name}_${i}"
        
        local start_time end_time duration success=true
        start_time=$(date +%s.%N)
        
        if eval "$benchmark_command" >/dev/null 2>&1; then
            success=true
            ((successful_runs++))
        else
            success=false
        fi
        
        end_time=$(date +%s.%N)
        duration=$(echo "$end_time - $start_time" | bc -l)
        
        end_timer "benchmark_${benchmark_name}_${i}" "$success"
        
        benchmark_results+=("$duration")
        total_time=$(echo "$total_time + $duration" | bc -l)
    done
    
    # Calculate statistics
    local avg_time min_time max_time
    avg_time=$(echo "$total_time / $BENCHMARK_ITERATIONS" | bc -l)
    min_time=$(printf '%s\n' "${benchmark_results[@]}" | sort -n | head -1)
    max_time=$(printf '%s\n' "${benchmark_results[@]}" | sort -n | tail -1)
    
    # Save benchmark results
    local benchmark_file="${METRICS_DIR}/benchmarks.log"
    echo "$(date -Iseconds),${benchmark_name},${avg_time},${min_time},${max_time},${successful_runs}/${BENCHMARK_ITERATIONS}" >> "$benchmark_file"
    
    log_info "📈 Benchmark Results for $benchmark_name:"
    log_info "  ⏱️  Average time: $(printf '%.3f' "$avg_time")s"
    log_info "  🚀 Best time: $(printf '%.3f' "$min_time")s"
    log_info "  🐌 Worst time: $(printf '%.3f' "$max_time")s"
    log_info "  ✅ Success rate: $successful_runs/$BENCHMARK_ITERATIONS"
}

# Load test with parallel operations
run_load_test() {
    local test_name="$1"
    local test_command="$2"
    local concurrent_operations="${3:-10}"
    local total_operations="${4:-50}"
    
    log_info "🔥 Running load test: $test_name"
    log_info "  📊 $concurrent_operations concurrent operations, $total_operations total"
    
    local pids=()
    local completed=0
    local successful=0
    local start_time end_time
    
    start_time=$(date +%s.%N)
    
    # Run operations in batches
    while [[ $completed -lt $total_operations ]]; do
        # Start batch of concurrent operations
        local batch_size=$concurrent_operations
        if [[ $((completed + batch_size)) -gt $total_operations ]]; then
            batch_size=$((total_operations - completed))
        fi
        
        for ((i=0; i<batch_size; i++)); do
            (
                start_timer "loadtest_${test_name}_$((completed + i + 1))"
                if eval "$test_command" >/dev/null 2>&1; then
                    end_timer "loadtest_${test_name}_$((completed + i + 1))" "true"
                    exit 0
                else
                    end_timer "loadtest_${test_name}_$((completed + i + 1))" "false"
                    exit 1
                fi
            ) &
            pids+=($!)
        done
        
        # Wait for batch to complete
        for pid in "${pids[@]}"; do
            if wait "$pid"; then
                ((successful++))
            fi
        done
        pids=()
        
        ((completed += batch_size))
        show_progress "$completed" "$total_operations" "Load Test Progress"
    done
    
    end_time=$(date +%s.%N)
    local total_time
    total_time=$(echo "$end_time - $start_time" | bc -l)
    
    # Calculate throughput
    local throughput
    throughput=$(echo "$total_operations / $total_time" | bc -l)
    
    # Save load test results
    local loadtest_file="${METRICS_DIR}/loadtests.log"
    echo "$(date -Iseconds),${test_name},${total_operations},${successful},${total_time},${throughput}" >> "$loadtest_file"
    
    log_info "🔥 Load Test Results for $test_name:"
    log_info "  ⏱️  Total time: $(printf '%.3f' "$total_time")s"
    log_info "  📈 Throughput: $(printf '%.2f' "$throughput") ops/sec"
    log_info "  ✅ Success rate: $successful/$total_operations ($(( successful * 100 / total_operations ))%)"
}

# Get comprehensive performance report
generate_performance_report() {
    log_header "📊 Performance Metrics Report"
    
    SCRIPT_END_TIME=$(date +%s.%N)
    local script_duration
    script_duration=$(echo "$SCRIPT_END_TIME - $SCRIPT_START_TIME" | bc -l)
    
    log_info "🕐 Script Execution Metrics:"
    log_info "  ⏱️  Total execution time: $(printf '%.3f' "$script_duration")s"
    log_info "  📊 Total operations: $TOTAL_OPERATIONS"
    log_info "  ✅ Successful operations: $SUCCESSFUL_OPERATIONS ($(( SUCCESSFUL_OPERATIONS * 100 / (TOTAL_OPERATIONS > 0 ? TOTAL_OPERATIONS : 1) ))%)"
    log_info "  💾 Cache operations: $CACHE_OPERATIONS"
    log_info "  🌐 API operations: $API_OPERATIONS"
    
    log_info "📈 Cache Performance:"
    log_info "  🎯 Overall cache hit rate: $(get_cache_hit_rate)%"
    
    log_info "⚡ Operation Performance:"
    log_info "  ⏱️  Average operation time: $(get_average_operation_time)s"
    log_info "  ✅ Overall success rate: $(get_operation_success_rate)%"
    
    # Show resource usage trends if available
    if [[ -f "${METRICS_DIR}/resources.log" ]]; then
        log_info "🖥️  Resource Usage:"
        get_resource_trends "*" | tail -n +2  # Skip the header line
        
        # Show current resource status
        if command -v get_resource_stats >/dev/null 2>&1; then
            log_info "📊 Current System Status:"
            get_resource_stats | tail -n +2  # Skip the header line
        fi
    fi
    
    # Show GitHub API metrics if available
    if command -v github_api_get_metrics &>/dev/null; then
        local api_metrics
        api_metrics=$(github_api_get_metrics 2>/dev/null)
        if [[ -n "$api_metrics" ]]; then
            log_info "🌐 GitHub API Performance:"
            echo "$api_metrics" | jq -r '. | 
                "  📞 Total API calls: \(.api_calls_total)",
                "  💾 Cache hits: \(.cache_hits) (\(.cache_hit_rate_percent)%)",
                "  ⚠️  Rate limit warnings: \(.rate_limit_warnings)"'
        fi
    fi
}

# Export metrics to JSON
export_metrics_json() {
    local output_file="$1"
    
    local script_duration
    script_duration=$(echo "${SCRIPT_END_TIME:-$(date +%s.%N)} - $SCRIPT_START_TIME" | bc -l)
    
    cat > "$output_file" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "script_duration": $script_duration,
  "operations": {
    "total": $TOTAL_OPERATIONS,
    "successful": $SUCCESSFUL_OPERATIONS,
    "success_rate_percent": $(( SUCCESSFUL_OPERATIONS * 100 / (TOTAL_OPERATIONS > 0 ? TOTAL_OPERATIONS : 1) )),
    "average_time": $(get_average_operation_time)
  },
  "cache": {
    "operations": $CACHE_OPERATIONS,
    "hit_rate_percent": $(get_cache_hit_rate)
  },
  "api": {
    "operations": $API_OPERATIONS
  },
  "resources": $(
    if [[ -f "${METRICS_DIR}/resources.log" ]]; then
      get_resource_stats "json"
    else
      echo '{"available": false}'
    fi
  )
}
EOF
    
    log_info "📤 Performance metrics exported to: $output_file"
}

# Cleanup performance metrics module
performance_metrics_cleanup() {
    # Clean up old metrics files
    find "$METRICS_DIR" -name "*.tmp" -delete 2>/dev/null || true
    
    # Archive old logs
    local archive_date
    archive_date=$(date -d "${METRICS_RETENTION_DAYS} days ago" '+%Y-%m-%d')
    
    for log_file in operations.log cache.log api.log benchmarks.log loadtests.log resources.log; do
        local full_path="${METRICS_DIR}/${log_file}"
        if [[ -f "$full_path" ]]; then
            # Remove entries older than retention period
            local temp_file="${full_path}.tmp"
            awk -F, -v cutoff="$archive_date" '
                BEGIN { cutoff_ts = mktime(gensub(/-/, " ", "g", cutoff) " 00 00 00") }
                { 
                    ts = mktime(gensub(/[-:T]/, " ", "g", gensub(/\+.*/, "", 1, $1)) " 00")
                    if (ts >= cutoff_ts) print $0
                }' "$full_path" > "$temp_file" && mv "$temp_file" "$full_path"
        fi
    done
    
    log_info "Performance metrics cleanup completed"
}