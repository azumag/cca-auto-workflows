#!/usr/bin/env bats
#
# Unit and integration tests for parallel processing in validate-workflows.sh
# Focuses on xargs parallel execution, file locking, and counter management

setup() {
    load 'helpers/test-helpers'
    setup_script_test
    
    # Create comprehensive workflow set for parallel testing
    create_mock_workflows
    
    # Set parallel processing environment
    export MAX_PARALLEL_JOBS=4
    export ENABLE_CACHE="true"
    export CACHE_TTL=300
    export CACHE_DIR="$TEST_TEMP_DIR/validation_cache"
    
    # Create mocks optimized for validation testing
    create_validation_mocks
}

teardown() {
    cleanup_validation_processes
    teardown_script_test
}

create_validation_mocks() {
    # Enhanced yq mock for parallel validation testing
    cat > "$TEST_TEMP_DIR/bin/yq" << 'EOF'
#!/bin/bash
# yq mock with specific validation responses

# Add small delay to simulate processing time
sleep 0.05

file_arg=""
for arg in "$@"; do
    if [[ -f "$arg" ]]; then
        file_arg="$arg"
        break
    fi
done

case "$1 $2" in
    "eval .")
        if [[ "$file_arg" == *"invalid"* ]]; then
            echo "yaml: line 3: mapping values are not allowed" >&2
            exit 1
        elif [[ "$file_arg" == *"problematic"* ]]; then
            echo "name: Problematic Workflow"
            echo "on: push"
            echo "jobs: {test: {runs-on: ubuntu-latest}}"
        else
            echo "name: Valid Workflow"
            echo "on: [push, pull_request]"
            echo "jobs: {test: {runs-on: ubuntu-latest, steps: []}}"
        fi
        exit 0
        ;;
    "eval .name")
        if [[ "$file_arg" == *"no-name"* ]]; then
            echo "null"
            exit 1
        fi
        echo "Test Workflow"
        ;;
    "eval .on")
        if [[ "$file_arg" == *"no-on"* ]]; then
            echo "null"
            exit 1
        fi
        echo "push"
        ;;
    "eval .jobs")
        if [[ "$file_arg" == *"no-jobs"* ]]; then
            echo "null"
            exit 1
        fi
        echo "{test: {runs-on: ubuntu-latest}}"
        ;;
    *)
        echo "mock yq output"
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/yq"
    
    # Create python3 mock for fallback validation
    cat > "$TEST_TEMP_DIR/bin/python3" << 'EOF'
#!/bin/bash
# python3 mock for YAML validation

sleep 0.02

if [[ "$*" == *"invalid"* ]]; then
    echo "yaml.scanner.ScannerError: while scanning" >&2
    exit 1
fi
exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/bin/python3"
}

cleanup_validation_processes() {
    # Clean up validation-specific temporary files
    rm -f /tmp/validate_workflows_$$.lock.* 2>/dev/null || true
    rm -f /tmp/validate_errors_$$.* 2>/dev/null || true
    rm -f /tmp/validate_warnings_$$.* 2>/dev/null || true
    rm -f /tmp/validate_temp_files_$$ 2>/dev/null || true
}

@test "validate-workflows parallel: basic parallel execution works" {
    run "$BATS_TEST_DIRNAME/../scripts/validate-workflows.sh"
    assert_success
    
    assert_output --partial "Validating workflows in parallel using xargs"
    assert_output --partial "Processing"
    assert_output --partial "workflow files with up to $MAX_PARALLEL_JOBS parallel jobs"
}

@test "validate-workflows parallel: processes multiple files concurrently" {
    # Create many workflows to ensure parallel processing
    local workflow_dir="$TEST_TEMP_DIR/repo/.github/workflows"
    for i in {6..15}; do
        create_basic_workflow "$workflow_dir/extra-$i.yml" "Extra Workflow $i"
    done
    
    local start_time end_time duration
    start_time=$(date +%s)
    
    run timeout 20 "$BATS_TEST_DIRNAME/../scripts/validate-workflows.sh"
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    assert_success
    assert_output --partial "Processing"
    assert_output --partial "workflow files"
    
    # Should complete in reasonable time despite having many files
    assert [ "$duration" -lt 15 ]
}

@test "validate-workflows parallel: handles file locking correctly" {
    # Test that concurrent validation doesn't cause race conditions
    export MAX_PARALLEL_JOBS=8  # High parallelism to stress test
    
    run "$BATS_TEST_DIRNAME/../scripts/validate-workflows.sh"
    assert_success
    
    # Should maintain accurate counters
    assert_output --partial "Validation completed with"
    assert_output --partial "errors and"
    assert_output --partial "warnings"
    
    # Extract error and warning counts
    local error_count warning_count
    error_count=$(echo "$output" | grep -o '[0-9]\+ errors' | head -1 | cut -d' ' -f1 || echo "0")
    warning_count=$(echo "$output" | grep -o '[0-9]\+ warnings' | head -1 | cut -d' ' -f1 || echo "0")
    
    # Counts should be valid integers (not corrupted by race conditions)
    [[ "$error_count" =~ ^[0-9]+$ ]]
    [[ "$warning_count" =~ ^[0-9]+$ ]]
    
    # Should be reasonable counts (not negative or impossibly high)
    assert [ "$error_count" -ge 0 ]
    assert [ "$warning_count" -ge 0 ]
    assert [ "$error_count" -lt 100 ]  # Sanity check
    assert [ "$warning_count" -lt 100 ]  # Sanity check
}

@test "validate-workflows parallel: error propagation works correctly" {
    # Add invalid workflow to test error handling
    cat > "$TEST_TEMP_DIR/repo/.github/workflows/invalid.yml" << 'EOF'
name: Invalid Workflow
on: push
jobs:
  test:
    invalid_yaml: {
EOF
    
    run "$BATS_TEST_DIRNAME/../scripts/validate-workflows.sh"
    assert_failure
    
    # Should detect and report errors from parallel workers
    assert_output --partial "ERROR:" 
    assert_output --partial "YAML syntax error" || assert_output --partial "invalid"
}

@test "validate-workflows parallel: cache integration works with parallel processing" {
    # Run validation twice to test caching with parallel processing
    "$BATS_TEST_DIRNAME/../scripts/validate-workflows.sh" >/dev/null 2>&1
    
    local start_time end_time duration
    start_time=$(date +%s)
    
    run "$BATS_TEST_DIRNAME/../scripts/validate-workflows.sh"
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    assert_success
    
    # Second run should be faster due to caching
    assert [ "$duration" -lt 8 ]
    
    # Should indicate cache usage
    assert_output --partial "cached" || assert_output --partial "cache"
}

@test "validate-workflows parallel: cleanup works correctly after parallel execution" {
    run "$BATS_TEST_DIRNAME/../scripts/validate-workflows.sh"
    assert_success
    
    # Check that temporary files are cleaned up
    local remaining_temp_files
    remaining_temp_files=$(find /tmp -name "validate_*_$$.*" 2>/dev/null | wc -l)
    assert_equal "$remaining_temp_files" "0"
    
    # Check that lock files are cleaned up
    local remaining_lock_files
    remaining_lock_files=$(find /tmp -name "validate_workflows_*.lock.*" 2>/dev/null | wc -l)
    assert_equal "$remaining_lock_files" "0"
}

@test "validate-workflows parallel: signal handling during parallel operations" {
    # Start validation in background
    "$BATS_TEST_DIRNAME/../scripts/validate-workflows.sh" &
    local pid=$!
    
    # Let it start processing
    sleep 2
    
    # Send SIGTERM
    kill -TERM $pid 2>/dev/null || true
    
    # Wait for shutdown
    wait $pid 2>/dev/null || true
    local exit_code=$?
    
    # Should not leave temp files behind
    local remaining_files
    remaining_files=$(find /tmp -name "*validate*$$*" 2>/dev/null | wc -l)
    assert_equal "$remaining_files" "0"
}

@test "validate-workflows parallel: handles workflow directory edge cases" {
    # Test with no workflow directory
    rm -rf "$TEST_TEMP_DIR/repo/.github"
    
    run "$BATS_TEST_DIRNAME/../scripts/validate-workflows.sh"
    assert_failure
    
    assert_output --partial "Workflow directory not found"
}

@test "validate-workflows parallel: handles empty workflow directory" {
    # Empty the workflow directory
    rm -f "$TEST_TEMP_DIR/repo/.github/workflows"/*.yml
    rm -f "$TEST_TEMP_DIR/repo/.github/workflows"/*.yaml
    
    run "$BATS_TEST_DIRNAME/../scripts/validate-workflows.sh"
    assert_success
    
    assert_output --partial "No workflow files found"
}

@test "validate-workflows parallel: validates export of functions for xargs" {
    # This test ensures that all necessary functions are exported for parallel execution
    run "$BATS_TEST_DIRNAME/../scripts/validate-workflows.sh"
    assert_success
    
    # Should not have function-related errors
    refute_output --partial "command not found"
    refute_output --partial "function not found"
    refute_output --partial "undefined function"
}

@test "validate-workflows parallel: performance with different parallel job counts" {
    local times=()
    
    # Test with different parallel job counts
    for jobs in 1 2 4 8; do
        export MAX_PARALLEL_JOBS=$jobs
        
        local start_time=$(date +%s)
        "$BATS_TEST_DIRNAME/../scripts/validate-workflows.sh" >/dev/null 2>&1
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        times+=("$duration")
    done
    
    # Generally, more parallel jobs should not be significantly slower
    # (allowing for some overhead and test environment variability)
    local time_1=${times[0]}
    local time_8=${times[3]}
    
    # 8 parallel jobs should not take more than 3x the time of 1 job
    assert [ "$time_8" -le $((time_1 * 3)) ]
}

# Helper function for creating basic workflow
create_basic_workflow() {
    cat > "$1" << EOF
name: $2
on: [push, pull_request]
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Test
        run: echo "Testing"
        if: github.event_name == 'push'
EOF
}