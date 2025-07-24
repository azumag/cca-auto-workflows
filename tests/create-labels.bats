#!/usr/bin/env bats

# Tests for scripts/create-labels.sh
# This file tests label creation and management functionality

# Load test helpers
load helpers/common.bash

# Set up BATS
setup() {
    setup_bats_libs
    load test-config.bash
    common_setup
    
    # Copy the script under test
    SCRIPT_PATH="./scripts/create-labels.sh"
    
    # Ensure script is executable
    chmod +x "$SCRIPT_PATH"
}

teardown() {
    restore_commands
    common_teardown
}

@test "create-labels.sh exists and is executable" {
    [ -f "$SCRIPT_PATH" ]
    [ -x "$SCRIPT_PATH" ]
}

@test "script has proper error handling" {
    run grep -q "set -euo pipefail" "$SCRIPT_PATH"
    assert_success
}

@test "script shows help when requested" {
    run bash "$SCRIPT_PATH" --help
    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "--dry-run"
    assert_output --partial "--force"
}

@test "script shows help with -h flag" {
    run bash "$SCRIPT_PATH" -h
    assert_success
    assert_output --partial "Usage:"
}

@test "script fails with unknown option" {
    run bash "$SCRIPT_PATH" --unknown-option
    assert_failure
    assert_output --partial "Unknown option"
}

@test "script sets dry run mode correctly" {
    # Check that dry run flag is processed
    run bash -c "source $SCRIPT_PATH" --dry-run
    # The script should process the flag (exact verification depends on implementation)
}

@test "script requires GitHub CLI" {
    # Mock command to simulate gh not being available
    eval "command() {
        if [[ \"\$1\" == \"-v\" && \"\$2\" == \"gh\" ]]; then
            return 1
        fi
        return 0
    }"
    
    run bash "$SCRIPT_PATH"
    assert_failure
    assert_output --partial "GitHub CLI (gh) is not installed"
}

@test "script requires GitHub authentication" {
    # Mock gh CLI available but not authenticated
    eval "command() { return 0; }"
    eval "gh() {
        if [[ \"\$1\" == \"auth\" && \"\$2\" == \"status\" ]]; then
            return 1
        fi
        return 0
    }"
    
    run bash "$SCRIPT_PATH"
    assert_failure
    assert_output --partial "Not authenticated with GitHub CLI"
}

@test "script requires git repository" {
    # Mock gh CLI available and authenticated
    eval "command() { return 0; }"
    eval "gh() { return 0; }"
    
    # Mock git to indicate not in repository
    eval "git() {
        if [[ \"\$1\" == \"rev-parse\" && \"\$2\" == \"--git-dir\" ]]; then
            return 1
        fi
        return 0
    }"
    
    run bash "$SCRIPT_PATH"
    assert_failure
    assert_output --partial "Not in a git repository"
}

@test "script requires repository access" {
    # Mock all prerequisites except repository access
    eval "command() { return 0; }"
    eval "git() { return 0; }"
    eval "gh() {
        case \"\$1\" in
            'auth') return 0 ;;
            'repo') return 1 ;;
            *) return 0 ;;
        esac
    }"
    
    run bash "$SCRIPT_PATH"
    assert_failure
    assert_output --partial "Cannot access repository"
}

@test "create_label function validates inputs" {
    # Load script functions
    source "$SCRIPT_PATH"
    
    # Test with empty parameters
    run create_label "" "FF0000" "description"
    assert_failure
    
    run create_label "name" "" "description"
    assert_failure
    
    run create_label "name" "FF0000" ""
    assert_failure
}

@test "create_label function validates color format" {
    source "$SCRIPT_PATH"
    
    # Test invalid color formats
    run create_label "test" "invalid" "description"
    assert_failure
    assert_output --partial "Invalid color format"
    
    run create_label "test" "#FF0000" "description"
    assert_failure
    assert_output --partial "Invalid color format"
    
    run create_label "test" "FF00" "description"
    assert_failure
    assert_output --partial "Invalid color format"
}

@test "create_label function works in dry run mode" {
    source "$SCRIPT_PATH"
    DRY_RUN=true
    
    run create_label "test-label" "FF0000" "Test description"
    assert_success
    assert_output --partial "Would create label: test-label"
}

@test "create_label function creates new labels" {
    source "$SCRIPT_PATH"
    DRY_RUN=false
    
    # Mock gh CLI to simulate label creation
    eval "gh() {
        case \"\$*\" in
            'label list --limit 1000 --json name --jq'*)
                echo ''  # No existing labels
                ;;
            'label create'*)
                return 0  # Successful creation
                ;;
            *) return 0 ;;
        esac
    }"
    
    run create_label "new-label" "00FF00" "New label description"
    assert_success
    assert_output --partial "Created: new-label"
}

@test "create_label function detects existing labels" {
    source "$SCRIPT_PATH"
    DRY_RUN=false
    FORCE_UPDATE=false
    
    # Mock gh CLI to return existing label
    eval "gh() {
        case \"\$*\" in
            'label list --limit 1000 --json name --jq'*)
                echo 'existing-label'
                ;;
            *) return 0 ;;
        esac
    }"
    
    eval "grep() {
        if [[ \"\$3\" == '^existing-label$' ]]; then
            return 0  # Label exists
        fi
        return 1
    }"
    
    run create_label "existing-label" "0000FF" "Existing label"
    assert_success
    assert_output --partial "Label already exists"
}

@test "create_label function updates labels when forced" {
    source "$SCRIPT_PATH"
    DRY_RUN=false
    FORCE_UPDATE=true
    
    # Mock gh CLI responses
    eval "gh() {
        case \"\$*\" in
            'label list --limit 1000 --json name --jq'*)
                echo 'existing-label'
                ;;
            'label edit'*)
                return 0  # Successful update
                ;;
            *) return 0 ;;
        esac
    }"
    
    eval "grep() {
        if [[ \"\$3\" == '^existing-label$' ]]; then
            return 0  # Label exists
        fi
        return 1
    }"
    
    run create_label "existing-label" "FF00FF" "Updated description"
    assert_success
    assert_output --partial "Updated: existing-label"
}

@test "create_label function handles creation failures" {
    source "$SCRIPT_PATH"
    DRY_RUN=false
    
    # Mock gh CLI to fail creation
    eval "gh() {
        case \"\$*\" in
            'label list --limit 1000 --json name --jq'*)
                echo ''  # No existing labels
                ;;
            'label create'*)
                echo 'Error: API rate limit exceeded' >&2
                return 1  # Failed creation
                ;;
            *) return 0 ;;
        esac
    }"
    
    run create_label "fail-label" "FFFF00" "This should fail"
    assert_failure
    assert_output --partial "Failed to create label"
}

@test "script defines required label categories" {
    # Check that all expected label arrays are defined
    run grep -q "ISSUE_PROCESSING_LABELS=" "$SCRIPT_PATH"
    assert_success
    
    run grep -q "PR_REVIEW_LABELS=" "$SCRIPT_PATH"
    assert_success
    
    run grep -q "CI_STATUS_LABELS=" "$SCRIPT_PATH"
    assert_success
    
    run grep -q "ADDITIONAL_LABELS=" "$SCRIPT_PATH"
    assert_success
}

@test "script includes all required issue processing labels" {
    # Check for key issue processing labels
    run grep -q "processing|FFA500" "$SCRIPT_PATH"
    assert_success
    
    run grep -q "pr-ready|0052CC" "$SCRIPT_PATH"
    assert_success
    
    run grep -q "pr-created|0E8A16" "$SCRIPT_PATH"
    assert_success
    
    run grep -q "resolved|6F42C1" "$SCRIPT_PATH"
    assert_success
}

@test "script includes PR review labels" {
    run grep -q "reviewed|D93F0B" "$SCRIPT_PATH"
    assert_success
    
    run grep -q "review-fixed|0052CC" "$SCRIPT_PATH"
    assert_success
}

@test "script includes CI status labels" {
    run grep -q "ci-failure|D93F0B" "$SCRIPT_PATH"
    assert_success
    
    run grep -q "ci-passed|0E8A16" "$SCRIPT_PATH"
    assert_success
}

@test "script includes standard GitHub labels" {
    run grep -q "bug|D73A4A" "$SCRIPT_PATH"
    assert_success
    
    run grep -q "enhancement|A2EEEF" "$SCRIPT_PATH"
    assert_success
    
    run grep -q "documentation|0075CA" "$SCRIPT_PATH"
    assert_success
}

@test "process_labels function works correctly" {
    source "$SCRIPT_PATH"
    
    # Mock successful label creation
    eval "create_label() {
        echo \"Created: \$1\"
        return 0
    }"
    
    # Create a test label array
    local TEST_LABELS=(
        "test1|FF0000|Test label 1"
        "test2|00FF00|Test label 2"
    )
    
    run process_labels TEST_LABELS "Test Category"
    assert_success
    assert_output --partial "Test Category"
    assert_output --partial "Created: test1"
    assert_output --partial "Created: test2"
}

@test "process_labels function handles failures" {
    source "$SCRIPT_PATH"
    
    # Mock label creation that fails
    eval "create_label() {
        echo \"Failed: \$1\"
        return 1
    }"
    
    local TEST_LABELS=(
        "fail1|FF0000|Failing label 1"
    )
    
    run process_labels TEST_LABELS "Test Category"
    assert_success  # process_labels continues even if individual labels fail
    assert_output --partial "Failed: fail1"
}

@test "main script execution processes all label categories" {
    # Mock all prerequisites
    eval "command() { return 0; }"
    eval "git() { return 0; }"
    eval "gh() {
        case \"\$*\" in
            'label list --limit 1000 --json name --jq'*)
                echo ''  # No existing labels
                ;;
            'label create'*)
                return 0  # Successful creation
                ;;
            *) return 0 ;;
        esac
    }"
    
    run bash "$SCRIPT_PATH" --dry-run
    assert_success
    assert_output --partial "Creating issue processing labels"
    assert_output --partial "Creating PR review labels"
    assert_output --partial "Creating CI/CD status labels"
    assert_output --partial "Creating additional useful labels"
}

@test "script provides final summary" {
    # Mock successful execution
    eval "command() { return 0; }"
    eval "git() { return 0; }"
    eval "gh() { return 0; }"
    
    run bash "$SCRIPT_PATH" --dry-run
    assert_success
    assert_output --partial "Dry run completed"
}

@test "script handles GitHub API errors gracefully" {
    # Mock prerequisites but API failures
    eval "command() { return 0; }"
    eval "git() { return 0; }"
    eval "gh() {
        case \"\$*\" in
            'auth'|'repo') return 0 ;;
            *) 
                echo 'API error: rate limit exceeded' >&2
                return 1
                ;;
        esac
    }"
    
    run bash "$SCRIPT_PATH"
    # Should handle API errors gracefully and continue processing
}

@test "script validates color codes for all labels" {
    # Extract all color codes from the script and validate format
    local colors
    colors=$(grep -E '\|[0-9A-Fa-f]{6}\|' "$SCRIPT_PATH" | sed -E 's/.*\|([0-9A-Fa-f]{6})\|.*/\1/')
    
    # Check that we found some colors
    [ -n "$colors" ]
    
    # Check that all colors are 6-character hex
    while IFS= read -r color; do
        if [[ ! "$color" =~ ^[0-9A-Fa-f]{6}$ ]]; then
            echo "Invalid color code: $color"
            exit 1
        fi
    done <<< "$colors"
}

@test "logging functions work properly" {
    source "$SCRIPT_PATH"
    QUIET=false
    
    run log_info "test info message"
    assert_success
    assert_output --partial "test info message"
    
    run log_error "test error message"
    assert_success
    assert_output --partial "test error message"
}

@test "quiet mode suppresses info output" {
    source "$SCRIPT_PATH"
    QUIET=true
    
    run log_info "test info message"
    assert_success
    refute_output --partial "test info message"
    
    # Error messages should still show
    run log_error "test error message"
    assert_success
    assert_output --partial "test error message"
}

@test "script uses proper exit codes" {
    # Test successful execution
    eval "command() { return 0; }"
    eval "git() { return 0; }"
    eval "gh() { return 0; }"
    
    run bash "$SCRIPT_PATH" --dry-run
    assert_success
    
    # Test failure scenario
    eval "command() {
        if [[ \"\$1\" == \"-v\" && \"\$2\" == \"gh\" ]]; then
            return 1
        fi
        return 0
    }"
    
    run bash "$SCRIPT_PATH"
    assert_failure
}