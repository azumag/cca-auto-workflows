# Test Suite for Claude Code Auto Workflows

This directory contains comprehensive test coverage for all shell scripts in the `scripts/` directory using the BATS (Bash Automated Testing System) framework.

## Setup

### Prerequisites
- Bash 4.0 or later
- curl (for downloading BATS)
- jq (for JSON processing in tests)
- git (for repository operations)

### Initial Setup
Run the setup script to install BATS and its dependencies:

```bash
./tests/bats-setup.sh
```

This will:
- Download and install BATS core
- Install BATS support libraries (bats-support, bats-assert, bats-file)
- Create the test runner script
- Set up the test environment

## Running Tests

### All Tests
```bash
./tests/run-tests.sh
```

### Verbose Output
```bash
./tests/run-tests.sh --verbose
```

### Specific Test File
```bash
./tests/run-tests.sh --test analyze-performance.bats
```

### Using npm Scripts
```bash
npm run test:setup        # Set up BATS framework
npm run test:bats         # Run all BATS tests
npm run test:bats:verbose # Run with verbose output
npm run test:coverage     # Generate coverage report
```

## Test Structure

### Test Files
- `analyze-performance.bats` - Tests for `scripts/analyze-performance.sh`
- `check-secrets.bats` - Tests for `scripts/check-secrets.sh`
- `cleanup-old-runs.bats` - Tests for `scripts/cleanup-old-runs.sh`
- `create-labels.bats` - Tests for `scripts/create-labels.sh`
- `validate-workflows.bats` - Tests for `scripts/validate-workflows.sh`

### Helper Files
- `helpers/test-helpers.bash` - Common test utilities and setup functions
- `bats-setup.sh` - BATS framework installation script
- `run-tests.sh` - Test runner with options

## Test Features

### Mocking
All external dependencies are mocked for isolated testing:
- **GitHub CLI (`gh`)** - Mocked API responses and authentication
- **jq** - JSON processing with controlled output
- **yq** - YAML processing for workflow validation
- **python3** - Python YAML parsing fallback
- **date** - Consistent date/time for testing

### Test Environment
Each test runs in an isolated environment:
- Temporary directory for test files
- Controlled PATH for binary mocking
- Mock GitHub repository structure
- Cleanup after each test

### Coverage Areas

#### Script Functionality Tests
- ✅ Core function testing
- ✅ Error handling
- ✅ Edge cases
- ✅ Input validation
- ✅ Output verification

#### Integration Tests
- ✅ GitHub API interactions (mocked)
- ✅ File system operations
- ✅ Command-line argument parsing
- ✅ Environment variable handling

#### Security Tests
- ✅ Secret detection patterns
- ✅ Permission validation
- ✅ Input sanitization

#### Performance Tests
- ✅ Large data set handling
- ✅ Timeout scenarios
- ✅ Resource usage patterns

## Writing New Tests

### Basic Test Structure
```bash
#!/usr/bin/env bats

# Setup and teardown
setup() {
    load 'helpers/test-helpers'
    setup_script_test
    # Your setup code here
}

teardown() {
    teardown_script_test
}

@test "script-name: test description" {
    # Your test code here
    run some_command
    assert_success
    assert_output --partial "expected output"
}
```

### Common Patterns

#### Testing Script Execution
```bash
@test "script: executes successfully" {
    run ./path/to/script.sh
    assert_success
    assert_output --partial "expected message"
}
```

#### Testing with Mocked Commands
```bash
@test "script: handles API failure" {
    create_gh_mock "" 1  # Exit code 1 for failure
    run ./path/to/script.sh
    assert_failure
    assert_output --partial "error message"
}
```

#### Testing Function Behavior
```bash
@test "script: function works correctly" {
    run bash -c "source './script.sh'; my_function 'arg1' 'arg2'"
    assert_success
    assert_output "expected result"
}
```

### Assertions Available
- `assert_success` / `assert_failure`
- `assert_output [--partial] "expected"`
- `refute_output [--partial] "unexpected"`
- `assert_line [--index N] [--partial] "expected"`
- `assert_file_exists "path"`
- `assert_file_executable "path"`

## CI Integration

The tests are automatically run in GitHub Actions workflow:
- **test.yml** - Main test workflow
- Runs on push/PR to main branches
- Includes linting, validation, and coverage reporting
- Generates test coverage artifacts

## Test Coverage

Current test coverage includes:

### analyze-performance.sh
- ✅ 30+ test cases
- ✅ API rate limit checking
- ✅ Workflow performance analysis
- ✅ Optimization recommendations

### check-secrets.sh  
- ✅ 25+ test cases
- ✅ Hardcoded secret detection
- ✅ Workflow security validation
- ✅ Pattern matching tests

### cleanup-old-runs.sh
- ✅ 25+ test cases
- ✅ Argument parsing
- ✅ Date handling
- ✅ Dry-run functionality

### create-labels.sh
- ✅ 20+ test cases
- ✅ Label creation/updating
- ✅ Color validation
- ✅ Error handling

### validate-workflows.sh
- ✅ 30+ test cases
- ✅ YAML syntax validation
- ✅ Security best practices
- ✅ Performance optimization checks

## Troubleshooting

### Common Issues

#### BATS Not Found
```bash
./tests/bats-setup.sh
```

#### Permission Denied
```bash
chmod +x tests/run-tests.sh
chmod +x tests/bats-setup.sh
```

#### Test Failures
1. Check that required tools are available
2. Verify test environment setup
3. Review mock configurations
4. Check for path issues

### Debug Mode
For debugging failing tests:
```bash
./tests/run-tests.sh --verbose --test failing-test.bats
```

## Maintenance

### Adding New Scripts
1. Create corresponding `.bats` test file
2. Add test cases for all functions
3. Include mocking for external dependencies
4. Update this README

### Updating Tests
1. Keep tests synchronized with script changes
2. Maintain mock responses for API changes
3. Update coverage documentation
4. Review CI integration

## Resources

- [BATS Documentation](https://bats-core.readthedocs.io/)
- [BATS Assert Library](https://github.com/bats-core/bats-assert)
- [BATS Support Library](https://github.com/bats-core/bats-support)
- [BATS File Library](https://github.com/bats-core/bats-file)