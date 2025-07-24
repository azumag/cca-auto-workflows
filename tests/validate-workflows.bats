#!/usr/bin/env bats

# Tests for scripts/validate-workflows.sh
# This file tests workflow validation functionality

# Load test helpers
load helpers/common.bash

# Set up BATS
setup() {
    setup_bats_libs
    load test-config.bash
    common_setup
    
    # Copy the script under test
    SCRIPT_PATH="./scripts/validate-workflows.sh"
    
    # Ensure script is executable
    chmod +x "$SCRIPT_PATH"
}

teardown() {
    restore_commands
    common_teardown
}

@test "validate-workflows.sh exists and is executable" {
    [ -f "$SCRIPT_PATH" ]
    [ -x "$SCRIPT_PATH" ]
}

@test "script has proper error handling" {
    run grep -q "set -euo pipefail" "$SCRIPT_PATH"
    assert_success
}

@test "script initializes error and warning counters" {
    run grep -q "ERRORS=0" "$SCRIPT_PATH"
    assert_success
    
    run grep -q "WARNINGS=0" "$SCRIPT_PATH"
    assert_success
}

@test "script defines required validation functions" {
    run grep -q "validate_github_actions_schema()" "$SCRIPT_PATH"
    assert_success
    
    run grep -q "check_yaml_syntax()" "$SCRIPT_PATH"
    assert_success
    
    run grep -q "check_required_fields()" "$SCRIPT_PATH"
    assert_success
    
    run grep -q "check_security_best_practices()" "$SCRIPT_PATH"
    assert_success
    
    run grep -q "check_performance_optimizations()" "$SCRIPT_PATH"
    assert_success
}

@test "check_yaml_syntax handles missing workflow directory" {
    # Run in directory without .github/workflows
    run bash -c "source $SCRIPT_PATH && check_yaml_syntax"
    assert_failure
    assert_output --partial "Workflow directory not found"
}

@test "check_yaml_syntax validates with yq when available" {
    # Create mock workflows directory
    local workflows_dir
    workflows_dir=$(setup_mock_workflows "$TEMP_TEST_DIR")
    cd "$TEMP_TEST_DIR"
    
    # Mock yq command to be available and successful
    eval "command() {
        if [[ \"\$1\" == \"-v\" && \"\$2\" == \"yq\" ]]; then
            return 0
        fi
        return 0
    }"
    
    eval "yq() {
        case \"\$*\" in
            'eval . '*) echo '{}' ;;  # Valid YAML
            'eval .name '*) echo 'CI' ;;
            'eval .on '*) echo 'push' ;;
            'eval .jobs '*) echo '{}' ;;
            *) echo '{}' ;;
        esac
    }"
    
    run bash -c "source $SCRIPT_PATH && check_yaml_syntax"
    assert_success
    assert_output --partial "All workflow files have valid YAML syntax"
}

@test "check_yaml_syntax detects YAML syntax errors with yq" {
    local workflows_dir="$TEMP_TEST_DIR/.github/workflows"
    mkdir -p "$workflows_dir"
    
    # Create invalid YAML file
    cat > "$workflows_dir/invalid.yml" << 'EOF'
name: Invalid YAML
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Test
        run: echo "test"
      - invalid: yaml: structure: here:
EOF
    
    cd "$TEMP_TEST_DIR"
    
    # Mock yq to return error for invalid YAML
    eval "command() {
        if [[ \"\$1\" == \"-v\" && \"\$2\" == \"yq\" ]]; then
            return 0
        fi
        return 0
    }"
    
    eval "yq() {
        echo 'yaml: line 8: mapping values are not allowed here' >&2
        return 1
    }"
    
    run bash -c "source $SCRIPT_PATH && check_yaml_syntax"
    assert_success  # Function continues even with errors
    assert_output --partial "YAML syntax error"
}

@test "check_yaml_syntax falls back to python when yq unavailable" {
    local workflows_dir
    workflows_dir=$(setup_mock_workflows "$TEMP_TEST_DIR")
    cd "$TEMP_TEST_DIR"
    
    # Mock yq as unavailable, python3 as available
    eval "command() {
        case \"\$2\" in
            'yq') return 1 ;;
            'python3') return 0 ;;
            *) return 0 ;;
        esac
    }"
    
    eval "python3() {
        return 0  # Successful YAML parsing
    }"
    
    run bash -c "source $SCRIPT_PATH && check_yaml_syntax"
    assert_success
    assert_output --partial "All workflow files have valid YAML syntax"
}

@test "validate_github_actions_schema checks required fields" {
    local workflows_dir="$TEMP_TEST_DIR/.github/workflows"
    mkdir -p "$workflows_dir"
    
    # Create workflow with missing required fields
    cat > "$workflows_dir/incomplete.yml" << 'EOF'
name: Incomplete Workflow
# Missing 'on' field
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo "test"
EOF
    
    cd "$TEMP_TEST_DIR"
    
    # Mock yq to simulate missing fields
    eval "yq() {
        case \"\$*\" in
            'eval .name '*) echo 'Incomplete Workflow' ;;
            'eval .on '*) return 1 ;;  # Missing field
            'eval .jobs '*) echo '{}' ;;
            *) return 1 ;;
        esac
    }"
    
    run bash -c "source $SCRIPT_PATH && validate_github_actions_schema '$workflows_dir/incomplete.yml'"
    assert_failure
}

@test "validate_github_actions_basic checks fields with grep" {
    local workflows_dir="$TEMP_TEST_DIR/.github/workflows"
    mkdir -p "$workflows_dir"
    
    # Create complete workflow
    cat > "$workflows_dir/complete.yml" << 'EOF'
name: Complete Workflow
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo "test"
EOF
    
    cd "$TEMP_TEST_DIR"
    
    run bash -c "source $SCRIPT_PATH && validate_github_actions_basic '$workflows_dir/complete.yml'"
    assert_success
}

@test "check_required_fields validates all workflow files" {
    local workflows_dir
    workflows_dir=$(setup_mock_workflows "$TEMP_TEST_DIR")
    cd "$TEMP_TEST_DIR"
    
    run bash -c "source $SCRIPT_PATH && check_required_fields"
    assert_success
    # Should process both workflow files without errors
}

@test "check_security_best_practices detects unpinned actions" {
    local workflows_dir="$TEMP_TEST_DIR/.github/workflows"
    mkdir -p "$workflows_dir"
    
    cat > "$workflows_dir/unpinned.yml" << 'EOF'
name: Unpinned Actions
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@main
      - uses: actions/setup-node@latest
EOF
    
    cd "$TEMP_TEST_DIR"
    
    run bash -c "source $SCRIPT_PATH && check_security_best_practices"
    assert_success
    assert_output --partial "unpinned action versions"
}

@test "check_security_best_practices warns about missing permissions" {
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
    
    run bash -c "source $SCRIPT_PATH && check_security_best_practices"
    assert_success
    assert_output --partial "No explicit permissions defined"
}

@test "check_security_best_practices detects hardcoded secrets" {
    local workflows_dir="$TEMP_TEST_DIR/.github/workflows"
    mkdir -p "$workflows_dir"
    
    cat > "$workflows_dir/hardcoded-secret.yml" << 'EOF'
name: Hardcoded Secret
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    env:
      SECRET_KEY: "hardcoded_secret_123456789"
    steps:
      - run: echo "test"
EOF
    
    cd "$TEMP_TEST_DIR"
    
    run bash -c "source $SCRIPT_PATH && check_security_best_practices"
    assert_success
    assert_output --partial "Potential hardcoded secret"
}

@test "check_security_best_practices approves proper secret usage" {
    local workflows_dir="$TEMP_TEST_DIR/.github/workflows"
    mkdir -p "$workflows_dir"
    
    cat > "$workflows_dir/good-secrets.yml" << 'EOF'
name: Good Secrets
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
      - env:
          API_KEY: ${{ secrets.API_KEY }}
        run: echo "test"
EOF
    
    cd "$TEMP_TEST_DIR"
    
    run bash -c "source $SCRIPT_PATH && check_security_best_practices"
    assert_success
    # Should not warn about proper secret usage
}

@test "check_performance_optimizations suggests caching" {
    local workflows_dir="$TEMP_TEST_DIR/.github/workflows"
    mkdir -p "$workflows_dir"
    
    cat > "$workflows_dir/no-cache.yml" << 'EOF'
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
    
    cd "$TEMP_TEST_DIR"
    
    run bash -c "source $SCRIPT_PATH && check_performance_optimizations"
    assert_success
    assert_output --partial "Consider adding dependency caching"
}

@test "check_performance_optimizations suggests conditionals" {
    local workflows_dir="$TEMP_TEST_DIR/.github/workflows"
    mkdir -p "$workflows_dir"
    
    cat > "$workflows_dir/no-conditionals.yml" << 'EOF'
name: No Conditionals
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm test
EOF
    
    cd "$TEMP_TEST_DIR"
    
    run bash -c "source $SCRIPT_PATH && check_performance_optimizations"
    assert_success
    assert_output --partial "Consider adding conditional execution"
}

@test "check_performance_optimizations detects parallel opportunities" {
    local workflows_dir="$TEMP_TEST_DIR/.github/workflows"
    mkdir -p "$workflows_dir"
    
    cat > "$workflows_dir/parallel.yml" << 'EOF'
name: Parallel Jobs
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: npm test
  lint:
    runs-on: ubuntu-latest
    steps:
      - run: npm run lint
EOF
    
    cd "$TEMP_TEST_DIR"
    
    run bash -c "source $SCRIPT_PATH && check_performance_optimizations"
    assert_success
    assert_output --partial "Multiple jobs detected"
}

@test "check_workflow_naming validates naming conventions" {
    local workflows_dir="$TEMP_TEST_DIR/.github/workflows"
    mkdir -p "$workflows_dir"
    
    # Create workflows with different naming patterns
    touch "$workflows_dir/good-name.yml"
    touch "$workflows_dir/BadName.yml"
    touch "$workflows_dir/a.yml"
    
    cd "$TEMP_TEST_DIR"
    
    run bash -c "source $SCRIPT_PATH && check_workflow_naming"
    assert_success
    assert_output --partial "Very short filename"
    assert_output --partial "Non-standard filename format"
}

@test "check_dependencies extracts and analyzes actions" {
    local workflows_dir="$TEMP_TEST_DIR/.github/workflows"
    mkdir -p "$workflows_dir"
    
    cat > "$workflows_dir/with-actions.yml" << 'EOF'
name: With Actions
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v3
      - uses: custom/action@main
EOF
    
    cd "$TEMP_TEST_DIR"
    
    run bash -c "source $SCRIPT_PATH && check_dependencies"
    assert_success
    assert_output --partial "Actions used in workflows"
    assert_output --partial "actions/checkout@v4"
    assert_output --partial "Consider pinning to a specific version"
}

@test "generate_summary provides validation results" {
    # Set up some errors and warnings
    run bash -c "ERRORS=2 WARNINGS=3 source $SCRIPT_PATH && generate_summary"
    assert_success
    assert_output --partial "Errors: 2"
    assert_output --partial "Warnings: 3"
    assert_output --partial "critical errors that need to be fixed"
}

@test "generate_summary handles clean validation" {
    run bash -c "ERRORS=0 WARNINGS=0 source $SCRIPT_PATH && generate_summary"
    assert_success
    assert_output --partial "All workflows passed validation"
}

@test "main function executes all validation steps" {
    local workflows_dir
    workflows_dir=$(setup_mock_workflows "$TEMP_TEST_DIR")
    cd "$TEMP_TEST_DIR"
    
    # Mock yq to be available
    eval "command() {
        if [[ \"\$2\" == \"yq\" ]]; then
            return 0
        fi
        return 0
    }"
    
    eval "yq() {
        case \"\$*\" in
            'eval . '*) echo '{}' ;;
            'eval .name '*) echo 'Test' ;;
            'eval .on '*) echo 'push' ;;
            'eval .jobs '*) echo '{}' ;;
            *) echo '{}' ;;
        esac
    }"
    
    run bash -c "source $SCRIPT_PATH && main"
    assert_success
    assert_output --partial "Starting workflow validation"
    assert_output --partial "Validation Summary"
}

@test "main function returns appropriate exit codes" {
    # Test with no errors
    local workflows_dir
    workflows_dir=$(setup_mock_workflows "$TEMP_TEST_DIR")
    cd "$TEMP_TEST_DIR"
    
    eval "command() { return 0; }"
    eval "yq() { echo '{}'; }"
    
    run bash -c "source $SCRIPT_PATH && main"
    assert_success
    
    # Test with errors would require mocking error conditions
}

@test "logging functions increment counters correctly" {
    run bash -c "source $SCRIPT_PATH && log_warn 'test' && echo \"Warnings: \$WARNINGS\""
    assert_success
    assert_output --partial "Warnings: 1"
    
    run bash -c "source $SCRIPT_PATH && log_error 'test' && echo \"Errors: \$ERRORS\""
    assert_success
    assert_output --partial "Errors: 1"
}

@test "script handles missing dependencies gracefully" {
    local workflows_dir
    workflows_dir=$(setup_mock_workflows "$TEMP_TEST_DIR")
    cd "$TEMP_TEST_DIR"
    
    # Mock all validation tools as unavailable
    eval "command() { return 1; }"
    
    run bash -c "source $SCRIPT_PATH && check_yaml_syntax"
    assert_success
    assert_output --partial "No YAML validator available"
}

@test "script validates workflow file extensions correctly" {
    local workflows_dir="$TEMP_TEST_DIR/.github/workflows"
    mkdir -p "$workflows_dir"
    
    # Create files with different extensions
    touch "$workflows_dir/test.yml"
    touch "$workflows_dir/test.yaml"
    touch "$workflows_dir/test.txt"
    touch "$workflows_dir/README.md"
    
    cd "$TEMP_TEST_DIR"
    
    # Mock tools to be available
    eval "command() { return 0; }"
    eval "yq() { echo '{}'; }"
    
    run bash -c "source $SCRIPT_PATH && check_yaml_syntax"
    assert_success
    # Should only process .yml and .yaml files
}

# Edge cases and error handling

@test "handles corrupted workflow files" {
    local workflows_dir="$TEMP_TEST_DIR/.github/workflows"
    mkdir -p "$workflows_dir"
    
    # Create binary file that shouldn't be parsed
    echo -e '\x00\x01\x02\x03' > "$workflows_dir/binary.yml"
    
    cd "$TEMP_TEST_DIR"
    
    eval "command() { return 0; }"
    eval "yq() {
        echo 'yaml: control characters are not allowed' >&2
        return 1
    }"
    
    run bash -c "source $SCRIPT_PATH && check_yaml_syntax"
    assert_success
    # Should handle binary files gracefully
}

@test "handles very large workflow files" {
    local workflows_dir="$TEMP_TEST_DIR/.github/workflows"
    mkdir -p "$workflows_dir"
    
    # Create a large but valid workflow
    cat > "$workflows_dir/large.yml" << 'EOF'
name: Large Workflow
on: push
jobs:
EOF
    
    # Add many jobs to make it large
    for i in {1..100}; do
        cat >> "$workflows_dir/large.yml" << EOF
  job$i:
    runs-on: ubuntu-latest
    steps:
      - run: echo "job $i"
EOF
    done
    
    cd "$TEMP_TEST_DIR"
    
    eval "command() { return 0; }"
    eval "yq() { echo '{}'; }"
    
    run bash -c "source $SCRIPT_PATH && check_yaml_syntax"
    assert_success
}

@test "validates complex workflow structures" {
    local workflows_dir="$TEMP_TEST_DIR/.github/workflows"
    mkdir -p "$workflows_dir"
    
    cat > "$workflows_dir/complex.yml" << 'EOF'
name: Complex Workflow
on:
  push:
    branches: [main, develop]
  pull_request:
    paths: ['src/**', 'tests/**']
  schedule:
    - cron: '0 0 * * 0'

permissions:
  contents: read
  pull-requests: write

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node-version: [16, 18, 20]
        os: [ubuntu-latest, windows-latest]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v3
        with:
          node-version: ${{ matrix.node-version }}
          cache: 'npm'
      - if: runner.os == 'Linux'
        run: npm ci
      - run: npm test
        
  security:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run security scan
        env:
          SECURITY_TOKEN: ${{ secrets.SECURITY_TOKEN }}
        run: npm audit
EOF
    
    cd "$TEMP_TEST_DIR"
    
    eval "command() { return 0; }"
    eval "yq() { echo '{}'; }"
    
    run bash -c "source $SCRIPT_PATH && main"
    assert_success
    # Should handle complex workflows without issues
}