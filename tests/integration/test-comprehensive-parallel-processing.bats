#!/usr/bin/env bats
#
# Comprehensive integration tests for parallel processing functionality
# Tests complete workflows with resource monitoring, performance scenarios, and real-world conditions
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
    
    # Create comprehensive workflow structure
    create_comprehensive_test_workflows
    
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
    
    # Create comprehensive mocks for advanced testing
    create_comprehensive_mocks
    create_resource_monitoring_mocks
}

teardown() {
    cleanup_comprehensive_processes
    teardown_test_environment
}

# Create comprehensive workflows for thorough testing
create_comprehensive_test_workflows() {
    local workflow_dir="$TEST_REPO_DIR/.github/workflows"
    mkdir -p "$workflow_dir"
    
    # Create 50 workflows to test large-scale parallel processing
    for i in $(seq 1 50); do
        local workflow_type=$((i % 5))
        case $workflow_type in
            0) create_resource_intensive_workflow "$workflow_dir/intensive-$i.yml" "Resource Intensive $i" ;;
            1) create_memory_heavy_workflow "$workflow_dir/memory-$i.yml" "Memory Heavy $i" ;;
            2) create_cpu_heavy_workflow "$workflow_dir/cpu-$i.yml" "CPU Heavy $i" ;;
            3) create_cached_workflow "$workflow_dir/cached-$i.yml" "Cached Workflow $i" ;;
            4) create_conditional_workflow "$workflow_dir/conditional-$i.yml" "Conditional $i" ;;
        esac
    done
    
    # Create workflows with specific resource patterns
    create_failing_workflow "$workflow_dir/failing-workflow.yml"
    create_timeout_workflow "$workflow_dir/timeout-workflow.yml"
    create_large_matrix_workflow "$workflow_dir/large-matrix.yml"
}

create_resource_intensive_workflow() {
    cat > "$1" << EOF
name: $2
on: [push, pull_request, schedule]
permissions:
  contents: read
  issues: write
  pull-requests: write
jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        version: [16, 18, 20]
        os: [ubuntu-latest, windows-latest, macos-latest]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/cache@v3
        with:
          path: |
            node_modules
            ~/.npm
            ~/.cache
          key: \${{ runner.os }}-\${{ matrix.version }}-\${{ hashFiles('package-lock.json') }}
      - name: Install dependencies
        run: npm install
      - name: Build
        run: npm run build
      - name: Test
        run: npm test
        if: github.event_name == 'push'
  deploy:
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Deploy
        run: echo "Deploying $2"
EOF
}

create_memory_heavy_workflow() {
    cat > "$1" << EOF
name: $2
on: push
jobs:
  memory-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Memory intensive task
        run: |
          # Simulate memory-heavy operations
          for i in {1..10}; do
            echo "Processing large dataset \$i"
            dd if=/dev/zero of=/tmp/test\$i bs=1M count=100 2>/dev/null || true
          done
          rm -f /tmp/test*
      - name: Cache large files
        uses: actions/cache@v3
        with:
          path: large-files/
          key: \${{ runner.os }}-large-files-\${{ hashFiles('**/*.bin') }}
EOF
}

create_cpu_heavy_workflow() {
    cat > "$1" << EOF
name: $2
on: push
jobs:
  cpu-test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        task: [compile, test, lint, format, analyze]
    steps:
      - uses: actions/checkout@v4
      - name: CPU intensive task - \${{ matrix.task }}
        run: |
          # Simulate CPU-heavy operations
          case "\${{ matrix.task }}" in
            compile) echo "Compiling with high CPU usage" ;;
            test) echo "Running CPU-intensive tests" ;;
            lint) echo "Linting with parallel processing" ;;
            format) echo "Formatting code in parallel" ;;
            analyze) echo "Static analysis with high CPU" ;;
          esac
          # Simulate some CPU work
          seq 1 1000000 | while read i; do echo \$i > /dev/null; done
EOF
}

create_cached_workflow() {
    cat > "$1" << EOF
name: $2
on: [push, pull_request]
permissions:
  contents: read
jobs:
  cached-build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/cache@v3
        with:
          path: ~/.cache/pip
          key: \${{ runner.os }}-pip-\${{ hashFiles('requirements.txt') }}
          restore-keys: |
            \${{ runner.os }}-pip-
      - uses: actions/cache@v3
        with:
          path: node_modules
          key: \${{ runner.os }}-node-\${{ hashFiles('package-lock.json') }}
      - name: Build with cache
        run: echo "Building $2 with caching enabled"
EOF
}

create_conditional_workflow() {
    cat > "$1" << EOF
name: $2
on: [push, pull_request]
jobs:
  conditional-job:
    runs-on: ubuntu-latest
    if: github.event_name == 'push' || contains(github.event.pull_request.labels.*.name, 'run-tests')
    steps:
      - uses: actions/checkout@v4
        if: github.ref == 'refs/heads/main'
      - name: Conditional step 1
        run: echo "Running $2"
        if: contains(github.event.head_commit.message, 'build')
      - name: Conditional step 2
        run: echo "Additional processing"
        if: github.event_name == 'pull_request' && github.event.action == 'opened'
EOF
}

create_failing_workflow() {
    cat > "$1" << 'EOF'
name: Failing Workflow
on: push
jobs:
  failing-job:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: This will fail
        run: exit 1
      - name: This won't run
        run: echo "Should not execute"
EOF
}

create_timeout_workflow() {
    cat > "$1" << 'EOF'
name: Timeout Workflow
on: push
jobs:
  long-running:
    runs-on: ubuntu-latest
    timeout-minutes: 1
    steps:
      - uses: actions/checkout@v4
      - name: Long running task
        run: sleep 300  # This will timeout
EOF
}

create_large_matrix_workflow() {
    cat > "$1" << 'EOF'
name: Large Matrix Workflow
on: push
jobs:
  matrix-job:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        version: [16, 17, 18, 19, 20, 21]
        os: [ubuntu-latest, ubuntu-20.04, ubuntu-22.04]
        arch: [x64, arm64]
    steps:
      - uses: actions/checkout@v4
      - name: Matrix test
        run: echo "Testing v${{ matrix.version }} on ${{ matrix.os }} (${{ matrix.arch }})"
EOF
}

# Create comprehensive mocks for advanced testing scenarios
create_comprehensive_mocks() {
    # Enhanced GitHub CLI mock with realistic API behavior
    cat > "$TEST_TEMP_DIR/bin/gh" << 'EOF'
#!/bin/bash
# Advanced GitHub CLI mock for comprehensive testing

# Simulate realistic API delays based on operation type
case "$1 $2" in
    "auth status")
        sleep 0.1
        echo "✓ Logged in to github.com as test-user"
        exit 0
        ;;
    "repo view")
        sleep 0.05
        echo "test-org/comprehensive-test-repo"
        exit 0
        ;;
    "api rate_limit")
        sleep 0.1
        # Simulate varying rate limit conditions for testing
        local remaining=\$(shuf -i 100-4500 -n 1)
        echo "{"
        echo "  \"resources\": {"
        echo "    \"core\": {"
        echo "      \"limit\": 5000,"
        echo "      \"used\": \$((5000 - remaining)),"
        echo "      \"remaining\": \$remaining,"
        echo "      \"reset\": \$(($(date +%s) + 3600))"
        echo "    },"
        echo "    \"search\": {"
        echo "      \"limit\": 30,"
        echo "      \"used\": \$((remaining % 20)),"
        echo "      \"remaining\": \$((30 - (remaining % 20))),"
        echo "      \"reset\": \$(($(date +%s) + 3600))"
        echo "    }"
        echo "  },"
        echo "  \"rate\": {"
        echo "    \"limit\": 5000,"
        echo "    \"used\": \$((5000 - remaining)),"
        echo "    \"remaining\": \$remaining,"
        echo "    \"reset\": \$(($(date +%s) + 3600))"
        echo "  }"
        echo "}"
        exit 0
        ;;
    "run list"*)
        sleep 0.2
        # Generate large number of runs for stress testing
        if [[ "$*" == *"--limit 1000"* ]]; then
            echo "["
            for ((i=1; i<=500; i++)); do
                local days_ago=$((i % 90 + 1))
                local status="completed"
                local conclusion="success"
                # Add some failures for testing error handling
                if [[ $((i % 20)) -eq 0 ]]; then
                    conclusion="failure"
                elif [[ $((i % 25)) -eq 0 ]]; then
                    conclusion="cancelled"
                fi
                
                local created_date="2024-01-$(printf "%02d" $((i % 28 + 1)))T$(printf "%02d" $((i % 24))):00:00Z"
                echo "  {"
                echo "    \"name\": \"Workflow $((i % 10 + 1))\","
                echo "    \"status\": \"$status\","
                echo "    \"conclusion\": \"$conclusion\","
                echo "    \"createdAt\": \"$created_date\","
                echo "    \"updatedAt\": \"$created_date\","
                echo "    \"databaseId\": $((20000 + i))"
                if [[ $i -lt 500 ]]; then
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
    "workflow list")
        sleep 0.1
        echo '['
        for ((i=1; i<=50; i++)); do
            echo "  {\"id\": $i, \"name\": \"Test Workflow $i\", \"state\": \"active\"}"
            if [[ $i -lt 50 ]]; then echo ","; fi
        done
        echo ']'
        exit 0
        ;;
    "run delete"*)
        # Simulate varying deletion times and occasional failures
        local run_id=$(echo "$*" | grep -o '[0-9]\+' | head -1)
        sleep $(echo "scale=3; $(shuf -i 100-500 -n 1) / 1000" | bc -l 2>/dev/null || echo 0.2)
        
        # Simulate 10% failure rate for testing error handling
        if [[ $((run_id % 10)) -eq 0 ]]; then
            echo "API Error: Run $run_id cannot be deleted" >&2
            exit 1
        fi
        
        echo "✓ Deleted run $run_id"
        exit 0
        ;;
    *)
        echo "Mock gh: Command '$*' executed"
        exit 0
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/gh"
    
    # Enhanced jq mock for complex data processing
    cat > "$TEST_TEMP_DIR/bin/jq" << 'EOF'
#!/bin/bash
# Advanced jq mock for comprehensive testing

# Simulate processing delay
sleep 0.02

input=$(cat)

case "$*" in
    "-r" ".rate.remaining")
        echo $(shuf -i 100-4500 -n 1)
        ;;
    "-r" ".rate.limit")
        echo "5000"
        ;;
    "-r" ".rate.used")
        echo $(shuf -i 500-4900 -n 1)
        ;;
    ". | length")
        if [[ "$input" == *"databaseId"* ]]; then
            echo "500"
        else
            echo "50"
        fi
        ;;
    "length")
        echo "500"
        ;;
    *"group_by(.name)"*)
        # Mock comprehensive workflow runtime analysis
        for i in {1..10}; do
            local avg_time=$((i * 2 + 5))
            local success_rate=$((95 - (i % 3) * 5))
            echo "  📊 Test Workflow $i: ${avg_time}min avg, ${success_rate}% success rate ($((i * 5)) runs)"
        done
        ;;
    *"map(select"*".createdAt"*)
        # Filter old runs for cleanup testing
        for ((i=1; i<=200; i++)); do
            echo $((20000 + i))
        done
        ;;
    *)
        echo "mock_jq_output"
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/jq"
}

# Create resource monitoring mocks that simulate various system conditions
create_resource_monitoring_mocks() {
    # Mock free command for memory testing
    cat > "$TEST_TEMP_DIR/bin/free" << 'EOF'
#!/bin/bash
# Mock free command for memory usage testing

case "$*" in
    "-m")
        # Simulate varying memory conditions
        local memory_condition="${MOCK_MEMORY_CONDITION:-normal}"
        case "$memory_condition" in
            "high")
                # High memory usage scenario
                echo "              total        used        free      shared  buff/cache   available"
                echo "Mem:           8000        7200         400           0         400         400"
                ;;
            "low")
                # Low memory usage scenario  
                echo "              total        used        free      shared  buff/cache   available"
                echo "Mem:           8000        1600        5600           0         800        5600"
                ;;
            "critical")
                # Critical memory scenario
                echo "              total        used        free      shared  buff/cache   available"
                echo "Mem:           8000        7800         100           0         100         100"
                ;;
            *)
                # Normal memory scenario
                echo "              total        used        free      shared  buff/cache   available"
                echo "Mem:           8000        4000        2400           0        1600        2400"
                ;;
        esac
        ;;
    *)
        /usr/bin/free "$@" 2>/dev/null || true
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/free"
    
    # Mock sar command for CPU testing
    cat > "$TEST_TEMP_DIR/bin/sar" << 'EOF'
#!/bin/bash
# Mock sar command for CPU usage testing

if [[ "$*" == "-u 1 1" ]]; then
    local cpu_condition="${MOCK_CPU_CONDITION:-normal}"
    case "$cpu_condition" in
        "high")
            echo "Linux 5.4.0 (test-host)    $(date '+%m/%d/%Y')      _x86_64_        (8 CPU)"
            echo ""
            echo "$(date '+%I:%M:%S %p')     CPU     %user     %nice   %system   %iowait    %steal     %idle"
            echo "$(date '+%I:%M:%S %p')     all     45.00      0.00     35.00      5.00      0.00     15.00"
            ;;
        "critical")
            echo "Linux 5.4.0 (test-host)    $(date '+%m/%d/%Y')      _x86_64_        (8 CPU)"
            echo ""
            echo "$(date '+%I:%M:%S %p')     CPU     %user     %nice   %system   %iowait    %steal     %idle"
            echo "$(date '+%I:%M:%S %p')     all     85.00      0.00     10.00      3.00      0.00      2.00"
            ;;
        "low")
            echo "Linux 5.4.0 (test-host)    $(date '+%m/%d/%Y')      _x86_64_        (8 CPU)"
            echo ""
            echo "$(date '+%I:%M:%S %p')     CPU     %user     %nice   %system   %iowait    %steal     %idle"
            echo "$(date '+%I:%M:%S %p')     all      5.00      0.00      3.00      1.00      0.00     91.00"
            ;;
        *)
            echo "Linux 5.4.0 (test-host)    $(date '+%m/%d/%Y')      _x86_64_        (8 CPU)"
            echo ""
            echo "$(date '+%I:%M:%S %p')     CPU     %user     %nice   %system   %iowait    %steal     %idle"
            echo "$(date '+%I:%M:%S %p')     all     25.00      0.00     15.00      2.00      0.00     58.00"
            ;;
    esac
fi
EOF
    chmod +x "$TEST_TEMP_DIR/bin/sar"
    
    # Mock bc command for calculations
    cat > "$TEST_TEMP_DIR/bin/bc" << 'EOF'
#!/bin/bash
# Mock bc command for mathematical calculations

while IFS= read -r line; do
    case "$line" in
        *" * 1.5")
            echo "12.0"
            ;;
        *"scale=3"*)
            echo "0.200"
            ;;
        *"/")
            echo "10"
            ;;
        *)
            echo "8"
            ;;
    esac
done
EOF
    chmod +x "$TEST_TEMP_DIR/bin/bc"
}

cleanup_comprehensive_processes() {
    # Clean up all comprehensive test artifacts
    local pids
    pids=$(jobs -p 2>/dev/null) || true
    if [[ -n "$pids" ]]; then
        echo "$pids" | xargs kill -TERM 2>/dev/null || true
        sleep 0.5
        echo "$pids" | xargs kill -KILL 2>/dev/null || true
    fi
    
    # Clean up temporary files
    rm -f /tmp/comprehensive_test_$$.* 2>/dev/null || true
    rm -f /tmp/resource_monitor_$$.* 2>/dev/null || true
    rm -f /tmp/validate_workflows_*.lock.* 2>/dev/null || true
    rm -f /tmp/cleanup_rate_limit_*.lock 2>/dev/null || true
}

# Integration Test 1: Complete parallel processing workflow with resource monitoring
@test "comprehensive integration: complete workflow with resource monitoring" {
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
    assert [ "$duration" -lt 30 ]
}

# Integration Test 2: Performance integration under memory pressure
@test "comprehensive integration: performance under memory pressure scenarios" {
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
@test "comprehensive integration: performance under high CPU usage scenarios" {
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
@test "comprehensive integration: optimal job calculation with various system conditions" {
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

# Integration Test 5: Large file counts with resource constraints
@test "comprehensive integration: large file counts with resource constraints" {
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
    assert [ "$duration" -lt 60 ]
    
    # Should show resource adaptation
    assert_output --partial "Adaptive parallelism" || assert_output --partial "System resources are constrained"
}

# Integration Test 6: System resource exhaustion behavior
@test "comprehensive integration: system resource exhaustion behavior" {
    export MOCK_MEMORY_CONDITION="critical"
    export MOCK_CPU_CONDITION="critical"
    export RESOURCE_MONITOR_ENABLED="true"
    export MEMORY_LIMIT_PERCENT=90
    export CPU_LIMIT_PERCENT=85
    export MIN_PARALLEL_JOBS=1
    
    run timeout $TEST_TIMEOUT_LONG ./scripts/validate-workflows.sh
    assert_success
    
    # Should handle critical resource conditions gracefully
    assert_output --partial "Memory usage high:" || assert_output --partial "CPU usage high:" || assert_output --partial "System resources are constrained"
    
    # Should still complete validation
    assert_output --partial "Validation completed"
    
    # Should reduce parallelism appropriately
    assert_output --partial "Adaptive parallelism: using"
    
    # Test that cleanup also handles resource exhaustion
    run timeout $TEST_TIMEOUT_MEDIUM ./scripts/cleanup-old-runs.sh --days 30 --max-runs 10 --force
    assert_success
    
    assert_output --partial "Cleanup completed!" || assert_output --partial "rate limiting"
}

# Integration Test 7: Graceful degradation when parallel jobs fail
@test "comprehensive integration: graceful degradation when parallel jobs fail" {
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

# Integration Test 8: Cache integration with parallel processing under various conditions
@test "comprehensive integration: cache integration with parallel processing" {
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
    
    # Should be faster due to caching
    assert [ "$duration" -lt 15 ]
    
    # Should mention cache usage
    assert_output --partial "cached" || assert_output --partial "cache"
    
    # Test performance analysis with caching
    run ./scripts/analyze-performance.sh
    assert_success
    
    assert_output --partial "cache" || assert_output --partial "Performance analysis completed"
}

# Integration Test 9: Signal handling during parallel processing with resource monitoring
@test "comprehensive integration: signal handling during complex parallel operations" {
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

# Integration Test 10: End-to-end workflow testing all components together
@test "comprehensive integration: end-to-end workflow with all parallel processing features" {
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
    assert [ "$total_duration" -lt 120 ]
    
    # All components should work together without conflicts
    # No resource leaks should occur
    local remaining_files
    remaining_files=$(find /tmp -name "*$$*" 2>/dev/null | wc -l)
    assert_equal "$remaining_files" "0"
}