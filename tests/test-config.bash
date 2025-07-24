#!/bin/bash

# Test configuration for Claude Code Auto Workflows BATS tests

# Test environment setup
export BATS_TEST_TIMEOUT=30
export GITHUB_TOKEN="mock_token_for_testing"

# Project paths
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$PROJECT_ROOT/scripts"
TESTS_DIR="$PROJECT_ROOT/tests"

# Test data paths
TEST_DATA_DIR="$TESTS_DIR/fixtures"
TEMP_TEST_DIR=""

# Common setup for all tests
common_setup() {
    # Set up temporary directory for test
    TEMP_TEST_DIR=$(mktemp -d)
    cd "$TEMP_TEST_DIR"
    
    # Copy scripts to temp directory for testing
    cp -r "$SCRIPTS_DIR" ./scripts
    
    # Make scripts executable
    chmod +x ./scripts/*.sh
}

# Common teardown for all tests
common_teardown() {
    # Clean up temporary directory
    if [[ -n "$TEMP_TEST_DIR" && -d "$TEMP_TEST_DIR" ]]; then
        rm -rf "$TEMP_TEST_DIR"
    fi
}
