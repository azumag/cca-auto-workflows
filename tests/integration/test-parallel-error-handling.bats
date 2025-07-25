#!/usr/bin/env bats
#
# Integration tests for parallel processing error handling and edge cases
# Tests cache behavior, signal handling, and graceful error recovery
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

# Test configuration constants
readonly DEFAULT_WORKFLOW_COUNT=10
readonly STRESS_TEST_WORKFLOW_COUNT=50
readonly LARGE_SCALE_WORKFLOW_COUNT=120
readonly DEFAULT_TEST_TIMEOUT=30
readonly MEDIUM_TEST_TIMEOUT=60
readonly LONG_TEST_TIMEOUT=120

# Create comprehensive workflows with configurable count
create_comprehensive_test_workflows() {
    local workflow_dir="$TEST_REPO_DIR/.github/workflows"
    local workflow_count="${1:-$DEFAULT_WORKFLOW_COUNT}"
    mkdir -p "$workflow_dir"
    
    # Create workflows based on specified count (default: 10 for most tests)
    for i in $(seq 1 "$workflow_count"); do
        local workflow_type=$((i % 5))
        case $workflow_type in
            0) create_test_workflow "$workflow_dir/intensive-$i.yml" "Resource Intensive $i" "resource_intensive" ;;
            1) create_test_workflow "$workflow_dir/memory-$i.yml" "Memory Heavy $i" "memory_heavy" ;;
            2) create_test_workflow "$workflow_dir/cpu-$i.yml" "CPU Heavy $i" "cpu_heavy" ;;
            3) create_test_workflow "$workflow_dir/cached-$i.yml" "Cached Workflow $i" "cached" ;;
            4) create_test_workflow "$workflow_dir/conditional-$i.yml" "Conditional $i" "conditional" ;;
        esac
    done
    
    # Create workflows with specific resource patterns
    create_failing_workflow "$workflow_dir/failing-workflow.yml"
    create_timeout_workflow "$workflow_dir/timeout-workflow.yml"
    create_large_matrix_workflow "$workflow_dir/large-matrix.yml"
}

# Consolidated workflow generator function (fixes DRY violation)
create_test_workflow() {
    local file="$1" name="$2" type="$3"
    
    case "$type" in
        "resource_intensive")
            cat > "$file" << EOF
name: $name
on: [push, pull_request, schedule]
permissions: { contents: read, issues: write, pull-requests: write }
jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix: { version: [16, 18, 20], os: [ubuntu-latest, windows-latest, macos-latest] }
    steps:
      - uses: actions/checkout@v4
      - uses: actions/cache@v3
        with:
          path: |
            node_modules
            ~/.npm
            ~/.cache
          key: \${{ runner.os }}-\${{ matrix.version }}-\${{ hashFiles('package-lock.json') }}
      - run: npm install
      - run: npm run build
      - run: npm test
        if: github.event_name == 'push'
  deploy:
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/main'
    steps:
      - run: echo "Deploying $name"
EOF
            ;;
        "memory_heavy")
            cat > "$file" << EOF
name: $name
on: push
jobs:
  memory-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: |
          for i in {1..10}; do
            echo "Processing large dataset \$i"
            dd if=/dev/zero of=/tmp/test\$i bs=1M count=100 2>/dev/null || true
          done
          rm -f /tmp/test*
      - uses: actions/cache@v3
        with:
          path: large-files/
          key: \${{ runner.os }}-large-files-\${{ hashFiles('**/*.bin') }}
EOF
            ;;
        "cpu_heavy")
            cat > "$file" << EOF
name: $name
on: push
jobs:
  cpu-test:
    runs-on: ubuntu-latest
    strategy:
      matrix: { task: [compile, test, lint, format, analyze] }
    steps:
      - uses: actions/checkout@v4
      - run: |
          case "\${{ matrix.task }}" in
            compile) echo "Compiling with high CPU usage" ;;
            test) echo "Running CPU-intensive tests" ;;
            *) echo "Processing \${{ matrix.task }}" ;;
          esac
          seq 1 1000000 | while read i; do echo \$i > /dev/null; done
EOF
            ;;
        "cached")
            cat > "$file" << EOF
name: $name
on: [push, pull_request]
permissions: { contents: read }
jobs:
  cached-build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/cache@v3
        with:
          path: ~/.cache/pip
          key: \${{ runner.os }}-pip-\${{ hashFiles('requirements.txt') }}
          restore-keys: \${{ runner.os }}-pip-
      - uses: actions/cache@v3
        with:
          path: node_modules
          key: \${{ runner.os }}-node-\${{ hashFiles('package-lock.json') }}
      - run: echo "Building $name with caching enabled"
EOF
            ;;
        "conditional")
            cat > "$file" << EOF
name: $name
on: [push, pull_request]
jobs:
  conditional-job:
    runs-on: ubuntu-latest
    if: github.event_name == 'push' || contains(github.event.pull_request.labels.*.name, 'run-tests')
    steps:
      - uses: actions/checkout@v4
        if: github.ref == 'refs/heads/main'
      - run: echo "Running $name"
        if: contains(github.event.head_commit.message, 'build')
      - run: echo "Additional processing"
        if: github.event_name == 'pull_request' && github.event.action == 'opened'
EOF
            ;;
        *)
            echo "Unknown workflow type: $type" >&2
            return 1
            ;;
    esac
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

# Simplified mocks focused on essential functionality (fixes KISS violation)
create_comprehensive_mocks() {
    # Simplified GitHub CLI mock
    cat > "$TEST_TEMP_DIR/bin/gh" << 'EOF'
#!/bin/bash
case "$1 $2" in
    "auth status") echo "✓ Logged in to github.com as test-user" ;;
    "repo view") echo "test-org/comprehensive-test-repo" ;;
    "api rate_limit")
        local remaining=${MOCK_RATE_LIMIT_REMAINING:-1000}
        echo "{\"rate\": {\"limit\": 5000, \"used\": $((5000 - remaining)), \"remaining\": $remaining, \"reset\": $(($(date +%s) + 3600))}}"
        ;;
    "run list"*)
        # Generate reasonable number of runs based on test needs (fixes performance issue)
        local max_runs=${MOCK_MAX_RUNS:-50}
        echo "["
        for ((i=1; i<=max_runs; i++)); do
            local conclusion="success"
            [[ $((i % 10)) -eq 0 ]] && conclusion="failure"
            echo "  {\"name\": \"Workflow $i\", \"status\": \"completed\", \"conclusion\": \"$conclusion\", \"databaseId\": $((20000 + i))}"
            [[ $i -lt $max_runs ]] && echo ","
        done
        echo "]"
        ;;
    "workflow list")
        echo '[{"id": 1, "name": "Test Workflow", "state": "active"}]'
        ;;
    "run delete"*)
        local run_id=$(echo "$*" | grep -o '[0-9]\+' | head -1)
        [[ $((run_id % 10)) -eq 0 ]] && { echo "API Error: Run $run_id cannot be deleted" >&2; exit 1; }
        echo "✓ Deleted run $run_id"
        ;;
    *) echo "Mock gh: Command '$*' executed" ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/gh"
    
    # Simplified jq mock
    cat > "$TEST_TEMP_DIR/bin/jq" << 'EOF'
#!/bin/bash
input=$(cat)
case "$*" in
    "-r" ".rate.remaining") echo "${MOCK_RATE_LIMIT_REMAINING:-1000}" ;;
    "-r" ".rate.limit") echo "5000" ;;
    "-r" ".rate.used") echo "${MOCK_RATE_LIMIT_USED:-4000}" ;;
    ". | length"|"length") echo "${MOCK_ARRAY_LENGTH:-50}" ;;
    *"group_by(.name)"*) echo "📊 Test Workflow: 10min avg, 95% success rate (25 runs)" ;;
    *"map(select"*) seq 20001 20050 ;;
    *) echo "mock_jq_output" ;;
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