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
