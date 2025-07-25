#!/bin/bash
#
# Basic validation script for common.sh functions
# This runs without bats to verify basic functionality

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source the common library
source "$PROJECT_ROOT/scripts/lib/common.sh"

# Test temp directory
TEST_TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEST_TEMP_DIR" EXIT

echo "Testing common.sh functions..."

# Test 1: get_enhanced_cache_key
echo "Testing get_enhanced_cache_key..."
TEST_FILE="$TEST_TEMP_DIR/test_file.txt"
echo "test content" > "$TEST_FILE"

CACHE_KEY=$(get_enhanced_cache_key "$TEST_FILE")
if [[ ${#CACHE_KEY} -eq 64 ]]; then
    echo "✓ get_enhanced_cache_key generates 64-character hash"
else
    echo "✗ get_enhanced_cache_key failed - got ${#CACHE_KEY} characters"
    exit 1
fi

# Test path traversal detection
if get_enhanced_cache_key "../../../etc/passwd" 2>/dev/null; then
    echo "✗ get_enhanced_cache_key failed to detect path traversal"
    exit 1
else
    echo "✓ get_enhanced_cache_key detects path traversal"
fi

# Test 2: setup_cache
echo "Testing setup_cache..."
TEST_CACHE_DIR="$TEST_TEMP_DIR/test_cache"
if setup_cache "$TEST_CACHE_DIR"; then
    if [[ -d "$TEST_CACHE_DIR" ]]; then
        echo "✓ setup_cache creates directory"
    else
        echo "✗ setup_cache failed to create directory"
        exit 1
    fi
else
    echo "✗ setup_cache failed"
    exit 1
fi

# Test 3: save_to_cache and get_from_cache
echo "Testing cache save/retrieve..."
CACHE_KEY="test_key"
TEST_DATA="test cache data"
CACHE_TTL=300

if save_to_cache "$CACHE_KEY" "$TEST_DATA" "$TEST_CACHE_DIR"; then
    echo "✓ save_to_cache succeeded"
else
    echo "✗ save_to_cache failed"
    exit 1
fi

RETRIEVED_DATA=$(get_from_cache "$CACHE_KEY" "$TEST_CACHE_DIR" "$CACHE_TTL")
if [[ "$RETRIEVED_DATA" == "$TEST_DATA" ]]; then
    echo "✓ get_from_cache retrieved correct data"
else
    echo "✗ get_from_cache failed - expected '$TEST_DATA', got '$RETRIEVED_DATA'"
    exit 1
fi

# Test 4: show_progress
echo "Testing show_progress..."
if show_progress 50 100 "test operation" >/dev/null; then
    echo "✓ show_progress runs without error"
else
    echo "✗ show_progress failed"
    exit 1
fi

# Test invalid inputs
if show_progress "invalid" 100 "test" 2>/dev/null; then
    echo "✗ show_progress failed to validate inputs"
    exit 1
else
    echo "✓ show_progress validates inputs"
fi

# Test 5: validate_config with proper values
echo "Testing validate_config..."
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

if validate_config 2>/dev/null; then
    echo "✓ validate_config passes with valid configuration"
else
    echo "✗ validate_config failed with valid configuration"
    exit 1
fi

# Test invalid config
export MAX_PARALLEL_JOBS="invalid"
if validate_config 2>/dev/null; then
    echo "✗ validate_config failed to catch invalid MAX_PARALLEL_JOBS"
    exit 1
else
    echo "✓ validate_config catches invalid MAX_PARALLEL_JOBS"
fi

# Test 6: check_command
echo "Testing check_command..."
if check_command "ls" 2>/dev/null; then
    echo "✓ check_command finds existing command"
else
    echo "✗ check_command failed to find ls"
    exit 1
fi

if check_command "non_existent_command_12345" 2>/dev/null; then
    echo "✗ check_command failed to detect missing command"
    exit 1
else
    echo "✓ check_command detects missing command"
fi

# Test 7: Basic resource monitoring functions
echo "Testing resource monitoring functions..."
MEMORY_USAGE=$(get_memory_usage)
if [[ "$MEMORY_USAGE" =~ ^[0-9]+$ ]]; then
    echo "✓ get_memory_usage returns numeric value: $MEMORY_USAGE%"
else
    echo "✗ get_memory_usage failed to return numeric value"
    exit 1
fi

CPU_CORES=$(get_cpu_cores)
if [[ "$CPU_CORES" =~ ^[0-9]+$ ]] && [[ "$CPU_CORES" -ge 1 ]]; then
    echo "✓ get_cpu_cores returns valid value: $CPU_CORES"
else
    echo "✗ get_cpu_cores failed to return valid value"
    exit 1
fi

echo ""
echo "All basic functionality tests passed! ✓"
echo ""
echo "Note: Full test suite requires bats testing framework."
echo "Run 'bats tests/lib/test-common.bats' when bats is available."