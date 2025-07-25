#!/usr/bin/env bats

# Tests for troubleshooting feedback collection system

load 'helpers/test-helpers.bash'

setup() {
    # Create temporary test directories
    export TEST_FEEDBACK_DIR="${BATS_TMPDIR}/test-feedback"
    export FEEDBACK_DIR="$TEST_FEEDBACK_DIR"
    mkdir -p "$TEST_FEEDBACK_DIR"
    
    # Source the feedback library
    source "$PROJECT_ROOT/scripts/lib/common.sh"
    source "$PROJECT_ROOT/scripts/lib/troubleshooting-feedback.sh"
}

teardown() {
    # Clean up test directories
    rm -rf "$TEST_FEEDBACK_DIR"
}

@test "troubleshooting feedback module initialization" {
    run troubleshooting_feedback_init
    [ "$status" -eq 0 ]
    [ -d "$TEST_FEEDBACK_DIR" ]
}

@test "list troubleshooting steps shows available steps" {
    run list_troubleshooting_steps
    [ "$status" -eq 0 ]
    [[ "$output" =~ "range_fix" ]]
    [[ "$output" =~ "cache_check" ]]
    [[ "$output" =~ "auth_failure" ]]
}

@test "start troubleshooting session creates session file" {
    troubleshooting_feedback_init
    
    run start_troubleshooting_session "range_fix" "Test description"
    [ "$status" -eq 0 ]
    
    # Extract session ID from output
    local session_id
    session_id=$(echo "$output" | grep "Started troubleshooting session:" | awk '{print $4}')
    
    # Check that session file was created
    [ -f "${TEST_FEEDBACK_DIR}/${session_id}.session" ]
    
    # Verify session file content
    run cat "${TEST_FEEDBACK_DIR}/${session_id}.session"
    [[ "$output" =~ "range_fix" ]]
    [[ "$output" =~ "Test description" ]]
    [[ "$output" =~ "in_progress" ]]
}

@test "end troubleshooting session completes successfully" {
    troubleshooting_feedback_init
    
    # Start a session
    local session_id
    session_id=$(start_troubleshooting_session "range_fix" "Test session")
    
    # Wait a moment to ensure measurable duration
    sleep 1
    
    # End the session
    run end_troubleshooting_session "$session_id" "success"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Completed troubleshooting session" ]]
    [[ "$output" =~ "Outcome: success" ]]
    
    # Check that feedback was logged
    [ -f "${TEST_FEEDBACK_DIR}/feedback.log" ]
    run cat "${TEST_FEEDBACK_DIR}/feedback.log"
    [[ "$output" =~ "range_fix" ]]
    [[ "$output" =~ "success" ]]
    
    # Session file should be cleaned up
    [ ! -f "${TEST_FEEDBACK_DIR}/${session_id}.session" ]
}

@test "feedback report generation works with data" {
    troubleshooting_feedback_init
    
    # Create some test feedback data
    cat > "${TEST_FEEDBACK_DIR}/feedback.log" << 'EOF'
2024-07-24T12:00:00Z,session1,range_fix,success,3.5,"2-5 minutes","Test session 1"
2024-07-24T12:30:00Z,session2,cache_check,failure,15.2,"8-20 minutes","Test session 2"
2024-07-24T13:00:00Z,session3,range_fix,success,2.1,"2-5 minutes","Test session 3"
EOF
    
    run generate_feedback_report "console" "*" 30
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Overall Statistics" ]]
    [[ "$output" =~ "Total troubleshooting sessions: 3" ]]
    [[ "$output" =~ "range_fix" ]]
    [[ "$output" =~ "cache_check" ]]
}

@test "feedback report handles empty data gracefully" {
    troubleshooting_feedback_init
    
    run generate_feedback_report "console" "*" 30
    [ "$status" -eq 1 ]
    [[ "$output" =~ "No feedback data available" ]]
}

@test "parse time estimate function works correctly" {
    run parse_time_estimate "2-5 minutes"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "120 300" ]]
    
    run parse_time_estimate "10-20 minutes"  
    [ "$status" -eq 0 ]
    [[ "$output" =~ "600 1200" ]]
    
    run parse_time_estimate "invalid format"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "0 0" ]]
}

@test "get active sessions lists current sessions" {
    troubleshooting_feedback_init
    
    # No active sessions initially
    run get_active_sessions
    [ "$status" -eq 0 ]
    [[ "$output" =~ "No active troubleshooting sessions" ]]
    
    # Start a session
    local session_id
    session_id=$(start_troubleshooting_session "range_fix" "Active test session")
    
    # Should now show active session
    run get_active_sessions
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Active Troubleshooting Sessions" ]]
    [[ "$output" =~ "$session_id" ]]
    [[ "$output" =~ "range_fix" ]]
}

@test "troubleshooting feedback script runs basic commands" {
    # Test that the main script runs without errors
    run "$PROJECT_ROOT/scripts/troubleshooting-feedback.sh" list-steps
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Available Troubleshooting Steps" ]]
    
    run "$PROJECT_ROOT/scripts/troubleshooting-feedback.sh" help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Troubleshooting Feedback Collection Tool" ]]
}

@test "troubleshooting analytics script runs basic commands" {
    # Test that the analytics script runs without errors
    run "$PROJECT_ROOT/scripts/troubleshooting-analytics.sh" help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Troubleshooting Analytics Dashboard" ]]
}

@test "feedback cleanup removes old data" {
    troubleshooting_feedback_init
    
    # Create old feedback data
    local old_date
    old_date=$(date -d "100 days ago" -Iseconds)
    cat > "${TEST_FEEDBACK_DIR}/feedback.log" << EOF
${old_date},old_session,range_fix,success,3.0,"2-5 minutes","Old data"
$(date -Iseconds),new_session,range_fix,success,4.0,"2-5 minutes","New data"
EOF
    
    # Run cleanup
    run troubleshooting_feedback_cleanup
    [ "$status" -eq 0 ]
    
    # Check that old data was removed but new data remains
    run cat "${TEST_FEEDBACK_DIR}/feedback.log"
    [[ "$output" =~ "new_session" ]]
    [[ ! "$output" =~ "old_session" ]]
}

@test "invalid step ID is rejected" {
    troubleshooting_feedback_init
    
    run start_troubleshooting_session "invalid_step_id" "Test"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown troubleshooting step" ]]
}

@test "ending non-existent session fails gracefully" {
    troubleshooting_feedback_init
    
    run end_troubleshooting_session "non_existent_session" "success"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Session not found" ]]
}