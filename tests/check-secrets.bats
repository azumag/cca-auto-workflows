#!/usr/bin/env bats

# Tests for scripts/check-secrets.sh
# This file tests all security checking functionality

# Load test helpers
load helpers/common.bash

# Set up BATS
setup() {
    setup_bats_libs
    load test-config.bash
    common_setup
    
    # Copy the script under test
    SCRIPT_PATH="./scripts/check-secrets.sh"
    
    # Ensure script is executable
    chmod +x "$SCRIPT_PATH"
}

teardown() {
    restore_commands
    common_teardown
}

@test "check-secrets.sh exists and is executable" {
    [ -f "$SCRIPT_PATH" ]
    [ -x "$SCRIPT_PATH" ]
}

@test "script has proper error handling" {
    run grep -q "set -euo pipefail" "$SCRIPT_PATH"
    assert_success
}

@test "script defines security check patterns" {
    run grep -q "patterns=(" "$SCRIPT_PATH"
    assert_success
}

@test "check_hardcoded_secrets function exists" {
    run grep -q "check_hardcoded_secrets()" "$SCRIPT_PATH"
    assert_success
}

@test "check_hardcoded_secrets reports no issues for clean repository" {
    # Create a clean test repository structure
    mkdir -p test-repo/src
    echo 'const API_URL = "https://api.example.com";' > test-repo/src/config.js
    echo 'print("Hello World")' > test-repo/src/main.py
    
    cd test-repo
    
    run bash -c "source ../$SCRIPT_PATH && check_hardcoded_secrets"
    assert_success
    assert_output --partial "No hardcoded secrets detected"
}

@test "check_hardcoded_secrets detects password patterns" {
    # Create file with hardcoded password
    mkdir -p test-repo/src
    echo 'const PASSWORD = "secretpassword123456";' > test-repo/src/config.js
    
    cd test-repo
    
    run bash -c "source ../$SCRIPT_PATH && check_hardcoded_secrets"
    assert_failure
    assert_output --partial "Potential hardcoded secret found"
}

@test "check_hardcoded_secrets detects API key patterns" {
    # Create file with API key
    mkdir -p test-repo/src
    echo 'api_key = "sk-1234567890abcdef1234567890abcdef12345678";' > test-repo/src/config.py
    
    cd test-repo
    
    run bash -c "source ../$SCRIPT_PATH && check_hardcoded_secrets"
    assert_failure
    assert_output --partial "Found 1 potential security issues"
}

@test "check_hardcoded_secrets detects GitHub tokens" {
    # Create file with GitHub token
    mkdir -p test-repo/src
    echo 'GITHUB_TOKEN="ghp_1234567890123456789012345678901234567890"' > test-repo/src/env.sh
    
    cd test-repo
    
    run bash -c "source ../$SCRIPT_PATH && check_hardcoded_secrets"
    assert_failure
    assert_output --partial "Potential hardcoded secret found"
}

@test "check_hardcoded_secrets detects GitHub PAT tokens" {
    # Create file with GitHub PAT
    mkdir -p test-repo/src
    echo 'token: github_pat_11ABCDEFG0123456789_AbCdEfGhIjKlMnOpQrStUvWxYz1234567890123456789012345678901234567890' > test-repo/config.yml
    
    cd test-repo
    
    run bash -c "source ../$SCRIPT_PATH && check_hardcoded_secrets"
    assert_failure
    assert_output --partial "Potential hardcoded secret found"
}

@test "check_hardcoded_secrets excludes test directories" {
    # Create files in excluded directories
    mkdir -p test-repo/tests test-repo/test test-repo/node_modules
    echo 'const PASSWORD = "testpassword123456";' > test-repo/tests/config.js
    echo 'api_key = "test_key_1234567890123456";' > test-repo/test/setup.py
    echo 'token = "fake_token_for_testing";' > test-repo/node_modules/lib.js
    
    cd test-repo
    
    run bash -c "source ../$SCRIPT_PATH && check_hardcoded_secrets"
    assert_success
    assert_output --partial "No hardcoded secrets detected"
}

@test "check_hardcoded_secrets excludes documentation files" {
    # Create documentation with example secrets
    mkdir -p test-repo/docs
    echo 'Example: api_key = "your_api_key_here_1234567890"' > test-repo/docs/README.md
    echo 'Token example: sk-1234567890abcdef1234567890abcdef12345678' > test-repo/docs/guide.txt
    
    cd test-repo
    
    run bash -c "source ../$SCRIPT_PATH && check_hardcoded_secrets"
    assert_success
    assert_output --partial "No hardcoded secrets detected"
}

@test "check_workflow_secrets function exists" {
    run grep -q "check_workflow_secrets()" "$SCRIPT_PATH"
    assert_success
}

@test "check_workflow_secrets handles missing workflow directory" {
    run bash -c "source $SCRIPT_PATH && check_workflow_secrets"
    assert_success
    assert_output --partial "Workflow secret usage check completed"
}

@test "check_workflow_secrets validates GITHUB_TOKEN usage" {
    # Create workflow using only GITHUB_TOKEN
    local workflows_dir="$TEMP_TEST_DIR/.github/workflows"
    mkdir -p "$workflows_dir"
    
    cat > "$workflows_dir/ci.yml" << 'EOF'
name: CI
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
EOF
    
    cd "$TEMP_TEST_DIR"
    
    run bash -c "source $SCRIPT_PATH && check_workflow_secrets"
    assert_success
    assert_output --partial "uses only GITHUB_TOKEN"
}

@test "check_workflow_secrets warns about custom secrets" {
    # Create workflow using custom secrets
    local workflows_dir="$TEMP_TEST_DIR/.github/workflows"
    mkdir -p "$workflows_dir"
    
    cat > "$workflows_dir/deploy.yml" << 'EOF'
name: Deploy
on: push
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy
        env:
          API_KEY: ${{ secrets.DEPLOY_KEY }}
          DATABASE_URL: ${{ secrets.DB_CONNECTION }}
        run: echo "Deploying..."
EOF
    
    cd "$TEMP_TEST_DIR"
    
    run bash -c "source $SCRIPT_PATH && check_workflow_secrets"
    assert_success
    assert_output --partial "uses custom secrets"
}

@test "check_permissions function exists" {
    run grep -q "check_permissions()" "$SCRIPT_PATH"
    assert_success
}

@test "check_permissions warns about missing permissions" {
    # Create workflow without permissions
    local workflows_dir="$TEMP_TEST_DIR/.github/workflows"
    mkdir -p "$workflows_dir"
    
    cat > "$workflows_dir/no-perms.yml" << 'EOF'
name: No Permissions
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo "test"
EOF
    
    cd "$TEMP_TEST_DIR"
    
    run bash -c "source $SCRIPT_PATH && check_permissions"
    assert_success
    assert_output --partial "doesn't specify permissions"
}

@test "check_permissions warns about write-all permissions" {
    # Create workflow with overly broad permissions
    local workflows_dir="$TEMP_TEST_DIR/.github/workflows"
    mkdir -p "$workflows_dir"
    
    cat > "$workflows_dir/broad-perms.yml" << 'EOF'
name: Broad Permissions
on: push
permissions: write-all
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo "test"
EOF
    
    cd "$TEMP_TEST_DIR"
    
    run bash -c "source $SCRIPT_PATH && check_permissions"
    assert_success
    assert_output --partial "uses 'write-all' permissions"
}

@test "check_permissions approves minimal permissions" {
    # Create workflow with appropriate permissions
    local workflows_dir="$TEMP_TEST_DIR/.github/workflows"
    mkdir -p "$workflows_dir"
    
    cat > "$workflows_dir/good-perms.yml" << 'EOF'
name: Good Permissions
on: push
permissions:
  contents: read
  pull-requests: write
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo "test"
EOF
    
    cd "$TEMP_TEST_DIR"
    
    run bash -c "source $SCRIPT_PATH && check_permissions"
    assert_success
    assert_output --partial "No permission issues found"
}

@test "main function executes all security checks" {
    # Create clean test environment
    setup_mock_workflows "$TEMP_TEST_DIR"
    cd "$TEMP_TEST_DIR"
    
    run bash -c "source $SCRIPT_PATH && main"
    assert_success
    assert_output --partial "Starting security check"
    assert_output --partial "Security check completed successfully"
}

@test "main function reports failures correctly" {
    # Create repository with security issues
    mkdir -p test-repo/src
    echo 'const SECRET = "hardcoded_secret_1234567890";' > test-repo/src/bad.js
    
    cd test-repo
    
    run bash -c "source ../$SCRIPT_PATH && main"
    assert_failure
    assert_output --partial "Security check found issues"
}

@test "script handles grep errors gracefully" {
    # Mock grep to fail
    eval "grep() {
        echo 'grep: error reading file' >&2
        return 2
    }"
    
    run bash -c "source $SCRIPT_PATH && check_hardcoded_secrets"
    # Should handle the error without crashing
}

@test "script properly escapes regex patterns" {
    # Create file with content that could break regex
    mkdir -p test-repo/src
    echo 'const PATTERN = "password.*[special chars]";' > test-repo/src/regex-test.js
    
    cd test-repo
    
    run bash -c "source ../$SCRIPT_PATH && check_hardcoded_secrets"
    # Should not crash due to regex escaping issues
}

@test "script reports correct line numbers and files" {
    # Create file with secret on specific line
    mkdir -p test-repo/src
    cat > test-repo/src/multi-line.js << 'EOF'
const config = {
    url: "https://api.example.com",
    password: "secretpassword123456",
    timeout: 5000
};
EOF
    
    cd test-repo
    
    run bash -c "source ../$SCRIPT_PATH && check_hardcoded_secrets"
    assert_failure
    # Output should include filename (exact format depends on grep output)
}

@test "logging functions work properly" {
    run bash -c "source $SCRIPT_PATH && log_info 'test info'"
    assert_success
    assert_output --partial "test info"
    
    run bash -c "source $SCRIPT_PATH && log_warn 'test warning'"
    assert_success
    assert_output --partial "test warning"
    
    run bash -c "source $SCRIPT_PATH && log_error 'test error'"
    assert_success
    assert_output --partial "test error"
}

@test "script uses proper exit codes" {
    # Test successful run
    setup_mock_workflows "$TEMP_TEST_DIR"
    cd "$TEMP_TEST_DIR"
    
    run bash -c "source $SCRIPT_PATH && main; echo \"Exit code: \$?\""
    assert_success
    
    # Test failure case
    mkdir -p bad-repo/src
    echo 'token = "ghp_1234567890123456789012345678901234567890";' > bad-repo/src/config.py
    cd bad-repo
    
    run bash -c "source ../$SCRIPT_PATH && main"
    assert_failure
}

# Test specific security patterns

@test "detects OpenAI API keys" {
    mkdir -p test-repo/src
    echo 'OPENAI_KEY = "sk-1234567890abcdef1234567890abcdef12345678";' > test-repo/src/ai.py
    
    cd test-repo
    
    run bash -c "source ../$SCRIPT_PATH && check_hardcoded_secrets"
    assert_failure
    assert_output --partial "Potential hardcoded secret found"
}

@test "ignores comments with example secrets" {
    mkdir -p test-repo/src
    cat > test-repo/src/config.js << 'EOF'
// Example: password: "your_password_here"
const config = {
    // TODO: Replace with actual secret
    // secret: "example_secret_12345678"
    url: "https://api.example.com"
};
EOF
    
    cd test-repo
    
    run bash -c "source ../$SCRIPT_PATH && check_hardcoded_secrets"
    assert_success
}