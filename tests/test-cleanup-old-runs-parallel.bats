#!/usr/bin/env bats
#
# Unit and integration tests for parallel processing in cleanup-old-runs.sh
# Focuses on rate limiting, file locking, and concurrent API operations

setup() {
    load 'helpers/test-helpers'
    setup_script_test
    
    # Set up environment for parallel cleanup testing
    export GITHUB_TOKEN="test-token-cleanup"
    export GITHUB_REPOSITORY="test-org/cleanup-test-repo"
    export DEFAULT_KEEP_DAYS=$DEFAULT_CLEANUP_DAYS
    export DEFAULT_MAX_RUNS=50
    export RATE_LIMIT_REQUESTS_PER_MINUTE=60
    export BURST_SIZE=10
    export RATE_LIMIT_DELAY=1
    
    # Create mocks for cleanup testing
    create_cleanup_mocks
}

teardown() {
    cleanup_cleanup_processes
    teardown_script_test
}

create_cleanup_mocks() {
    # GitHub CLI mock for cleanup testing with rate limiting simulation
    cat > "$TEST_TEMP_DIR/bin/gh" << 'EOF'
#!/bin/bash
# GitHub CLI mock for cleanup parallel processing tests

# Simulate API call delay
sleep 0.1

case "$1 $2" in
    "auth status")
        echo "✓ Logged in to github.com as test-user"
        exit 0
        ;;
    "repo view")
        echo "test-org/cleanup-test-repo"
        exit 0
        ;;
    "api rate_limit")
        # Simulate varying rate limit conditions
        local remaining=$(shuf -i 100-4900 -n 1)
        cat << EOF
{
  "rate": {
    "limit": $GITHUB_API_LIMIT_DEFAULT,
    "used": $((5000 - remaining)),
    "remaining": $remaining,
    "reset": 1640995200
  }
}
EOF
        exit 0
        ;;
    "run list"*)
        if [[ "$*" == *"--limit 1000"* ]]; then
            # Generate many runs for testing parallel deletion
            echo "["
            for ((i=1; i<=200; i++)); do
                local days_ago=$((i % 60 + 1))
                local created_date=$(date -d "$days_ago days ago" --iso-8601)
                echo "  {"
                echo "    \"name\": \"Test Workflow $((i % 5 + 1))\","
                echo "    \"status\": \"completed\","
                echo "    \"conclusion\": \"success\","
                echo "    \"createdAt\": \"${created_date}T10:00:00Z\","
                echo "    \"updatedAt\": \"${created_date}T10:05:00Z\","
                echo "    \"databaseId\": $((12000 + i))"
                if [[ $i -lt 200 ]]; then
                    echo "  },"
                else
                    echo "  }"
                fi
            done
            echo "]"
        elif [[ "$*" == *"--workflow="* ]]; then
            # Workflow-specific runs
            local workflow_name=$(echo "$*" | grep -o 'workflow=[^[:space:]]*' | cut -d= -f2 | tr -d '"')
            echo "["
            for ((i=1; i<=60; i++)); do
                echo "  {"
                echo "    \"name\": \"$workflow_name\","
                echo "    \"databaseId\": $((13000 + i))"
                if [[ $i -lt 60 ]]; then
                    echo "  },"
                else
                    echo "  }"
                fi
            done
            echo "]"
        else
            echo "[]"
        fi
        exit 0
        ;;
    "workflow list")
        echo '[
          {"name": "Test Workflow 1"},
          {"name": "Test Workflow 2"},
          {"name": "Test Workflow 3"},
          {"name": "Test Workflow 4"},
          {"name": "Test Workflow 5"}
        ]'
        exit 0
        ;;
    "run delete"*)
        # Extract run ID and simulate deletion with occasional failures
        local run_id=$(echo "$*" | grep -o '[0-9]\+' | head -1)
        
        # Simulate 5% failure rate for testing error handling
        if [[ $((run_id % 20)) -eq 0 ]]; then
            echo "Error: Run not found or cannot be deleted" >&2
            exit 1
        fi
        
        # Add variable delay to simulate real API behavior
        sleep $(bc -l <<< "scale=3; $(shuf -i 50-200 -n 1) / 1000" 2>/dev/null || echo 0.1)
        
        echo "✓ Deleted run $run_id"
        exit 0
        ;;
    *)
        echo "Mock gh: Command '$*' executed"
        exit 0
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/gh"
    
    # Enhanced jq mock for cleanup operations
    cat > "$TEST_TEMP_DIR/bin/jq" << 'EOF'
#!/bin/bash
# jq mock for cleanup parallel processing

input=$(cat)

case "$*" in
    "length")
        # Count items in JSON array
        if [[ "$input" == *"databaseId"* ]]; then
            echo "$input" | grep -o '"databaseId"' | wc -l
        else
            echo "0"
        fi
        ;;
    "-r" ".rate.remaining")
        echo $(shuf -i 100-4900 -n 1)
        ;;
    "-r" ".rate.limit")
        echo "5000"
        ;;
    "-r" ".rate.used")
        echo $(shuf -i 100-4900 -n 1)
        ;;
    *"select(.createdAt"*)
        # Filter by date
        for ((i=1; i<=50; i++)); do
            echo $((12000 + i))
        done
        ;;
    *"tonumber"*)
        # Handle max runs filtering
        for ((i=51; i<=60; i++)); do
            echo $((13000 + i))
        done
        ;;
    *".[]")
        # Return array elements
        for ((i=1; i<=10; i++)); do
            echo $((12000 + i))
        done
        ;;
    *)
        echo "mock_jq_output"
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/jq"
    
    # Mock date command for consistent testing
    cat > "$TEST_TEMP_DIR/bin/date" << 'EOF'
#!/bin/bash
# date mock for cleanup testing

case "$*" in
    "-d "*" days ago --iso-8601")
        local days=$(echo "$*" | grep -o '[0-9]\+')
        echo "2024-01-$(printf "%02d" $((30 - days)))"
        ;;
    "+%s")
        echo "1640995200"
        ;;
    *)
        /bin/date "$@"
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/date"
}

cleanup_cleanup_processes() {
    # Clean up cleanup-specific temporary files and locks
    rm -f /tmp/cleanup_rate_limit_*.lock 2>/dev/null || true
    rm -f /tmp/cleanup_runs_$$.* 2>/dev/null || true
    
    # Kill any lingering processes
    local pids
    pids=$(jobs -p 2>/dev/null) || true
    if [[ -n "$pids" ]]; then
        echo "$pids" | xargs kill -TERM 2>/dev/null || true
        sleep 0.5
        echo "$pids" | xargs kill -KILL 2>/dev/null || true
    fi
}

@test "cleanup parallel: basic rate limiting functionality works" {
    run "$BATS_TEST_DIRNAME/../scripts/cleanup-old-runs.sh" --days 45 --max-runs 10 --force
    assert_success
    
    assert_output --partial "Starting cleanup process"
    assert_output --partial "Cleanup completed!"
}

@test "cleanup parallel: rate limiting prevents API abuse" {
    # Set aggressive rate limiting
    export RATE_LIMIT_REQUESTS_PER_MINUTE=12
    export BURST_SIZE=3
    export RATE_LIMIT_DELAY=2
    
    local start_time end_time duration
    start_time=$(date +%s)
    
    run timeout $TEST_TIMEOUT_LONG "$BATS_TEST_DIRNAME/../scripts/cleanup-old-runs.sh" --days 60 --max-runs 20 --force
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    assert_success
    
    # With rate limiting, should take longer than without
    assert [ "$duration" -ge 3 ]
    
    assert_output --partial "rate limiting" || assert_output --partial "Applying additional rate limiting"
}

@test "cleanup parallel: file locking prevents race conditions in rate limiting" {
    # Create lock file manually to test locking behavior
    local lock_file="/tmp/cleanup_rate_limit_$$.lock"
    
    # Start cleanup in background with lock held
    (
        exec 200>"$lock_file"
        flock -x 200
        sleep 5
        "$BATS_TEST_DIRNAME/../scripts/cleanup-old-runs.sh" --days 30 --max-runs 10 --force
    ) &
    local pid1=$!
    
    # Start another cleanup that should wait for lock
    sleep 1
    "$BATS_TEST_DIRNAME/../scripts/cleanup-old-runs.sh" --days 30 --max-runs 10 --force &
    local pid2=$!
    
    # Wait for both to complete
    wait $pid1
    local exit1=$?
    wait $pid2  
    local exit2=$?
    
    # Both should complete successfully
    assert_equal "$exit1" "0"
    assert_equal "$exit2" "0"
    
    # Lock file should be cleaned up
    assert [ ! -f "$lock_file" ]
}

@test "cleanup parallel: concurrent operations handle API failures gracefully" {
    # Create gh mock that fails for some deletions
    cat > "$TEST_TEMP_DIR/bin/gh" << 'EOF'
#!/bin/bash
case "$1 $2" in
    "auth status"|"repo view"|"workflow list")
        exit 0
        ;;
    "api rate_limit")
        echo '{"rate":{"limit":5000,"used":2500,"remaining":2500,"reset":1640995200}}'
        exit 0
        ;;
    "run list"*)
        echo '[
          {"databaseId": 12001, "createdAt": "2024-01-01T10:00:00Z", "name": "Test 1"},
          {"databaseId": 12002, "createdAt": "2024-01-01T10:00:00Z", "name": "Test 2"},
          {"databaseId": 12003, "createdAt": "2024-01-01T10:00:00Z", "name": "Test 3"},
          {"databaseId": 12004, "createdAt": "2024-01-01T10:00:00Z", "name": "Test 4"},
          {"databaseId": 12005, "createdAt": "2024-01-01T10:00:00Z", "name": "Test 5"}
        ]'
        exit 0
        ;;
    "run delete"*)
        local run_id=$(echo "$*" | grep -o '[0-9]\+' | head -1)
        if [[ "$run_id" == "12003" ]]; then
            echo "API Error: Not found" >&2
            exit 1
        fi
        echo "Deleted run $run_id"
        exit 0
        ;;
    *)
        exit 0
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/gh"
    
    run "$BATS_TEST_DIRNAME/../scripts/cleanup-old-runs.sh" --days 60 --max-runs 3 --force
    assert_success
    
    # Should handle individual failures gracefully
    assert_output --partial "Failed to delete run ID: 12003"
    assert_output --partial "Cleanup completed!"
}

@test "cleanup parallel: progress reporting works during parallel operations" {
    run "$BATS_TEST_DIRNAME/../scripts/cleanup-old-runs.sh" --days 45 --max-runs 20 --force
    assert_success
    
    # Should show progress for parallel operations
    assert_output --partial "Deleting old runs" || assert_output --partial "Deleting"
    assert_output --partial "Processing workflows" || assert_output --partial "workflow"
    assert_output --partial "Cleanup completed!"
}

@test "cleanup parallel: dry run mode works with parallel processing simulation" {
    run "$BATS_TEST_DIRNAME/../scripts/cleanup-old-runs.sh" --days 30 --max-runs 10 --dry-run
    assert_success
    
    assert_output --partial "DRY RUN: Showing what would be cleaned up"
    assert_output --partial "Total cleanup candidates:" || assert_output --partial "candidates"
    
    # Should not actually delete anything
    refute_output --partial "Deleted"
    refute_output --partial "✓ Deleted run"
}

@test "cleanup parallel: handles low API rate limits correctly" {
    # Create mock that reports very low remaining rate limit
    cat > "$TEST_TEMP_DIR/bin/gh" << 'EOF'
#!/bin/bash
case "$1 $2" in
    "auth status"|"repo view"|"workflow list")
        exit 0
        ;;
    "api rate_limit")
        echo '{"rate":{"limit":5000,"used":4950,"remaining":50,"reset":1640995200}}'
        exit 0
        ;;
    "run list"*)
        echo '[{"databaseId": 12001, "createdAt": "2024-01-01T10:00:00Z"}]'
        exit 0
        ;;
    "run delete"*)
        sleep 0.5  # Longer delay to simulate throttling
        echo "Deleted run"
        exit 0
        ;;
    *)
        exit 0
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/gh"
    
    run timeout 20 "$BATS_TEST_DIRNAME/../scripts/cleanup-old-runs.sh" --days 60 --max-runs 5 --force
    assert_success
    
    assert_output --partial "Low GitHub API rate limit remaining: 50 requests"
    assert_output --partial "Applying additional rate limiting"
}

@test "cleanup parallel: handles workflow-specific cleanup correctly" {
    run "$BATS_TEST_DIRNAME/../scripts/cleanup-old-runs.sh" --days 30 --max-runs 5 --force
    assert_success
    
    assert_output --partial "Cleaning up excess runs per workflow"
    assert_output --partial "Processing workflows"
    assert_output --partial "Cleanup completed!"
}

@test "cleanup parallel: signal handling during concurrent operations" {
    # Start cleanup in background
    "$BATS_TEST_DIRNAME/../scripts/cleanup-old-runs.sh" --days 30 --max-runs 10 --force &
    local pid=$!
    
    # Let it start processing
    sleep 2
    
    # Send SIGTERM
    kill -TERM $pid 2>/dev/null || true
    
    # Wait for graceful shutdown
    wait $pid 2>/dev/null || true
    
    # Check that lock files are cleaned up
    local remaining_locks
    remaining_locks=$(find /tmp -name "cleanup_rate_limit_*.lock" 2>/dev/null | wc -l)
    assert_equal "$remaining_locks" "0"
}

@test "cleanup parallel: resource cleanup works correctly" {
    run "$BATS_TEST_DIRNAME/../scripts/cleanup-old-runs.sh" --days 30 --max-runs 10 --force
    assert_success
    
    # Check that temporary files are cleaned up
    local remaining_temp_files
    remaining_temp_files=$(find /tmp -name "cleanup_runs_$$.*" 2>/dev/null | wc -l)
    assert_equal "$remaining_temp_files" "0"
    
    # Check that rate limiting lock files are cleaned up
    local remaining_lock_files
    remaining_lock_files=$(find /tmp -name "cleanup_rate_limit_*.lock" 2>/dev/null | wc -l)
    assert_equal "$remaining_lock_files" "0"
}

@test "cleanup parallel: concurrent cleanup processes don't interfere" {
    # Start two cleanup processes simultaneously
    "$BATS_TEST_DIRNAME/../scripts/cleanup-old-runs.sh" --days 40 --max-runs 15 --force &
    local pid1=$!
    
    "$BATS_TEST_DIRNAME/../scripts/cleanup-old-runs.sh" --days 35 --max-runs 20 --force &
    local pid2=$!
    
    # Wait for both to complete
    wait $pid1
    local exit1=$?
    wait $pid2
    local exit2=$?
    
    # Both should complete successfully without interfering
    assert_equal "$exit1" "0"
    assert_equal "$exit2" "0"
}

@test "cleanup parallel: handles empty run lists gracefully" {
    # Create mock that returns no runs
    cat > "$TEST_TEMP_DIR/bin/gh" << 'EOF'
#!/bin/bash
case "$1 $2" in
    "auth status"|"repo view"|"workflow list")
        exit 0
        ;;
    "api rate_limit")
        echo '{"rate":{"limit":5000,"used":100,"remaining":4900,"reset":1640995200}}'
        exit 0
        ;;
    "run list"*)
        echo "[]"
        exit 0
        ;;
    *)
        exit 0
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/gh"
    
    run "$BATS_TEST_DIRNAME/../scripts/cleanup-old-runs.sh" --days 30 --max-runs 10 --force
    assert_success
    
    assert_output --partial "No cleanup needed! Repository is already optimized."
}

@test "cleanup parallel: validates command line arguments correctly" {
    run "$BATS_TEST_DIRNAME/../scripts/cleanup-old-runs.sh" --days invalid
    assert_failure
    
    assert_output --partial "Invalid or missing value for --days"
}

@test "cleanup parallel: shows help message correctly" {
    run "$BATS_TEST_DIRNAME/../scripts/cleanup-old-runs.sh" --help
    assert_success
    
    assert_output --partial "Usage:"
    assert_output --partial "Cleanup old GitHub Actions workflow runs"
    assert_output --partial "OPTIONS:"
    assert_output --partial "EXAMPLES:"
}

@test "cleanup parallel: handles authentication failures" {
    # Create gh mock that fails authentication
    cat > "$TEST_TEMP_DIR/bin/gh" << 'EOF'
#!/bin/bash
case "$1 $2" in
    "auth status")
        echo "Not logged in" >&2
        exit 1
        ;;
    *)
        exit 0
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/gh"
    
    run "$BATS_TEST_DIRNAME/../scripts/cleanup-old-runs.sh" --days 30 --max-runs 10 --force
    assert_failure
    
    assert_output --partial "Not authenticated with GitHub CLI"
}