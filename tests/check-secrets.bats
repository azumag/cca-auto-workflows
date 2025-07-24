#!/usr/bin/env bats
#
# Tests for check-secrets.sh script

# Setup and teardown
setup() {
    load 'helpers/test-helpers'
    setup_script_test
    
    # Copy the script to test location
    cp "$BATS_TEST_DIRNAME/../scripts/check-secrets.sh" "$TEST_TEMP_DIR/check-secrets.sh"
    chmod +x "$TEST_TEMP_DIR/check-secrets.sh"
    
    SCRIPT_UNDER_TEST="$TEST_TEMP_DIR/check-secrets.sh"
    REPO_ROOT="$TEST_TEMP_DIR/repo"
    export REPO_ROOT
}

teardown() {
    teardown_script_test
}

@test "check-secrets.sh: script exists and is executable" {
    assert_file_exists "$SCRIPT_UNDER_TEST"
    assert_file_executable "$SCRIPT_UNDER_TEST"
}

@test "check-secrets.sh: displays correct script header" {
    run bash -c "head -5 '$SCRIPT_UNDER_TEST'"
    assert_success
    assert_output --partial "Security Check Script"
    assert_output --partial "Claude Code Auto Workflows"
}

@test "check-secrets.sh: check_hardcoded_secrets detects no secrets in clean files" {
    # Create clean test files
    mkdir -p "$REPO_ROOT/src"
    echo "console.log('Hello World');" > "$REPO_ROOT/src/app.js"
    echo "const config = { debug: true };" > "$REPO_ROOT/src/config.js"
    
    cd "$REPO_ROOT"
    run bash -c "source '$SCRIPT_UNDER_TEST'; check_hardcoded_secrets"
    assert_success
    assert_output --partial "No hardcoded secrets detected"
}

@test "check-secrets.sh: check_hardcoded_secrets detects password patterns" {
    # Create file with hardcoded password
    mkdir -p "$REPO_ROOT/src"
    echo 'const password = "supersecretpassword123";' > "$REPO_ROOT/src/bad.js"
    
    cd "$REPO_ROOT"
    run bash -c "source '$SCRIPT_UNDER_TEST'; check_hardcoded_secrets"
    assert_failure
    assert_output --partial "Potential hardcoded secret found"
    assert_output --partial "Found 1 potential security issues"
}

@test "check-secrets.sh: check_hardcoded_secrets detects API key patterns" {
    # Create file with hardcoded API key
    mkdir -p "$REPO_ROOT/src"
    echo 'api_key = "sk-1234567890abcdef1234567890abcdef12345678";' > "$REPO_ROOT/src/api.js"
    
    cd "$REPO_ROOT"
    run bash -c "source '$SCRIPT_UNDER_TEST'; check_hardcoded_secrets"
    assert_failure
    assert_output --partial "Potential hardcoded secret found"
}

@test "check-secrets.sh: check_hardcoded_secrets detects GitHub tokens" {
    # Create file with GitHub personal access token
    mkdir -p "$REPO_ROOT/src"
    echo 'export GITHUB_TOKEN="ghp_abcd1234567890abcd1234567890abcd1234"' > "$REPO_ROOT/src/tokens.sh"
    
    cd "$REPO_ROOT"
    run bash -c "source '$SCRIPT_UNDER_TEST'; check_hardcoded_secrets"
    assert_failure
    assert_output --partial "Potential hardcoded secret found"
}

@test "check-secrets.sh: check_hardcoded_secrets excludes test directories" {
    # Create test file with hardcoded secret (should be ignored)
    mkdir -p "$REPO_ROOT/tests"
    echo 'password = "testsecret123456789";' > "$REPO_ROOT/tests/test.js"
    
    cd "$REPO_ROOT"
    run bash -c "source '$SCRIPT_UNDER_TEST'; check_hardcoded_secrets"
    assert_success
    assert_output --partial "No hardcoded secrets detected"
}

@test "check-secrets.sh: check_hardcoded_secrets excludes markdown files" {
    # Create markdown file with example secret (should be ignored)
    echo 'password = "examplepassword123";' > "$REPO_ROOT/README.md"
    
    cd "$REPO_ROOT"
    run bash -c "source '$SCRIPT_UNDER_TEST'; check_hardcoded_secrets"
    assert_success
    assert_output --partial "No hardcoded secrets detected"
}

@test "check-secrets.sh: check_workflow_secrets with no workflows" {
    # No workflow directory
    cd "$REPO_ROOT"
    run bash -c "source '$SCRIPT_UNDER_TEST'; check_workflow_secrets"
    assert_success
    assert_output --partial "Workflow secret usage check completed"
}

@test "check-secrets.sh: check_workflow_secrets with GITHUB_TOKEN usage" {
    # Create workflow using GITHUB_TOKEN
    mkdir -p "$REPO_ROOT/.github/workflows"
    cat > "$REPO_ROOT/.github/workflows/test.yml" << 'EOF'
name: Test
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
EOF
    
    cd "$REPO_ROOT"
    run bash -c "source '$SCRIPT_UNDER_TEST'; check_workflow_secrets"
    assert_success
    assert_output --partial "uses only GITHUB_TOKEN"
}

@test "check-secrets.sh: check_workflow_secrets with custom secrets" {
    # Create workflow using custom secrets
    mkdir -p "$REPO_ROOT/.github/workflows"
    cat > "$REPO_ROOT/.github/workflows/deploy.yml" << 'EOF'
name: Deploy
on: push
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy
        env:
          API_KEY: ${{ secrets.DEPLOY_API_KEY }}
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
        run: deploy.sh
EOF
    
    cd "$REPO_ROOT"
    run bash -c "source '$SCRIPT_UNDER_TEST'; check_workflow_secrets"
    assert_success
    assert_output --partial "uses custom secrets"
    assert_output --partial "ensure they are properly configured"
}

@test "check-secrets.sh: check_permissions with no permissions defined" {
    # Create workflow without permissions
    mkdir -p "$REPO_ROOT/.github/workflows"
    cat > "$REPO_ROOT/.github/workflows/no-perms.yml" << 'EOF'
name: No Permissions
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
EOF
    
    cd "$REPO_ROOT"
    run bash -c "source '$SCRIPT_UNDER_TEST'; check_permissions"
    assert_success
    assert_output --partial "doesn't specify permissions"
}

@test "check-secrets.sh: check_permissions with write-all permissions" {
    # Create workflow with overly permissive permissions
    mkdir -p "$REPO_ROOT/.github/workflows"
    cat > "$REPO_ROOT/.github/workflows/write-all.yml" << 'EOF'
name: Write All
on: push
permissions: write-all
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
EOF
    
    cd "$REPO_ROOT"
    run bash -c "source '$SCRIPT_UNDER_TEST'; check_permissions"
    assert_success
    assert_output --partial "uses 'write-all' permissions"
    assert_output --partial "consider using minimal permissions"
}

@test "check-secrets.sh: check_permissions with proper minimal permissions" {
    # Create workflow with minimal permissions
    mkdir -p "$REPO_ROOT/.github/workflows"
    cat > "$REPO_ROOT/.github/workflows/minimal-perms.yml" << 'EOF'
name: Minimal Permissions
on: push
permissions:
  contents: read
  pull-requests: write
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
EOF
    
    cd "$REPO_ROOT"
    run bash -c "source '$SCRIPT_UNDER_TEST'; check_permissions"
    assert_success
    assert_output --partial "No permission issues found"
}

@test "check-secrets.sh: main function executes all checks successfully" {
    # Create clean repository structure
    mkdir -p "$REPO_ROOT/.github/workflows"
    mkdir -p "$REPO_ROOT/src"
    
    # Clean source file
    echo "console.log('Hello');" > "$REPO_ROOT/src/app.js"
    
    # Workflow with good practices
    cat > "$REPO_ROOT/.github/workflows/good.yml" << 'EOF'
name: Good Workflow
on: push
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
EOF
    
    cd "$REPO_ROOT"
    run "$SCRIPT_UNDER_TEST"
    assert_success
    assert_output --partial "Starting security check"
    assert_output --partial "Security check completed successfully"
}

@test "check-secrets.sh: main function fails when issues found" {
    # Create problematic files
    mkdir -p "$REPO_ROOT/src"
    echo 'const secret = "hardcoded_secret_12345678";' > "$REPO_ROOT/src/bad.js"
    
    cd "$REPO_ROOT"
    run "$SCRIPT_UNDER_TEST"
    assert_failure
    assert_output --partial "Starting security check"
    assert_output --partial "Security check found issues"
}

@test "check-secrets.sh: logging functions work correctly" {
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        log_info 'Test info message'
        log_warn 'Test warning message'
        log_error 'Test error message'
    "
    assert_success
    assert_output --partial "[INFO] Test info message"
    assert_output --partial "[WARN] Test warning message"
    assert_output --partial "[ERROR] Test error message"
}

@test "check-secrets.sh: handles multiple secret patterns in single file" {
    # Create file with multiple types of secrets
    mkdir -p "$REPO_ROOT/src"
    cat > "$REPO_ROOT/src/multiple-secrets.js" << 'EOF'
const config = {
    password: "supersecretpassword123",
    apiKey: "sk-1234567890abcdef1234567890abcdef12345678",
    token: "ghp_abcd1234567890abcd1234567890abcd1234"
};
EOF
    
    cd "$REPO_ROOT"
    run bash -c "source '$SCRIPT_UNDER_TEST'; check_hardcoded_secrets"
    assert_failure
    assert_output --partial "Found 3 potential security issues"
}

@test "check-secrets.sh: script variables are set correctly" {
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        echo \"SCRIPT_DIR: \$SCRIPT_DIR\"
        echo \"REPO_ROOT: \$REPO_ROOT\"
    "
    
    assert_success
    assert_output --partial "SCRIPT_DIR:"
    assert_output --partial "REPO_ROOT:"
}