#!/usr/bin/env bats
#
# Tests for analyze-performance.sh script

# Setup and teardown
setup() {
    load 'helpers/test-helpers'
    setup_script_test
    
    # Copy the script to test location
    cp "$BATS_TEST_DIRNAME/../scripts/analyze-performance.sh" "$TEST_TEMP_DIR/analyze-performance.sh"
    chmod +x "$TEST_TEMP_DIR/analyze-performance.sh"
    
    SCRIPT_UNDER_TEST="$TEST_TEMP_DIR/analyze-performance.sh"
}

teardown() {
    teardown_script_test
}

@test "analyze-performance.sh: script exists and is executable" {
    assert_file_exists "$SCRIPT_UNDER_TEST"
    assert_file_executable "$SCRIPT_UNDER_TEST"
}

@test "analyze-performance.sh: displays help information correctly" {
    run bash -c "head -10 '$SCRIPT_UNDER_TEST'"
    assert_success
    assert_output --partial "Performance Analysis Script"
    assert_output --partial "Claude Code Auto Workflows"
}

@test "analyze-performance.sh: fails when gh CLI is not available" {
    # Remove gh from PATH
    export PATH="/usr/bin:/bin"
    
    run "$SCRIPT_UNDER_TEST"
    assert_failure
    assert_output --partial "GitHub CLI (gh) is required"
}

@test "analyze-performance.sh: handles successful execution with mocked gh CLI" {
    local responses_dir
    responses_dir=$(create_github_api_responses)
    
    create_gh_mock "$responses_dir/workflow_runs.json" 0
    create_jq_mock '[{"name":"CI","count":5,"avg_duration":3,"success_rate":80}]'
    
    run "$SCRIPT_UNDER_TEST"
    assert_success
    assert_output --partial "Starting performance analysis"
    assert_output --partial "Performance analysis completed"
}

@test "analyze-performance.sh: analyze_workflow_runtime function" {
    local responses_dir
    responses_dir=$(create_github_api_responses)
    
    create_gh_mock "$responses_dir/workflow_runs.json" 0
    create_jq_mock 'CI: 3min avg, 80% success rate (5 runs)'
    
    run bash -c "source '$SCRIPT_UNDER_TEST'; analyze_workflow_runtime"
    assert_success
    assert_output --partial "Analyzing workflow runtime performance"
}

@test "analyze-performance.sh: analyze_workflow_runtime handles no data" {
    create_gh_mock "/dev/null" 0
    create_jq_mock "[]"
    
    run bash -c "source '$SCRIPT_UNDER_TEST'; analyze_workflow_runtime"
    assert_success
    assert_output --partial "No workflow run data available"
}

@test "analyze-performance.sh: analyze_api_usage function" {
    create_gh_mock "" 0
    
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        # Override gh api call for testing
        gh() {
            if [[ \"\$1 \$2\" == \"api rate_limit\" ]]; then
                echo '{\"rate\":{\"used\":1000,\"limit\":5000,\"remaining\":4000}}'
            fi
        }
        export -f gh
        analyze_api_usage
    "
    assert_success
    assert_output --partial "GitHub API Usage"
    assert_output --partial "Core API: 1000/5000"
}

@test "analyze-performance.sh: analyze_api_usage detects high usage" {
    create_gh_mock "" 0
    
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        # Override gh api call for high usage scenario
        gh() {
            if [[ \"\$1 \$2\" == \"api rate_limit\" ]]; then
                echo '{\"rate\":{\"used\":4500,\"limit\":5000,\"remaining\":500}}'
            fi
        }
        export -f gh
        analyze_api_usage
    "
    assert_success
    assert_output --partial "High API usage detected"
    assert_output --partial "API Optimization Suggestions"
}

@test "analyze-performance.sh: analyze_workflow_efficiency function" {
    local workflow_dir
    workflow_dir=$(create_mock_workflows)
    cd "$TEST_TEMP_DIR"
    
    run bash -c "source '$SCRIPT_UNDER_TEST'; analyze_workflow_efficiency"
    assert_success
    assert_output --partial "Analyzing workflow efficiency"
    assert_output --partial "Total workflows:"
}

@test "analyze-performance.sh: analyze_workflow_efficiency detects caching" {
    local workflow_dir="$TEST_TEMP_DIR/.github/workflows"
    mkdir -p "$workflow_dir"
    
    # Create workflow with caching
    cat > "$workflow_dir/cached.yml" << 'EOF'
name: Cached Workflow
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/cache@v3
        with:
          path: node_modules
          key: ${{ runner.os }}-node-${{ hashFiles('package-lock.json') }}
EOF
    
    cd "$TEST_TEMP_DIR"
    run bash -c "source '$SCRIPT_UNDER_TEST'; analyze_workflow_efficiency"
    assert_success
    assert_output --partial "Using caching: 1/"
}

@test "analyze-performance.sh: analyze_workflow_efficiency detects conditionals" {
    local workflow_dir="$TEST_TEMP_DIR/.github/workflows"
    mkdir -p "$workflow_dir"
    
    # Create workflow with conditionals
    cat > "$workflow_dir/conditional.yml" << 'EOF'
name: Conditional Workflow
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    if: github.event_name == 'push'
    steps:
      - uses: actions/checkout@v4
EOF
    
    cd "$TEST_TEMP_DIR"
    run bash -c "source '$SCRIPT_UNDER_TEST'; analyze_workflow_efficiency"
    assert_success
    assert_output --partial "Using conditionals: 1/"
}

@test "analyze-performance.sh: analyze_workflow_efficiency detects matrix builds" {
    local workflow_dir="$TEST_TEMP_DIR/.github/workflows"
    mkdir -p "$workflow_dir"
    
    # Create workflow with matrix strategy
    cat > "$workflow_dir/matrix.yml" << 'EOF'
name: Matrix Workflow
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node-version: [16, 18, 20]
    steps:
      - uses: actions/checkout@v4
EOF
    
    cd "$TEST_TEMP_DIR"
    run bash -c "source '$SCRIPT_UNDER_TEST'; analyze_workflow_efficiency"
    assert_success
    assert_output --partial "Using matrix builds: 1/"
}

@test "analyze-performance.sh: generate_performance_report function" {
    run bash -c "source '$SCRIPT_UNDER_TEST'; generate_performance_report"
    assert_success
    assert_output --partial "Performance Optimization Recommendations"
    assert_output --partial "Enable dependency caching"
    assert_output --partial "Use conditional job execution"
    assert_output --partial "Implement matrix strategies"
}

@test "analyze-performance.sh: handles missing workflow directory" {
    # Ensure no workflow directory exists
    rm -rf "$TEST_TEMP_DIR/.github"
    cd "$TEST_TEMP_DIR"
    
    run bash -c "source '$SCRIPT_UNDER_TEST'; analyze_workflow_efficiency"
    assert_success
    assert_output --partial "No workflow directory found"
}

@test "analyze-performance.sh: handles API failure gracefully" {
    create_gh_mock "" 1  # Exit code 1 for failure
    
    run "$SCRIPT_UNDER_TEST"
    assert_failure
    assert_output --partial "GitHub CLI (gh) is required"
}

@test "analyze-performance.sh: logging functions work correctly" {
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        log_info 'Test info message'
        log_warn 'Test warning message'  
        log_error 'Test error message'
        log_header 'Test header message'
    "
    assert_success
    assert_output --partial "[INFO] Test info message"
    assert_output --partial "[WARN] Test warning message"
    assert_output --partial "[ERROR] Test error message"
    assert_output --partial "[ANALYSIS] Test header message"
}

@test "analyze-performance.sh: main function executes all components" {
    local responses_dir
    responses_dir=$(create_github_api_responses)
    
    create_gh_mock "$responses_dir/workflow_runs.json" 0
    create_jq_mock '[{"name":"CI","count":5,"avg_duration":3,"success_rate":80}]'
    create_mock_workflows
    cd "$TEST_TEMP_DIR"
    
    run "$SCRIPT_UNDER_TEST"
    assert_success
    assert_output --partial "Starting performance analysis"
    assert_output --partial "Analyzing workflow runtime performance"
    assert_output --partial "Analyzing GitHub API usage"
    assert_output --partial "Analyzing workflow efficiency"
    assert_output --partial "Performance Optimization Recommendations"
    assert_output --partial "Performance analysis completed"
}