#!/usr/bin/env bats
#
# Unit tests for GitHub API module functionality
# Tests API initialization, rate limiting, caching, and error handling

# Setup and teardown
setup() {
    load '../helpers/test-helpers'
    setup_test_environment
    
    # Source the GitHub API library
    source "$BATS_TEST_DIRNAME/../../scripts/lib/common.sh"
    source "$BATS_TEST_DIRNAME/../../scripts/lib/github-api.sh"
    
    # Set up test environment
    TEST_API_CACHE_DIR="$TEST_TEMP_DIR/github_api_cache"
    export GITHUB_API_CACHE_DIR="$TEST_API_CACHE_DIR"
    export GITHUB_API_CACHE_TTL=300
    
    # Mock GitHub CLI
    create_gh_mock "/dev/null" 0
}

teardown() {
    teardown_test_environment
}

# GitHub API initialization tests
@test "github_api_init: initializes successfully with gh CLI available" {
    run github_api_init
    assert_success
    assert_output --partial "GitHub API module initialized"
    
    # Verify cache directory was created
    assert [ -d "$GITHUB_API_CACHE_DIR" ]
}

@test "github_api_init: fails when gh CLI is not available" {
    # Remove gh from PATH
    export PATH="/usr/bin:/bin"
    
    run github_api_init
    assert_failure
    assert_output --partial "GitHub CLI (gh) is required"
}

@test "github_api_init: fails when gh CLI authentication is invalid" {
    # Mock gh auth status to fail
    create_gh_mock "/dev/null" 1
    
    run github_api_init
    assert_failure
    assert_output --partial "GitHub CLI authentication required"
}

@test "github_api_init: sets up cache directory with correct permissions" {
    github_api_init
    
    # Check cache directory exists with correct permissions
    assert [ -d "$GITHUB_API_CACHE_DIR" ]
    local perms
    perms=$(stat -c %a "$GITHUB_API_CACHE_DIR")
    assert_equal "$perms" "700"
}

# GitHub API call tests
@test "github_api_call: makes successful API call" {
    github_api_init
    
    # Mock API response
    local mock_response='{"message": "test response"}'
    create_gh_mock <(echo "$mock_response") 0
    
    run github_api_call "test/endpoint"
    assert_success
    assert_output "$mock_response"
}

@test "github_api_call: uses cached response on second call" {
    github_api_init
    
    # Mock API response
    local mock_response='{"cached": "response"}'
    create_gh_mock <(echo "$mock_response") 0
    
    # First call - should hit API
    github_api_call "cached/endpoint" > /dev/null
    
    # Second call - should use cache
    # We'll verify by removing gh from PATH and checking it still works
    export PATH="/usr/bin:/bin"
    
    run github_api_call "cached/endpoint"
    assert_success
    assert_output "$mock_response"
}

@test "github_api_call: increments API call counter" {
    github_api_init
    github_api_reset_metrics
    
    create_gh_mock <(echo '{"test": "data"}') 0
    
    # Make multiple API calls
    github_api_call "endpoint1" > /dev/null
    github_api_call "endpoint2" > /dev/null
    
    local metrics
    metrics=$(github_api_get_metrics)
    local call_count
    call_count=$(echo "$metrics" | jq -r '.api_calls_total')
    
    assert_equal "$call_count" "2"
}

@test "github_api_call: handles API failure gracefully" {
    github_api_init
    
    # Mock API failure
    create_gh_mock "/dev/null" 1
    
    run github_api_call "failing/endpoint"
    assert_failure
    assert_output --partial "Failed to call GitHub API endpoint"
}

# Rate limiting tests
@test "github_api_call: checks rate limit before API call" {
    github_api_init
    
    # Mock rate limit response indicating low remaining requests
    local rate_limit_response='{
        "rate": {
            "limit": 5000,
            "used": 4950,
            "remaining": 50,
            "reset": '$(date -d '+1 hour' +%s)'
        }
    }'
    
    # Create mock that returns rate limit info for rate_limit endpoint
    cat > "$TEST_TEMP_DIR/bin/gh" << EOF
#!/bin/bash
case "\$1 \$2" in
    "api rate_limit")
        echo '$rate_limit_response'
        exit 0
        ;;
    "api test/endpoint")
        echo '{"test": "data"}'
        exit 0
        ;;
    *)
        exit 1
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/gh"
    
    run github_api_call "test/endpoint"
    assert_success
    assert_output --partial "test"
}

@test "github_api_call: fails when rate limit is exhausted" {
    github_api_init
    
    # Mock rate limit response indicating exhausted requests
    local rate_limit_response='{
        "rate": {
            "limit": 5000,
            "used": 4999,
            "remaining": 1,
            "reset": '$(date -d '+1 hour' +%s)'
        }
    }'
    
    cat > "$TEST_TEMP_DIR/bin/gh" << EOF
#!/bin/bash
case "\$1 \$2" in
    "api rate_limit")
        echo '$rate_limit_response'
        exit 0
        ;;
    *)
        exit 1
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/gh"
    
    run github_api_call "test/endpoint"
    assert_failure
    assert_output --partial "rate limit exceeded"
}

# GitHub run list tests
@test "github_run_list: makes successful run list call" {
    github_api_init
    
    local mock_response='[{"name": "CI", "status": "completed"}]'
    create_gh_mock <(echo "$mock_response") 0
    
    run github_run_list "--limit 10"
    assert_success
    assert_output "$mock_response"
}

@test "github_run_list: caches run list responses" {
    github_api_init
    
    local mock_response='[{"name": "Cached Run", "status": "success"}]'
    create_gh_mock <(echo "$mock_response") 0
    
    # First call
    github_run_list "--limit 5" > /dev/null
    
    # Second call with gh removed from PATH
    export PATH="/usr/bin:/bin"
    
    run github_run_list "--limit 5"
    assert_success
    assert_output "$mock_response"
}

@test "github_run_list: handles run list failure" {
    github_api_init
    
    create_gh_mock "/dev/null" 1
    
    run github_run_list "--limit 10"
    assert_failure
    assert_output --partial "Failed to list GitHub workflow runs"
}

# Rate limit information tests
@test "github_get_rate_limit: returns rate limit information" {
    github_api_init
    
    local rate_limit_response='{
        "rate": {
            "limit": 5000,
            "used": 1000,
            "remaining": 4000,
            "reset": 1640995200
        }
    }'
    
    create_gh_mock <(echo "$rate_limit_response") 0
    
    run github_get_rate_limit
    assert_success
    assert_output "$rate_limit_response"
}

# Metrics collection tests
@test "github_api_get_metrics: returns correct metrics structure" {
    github_api_init
    github_api_reset_metrics
    
    local metrics
    metrics=$(github_api_get_metrics)
    
    # Verify JSON structure
    run jq -e '.api_calls_total' <<< "$metrics"
    assert_success
    
    run jq -e '.cache_hits' <<< "$metrics"
    assert_success
    
    run jq -e '.cache_hit_rate_percent' <<< "$metrics"
    assert_success
    
    run jq -e '.rate_limit_warnings' <<< "$metrics"
    assert_success
}

@test "github_api_get_metrics: calculates cache hit rate correctly" {
    github_api_init
    github_api_reset_metrics
    
    # Create mock for API calls
    create_gh_mock <(echo '{"test": "data"}') 0
    
    # Make API calls (first will miss cache, second will hit)
    github_api_call "test/endpoint1" > /dev/null
    github_api_call "test/endpoint1" > /dev/null  # Cache hit
    github_api_call "test/endpoint2" > /dev/null  # Cache miss
    
    local metrics
    metrics=$(github_api_get_metrics)
    
    local total_calls cache_hits hit_rate
    total_calls=$(echo "$metrics" | jq -r '.api_calls_total')
    cache_hits=$(echo "$metrics" | jq -r '.cache_hits')
    hit_rate=$(echo "$metrics" | jq -r '.cache_hit_rate_percent')
    
    assert_equal "$total_calls" "3"
    assert_equal "$cache_hits" "1"
    assert_equal "$hit_rate" "33"  # 1/3 * 100 = 33%
}

@test "github_api_reset_metrics: resets all counters to zero" {
    github_api_init
    
    # Make some API calls to increment counters
    create_gh_mock <(echo '{"test": "data"}') 0
    github_api_call "test/endpoint" > /dev/null
    
    # Reset metrics
    github_api_reset_metrics
    
    local metrics
    metrics=$(github_api_get_metrics)
    
    local total_calls cache_hits warnings
    total_calls=$(echo "$metrics" | jq -r '.api_calls_total')
    cache_hits=$(echo "$metrics" | jq -r '.cache_hits')
    warnings=$(echo "$metrics" | jq -r '.rate_limit_warnings')
    
    assert_equal "$total_calls" "0"
    assert_equal "$cache_hits" "0"
    assert_equal "$warnings" "0"
}

# Statistics display tests
@test "github_api_show_stats: displays formatted statistics" {
    github_api_init
    github_api_reset_metrics
    
    # Make some API calls
    create_gh_mock <(echo '{"test": "data"}') 0
    github_api_call "stats/endpoint1" > /dev/null
    github_api_call "stats/endpoint1" > /dev/null  # Cache hit
    
    run github_api_show_stats
    assert_success
    assert_output --partial "GitHub API Statistics"
    assert_output --partial "Total API calls: 2"
    assert_output --partial "Cache hits: 1"
    assert_output --partial "Rate limit warnings: 0"
}

# Cleanup tests
@test "github_api_cleanup: cleans up cache directory" {
    github_api_init
    
    # Create some cache files
    echo "test data 1" > "$GITHUB_API_CACHE_DIR/file1"
    echo "test data 2" > "$GITHUB_API_CACHE_DIR/file2"
    
    run github_api_cleanup
    assert_success
    assert_output --partial "GitHub API module cleanup completed"
    
    # Cache directory should be empty
    local file_count
    file_count=$(find "$GITHUB_API_CACHE_DIR" -type f | wc -l)
    assert_equal "$file_count" "0"
}

# Error handling tests
@test "github_api_call: handles network errors gracefully" {
    github_api_init
    
    # Mock network failure (gh command exists but fails)
    cat > "$TEST_TEMP_DIR/bin/gh" << 'EOF'
#!/bin/bash
case "$1 $2" in
    "auth status")
        exit 0  # Auth OK
        ;;
    "api rate_limit")
        echo '{"rate":{"limit":5000,"used":100,"remaining":4900,"reset":1640995200}}'
        exit 0
        ;;
    *)
        echo "Network error: connection timeout" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/gh"
    
    run github_api_call "network/fail"
    assert_failure
    assert_output --partial "Failed to call GitHub API endpoint"
}

@test "github_api_call: handles malformed JSON responses" {
    github_api_init
    
    # Mock malformed JSON response
    create_gh_mock <(echo 'invalid json {') 0
    
    # The function should still return the response (it doesn't validate JSON)
    run github_api_call "malformed/json"
    assert_success
    assert_output "invalid json {"
}

# Rate limiting edge cases
@test "rate_limit_check: handles missing rate limit fields" {
    github_api_init
    
    # Mock incomplete rate limit response
    local incomplete_response='{"rate": {"limit": 5000}}'
    create_gh_mock <(echo "$incomplete_response") 0
    
    # Should handle missing fields gracefully
    run github_api_call "test/endpoint"
    # The function uses jq with '// 0' fallback, so should not fail
    assert_success
}

@test "rate_limit_check: handles rate limit reset in the past" {
    github_api_init
    
    # Mock rate limit with reset time in the past
    local past_reset_time=$(date -d '1 hour ago' +%s)
    local rate_limit_response='{
        "rate": {
            "limit": 5000,
            "used": 4999,
            "remaining": 1,
            "reset": '$past_reset_time'
        }
    }'
    
    cat > "$TEST_TEMP_DIR/bin/gh" << EOF
#!/bin/bash
case "\$1 \$2" in
    "api rate_limit")
        echo '$rate_limit_response'
        exit 0
        ;;
    *)
        exit 1
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/gh"
    
    # Should not wait for a reset time in the past
    run github_api_call "test/endpoint"
    assert_failure
}

# Integration tests
@test "github_api_integration: full API workflow" {
    github_api_init
    github_api_reset_metrics
    
    # Mock API responses
    local response1='{"endpoint": "one", "data": "first"}'
    local response2='{"endpoint": "two", "data": "second"}'
    
    cat > "$TEST_TEMP_DIR/bin/gh" << EOF
#!/bin/bash
case "\$*" in
    "auth status")
        exit 0
        ;;
    "api rate_limit")
        echo '{"rate":{"limit":5000,"used":100,"remaining":4900,"reset":1640995200}}'
        exit 0
        ;;
    "api endpoint/one")
        echo '$response1'
        exit 0
        ;;
    "api endpoint/two")
        echo '$response2'
        exit 0
        ;;
    "run list --limit 10")
        echo '[{"name": "test-run", "status": "completed"}]'
        exit 0
        ;;
    *)
        exit 1
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/gh"
    
    # 1. Make API calls
    local result1 result2
    result1=$(github_api_call "endpoint/one")
    result2=$(github_api_call "endpoint/two")
    
    assert_equal "$result1" "$response1"
    assert_equal "$result2" "$response2"
    
    # 2. Make run list call
    local run_result
    run_result=$(github_run_list "--limit 10")
    assert [ -n "$run_result" ]
    
    # 3. Get rate limit info
    local rate_limit
    rate_limit=$(github_get_rate_limit)
    assert [ -n "$rate_limit" ]
    
    # 4. Check metrics
    local metrics
    metrics=$(github_api_get_metrics)
    local total_calls
    total_calls=$(echo "$metrics" | jq -r '.api_calls_total')
    assert [ "$total_calls" -ge 3 ]  # At least 3 calls made
    
    # 5. Show stats
    run github_api_show_stats
    assert_success
    assert_output --partial "GitHub API Statistics"
    
    # 6. Cleanup
    run github_api_cleanup
    assert_success
}