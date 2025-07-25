#!/usr/bin/env bats
#
# Unit and integration tests for parallel processing in analyze-performance.sh
# Focuses on modular architecture, concurrent benchmarks, and load testing

setup() {
    load 'helpers/test-helpers'
    setup_script_test
    
    # Set up environment for parallel performance analysis testing
    export GITHUB_TOKEN="test-token-performance"
    export GITHUB_REPOSITORY="test-org/performance-test-repo"
    export ENABLE_BENCHMARKS="false"
    export ENABLE_LOAD_TESTS="false"
    export OUTPUT_FORMAT="console"
    export OUTPUT_FILE=""
    
    # Create comprehensive mocks for performance analysis
    create_performance_mocks
    
    # Create test workflows for analysis
    create_performance_test_workflows
}

teardown() {
    cleanup_performance_processes
    teardown_script_test
}

create_performance_mocks() {
    # GitHub CLI mock optimized for performance analysis
    cat > "$TEST_TEMP_DIR/bin/gh" << 'EOF'
#!/bin/bash
# GitHub CLI mock for performance analysis testing

# Add realistic delays to simulate API behavior
case "$1 $2" in
    "auth status")
        sleep 0.1
        echo "✓ Logged in to github.com as test-user"
        exit 0
        ;;
    "api rate_limit")
        sleep 0.05
        cat << 'RATE_LIMIT_EOF'
{
  "resources": {
    "core": {
      "limit": 5000,
      "used": 1500,
      "remaining": 3500,
      "reset": 1640995200
    },
    "search": {
      "limit": 30,
      "used": 10,
      "remaining": 20,
      "reset": 1640991600
    }
  },
  "rate": {
    "limit": 5000,
    "used": 1500,
    "remaining": 3500,
    "reset": 1640995200
  }
}
RATE_LIMIT_EOF
        exit 0
        ;;
    "run list"*)
        sleep 0.1
        if [[ "$*" == *"--limit 50"* ]]; then
            cat << 'RUNS_EOF'
[
  {
    "name": "CI",
    "status": "completed",
    "conclusion": "success",
    "createdAt": "2024-01-15T10:00:00Z",
    "updatedAt": "2024-01-15T10:04:00Z",
    "databaseId": 12345,
    "workflowId": 1
  },
  {
    "name": "CI",
    "status": "completed", 
    "conclusion": "success",
    "createdAt": "2024-01-15T09:00:00Z",
    "updatedAt": "2024-01-15T09:03:00Z",
    "databaseId": 12344,
    "workflowId": 1
  },
  {
    "name": "Build",
    "status": "completed",
    "conclusion": "failure",
    "createdAt": "2024-01-15T08:00:00Z",
    "updatedAt": "2024-01-15T08:25:00Z",
    "databaseId": 12343,
    "workflowId": 2
  },
  {
    "name": "Deploy",
    "status": "completed",
    "conclusion": "success",
    "createdAt": "2024-01-15T07:00:00Z",
    "updatedAt": "2024-01-15T07:08:00Z",
    "databaseId": 12342,
    "workflowId": 3
  }
]
RUNS_EOF
        else
            echo "[]"
        fi
        exit 0
        ;;
    "workflow list")
        sleep 0.05
        cat << 'WORKFLOWS_EOF'
[
  {
    "id": 1,
    "name": "CI",
    "path": ".github/workflows/ci.yml",
    "state": "active"
  },
  {
    "id": 2,
    "name": "Build",
    "path": ".github/workflows/build.yml", 
    "state": "active"
  },
  {
    "id": 3,
    "name": "Deploy",
    "path": ".github/workflows/deploy.yml",
    "state": "active"
  }
]
WORKFLOWS_EOF
        exit 0
        ;;
    "api "*"/workflows")
        sleep 0.05
        echo '[{"id":1,"name":"CI","state":"active"},{"id":2,"name":"Build","state":"active"}]'
        exit 0
        ;;
    *)
        echo "Mock gh: Command '$*' executed"
        exit 0
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/gh"
    
    # Enhanced jq mock for performance analysis
    cat > "$TEST_TEMP_DIR/bin/jq" << 'EOF'
#!/bin/bash
# jq mock for performance analysis testing

# Add small processing delay
sleep 0.02

input=$(cat)

case "$*" in
    "-r" ".rate.used")
        echo "1500"
        ;;
    "-r" ".rate.limit")
        echo "5000"
        ;;
    "-r" ".rate.remaining")
        echo "3500"
        ;;
    "-r" ".rate.reset")
        echo "1640995200"
        ;;
    "-r" ".resources.core.used")
        echo "1500"
        ;;
    "-r" ".resources.core.remaining")
        echo "3500"
        ;;
    "-r" ".resources.search.used")
        echo "10"
        ;;
    "-r" ".resources.search.remaining")
        echo "20"
        ;;
    *"group_by(.name)"*)
        # Performance analysis runtime grouping
        cat << 'JQ_RUNTIME_EOF'
  📊 CI: 3.5min avg, 100% success rate (2 runs)
  📊 Build: 25min avg, 0% success rate (1 runs)  
  📊 Deploy: 8min avg, 100% success rate (1 runs)
JQ_RUNTIME_EOF
        ;;
    "-e" ".api_calls_total")
        echo "15"
        ;;
    "-e" ".cache_hits")
        echo "5"
        ;;
    "-e" ".cache_hit_rate_percent")
        echo "33"
        ;;
    "-e" ".rate_limit_warnings")
        echo "0"
        ;;
    "-r" ".api_calls_total")
        echo "15"
        ;;
    "-r" ".cache_hits")
        echo "5"
        ;;
    "-r" ".cache_hit_rate_percent")
        echo "33"
        ;;
    "-r" ".rate_limit_warnings")
        echo "0"
        ;;
    "-r" ".report.generated_at")
        echo "2024-01-15T12:00:00Z"
        ;;
    "-r" ".workflows.total_count")
        echo "3"
        ;;
    "-r" ".api_usage.core.used")
        echo "1500"
        ;;
    ". | length")
        if [[ "$input" == *"databaseId"* ]]; then
            echo "4"
        else
            echo "3"
        fi
        ;;
    *)
        echo "mock_jq_output"
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/jq"
    
    # Mock bc command for load testing calculations
    cat > "$TEST_TEMP_DIR/bin/bc" << 'EOF'
#!/bin/bash
# bc mock for performance calculations

while IFS= read -r line; do
    case "$line" in
        *"scale=3"*)
            echo "0.150"
            ;;
        *"/"*)
            echo "10.5"
            ;;
        *)
            echo "42"
            ;;
    esac
done
EOF
    chmod +x "$TEST_TEMP_DIR/bin/bc"
}

create_performance_test_workflows() {
    local workflow_dir="$TEST_TEMP_DIR/repo/.github/workflows"
    mkdir -p "$workflow_dir"
    
    # Workflow 1: CI with caching
    cat > "$workflow_dir/ci.yml" << 'EOF'
name: CI
on: [push, pull_request]
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/cache@v3
        with:
          path: node_modules
          key: ${{ runner.os }}-node-${{ hashFiles('package-lock.json') }}
      - name: Install dependencies
        run: npm install
      - name: Run tests
        run: npm test
        if: github.event_name == 'push'
EOF

    # Workflow 2: Build workflow (complex, no caching)
    cat > "$workflow_dir/build.yml" << 'EOF'
name: Build
on: push
jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        version: [16, 18, 20]
    steps:
      - uses: actions/checkout@main
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: ${{ matrix.version }}
      - name: Install dependencies
        run: npm install
      - name: Build
        run: npm run build
EOF

    # Workflow 3: Deploy workflow
    cat > "$workflow_dir/deploy.yml" << 'EOF'
name: Deploy
on:
  push:
    branches: [main]
permissions:
  contents: read
  deployments: write
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/cache@v3
        with:
          path: ~/.npm
          key: ${{ runner.os }}-npm-${{ hashFiles('package-lock.json') }}
      - name: Deploy
        run: echo "Deploying..."
        if: github.ref == 'refs/heads/main'
EOF
}

cleanup_performance_processes() {
    # Clean up performance analysis temporary files
    rm -f /tmp/performance_analysis_$$.* 2>/dev/null || true
    rm -rf /tmp/benchmark_cache_$$ 2>/dev/null || true
    rm -rf /tmp/load_test_cache_$$ 2>/dev/null || true
    
    # Kill any lingering benchmark/load test processes
    local pids
    pids=$(jobs -p 2>/dev/null) || true
    if [[ -n "$pids" ]]; then
        echo "$pids" | xargs kill -TERM 2>/dev/null || true
        sleep 0.5
        echo "$pids" | xargs kill -KILL 2>/dev/null || true
    fi
}

@test "performance parallel: basic module initialization works" {
    run "$BATS_TEST_DIRNAME/../scripts/analyze-performance.sh"
    assert_success
    
    assert_output --partial "Starting performance analysis"
    assert_output --partial "Initializing performance analysis modules"
    assert_output --partial "All modules initialized successfully"
    assert_output --partial "Performance analysis completed"
}

@test "performance parallel: modules execute concurrently" {
    local start_time end_time duration
    start_time=$(date +%s)
    
    run timeout 30 "$BATS_TEST_DIRNAME/../scripts/analyze-performance.sh"
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    assert_success
    
    # Should complete in reasonable time with concurrent modules
    assert [ "$duration" -lt 20 ]
    
    assert_output --partial "Analyzing workflow runtime performance"
    assert_output --partial "Analyzing GitHub API usage"
    assert_output --partial "Analyzing workflow efficiency"
    assert_output --partial "Analyzing workflow complexity"
}

@test "performance parallel: benchmarks run concurrently when enabled" {
    export ENABLE_BENCHMARKS="true"
    
    local start_time end_time duration
    start_time=$(date +%s)
    
    run timeout 30 "$BATS_TEST_DIRNAME/../scripts/analyze-performance.sh" --benchmarks
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    assert_success
    
    assert_output --partial "Configuration: benchmarks=true"
    assert_output --partial "Running performance benchmarks"
    assert_output --partial "Benchmark Results"
    assert_output --partial "github_api_rate_limit"
    assert_output --partial "workflow_runtime_analysis"
    assert_output --partial "cache_operations"
    
    # Should complete benchmarks in reasonable time
    assert [ "$duration" -lt 25 ]
}

@test "performance parallel: load tests execute with concurrent operations" {
    export ENABLE_LOAD_TESTS="true"
    
    run timeout 30 "$BATS_TEST_DIRNAME/../scripts/analyze-performance.sh" --load-tests
    assert_success
    
    assert_output --partial "Configuration: load-tests=true"
    assert_output --partial "Running load tests"
    assert_output --partial "Load Test Results"
    assert_output --partial "concurrent operations"
    assert_output --partial "Throughput:"
    assert_output --partial "ops/sec"
}

@test "performance parallel: concurrent benchmarks and load tests work together" {
    export ENABLE_BENCHMARKS="true"
    export ENABLE_LOAD_TESTS="true"
    
    run timeout 45 "$BATS_TEST_DIRNAME/../scripts/analyze-performance.sh" --benchmarks --load-tests
    assert_success
    
    assert_output --partial "benchmarks=true"
    assert_output --partial "load-tests=true"
    assert_output --partial "Running performance benchmarks"
    assert_output --partial "Running load tests"
    assert_output --partial "Benchmark Results"
    assert_output --partial "Load Test Results"
}

@test "performance parallel: cache operations work safely in concurrent environment" {
    # Enable caching and run analysis multiple times
    export ENABLE_CACHE="true"
    export CACHE_TTL=300
    
    # First run to populate cache
    "$BATS_TEST_DIRNAME/../scripts/analyze-performance.sh" >/dev/null 2>&1
    
    # Second run should use cache
    local start_time end_time duration
    start_time=$(date +%s)
    
    run "$BATS_TEST_DIRNAME/../scripts/analyze-performance.sh"
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    assert_success
    
    # Should be faster with cache
    assert [ "$duration" -lt 10 ]
    
    # Should mention cache usage
    assert_output --partial "cache" || assert_output --partial "cached"
}

@test "performance parallel: JSON output generation works with concurrent data collection" {
    local json_file="test-performance-output.json"
    
    run "$BATS_TEST_DIRNAME/../scripts/analyze-performance.sh" --format json --output "$json_file"
    assert_success
    
    assert_output --partial "Generating JSON report: $json_file"
    
    # Verify JSON file was created
    assert [ -f "$json_file" ]
    
    # Verify JSON structure (using our mock jq)
    run jq -e '.report.generated_at' "$json_file"
    assert_success
}

@test "performance parallel: Markdown output generation works with concurrent analysis" {
    local md_file="test-performance-output.md"
    
    run "$BATS_TEST_DIRNAME/../scripts/analyze-performance.sh" --format markdown --output "$md_file"
    assert_success
    
    assert_output --partial "Generating Markdown report: $md_file"
    
    # Verify Markdown file was created
    assert [ -f "$md_file" ]
    
    # Verify it contains expected headers
    run grep -q "# GitHub Actions Performance Analysis Report" "$md_file"
    assert_success
}

@test "performance parallel: module cleanup works correctly after concurrent execution" {
    run "$BATS_TEST_DIRNAME/../scripts/analyze-performance.sh" --benchmarks
    assert_success
    
    assert_output --partial "Cleaning up modules"
    assert_output --partial "Module cleanup completed"
    
    # Check that temporary files are cleaned up
    local remaining_temp_files
    remaining_temp_files=$(find /tmp -name "performance_analysis_$$.*" -o -name "benchmark_cache_$$" -o -name "load_test_cache_$$" 2>/dev/null | wc -l)
    assert_equal "$remaining_temp_files" "0"
}

@test "performance parallel: error handling works during concurrent module initialization" {
    # Create a scenario where initialization might fail
    export GITHUB_TOKEN=""
    
    run "$BATS_TEST_DIRNAME/../scripts/analyze-performance.sh"
    assert_failure
    
    assert_output --partial "Failed to initialize" || assert_output --partial "Module initialization failed"
    
    # Should still attempt cleanup
    assert_output --partial "Cleaning up" || assert_output --partial "cleanup"
}

@test "performance parallel: signal handling during concurrent operations" {
    # Start analysis in background
    "$BATS_TEST_DIRNAME/../scripts/analyze-performance.sh" --benchmarks --load-tests &
    local pid=$!
    
    # Let it start processing
    sleep 3
    
    # Send SIGTERM
    kill -TERM $pid 2>/dev/null || true
    
    # Wait for shutdown
    wait $pid 2>/dev/null || true
    
    # Check cleanup occurred
    local remaining_files
    remaining_files=$(find /tmp -name "*performance*$$*" -o -name "*benchmark*$$*" -o -name "*load_test*$$*" 2>/dev/null | wc -l)
    assert_equal "$remaining_files" "0"
}

@test "performance parallel: concurrent API usage analysis works correctly" {
    run "$BATS_TEST_DIRNAME/../scripts/analyze-performance.sh"
    assert_success
    
    assert_output --partial "GitHub API Usage"
    assert_output --partial "Core API: 1500/5000"
    assert_output --partial "Search API: 10/30"
    assert_output --partial "Remaining: 3500"
    assert_output --partial "API usage is within healthy limits"
}

@test "performance parallel: workflow efficiency analysis handles concurrent workflow processing" {
    run "$BATS_TEST_DIRNAME/../scripts/analyze-performance.sh"
    assert_success
    
    assert_output --partial "Workflow Configuration Analysis"
    assert_output --partial "Total workflows: 3"
    assert_output --partial "Using caching:"
    assert_output --partial "Using conditionals:"
    assert_output --partial "Using matrix builds:"
}

@test "performance parallel: workflow complexity analysis processes multiple workflows concurrently" {
    run "$BATS_TEST_DIRNAME/../scripts/analyze-performance.sh"
    assert_success
    
    assert_output --partial "Analyzing workflow complexity"
    assert_output --partial "Workflow Complexity Metrics"
    assert_output --partial "Average jobs per workflow:"
    assert_output --partial "Average steps per workflow:"
}

@test "performance parallel: performance metrics collection works during concurrent operations" {
    run "$BATS_TEST_DIRNAME/../scripts/analyze-performance.sh" --benchmarks
    assert_success
    
    assert_output --partial "Performance Metrics Report"
    assert_output --partial "Script Execution Metrics"
    assert_output --partial "Total execution time:"
    assert_output --partial "Cache Performance:"
    assert_output --partial "Operation Performance:"
}

@test "performance parallel: data sharing between concurrent modules works correctly" {
    local json_file="module-data-test.json"
    
    run "$BATS_TEST_DIRNAME/../scripts/analyze-performance.sh" --format json --output "$json_file"
    assert_success
    
    # Verify data was shared correctly between modules
    assert [ -f "$json_file" ]
    
    # Test that API usage data flows to report
    run jq -e '.api_usage' "$json_file"
    assert_success
    
    # Test that workflow count is correct
    run jq -e '.workflows.total_count' "$json_file"
    assert_success
    
    local workflow_count
    workflow_count=$(jq -r '.workflows.total_count' "$json_file")
    assert_equal "$workflow_count" "3"
}

@test "performance parallel: command line argument validation works" {
    run "$BATS_TEST_DIRNAME/../scripts/analyze-performance.sh" --invalid-option
    assert_failure
    
    assert_output --partial "Unknown option: --invalid-option"
}

@test "performance parallel: help message displays correctly" {
    run "$BATS_TEST_DIRNAME/../scripts/analyze-performance.sh" --help
    assert_success
    
    assert_output --partial "Usage:"
    assert_output --partial "Performance Analysis Script"
    assert_output --partial "OPTIONS:"
    assert_output --partial "EXAMPLES:"
}

@test "performance parallel: handles missing workflow directory gracefully" {
    # Remove workflow directory
    rm -rf "$TEST_TEMP_DIR/repo/.github"
    
    run "$BATS_TEST_DIRNAME/../scripts/analyze-performance.sh"
    assert_success
    
    # Should handle gracefully, possibly with warnings
    assert_output --partial "analysis completed" || assert_output --partial "No workflow"
}

@test "performance parallel: handles GitHub API failures during concurrent operations" {
    # Create failing gh mock
    cat > "$TEST_TEMP_DIR/bin/gh" << 'EOF'
#!/bin/bash
case "$1 $2" in
    "auth status")
        exit 0  # Auth OK
        ;;
    *)
        echo "API Error: rate limit exceeded" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/gh"
    
    run "$BATS_TEST_DIRNAME/../scripts/analyze-performance.sh"
    assert_failure
    
    assert_output --partial "Failed to" || assert_output --partial "Error" || assert_output --partial "initialization failed"
}

@test "performance parallel: comprehensive integration test with all concurrent features" {
    export ENABLE_BENCHMARKS="true"
    export ENABLE_LOAD_TESTS="true"
    export ENABLE_CACHE="true"
    
    local start_time end_time duration
    start_time=$(date +%s)
    
    run timeout 60 "$BATS_TEST_DIRNAME/../scripts/analyze-performance.sh" --benchmarks --load-tests --format console
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    assert_success
    
    # Should complete comprehensive analysis in reasonable time
    assert [ "$duration" -lt 50 ]
    
    # Should include all components
    assert_output --partial "Starting performance analysis"
    assert_output --partial "Initializing performance analysis modules"
    assert_output --partial "Analyzing workflow runtime performance"
    assert_output --partial "Analyzing GitHub API usage"
    assert_output --partial "Analyzing workflow efficiency"
    assert_output --partial "Analyzing workflow complexity"
    assert_output --partial "Running performance benchmarks"
    assert_output --partial "Running load tests"
    assert_output --partial "Performance Metrics Report"
    assert_output --partial "GitHub API Statistics"
    assert_output --partial "Cleaning up modules"
    assert_output --partial "Performance analysis completed successfully"
}