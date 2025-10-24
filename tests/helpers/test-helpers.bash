#!/bin/bash
#
# Test helpers for Claude Code Auto Workflows BATS tests

# Load BATS libraries from npm packages
# Try to load from the proper npm path
if [[ -f "../node_modules/bats-support/load.bash" ]]; then
    load "../node_modules/bats-support/load.bash"
    load "../node_modules/bats-assert/load.bash"
elif [[ -f "${BATS_LIB_PATH:-./node_modules}/bats-support/load.bash" ]]; then
    load "${BATS_LIB_PATH:-./node_modules}/bats-support/load.bash"
    load "${BATS_LIB_PATH:-./node_modules}/bats-assert/load.bash"
else
    # Fallback - use basic assertions
    assert_success() { [[ "$status" -eq 0 ]]; }
    assert_failure() { [[ "$status" -ne 0 ]]; }
    assert_output() { 
        if [[ "$1" == "--partial" ]]; then
            [[ "$output" == *"$2"* ]]
        else
            [[ "$output" == "$1" ]]
        fi
    }
    refute_output() {
        if [[ "$1" == "--partial" ]]; then
            [[ "$output" != *"$2"* ]]
        else
            [[ "$output" != "$1" ]]
        fi
    }
    assert_equal() { [[ "$1" == "$2" ]]; }
    fail() { echo "FAIL: $1" >&2; return 1; }
fi

# Source test constants
source "${BASH_SOURCE[0]%/*}/test-constants.bash"

# Source integration test helpers  
source "${BASH_SOURCE[0]%/*}/test-integration-helpers.bash"

# Test environment setup
setup_test_environment() {
    export TEST_TEMP_DIR="$(mktemp -d)"
    export ORIGINAL_PATH="$PATH"
    export PATH="$TEST_TEMP_DIR/bin:$PATH"
    
    # Create mock bin directory
    mkdir -p "$TEST_TEMP_DIR/bin"
    
    # Set environment variables for testing
    export GITHUB_TOKEN="test-token"
    export GITHUB_REPOSITORY="test/repo"
    export GITHUB_API_URL="https://api.github.com"
}

teardown_test_environment() {
    if [[ -n "${TEST_TEMP_DIR:-}" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
    export PATH="$ORIGINAL_PATH"
}

# Generic mock command builder to reduce code duplication
create_command_mock() {
    local command_name="$1"
    local mock_content="$2"
    local exit_code="${3:-0}"
    
    cat > "$TEST_TEMP_DIR/bin/$command_name" << EOF
#!/bin/bash
# Mock $command_name for testing
$mock_content
exit $exit_code
EOF
    chmod +x "$TEST_TEMP_DIR/bin/$command_name"
}

# Mock GitHub CLI
create_gh_mock() {
    local response_file="$1"
    local exit_code="${2:-0}"
    
    cat > "$TEST_TEMP_DIR/bin/gh" << EOF
#!/bin/bash
# Mock GitHub CLI for testing

case "\$1 \$2" in
    "auth status")
        exit $exit_code
        ;;
    "repo view")
        exit $exit_code
        ;;
    "run list")
        if [[ -f "$response_file" ]]; then
            cat "$response_file"
        else
            echo "[]"
        fi
        exit $exit_code
        ;;
    "api rate_limit")
        echo '{"rate":{"limit":5000,"used":100,"remaining":4900}}'
        exit $exit_code
        ;;
    "label list")
        echo '[{"name":"bug","color":"d73a4a"},{"name":"enhancement","color":"a2eeef"}]'
        exit $exit_code
        ;;
    "label create"*)
        exit $exit_code
        ;;
    "label edit"*)
        exit $exit_code
        ;;
    "workflow list")
        echo '[{"name":"CI","id":123},{"name":"Deploy","id":456}]'
        exit $exit_code
        ;;
    *)
        if [[ -f "$response_file" ]]; then
            cat "$response_file"
        fi
        exit $exit_code
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/gh"
}

# Mock jq command
create_jq_mock() {
    local response="$1"
    
    create_command_mock "jq" "echo '$response'"
}

# Mock yq command
create_yq_mock() {
    local exit_code="${1:-0}"
    
    cat > "$TEST_TEMP_DIR/bin/yq" << EOF
#!/bin/bash
# Mock yq for testing
case "\$1 \$2" in
    "eval .")
        # Return valid YAML structure for syntax check
        echo "name: Test Workflow"
        echo "on: push"
        echo "jobs:"
        echo "  test:"
        echo "    runs-on: ubuntu-latest"
        echo "    steps:"
        echo "      - uses: actions/checkout@v2"
        ;;
    "eval .name")
        echo "Test Workflow"
        ;;
    "eval .on")
        echo "push"
        ;;
    "eval .jobs")
        echo "test: {runs-on: ubuntu-latest, steps: [{uses: actions/checkout@v2}]}"
        ;;
    *)
        echo "mock yq output"
        ;;
esac
exit $exit_code
EOF
    chmod +x "$TEST_TEMP_DIR/bin/yq"
}

# Mock python3 command
create_python3_mock() {
    local exit_code="${1:-0}"
    
    create_command_mock "python3" "" "$exit_code"
}

# Create mock workflow directory
create_mock_workflows() {
    local workflow_dir="$TEST_TEMP_DIR/.github/workflows"
    mkdir -p "$workflow_dir"
    
    # Create valid workflow file
    cat > "$workflow_dir/test.yml" << 'EOF'
name: Test Workflow
on: [push, pull_request]
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Test
        run: echo "test"
        if: github.event_name == 'push'
EOF

    # Create workflow with issues
    cat > "$workflow_dir/problematic.yml" << 'EOF'
name: Problematic Workflow
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@main
      - name: Test with secret
        run: echo "secret=hardcoded_value_123456789"
        env:
          TOKEN: ${{ secrets.GITHUB_TOKEN }}
EOF

    echo "$workflow_dir"
}

# Create test repository structure
create_test_repo() {
    local repo_dir="$TEST_TEMP_DIR/repo"
    mkdir -p "$repo_dir"
    cd "$repo_dir"
    
    git init
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create basic structure
    mkdir -p scripts .github/workflows
    
    echo "$repo_dir"
}

# Mock date command for consistent testing
create_date_mock() {
    local mock_date="${1:-2024-01-15}"
    
    cat > "$TEST_TEMP_DIR/bin/date" << EOF
#!/bin/bash
# Mock date for testing
case "\$*" in
    "-d "* "days ago --iso-8601")
        echo "$mock_date"
        ;;
    "-d "* "days ago" "'+%Y-%m-%d'")
        echo "$mock_date"
        ;;
    *)
        /bin/date "\$@"
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/date"
}

# Create mock response files
create_github_api_responses() {
    local responses_dir="$TEST_TEMP_DIR/responses"
    mkdir -p "$responses_dir"
    
    # Workflow runs response
    cat > "$responses_dir/workflow_runs.json" << 'EOF'
[
  {
    "name": "CI",
    "status": "completed",
    "conclusion": "success",
    "createdAt": "2024-01-01T10:00:00Z",
    "updatedAt": "2024-01-01T10:05:00Z",
    "databaseId": 123
  },
  {
    "name": "Deploy",
    "status": "completed",
    "conclusion": "failure",
    "createdAt": "2024-01-01T11:00:00Z",
    "updatedAt": "2024-01-01T11:03:00Z",
    "databaseId": 124
  }
]
EOF

    # Rate limit response
    cat > "$responses_dir/rate_limit.json" << 'EOF'
{
  "rate": {
    "limit": 5000,
    "used": 2500,
    "remaining": 2500,
    "reset": 1640995200
  }
}
EOF

    echo "$responses_dir"
}

# Assertion helpers
assert_log_contains() {
    local expected="$1"
    local log_output="$2"
    
    if [[ "$log_output" != *"$expected"* ]]; then
        fail "Expected log to contain: $expected"
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    
    if [[ "$actual" != "$expected" ]]; then
        fail "Expected exit code $expected, got $actual"
    fi
}

# Skip test if command not available
skip_if_command_missing() {
    local command="$1"
    local reason="${2:-Command $command not available}"
    
    if ! command -v "$command" >/dev/null 2>&1; then
        skip "$reason"
    fi
}

# Common setup for script tests
setup_script_test() {
    setup_test_environment
    create_test_repo
    cd "$TEST_TEMP_DIR/repo"
}

# Common teardown for script tests
teardown_script_test() {
    teardown_test_environment
}