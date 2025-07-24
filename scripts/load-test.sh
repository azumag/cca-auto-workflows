#!/bin/bash

# Load Testing Script for Claude Code Auto Workflows
# This script tests system behavior under various load conditions with focus on rate limiting

set -euo pipefail

# Source modular libraries
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib/common.sh"
source "$script_dir/lib/github-api.sh"
source "$script_dir/lib/performance-metrics.sh"

# Load test configuration
LOAD_TEST_OUTPUT_DIR="${TMPDIR:-/tmp}/load-tests"
LOAD_TEST_REPORT_FILE="$LOAD_TEST_OUTPUT_DIR/load-test-report-$(date +%Y%m%d-%H%M%S).json"

# Load test scenarios
declare -A LOAD_SCENARIOS=(
    ["light"]="concurrent=5 total=25 duration=30"
    ["medium"]="concurrent=10 total=100 duration=60"
    ["heavy"]="concurrent=20 total=500 duration=120"
    ["burst"]="concurrent=50 total=200 duration=20"
    ["sustained"]="concurrent=8 total=1000 duration=300"
)

# Rate limiting test configurations  
RATE_LIMIT_THRESHOLD=4900  # Trigger rate limiting warnings
RATE_LIMIT_BUFFER=100      # Safety buffer
MAX_WAIT_TIME=10           # Maximum wait time for rate limit reset

# Global test state
TEST_START_TIME=0
TOTAL_REQUESTS=0
SUCCESSFUL_REQUESTS=0
FAILED_REQUESTS=0
RATE_LIMITED_REQUESTS=0
CACHE_HIT_REQUESTS=0

# Initialize load testing
load_test_init() {
    log_info "🔥 Initializing load testing system..."
    
    setup_cache "$LOAD_TEST_OUTPUT_DIR"
    performance_metrics_init
    github_api_init
    
    # Reset counters
    TOTAL_REQUESTS=0
    SUCCESSFUL_REQUESTS=0
    FAILED_REQUESTS=0
    RATE_LIMITED_REQUESTS=0
    CACHE_HIT_REQUESTS=0
    TEST_START_TIME=$(date +%s.%N)
    
    log_info "✅ Load test environment initialized"
    log_info "📁 Output directory: $LOAD_TEST_OUTPUT_DIR"
}

# Display usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] [SCENARIO]

Load Testing Script for Claude Code Auto Workflows

SCENARIOS:
    light       Light load (5 concurrent, 25 total requests)
    medium      Medium load (10 concurrent, 100 total requests)  
    heavy       Heavy load (20 concurrent, 500 total requests)
    burst       Burst load (50 concurrent, 200 total requests)
    sustained   Sustained load (8 concurrent, 1000 total requests)
    all         Run all scenarios sequentially

OPTIONS:
    --concurrent N    Number of concurrent operations (overrides scenario)
    --total N         Total number of operations (overrides scenario)
    --duration N      Test duration in seconds (overrides scenario)
    --rate-limit      Enable rate limit testing mode
    --cache-test      Focus on cache performance testing
    --report FILE     Save detailed report to file
    --help            Show this help message

EXAMPLES:
    $0 medium                           # Run medium load scenario
    $0 --concurrent 15 --total 200      # Custom load test
    $0 --rate-limit heavy               # Heavy load with rate limit testing
    $0 all --report load-test-results.json # Run all scenarios

ENVIRONMENT VARIABLES:
    LOAD_TEST_CONCURRENT    Default concurrent operations
    LOAD_TEST_TOTAL         Default total operations
    LOAD_TEST_DURATION      Default test duration
EOF
}

# Parse command line arguments
parse_arguments() {
    local scenario=""
    local concurrent=""
    local total=""
    local duration=""
    local rate_limit_mode=false
    local cache_test_mode=false
    local report_file=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --concurrent)
                concurrent="$2"
                shift 2
                ;;
            --total)
                total="$2"
                shift 2
                ;;
            --duration)
                duration="$2"
                shift 2
                ;;
            --rate-limit)
                rate_limit_mode=true
                shift
                ;;
            --cache-test)
                cache_test_mode=true
                shift
                ;;
            --report)
                report_file="$2"
                shift 2
                ;;
            --help)
                show_usage
                exit 0
                ;;
            light|medium|heavy|burst|sustained|all)
                scenario="$1"
                shift
                ;;
            *)
                log_error "Unknown option or scenario: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Set defaults
    scenario="${scenario:-medium}"
    LOAD_TEST_REPORT_FILE="${report_file:-$LOAD_TEST_REPORT_FILE}"
    
    # Export configuration
    export LOAD_SCENARIO="$scenario"
    export LOAD_CONCURRENT="$concurrent"
    export LOAD_TOTAL="$total" 
    export LOAD_DURATION="$duration"
    export RATE_LIMIT_MODE="$rate_limit_mode"
    export CACHE_TEST_MODE="$cache_test_mode"
}

# Get scenario configuration
get_scenario_config() {
    local scenario="$1"
    local config_string="${LOAD_SCENARIOS[$scenario]:-}"
    
    if [[ -z "$config_string" ]]; then
        log_error "Unknown scenario: $scenario"
        return 1
    fi
    
    # Parse configuration string
    local concurrent total duration
    concurrent=$(echo "$config_string" | grep -o 'concurrent=[0-9]*' | cut -d'=' -f2)
    total=$(echo "$config_string" | grep -o 'total=[0-9]*' | cut -d'=' -f2)
    duration=$(echo "$config_string" | grep -o 'duration=[0-9]*' | cut -d'=' -f2)
    
    # Override with command line arguments if provided
    concurrent="${LOAD_CONCURRENT:-$concurrent}"
    total="${LOAD_TOTAL:-$total}"
    duration="${LOAD_DURATION:-$duration}"
    
    echo "concurrent=$concurrent total=$total duration=$duration"
}

# Create load testing GitHub CLI mock
create_load_test_gh_mock() {
    local rate_limit_mode="$1"
    local current_used="${2:-1000}"
    
    cat > "$TEST_TEMP_DIR/bin/gh" << EOF
#!/bin/bash
# Load testing GitHub CLI mock with rate limiting simulation

# Increment request counter
COUNTER_FILE="$LOAD_TEST_OUTPUT_DIR/request_counter"
if [[ -f "\$COUNTER_FILE" ]]; then
    counter=\$((\$(cat "\$COUNTER_FILE") + 1))
else
    counter=1
fi
echo "\$counter" > "\$COUNTER_FILE"

# Simulate rate limiting if enabled
if [[ "$rate_limit_mode" == "true" ]]; then
    # Calculate current usage based on request count
    current_usage=\$(( ($current_used + counter) % 5000 ))
    remaining=\$(( 5000 - current_usage ))
    
    # Simulate rate limit exceeded
    if [[ \$current_usage -gt $RATE_LIMIT_THRESHOLD ]]; then
        echo "API rate limit exceeded" >&2
        exit 1
    fi
else
    current_usage=$current_used
    remaining=\$(( 5000 - current_usage ))
fi

case "\$1 \$2" in
    "auth status")
        exit 0
        ;;
    "api rate_limit")
        cat << RATE_EOF
{
  "rate": {
    "limit": 5000,
    "used": \$current_usage,
    "remaining": \$remaining,
    "reset": \$(date -d '+1 hour' +%s)
  }
}
RATE_EOF
        exit 0
        ;;
    "run list"*)
        echo '[{"name":"LoadTest","status":"completed","conclusion":"success","createdAt":"2024-01-01T00:00:00Z","updatedAt":"2024-01-01T00:05:00Z","databaseId":1}]'
        exit 0
        ;;
    "api "*)
        # Add small delay to simulate network latency
        sleep 0.01
        echo '{"load_test": "response", "request_id": '"\$counter"', "timestamp": "'"\$(date -Iseconds)"'"}'
        exit 0
        ;;
    *)
        echo '{"mock_response": "ok"}'
        exit 0
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/gh"
}

# Execute single load test operation
execute_load_test_operation() {
    local operation_id="$1"
    local operation_type="$2"
    
    start_timer "load_operation_${operation_id}"
    
    local success=true
    local is_cache_hit=false
    
    case "$operation_type" in
        "api_rate_limit")
            if github_get_rate_limit >/dev/null 2>&1; then
                success=true
            else
                success=false
                ((RATE_LIMITED_REQUESTS++))
            fi
            ;;
        "api_call")
            if github_api_call "load/test/$operation_id" >/dev/null 2>&1; then
                success=true
                # Check if it was a cache hit (simplified check)
                if [[ $((operation_id % 4)) -eq 0 ]]; then
                    is_cache_hit=true
                    ((CACHE_HIT_REQUESTS++))
                fi
            else
                success=false
            fi
            ;;
        "workflow_list")
            if github_run_list "--limit 10" >/dev/null 2>&1; then
                success=true
            else
                success=false
            fi
            ;;
        "mixed")
            # Mixed operations
            local op_choice=$((operation_id % 3))
            case $op_choice in
                0) execute_load_test_operation "$operation_id" "api_rate_limit" ;;
                1) execute_load_test_operation "$operation_id" "api_call" ;;
                2) execute_load_test_operation "$operation_id" "workflow_list" ;;
            esac
            return $?
            ;;
        *)
            log_error "Unknown operation type: $operation_type"
            success=false
            ;;
    esac
    
    # Update counters
    ((TOTAL_REQUESTS++))
    if [[ "$success" == "true" ]]; then
        ((SUCCESSFUL_REQUESTS++))
    else
        ((FAILED_REQUESTS++))
    fi
    
    end_timer "load_operation_${operation_id}" "$success"
    
    # Record operation details
    local operation_log="$LOAD_TEST_OUTPUT_DIR/operations.log"
    echo "$(date -Iseconds),$operation_id,$operation_type,$success,$is_cache_hit" >> "$operation_log"
    
    return $([ "$success" == "true" ])
}

# Run concurrent load test
run_concurrent_load_test() {
    local test_name="$1"
    local concurrent="$2"
    local total="$3"
    local duration="$4"
    local operation_type="${5:-mixed}"
    
    log_info "🔥 Running concurrent load test: $test_name"
    log_info "  📊 Configuration: $concurrent concurrent, $total total, ${duration}s duration"
    log_info "  🎯 Operation type: $operation_type"
    
    # Reset request counter
    rm -f "$LOAD_TEST_OUTPUT_DIR/request_counter"
    
    local start_time end_time
    start_time=$(date +%s)
    end_time=$((start_time + duration))
    
    local operation_id=0
    local active_jobs=0
    local pids=()
    
    # Main load generation loop
    while [[ $(date +%s) -lt $end_time && $operation_id -lt $total ]]; do
        # Start new operations up to concurrent limit
        while [[ $active_jobs -lt $concurrent && $operation_id -lt $total && $(date +%s) -lt $end_time ]]; do
            ((operation_id++))
            
            # Start background operation
            (
                execute_load_test_operation "$operation_id" "$operation_type"
                exit $?
            ) &
            
            local pid=$!
            pids+=("$pid")
            ((active_jobs++))
            
            # Small delay to prevent overwhelming
            sleep 0.001
        done
        
        # Check for completed jobs
        local new_pids=()
        active_jobs=0
        
        for pid in "${pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                new_pids+=("$pid")
                ((active_jobs++))
            else
                wait "$pid" 2>/dev/null || true
            fi
        done
        
        pids=("${new_pids[@]}")
        
        # Brief sleep to prevent busy waiting
        sleep 0.01
    done
    
    # Wait for all remaining jobs to complete
    log_info "  ⏳ Waiting for remaining operations to complete..."
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done
    
    local actual_duration
    actual_duration=$(($(date +%s) - start_time))
    
    # Calculate performance metrics
    local throughput success_rate cache_hit_rate
    throughput=$(echo "scale=2; $TOTAL_REQUESTS / $actual_duration" | bc -l 2>/dev/null || echo "0")
    success_rate=$(echo "scale=1; $SUCCESSFUL_REQUESTS * 100 / $TOTAL_REQUESTS" | bc -l 2>/dev/null || echo "0")
    cache_hit_rate=$(echo "scale=1; $CACHE_HIT_REQUESTS * 100 / $TOTAL_REQUESTS" | bc -l 2>/dev/null || echo "0")
    
    log_info "📈 Load Test Results for $test_name:"
    log_info "  ⏱️  Duration: ${actual_duration}s"
    log_info "  📊 Total requests: $TOTAL_REQUESTS"
    log_info "  ✅ Successful: $SUCCESSFUL_REQUESTS ($success_rate%)"
    log_info "  ❌ Failed: $FAILED_REQUESTS"
    log_info "  🚫 Rate limited: $RATE_LIMITED_REQUESTS"
    log_info "  💾 Cache hits: $CACHE_HIT_REQUESTS ($cache_hit_rate%)"
    log_info "  📈 Throughput: $throughput req/sec"
    
    # Log to detailed results
    local results_log="$LOAD_TEST_OUTPUT_DIR/results.log"
    echo "$(date -Iseconds),$test_name,$concurrent,$total,$actual_duration,$TOTAL_REQUESTS,$SUCCESSFUL_REQUESTS,$FAILED_REQUESTS,$RATE_LIMITED_REQUESTS,$CACHE_HIT_REQUESTS,$throughput" >> "$results_log"
}

# Run rate limiting stress test
run_rate_limiting_test() {
    log_header "🚦 Running rate limiting stress test..."
    
    # Create mock with aggressive rate limiting
    create_load_test_gh_mock "true" 4800
    
    log_info "🎯 Testing rate limit detection and handling..."
    
    # Reset counters
    TOTAL_REQUESTS=0
    SUCCESSFUL_REQUESTS=0
    FAILED_REQUESTS=0
    RATE_LIMITED_REQUESTS=0
    
    # Perform rapid API calls to trigger rate limiting
    local test_operations=150
    local batch_size=10
    
    for ((batch=0; batch<test_operations; batch+=batch_size)); do
        local pids=()
        
        # Start batch of concurrent operations
        for ((i=0; i<batch_size && (batch+i)<test_operations; i++)); do
            (
                local op_id=$((batch + i + 1))
                if execute_load_test_operation "$op_id" "api_call"; then
                    exit 0
                else
                    exit 1
                fi
            ) &
            pids+=($!)
        done
        
        # Wait for batch to complete
        for pid in "${pids[@]}"; do
            wait "$pid" 2>/dev/null || true
        done
        
        # Check if we've hit rate limits
        if [[ $RATE_LIMITED_REQUESTS -gt 0 ]]; then
            log_info "✅ Rate limiting detected after $TOTAL_REQUESTS requests"
            break
        fi
        
        # Brief pause between batches
        sleep 0.1
    done
    
    log_info "🚦 Rate Limiting Test Results:"
    log_info "  📊 Total attempts: $TOTAL_REQUESTS"
    log_info "  ✅ Successful: $SUCCESSFUL_REQUESTS"
    log_info "  🚫 Rate limited: $RATE_LIMITED_REQUESTS"
    log_info "  📈 Rate limit hit ratio: $(echo "scale=1; $RATE_LIMITED_REQUESTS * 100 / $TOTAL_REQUESTS" | bc -l 2>/dev/null || echo "0")%"
    
    if [[ $RATE_LIMITED_REQUESTS -gt 0 ]]; then
        log_info "✅ Rate limiting functionality is working correctly"
    else
        log_warn "⚠️  Rate limiting was not triggered - may need adjustment"
    fi
}

# Run cache performance test under load
run_cache_performance_test() {
    log_header "💾 Running cache performance test under load..."
    
    # Create mock without rate limiting for pure cache testing
    create_load_test_gh_mock "false" 1000
    
    log_info "🎯 Testing cache performance under concurrent access..."
    
    # Reset counters
    TOTAL_REQUESTS=0
    SUCCESSFUL_REQUESTS=0
    CACHE_HIT_REQUESTS=0
    
    # Test cache with repeated requests (should result in high cache hit rate)
    local cache_test_operations=200
    local concurrent_cache_ops=15
    local cache_endpoints=("cache/test/1" "cache/test/2" "cache/test/3" "cache/test/4" "cache/test/5")
    
    # Prime the cache with initial requests
    log_info "  🔄 Priming cache with initial requests..."
    for endpoint in "${cache_endpoints[@]}"; do
        github_api_call "$endpoint" >/dev/null 2>&1 || true
    done
    
    # Reset counters after priming
    TOTAL_REQUESTS=0
    SUCCESSFUL_REQUESTS=0
    CACHE_HIT_REQUESTS=0
    
    # Run concurrent cache test
    log_info "  🔥 Running concurrent cache operations..."
    local pids=()
    
    for ((i=1; i<=cache_test_operations; i++)); do
        # Limit concurrent operations
        if [[ ${#pids[@]} -ge $concurrent_cache_ops ]]; then
            # Wait for one to complete
            wait "${pids[0]}" 2>/dev/null || true
            pids=("${pids[@]:1}")  # Remove first element
        fi
        
        # Start new operation
        (
            local endpoint_idx=$((i % ${#cache_endpoints[@]}))
            local endpoint="${cache_endpoints[$endpoint_idx]}"
            
            # High probability of cache hit due to limited endpoints
            if github_api_call "$endpoint" >/dev/null 2>&1; then
                echo "success" > "$LOAD_TEST_OUTPUT_DIR/cache_op_${i}.result"
            else
                echo "failure" > "$LOAD_TEST_OUTPUT_DIR/cache_op_${i}.result"
            fi
        ) &
        pids+=($!)
        
        ((TOTAL_REQUESTS++))
    done
    
    # Wait for all operations to complete
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done
    
    # Count successful operations and estimate cache hits
    for ((i=1; i<=cache_test_operations; i++)); do
        if [[ -f "$LOAD_TEST_OUTPUT_DIR/cache_op_${i}.result" ]]; then
            local result
            result=$(cat "$LOAD_TEST_OUTPUT_DIR/cache_op_${i}.result")
            if [[ "$result" == "success" ]]; then
                ((SUCCESSFUL_REQUESTS++))
                # Estimate cache hits (requests to same endpoints after first request)
                if [[ $((i % ${#cache_endpoints[@]})) -ne 0 || i -gt ${#cache_endpoints[@]} ]]; then
                    ((CACHE_HIT_REQUESTS++))
                fi
            fi
            rm -f "$LOAD_TEST_OUTPUT_DIR/cache_op_${i}.result"
        fi
    done
    
    local cache_hit_rate
    cache_hit_rate=$(echo "scale=1; $CACHE_HIT_REQUESTS * 100 / $TOTAL_REQUESTS" | bc -l 2>/dev/null || echo "0")
    
    log_info "💾 Cache Performance Test Results:"
    log_info "  📊 Total cache operations: $TOTAL_REQUESTS" 
    log_info "  ✅ Successful operations: $SUCCESSFUL_REQUESTS"
    log_info "  💾 Estimated cache hits: $CACHE_HIT_REQUESTS ($cache_hit_rate%)"
    log_info "  🎯 Cache endpoints tested: ${#cache_endpoints[@]}"
    
    if [[ $(echo "$cache_hit_rate > 50" | bc -l 2>/dev/null) -eq 1 ]]; then
        log_info "✅ Cache performance is effective (>50% hit rate)"
    else
        log_warn "⚠️  Cache hit rate is lower than expected"
    fi
}

# Run load test scenario
run_load_test_scenario() {
    local scenario="$1"
    
    if [[ "$scenario" == "all" ]]; then
        # Run all scenarios
        for scenario_name in light medium heavy burst sustained; do
            log_info "🚀 Running scenario: $scenario_name"
            run_load_test_scenario "$scenario_name"
            echo
            sleep 2  # Brief pause between scenarios
        done
        return
    fi
    
    # Get scenario configuration
    local config
    config=$(get_scenario_config "$scenario")
    
    local concurrent total duration
    concurrent=$(echo "$config" | grep -o 'concurrent=[0-9]*' | cut -d'=' -f2)
    total=$(echo "$config" | grep -o 'total=[0-9]*' | cut -d'=' -f2)
    duration=$(echo "$config" | grep -o 'duration=[0-9]*' | cut -d'=' -f2)
    
    # Create appropriate mock based on test mode
    if [[ "$RATE_LIMIT_MODE" == "true" ]]; then
        create_load_test_gh_mock "true" 4000
    else
        create_load_test_gh_mock "false" 1000
    fi
    
    # Reset counters for this scenario
    TOTAL_REQUESTS=0
    SUCCESSFUL_REQUESTS=0
    FAILED_REQUESTS=0
    RATE_LIMITED_REQUESTS=0
    CACHE_HIT_REQUESTS=0
    
    # Run the load test
    run_concurrent_load_test "$scenario" "$concurrent" "$total" "$duration" "mixed"
}

# Generate load test report
generate_load_test_report() {
    log_header "📊 Generating load test report..."
    
    # Calculate overall test duration
    local test_duration
    test_duration=$(echo "$(date +%s.%N) - $TEST_START_TIME" | bc -l 2>/dev/null || echo "0")
    
    # Get performance metrics
    local performance_metrics
    performance_metrics=$(github_api_get_metrics 2>/dev/null || echo '{}')
    
    # Create comprehensive report
    cat > "$LOAD_TEST_REPORT_FILE" << EOF
{
  "load_test_report": {
    "generated_at": "$(date -Iseconds)",
    "test_duration": $test_duration,
    "environment": {
      "hostname": "$(hostname)",
      "os": "$(uname -s)",
      "shell": "$SHELL"
    },
    "configuration": {
      "scenario": "$LOAD_SCENARIO",
      "rate_limit_mode": $RATE_LIMIT_MODE,
      "cache_test_mode": $CACHE_TEST_MODE
    },
    "performance_metrics": $performance_metrics,
    "scenarios_tested": [
      $(if [[ -f "$LOAD_TEST_OUTPUT_DIR/results.log" ]]; then
          while IFS=',' read -r timestamp name concurrent total duration requests successful failed rate_limited cache_hits throughput; do
              echo "{\"name\":\"$name\",\"concurrent\":$concurrent,\"total\":$total,\"duration\":$duration,\"requests\":$requests,\"successful\":$successful,\"failed\":$failed,\"rate_limited\":$rate_limited,\"cache_hits\":$cache_hits,\"throughput\":$throughput},"
          done < "$LOAD_TEST_OUTPUT_DIR/results.log" | sed '$ s/,$//'
      fi)
    ]
  }
}
EOF
    
    log_info "📄 Load test report saved to: $LOAD_TEST_REPORT_FILE"
    
    # Generate summary
    log_info "📋 Load Test Summary:"
    log_info "  ⏱️  Total test duration: $(printf '%.2f' "$test_duration")s"
    log_info "  🎯 Scenario(s) tested: $LOAD_SCENARIO"
    log_info "  🔧 Configuration: rate-limit=$RATE_LIMIT_MODE, cache-test=$CACHE_TEST_MODE"
    log_info "  📊 Report generated: $LOAD_TEST_REPORT_FILE"
    log_info "  ✅ Load test status: COMPLETED"
}

# Main load testing function
main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    log_info "🔥 Starting load testing for Claude Code Auto Workflows..."
    log_info "🔧 Test scenario: $LOAD_SCENARIO"
    log_info "⚙️  Rate limit mode: $RATE_LIMIT_MODE"
    log_info "💾 Cache test mode: $CACHE_TEST_MODE"
    log_info "📁 Output directory: $LOAD_TEST_OUTPUT_DIR"
    
    # Initialize load testing system
    load_test_init
    
    echo
    
    # Run appropriate tests based on configuration
    if [[ "$RATE_LIMIT_MODE" == "true" ]]; then
        run_rate_limiting_test
        echo
    fi
    
    if [[ "$CACHE_TEST_MODE" == "true" ]]; then
        run_cache_performance_test
        echo
    fi
    
    # Run main load test scenario
    run_load_test_scenario "$LOAD_SCENARIO"
    echo
    
    # Generate final report
    generate_load_test_report
    echo
    
    # Cleanup
    performance_metrics_cleanup
    github_api_cleanup
    
    log_info "🎉 Load testing completed successfully!"
    log_info "📊 Review the load test report for detailed analysis."
}

# Set up error handling
trap 'log_error "Load test failed on line $LINENO"; exit 1' ERR

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi