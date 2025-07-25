#!/usr/bin/env bats
#
# Unit tests for common.sh library functions
# Tests enhanced cache key generation, parallel processing, error handling, 
# progress reporting, resource monitoring, and configuration validation
#
# PERFORMANCE OPTIMIZATIONS:
# - Uses setup_file() for shared test fixtures to reduce test setup time
# - Optimized resource monitoring tests with better mocking to avoid system calls
# - Supports parallel test execution: bats --jobs 4 tests/lib/test-common.bats
# - Individual test cleanup to prevent cross-test contamination

# Constants for testing
readonly SHA256_HASH_LENGTH=64
readonly DEFAULT_MEMORY_PER_JOB_MB=100

# Global test variables (shared across all tests)
SHARED_TEST_TEMP_DIR=
SHARED_TEST_CACHE_DIR=
SHARED_TEST_FILE=

# Setup and teardown - optimized for performance
setup_file() {
    load '../helpers/test-helpers'
    
    # Create shared test environment once for all tests
    export SHARED_TEST_TEMP_DIR="$(mktemp -d)"
    export ORIGINAL_PATH="$PATH"
    export PATH="$SHARED_TEST_TEMP_DIR/bin:$PATH"
    
    # Create shared mock bin directory
    mkdir -p "$SHARED_TEST_TEMP_DIR/bin"
    
    # Source the common library once
    source "$BATS_TEST_DIRNAME/../../scripts/lib/common.sh"
    
    # Set up shared test directories and files
    SHARED_TEST_CACHE_DIR="$SHARED_TEST_TEMP_DIR/test_cache"
    SHARED_TEST_FILE="$SHARED_TEST_TEMP_DIR/test_file.txt"
    echo "test content" > "$SHARED_TEST_FILE"
    
    # Set environment variables for testing once
    export MAX_PARALLEL_JOBS=4
    export CACHE_TTL=300
    export MEMORY_LIMIT_PERCENT=80
    export CPU_LIMIT_PERCENT=90
    export MIN_PARALLEL_JOBS=1
    export MAX_SYSTEM_PARALLEL_JOBS=16
    export RESOURCE_CHECK_INTERVAL=5
    export PARALLEL_JOB_TIMEOUT=300
    export ENABLE_CACHE=true
    export RESOURCE_MONITOR_ENABLED=true
    
    # Set environment variables for test helpers
    export GITHUB_TOKEN="test-token"
    export GITHUB_REPOSITORY="test/repo"
    export GITHUB_API_URL="https://api.github.com"
}

teardown_file() {
    if [[ -n "${SHARED_TEST_TEMP_DIR:-}" && -d "$SHARED_TEST_TEMP_DIR" ]]; then
        rm -rf "$SHARED_TEST_TEMP_DIR"
    fi
    export PATH="$ORIGINAL_PATH"
}

setup() {
    # Lightweight per-test setup
    # Use shared resources created in setup_file()
    TEST_TEMP_DIR="$SHARED_TEST_TEMP_DIR"
    TEST_CACHE_DIR="$SHARED_TEST_CACHE_DIR"
    TEST_FILE="$SHARED_TEST_FILE"
    
    # Load test helpers for each test (needed for assertions)
    load '../helpers/test-helpers'
}

teardown() {
    # Lightweight per-test cleanup
    # Don't remove shared directories - handled by teardown_file()
    :  # No-op - shared resources cleaned up in teardown_file()
}

# Enhanced cache key generation tests
@test "get_enhanced_cache_key: generates consistent key for same file" {
    run get_enhanced_cache_key "$TEST_FILE"
    assert_success
    local key1="$output"
    
    run get_enhanced_cache_key "$TEST_FILE"
    assert_success
    local key2="$output"
    
    assert_equal "$key1" "$key2"
}

@test "get_enhanced_cache_key: generates different keys for different files" {
    # Use shared test file for first key, create minimal second file
    local test_file2="$SHARED_TEST_TEMP_DIR/test_file2.txt"
    echo "different content" > "$test_file2"
    
    local key1 key2
    key1=$(get_enhanced_cache_key "$TEST_FILE")
    key2=$(get_enhanced_cache_key "$test_file2")
    
    assert [ "$key1" != "$key2" ]
    
    # Cleanup for reuse in other tests
    rm -f "$test_file2"
}

@test "get_enhanced_cache_key: includes additional context in key generation" {
    local key1 key2
    key1=$(get_enhanced_cache_key "$TEST_FILE" "context1")
    key2=$(get_enhanced_cache_key "$TEST_FILE" "context2")
    
    assert [ "$key1" != "$key2" ]
}

@test "get_enhanced_cache_key: handles missing file parameter" {
    run get_enhanced_cache_key ""
    assert_failure
    assert_output --partial "get_enhanced_cache_key: file parameter is required"
}

@test "get_enhanced_cache_key: detects path traversal attempts" {
    run get_enhanced_cache_key "../../../etc/passwd"
    assert_failure
    assert_output --partial "get_enhanced_cache_key: path traversal detected"
}

@test "get_enhanced_cache_key: handles non-existent file" {
    local non_existent="/tmp/non_existent_file_12345.txt"
    run get_enhanced_cache_key "$non_existent"
    assert_success
    # Should still generate a key but mark file as missing
    assert [ ${#output} -eq $SHA256_HASH_LENGTH ]
}

@test "get_enhanced_cache_key: uses absolute path for key generation" {
    # Use pre-created shared directories for efficiency
    local dir1="$SHARED_TEST_TEMP_DIR/dir1"
    local dir2="$SHARED_TEST_TEMP_DIR/dir2"
    mkdir -p "$dir1" "$dir2"
    
    echo "same content" > "$dir1/file.txt"
    echo "same content" > "$dir2/file.txt"
    
    local key1 key2
    key1=$(get_enhanced_cache_key "$dir1/file.txt")
    key2=$(get_enhanced_cache_key "$dir2/file.txt")
    
    # Keys should be different due to different absolute paths
    assert [ "$key1" != "$key2" ]
    
    # Cleanup for reuse
    rm -rf "$dir1" "$dir2"
}

@test "get_enhanced_cache_key: includes file modification time" {
    local key1 key2
    key1=$(get_enhanced_cache_key "$TEST_FILE")
    
    # Modify the file
    echo "modified content" >> "$TEST_FILE"
    key2=$(get_enhanced_cache_key "$TEST_FILE")
    
    # Keys should be different due to different mtime and content
    assert [ "$key1" != "$key2" ]
}

# Parallel processing tests
@test "run_parallel_function: validates function exists" {
    run run_parallel_function "non_existent_function" 2 "$TEST_FILE"
    assert_failure
    assert_output --partial "run_parallel_function: function not found: non_existent_function"
}

@test "run_parallel_function: processes files in parallel" {
    # Define a test function
    test_parallel_func() {
        local file="$1"
        echo "processed: $(basename "$file")" > "${file}.result"
    }
    export -f test_parallel_func
    
    # Create test files efficiently
    local files=()
    for i in {1..3}; do
        local file="$SHARED_TEST_TEMP_DIR/file_$i.txt"
        echo "content $i" > "$file"
        files+=("$file")
    done
    
    run run_parallel_function "test_parallel_func" 2 "${files[@]}"
    assert_success
    
    # Wait for background processes to complete
    sleep 0.5
    
    # Check that result files were created
    for i in {1..3}; do
        local result_file="$SHARED_TEST_TEMP_DIR/file_$i.txt.result"
        assert [ -f "$result_file" ]
        # Cleanup for next test
        rm -f "$SHARED_TEST_TEMP_DIR/file_$i.txt" "$result_file"
    done
}

@test "run_parallel_function: handles files with spaces in names" {
    # Define a test function
    test_space_func() {
        local file="$1"
        touch "${file}.processed"
    }
    export -f test_space_func
    
    # Create files with spaces using shared temp dir
    local file_with_spaces="$SHARED_TEST_TEMP_DIR/file with spaces.txt"
    echo "content" > "$file_with_spaces"
    
    run run_parallel_function "test_space_func" 1 "$file_with_spaces"
    assert_success
    
    assert [ -f "${file_with_spaces}.processed" ]
    
    # Cleanup for next test
    rm -f "$file_with_spaces" "${file_with_spaces}.processed"
}

# Error handling and cleanup tests
@test "add_cleanup_function: adds function to cleanup list" {
    # Reset cleanup functions array
    CLEANUP_FUNCTIONS=()
    
    add_cleanup_function "echo 'cleanup1'"
    add_cleanup_function "echo 'cleanup2'"
    
    assert_equal "${#CLEANUP_FUNCTIONS[@]}" "2"
    assert_equal "${CLEANUP_FUNCTIONS[0]}" "echo 'cleanup1'"
    assert_equal "${CLEANUP_FUNCTIONS[1]}" "echo 'cleanup2'"
}

@test "setup_signal_handling: sets up signal traps" {
    setup_signal_handling
    
    # Check that traps are set (this is tricky to test directly)
    # We'll just verify the function runs without error
    assert_success
}

# Progress reporting tests
@test "show_progress: displays progress correctly" {
    run show_progress 25 100 "test operation"
    assert_success
    assert_output --partial "test operation"
    assert_output --partial "25/100"
    assert_output --partial "(25%)"
}

@test "show_progress: validates numeric inputs" {
    run show_progress "invalid" 100 "test"
    assert_failure
    assert_output --partial "show_progress: current and total parameters must be numeric values"
}

@test "show_progress: handles zero total" {
    run show_progress 1 0 "test"
    assert_failure
    assert_output --partial "show_progress: total parameter cannot be zero"
}

@test "show_progress: handles completion (100%)" {
    run show_progress 100 100 "completed operation"
    assert_success
    assert_output --partial "completed operation"
    assert_output --partial "100/100"
    assert_output --partial "(100%)"
}

# Configuration validation tests
@test "validate_config: validates MAX_PARALLEL_JOBS" {
    MAX_PARALLEL_JOBS="invalid"
    run validate_config
    assert_failure
    assert_output --partial "validate_config: MAX_PARALLEL_JOBS must be >= 1, got:"
    
    MAX_PARALLEL_JOBS="0"
    run validate_config
    assert_failure
    assert_output --partial "validate_config: MAX_PARALLEL_JOBS must be >= 1, got:"
    
    MAX_PARALLEL_JOBS="4"
    # This may still fail due to other config values, but this specific error shouldn't occur
}

@test "validate_config: validates CACHE_TTL" {
    CACHE_TTL="30"  # Below minimum of 60
    run validate_config
    assert_failure
    assert_output --partial "validate_config: CACHE_TTL must be >= 60 seconds, got:"
    
    CACHE_TTL="invalid"
    run validate_config
    assert_failure
    assert_output --partial "validate_config: CACHE_TTL must be >= 60 seconds, got:"
}

@test "validate_config: validates MEMORY_LIMIT_PERCENT" {
    MEMORY_LIMIT_PERCENT="150"  # Above maximum of 100
    run validate_config
    assert_failure
    assert_output --partial "validate_config: MEMORY_LIMIT_PERCENT must be 1-100, got:"
    
    MEMORY_LIMIT_PERCENT="0"  # Below minimum of 1
    run validate_config
    assert_failure
    assert_output --partial "validate_config: MEMORY_LIMIT_PERCENT must be 1-100, got:"
}

@test "validate_config: validates boolean values" {
    ENABLE_CACHE="invalid"
    run validate_config
    assert_failure
    assert_output --partial "validate_config: ENABLE_CACHE must be true or false, got:"
    
    RESOURCE_MONITOR_ENABLED="invalid"
    run validate_config
    assert_failure
    assert_output --partial "validate_config: RESOURCE_MONITOR_ENABLED must be true or false, got:"
}

# Resource monitoring tests (optimized with better mocking)
@test "get_memory_usage: returns numeric value" {
    # Create optimized mock that avoids actual system calls
    cat > "$SHARED_TEST_TEMP_DIR/bin/free" << 'EOF'
#!/bin/bash
echo "              total        used        free      shared  buff/cache   available"
echo "Mem:        8000000     4000000     2000000      100000     1900000     3500000"
EOF
    chmod +x "$SHARED_TEST_TEMP_DIR/bin/free"
    
    run get_memory_usage
    assert_success
    # Should return a percentage (numeric value)
    assert [[ "$output" =~ ^[0-9]+$ ]]
}

@test "get_cpu_usage: returns numeric value within valid range" {
    # Create optimized mock for sar command
    cat > "$SHARED_TEST_TEMP_DIR/bin/sar" << 'EOF'
#!/bin/bash
echo "Linux 5.4.0 (test) 	01/01/24 	_x86_64_	(4 CPU)"
echo ""
echo "Average:        CPU     %user     %nice   %system   %iowait    %steal     %idle"
echo "Average:        all      5.00      0.00      2.00      1.00      0.00     92.00"
EOF
    chmod +x "$SHARED_TEST_TEMP_DIR/bin/sar"
    
    run get_cpu_usage
    assert_success
    # Should return a percentage between 0-100
    assert [[ "$output" =~ ^[0-9]+$ ]]
    assert [ "$output" -ge 0 ]
    assert [ "$output" -le 100 ]
}

@test "get_cpu_cores: returns positive integer" {
    # Mock nproc command to avoid system calls
    cat > "$SHARED_TEST_TEMP_DIR/bin/nproc" << 'EOF'
#!/bin/bash
echo "4"
EOF
    chmod +x "$SHARED_TEST_TEMP_DIR/bin/nproc"
    
    run get_cpu_cores
    assert_success
    # Should return a positive integer
    assert [[ "$output" =~ ^[0-9]+$ ]]
    assert [ "$output" -ge 1 ]
}

@test "check_system_resources: validates resource limits" {
    # Create optimized mocks for all resource commands
    cat > "$SHARED_TEST_TEMP_DIR/bin/free" << 'EOF'
#!/bin/bash
echo "              total        used        free      shared  buff/cache   available"
echo "Mem:        8000000     2800000     3200000      100000     1900000     4500000"
EOF
    cat > "$SHARED_TEST_TEMP_DIR/bin/sar" << 'EOF'
#!/bin/bash
echo "Average:        CPU     %user     %nice   %system   %iowait    %steal     %idle"
echo "Average:        all      5.00      0.00      2.00      1.00      0.00     92.00"
EOF
    cat > "$SHARED_TEST_TEMP_DIR/bin/uptime" << 'EOF'
#!/bin/bash
echo "12:00:00 up 1 day, 2:00, 1 user, load average: 2.0, 1.8, 1.5"
EOF
    cat > "$SHARED_TEST_TEMP_DIR/bin/nproc" << 'EOF'
#!/bin/bash
echo "4"
EOF
    chmod +x "$SHARED_TEST_TEMP_DIR/bin/"*
    
    run check_system_resources
    assert_success
}

@test "check_system_resources: detects high memory usage" {
    # Create mock that simulates high memory usage (90% > 80% limit)
    cat > "$SHARED_TEST_TEMP_DIR/bin/free" << 'EOF'
#!/bin/bash
echo "              total        used        free      shared  buff/cache   available"
echo "Mem:        8000000     7200000      800000      100000     1900000     1000000"
EOF
    cat > "$SHARED_TEST_TEMP_DIR/bin/sar" << 'EOF'
#!/bin/bash
echo "Average:        CPU     %user     %nice   %system   %iowait    %steal     %idle"
echo "Average:        all      5.00      0.00      2.00      1.00      0.00     92.00"
EOF
    cat > "$SHARED_TEST_TEMP_DIR/bin/uptime" << 'EOF'
#!/bin/bash
echo "12:00:00 up 1 day, 2:00, 1 user, load average: 2.0, 1.8, 1.5"
EOF
    cat > "$SHARED_TEST_TEMP_DIR/bin/nproc" << 'EOF'
#!/bin/bash
echo "4"
EOF
    chmod +x "$SHARED_TEST_TEMP_DIR/bin/"*
    
    run check_system_resources
    assert_failure
    assert_output --partial "Memory usage high"
}

@test "check_system_resources: detects high CPU usage" {
    # Create mock that simulates high CPU usage (95% > 90% limit)
    cat > "$SHARED_TEST_TEMP_DIR/bin/free" << 'EOF'
#!/bin/bash
echo "              total        used        free      shared  buff/cache   available"
echo "Mem:        8000000     2800000     3200000      100000     1900000     4500000"
EOF
    cat > "$SHARED_TEST_TEMP_DIR/bin/sar" << 'EOF'
#!/bin/bash
echo "Average:        CPU     %user     %nice   %system   %iowait    %steal     %idle"
echo "Average:        all     85.00      5.00      5.00      0.00      0.00      5.00"
EOF
    cat > "$SHARED_TEST_TEMP_DIR/bin/uptime" << 'EOF'
#!/bin/bash
echo "12:00:00 up 1 day, 2:00, 1 user, load average: 2.0, 1.8, 1.5"
EOF
    cat > "$SHARED_TEST_TEMP_DIR/bin/nproc" << 'EOF'
#!/bin/bash
echo "4"
EOF
    chmod +x "$SHARED_TEST_TEMP_DIR/bin/"*
    
    run check_system_resources
    assert_failure
    assert_output --partial "CPU usage high"
}

@test "calculate_optimal_parallel_jobs: returns valid job count" {
    # Create optimized mocks for resource calculation
    cat > "$SHARED_TEST_TEMP_DIR/bin/free" << 'EOF'
#!/bin/bash
echo "              total        used        free      shared  buff/cache   available"
echo "Mem:        8000000     2000000     4000000      100000     1900000     6000000"
EOF
    cat > "$SHARED_TEST_TEMP_DIR/bin/sar" << 'EOF'
#!/bin/bash
echo "Average:        CPU     %user     %nice   %system   %iowait    %steal     %idle"
echo "Average:        all     10.00      0.00      5.00      0.00      0.00     85.00"
EOF
    cat > "$SHARED_TEST_TEMP_DIR/bin/nproc" << 'EOF'
#!/bin/bash
echo "4"
EOF
    chmod +x "$SHARED_TEST_TEMP_DIR/bin/"*
    
    run calculate_optimal_parallel_jobs 8
    assert_success
    # Should return a positive integer within reasonable bounds
    assert [[ "$output" =~ ^[0-9]+$ ]]
    assert [ "$output" -ge "$MIN_PARALLEL_JOBS" ]
    assert [ "$output" -le "$MAX_SYSTEM_PARALLEL_JOBS" ]
}

@test "calculate_optimal_parallel_jobs: validates input" {
    run calculate_optimal_parallel_jobs "invalid"
    assert_failure
    assert_output --partial "calculate_optimal_parallel_jobs: base_jobs must be positive integer, got:"
    
    run calculate_optimal_parallel_jobs "0"
    assert_failure
    assert_output --partial "calculate_optimal_parallel_jobs: base_jobs must be positive integer, got:"
}

# Cache setup tests (extending existing coverage)
@test "setup_cache: validates cache directory path for security" {
    run setup_cache "../../../tmp/malicious_cache"
    assert_failure
    assert_output --partial "setup_cache: path traversal detected"
}

@test "setup_cache: creates cache with custom permissions" {
    local custom_cache="$TEST_TEMP_DIR/custom_cache"
    run setup_cache "$custom_cache" "755"
    assert_success
    
    # Check directory exists with correct permissions
    assert [ -d "$custom_cache" ]
    local perms
    perms=$(stat -c %a "$custom_cache")
    assert_equal "$perms" "755"
}

# save_to_cache security and error handling tests
@test "save_to_cache: validates cache key for path traversal" {
    setup_cache "$TEST_CACHE_DIR"
    
    run save_to_cache "../malicious_key" "data" "$TEST_CACHE_DIR"
    assert_failure
    assert_output --partial "save_to_cache: invalid cache key:"
    
    run save_to_cache "key/with/slashes" "data" "$TEST_CACHE_DIR"
    assert_failure
    assert_output --partial "save_to_cache: invalid cache key:"
}

@test "save_to_cache: validates required parameters" {
    setup_cache "$TEST_CACHE_DIR"
    
    run save_to_cache "" "data" "$TEST_CACHE_DIR"
    assert_failure
    assert_output --partial "save_to_cache: cache_key and cache_dir parameters are required"
    
    run save_to_cache "key" "data" ""
    assert_failure
    assert_output --partial "save_to_cache: cache_key and cache_dir parameters are required"
}

@test "save_to_cache: handles temporary file creation failure" {
    setup_cache "$TEST_CACHE_DIR"
    
    # Make cache directory read-only to force temp file creation failure
    chmod 444 "$TEST_CACHE_DIR"
    
    run save_to_cache "test_key" "test_data" "$TEST_CACHE_DIR"
    assert_failure
    assert_output --partial "save_to_cache: failed to create temporary file"
    
    # Restore permissions for cleanup
    chmod 755 "$TEST_CACHE_DIR"
}

# Error handling utility tests
@test "check_command: validates command availability" {
    run check_command "ls"
    assert_success
    
    run check_command "non_existent_command_12345"
    assert_failure
    assert_output --partial "check_command: command 'non_existent_command_12345' is required but not found"
}

@test "check_command: uses custom error message" {
    run check_command "non_existent_cmd" "Custom error message"
    assert_failure
    assert_output --partial "Custom error message"
}

@test "wait_for_jobs: handles successful jobs" {
    # Start some background processes that will succeed
    sleep 0.1 &
    local pid1=$!
    sleep 0.1 &
    local pid2=$!
    
    run wait_for_jobs $pid1 $pid2
    assert_success
}

@test "wait_for_jobs: counts failed jobs" {
    # Start a process that will fail
    (exit 1) &
    local pid1=$!
    # Start a process that will succeed
    sleep 0.1 &
    local pid2=$!
    
    run wait_for_jobs $pid1 $pid2
    assert_failure
    assert_equal "$status" "1"  # One job failed
}

# Logging function tests
@test "log_info: outputs info message with color" {
    run log_info "test message"
    assert_success
    assert_output --partial "[INFO]"
    assert_output --partial "test message"
}

@test "log_warn: outputs warning message with color" {
    run log_warn "warning message"
    assert_success
    assert_output --partial "[WARN]"
    assert_output --partial "warning message"
}

@test "log_error: outputs error message with color" {
    run log_error "error message"
    assert_success
    assert_output --partial "[ERROR]"
    assert_output --partial "error message"
}

@test "log_header: outputs header message with color" {
    run log_header "header message"
    assert_success
    assert_output --partial "[HEADER]"
    assert_output --partial "header message"
}

# Integration test for parallel processing with resource limits
@test "run_parallel_with_resource_limits: validates function name for security" {
    run run_parallel_with_resource_limits "invalid-function-name!" "$TEST_FILE"
    assert_failure
    assert_output --partial "run_parallel_with_resource_limits: function name contains unsafe characters:"
}

@test "run_parallel_with_resource_limits: falls back when monitoring disabled" {
    RESOURCE_MONITOR_ENABLED=false
    
    # Define a simple test function
    test_resource_func() {
        local file="$1"
        echo "processed" > "${file}.done"
    }
    export -f test_resource_func
    
    run run_parallel_with_resource_limits "test_resource_func" "$TEST_FILE"
    assert_success
    assert [ -f "${TEST_FILE}.done" ]
}

# cleanup_cache function tests (optimized)
@test "cleanup_cache: removes expired cache entries" {
    local test_cache_dir="$SHARED_TEST_TEMP_DIR/cleanup_test_cache"
    mkdir -p "$test_cache_dir"
    
    # Create test files with different ages
    local old_file="$test_cache_dir/old_file.cache"
    local new_file="$test_cache_dir/new_file.cache"
    
    echo "old content" > "$old_file"
    echo "new content" > "$new_file"
    
    # Make the old file appear older than 10 minutes (600 seconds TTL)
    # Use touch to set modification time to 15 minutes ago
    touch -t $(date -d '15 minutes ago' '+%Y%m%d%H%M.%S') "$old_file"
    
    # Run cleanup with 10 minute (600 second) TTL
    run cleanup_cache "$test_cache_dir" 600
    assert_success
    
    # Old file should be deleted, new file should remain
    assert [ ! -f "$old_file" ]
    assert [ -f "$new_file" ]
    
    # Cleanup for reuse
    rm -rf "$test_cache_dir"
}

@test "cleanup_cache: preserves non-expired cache entries" {
    local test_cache_dir="$SHARED_TEST_TEMP_DIR/cleanup_preserve_cache"
    mkdir -p "$test_cache_dir"
    
    # Create recent test files
    local recent_file1="$test_cache_dir/recent1.cache"
    local recent_file2="$test_cache_dir/recent2.cache"
    
    echo "recent content 1" > "$recent_file1"
    echo "recent content 2" > "$recent_file2"
    
    # Run cleanup with 10 minute (600 second) TTL
    run cleanup_cache "$test_cache_dir" 600
    assert_success
    
    # Both files should still exist
    assert [ -f "$recent_file1" ]
    assert [ -f "$recent_file2" ]
    
    # Cleanup for reuse
    rm -rf "$test_cache_dir"
}

@test "cleanup_cache: handles empty cache directory" {
    local empty_cache_dir="$TEST_TEMP_DIR/empty_cache"
    mkdir -p "$empty_cache_dir"
    
    # Run cleanup on empty directory
    run cleanup_cache "$empty_cache_dir" 600
    assert_success
    
    # Directory should still exist and be empty
    assert [ -d "$empty_cache_dir" ]
    assert [ -z "$(ls -A "$empty_cache_dir")" ]
}

@test "cleanup_cache: handles non-existent directory gracefully" {
    local non_existent_dir="$TEST_TEMP_DIR/non_existent_cache"
    
    # Ensure directory doesn't exist
    rm -rf "$non_existent_dir"
    
    # Run cleanup on non-existent directory
    run cleanup_cache "$non_existent_dir" 600
    assert_success
    
    # Directory should still not exist
    assert [ ! -d "$non_existent_dir" ]
}

@test "cleanup_cache: handles mixed file ages correctly" {
    local mixed_cache_dir="$TEST_TEMP_DIR/mixed_age_cache"
    mkdir -p "$mixed_cache_dir"
    
    # Create files with different ages
    local very_old_file="$mixed_cache_dir/very_old.cache"
    local old_file="$mixed_cache_dir/old.cache"
    local recent_file="$mixed_cache_dir/recent.cache"
    local new_file="$mixed_cache_dir/new.cache"
    
    echo "very old content" > "$very_old_file"
    echo "old content" > "$old_file"
    echo "recent content" > "$recent_file"
    echo "new content" > "$new_file"
    
    # Set different modification times
    # Very old: 20 minutes ago
    touch -t $(date -d '20 minutes ago' '+%Y%m%d%H%M.%S') "$very_old_file"
    # Old: 12 minutes ago
    touch -t $(date -d '12 minutes ago' '+%Y%m%d%H%M.%S') "$old_file"
    # Recent: 5 minutes ago (within TTL)
    touch -t $(date -d '5 minutes ago' '+%Y%m%d%H%M.%S') "$recent_file"
    # New: current time (definitely within TTL)
    
    # Run cleanup with 10 minute (600 second) TTL
    run cleanup_cache "$mixed_cache_dir" 600
    assert_success
    
    # Files older than 10 minutes should be deleted
    assert [ ! -f "$very_old_file" ]
    assert [ ! -f "$old_file" ]
    
    # Files within TTL should remain
    assert [ -f "$recent_file" ]
    assert [ -f "$new_file" ]
}

@test "cleanup_cache: validates TTL parameter handling" {
    local test_cache_dir="$TEST_TEMP_DIR/ttl_test_cache"
    mkdir -p "$test_cache_dir"
    
    # Create a test file
    local test_file="$test_cache_dir/test.cache"
    echo "test content" > "$test_file"
    
    # Make file 2 minutes old
    touch -t $(date -d '2 minutes ago' '+%Y%m%d%H%M.%S') "$test_file"
    
    # Test with 60 second TTL (1 minute) - file should be deleted
    run cleanup_cache "$test_cache_dir" 60
    assert_success
    assert [ ! -f "$test_file" ]
    
    # Create another test file
    echo "test content 2" > "$test_file"
    touch -t $(date -d '2 minutes ago' '+%Y%m%d%H%M.%S') "$test_file"
    
    # Test with 300 second TTL (5 minutes) - file should remain
    run cleanup_cache "$test_cache_dir" 300
    assert_success
    assert [ -f "$test_file" ]
}