#!/bin/bash
# Test constants for parallel processing integration tests
# This file defines commonly used values to avoid magic numbers

# Test data sizes
readonly TEST_WORKFLOWS_COUNT=20
readonly MAX_TEST_RUNS=100
readonly SAMPLE_RUN_COUNT=3

# Timeout values (in seconds)
readonly TEST_TIMEOUT_SHORT=15
readonly TEST_TIMEOUT_MEDIUM=20
readonly TEST_TIMEOUT_LONG=30

# GitHub API limits and values
readonly GITHUB_API_LIMIT_DEFAULT=5000
readonly GITHUB_API_REMAINING_LOW=50
readonly GITHUB_API_REMAINING_HIGH=4900
readonly GITHUB_API_USED_LOW=100
readonly GITHUB_API_USED_HIGH=4950

# Default values for cleanup operations
readonly DEFAULT_CLEANUP_DAYS=30
readonly DEFAULT_MAX_RUNS=10
readonly DEFAULT_KEEP_RUNS=5

# Performance thresholds
readonly PERFORMANCE_DURATION_THRESHOLD=20
readonly SUCCESS_RATE_PERFECT=100
readonly API_HIT_RATE_THRESHOLD=33

# Mock delay settings
readonly MOCK_API_DELAY_SECONDS=0.1
readonly MOCK_PROCESS_SLEEP=0.5

# Node versions for testing
readonly NODE_VERSIONS="16 18 20"

# File system limits
readonly MAX_ERROR_COUNT=100
readonly MAX_WARNING_COUNT=100

# Random range values for API rate limiting simulation
readonly API_REMAINING_MIN=100
readonly API_REMAINING_MAX=4900