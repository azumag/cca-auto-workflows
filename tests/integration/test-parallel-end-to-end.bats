#!/usr/bin/env bats
#
# End-to-end integration tests for comprehensive parallel processing workflows
# Tests complete integration of all parallel processing features together
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

# Integration Test 10: End-to-end workflow testing all components together
@test "integration: end-to-end workflow with all parallel processing features" {
    export RESOURCE_MONITOR_ENABLED="true"
    export ENABLE_CACHE="true"
    export MAX_PARALLEL_JOBS=6
    export ENABLE_BENCHMARKS="true"
    
    local start_time end_time total_duration
    start_time=$(date +%s)
    
    # Step 1: Validate workflows with resource monitoring
    run timeout $TEST_TIMEOUT_LONG ./scripts/validate-workflows.sh
    assert_success
    assert_output --partial "Validation completed"
    assert_output --partial "Adaptive parallelism"
    
    # Step 2: Analyze performance with benchmarks
    run timeout $TEST_TIMEOUT_MEDIUM ./scripts/analyze-performance.sh --benchmarks
    assert_success
    assert_output --partial "Performance analysis completed"
    assert_output --partial "Running performance benchmarks"
    
    # Step 3: Cleanup old runs with rate limiting
    run timeout $TEST_TIMEOUT_MEDIUM ./scripts/cleanup-old-runs.sh --days 30 --max-runs 15 --force
    assert_success
    assert_output --partial "Cleanup completed!"
    
    end_time=$(date +%s)
    total_duration=$((end_time - start_time))
    
    # Entire workflow should complete in reasonable time
    assert [ "$total_duration" -lt "$LONG_TEST_TIMEOUT" ]
    
    # All components should work together without conflicts
    # No resource leaks should occur
    local remaining_files
    remaining_files=$(find /tmp -name "*$$*" 2>/dev/null | wc -l)
    assert_equal "$remaining_files" "0"
}