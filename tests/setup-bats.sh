#!/bin/bash

# BATS Setup Script for Claude Code Auto Workflows
# This script sets up the BATS testing framework for shell script testing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BATS_VERSION="1.11.0"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

check_prerequisites() {
    log_info "Checking prerequisites for BATS installation..."
    
    # Check if git is available
    if ! command -v git &> /dev/null; then
        log_error "git is required but not installed"
        exit 1
    fi
    
    # Check if we can create directories
    if [[ ! -w "$PROJECT_ROOT" ]]; then
        log_error "Cannot write to project root: $PROJECT_ROOT"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

install_bats_core() {
    local bats_dir="$PROJECT_ROOT/tests/bats"
    
    log_info "Installing BATS core framework..."
    
    if [[ -d "$bats_dir" ]]; then
        log_warn "BATS directory already exists, removing..."
        rm -rf "$bats_dir"
    fi
    
    mkdir -p "$bats_dir"
    cd "$bats_dir"
    
    # Clone BATS core
    log_info "Cloning BATS core v$BATS_VERSION..."
    git clone --depth 1 --branch "v$BATS_VERSION" https://github.com/bats-core/bats-core.git bats-core
    
    # Clone BATS support libraries
    log_info "Cloning BATS support libraries..."
    git clone --depth 1 https://github.com/bats-core/bats-support.git bats-support
    git clone --depth 1 https://github.com/bats-core/bats-assert.git bats-assert
    git clone --depth 1 https://github.com/bats-core/bats-file.git bats-file
    
    # Make BATS executable
    chmod +x bats-core/bin/bats
    
    log_info "BATS framework installed successfully"
}

create_test_helpers() {
    local helpers_dir="$PROJECT_ROOT/tests/helpers"
    
    log_info "Creating test helper functions..."
    
    mkdir -p "$helpers_dir"
    
    # Create common test helpers
    cat > "$helpers_dir/common.bash" << 'EOF'
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
EOF

    log_info "Test helper functions created"
}

create_test_config() {
    local config_file="$PROJECT_ROOT/tests/test-config.bash"
    
    log_info "Creating test configuration..."
    
    cat > "$config_file" << 'EOF'
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
EOF

    log_info "Test configuration created"
}

create_npm_scripts() {
    log_info "Adding test scripts to package.json..."
    
    local package_json="$PROJECT_ROOT/package.json"
    
    # Check if jq is available for JSON manipulation
    if command -v jq &> /dev/null; then
        # Use jq to add test scripts
        jq '.scripts += {
            "test:setup": "tests/setup-bats.sh",
            "test:bats": "tests/bats/bats-core/bin/bats tests/*.bats",
            "test:coverage": "tests/bats/bats-core/bin/bats --report-formatter tap tests/*.bats | tee test-results.tap",
            "test:watch": "find tests -name \"*.bats\" | entr -c npm run test:bats",
            "test:clean": "rm -rf tests/bats test-results.tap"
        }' "$package_json" > "$package_json.tmp" && mv "$package_json.tmp" "$package_json"
    else
        log_warn "jq not available, please manually add these scripts to package.json:"
        echo "  \"test:setup\": \"tests/setup-bats.sh\","
        echo "  \"test:bats\": \"tests/bats/bats-core/bin/bats tests/*.bats\","
        echo "  \"test:coverage\": \"tests/bats/bats-core/bin/bats --report-formatter tap tests/*.bats | tee test-results.tap\","
        echo "  \"test:watch\": \"find tests -name \\\"*.bats\\\" | entr -c npm run test:bats\","
        echo "  \"test:clean\": \"rm -rf tests/bats test-results.tap\""
    fi
    
    log_info "Test scripts configuration completed"
}

create_readme() {
    local readme_file="$PROJECT_ROOT/tests/README.md"
    
    log_info "Creating test documentation..."
    
    cat > "$readme_file" << 'EOF'
# Test Suite for Claude Code Auto Workflows

This directory contains comprehensive tests for all shell scripts in the project using the BATS (Bash Automated Testing System) framework.

## Setup

Run the setup script to install BATS and dependencies:

```bash
npm run test:setup
```

## Running Tests

### Run all tests
```bash
npm run test:bats
```

### Run tests with coverage reporting
```bash
npm run test:coverage
```

### Watch mode (requires entr)
```bash
npm run test:watch
```

### Clean up test artifacts
```bash
npm run test:clean
```

## Test Structure

- `tests/` - Main test directory
  - `*.bats` - Test files for each script
  - `helpers/` - Common test helper functions
  - `fixtures/` - Test data and mock files
  - `bats/` - BATS framework installation
  - `setup-bats.sh` - Setup script for BATS framework

## Test Coverage

The test suite covers:

- **analyze-performance.sh** - Performance analysis functionality
- **check-secrets.sh** - Security scanning capabilities
- **cleanup-old-runs.sh** - Workflow cleanup operations
- **create-labels.sh** - Label management features
- **validate-workflows.sh** - Workflow validation logic

## Mocking Strategy

Tests use comprehensive mocking for external dependencies:

- GitHub CLI (`gh`) commands
- JSON processing tools (`jq`, `yq`)
- System commands (`date`, `find`, etc.)
- File system operations

## Writing New Tests

1. Create a new `.bats` file in the `tests/` directory
2. Load common helpers: `load helpers/common.bash`
3. Use setup/teardown functions for test isolation
4. Mock external dependencies appropriately
5. Use BATS assertion functions for validation

## Best Practices

- Test both success and failure scenarios
- Mock all external dependencies
- Use descriptive test names
- Test edge cases and error conditions
- Maintain test isolation
- Keep tests fast and reliable
EOF

    log_info "Test documentation created"
}

main() {
    log_info "Setting up BATS testing framework for Claude Code Auto Workflows..."
    
    check_prerequisites
    install_bats_core
    create_test_helpers
    create_test_config
    create_npm_scripts
    create_readme
    
    log_info "✅ BATS framework setup completed successfully!"
    log_info ""
    log_info "Next steps:"
    log_info "  1. Run 'npm run test:bats' to execute tests"
    log_info "  2. Run 'npm run test:coverage' for coverage reports"
    log_info "  3. Check tests/README.md for detailed usage instructions"
}

main "$@"