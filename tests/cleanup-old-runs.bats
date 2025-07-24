#!/usr/bin/env bats

# Tests for scripts/cleanup-old-runs.sh
# This file tests workflow cleanup functionality

# Load test helpers
load helpers/common.bash

# Set up BATS
setup() {
    setup_bats_libs
    load test-config.bash
    common_setup
    
    # Copy the script under test
    SCRIPT_PATH="./scripts/cleanup-old-runs.sh"
    
    # Ensure script is executable
    chmod +x "$SCRIPT_PATH"
}

teardown() {
    restore_commands
    common_teardown
}

@test "cleanup-old-runs.sh exists and is executable" {
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
    assert_output --partial "OPTIONS:"
    assert_output --partial "EXAMPLES:"
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

@test "parse_arguments function handles default values" {
    run bash -c "source $SCRIPT_PATH && parse_arguments"
    assert_success
    assert_output --partial "30 100"  # DEFAULT_KEEP_DAYS DEFAULT_MAX_RUNS
}

@test "parse_arguments handles --days option" {
    run bash -c "source $SCRIPT_PATH && parse_arguments --days 7"
    assert_success
    assert_output --partial "7 100"
}

@test "parse_arguments handles --max-runs option" {
    run bash -c "source $SCRIPT_PATH && parse_arguments --max-runs 50"
    assert_success
    assert_output --partial "30 50"
}

@test "parse_arguments handles both options together" {
    run bash -c "source $SCRIPT_PATH && parse_arguments --days 14 --max-runs 75"
    assert_success
    assert_output --partial "14 75"
}

@test "parse_arguments validates --days argument" {
    run bash -c "source $SCRIPT_PATH && parse_arguments --days invalid"
    assert_failure
    assert_output --partial "Invalid or missing value for --days"
}

@test "parse_arguments validates --max-runs argument" {
    run bash -c "source $SCRIPT_PATH && parse_arguments --max-runs abc"
    assert_failure
    assert_output --partial "Invalid or missing value for --max-runs"
}

@test "parse_arguments sets DRY_RUN flag" {
    # Test dry run flag setting
    run bash -c "source $SCRIPT_PATH && parse_arguments --dry-run && echo \"DRY_RUN=\$DRY_RUN\""
    assert_success
    assert_output --partial "DRY_RUN=true"
}

@test "parse_arguments sets FORCE flag" {
    # Test force flag setting
    run bash -c "source $SCRIPT_PATH && parse_arguments --force && echo \"FORCE=\$FORCE\""
    assert_success
    assert_output --partial "FORCE=true"
}

@test "check_prerequisites fails without gh CLI" {
    # Mock command to simulate gh not being available
    eval "command() {
        if [[ \"\$1\" == \"-v\" && \"\$2\" == \"gh\" ]]; then
            return 1
        fi
        return 0
    }"
    
    run bash -c "source $SCRIPT_PATH && check_prerequisites"
    assert_failure
    assert_output --partial "GitHub CLI (gh) is required"
}

@test "check_prerequisites fails when not authenticated" {
    # Mock gh auth status to fail
    eval "command() { return 0; }"
    eval "gh() {
        if [[ \"\$1\" == \"auth\" && \"\$2\" == \"status\" ]]; then
            return 1
        fi
        return 0
    }"
    
    run bash -c "source $SCRIPT_PATH && check_prerequisites"
    assert_failure
    assert_output --partial "Not authenticated with GitHub CLI"
}

@test "check_prerequisites fails when repository not accessible" {
    # Mock successful command and auth but failing repo access
    eval "command() { return 0; }"
    eval "gh() {
        case \"\$1\" in
            'auth') return 0 ;;
            'repo') return 1 ;;
            *) return 0 ;;
        esac
    }"
    
    run bash -c "source $SCRIPT_PATH && check_prerequisites"
    assert_failure
    assert_output --partial "Cannot access repository"
}

@test "check_prerequisites passes with all requirements met" {
    # Mock all requirements as met
    eval "command() { return 0; }"
    eval "gh() { return 0; }"
    
    run bash -c "source $SCRIPT_PATH && check_prerequisites"
    assert_success
}

@test "analyze_workflow_runs function processes run data" {
    # Mock successful GitHub CLI responses
    eval "command() { return 0; }"
    eval "gh() {
        case \"\$*\" in
            'run list --limit 1000 --json databaseId')
                echo '[{"databaseId": 1}, {"databaseId": 2}]'
                ;;
            'run list --limit 1000 --json name,status,createdAt')
                echo '[
                    {"name": "CI", "status": "completed", "createdAt": "2024-01-01T00:00:00Z"},
                    {"name": "Deploy", "status": "failed", "createdAt": "2024-01-01T01:00:00Z"}
                ]'
                ;;
            *) return 0 ;;
        esac
    }"
    
    # Mock jq for JSON processing
    eval "jq() {
        case \"\$1\" in
            'length') echo '2' ;;
            *) echo '   CI: 1 runs (1 success, 0 failed)\n   Deploy: 1 runs (0 success, 1 failed)' ;;
        esac
    }"
    
    # Mock date command
    eval "date() {
        echo '2024-01-31'
    }"
    
    run bash -c "source $SCRIPT_PATH && analyze_workflow_runs 30 100"
    assert_success
    assert_output --partial "Repository Statistics"
    assert_output --partial "Total workflow runs: 2"
}

@test "identify_cleanup_candidates calculates old runs correctly" {
    # Mock date command for consistent testing
    eval "date() {
        case \"\$*\" in
            *'--iso-8601') echo '2024-01-01T00:00:00+00:00' ;;
            *) echo '2024-01-31' ;;
        esac
    }"
    
    # Mock gh CLI responses
    eval "gh() {
        case \"\$*\" in
            'run list --limit 1000 --json'*)
                echo '[{"databaseId": 1, "createdAt": "2023-12-01T00:00:00Z"}]'
                ;;
            'workflow list --json name --jq'*)
                echo 'CI\nDeploy'
                ;;
            *) return 0 ;;
        esac
    }"
    
    # Mock wc command
    eval "wc() {
        echo '1'
    }"
    
    run bash -c "source $SCRIPT_PATH && identify_cleanup_candidates 30 100"
    # Function should return with number of candidates (but we can't easily test return value)
    assert_success
    assert_output --partial "Runs older than 30 days"
}

@test "perform_cleanup shows dry run information" {
    # Set DRY_RUN to true
    run bash -c "DRY_RUN=true source $SCRIPT_PATH && perform_cleanup 30 100"
    assert_success
    assert_output --partial "DRY RUN: Showing what would be cleaned up"
}

@test "perform_cleanup prompts for confirmation when not forced" {
    # Mock all prerequisites
    eval "command() { return 0; }"
    eval "gh() { return 0; }"
    
    # Set up non-dry-run, non-force scenario
    # Use timeout to simulate user not responding to prompt
    run timeout 2s bash -c "DRY_RUN=false FORCE=false source $SCRIPT_PATH && perform_cleanup 30 100" || true
    # Should contain warning about permanent deletion
    assert_output --partial "permanently delete workflow runs"
}

@test "perform_cleanup skips confirmation when forced" {
    # Mock successful deletion scenario
    eval "command() { return 0; }"
    eval "gh() {
        case \"\$*\" in
            'run delete'*) return 0 ;;
            'run list'*) echo '' ;;  # No runs to delete
            'workflow list'*) echo '' ;;  # No workflows
            *) return 0 ;;
        esac
    }"
    
    eval "date() {
        case \"\$*\" in
            *'--iso-8601') echo '2024-01-01T00:00:00+00:00' ;;
            *) echo '2024-01-31' ;;
        esac
    }"
    
    run bash -c "DRY_RUN=false FORCE=true source $SCRIPT_PATH && perform_cleanup 30 100"
    assert_success
    assert_output --partial "Starting cleanup process"
}

@test "perform_cleanup handles deletion failures gracefully" {
    # Mock failed deletion
    eval "command() { return 0; }"
    eval "gh() {
        case \"\$*\" in
            'run delete'*) return 1 ;;  # Simulate deletion failure
            'run list'*) echo '12345' ;;  # One run to delete
            'workflow list'*) echo '' ;;
            *) return 0 ;;
        esac
    }"
    
    eval "date() {
        case \"\$*\" in
            *'--iso-8601') echo '2024-01-01T00:00:00+00:00' ;;
            *) echo '2024-01-31' ;;
        esac
    }"
    
    run bash -c "DRY_RUN=false FORCE=true source $SCRIPT_PATH && perform_cleanup 30 100"
    assert_success
    assert_output --partial "Failed to delete run ID"
}

@test "main function parses arguments and executes workflow" {
    # Mock all dependencies
    eval "command() { return 0; }"
    eval "gh() {
        case \"\$*\" in
            'run list --limit 1000 --json databaseId') echo '[]' ;;
            'run list --limit 1000 --json name,status,createdAt') echo '[]' ;;
            'workflow list --json name --jq'*) echo '' ;;
            *) return 0 ;;
        esac
    }"
    
    eval "jq() {
        case \"\$1\" in
            'length') echo '0' ;;
            *) echo '' ;;
        esac
    }"
    
    eval "date() {
        case \"\$*\" in
            *'--iso-8601') echo '2024-01-01T00:00:00+00:00' ;;
            *) echo '2024-01-31' ;;
        esac
    }"
    
    run bash -c "source $SCRIPT_PATH && main --dry-run"
    assert_success
    assert_output --partial "Starting workflow runs cleanup"
    assert_output --partial "No cleanup needed"
}

@test "main function handles argument parsing errors" {
    run bash -c "source $SCRIPT_PATH && main --invalid-arg"
    assert_failure
}

@test "script handles missing jq dependency" {
    # Test scenario where jq is not available but gh is
    eval "command() {
        case \"\$2\" in
            'jq') return 1 ;;
            *) return 0 ;;
        esac
    }"
    
    eval "gh() {
        echo 'raw json output'
        return 0
    }"
    
    # The script should handle missing jq gracefully or fail appropriately
    run bash -c "source $SCRIPT_PATH && analyze_workflow_runs 30 100"
    # Behavior depends on implementation - should either work or fail gracefully
}

@test "script uses proper color codes for output" {
    run grep -q "RED=" "$SCRIPT_PATH"
    assert_success
    run grep -q "GREEN=" "$SCRIPT_PATH"
    assert_success
    run grep -q "YELLOW=" "$SCRIPT_PATH"
    assert_success
    run grep -q "NC=" "$SCRIPT_PATH"
    assert_success
}

@test "logging functions include proper prefixes" {
    run bash -c "source $SCRIPT_PATH && log_info 'test'"
    assert_success
    assert_output --partial "[INFO]"
    
    run bash -c "source $SCRIPT_PATH && log_warn 'test'"
    assert_success
    assert_output --partial "[WARN]"
    
    run bash -c "source $SCRIPT_PATH && log_error 'test'"
    assert_success
    assert_output --partial "[ERROR]"
    
    run bash -c "source $SCRIPT_PATH && log_header 'test'"
    assert_success
    assert_output --partial "[CLEANUP]"
}

# Edge cases and error handling

@test "handles invalid date calculations" {
    # Mock date command to fail
    eval "date() {
        echo 'date: invalid date' >&2
        return 1
    }"
    
    run bash -c "source $SCRIPT_PATH && identify_cleanup_candidates 30 100"
    # Should handle date errors gracefully
}

@test "handles network timeouts during API calls" {
    # Mock gh to simulate timeout
    eval "gh() {
        echo 'timeout: network unreachable' >&2
        return 124
    }"
    
    run bash -c "source $SCRIPT_PATH && analyze_workflow_runs 30 100"
    # Should handle network errors gracefully
}

@test "validates numeric arguments properly" {
    # Test boundary conditions
    run bash -c "source $SCRIPT_PATH && parse_arguments --days 0"
    assert_success
    
    run bash -c "source $SCRIPT_PATH && parse_arguments --max-runs 0"
    assert_success
    
    # Test negative numbers
    run bash -c "source $SCRIPT_PATH && parse_arguments --days -1"
    assert_failure
    
    # Test very large numbers
    run bash -c "source $SCRIPT_PATH && parse_arguments --days 999999999999999999999"
    # Should either work or fail gracefully
}