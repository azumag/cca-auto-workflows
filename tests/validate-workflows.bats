#!/usr/bin/env bats
#
# Tests for validate-workflows.sh script

# Setup and teardown
setup() {
    load 'helpers/test-helpers'
    setup_script_test
    
    # Copy the script to test location
    cp "$BATS_TEST_DIRNAME/../scripts/validate-workflows.sh" "$TEST_TEMP_DIR/validate-workflows.sh"
    chmod +x "$TEST_TEMP_DIR/validate-workflows.sh"
    
    SCRIPT_UNDER_TEST="$TEST_TEMP_DIR/validate-workflows.sh"
}

teardown() {
    teardown_script_test
}

@test "validate-workflows.sh: script exists and is executable" {
    assert_file_exists "$SCRIPT_UNDER_TEST"
    assert_file_executable "$SCRIPT_UNDER_TEST"
}

@test "validate-workflows.sh: displays correct script header" {
    run bash -c "head -5 '$SCRIPT_UNDER_TEST'"
    assert_success
    assert_output --partial "Workflow Validation Script"
    assert_output --partial "Claude Code Auto Workflows"
}

@test "validate-workflows.sh: check_yaml_syntax with no workflow directory" {
    # No workflow directory exists
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        check_yaml_syntax
    "
    assert_failure
    assert_output --partial "Workflow directory not found"
}

@test "validate-workflows.sh: check_yaml_syntax with valid workflows using yq" {
    create_yq_mock 0
    create_mock_workflows
    cd "$TEST_TEMP_DIR"
    
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        check_yaml_syntax
    "
    assert_success
    assert_output --partial "All workflow files have valid YAML syntax"
}

@test "validate-workflows.sh: check_yaml_syntax with invalid YAML using yq" {
    create_yq_mock 1  # yq returns error
    create_mock_workflows
    cd "$TEST_TEMP_DIR"
    
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        check_yaml_syntax
    "
    assert_success  # Script continues even with errors
    assert_output --partial "YAML syntax error"
}

@test "validate-workflows.sh: check_yaml_syntax fallback to python3" {
    # No yq available, use python3
    create_python3_mock 0
    create_mock_workflows
    cd "$TEST_TEMP_DIR"
    
    run bash -c "
        export PATH=\"/usr/bin:/bin\"  # Remove yq from PATH
        source '$SCRIPT_UNDER_TEST'
        check_yaml_syntax
    "
    assert_success
    assert_output --partial "All workflow files have valid YAML syntax"
}

@test "validate-workflows.sh: check_yaml_syntax with no validators" {
    # No yq or python3 available
    export PATH="/usr/bin:/bin"
    create_mock_workflows
    cd "$TEST_TEMP_DIR"
    
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        check_yaml_syntax
    "
    assert_success
    assert_output --partial "No YAML validator available"
}

@test "validate-workflows.sh: validate_github_actions_schema function" {
    create_mock_workflows
    local workflow_file="$TEST_TEMP_DIR/.github/workflows/test.yml"
    
    create_yq_mock 0
    
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        validate_github_actions_schema '$workflow_file'
    "
    assert_success
}

@test "validate-workflows.sh: validate_github_actions_basic function" {
    create_mock_workflows
    local workflow_file="$TEST_TEMP_DIR/.github/workflows/test.yml"
    
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        validate_github_actions_basic '$workflow_file'
    "
    assert_success
}

@test "validate-workflows.sh: validate_github_actions_basic detects missing fields" {
    # Create workflow missing required fields
    local workflow_dir="$TEST_TEMP_DIR/.github/workflows"
    mkdir -p "$workflow_dir"
    
    cat > "$workflow_dir/incomplete.yml" << 'EOF'
# Missing name and on fields
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
EOF
    
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        validate_github_actions_basic '$workflow_dir/incomplete.yml'
    "
    assert_failure
    assert_output --partial "Missing 'name' field"
    assert_output --partial "Missing 'on' field"
}

@test "validate-workflows.sh: check_required_fields function" {
    create_mock_workflows
    cd "$TEST_TEMP_DIR"
    
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        check_required_fields
    "
    assert_success
}

@test "validate-workflows.sh: check_security_best_practices detects unpinned actions" {
    local workflow_dir="$TEST_TEMP_DIR/.github/workflows"
    mkdir -p "$workflow_dir"
    
    # Create workflow with unpinned actions
    cat > "$workflow_dir/unpinned.yml" << 'EOF'
name: Unpinned Actions
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@main
      - uses: actions/setup-node@latest
EOF
    
    cd "$TEST_TEMP_DIR"
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        check_security_best_practices
    "
    assert_success
    assert_output --partial "Using unpinned action versions"
}

@test "validate-workflows.sh: check_security_best_practices detects missing permissions" {
    local workflow_dir="$TEST_TEMP_DIR/.github/workflows"
    mkdir -p "$workflow_dir"
    
    # Create workflow without permissions
    cat > "$workflow_dir/no-perms.yml" << 'EOF'
name: No Permissions
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
EOF
    
    cd "$TEST_TEMP_DIR"
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        check_security_best_practices
    "
    assert_success
    assert_output --partial "No explicit permissions defined"
}

@test "validate-workflows.sh: check_security_best_practices detects hardcoded secrets" {
    local workflow_dir="$TEST_TEMP_DIR/.github/workflows"
    mkdir -p "$workflow_dir"
    
    # Create workflow with potential hardcoded secret
    cat > "$workflow_dir/hardcoded.yml" << 'EOF'
name: Hardcoded Secret
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Bad step
        run: echo "password=secret123456789"
EOF
    
    cd "$TEST_TEMP_DIR"
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        check_security_best_practices
    "
    assert_success
    assert_output --partial "Potential hardcoded secret"
}

@test "validate-workflows.sh: check_performance_optimizations detects missing caching" {
    local workflow_dir="$TEST_TEMP_DIR/.github/workflows"
    mkdir -p "$workflow_dir"
    
    # Create workflow with npm install but no caching
    cat > "$workflow_dir/no-cache.yml" << 'EOF'
name: No Cache
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm install
      - run: npm test
EOF
    
    cd "$TEST_TEMP_DIR"
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        check_performance_optimizations
    "
    assert_success
    assert_output --partial "Consider adding dependency caching"
}

@test "validate-workflows.sh: check_performance_optimizations detects missing conditionals" {
    local workflow_dir="$TEST_TEMP_DIR/.github/workflows"
    mkdir -p "$workflow_dir"
    
    # Create workflow without conditionals
    cat > "$workflow_dir/no-conditions.yml" << 'EOF'
name: No Conditionals
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "test"
EOF
    
    cd "$TEST_TEMP_DIR"
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        check_performance_optimizations
    "
    assert_success
    assert_output --partial "Consider adding conditional execution"
}

@test "validate-workflows.sh: check_performance_optimizations detects parallel jobs" {
    local workflow_dir="$TEST_TEMP_DIR/.github/workflows"
    mkdir -p "$workflow_dir"
    
    # Create workflow with multiple jobs
    cat > "$workflow_dir/parallel.yml" << 'EOF'
name: Parallel Jobs
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
EOF
    
    cd "$TEST_TEMP_DIR"
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        check_performance_optimizations
    "
    assert_success
    assert_output --partial "Multiple jobs detected"
}

@test "validate-workflows.sh: check_workflow_naming detects short filenames" {
    local workflow_dir="$TEST_TEMP_DIR/.github/workflows"
    mkdir -p "$workflow_dir"
    
    # Create workflow with very short name
    cat > "$workflow_dir/ci.yml" << 'EOF'
name: CI
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
EOF
    
    cd "$TEST_TEMP_DIR"
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        check_workflow_naming
    "
    assert_success
    assert_output --partial "Very short filename"
}

@test "validate-workflows.sh: check_workflow_naming detects non-standard naming" {
    local workflow_dir="$TEST_TEMP_DIR/.github/workflows"
    mkdir -p "$workflow_dir"
    
    # Create workflow with non-kebab-case name
    cat > "$workflow_dir/BadNaming_123.yml" << 'EOF'
name: Bad Naming
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
EOF
    
    cd "$TEST_TEMP_DIR"
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        check_workflow_naming
    "
    assert_success
    assert_output --partial "Non-standard filename format"
}

@test "validate-workflows.sh: check_dependencies extracts used actions" {
    create_mock_workflows
    cd "$TEST_TEMP_DIR"
    
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        check_dependencies
    "
    assert_success
    assert_output --partial "Actions used in workflows"
    assert_output --partial "actions/checkout@"
}

@test "validate-workflows.sh: check_dependencies suggests pinning" {
    local workflow_dir="$TEST_TEMP_DIR/.github/workflows"
    mkdir -p "$workflow_dir"
    
    # Create workflow with unpinned action
    cat > "$workflow_dir/unpinned-deps.yml" << 'EOF'
name: Unpinned Dependencies
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@main
EOF
    
    cd "$TEST_TEMP_DIR"
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        check_dependencies
    "
    assert_success
    assert_output --partial "Consider pinning to a specific version"
}

@test "validate-workflows.sh: generate_summary with no errors or warnings" {
    export ERRORS=0
    export WARNINGS=0
    
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        generate_summary
    "
    assert_success
    assert_output --partial "All workflows passed validation"
    assert_output --partial "Errors: 0"
    assert_output --partial "Warnings: 0"
}

@test "validate-workflows.sh: generate_summary with warnings only" {
    export ERRORS=0
    export WARNINGS=3
    
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        generate_summary
    "
    assert_success
    assert_output --partial "Workflows have warnings but no critical errors"
    assert_output --partial "Warnings: 3"
}

@test "validate-workflows.sh: generate_summary with errors" {
    export ERRORS=2
    export WARNINGS=1
    
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        generate_summary
    "
    assert_success
    assert_output --partial "Workflows have critical errors"
    assert_output --partial "Errors: 2"
}

@test "validate-workflows.sh: logging functions work correctly and increment counters" {
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        log_info 'Test info message'
        log_warn 'Test warning 1'
        log_warn 'Test warning 2'
        log_error 'Test error 1'
        echo \"Final counts - Errors: \$ERRORS, Warnings: \$WARNINGS\"
    "
    assert_success
    assert_output --partial "[INFO] Test info message"
    assert_output --partial "[WARN] Test warning 1"
    assert_output --partial "[WARN] Test warning 2"
    assert_output --partial "[ERROR] Test error 1"
    assert_output --partial "Final counts - Errors: 1, Warnings: 2"
}

@test "validate-workflows.sh: main function executes all validation steps" {
    create_yq_mock 0
    create_mock_workflows
    cd "$TEST_TEMP_DIR"
    
    run "$SCRIPT_UNDER_TEST"
    assert_success
    assert_output --partial "Starting workflow validation"
    assert_output --partial "Checking YAML syntax"
    assert_output --partial "Checking required workflow fields"
    assert_output --partial "Checking security best practices"
    assert_output --partial "Checking performance optimizations"
    assert_output --partial "Checking workflow naming conventions"
    assert_output --partial "Checking workflow dependencies"
    assert_output --partial "Validation Summary"
}

@test "validate-workflows.sh: main function returns correct exit codes" {
    create_yq_mock 0
    create_mock_workflows
    cd "$TEST_TEMP_DIR"
    
    # Test with no errors
    run "$SCRIPT_UNDER_TEST"
    assert_success
    
    # Test with errors (create problematic workflow)
    cat > "$TEST_TEMP_DIR/.github/workflows/broken.yml" << 'EOF'
# Missing required fields
steps:
  - run: echo "broken"
EOF
    
    run "$SCRIPT_UNDER_TEST"
    assert_failure
}

@test "validate-workflows.sh: handles empty workflow directory" {
    mkdir -p "$TEST_TEMP_DIR/.github/workflows"
    cd "$TEST_TEMP_DIR"
    
    run "$SCRIPT_UNDER_TEST"
    assert_success
    assert_output --partial "Starting workflow validation"
}

@test "validate-workflows.sh: processes both yml and yaml extensions" {
    local workflow_dir="$TEST_TEMP_DIR/.github/workflows"
    mkdir -p "$workflow_dir"
    
    # Create both .yml and .yaml files
    cat > "$workflow_dir/test.yml" << 'EOF'
name: YML Test
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
EOF
    
    cat > "$workflow_dir/test.yaml" << 'EOF'
name: YAML Test
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
EOF
    
    create_yq_mock 0
    cd "$TEST_TEMP_DIR"
    
    run "$SCRIPT_UNDER_TEST"
    assert_success
    assert_output --partial "Validating: test.yml"
    assert_output --partial "Validating: test.yaml"
}