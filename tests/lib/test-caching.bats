#!/usr/bin/env bats
#
# Unit tests for caching functionality in common.sh
# Tests cache setup, key generation, validation, storage, and retrieval

# Setup and teardown
setup() {
    load '../helpers/test-helpers'
    setup_test_environment
    
    # Source the common library
    source "$BATS_TEST_DIRNAME/../../scripts/lib/common.sh"
    
    # Set up test cache directory
    TEST_CACHE_DIR="$TEST_TEMP_DIR/test_cache"
    TEST_CACHE_TTL=300
}

teardown() {
    teardown_test_environment
}

# Cache setup tests
@test "setup_cache: creates cache directory with correct permissions" {
    run setup_cache "$TEST_CACHE_DIR"
    assert_success
    
    # Check directory exists
    assert [ -d "$TEST_CACHE_DIR" ]
    
    # Check permissions (700 = rwx------)
    local perms
    perms=$(stat -c %a "$TEST_CACHE_DIR")
    assert_equal "$perms" "700"
}

@test "setup_cache: handles missing cache directory parameter" {
    run setup_cache ""
    assert_failure
    assert_output --partial "Cache directory not specified"
}

@test "setup_cache: creates nested cache directories" {
    local nested_cache="$TEST_CACHE_DIR/nested/deep/cache"
    run setup_cache "$nested_cache"
    assert_success
    assert [ -d "$nested_cache" ]
}

# Cache key generation tests
@test "get_cache_key: generates consistent SHA256 hash" {
    local input="test_input_data"
    local expected_hash
    expected_hash=$(echo -n "$input" | sha256sum | cut -d' ' -f1)
    
    run get_cache_key "$input"
    assert_success
    assert_output "$expected_hash"
}

@test "get_cache_key: generates different hashes for different inputs" {
    local key1 key2
    key1=$(get_cache_key "input1")
    key2=$(get_cache_key "input2")
    
    assert [ "$key1" != "$key2" ]
}

@test "get_cache_key: generates same hash for same input" {
    local key1 key2
    key1=$(get_cache_key "same_input")
    key2=$(get_cache_key "same_input")
    
    assert_equal "$key1" "$key2"
}

@test "get_cache_key: handles special characters and spaces" {
    local input="test input with spaces & special chars!@#$%"
    run get_cache_key "$input"
    assert_success
    # Should produce a valid SHA256 hash (64 characters)
    assert [ ${#output} -eq 64 ]
}

# Cache validation tests
@test "is_cache_valid: returns false for non-existent file" {
    local non_existent_file="$TEST_CACHE_DIR/non_existent"
    run is_cache_valid "$non_existent_file" "$TEST_CACHE_TTL"
    assert_failure
}

@test "is_cache_valid: returns true for fresh cache file" {
    setup_cache "$TEST_CACHE_DIR"
    local cache_file="$TEST_CACHE_DIR/fresh_cache"
    echo "test data" > "$cache_file"
    
    run is_cache_valid "$cache_file" "$TEST_CACHE_TTL"
    assert_success
}

@test "is_cache_valid: returns false for expired cache file" {
    setup_cache "$TEST_CACHE_DIR"
    local cache_file="$TEST_CACHE_DIR/expired_cache"
    echo "test data" > "$cache_file"
    
    # Make the file appear old by setting mtime to past
    touch -t $(date -d '1 hour ago' +%Y%m%d%H%M) "$cache_file"
    
    run is_cache_valid "$cache_file" "60"  # 1 minute TTL
    assert_failure
}

# Cache storage tests
@test "save_to_cache: stores data correctly" {
    setup_cache "$TEST_CACHE_DIR"
    local cache_key="test_key"
    local test_data="test data for caching"
    
    run save_to_cache "$cache_key" "$test_data" "$TEST_CACHE_DIR"
    assert_success
    
    # Verify file was created
    local cache_file="$TEST_CACHE_DIR/$cache_key"
    assert [ -f "$cache_file" ]
    
    # Verify data was stored correctly
    local stored_data
    stored_data=$(cat "$cache_file")
    assert_equal "$stored_data" "$test_data"
}

@test "save_to_cache: handles multiline data" {
    setup_cache "$TEST_CACHE_DIR"
    local cache_key="multiline_key"
    local test_data="line1
line2
line3"
    
    run save_to_cache "$cache_key" "$test_data" "$TEST_CACHE_DIR"
    assert_success
    
    local cache_file="$TEST_CACHE_DIR/$cache_key"
    local stored_data
    stored_data=$(cat "$cache_file")
    assert_equal "$stored_data" "$test_data"
}

@test "save_to_cache: handles special characters" {
    setup_cache "$TEST_CACHE_DIR"
    local cache_key="special_key"
    local test_data='{"name": "test", "value": 123, "special": "!@#$%^&*()"}'
    
    run save_to_cache "$cache_key" "$test_data" "$TEST_CACHE_DIR"
    assert_success
    
    local cache_file="$TEST_CACHE_DIR/$cache_key"
    local stored_data
    stored_data=$(cat "$cache_file")
    assert_equal "$stored_data" "$test_data"
}

@test "save_to_cache: atomic write operation" {
    setup_cache "$TEST_CACHE_DIR"
    local cache_key="atomic_key"
    local test_data="atomic test data"
    
    # Save data
    save_to_cache "$cache_key" "$test_data" "$TEST_CACHE_DIR"
    
    # Verify no temporary files remain
    local temp_files
    temp_files=$(find "$TEST_CACHE_DIR" -name "*.tmp.*" | wc -l)
    assert_equal "$temp_files" "0"
}

# Cache retrieval tests
@test "get_from_cache: retrieves stored data correctly" {
    setup_cache "$TEST_CACHE_DIR"
    local cache_key="retrieval_key"
    local test_data="data to retrieve"
    
    # Store data first
    save_to_cache "$cache_key" "$test_data" "$TEST_CACHE_DIR"
    
    # Retrieve data
    run get_from_cache "$cache_key" "$TEST_CACHE_DIR" "$TEST_CACHE_TTL"
    assert_success
    assert_output "$test_data"
}

@test "get_from_cache: returns failure for non-existent key" {
    setup_cache "$TEST_CACHE_DIR"
    
    run get_from_cache "non_existent_key" "$TEST_CACHE_DIR" "$TEST_CACHE_TTL"
    assert_failure
}

@test "get_from_cache: returns failure for expired cache" {
    setup_cache "$TEST_CACHE_DIR"
    local cache_key="expired_key"
    local test_data="expired data"
    
    # Store data
    save_to_cache "$cache_key" "$test_data" "$TEST_CACHE_DIR"
    
    # Make file appear expired
    local cache_file="$TEST_CACHE_DIR/$cache_key"
    touch -t $(date -d '1 hour ago' +%Y%m%d%H%M) "$cache_file"
    
    run get_from_cache "$cache_key" "$TEST_CACHE_DIR" "60"  # 1 minute TTL
    assert_failure
}

# Cache cleanup tests
@test "cleanup_cache: validates required parameters" {
    run cleanup_cache "" "3600"
    assert_failure
    assert_output --partial "cleanup_cache: cache_dir and cache_ttl are required"
    
    run cleanup_cache "$TEST_CACHE_DIR" ""
    assert_failure
    assert_output --partial "cleanup_cache: cache_dir and cache_ttl are required"
    
    run cleanup_cache
    assert_failure
    assert_output --partial "cleanup_cache: cache_dir and cache_ttl are required"
}

@test "cleanup_cache: validates TTL is numeric and positive" {
    setup_cache "$TEST_CACHE_DIR"
    
    # Test non-numeric TTL
    run cleanup_cache "$TEST_CACHE_DIR" "invalid"
    assert_failure
    assert_output --partial "cleanup_cache: invalid TTL value: invalid"
    
    # Test negative TTL
    run cleanup_cache "$TEST_CACHE_DIR" "-100"
    assert_failure
    assert_output --partial "cleanup_cache: invalid TTL value: -100"
    
    # Test zero TTL
    run cleanup_cache "$TEST_CACHE_DIR" "0"
    assert_failure
    assert_output --partial "cleanup_cache: invalid TTL value: 0"
    
    # Test floating point TTL
    run cleanup_cache "$TEST_CACHE_DIR" "3.14"
    assert_failure
    assert_output --partial "cleanup_cache: invalid TTL value: 3.14"
}

@test "cleanup_cache: prevents path traversal attacks" {
    # Test various path traversal attempts
    run cleanup_cache "../../../etc" "3600"
    assert_failure
    assert_output --partial "cleanup_cache: path traversal detected in cache_dir: ../../../etc"
    
    run cleanup_cache "/tmp/../../../etc" "3600"
    assert_failure
    assert_output --partial "cleanup_cache: path traversal detected in cache_dir: /tmp/../../../etc"
    
    run cleanup_cache "cache/../sensitive" "3600"
    assert_failure
    assert_output --partial "cleanup_cache: path traversal detected in cache_dir: cache/../sensitive"
}

@test "cleanup_cache: removes expired files" {
    setup_cache "$TEST_CACHE_DIR"
    
    # Create fresh file
    local fresh_file="$TEST_CACHE_DIR/fresh"
    echo "fresh data" > "$fresh_file"
    
    # Create expired file
    local expired_file="$TEST_CACHE_DIR/expired"
    echo "expired data" > "$expired_file"
    touch -t $(date -d '2 hours ago' +%Y%m%d%H%M) "$expired_file"
    
    # Run cleanup with 1 hour TTL
    run cleanup_cache "$TEST_CACHE_DIR" "3600"
    assert_success
    
    # Fresh file should remain
    assert [ -f "$fresh_file" ]
    
    # Expired file should be removed
    assert [ ! -f "$expired_file" ]
}

@test "cleanup_cache: handles non-existent cache directory" {
    local non_existent_dir="/tmp/non_existent_cache"
    run cleanup_cache "$non_existent_dir" "3600"
    assert_success  # Should not fail
}

@test "cleanup_cache: preserves fresh files" {
    setup_cache "$TEST_CACHE_DIR"
    
    # Create multiple fresh files
    for i in {1..5}; do
        echo "data $i" > "$TEST_CACHE_DIR/file_$i"
    done
    
    run cleanup_cache "$TEST_CACHE_DIR" "3600"
    assert_success
    
    # All files should remain
    for i in {1..5}; do
        assert [ -f "$TEST_CACHE_DIR/file_$i" ]
    done
}

# Cache statistics tests
@test "show_cache_stats: displays correct file count" {
    setup_cache "$TEST_CACHE_DIR"
    
    # Create test files
    for i in {1..3}; do
        echo "data $i" > "$TEST_CACHE_DIR/file_$i"
    done
    
    run show_cache_stats "$TEST_CACHE_DIR" "test files"
    assert_success
    assert_output --partial "3 cached entries"
    assert_output --partial "test files"
}

@test "show_cache_stats: handles empty cache directory" {
    setup_cache "$TEST_CACHE_DIR"
    
    run show_cache_stats "$TEST_CACHE_DIR" "empty cache"
    assert_success
    # Should not output anything for empty cache
    assert_equal "$output" ""
}

@test "show_cache_stats: handles non-existent directory" {
    local non_existent_dir="/tmp/non_existent_stats"
    
    run show_cache_stats "$non_existent_dir" "missing cache"
    assert_success
    # Should not output anything for missing directory
    assert_equal "$output" ""
}

# Integration tests
@test "cache_integration: full cache lifecycle" {
    setup_cache "$TEST_CACHE_DIR"
    
    local cache_key
    cache_key=$(get_cache_key "integration_test_data")
    local test_data='{"integration": "test", "timestamp": "2024-01-01T00:00:00Z"}'
    
    # 1. Store data
    run save_to_cache "$cache_key" "$test_data" "$TEST_CACHE_DIR"
    assert_success
    
    # 2. Retrieve data
    run get_from_cache "$cache_key" "$TEST_CACHE_DIR" "$TEST_CACHE_TTL"
    assert_success
    assert_output "$test_data"
    
    # 3. Verify cache is valid
    local cache_file="$TEST_CACHE_DIR/$cache_key"
    run is_cache_valid "$cache_file" "$TEST_CACHE_TTL"
    assert_success
    
    # 4. Show stats
    run show_cache_stats "$TEST_CACHE_DIR" "integration test"
    assert_success
    assert_output --partial "1 cached entries"
    
    # 5. Cleanup
    run cleanup_cache "$TEST_CACHE_DIR" "1"  # Remove all files (1 second TTL)
    assert_success
    
    # 6. Verify cleanup
    assert [ ! -f "$cache_file" ]
}

@test "cache_performance: handles large data" {
    skip_if_command_missing "time"
    
    setup_cache "$TEST_CACHE_DIR"
    
    # Generate large test data (1MB)
    local large_data
    large_data=$(yes "large data line for performance testing" | head -n 10000 | tr '\n' ' ')
    
    local cache_key
    cache_key=$(get_cache_key "large_data_test")
    
    # Test save performance
    run save_to_cache "$cache_key" "$large_data" "$TEST_CACHE_DIR"
    assert_success
    
    # Test retrieval performance
    run get_from_cache "$cache_key" "$TEST_CACHE_DIR" "$TEST_CACHE_TTL"
    assert_success
    
    # Verify data integrity
    assert [ ${#output} -gt 100000 ]  # Should be large
}

@test "cache_concurrency: handles concurrent access" {
    setup_cache "$TEST_CACHE_DIR"
    
    local cache_key="concurrent_key"
    local base_data="concurrent data"
    
    # Start multiple background processes
    local pids=()
    for i in {1..5}; do
        (
            local data="${base_data}_${i}"
            save_to_cache "${cache_key}_${i}" "$data" "$TEST_CACHE_DIR"
            get_from_cache "${cache_key}_${i}" "$TEST_CACHE_DIR" "$TEST_CACHE_TTL" >/dev/null
        ) &
        pids+=($!)
    done
    
    # Wait for all processes to complete
    local failed=0
    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            ((failed++))
        fi
    done
    
    # All operations should succeed
    assert_equal "$failed" "0"
    
    # Verify all files were created
    for i in {1..5}; do
        local cache_file="$TEST_CACHE_DIR/${cache_key}_${i}"
        assert [ -f "$cache_file" ]
        
        local stored_data
        stored_data=$(cat "$cache_file")
        assert_equal "$stored_data" "${base_data}_${i}"
    done
}