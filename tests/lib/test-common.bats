#!/usr/bin/env bats
#
# Unit tests for common.sh library functions
# Tests enhanced cache key generation, parallel processing, error handling, 
# progress reporting, resource monitoring, and configuration validation

# Constants for testing
readonly SHA256_HASH_LENGTH=64
readonly DEFAULT_MEMORY_PER_JOB_MB=100

# Setup and teardown
setup() {
    load '../helpers/test-helpers'
    setup_test_environment
    
    # Source the common library
    source "$BATS_TEST_DIRNAME/../../scripts/lib/common.sh"
    
    # Set up test directories and files
    TEST_CACHE_DIR="$TEST_TEMP_DIR/test_cache"
    TEST_FILE="$TEST_TEMP_DIR/test_file.txt"
    echo "test content" > "$TEST_FILE"
    
    # Mock configuration values for testing
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
}

teardown() {
    teardown_test_environment
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
    local test_file2="$TEST_TEMP_DIR/test_file2.txt"
    echo "different content" > "$test_file2"
    
    local key1 key2
    key1=$(get_enhanced_cache_key "$TEST_FILE")
    key2=$(get_enhanced_cache_key "$test_file2")
    
    assert [ "$key1" != "$key2" ]
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
    assert_output --partial "file parameter is required"
}

@test "get_enhanced_cache_key: detects path traversal attempts" {
    run get_enhanced_cache_key "../../../etc/passwd"
    assert_failure
    assert_output --partial "path traversal detected"
}

@test "get_enhanced_cache_key: handles non-existent file" {
    local non_existent="/tmp/non_existent_file_12345.txt"
    run get_enhanced_cache_key "$non_existent"
    assert_success
    # Should still generate a key but mark file as missing
    assert [ ${#output} -eq $SHA256_HASH_LENGTH ]
}

@test "get_enhanced_cache_key: uses absolute path for key generation" {
    # Create the same filename in different directories
    local dir1="$TEST_TEMP_DIR/dir1"
    local dir2="$TEST_TEMP_DIR/dir2"
    mkdir -p "$dir1" "$dir2"
    
    echo "same content" > "$dir1/file.txt"
    echo "same content" > "$dir2/file.txt"
    
    local key1 key2
    key1=$(get_enhanced_cache_key "$dir1/file.txt")
    key2=$(get_enhanced_cache_key "$dir2/file.txt")
    
    # Keys should be different due to different absolute paths
    assert [ "$key1" != "$key2" ]
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
    assert_output --partial "Function non_existent_function not found"
}

@test "run_parallel_function: processes files in parallel" {
    # Define a test function
    test_parallel_func() {
        local file="$1"
        echo "processed: $(basename "$file")" > "${file}.result"
    }
    export -f test_parallel_func
    
    # Create test files
    local files=()
    local pids=()
    for i in {1..3}; do
        local file="$TEST_TEMP_DIR/file_$i.txt"
        echo "content $i" > "$file"
        files+=("$file")
    done
    
    run run_parallel_function "test_parallel_func" 2 "${files[@]}"
    assert_success
    
    # Wait for background processes to complete
    sleep 0.5
    
    # Check that result files were created
    for i in {1..3}; do
        local result_file="$TEST_TEMP_DIR/file_$i.txt.result"
        assert [ -f "$result_file" ]
    done
}

@test "run_parallel_function: handles files with spaces in names" {
    # Define a test function
    test_space_func() {
        local file="$1"
        touch "${file}.processed"
    }
    export -f test_space_func
    
    # Create files with spaces
    local file_with_spaces="$TEST_TEMP_DIR/file with spaces.txt"
    echo "content" > "$file_with_spaces"
    
    run run_parallel_function "test_space_func" 1 "$file_with_spaces"
    assert_success
    
    assert [ -f "${file_with_spaces}.processed" ]
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
    assert_output --partial "current and total must be numeric"
}

@test "show_progress: handles zero total" {
    run show_progress 1 0 "test"
    assert_failure
    assert_output --partial "total cannot be zero"
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
    assert_output --partial "Invalid MAX_PARALLEL_JOBS value"
    
    MAX_PARALLEL_JOBS="0"
    run validate_config
    assert_failure
    assert_output --partial "Invalid MAX_PARALLEL_JOBS value"
    
    MAX_PARALLEL_JOBS="4"
    # This may still fail due to other config values, but this specific error shouldn't occur
}

@test "validate_config: validates CACHE_TTL" {
    CACHE_TTL="30"  # Below minimum of 60
    run validate_config
    assert_failure
    assert_output --partial "Invalid CACHE_TTL value"
    
    CACHE_TTL="invalid"
    run validate_config
    assert_failure
    assert_output --partial "Invalid CACHE_TTL value"
}

@test "validate_config: validates MEMORY_LIMIT_PERCENT" {
    MEMORY_LIMIT_PERCENT="150"  # Above maximum of 100
    run validate_config
    assert_failure
    assert_output --partial "Invalid MEMORY_LIMIT_PERCENT value"
    
    MEMORY_LIMIT_PERCENT="0"  # Below minimum of 1
    run validate_config
    assert_failure
    assert_output --partial "Invalid MEMORY_LIMIT_PERCENT value"
}

@test "validate_config: validates boolean values" {
    ENABLE_CACHE="invalid"
    run validate_config
    assert_failure
    assert_output --partial "Invalid ENABLE_CACHE value"
    
    RESOURCE_MONITOR_ENABLED="invalid"
    run validate_config
    assert_failure
    assert_output --partial "Invalid RESOURCE_MONITOR_ENABLED value"
}

# Resource monitoring tests (basic functionality)
@test "get_memory_usage: returns numeric value" {
    # Mock free command
    create_command_mock "free" 'echo "              total        used        free      shared  buff/cache   available"
echo "Mem:        8000000     4000000     2000000      100000     1900000     3500000"'
    
    run get_memory_usage
    assert_success
    # Should return a percentage (numeric value)
    assert [[ "$output" =~ ^[0-9]+$ ]]
}

@test "get_cpu_usage: returns numeric value within valid range" {
    # Mock sar command
    create_command_mock "sar" 'echo "Linux 5.4.0 (test) 	01/01/24 	_x86_64_	(4 CPU)"
echo ""
echo "Average:        CPU     %user     %nice   %system   %iowait    %steal     %idle"
echo "Average:        all      5.00      0.00      2.00      1.00      0.00     92.00"'
    
    run get_cpu_usage
    assert_success
    # Should return a percentage between 0-100
    assert [[ "$output" =~ ^[0-9]+$ ]]
    assert [ "$output" -ge 0 ]
    assert [ "$output" -le 100 ]
}

@test "get_cpu_cores: returns positive integer" {
    run get_cpu_cores
    assert_success
    # Should return a positive integer
    assert [[ "$output" =~ ^[0-9]+$ ]]
    assert [ "$output" -ge 1 ]
}

@test "check_system_resources: validates resource limits" {
    # Mock resource functions to return safe values
    get_memory_usage() { echo "70"; }
    get_cpu_usage() { echo "60"; }
    get_load_average() { echo "2.0"; }
    get_cpu_cores() { echo "4"; }
    export -f get_memory_usage get_cpu_usage get_load_average get_cpu_cores
    
    run check_system_resources
    assert_success
}

@test "check_system_resources: detects high memory usage" {
    # Mock high memory usage
    get_memory_usage() { echo "90"; }  # Above 80% limit
    get_cpu_usage() { echo "60"; }
    get_load_average() { echo "2.0"; }
    get_cpu_cores() { echo "4"; }
    export -f get_memory_usage get_cpu_usage get_load_average get_cpu_cores
    
    run check_system_resources
    assert_failure
    assert_output --partial "Memory usage high"
}

@test "check_system_resources: detects high CPU usage" {
    # Mock high CPU usage
    get_memory_usage() { echo "70"; }
    get_cpu_usage() { echo "95"; }  # Above 90% limit
    get_load_average() { echo "2.0"; }
    get_cpu_cores() { echo "4"; }
    export -f get_memory_usage get_cpu_usage get_load_average get_cpu_cores
    
    run check_system_resources
    assert_failure
    assert_output --partial "CPU usage high"
}

@test "calculate_optimal_parallel_jobs: returns valid job count" {
    # Mock resource functions
    get_memory_usage() { echo "50"; }
    get_cpu_usage() { echo "40"; }
    get_available_memory() { echo "2000"; }  # 2GB available
    get_cpu_cores() { echo "4"; }
    export -f get_memory_usage get_cpu_usage get_available_memory get_cpu_cores
    
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
    assert_output --partial "Invalid base_jobs"
    
    run calculate_optimal_parallel_jobs "0"
    assert_failure
    assert_output --partial "Invalid base_jobs"
}

# Cache setup tests (extending existing coverage)
@test "setup_cache: validates cache directory path for security" {
    run setup_cache "../../../tmp/malicious_cache"
    assert_failure
    assert_output --partial "Path traversal detected"
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
    assert_output --partial "invalid cache key"
    
    run save_to_cache "key/with/slashes" "data" "$TEST_CACHE_DIR"
    assert_failure
    assert_output --partial "invalid cache key"
}

@test "save_to_cache: validates required parameters" {
    setup_cache "$TEST_CACHE_DIR"
    
    run save_to_cache "" "data" "$TEST_CACHE_DIR"
    assert_failure
    assert_output --partial "cache_key and cache_dir are required"
    
    run save_to_cache "key" "data" ""
    assert_failure
    assert_output --partial "cache_key and cache_dir are required"
}

@test "save_to_cache: handles temporary file creation failure" {
    setup_cache "$TEST_CACHE_DIR"
    
    # Make cache directory read-only to force temp file creation failure
    chmod 444 "$TEST_CACHE_DIR"
    
    run save_to_cache "test_key" "test_data" "$TEST_CACHE_DIR"
    assert_failure
    assert_output --partial "failed to create temporary file"
    
    # Restore permissions for cleanup
    chmod 755 "$TEST_CACHE_DIR"
}

# Error handling utility tests
@test "check_command: validates command availability" {
    run check_command "ls"
    assert_success
    
    run check_command "non_existent_command_12345"
    assert_failure
    assert_output --partial "Command 'non_existent_command_12345' is required but not found"
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
    assert_output --partial "Invalid function name"
    assert_output --partial "contains unsafe characters"
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