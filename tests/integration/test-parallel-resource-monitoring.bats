#!/usr/bin/env bats
#
# Integration tests for parallel processing with resource monitoring
# Tests parallel workflow validation under various resource conditions
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

# Integration Test 1: Complete parallel processing workflow with resource monitoring
@test "integration: complete workflow with resource monitoring" {
    export RESOURCE_MONITOR_ENABLED="true"
    export MAX_PARALLEL_JOBS=6
    
    local start_time end_time duration
    start_time=$(date +%s)
    
    run timeout $TEST_TIMEOUT_LONG ./scripts/validate-workflows.sh
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    assert_success
    
    # Verify resource monitoring was active
    assert_output --partial "Adaptive parallelism: using" 
    assert_output --partial "jobs (memory:" 
    assert_output --partial "CPU:"
    
    # Verify parallel processing occurred
    assert_output --partial "Validating workflows in parallel"
    assert_output --partial "Processing"
    assert_output --partial "workflow files"
    
    # Should complete efficiently with resource monitoring
    assert [ "$duration" -lt "$DEFAULT_TEST_TIMEOUT" ]
}

# Integration Test 2: Performance integration under memory pressure
@test "integration: performance under memory pressure scenarios" {
    export MOCK_MEMORY_CONDITION="high"
    export RESOURCE_MONITOR_ENABLED="true"
    export MEMORY_LIMIT_PERCENT=60
    export MAX_PARALLEL_JOBS=8
    
    run timeout $TEST_TIMEOUT_LONG ./scripts/validate-workflows.sh
    assert_success
    
    # Should detect high memory usage and adapt
    assert_output --partial "Memory usage high:" || assert_output --partial "System resources are constrained"
    
    # Should still complete successfully despite memory pressure
    assert_output --partial "Validation completed"
    
    # Run performance analysis under memory pressure
    run timeout $TEST_TIMEOUT_MEDIUM ./scripts/analyze-performance.sh
    assert_success
    
    assert_output --partial "Performance analysis completed"
}

# Integration Test 3: Performance integration under high CPU usage
@test "integration: performance under high CPU usage scenarios" {
    export MOCK_CPU_CONDITION="high"
    export RESOURCE_MONITOR_ENABLED="true"
    export CPU_LIMIT_PERCENT=50
    export MAX_PARALLEL_JOBS=8
    
    run timeout $TEST_TIMEOUT_LONG ./scripts/validate-workflows.sh
    assert_success
    
    # Should detect high CPU usage and adapt
    assert_output --partial "CPU usage high:" || assert_output --partial "System resources are constrained"
    
    # Should still complete successfully despite CPU pressure
    assert_output --partial "Validation completed"
    
    # Test cleanup under high CPU load
    run timeout $TEST_TIMEOUT_MEDIUM ./scripts/cleanup-old-runs.sh --days 30 --max-runs 20 --force
    assert_success
    
    assert_output --partial "Cleanup completed!"
}

# Integration Test 4: Optimal job calculation with various system conditions
@test "integration: optimal job calculation with various system conditions" {
    # Test normal conditions
    export MOCK_MEMORY_CONDITION="normal"
    export MOCK_CPU_CONDITION="normal"
    export RESOURCE_MONITOR_ENABLED="true"
    
    run ./scripts/validate-workflows.sh
    assert_success
    assert_output --partial "Adaptive parallelism: using"
    
    # Test low resource conditions
    export MOCK_MEMORY_CONDITION="low"
    export MOCK_CPU_CONDITION="low"
    
    run ./scripts/validate-workflows.sh
    assert_success
    assert_output --partial "Adaptive parallelism: using"
    
    # Test critical resource conditions
    export MOCK_MEMORY_CONDITION="critical"
    export MOCK_CPU_CONDITION="critical"
    
    run ./scripts/validate-workflows.sh
    assert_success
    assert_output --partial "Adaptive parallelism: using"
    # Should use fewer jobs under critical conditions
    assert_output --partial "System resources are constrained" || assert_output --partial "Memory usage high" || assert_output --partial "CPU usage high"
}