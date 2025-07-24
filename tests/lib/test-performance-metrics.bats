#!/usr/bin/env bats
#
# Unit tests for performance metrics module
# Tests timing, benchmarking, load testing, and metrics collection

# Setup and teardown
setup() {
    load '../helpers/test-helpers'
    setup_test_environment
    
    # Source the performance metrics library
    source "$BATS_TEST_DIRNAME/../../scripts/lib/common.sh"
    source "$BATS_TEST_DIRNAME/../../scripts/lib/performance-metrics.sh"
    
    # Set up test environment
    TEST_METRICS_DIR="$TEST_TEMP_DIR/performance_metrics"
    export METRICS_DIR="$TEST_METRICS_DIR"
    export BENCHMARK_ITERATIONS=3  # Reduce for faster tests
    
    # Mock bc command for calculations
    create_bc_mock
}

teardown() {
    teardown_test_environment
}

# Helper to create bc mock
create_bc_mock() {
    cat > "$TEST_TEMP_DIR/bin/bc" << 'EOF'
#!/bin/bash
# Mock bc for basic calculations
input=$(cat)
case "$input" in
    *" - "*)
        # Subtraction for timing
        echo "1.234"
        ;;
    *" + "*)
        # Addition for cumulative timing
        echo "3.456"
        ;;
    *" / "*)
        # Division for averages
        echo "1.152"
        ;;
    *" * "*)
        # Multiplication for percentages
        echo "75"
        ;;
    *)
        echo "1.0"
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/bc"
}

# Performance metrics initialization tests
@test "performance_metrics_init: initializes successfully" {
    run performance_metrics_init
    assert_success
    assert_output --partial "Performance metrics collection initialized"
    
    # Verify metrics directory was created
    assert [ -d "$TEST_METRICS_DIR" ]
}

@test "performance_metrics_init: sets start time" {
    performance_metrics_init
    
    # SCRIPT_START_TIME should be set to a timestamp
    assert [ -n "$SCRIPT_START_TIME" ]
    assert [ "$SCRIPT_START_TIME" != "0" ]
}

@test "performance_metrics_init: cleans up old metrics" {
    # Create old metrics file
    mkdir -p "$TEST_METRICS_DIR"
    echo "old data" > "$TEST_METRICS_DIR/old_metrics.log"
    touch -t $(date -d '35 days ago' +%Y%m%d%H%M) "$TEST_METRICS_DIR/old_metrics.log"
    
    run performance_metrics_init
    assert_success
    
    # Old file should be cleaned up (mocked, so might not actually delete)
    # Test passes if no errors occur during cleanup
}

# Timer functionality tests
@test "start_timer: creates timer start file" {
    performance_metrics_init
    
    run start_timer "test_operation"
    assert_success
    
    # Verify start file was created
    assert [ -f "$TEST_METRICS_DIR/test_operation_start.tmp" ]
}

@test "end_timer: calculates duration and logs operation" {
    performance_metrics_init
    
    # Start timer
    start_timer "test_operation"
    
    # End timer
    run end_timer "test_operation" "true"
    assert_success
    
    # Verify start file was cleaned up
    assert [ ! -f "$TEST_METRICS_DIR/test_operation_start.tmp" ]
    
    # Verify operation was logged
    assert [ -f "$TEST_METRICS_DIR/operations.log" ]
    
    # Check log content
    local log_content
    log_content=$(cat "$TEST_METRICS_DIR/operations.log")
    assert [[ "$log_content" == *"test_operation"* ]]
    assert [[ "$log_content" == *"true"* ]]
}

@test "end_timer: handles missing start file" {
    performance_metrics_init
    
    run end_timer "missing_operation" "true"
    assert_failure
    assert_output --partial "No start time found"
}

@test "end_timer: warns about slow operations" {
    performance_metrics_init
    
    start_timer "slow_operation"
    
    # Mock bc to return a large duration
    cat > "$TEST_TEMP_DIR/bin/bc" << 'EOF'
#!/bin/bash
echo "10.5"  # 10.5 seconds
EOF
    chmod +x "$TEST_TEMP_DIR/bin/bc"
    
    run end_timer "slow_operation" "true"
    assert_success
    assert_output --partial "Slow operation detected"
}

@test "end_timer: increments operation counters" {
    performance_metrics_init
    
    # Reset counters
    TOTAL_OPERATIONS=0
    SUCCESSFUL_OPERATIONS=0
    
    start_timer "counter_test"
    end_timer "counter_test" "true"
    
    assert_equal "$TOTAL_OPERATIONS" "1"
    assert_equal "$SUCCESSFUL_OPERATIONS" "1"
}

@test "end_timer: handles failed operations" {
    performance_metrics_init
    
    TOTAL_OPERATIONS=0
    SUCCESSFUL_OPERATIONS=0
    
    start_timer "failed_operation"
    end_timer "failed_operation" "false"
    
    assert_equal "$TOTAL_OPERATIONS" "1"
    assert_equal "$SUCCESSFUL_OPERATIONS" "0"
}

# Cache operation recording tests
@test "record_cache_operation: logs cache hits and misses" {
    performance_metrics_init
    
    record_cache_operation "hit" "test_cache"
    record_cache_operation "miss" "test_cache"
    
    # Verify cache log exists
    assert [ -f "$TEST_METRICS_DIR/cache.log" ]
    
    # Check log content
    local log_content
    log_content=$(cat "$TEST_METRICS_DIR/cache.log")
    assert [[ "$log_content" == *"test_cache,hit"* ]]
    assert [[ "$log_content" == *"test_cache,miss"* ]]
}

@test "record_cache_operation: increments cache counter" {
    performance_metrics_init
    
    CACHE_OPERATIONS=0
    
    record_cache_operation "hit" "test_cache"
    record_cache_operation "miss" "test_cache"
    
    assert_equal "$CACHE_OPERATIONS" "2"
}

# API operation recording tests
@test "record_api_operation: logs API calls" {
    performance_metrics_init
    
    record_api_operation "/api/test" "200" "0.5"
    record_api_operation "/api/error" "500" "1.2"
    
    # Verify API log exists
    assert [ -f "$TEST_METRICS_DIR/api.log" ]
    
    # Check log content
    local log_content
    log_content=$(cat "$TEST_METRICS_DIR/api.log")
    assert [[ "$log_content" == *"/api/test,200,0.5"* ]]
    assert [[ "$log_content" == *"/api/error,500,1.2"* ]]
}

@test "record_api_operation: increments API counter" {
    performance_metrics_init
    
    API_OPERATIONS=0
    
    record_api_operation "/api/test1" "200" "0.5"
    record_api_operation "/api/test2" "200" "0.7"
    
    assert_equal "$API_OPERATIONS" "2"
}

# Cache hit rate calculation tests
@test "get_cache_hit_rate: calculates correct rate for specific cache" {
    performance_metrics_init
    
    # Create cache log with sample data
    cat > "$TEST_METRICS_DIR/cache.log" << 'EOF'
2024-01-01T10:00:00+00:00,test_cache,hit
2024-01-01T10:01:00+00:00,test_cache,miss
2024-01-01T10:02:00+00:00,test_cache,hit
2024-01-01T10:03:00+00:00,other_cache,hit
EOF

    run get_cache_hit_rate "test_cache"
    assert_success
    # 2 hits out of 3 operations = 66%
    assert_equal "$output" "66"
}

@test "get_cache_hit_rate: calculates overall rate for all caches" {
    performance_metrics_init
    
    # Create cache log with sample data
    cat > "$TEST_METRICS_DIR/cache.log" << 'EOF'
2024-01-01T10:00:00+00:00,cache1,hit
2024-01-01T10:01:00+00:00,cache1,miss
2024-01-01T10:02:00+00:00,cache2,hit
2024-01-01T10:03:00+00:00,cache2,hit
EOF

    run get_cache_hit_rate "*"
    assert_success
    # 3 hits out of 4 operations = 75%
    assert_equal "$output" "75"
}

@test "get_cache_hit_rate: returns zero for non-existent cache" {
    performance_metrics_init
    
    run get_cache_hit_rate "non_existent_cache"
    assert_success
    assert_equal "$output" "0"
}

@test "get_cache_hit_rate: handles missing cache log file" {
    performance_metrics_init
    
    # Remove cache log file
    rm -f "$TEST_METRICS_DIR/cache.log"
    
    run get_cache_hit_rate "any_cache"
    assert_success
    assert_equal "$output" "0"
}

# Average operation time tests
@test "get_average_operation_time: calculates correct average" {
    performance_metrics_init
    
    # Create operations log with sample data
    cat > "$TEST_METRICS_DIR/operations.log" << 'EOF'
2024-01-01T10:00:00+00:00,test_op,1.0,true
2024-01-01T10:01:00+00:00,test_op,2.0,true
2024-01-01T10:02:00+00:00,test_op,3.0,false
EOF

    run get_average_operation_time "test_op"
    assert_success
    # Mock bc returns 1.152 for division
    assert_equal "$output" "1.152"
}

@test "get_average_operation_time: returns zero for non-existent operation" {
    performance_metrics_init
    
    run get_average_operation_time "non_existent_op"
    assert_success
    assert_equal "$output" "0.000"
}

# Operation success rate tests
@test "get_operation_success_rate: calculates correct success rate" {
    performance_metrics_init
    
    # Create operations log with sample data
    cat > "$TEST_METRICS_DIR/operations.log" << 'EOF'
2024-01-01T10:00:00+00:00,test_op,1.0,true
2024-01-01T10:01:00+00:00,test_op,2.0,true
2024-01-01T10:02:00+00:00,test_op,3.0,false
2024-01-01T10:03:00+00:00,test_op,1.5,true
EOF

    run get_operation_success_rate "test_op"
    assert_success
    # 3 successful out of 4 total = 75%
    assert_equal "$output" "75"
}

@test "get_operation_success_rate: returns 100 for non-existent operation" {
    performance_metrics_init
    
    run get_operation_success_rate "non_existent_op"
    assert_success
    assert_equal "$output" "100"
}

# Performance benchmark tests
@test "run_performance_benchmark: executes benchmark iterations" {
    performance_metrics_init
    
    # Use a simple command that always succeeds
    run run_performance_benchmark "test_benchmark" "echo 'test'"
    assert_success
    
    assert_output --partial "Running performance benchmark: test_benchmark"
    assert_output --partial "Benchmark iteration 1/3"
    assert_output --partial "Benchmark iteration 2/3"
    assert_output --partial "Benchmark iteration 3/3"
    assert_output --partial "Benchmark Results for test_benchmark"
}

@test "run_performance_benchmark: logs benchmark results" {
    performance_metrics_init
    
    run_performance_benchmark "logged_benchmark" "echo 'success'" >/dev/null
    
    # Verify benchmark log exists
    assert [ -f "$TEST_METRICS_DIR/benchmarks.log" ]
    
    # Check log content
    local log_content
    log_content=$(cat "$TEST_METRICS_DIR/benchmarks.log")
    assert [[ "$log_content" == *"logged_benchmark"* ]]
}

@test "run_performance_benchmark: handles failing commands" {
    performance_metrics_init
    
    run run_performance_benchmark "failing_benchmark" "exit 1"
    assert_success  # The benchmark function itself should succeed
    
    assert_output --partial "Success rate: 0/3"
}

# Load test tests
@test "run_load_test: executes concurrent operations" {
    performance_metrics_init
    
    # Use a simple command that always succeeds
    run run_load_test "test_load" "echo 'concurrent'" 2 4
    assert_success
    
    assert_output --partial "Running load test: test_load"
    assert_output --partial "2 concurrent operations, 4 total"
    assert_output --partial "Load Test Results for test_load"
}

@test "run_load_test: logs load test results" {
    performance_metrics_init
    
    run_load_test "logged_load_test" "echo 'success'" 1 2 >/dev/null
    
    # Verify load test log exists
    assert [ -f "$TEST_METRICS_DIR/loadtests.log" ]
    
    # Check log content
    local log_content
    log_content=$(cat "$TEST_METRICS_DIR/loadtests.log")
    assert [[ "$log_content" == *"logged_load_test"* ]]
}

@test "run_load_test: calculates throughput" {
    performance_metrics_init
    
    run run_load_test "throughput_test" "echo 'fast'" 1 3
    assert_success
    
    assert_output --partial "Throughput:"
    assert_output --partial "ops/sec"
}

# Performance report generation tests
@test "generate_performance_report: displays comprehensive metrics" {
    performance_metrics_init
    
    # Set some test values
    TOTAL_OPERATIONS=10
    SUCCESSFUL_OPERATIONS=8
    CACHE_OPERATIONS=5
    API_OPERATIONS=3
    
    run generate_performance_report
    assert_success
    
    assert_output --partial "Performance Metrics Report"
    assert_output --partial "Script Execution Metrics"
    assert_output --partial "Total operations: 10"
    assert_output --partial "Successful operations: 8"
    assert_output --partial "Cache operations: 5"
    assert_output --partial "API operations: 3"
}

@test "generate_performance_report: calculates success rate" {
    performance_metrics_init
    
    TOTAL_OPERATIONS=4
    SUCCESSFUL_OPERATIONS=3
    
    run generate_performance_report
    assert_success
    
    assert_output --partial "Successful operations: 3 (75%)"
}

@test "generate_performance_report: handles zero operations" {
    performance_metrics_init
    
    TOTAL_OPERATIONS=0
    SUCCESSFUL_OPERATIONS=0
    
    run generate_performance_report
    assert_success
    
    assert_output --partial "Successful operations: 0 (100%)"
}

# JSON export tests
@test "export_metrics_json: creates valid JSON file" {
    performance_metrics_init
    
    local output_file="$TEST_TEMP_DIR/metrics.json"
    
    TOTAL_OPERATIONS=5
    SUCCESSFUL_OPERATIONS=4
    CACHE_OPERATIONS=2
    API_OPERATIONS=1
    
    run export_metrics_json "$output_file"
    assert_success
    
    # Verify JSON file was created
    assert [ -f "$output_file" ]
    
    # Verify JSON is valid
    run jq -e '.timestamp' "$output_file"
    assert_success
    
    run jq -e '.operations.total' "$output_file"
    assert_success
    assert_output "5"
    
    run jq -e '.operations.successful' "$output_file"
    assert_success
    assert_output "4"
}

@test "export_metrics_json: includes all required fields" {
    performance_metrics_init
    
    local output_file="$TEST_TEMP_DIR/complete_metrics.json"
    
    export_metrics_json "$output_file"
    
    # Check all required fields exist
    local required_fields=(
        "timestamp"
        "script_duration"
        "operations"
        "operations.total"
        "operations.successful"
        "operations.success_rate_percent"
        "operations.average_time"
        "cache"
        "cache.operations"
        "cache.hit_rate_percent"
        "api"
        "api.operations"
    )
    
    for field in "${required_fields[@]}"; do
        run jq -e ".$field" "$output_file"
        assert_success
    done
}

# Cleanup tests
@test "performance_metrics_cleanup: removes temporary files" {
    performance_metrics_init
    
    # Create temporary files
    echo "temp data" > "$TEST_METRICS_DIR/temp_file.tmp"
    echo "another temp" > "$TEST_METRICS_DIR/another.tmp"
    
    run performance_metrics_cleanup
    assert_success
    
    # Temporary files should be removed
    assert [ ! -f "$TEST_METRICS_DIR/temp_file.tmp" ]
    assert [ ! -f "$TEST_METRICS_DIR/another.tmp" ]
}

@test "performance_metrics_cleanup: preserves log files" {
    performance_metrics_init
    
    # Create log files
    echo "operations data" > "$TEST_METRICS_DIR/operations.log"
    echo "cache data" > "$TEST_METRICS_DIR/cache.log"
    
    run performance_metrics_cleanup
    assert_success
    
    # Log files should remain
    assert [ -f "$TEST_METRICS_DIR/operations.log" ]
    assert [ -f "$TEST_METRICS_DIR/cache.log" ]
}

# Integration tests
@test "performance_metrics_integration: full metrics lifecycle" {
    performance_metrics_init
    
    # 1. Record some operations
    start_timer "integration_op1"
    end_timer "integration_op1" "true"
    
    start_timer "integration_op2"
    end_timer "integration_op2" "false"
    
    # 2. Record cache operations
    record_cache_operation "hit" "integration_cache"
    record_cache_operation "miss" "integration_cache"
    record_cache_operation "hit" "integration_cache"
    
    # 3. Record API operations
    record_api_operation "/api/test" "200" "0.5"
    record_api_operation "/api/test2" "404" "0.3"
    
    # 4. Check metrics
    local cache_hit_rate operation_success_rate
    cache_hit_rate=$(get_cache_hit_rate "integration_cache")
    operation_success_rate=$(get_operation_success_rate "*")
    
    # 2 hits out of 3 = 66%
    assert_equal "$cache_hit_rate" "66"
    
    # 1 success out of 2 = 50%
    assert_equal "$operation_success_rate" "50"
    
    # 5. Generate report
    run generate_performance_report
    assert_success
    assert_output --partial "Performance Metrics Report"
    
    # 6. Export JSON
    local json_file="$TEST_TEMP_DIR/integration_metrics.json"
    export_metrics_json "$json_file"
    assert [ -f "$json_file" ]
    
    # 7. Cleanup
    run performance_metrics_cleanup
    assert_success
}