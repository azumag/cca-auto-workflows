#!/usr/bin/env bats
#
# Integration tests for parallel processing functionality across all scripts
# Tests end-to-end parallel processing with race conditions, file locking, and error handling

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
    
    # Create comprehensive workflow structure for parallel testing
    create_parallel_test_workflows
    
    # Copy scripts to test location
    cp -r "$BATS_TEST_DIRNAME/../../scripts" .
    
    # Set up environment variables for parallel processing
    export GITHUB_TOKEN="test-token-parallel-12345"
    export GITHUB_REPOSITORY="test-org/parallel-test-repo"
    export GITHUB_API_URL="https://api.github.com"
    export MAX_PARALLEL_JOBS=4
    export ENABLE_CACHE="true"
    export CACHE_TTL=300
    export RATE_LIMIT_REQUESTS_PER_MINUTE=60
    export BURST_SIZE=10
    export RATE_LIMIT_DELAY=1
    
    # Create comprehensive mocks for parallel testing
    create_parallel_gh_mock
    create_parallel_jq_mock
    create_parallel_utility_mocks
}

teardown() {
    # Clean up any remaining parallel processes
    cleanup_parallel_processes
    teardown_test_environment
}

# Create comprehensive workflows for parallel testing
create_parallel_test_workflows() {
    local workflow_dir="$TEST_REPO_DIR/.github/workflows"
    mkdir -p "$workflow_dir"
    
    # Create 20 test workflows to ensure parallel processing is exercised
    for i in {1..20}; do
        local workflow_type=$((i % 4))
        case $workflow_type in
            0) create_basic_workflow "$workflow_dir/basic-$i.yml" "Basic Workflow $i" ;;
            1) create_matrix_workflow "$workflow_dir/matrix-$i.yml" "Matrix Workflow $i" ;;
            2) create_complex_workflow "$workflow_dir/complex-$i.yml" "Complex Workflow $i" ;;
            3) create_problematic_workflow "$workflow_dir/problematic-$i.yml" "Problematic Workflow $i" ;;
        esac
    done
    
    # Create additional workflows with specific issues for testing
    create_invalid_workflow "$workflow_dir/invalid.yml"
    create_security_issue_workflow "$workflow_dir/security-issues.yml"
}

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
        run: echo "Testing $2"
        if: github.event_name == 'push'
EOF
}

create_matrix_workflow() {
    cat > "$1" << EOF
name: $2
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        version: [16, 18, 20]
    steps:
      - uses: actions/checkout@v4
      - name: Test with version \${{ matrix.version }}
        run: echo "Testing with version \${{ matrix.version }}"
EOF
}

create_complex_workflow() {
    cat > "$1" << EOF
name: $2
on: [push, pull_request, schedule]
permissions:
  contents: read
  issues: write
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/cache@v3
        with:
          path: node_modules
          key: \${{ runner.os }}-node-\${{ hashFiles('package-lock.json') }}
      - name: Lint
        run: npm run lint
  test:
    runs-on: ubuntu-latest
    needs: lint
    steps:
      - uses: actions/checkout@v4
      - name: Test
        run: npm test
        if: always()
  deploy:
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Deploy
        run: echo "Deploying $2"
EOF
}

create_problematic_workflow() {
    cat > "$1" << EOF
name: $2
on: push
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@main
      - name: Build without caching
        run: |
          npm install
          npm run build
      - name: Test with potential secret
        run: echo "token=hardcoded_value_123456789"
EOF
}

create_invalid_workflow() {
    cat > "$1" << 'EOF'
name: Invalid Workflow
# Missing 'on' field intentionally
jobs:
  invalid:
    # Missing 'runs-on' field intentionally
    steps:
      - name: Invalid step
        run: echo "invalid"
EOF
}

create_security_issue_workflow() {
    cat > "$1" << 'EOF'
name: Security Issues Workflow
on: push
jobs:
  security-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@latest
      - name: Hardcoded secret
        run: echo "password='secret123456789'"
        env:
          API_KEY: hardcoded_api_key_value
EOF
}

# Create GitHub CLI mock optimized for parallel testing
create_parallel_gh_mock() {
    cat > "$TEST_TEMP_DIR/bin/gh" << 'EOF'
#!/bin/bash
# GitHub CLI mock for parallel processing tests

# Add small delay to simulate API calls and test parallel behavior
sleep 0.1

case "$1 $2" in
    "auth status")
        echo "✓ Logged in to github.com as test-user"
        exit 0
        ;;
    "repo view")
        echo "test-org/parallel-test-repo"
        exit 0
        ;;
    "api rate_limit")
        cat << 'RATE_LIMIT_EOF'
{
  "resources": {
    "core": {
      "limit": 5000,
      "used": 250,
      "remaining": 4750,
      "reset": 1640995200
    }
  },
  "rate": {
    "limit": 5000,
    "used": 250,
    "remaining": 4750,
    "reset": 1640995200
  }
}
RATE_LIMIT_EOF
        exit 0
        ;;
    "run list"*)
        # Generate dynamic response based on arguments
        if [[ "$*" == *"--limit 1000"* ]]; then
            # Generate 50 mock runs for cleanup testing
            echo "["
            for ((i=1; i<=50; i++)); do
                local created_date="2024-01-$(printf "%02d" $((i % 28 + 1)))T10:00:00Z"
                echo "  {"
                echo "    \"name\": \"Test Workflow $i\","
                echo "    \"status\": \"completed\","
                echo "    \"conclusion\": \"success\","
                echo "    \"createdAt\": \"$created_date\","
                echo "    \"updatedAt\": \"$created_date\","
                echo "    \"databaseId\": $((12340 + i))"
                if [[ $i -lt 50 ]]; then
                    echo "  },"
                else
                    echo "  }"
                fi
            done
            echo "]"
        else
            echo "[]"
        fi
        exit 0
        ;;
    "run delete"*)
        # Extract run ID and simulate deletion
        local run_id=$(echo "$*" | grep -o '[0-9]\+' | head -1)
        echo "✓ Deleted run $run_id"
        exit 0
        ;;
    "workflow list")
        echo '[{"id":1,"name":"Test Workflow","state":"active"}]'
        exit 0
        ;;
    *)
        echo "Mock gh: Command '$*' executed"
        exit 0
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/gh"
}

# Create jq mock for parallel processing
create_parallel_jq_mock() {
    cat > "$TEST_TEMP_DIR/bin/jq" << 'EOF'
#!/bin/bash
# jq mock for parallel processing tests

# Add small delay to simulate processing
sleep 0.05

input=$(cat)

case "$*" in
    "-r" ".rate.remaining")
        echo "4750"
        ;;
    "-r" ".rate.limit")
        echo "5000"
        ;;
    "-r" ".rate.used")
        echo "250"
        ;;
    ". | length")
        # Count based on input
        if [[ "$input" == *"databaseId"* ]]; then
            echo "50"
        else
            echo "20"
        fi
        ;;
    "length")
        echo "50"
        ;;
    *"group_by(.name)"*)
        # Mock workflow runtime analysis for parallel performance testing
        echo "  📊 Test Workflow 1: 5min avg, 100% success rate (2 runs)"
        echo "  📊 Test Workflow 2: 3min avg, 100% success rate (3 runs)"
        echo "  📊 Test Workflow 3: 7min avg, 90% success rate (5 runs)"
        ;;
    *"map(select"*)
        # Return filtered results
        echo "12345"
        echo "12346"
        echo "12347"
        ;;
    *)
        echo "mock_jq_output"
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/jq"
}

# Create utility mocks for parallel testing
create_parallel_utility_mocks() {
    # Create yq mock that handles parallel validation
    cat > "$TEST_TEMP_DIR/bin/yq" << 'EOF'
#!/bin/bash
# yq mock for parallel workflow validation

sleep 0.02  # Small delay to simulate processing

case "$*" in
    "eval .")
        if [[ "${3:-}" == *"invalid.yml"* ]]; then
            echo "Error: invalid YAML syntax" >&2
            exit 1
        fi
        echo "name: Mock Workflow"
        echo "on: push"
        echo "jobs: {test: {runs-on: ubuntu-latest}}"
        exit 0
        ;;
    "eval .name")
        echo "Mock Workflow"
        ;;
    "eval .on")
        echo "push"
        ;;
    "eval .jobs")
        echo "{test: {runs-on: ubuntu-latest, steps: []}}"
        ;;
    *)
        echo "mock_yq_output"
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/yq"
    
    # Create python3 mock for fallback validation
    cat > "$TEST_TEMP_DIR/bin/python3" << 'EOF'
#!/bin/bash
# python3 mock for YAML validation fallback

if [[ "$*" == *"invalid.yml"* ]]; then
    echo "yaml.scanner.ScannerError: invalid YAML" >&2
    exit 1
fi
exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/bin/python3"
    
    # Create mktemp mock to track temporary file creation
    cat > "$TEST_TEMP_DIR/bin/mktemp" << 'EOF'
#!/bin/bash
# mktemp mock that tracks file creation for cleanup testing

real_mktemp="/bin/mktemp"
if command -v "$real_mktemp" >/dev/null; then
    temp_file=$($real_mktemp "$@")
    echo "$temp_file" >> "$TEST_TEMP_DIR/created_temp_files.log" 2>/dev/null || true
    echo "$temp_file"
else
    # Fallback implementation
    temp_file="/tmp/mock_temp_$$_$(date +%N)"
    touch "$temp_file"
    echo "$temp_file" >> "$TEST_TEMP_DIR/created_temp_files.log" 2>/dev/null || true
    echo "$temp_file"
fi
EOF
    chmod +x "$TEST_TEMP_DIR/bin/mktemp"
}

# Cleanup function for parallel processes
cleanup_parallel_processes() {
    # Kill any lingering background processes
    local pids
    pids=$(jobs -p 2>/dev/null) || true
    if [[ -n "$pids" ]]; then
        echo "$pids" | xargs kill -TERM 2>/dev/null || true
        sleep 0.5
        echo "$pids" | xargs kill -KILL 2>/dev/null || true
    fi
    
    # Clean up any temporary files created during testing
    if [[ -f "$TEST_TEMP_DIR/created_temp_files.log" ]]; then
        while IFS= read -r temp_file; do
            rm -f "$temp_file" 2>/dev/null || true
        done < "$TEST_TEMP_DIR/created_temp_files.log"
    fi
    
    # Clean up lock files and other parallel processing artifacts
    rm -f /tmp/validate_workflows_*.lock.* 2>/dev/null || true
    rm -f /tmp/cleanup_rate_limit_*.lock 2>/dev/null || true
    rm -f /tmp/validate_temp_files_* 2>/dev/null || true
}

# Parallel validation tests
@test "parallel processing: validate-workflows.sh processes multiple files concurrently" {
    # Run validation and capture timing
    local start_time end_time duration
    start_time=$(date +%s)
    
    run timeout 30 ./scripts/validate-workflows.sh
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    assert_success
    assert_output --partial "Validating workflows in parallel"
    assert_output --partial "Processing 22 workflow files"
    assert_output --partial "parallel jobs"
    
    # Should complete faster than sequential processing would
    # With 22 files and 0.1s mock delay each, sequential would take ~2.2s
    # Parallel with 4 jobs should take ~0.6s, allow up to 10s for test overhead
    assert [ "$duration" -lt 10 ]
}

@test "parallel processing: validation handles race conditions with file locking" {
    # Create a test that would expose race conditions without proper locking
    export MAX_PARALLEL_JOBS=8  # Increase parallelism to stress test
    
    run timeout 20 ./scripts/validate-workflows.sh
    assert_success
    
    # Should maintain accurate error/warning counts despite parallel execution
    assert_output --partial "Validation completed"
    assert_output --partial "errors and"
    assert_output --partial "warnings"
    
    # Check that counters are consistent (not garbled by race conditions)
    local error_count warning_count
    error_count=$(echo "$output" | grep -o '[0-9]\+ errors' | head -1 | grep -o '[0-9]\+' || echo "0")
    warning_count=$(echo "$output" | grep -o '[0-9]\+ warnings' | head -1 | grep -o '[0-9]\+' || echo "0")
    
    # Counts should be valid numbers
    assert [[ "$error_count" =~ ^[0-9]+$ ]]
    assert [[ "$warning_count" =~ ^[0-9]+$ ]]
}

@test "parallel processing: validate-workflows.sh cleans up temporary files properly" {
    run ./scripts/validate-workflows.sh
    assert_success
    
    # Check that temporary files are cleaned up
    local remaining_temp_files
    remaining_temp_files=$(find /tmp -name "validate_*_$$.*" 2>/dev/null | wc -l)
    assert_equal "$remaining_temp_files" "0"
    
    # Check lock files are cleaned up
    local remaining_lock_files
    remaining_lock_files=$(find /tmp -name "validate_workflows_*.lock.*" 2>/dev/null | wc -l)
    assert_equal "$remaining_lock_files" "0"
}

# Parallel cleanup tests
@test "parallel processing: cleanup-old-runs.sh handles concurrent API operations safely" {
    # Create mock that simulates API rate limiting
    cat > "$TEST_TEMP_DIR/bin/gh" << 'EOF'
#!/bin/bash
# Simulate API calls with rate limiting

case "$1 $2" in
    "auth status"|"repo view")
        exit 0
        ;;
    "api rate_limit")
        echo '{"rate":{"limit":5000,"used":4900,"remaining":100,"reset":1640995200}}'
        exit 0
        ;;
    "run list"*)
        # Return many runs to test parallel deletion
        echo "["
        for ((i=1; i<=100; i++)); do
            echo "  {\"databaseId\": $((12000 + i)), \"createdAt\": \"2024-01-01T10:00:00Z\", \"name\": \"Test Run $i\"}"
            if [[ $i -lt 100 ]]; then echo ","; fi
        done
        echo "]"
        ;;
    "workflow list")
        echo '[{"name":"Test Workflow"}]'
        ;;
    "run delete"*)
        # Simulate deletion with small delay
        sleep 0.1
        echo "Deleted run"
        exit 0
        ;;
    *)
        exit 0
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/gh"
    
    run timeout 30 ./scripts/cleanup-old-runs.sh --days 30 --max-runs 5 --force
    assert_success
    
    assert_output --partial "Starting cleanup process"
    assert_output --partial "rate limiting"
    assert_output --partial "Cleanup completed!"
}

@test "parallel processing: cleanup-old-runs.sh applies rate limiting correctly" {
    # Test that rate limiting prevents API abuse
    export RATE_LIMIT_REQUESTS_PER_MINUTE=10
    export BURST_SIZE=3
    export RATE_LIMIT_DELAY=2
    
    local start_time end_time duration
    start_time=$(date +%s)
    
    run timeout 20 ./scripts/cleanup-old-runs.sh --days 30 --max-runs 10 --force
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    assert_success
    
    # With rate limiting, should take longer than without
    # This tests that rate limiting is actually applied
    assert [ "$duration" -ge 2 ]
    
    assert_output --partial "rate limiting" || assert_output --partial "Applying additional rate limiting"
}

@test "parallel processing: cleanup-old-runs.sh uses file locking for operation counting" {
    # Test concurrent cleanup operations don't interfere with each other
    
    # Start two cleanup processes in parallel (background)
    timeout 15 ./scripts/cleanup-old-runs.sh --days 30 --max-runs 20 --force &
    local pid1=$!
    
    timeout 15 ./scripts/cleanup-old-runs.sh --days 30 --max-runs 20 --force &
    local pid2=$!
    
    # Wait for both to complete
    wait $pid1
    local exit1=$?
    wait $pid2
    local exit2=$?
    
    # Both should complete successfully without interfering
    assert_equal "$exit1" "0"
    assert_equal "$exit2" "0"
    
    # No lock files should remain
    local remaining_locks
    remaining_locks=$(find /tmp -name "cleanup_rate_limit_*.lock" 2>/dev/null | wc -l)
    assert_equal "$remaining_locks" "0"
}

# Parallel performance analysis tests
@test "parallel processing: analyze-performance.sh runs benchmarks concurrently" {
    run timeout 30 ./scripts/analyze-performance.sh --benchmarks
    assert_success
    
    assert_output --partial "Running performance benchmarks"
    assert_output --partial "Benchmark Results"
    assert_output --partial "github_api_rate_limit"
    assert_output --partial "workflow_runtime_analysis"
    assert_output --partial "cache_operations"
}

@test "parallel processing: analyze-performance.sh handles concurrent load tests" {
    export ENABLE_LOAD_TESTS="true"
    
    run timeout 30 ./scripts/analyze-performance.sh --load-tests
    assert_success
    
    assert_output --partial "Running load tests"
    assert_output --partial "Load Test Results"
    assert_output --partial "concurrent operations"
    assert_output --partial "Throughput:"
}

@test "parallel processing: analyze-performance.sh modules work together safely" {
    # Test that all modules can run concurrently without interference
    
    run timeout 30 ./scripts/analyze-performance.sh --benchmarks --load-tests
    assert_success
    
    assert_output --partial "Initializing performance analysis modules"
    assert_output --partial "All modules initialized successfully"
    assert_output --partial "Cleaning up modules"
    assert_output --partial "Module cleanup completed"
    
    # Should not have any module conflicts or race conditions
    refute_output --partial "Error"
    refute_output --partial "Failed to initialize"
}

# Signal handling and resource cleanup tests
@test "parallel processing: scripts handle SIGTERM gracefully during parallel operations" {
    # Start validation in background
    timeout 30 ./scripts/validate-workflows.sh &
    local pid=$!
    
    # Let it start processing
    sleep 2
    
    # Send SIGTERM
    kill -TERM $pid 2>/dev/null || true
    
    # Wait for graceful shutdown
    local exit_code
    wait $pid 2>/dev/null
    exit_code=$?
    
    # Should exit with appropriate code (not 0, but not crashed)
    assert [ "$exit_code" -ne 0 ]
    
    # Check cleanup occurred
    local remaining_temp_files
    remaining_temp_files=$(find /tmp -name "*validate*$$*" -o -name "*cleanup*$$*" 2>/dev/null | wc -l)
    assert_equal "$remaining_temp_files" "0"
}

@test "parallel processing: scripts handle resource cleanup on interruption" {
    # Test cleanup when script is interrupted during parallel processing
    
    # Start cleanup script in background
    ./scripts/cleanup-old-runs.sh --dry-run &
    local pid=$!
    
    # Let it start
    sleep 1
    
    # Interrupt it
    kill -INT $pid 2>/dev/null || true
    wait $pid 2>/dev/null || true
    
    # Check that cleanup functions were called
    local remaining_locks
    remaining_locks=$(find /tmp -name "cleanup_rate_limit_*.lock" -o -name "validate_workflows_*.lock.*" 2>/dev/null | wc -l)
    assert_equal "$remaining_locks" "0"
}

# Error propagation tests
@test "parallel processing: validation propagates errors from parallel workers correctly" {
    # Create a workflow that will cause validation errors
    echo "invalid yaml content {" > .github/workflows/broken.yml
    
    run ./scripts/validate-workflows.sh
    assert_failure
    
    # Should detect and report the error despite parallel processing
    assert_output --partial "ERROR:" || assert_output --partial "syntax error"
    assert_output --partial "broken.yml" || assert_output --partial "YAML"
}

@test "parallel processing: cleanup propagates API errors correctly" {
    # Create gh mock that fails for some operations
    cat > "$TEST_TEMP_DIR/bin/gh" << 'EOF'
#!/bin/bash
case "$1 $2" in
    "auth status"|"repo view"|"workflow list")
        exit 0
        ;;
    "run list"*)
        echo '[{"databaseId": 12345, "createdAt": "2024-01-01T10:00:00Z"}]'
        exit 0
        ;;
    "run delete"*)
        if [[ "$*" == *"12345"* ]]; then
            echo "API Error: Not found" >&2
            exit 1
        fi
        exit 0
        ;;
    *)
        exit 0
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/gh"
    
    run ./scripts/cleanup-old-runs.sh --days 30 --max-runs 5 --force
    assert_success  # Should handle individual failures gracefully
    
    assert_output --partial "Failed to delete run ID: 12345" || assert_output --partial "API Error"
}

@test "parallel processing: performance analysis handles module failures gracefully" {
    # Create a scenario where one module fails
    export GITHUB_TOKEN=""  # This should cause API module to fail
    
    run ./scripts/analyze-performance.sh
    assert_failure
    
    assert_output --partial "Failed to initialize" || assert_output --partial "Module initialization failed"
    
    # Should still attempt cleanup
    assert_output --partial "Cleaning up" || assert_output --partial "cleanup"
}

# Integration and dependency tests  
@test "parallel processing: multi-script workflow executes all scripts in sequence" {
    # Test running all scripts in a workflow-like sequence
    
    # First validate
    run ./scripts/validate-workflows.sh
    assert_success
    
    # Then analyze performance
    run ./scripts/analyze-performance.sh --format console
    assert_success
    
    # Finally cleanup (dry run)
    run ./scripts/cleanup-old-runs.sh --dry-run
    assert_success
    
    # All should work together without conflicts
}

@test "parallel processing: scripts share cache data appropriately" {
    # Test that caching works correctly across parallel operations
    export ENABLE_CACHE="true"
    export CACHE_TTL=300
    
    # Run validation twice to test cache reuse
    ./scripts/validate-workflows.sh >/dev/null 2>&1
    
    local start_time end_time duration
    start_time=$(date +%s)
    
    run ./scripts/validate-workflows.sh
    
    end_time=$(date +%s) 
    duration=$((end_time - start_time))
    
    assert_success
    
    # Second run should be faster due to caching
    assert [ "$duration" -lt 5 ]
    
    # Should mention cache usage
    assert_output --partial "cached" || assert_output --partial "cache"
}

@test "parallel processing: performance regression testing works correctly" {
    # Test that parallel processing doesn't degrade performance
    local sequential_time parallel_time
    
    # Test with MAX_PARALLEL_JOBS=1 (sequential)
    export MAX_PARALLEL_JOBS=1
    export ENABLE_CACHE="false"  # Disable cache to get true timing
    
    local start_time=$(date +%s)
    ./scripts/validate-workflows.sh >/dev/null 2>&1
    sequential_time=$(($(date +%s) - start_time))
    
    # Test with MAX_PARALLEL_JOBS=4 (parallel)
    export MAX_PARALLEL_JOBS=4
    
    start_time=$(date +%s)
    ./scripts/validate-workflows.sh >/dev/null 2>&1
    parallel_time=$(($(date +%s) - start_time))
    
    # Parallel should be faster or at least not significantly slower
    # Allow some overhead, but parallel should be at most 2x sequential time
    assert [ "$parallel_time" -le $((sequential_time * 2)) ]
}

# Comprehensive integration test
@test "parallel processing: comprehensive integration test with all features" {
    # Test all parallel processing features together
    export MAX_PARALLEL_JOBS=6
    export ENABLE_BENCHMARKS="true"
    export ENABLE_LOAD_TESTS="true"
    export ENABLE_CACHE="true"
    
    # Run validation
    run timeout 30 ./scripts/validate-workflows.sh
    assert_success
    assert_output --partial "parallel"
    
    # Run performance analysis with all features
    run timeout 45 ./scripts/analyze-performance.sh --benchmarks --load-tests
    assert_success
    assert_output --partial "benchmarks=true"
    assert_output --partial "load-tests=true"
    
    # Run cleanup (dry run)
    run timeout 20 ./scripts/cleanup-old-runs.sh --dry-run
    assert_success
    assert_output --partial "DRY RUN"
    
    # All scripts should complete successfully
    # No race conditions or resource conflicts should occur
}