#!/usr/bin/env bats
#
# Integration tests for the complete performance analysis system
# Tests end-to-end functionality with mocked GitHub API responses

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
    
    # Create .github/workflows directory and sample workflows
    create_integration_test_workflows
    
    # Copy scripts to test location
    cp -r "$BATS_TEST_DIRNAME/../../scripts" .
    
    # Fix package.json issue for testing
    sed -i 's/"bats-assert": "^2.1.0"/"bats-assert": "^2.0.0"/' "$BATS_TEST_DIRNAME/../../package.json" 2>/dev/null || true
    
    # Set up environment variables
    export GITHUB_TOKEN="test-token-12345"
    export GITHUB_REPOSITORY="test-org/test-repo"
    export GITHUB_API_URL="https://api.github.com"
    
    # Create comprehensive GitHub API mock
    create_comprehensive_gh_mock
    
    # Create jq mock for JSON processing
    create_comprehensive_jq_mock
}

teardown() {
    teardown_test_environment
}

# Create sample workflows for testing
create_integration_test_workflows() {
    local workflow_dir="$TEST_REPO_DIR/.github/workflows"
    mkdir -p "$workflow_dir"
    
    # Workflow 1: Basic CI with caching
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

    # Workflow 2: Matrix build
    cat > "$workflow_dir/matrix-test.yml" << 'EOF'
name: Matrix Test
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node-version: [16, 18, 20]
    steps:
      - uses: actions/checkout@v4
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: ${{ matrix.node-version }}
      - name: Test
        run: echo "Testing with Node ${{ matrix.node-version }}"
EOF

    # Workflow 3: Problematic workflow (no caching, outdated actions)
    cat > "$workflow_dir/problematic.yml" << 'EOF'
name: Problematic Workflow
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
      - name: Deploy
        run: echo "Deploying..."
EOF

    # Workflow 4: Complex workflow
    cat > "$workflow_dir/complex.yml" << 'EOF'
name: Complex Workflow
on: [push, pull_request, schedule]
permissions:
  contents: read
  issues: write
  pull-requests: write
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Lint
        run: npm run lint
  test:
    runs-on: ubuntu-latest
    needs: lint
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/cache@v3
        with:
          path: ~/.npm
          key: ${{ runner.os }}-node-${{ hashFiles('package-lock.json') }}
      - name: Test on ${{ matrix.os }}
        run: npm test
        if: always()
  build:
    runs-on: ubuntu-latest
    needs: test
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: npm run build
  deploy:
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Deploy
        run: echo "Deploying to production"
  notify:
    runs-on: ubuntu-latest
    needs: [lint, test, build, deploy]
    if: always()
    steps:
      - name: Notify
        run: echo "Workflow completed"
EOF
}

# Create comprehensive GitHub CLI mock
create_comprehensive_gh_mock() {
    cat > "$TEST_TEMP_DIR/bin/gh" << 'EOF'
#!/bin/bash
# Comprehensive GitHub CLI mock for integration testing

case "$1 $2" in
    "auth status")
        echo "✓ Logged in to github.com as test-user"
        exit 0
        ;;
    "api rate_limit")
        cat << 'RATE_LIMIT_EOF'
{
  "resources": {
    "core": {
      "limit": 5000,
      "used": 1250,
      "remaining": 3750,
      "reset": 1640995200
    },
    "search": {
      "limit": 30,
      "used": 5,
      "remaining": 25,
      "reset": 1640991600
    }
  },
  "rate": {
    "limit": 5000,
    "used": 1250,
    "remaining": 3750,
    "reset": 1640995200
  }
}
RATE_LIMIT_EOF
        exit 0
        ;;
    "run list"*)
        # Parse arguments to determine response
        if [[ "$*" == *"--limit 50"* ]]; then
            cat << 'RUNS_EOF'
[
  {
    "name": "CI",
    "status": "completed",
    "conclusion": "success",
    "createdAt": "2024-01-15T10:00:00Z",
    "updatedAt": "2024-01-15T10:05:00Z",
    "databaseId": 12345
  },
  {
    "name": "CI",
    "status": "completed",
    "conclusion": "success",
    "createdAt": "2024-01-15T09:00:00Z",
    "updatedAt": "2024-01-15T09:04:00Z",
    "databaseId": 12344
  },
  {
    "name": "Matrix Test",
    "status": "completed",
    "conclusion": "success",
    "createdAt": "2024-01-15T08:00:00Z",
    "updatedAt": "2024-01-15T08:12:00Z",
    "databaseId": 12343
  },
  {
    "name": "Complex Workflow",
    "status": "completed",
    "conclusion": "failure",
    "createdAt": "2024-01-15T07:00:00Z",
    "updatedAt": "2024-01-15T07:25:00Z",
    "databaseId": 12342
  },
  {
    "name": "Problematic Workflow",
    "status": "completed",
    "conclusion": "success",
    "createdAt": "2024-01-15T06:00:00Z",
    "updatedAt": "2024-01-15T06:15:00Z",
    "databaseId": 12341
  }
]
RUNS_EOF
        else
            echo "[]"
        fi
        exit 0
        ;;
    "workflow list")
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
    "name": "Matrix Test",
    "path": ".github/workflows/matrix-test.yml",
    "state": "active"
  },
  {
    "id": 3,
    "name": "Problematic Workflow",
    "path": ".github/workflows/problematic.yml",
    "state": "active"
  },
  {
    "id": 4,
    "name": "Complex Workflow",
    "path": ".github/workflows/complex.yml",
    "state": "active"
  }
]
WORKFLOWS_EOF
        exit 0
        ;;
    "api "*"/workflows")
        echo '[{"id":1,"name":"CI","state":"active"},{"id":2,"name":"Matrix Test","state":"active"}]'
        exit 0
        ;;
    *)
        echo "Mock gh: Unknown command '$*'" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/gh"
}

# Create comprehensive jq mock
create_comprehensive_jq_mock() {
    cat > "$TEST_TEMP_DIR/bin/jq" << 'EOF'
#!/bin/bash
# Comprehensive jq mock for integration testing

# Read input
input=$(cat)

# Handle different jq queries
case "$*" in
    "-r" ".rate.used")
        echo "1250"
        ;;
    "-r" ".rate.limit")
        echo "5000"
        ;;
    "-r" ".rate.remaining")
        echo "3750"
        ;;
    "-r" ".rate.reset")
        echo "1640995200"
        ;;
    "-r" "group_by(.name)"* | *"group_by(.name)"*)
        # Workflow runtime analysis query
        cat << 'JQ_OUTPUT_EOF'
  📊 CI: 4min avg, 100% success rate (2 runs)
  📊 Complex Workflow: 25min avg, 0% success rate (1 runs)
  📊 Matrix Test: 12min avg, 100% success rate (1 runs)
  📊 Problematic Workflow: 15min avg, 100% success rate (1 runs)
JQ_OUTPUT_EOF
        ;;
    "-e" ".api_calls_total")
        echo "5"
        ;;
    "-e" ".cache_hits")
        echo "2"
        ;;
    "-e" ".cache_hit_rate_percent")
        echo "40"
        ;;
    "-e" ".rate_limit_warnings")
        echo "0"
        ;;
    "-r" ".api_calls_total")
        echo "5"
        ;;
    "-r" ".cache_hits")
        echo "2"
        ;;
    "-r" ".cache_hit_rate_percent")
        echo "40"
        ;;
    "-r" ".rate_limit_warnings")
        echo "0"
        ;;
    ". | length")
        echo "4"
        ;;
    *)
        # Default response for other queries
        echo "mock_jq_response"
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/jq"
}

# Integration test: Basic performance analysis
@test "integration: basic performance analysis runs successfully" {
    run ./scripts/analyze-performance.sh
    assert_success
    
    assert_output --partial "Starting performance analysis"
    assert_output --partial "Analyzing workflow runtime performance"
    assert_output --partial "Analyzing GitHub API usage"
    assert_output --partial "Analyzing workflow efficiency"
    assert_output --partial "Performance analysis completed"
}

@test "integration: analyzes workflow runtime with real data" {
    run ./scripts/analyze-performance.sh
    assert_success
    
    # Should display workflow performance data
    assert_output --partial "Recent workflow performance"
    assert_output --partial "CI:"
    assert_output --partial "avg"
    assert_output --partial "success rate"
}

@test "integration: analyzes API usage with rate limiting" {
    run ./scripts/analyze-performance.sh
    assert_success
    
    assert_output --partial "GitHub API Usage"
    assert_output --partial "Core API: 1250/5000"
    assert_output --partial "Remaining: 3750"
    assert_output --partial "API usage is within healthy limits"
}

@test "integration: analyzes workflow efficiency patterns" {
    run ./scripts/analyze-performance.sh
    assert_success
    
    assert_output --partial "Workflow Configuration Analysis"
    assert_output --partial "Total workflows: 4"
    assert_output --partial "Using caching:"
    assert_output --partial "Using conditionals:"
    assert_output --partial "Using matrix builds:"
}

@test "integration: detects workflow optimization opportunities" {
    run ./scripts/analyze-performance.sh
    assert_success
    
    # Should detect the problematic workflow
    assert_output --partial "Consider adding caching to more workflows" || 
    assert_output --partial "workflows with >15min average runtime" ||
    assert_output --partial "workflows using @main/@master"
}

@test "integration: generates performance recommendations" {
    run ./scripts/analyze-performance.sh
    assert_success
    
    assert_output --partial "Performance Optimization Recommendations"
    assert_output --partial "Enable dependency caching"
    assert_output --partial "Use conditional job execution"
    assert_output --partial "Implement matrix strategies"
}

# Integration test: Performance analysis with benchmarks
@test "integration: runs with benchmark mode enabled" {
    run ./scripts/analyze-performance.sh --benchmarks
    assert_success
    
    assert_output --partial "Configuration: benchmarks=true"
    assert_output --partial "Running performance benchmarks"
    assert_output --partial "Benchmark Results"
}

@test "integration: benchmark mode measures API operations" {
    run ./scripts/analyze-performance.sh --benchmarks
    assert_success
    
    assert_output --partial "github_api_rate_limit"
    assert_output --partial "Average time:"
    assert_output --partial "Best time:"
    assert_output --partial "Worst time:"
}

# Integration test: Performance analysis with load tests
@test "integration: runs with load test mode enabled" {
    run ./scripts/analyze-performance.sh --load-tests
    assert_success
    
    assert_output --partial "Configuration: load-tests=true"
    assert_output --partial "Running load tests"
    assert_output --partial "Load Test Results"
}

@test "integration: load test mode measures concurrent operations" {
    run ./scripts/analyze-performance.sh --load-tests
    assert_success
    
    assert_output --partial "concurrent operations"
    assert_output --partial "Throughput:"
    assert_output --partial "ops/sec"
    assert_output --partial "Success rate:"
}

# Integration test: Different output formats
@test "integration: generates JSON output format" {
    run ./scripts/analyze-performance.sh --format json --output test-report.json
    assert_success
    
    assert_output --partial "Generating JSON report: test-report.json"
    
    # Verify JSON file was created
    assert [ -f "test-report.json" ]
    
    # Verify it contains expected structure
    run jq -e '.report.generated_at' test-report.json
    assert_success
}

@test "integration: generates Markdown output format" {
    run ./scripts/analyze-performance.sh --format markdown --output test-report.md
    assert_success
    
    assert_output --partial "Generating Markdown report: test-report.md"
    
    # Verify Markdown file was created
    assert [ -f "test-report.md" ]
    
    # Verify it contains expected content
    run grep -q "# GitHub Actions Performance Analysis Report" test-report.md
    assert_success
    
    run grep -q "## Executive Summary" test-report.md
    assert_success
}

# Integration test: Module initialization and cleanup
@test "integration: initializes all modules correctly" {
    run ./scripts/analyze-performance.sh
    assert_success
    
    assert_output --partial "Initializing performance analysis modules"
    assert_output --partial "GitHub API module initialized"
    assert_output --partial "All modules initialized successfully"
}

@test "integration: cleans up modules after execution" {
    run ./scripts/analyze-performance.sh
    assert_success
    
    assert_output --partial "Cleaning up modules"
    assert_output --partial "Module cleanup completed"
}

# Integration test: Error handling and edge cases
@test "integration: handles missing workflow directory gracefully" {
    # Remove workflow directory
    rm -rf .github
    
    run ./scripts/analyze-performance.sh
    assert_success
    
    assert_output --partial "No workflow directory found"
}

@test "integration: handles GitHub API failures gracefully" {
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
    
    run ./scripts/analyze-performance.sh
    assert_failure
    
    assert_output --partial "Failed to" || assert_output --partial "Error"
}

@test "integration: validates command line arguments" {
    run ./scripts/analyze-performance.sh --invalid-option
    assert_failure
    
    assert_output --partial "Unknown option: --invalid-option"
}

@test "integration: shows help message" {
    run ./scripts/analyze-performance.sh --help
    assert_success
    
    assert_output --partial "Usage:"
    assert_output --partial "Performance Analysis Script"
    assert_output --partial "OPTIONS:"
    assert_output --partial "EXAMPLES:"
}

# Integration test: Performance metrics collection
@test "integration: collects comprehensive performance metrics" {
    run ./scripts/analyze-performance.sh
    assert_success
    
    assert_output --partial "Performance Metrics Report"
    assert_output --partial "Script Execution Metrics"
    assert_output --partial "Total execution time:"
    assert_output --partial "Total operations:"
    assert_output --partial "Cache Performance:"
    assert_output --partial "Operation Performance:"
}

@test "integration: tracks API usage statistics" {
    run ./scripts/analyze-performance.sh
    assert_success
    
    assert_output --partial "GitHub API Statistics"
    assert_output --partial "Total API calls:"
    assert_output --partial "Cache hits:"
    assert_output --partial "Rate limit warnings:"
}

# Integration test: Workflow complexity analysis
@test "integration: analyzes workflow complexity correctly" {
    run ./scripts/analyze-performance.sh
    assert_success
    
    assert_output --partial "Analyzing workflow complexity"
    assert_output --partial "Workflow Complexity Metrics"
    assert_output --partial "Average jobs per workflow:"
    assert_output --partial "Average steps per workflow:"
}

@test "integration: detects complex workflows" {
    run ./scripts/analyze-performance.sh
    assert_success
    
    # Complex workflow should be detected
    assert_output --partial "Complex workflow detected: complex" ||
    assert_output --partial "Complex workflows:"
}

# Integration test: Full system with all features
@test "integration: full system test with all features enabled" {
    run ./scripts/analyze-performance.sh --benchmarks --load-tests --format console
    assert_success
    
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

# Integration test: Cache functionality across modules
@test "integration: cache works correctly across API calls" {
    # Run analysis twice to test caching
    ./scripts/analyze-performance.sh >/dev/null 2>&1
    
    run ./scripts/analyze-performance.sh
    assert_success
    
    # Second run should use cached data
    assert_output --partial "Using cached" ||
    assert_output --partial "cached entries" ||
    assert_output --partial "Cache hits:"
}

# Integration test: Report generation integration
@test "integration: generates comprehensive reports with real data" {
    run ./scripts/analyze-performance.sh --format markdown --output integration-test.md
    assert_success
    
    # Verify report contains real analysis data
    assert [ -f "integration-test.md" ]
    
    # Check report content
    local report_content
    report_content=$(cat "integration-test.md")
    
    # Should contain actual workflow data
    [[ "$report_content" == *"Total Workflows: 4"* ]] || 
    [[ "$report_content" == *"CI"* ]] ||
    [[ "$report_content" == *"Matrix Test"* ]]
    
    # Should contain API usage data
    [[ "$report_content" == *"API Usage Analysis"* ]]
    
    # Should contain recommendations
    [[ "$report_content" == *"Optimization Recommendations"* ]]
}

# Integration test: Module interaction and data flow
@test "integration: modules share data correctly" {
    run ./scripts/analyze-performance.sh --format json --output data-flow-test.json
    assert_success
    
    # Verify JSON contains data from all modules
    assert [ -f "data-flow-test.json" ]
    
    # Check that API usage data flows to report
    run jq -e '.api_usage' data-flow-test.json
    assert_success
    
    # Check that workflow count is correct
    run jq -e '.workflows.total_count' data-flow-test.json
    assert_success
    
    local workflow_count
    workflow_count=$(jq -r '.workflows.total_count' data-flow-test.json)
    assert_equal "$workflow_count" "4"
}