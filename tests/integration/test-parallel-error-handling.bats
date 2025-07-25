#!/usr/bin/env bats
#
# Integration tests for parallel processing error handling and edge cases
# Tests cache behavior, signal handling, and graceful error recovery
# Addresses Issue #78 - missing integration test scenarios

# Setup and teardown
setup() {
    load '../helpers/test-helpers'
    setup_integration_test_environment
}

teardown() {
    cleanup_integration_processes
    teardown_test_environment
}

# All common functions are now in tests/helpers/test-integration-helpers.bash

# Integration Test 8: Cache integration with parallel processing under various conditions
@test "integration: cache integration with parallel processing" {
    export ENABLE_CACHE="true"
    export CACHE_TTL=300
    export RESOURCE_MONITOR_ENABLED="true"
    export MAX_PARALLEL_JOBS=8
    
    # First run to populate cache
    run ./scripts/validate-workflows.sh
    assert_success
    
    # Second run should use cache extensively
    local start_time end_time duration
    start_time=$(date +%s)
    
    run ./scripts/validate-workflows.sh
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    assert_success
    
    # Should be faster due to caching (use smaller timeout)
    assert [ "$duration" -lt 15 ]
    
    # Should mention cache usage
    assert_output --partial "cached" || assert_output --partial "cache"
    
    # Test performance analysis with caching
    run ./scripts/analyze-performance.sh
    assert_success
    
    assert_output --partial "cache" || assert_output --partial "Performance analysis completed"
}

# Integration Test 9: Signal handling during parallel processing with resource monitoring
@test "integration: signal handling during complex parallel operations" {
    export RESOURCE_MONITOR_ENABLED="true"
    export MAX_PARALLEL_JOBS=8
    
    # Start validation with resource monitoring in background
    ./scripts/validate-workflows.sh &
    local pid=$!
    
    # Let it start processing
    sleep 3
    
    # Send SIGTERM to test graceful shutdown
    kill -TERM $pid 2>/dev/null || true
    
    # Wait for shutdown
    wait $pid 2>/dev/null || true
    
    # Check that cleanup occurred properly
    local remaining_processes remaining_temp_files remaining_locks
    remaining_processes=$(pgrep -f "resource_monitor" | wc -l)
    remaining_temp_files=$(find /tmp -name "*validate*$$*" -o -name "*resource*$$*" 2>/dev/null | wc -l)
    remaining_locks=$(find /tmp -name "*.lock*" 2>/dev/null | wc -l)
    
    assert_equal "$remaining_processes" "0"
    assert_equal "$remaining_temp_files" "0"
    assert_equal "$remaining_locks" "0"
}