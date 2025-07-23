#!/usr/bin/env bats
#
# Tests for create-labels.sh script

# Setup and teardown
setup() {
    load 'helpers/test-helpers'
    setup_script_test
    
    # Copy the script to test location
    cp "$BATS_TEST_DIRNAME/../scripts/create-labels.sh" "$TEST_TEMP_DIR/create-labels.sh"
    chmod +x "$TEST_TEMP_DIR/create-labels.sh"
    
    SCRIPT_UNDER_TEST="$TEST_TEMP_DIR/create-labels.sh"
}

teardown() {
    teardown_script_test
}

@test "create-labels.sh: script exists and is executable" {
    assert_file_exists "$SCRIPT_UNDER_TEST"
    assert_file_executable "$SCRIPT_UNDER_TEST"
}

@test "create-labels.sh: displays correct script header" {
    run bash -c "head -10 '$SCRIPT_UNDER_TEST'"
    assert_success
    assert_output --partial "Create Labels Script"
    assert_output --partial "Claude Code Auto Workflows"
}

@test "create-labels.sh: shows help when requested" {
    run "$SCRIPT_UNDER_TEST" --help
    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "--dry-run"
    assert_output --partial "--force"
    assert_output --partial "--quiet"
}

@test "create-labels.sh: shows help with -h flag" {
    run "$SCRIPT_UNDER_TEST" -h
    assert_success
    assert_output --partial "Usage:"
}

@test "create-labels.sh: fails with unknown option" {
    run "$SCRIPT_UNDER_TEST" --unknown-option
    assert_failure
    assert_output --partial "Unknown option: --unknown-option"
}

@test "create-labels.sh: fails without gh CLI" {
    # Remove gh from PATH
    export PATH="/usr/bin:/bin"
    
    run "$SCRIPT_UNDER_TEST"
    assert_failure
    assert_output --partial "GitHub CLI (gh) is not installed"
    assert_output --partial "https://cli.github.com/"
}

@test "create-labels.sh: fails when not authenticated" {
    create_gh_mock "" 1  # gh auth status fails
    
    run "$SCRIPT_UNDER_TEST"
    assert_failure
    assert_output --partial "Not authenticated with GitHub CLI"
    assert_output --partial "gh auth login"
}

@test "create-labels.sh: fails when not in git repository" {
    create_gh_mock "" 0
    
    # Remove .git directory
    rm -rf "$TEST_TEMP_DIR/repo/.git"
    cd "$TEST_TEMP_DIR/repo"
    
    run "$SCRIPT_UNDER_TEST"
    assert_failure
    assert_output --partial "Not in a git repository"
}

@test "create-labels.sh: fails without repository access" {
    # Mock git but fail gh repo view
    cat > "$TEST_TEMP_DIR/bin/git" << 'EOF'
#!/bin/bash
case "$1" in
    "rev-parse") exit 0 ;;
    *) /usr/bin/git "$@" ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/git"
    
    cat > "$TEST_TEMP_DIR/bin/gh" << 'EOF'
#!/bin/bash
case "$1 $2" in
    "auth status") exit 0 ;;
    "repo view") exit 1 ;;
    *) exit 0 ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/gh"
    
    cd "$TEST_TEMP_DIR/repo"
    run "$SCRIPT_UNDER_TEST"
    assert_failure
    assert_output --partial "Cannot access repository"
}

@test "create-labels.sh: create_label function validates inputs" {
    create_gh_mock "" 0
    
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        create_label '' 'ff0000' 'Test description'
    "
    assert_failure
    assert_output --partial "Invalid label parameters"
}

@test "create-labels.sh: create_label function validates color format" {
    create_gh_mock "" 0
    
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        create_label 'test-label' 'invalid-color' 'Test description'
    "
    assert_failure
    assert_output --partial "Invalid color format"
    assert_output --partial "should be 6-character hex without #"
}

@test "create-labels.sh: create_label function with dry-run" {
    create_gh_mock "" 0
    export DRY_RUN=true
    
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        create_label 'test-label' 'ff0000' 'Test description'
    "
    assert_success
    assert_output --partial "Would create label: test-label"
    assert_output --partial "color: #ff0000"
}

@test "create-labels.sh: create_label creates new label successfully" {
    # Mock gh to simulate label creation
    cat > "$TEST_TEMP_DIR/bin/gh" << 'EOF'
#!/bin/bash
case "$1 $2" in
    "label list") echo '[]' ;;  # No existing labels
    "label create"*) exit 0 ;;  # Successful creation
    *) exit 0 ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/gh"
    
    export DRY_RUN=false
    
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        create_label 'new-label' 'ff0000' 'New test label'
    "
    assert_success
    assert_output --partial "Created: new-label"
}

@test "create-labels.sh: create_label handles existing label without force" {
    # Mock gh to simulate existing label
    cat > "$TEST_TEMP_DIR/bin/gh" << 'EOF'
#!/bin/bash
case "$1 $2" in
    "label list") echo '[{"name":"existing-label"}]' ;;
    *) exit 0 ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/gh"
    
    export DRY_RUN=false
    export FORCE_UPDATE=false
    
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        create_label 'existing-label' 'ff0000' 'Existing label'
    "
    assert_success
    assert_output --partial "Label already exists"
    assert_output --partial "use --force to update"
}

@test "create-labels.sh: create_label updates existing label with force" {
    # Mock gh to simulate existing label and successful update
    cat > "$TEST_TEMP_DIR/bin/gh" << 'EOF'
#!/bin/bash
case "$1 $2" in
    "label list") echo '[{"name":"existing-label"}]' ;;
    "label edit"*) exit 0 ;;  # Successful update
    *) exit 0 ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/gh"
    
    export DRY_RUN=false
    export FORCE_UPDATE=true
    
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        create_label 'existing-label' '00ff00' 'Updated label'
    "
    assert_success
    assert_output --partial "Label exists, updating"
    assert_output --partial "Updated: existing-label"
}

@test "create-labels.sh: create_label handles creation failure" {
    # Mock gh to simulate creation failure
    cat > "$TEST_TEMP_DIR/bin/gh" << 'EOF'
#!/bin/bash
case "$1 $2" in
    "label list") echo '[]' ;;  # No existing labels
    "label create"*) 
        echo "Error: Label creation failed" >&2
        exit 1 
        ;;
    *) exit 0 ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/gh"
    
    export DRY_RUN=false
    
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        create_label 'fail-label' 'ff0000' 'This will fail'
    "
    assert_failure
    assert_output --partial "Failed to create label"
}

@test "create-labels.sh: process_labels function works correctly" {
    create_gh_mock "" 0
    export DRY_RUN=true
    export QUIET=false
    
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        declare -a TEST_LABELS=(
            'test-label-1|ff0000|Test label 1'
            'test-label-2|00ff00|Test label 2'
        )
        process_labels TEST_LABELS 'Testing category'
    "
    assert_success
    assert_output --partial "Testing category"
    assert_output --partial "Would create label: test-label-1"
    assert_output --partial "Would create label: test-label-2"
}

@test "create-labels.sh: quiet mode suppresses output" {
    create_gh_mock "" 0
    export QUIET=true
    
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        log_info 'This should be suppressed'
    "
    refute_output --partial "This should be suppressed"
}

@test "create-labels.sh: quiet mode allows errors" {
    export QUIET=true
    
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        log_error 'This error should show'
    "
    assert_output --partial "This error should show"
}

@test "create-labels.sh: script defines all required label arrays" {
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        echo 'ISSUE_PROCESSING_LABELS: \${#ISSUE_PROCESSING_LABELS[@]}'
        echo 'PR_REVIEW_LABELS: \${#PR_REVIEW_LABELS[@]}'
        echo 'CI_STATUS_LABELS: \${#CI_STATUS_LABELS[@]}'
        echo 'ADDITIONAL_LABELS: \${#ADDITIONAL_LABELS[@]}'
    "
    assert_success
    assert_output --partial "ISSUE_PROCESSING_LABELS: 4"
    assert_output --partial "PR_REVIEW_LABELS: 2"
    assert_output --partial "CI_STATUS_LABELS: 2"
    assert_output --partial "ADDITIONAL_LABELS: 10"
}

@test "create-labels.sh: label definitions have correct format" {
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        # Check that all label definitions follow the pattern: name|color|description
        for label_def in \"\${ISSUE_PROCESSING_LABELS[@]}\"; do
            IFS='|' read -r name color description <<< \"\$label_def\"
            echo \"Label: \$name, Color: \$color, Description: \$description\"
            if [[ -z \"\$name\" || -z \"\$color\" || -z \"\$description\" ]]; then
                echo \"ERROR: Invalid label definition: \$label_def\"
                exit 1
            fi
        done
    "
    assert_success
    assert_output --partial "Label: processing"
    assert_output --partial "Label: pr-ready"
    refute_output --partial "ERROR:"
}

@test "create-labels.sh: main function executes with dry-run" {
    create_gh_mock "" 0
    cd "$TEST_TEMP_DIR/repo"
    
    run "$SCRIPT_UNDER_TEST" --dry-run
    assert_success
    assert_output --partial "Creating required labels"
    assert_output --partial "Creating issue processing labels"
    assert_output --partial "Creating PR review labels"
    assert_output --partial "Creating CI/CD status labels"
    assert_output --partial "Creating additional useful labels"
    assert_output --partial "Dry run completed"
}

@test "create-labels.sh: main function creates labels successfully" {
    # Mock successful label operations
    cat > "$TEST_TEMP_DIR/bin/gh" << 'EOF'
#!/bin/bash
case "$1 $2" in
    "auth status") exit 0 ;;
    "repo view") exit 0 ;;
    "label list") echo '[]' ;;  # No existing labels
    "label create"*) exit 0 ;;  # All creations succeed
    *) exit 0 ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/gh"
    
    cd "$TEST_TEMP_DIR/repo"
    
    run "$SCRIPT_UNDER_TEST" --quiet
    assert_success
    assert_output --partial "All required labels have been processed successfully"
}

@test "create-labels.sh: main function handles mixed success/failure" {
    # Mock some failures in label creation
    cat > "$TEST_TEMP_DIR/bin/gh" << 'EOF'
#!/bin/bash
case "$1 $2" in
    "auth status") exit 0 ;;
    "repo view") exit 0 ;;
    "label list") echo '[]' ;;
    "label create"*)
        # Fail for certain labels
        if [[ "$*" == *"processing"* ]]; then
            exit 1
        fi
        exit 0
        ;;
    *) exit 0 ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/gh"
    
    cd "$TEST_TEMP_DIR/repo"
    
    run "$SCRIPT_UNDER_TEST"
    assert_failure
    assert_output --partial "Some labels failed to process"
}

@test "create-labels.sh: validates all label colors are valid hex" {
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        # Test all defined labels have valid hex colors
        error_count=0
        for array_name in ISSUE_PROCESSING_LABELS PR_REVIEW_LABELS CI_STATUS_LABELS ADDITIONAL_LABELS; do
            declare -n labels_ref=\$array_name
            for label_def in \"\${labels_ref[@]}\"; do
                IFS='|' read -r name color description <<< \"\$label_def\"
                if [[ ! \"\$color\" =~ ^[0-9A-Fa-f]{6}\$ ]]; then
                    echo \"ERROR: Invalid color '\$color' for label '\$name'\"
                    ((error_count++))
                fi
            done
        done
        echo \"Total color validation errors: \$error_count\"
        exit \$error_count
    "
    assert_success
    assert_output --partial "Total color validation errors: 0"
}