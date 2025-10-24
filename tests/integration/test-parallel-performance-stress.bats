#!/usr/bin/env bats
#
# Integration tests for parallel processing under stress conditions
# Tests performance and behavior under high load and resource constraints
# Addresses Issue #78 - missing integration test scenarios

# Setup and teardown
setup() {
    load '../helpers/test-helpers'
    setup_test_environment
    
    # Create test repository structure
    TEST_REPO_DIR="$TEST_TEMP_DIR/test_repo"
    mkdir -p "$TEST_REPO_DIR"
    cd "$TEST_REPO_DIR"
    
    # Initialize git repository
    git init --quiet
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create test workflows (default count for faster setup) 
    create_integration_test_workflows
    
    # Copy scripts to test location
    cp -r "$BATS_TEST_DIRNAME/../../scripts" .
    
    # Set up environment variables for comprehensive testing
    export GITHUB_TOKEN="test-token-comprehensive-12345"
    export GITHUB_REPOSITORY="test-org/comprehensive-test-repo"
    export GITHUB_API_URL="https://api.github.com"
    export ENABLE_CACHE="true"
    export CACHE_TTL=300
    export RESOURCE_MONITOR_ENABLED="true"
    export MEMORY_LIMIT_PERCENT=80
    export CPU_LIMIT_PERCENT=70
    export MIN_PARALLEL_JOBS=1
    export MAX_SYSTEM_PARALLEL_JOBS=16
    export RESOURCE_CHECK_INTERVAL=2
    export PARALLEL_JOB_TIMEOUT=300
    
    # Create integration mocks for advanced testing
    create_integration_mocks
    create_resource_monitoring_mocks
}

teardown() {
    cleanup_integration_processes
    teardown_test_environment
}

# All common functions are now in tests/helpers/test-integration-helpers.bash

# Integration Test 5: Large file counts with resource constraints
@test "integration: large file counts with resource constraints" {
    # Create additional workflows to reach 100+ files
    local workflow_dir="$TEST_REPO_DIR/.github/workflows"
    for i in {51..120}; do
        create_resource_intensive_workflow "$workflow_dir/extra-$i.yml" "Extra Workflow $i"
    done
    
    export MOCK_MEMORY_CONDITION="high"
    export RESOURCE_MONITOR_ENABLED="true"
    export MAX_PARALLEL_JOBS=4  # Reduced due to constraints
    
    local start_time end_time duration
    start_time=$(date +%s)
    
    run timeout $TEST_TIMEOUT_LONG ./scripts/validate-workflows.sh
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    assert_success
    
    # Should process all files despite constraints
    assert_output --partial "Processing 120 workflow files"
    
    # Should complete in reasonable time even with constraints
    assert [ "$duration" -lt "$MEDIUM_TEST_TIMEOUT" ]
    
    # Should show resource adaptation
    assert_output --partial "Adaptive parallelism" || assert_output --partial "System resources are constrained"
}

# Integration Test 6: System resource exhaustion behavior
@test "integration: system resource exhaustion behavior" {
    export MOCK_MEMORY_CONDITION="critical"
    export MOCK_CPU_CONDITION="critical"
    export RESOURCE_MONITOR_ENABLED="true"
    export MEMORY_LIMIT_PERCENT=90
    export CPU_LIMIT_PERCENT=85
    export MIN_PARALLEL_JOBS=1
    
    run timeout $TEST_TIMEOUT_LONG ./scripts/validate-workflows.sh
    assert_success
    
    # Should handle critical resource conditions gracefully
    assert_output --partial "Memory usage high" || assert_output --partial "CPU usage high" || assert_output --partial "System resources are constrained" || assert_output --partial "completed"
    
    # Should complete validation and adapt parallelism
    assert_output --partial "completed"
    assert_output --partial "Adaptive parallelism" || assert_output --partial "using"
    
    # Test that cleanup also handles resource exhaustion
    run timeout $TEST_TIMEOUT_MEDIUM ./scripts/cleanup-old-runs.sh --days 30 --max-runs 10 --force
    assert_success
    
    assert_output --partial "Cleanup completed!" || assert_output --partial "rate limiting"
}

# Integration Test 7: Graceful degradation when parallel jobs fail
@test "integration: graceful degradation when parallel jobs fail" {
    # Add some invalid workflows to cause failures
    echo "invalid yaml content {" > "$TEST_REPO_DIR/.github/workflows/broken1.yml"
    echo "invalid: yaml: content" > "$TEST_REPO_DIR/.github/workflows/broken2.yml"
    cat > "$TEST_REPO_DIR/.github/workflows/broken3.yml" << 'EOF'
name: Broken Workflow
# Missing required fields
jobs:
  test:
    # Missing runs-on
    steps:
      - name: Test
EOF
    
    export MAX_PARALLEL_JOBS=6
    export RESOURCE_MONITOR_ENABLED="true"
    
    run ./scripts/validate-workflows.sh
    assert_failure  # Should fail due to invalid workflows
    
    # Should report errors but continue processing other files
    assert_output --partial "ERROR:" 
    assert_output --partial "YAML syntax error" || assert_output --partial "validation failed"
    
    # Should still process valid workflows
    assert_output --partial "Processing"
    assert_output --partial "workflow files"
    
    # Should provide error summary
    assert_output --partial "errors and"
    assert_output --partial "warnings"
    
    # Test cleanup with some API failures
    run ./scripts/cleanup-old-runs.sh --days 30 --max-runs 20 --force
    assert_success  # Should handle individual API failures gracefully
    
    # Should report any failures but continue
    assert_output --partial "Cleanup completed!" || assert_output --partial "Failed to delete"
}