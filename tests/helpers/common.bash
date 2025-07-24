#!/bin/bash

# Common test helper functions for Claude Code Auto Workflows

# Set up BATS libraries
setup_bats_libs() {
    local test_dir="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
    local bats_dir="$test_dir/bats"
    
    load "$bats_dir/bats-support/load.bash"
    load "$bats_dir/bats-assert/load.bash"
    load "$bats_dir/bats-file/load.bash"
}

# Mock GitHub CLI commands
mock_gh_command() {
    local command="$1"
    local output="$2"
    local exit_code="${3:-0}"
    
    # Create mock function
    eval "gh() {
        if [[ \"\$1\" == \"$command\" ]]; then
            echo '$output'
            return $exit_code
        else
            echo 'Mock gh command called with: \$*' >&2
            return 1
        fi
    }"
}

# Mock jq command
mock_jq_command() {
    local output="$1"
    local exit_code="${2:-0}"
    
    eval "jq() {
        echo '$output'
        return $exit_code
    }"
}

# Mock yq command  
mock_yq_command() {
    local output="$1"
    local exit_code="${2:-0}"
    
    eval "yq() {
        echo '$output'
        return $exit_code
    }"
}

# Mock date command
mock_date_command() {
    local output="$1"
    local exit_code="${2:-0}"
    
    eval "date() {
        echo '$output'
        return $exit_code
    }"
}

# Create temporary test directory
create_temp_test_dir() {
    local temp_dir
    temp_dir=$(mktemp -d)
    echo "$temp_dir"
}

# Setup mock .github/workflows directory
setup_mock_workflows() {
    local test_dir="$1"
    local workflows_dir="$test_dir/.github/workflows"
    
    mkdir -p "$workflows_dir"
    
    # Create sample workflow files
    cat > "$workflows_dir/ci.yml" << 'YAML'
name: CI
on: [push, pull_request]
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: npm test
YAML

    cat > "$workflows_dir/deploy.yml" << 'YAML'
name: Deploy
on:
  push:
    branches: [main]
permissions:
  contents: read
  deployments: write
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy
        run: echo "Deploying..."
YAML
    
    echo "$workflows_dir"
}

# Mock successful API responses
setup_successful_api_mocks() {
    # Mock rate limit response
    mock_gh_command "api rate_limit" '{
        "rate": {
            "used": 100,
            "limit": 5000,
            "remaining": 4900,
            "reset": 1234567890
        }
    }'
    
    # Mock run list response
    mock_gh_command "run list*" '[
        {
            "name": "CI",
            "status": "completed",
            "conclusion": "success",
            "createdAt": "2024-01-01T00:00:00Z",
            "updatedAt": "2024-01-01T00:05:00Z",
            "databaseId": 12345
        }
    ]'
    
    # Mock workflow list response
    mock_gh_command "workflow list*" '[
        {"name": "CI"},
        {"name": "Deploy"}
    ]'
    
    # Mock label list response
    mock_gh_command "label list*" '[
        {"name": "bug"},
        {"name": "enhancement"}
    ]'
}

# Setup error scenarios for testing
setup_error_api_mocks() {
    # Mock API errors
    eval "gh() {
        echo 'API error: rate limit exceeded' >&2
        return 1
    }"
}

# Restore original commands
restore_commands() {
    unset -f gh jq yq date
}
