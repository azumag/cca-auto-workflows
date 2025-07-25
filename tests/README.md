# Test Suite for Claude Code Auto Workflows

This directory contains test coverage for shell scripts in the `scripts/` directory using the BATS (Bash Automated Testing System) framework.

## Setup

### Prerequisites
- Bash 4.0 or later
- BATS testing framework (installed via system package manager or GitHub Actions)
- jq (for JSON processing in tests)
- git (for repository operations)

### Local Testing

For local development, install BATS using your system package manager:

**Ubuntu/Debian:**
```bash
sudo apt-get install bats
```

**macOS:**
```bash
brew install bats-core
```

**Install test dependencies:**
```bash
npm install  # Installs bats-support and bats-assert
```

## Running Tests

### Using GitHub Actions (Recommended)
Tests run automatically on push and pull requests via the `.github/workflows/tests.yml` workflow.

### Local Testing
```bash
# Set the library path for npm-installed dependencies
export BATS_LIB_PATH="./node_modules"

# Run all tests
bats tests/

# Run specific test file
bats tests/create-labels.bats

# Run with verbose output  
bats -v tests/
```

### Using npm Scripts
```bash
npm test  # Runs validation and linting
```

## Test Structure

- `*.bats` - Individual test files for each script
- `helpers/test-helpers.bash` - Shared test utilities and mocks
- `lib/test-common.bats` - Unit tests for common.sh library functions (performance optimized)
- Test files follow the naming pattern: `<script-name>.bats`

## Test Coverage

| Script | Test File | Status | Notes |
|--------|-----------|--------|-------|
| analyze-performance.sh | analyze-performance.bats | ✅ | |
| check-secrets.sh | check-secrets.bats | ✅ | |
| cleanup-old-runs.sh | cleanup-old-runs.bats | ✅ | |
| create-labels.sh | create-labels.bats | ✅ | |
| validate-workflows.sh | validate-workflows.bats | ✅ | |
| lib/common.sh | lib/test-common.bats | ✅ | Performance optimized |

## Performance Optimizations (Issue #75)

The `lib/test-common.bats` test suite has been optimized for performance:

### Improvements Made
- **Shared test fixtures**: Uses `setup_file()` instead of `setup()` for common resources
- **Reduced test setup time**: Environment variables and library sourcing done once vs. 40+ times
- **Optimized resource monitoring**: Better mocking to avoid actual system calls
- **Parallel test support**: Tests can run in parallel with `bats --jobs N`
- **Reduced temporary file creation**: Shared directories and files across tests

### Performance Gains
- Estimated **30-40% reduction** in test execution time
- **Reduced system resource usage** during test runs
- **Better test isolation** with proper cleanup

### Usage
```bash
# Run with parallel execution (recommended)
bats --jobs 4 tests/lib/test-common.bats

# Standard execution
bats tests/lib/test-common.bats
```

## Adding New Tests

1. Create a new `.bats` file in the `tests/` directory
2. Follow the naming convention: `<script-name>.bats`
3. Use the shared test helpers for consistent setup
4. Include both positive and negative test cases
5. Mock external dependencies (GitHub API, etc.)

Example test structure:
```bash
#!/usr/bin/env bats

setup() {
    load 'helpers/test-helpers'
    setup_script_test
}

teardown() {
    teardown_script_test
}

@test "script runs successfully with valid input" {
    # Test implementation
}
```