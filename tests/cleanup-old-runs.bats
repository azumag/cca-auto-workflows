#!/usr/bin/env bats
#
# Tests for cleanup-old-runs.sh script

# Setup and teardown
setup() {
    load 'helpers/test-helpers'
    setup_script_test
    
    # Copy the script to test location
    cp "$BATS_TEST_DIRNAME/../scripts/cleanup-old-runs.sh" "$TEST_TEMP_DIR/cleanup-old-runs.sh"
    chmod +x "$TEST_TEMP_DIR/cleanup-old-runs.sh"
    
    SCRIPT_UNDER_TEST="$TEST_TEMP_DIR/cleanup-old-runs.sh"
}

teardown() {
    teardown_script_test
}

@test "cleanup-old-runs.sh: script exists and is executable" {
    assert_file_exists "$SCRIPT_UNDER_TEST"
    assert_file_executable "$SCRIPT_UNDER_TEST"
}

@test "cleanup-old-runs.sh: displays correct script header" {
    run bash -c "head -5 '$SCRIPT_UNDER_TEST'"
    assert_success
    assert_output --partial "Cleanup Old Workflow Runs Script"
    assert_output --partial "Claude Code Auto Workflows"
}

@test "cleanup-old-runs.sh: shows help when requested" {
    run "$SCRIPT_UNDER_TEST" --help
    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "--days DAYS"
    assert_output --partial "--max-runs RUNS"
    assert_output --partial "--dry-run"
    assert_output --partial "--force"
}

@test "cleanup-old-runs.sh: shows help with -h flag" {
    run "$SCRIPT_UNDER_TEST" -h
    assert_success
    assert_output --partial "Usage:"
}

@test "cleanup-old-runs.sh: fails with unknown option" {
    run "$SCRIPT_UNDER_TEST" --unknown-option
    assert_failure
    assert_output --partial "Unknown option: --unknown-option"
}

@test "cleanup-old-runs.sh: parse_arguments with default values" {
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        parse_arguments
    "
    assert_success
    assert_output "30 100"
}

@test "cleanup-old-runs.sh: parse_arguments with custom days" {
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        parse_arguments --days 7
    "
    assert_success
    assert_output "7 100"
}

@test "cleanup-old-runs.sh: parse_arguments with custom max-runs" {
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        parse_arguments --max-runs 50
    "
    assert_success
    assert_output "30 50"
}

@test "cleanup-old-runs.sh: parse_arguments with both custom values" {
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        parse_arguments --days 14 --max-runs 75
    "
    assert_success
    assert_output "14 75"
}

@test "cleanup-old-runs.sh: parse_arguments fails with invalid days" {
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        parse_arguments --days invalid
    "
    assert_failure
    assert_output --partial "Invalid or missing value for --days"
}

@test "cleanup-old-runs.sh: parse_arguments fails with invalid max-runs" {
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        parse_arguments --max-runs abc
    "
    assert_failure
    assert_output --partial "Invalid or missing value for --max-runs"
}

@test "cleanup-old-runs.sh: check_prerequisites fails without gh CLI" {
    # Remove gh from PATH
    export PATH="/usr/bin:/bin"
    
    run bash -c "source '$SCRIPT_UNDER_TEST'; check_prerequisites"
    assert_failure
    assert_output --partial "GitHub CLI (gh) is required"
    assert_output --partial "https://cli.github.com/"
}

@test "cleanup-old-runs.sh: check_prerequisites fails when not authenticated" {
    create_gh_mock "" 1  # gh auth status fails
    
    run bash -c "source '$SCRIPT_UNDER_TEST'; check_prerequisites"
    assert_failure
    assert_output --partial "Not authenticated with GitHub CLI"
    assert_output --partial "gh auth login"
}

@test "cleanup-old-runs.sh: check_prerequisites fails without repo access" {
    # Mock gh commands
    cat > "$TEST_TEMP_DIR/bin/gh" << 'EOF'
#!/bin/bash
case "$1 $2" in
    "auth status") exit 0 ;;
    "repo view") exit 1 ;;
    *) exit 0 ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/gh"
    
    run bash -c "source '$SCRIPT_UNDER_TEST'; check_prerequisites"
    assert_failure
    assert_output --partial "Cannot access repository"
}

@test "cleanup-old-runs.sh: check_prerequisites succeeds with proper setup" {
    create_gh_mock "" 0
    
    run bash -c "source '$SCRIPT_UNDER_TEST'; check_prerequisites"
    assert_success
}

@test "cleanup-old-runs.sh: analyze_workflow_runs function" {
    local responses_dir
    responses_dir=$(create_github_api_responses)
    
    create_gh_mock "$responses_dir/workflow_runs.json" 0
    create_jq_mock "2"  # Mock for length
    create_date_mock "2024-01-01"
    
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        # Override jq to provide consistent output
        jq() {
            case \"\$*\" in
                *length*) echo '5' ;;
                *group_by*) echo 'CI: 3 runs (2 success, 1 failed)' ;;
                *) echo 'mock output' ;;
            esac
        }
        export -f jq
        analyze_workflow_runs 30 100
    "
    assert_success
    assert_output --partial "Repository Statistics"
    assert_output --partial "Total workflow runs:"
    assert_output --partial "Keeping runs newer than:"
}

@test "cleanup-old-runs.sh: identify_cleanup_candidates function" {
    create_gh_mock "" 0
    create_date_mock "2024-01-01"
    create_jq_mock ""
    
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        # Mock commands for testing
        wc() { echo '5'; }
        export -f wc
        identify_cleanup_candidates 30 100
    "
    assert_success
    assert_output --partial "Identifying runs for cleanup"
    assert_output --partial "Runs older than 30 days:"
}

@test "cleanup-old-runs.sh: perform_cleanup with dry-run" {
    export DRY_RUN=true
    
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        perform_cleanup 30 100
    "
    assert_success
    assert_output --partial "DRY RUN: Showing what would be cleaned up"
}

@test "cleanup-old-runs.sh: perform_cleanup requires confirmation" {
    export DRY_RUN=false
    export FORCE=false
    
    # Mock user input (simulate 'n' response)
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        echo 'n' | perform_cleanup 30 100
    "
    assert_success
    assert_output --partial "This will permanently delete workflow runs"
    assert_output --partial "Cleanup cancelled by user"
}

@test "cleanup-old-runs.sh: perform_cleanup with force flag" {
    export DRY_RUN=false
    export FORCE=true
    
    create_gh_mock "" 0
    create_date_mock "2024-01-01"
    
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        # Mock gh commands for cleanup
        gh() {
            case \"\$1 \$2\" in
                \"run list\") echo '[]' ;;
                \"run delete\"*) echo 'Deleted run' ;;
                \"workflow list\") echo '[]' ;;
                *) return 0 ;;
            esac
        }
        export -f gh
        perform_cleanup 30 100
    "
    assert_success
    assert_output --partial "Starting cleanup process"
    assert_output --partial "Cleanup completed"
}

@test "cleanup-old-runs.sh: logging functions work correctly" {
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
    assert_output --partial "[CLEANUP] Test header message"
}

@test "cleanup-old-runs.sh: main function with dry-run" {
    create_gh_mock "" 0
    create_date_mock "2024-01-01"
    
    run "$SCRIPT_UNDER_TEST" --dry-run
    assert_success
    assert_output --partial "Starting workflow runs cleanup"
    assert_output --partial "Repository Statistics"
    assert_output --partial "DRY RUN"
    assert_output --partial "Run without --dry-run to perform actual cleanup"
}

@test "cleanup-old-runs.sh: main function handles no cleanup needed" {
    create_gh_mock "" 0
    create_date_mock "2024-01-01"
    
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        # Mock identify_cleanup_candidates to return 0
        identify_cleanup_candidates() {
            echo 'No cleanup needed'
            return 0
        }
        export -f identify_cleanup_candidates
        main --dry-run
    "
    assert_success
    assert_output --partial "No cleanup needed! Repository is already optimized"
}

@test "cleanup-old-runs.sh: handles complex argument combinations" {
    create_gh_mock "" 0
    create_date_mock "2024-01-01"
    
    run "$SCRIPT_UNDER_TEST" --days 7 --max-runs 25 --dry-run
    assert_success
    assert_output --partial "Keeping runs newer than:"
    assert_output --partial "Max runs per workflow: 25"
}

@test "cleanup-old-runs.sh: date command integration" {
    create_date_mock "2023-12-16"
    
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        cutoff_date=\$(date -d '30 days ago' '+%Y-%m-%d')
        echo \"Cutoff date: \$cutoff_date\"
    "
    assert_success
    assert_output --partial "Cutoff date: 2023-12-16"
}

@test "cleanup-old-runs.sh: workflow list integration" {
    create_gh_mock "" 0
    
    run bash -c "
        source '$SCRIPT_UNDER_TEST'
        # Mock gh workflow list
        gh() {
            case \"\$1 \$2\" in
                \"workflow list\") echo '[{\"name\":\"CI\"},{\"name\":\"Deploy\"}]' ;;
                *) return 0 ;;
            esac
        }
        export -f gh
        
        # Test workflow list processing
        gh workflow list --json name --jq '.[].name' | while read -r workflow_name; do
            echo \"Found workflow: \$workflow_name\"
        done
    "
    assert_success
}