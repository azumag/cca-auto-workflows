# Performance Testing Framework

This document provides comprehensive documentation for the performance testing and optimization framework of Claude Code Auto Workflows.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Getting Started](#getting-started)
- [Testing Framework](#testing-framework)
- [Performance Analysis](#performance-analysis)
- [Benchmarking](#benchmarking)
- [Load Testing](#load-testing)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [API Reference](#api-reference)

## 🔍 Overview

The performance testing framework provides comprehensive tools for analyzing, benchmarking, and optimizing GitHub Actions workflows. It includes:

- **Modular Architecture**: Single-responsibility modules for maintainability
- **Comprehensive Testing**: Unit tests, integration tests, and end-to-end tests
- **Performance Analysis**: Real-time workflow and API usage analysis
- **Benchmarking**: Performance validation with baseline comparisons
- **Load Testing**: Stress testing under various load conditions
- **Metrics Collection**: Detailed performance metrics and reporting

## 🏗️ Architecture

The framework follows a modular architecture with clear separation of concerns:

```
scripts/
├── analyze-performance.sh      # Main analysis script
├── benchmark-performance.sh    # Benchmarking script
├── load-test.sh               # Load testing script
└── lib/                       # Modular libraries
    ├── common.sh              # Shared utilities
    ├── github-api.sh          # GitHub API interactions
    ├── workflow-analyzer.sh   # Workflow analysis
    ├── performance-metrics.sh # Metrics collection
    └── report-generator.sh    # Report generation

tests/
├── lib/                       # Unit tests for modules
├── integration/               # Integration tests
└── helpers/                   # Test utilities
```

### Core Modules

#### 1. GitHub API Module (`github-api.sh`)
- Centralized GitHub API interactions
- Intelligent caching with TTL
- Rate limiting protection
- Performance metrics collection

#### 2. Workflow Analyzer Module (`workflow-analyzer.sh`)
- Workflow runtime analysis
- Configuration efficiency analysis
- Complexity assessment
- Optimization recommendations

#### 3. Performance Metrics Module (`performance-metrics.sh`)
- Operation timing and measurement
- Cache hit rate tracking
- Memory usage monitoring
- Comprehensive reporting

#### 4. Report Generator Module (`report-generator.sh`)
- Multiple output formats (console, JSON, Markdown)
- API usage analysis reports
- Workflow optimization recommendations
- Executive summaries

## 🚀 Getting Started

### Prerequisites

- Bash 4.0 or later
- GitHub CLI (`gh`) installed and authenticated
- `jq` for JSON processing
- `bc` for calculations (optional, for advanced metrics)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/your-org/cca-auto-workflows.git
cd cca-auto-workflows
```

2. Install dependencies:
```bash
npm install --legacy-peer-deps
```

3. Verify GitHub CLI authentication:
```bash
gh auth status
```

### Basic Usage

#### Quick Performance Analysis
```bash
# Basic analysis
./scripts/analyze-performance.sh

# With benchmarking
./scripts/analyze-performance.sh --benchmarks

# Generate JSON report
./scripts/analyze-performance.sh --format json --output report.json
```

#### Performance Benchmarking
```bash
# Run comprehensive benchmarks
./scripts/benchmark-performance.sh

# Custom benchmark iterations
BENCHMARK_ITERATIONS=20 ./scripts/benchmark-performance.sh
```

#### Load Testing
```bash
# Medium load test
./scripts/load-test.sh medium

# Custom load test
./scripts/load-test.sh --concurrent 15 --total 200

# Rate limiting test
./scripts/load-test.sh --rate-limit heavy
```

## 🧪 Testing Framework

### Unit Tests

The framework includes comprehensive unit tests for all modules:

```bash
# Run all unit tests
npm test

# Run specific module tests
./node_modules/.bin/bats tests/lib/test-caching.bats
./node_modules/.bin/bats tests/lib/test-github-api.bats
./node_modules/.bin/bats tests/lib/test-performance-metrics.bats
```

#### Test Coverage

- **Caching Logic**: Cache setup, key generation, storage, retrieval, TTL validation
- **Rate Limiting**: API rate limit detection, backoff strategies, error handling
- **Parallel Processing**: Concurrent operations, load testing, thread safety
- **Integration**: End-to-end workflows with mocked GitHub API responses

### Integration Tests

Full system integration tests simulate real-world scenarios:

```bash
# Run integration tests
./node_modules/.bin/bats tests/integration/test-performance-analysis-integration.bats
```

Integration tests cover:
- Complete workflow analysis cycles
- Multiple output format generation
- Error handling and edge cases
- Module interaction and data flow

### Test Utilities

The `tests/helpers/test-helpers.bash` file provides utilities for:
- Mock GitHub CLI responses
- Test environment setup
- Assertion helpers
- Response file generation

## 📊 Performance Analysis

### Core Analysis Features

#### 1. Workflow Runtime Analysis
Analyzes recent workflow executions to identify:
- Average execution times by workflow
- Success/failure rates
- Performance trends
- Slow-running workflows (>15min average)

```bash
# Example output
Recent workflow performance (last 50 runs):
  📊 CI: 4min avg, 100% success rate (25 runs)
  📊 Deploy: 12min avg, 95% success rate (8 runs)
  📊 Tests: 18min avg, 88% success rate (15 runs)
```

#### 2. API Usage Analysis
Monitors GitHub API consumption:
- Current rate limit usage
- Remaining requests
- Reset time estimation
- Usage pattern recommendations

```bash
# Example output
GitHub API Usage:
  📈 Core API: 1250/5000 used (25%)
  🔄 Remaining: 3750 requests until reset
  ⏰ Reset in: 45 minutes
  ✅ API usage is within healthy limits
```

#### 3. Workflow Efficiency Analysis
Evaluates workflow configurations for optimization opportunities:
- Caching usage patterns
- Conditional execution adoption
- Matrix build utilization
- Security best practices

### Advanced Analysis Options

#### Command Line Options
```bash
# All available options
./scripts/analyze-performance.sh --help

# Key options:
--benchmarks          # Enable performance benchmarking
--load-tests         # Enable load testing
--format FORMAT      # Output format: console, json, markdown
--output FILE        # Save output to file
```

#### Environment Variables
```bash
# Configure behavior
export ENABLE_BENCHMARKS=true
export ENABLE_LOAD_TESTS=true
export OUTPUT_FORMAT=json
export OUTPUT_FILE=my-report.json
```

## 🏃 Benchmarking

### Benchmark Categories

#### 1. Cache Operations
- Write performance: `save_to_cache` operations
- Read performance: `get_from_cache` operations  
- Key generation: `get_cache_key` performance
- Cache validation: `is_cache_valid` speed

#### 2. GitHub API Operations
- Rate limit checks
- API call latency (with/without caching)
- Workflow run listing
- Cache hit performance

#### 3. Workflow Analysis
- Runtime analysis performance
- Efficiency analysis speed
- Complexity assessment time
- Large workflow handling

#### 4. Report Generation
- JSON report creation
- Markdown report generation
- API usage report compilation
- Comprehensive report assembly

### Benchmark Configuration

```bash
# Set benchmark iterations
export BENCHMARK_ITERATIONS=15

# Enable specific benchmarks
./scripts/benchmark-performance.sh

# View detailed results
cat /tmp/performance-benchmarks/benchmark-report-*.json
```

### Performance Baselines

The framework includes performance baselines for comparison:

| Operation | Baseline | Good Performance | Needs Optimization |
|-----------|----------|------------------|-------------------|
| Cache Operation | 1ms | <5ms | >10ms |
| API Call | 100ms | <200ms | >500ms |
| Workflow Analysis | 500ms | <1s | >2s |
| Report Generation | 200ms | <500ms | >1s |

## 🔥 Load Testing

### Load Test Scenarios

#### Built-in Scenarios
```bash
# Light load (5 concurrent, 25 total)
./scripts/load-test.sh light

# Medium load (10 concurrent, 100 total)
./scripts/load-test.sh medium

# Heavy load (20 concurrent, 500 total)
./scripts/load-test.sh heavy

# Burst load (50 concurrent, 200 total)
./scripts/load-test.sh burst

# Sustained load (8 concurrent, 1000 total)
./scripts/load-test.sh sustained

# All scenarios
./scripts/load-test.sh all
```

#### Custom Load Tests
```bash
# Custom configuration
./scripts/load-test.sh --concurrent 25 --total 300 --duration 180

# Rate limiting focus
./scripts/load-test.sh --rate-limit heavy

# Cache performance focus
./scripts/load-test.sh --cache-test medium
```

### Load Test Metrics

Load tests measure:
- **Throughput**: Requests per second
- **Success Rate**: Percentage of successful operations
- **Failure Rate**: Failed operations and reasons
- **Rate Limiting**: Rate limit hits and handling
- **Cache Performance**: Cache hit rates under load
- **Latency**: Operation response times

### Load Test Reports

```bash
# Generate detailed report
./scripts/load-test.sh medium --report load-test-results.json

# Example report structure
{
  "load_test_report": {
    "test_duration": 120.5,
    "scenarios_tested": [
      {
        "name": "medium",
        "concurrent": 10,
        "total": 100,
        "throughput": 8.3,
        "success_rate": 95.0
      }
    ]
  }
}
```

## 📚 Best Practices

### 1. Regular Performance Monitoring

#### Daily Monitoring
```bash
# Add to crontab for daily analysis
0 9 * * * cd /path/to/repo && ./scripts/analyze-performance.sh --format json --output daily-report.json
```

#### CI/CD Integration
```yaml
# GitHub Actions workflow
name: Performance Monitoring
on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours
jobs:
  performance:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Performance Analysis
        run: ./scripts/analyze-performance.sh --benchmarks
```

### 2. Optimization Workflow

1. **Baseline Measurement**: Run initial performance analysis
2. **Identify Issues**: Focus on workflows with >15min average runtime
3. **Implement Optimizations**: Add caching, conditionals, matrix builds
4. **Validate Improvements**: Re-run benchmarks to confirm gains
5. **Monitor Ongoing**: Set up regular monitoring

### 3. Cache Strategy

#### Effective Caching
```bash
# Good caching patterns in workflows
- uses: actions/cache@v3
  with:
    path: |
      ~/.npm
      node_modules
    key: ${{ runner.os }}-node-${{ hashFiles('package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-node-
```

#### Cache Monitoring
```bash
# Monitor cache effectiveness
./scripts/analyze-performance.sh | grep -A5 "Cache Performance"
```

### 4. Rate Limit Management

#### Proactive Monitoring
```bash
# Check current API usage
gh api rate_limit

# Monitor usage trends
./scripts/analyze-performance.sh | grep -A3 "API Usage"
```

#### Rate Limit Optimization
- Use GitHub App tokens for higher limits (15,000/hour vs 5,000/hour)
- Implement caching for repeated API calls
- Use conditional execution to reduce unnecessary API calls
- Batch operations where possible

### 5. Workflow Optimization

#### Performance Checklist
- [ ] Enable dependency caching
- [ ] Use explicit permissions (principle of least privilege)
- [ ] Pin action versions (avoid @main/@master)
- [ ] Implement conditional job execution
- [ ] Use matrix strategies for parallel execution
- [ ] Optimize Docker images (use specific, smaller images)
- [ ] Set up proper error handling and retries

#### Monitoring Improvements
```bash
# Before optimization
./scripts/benchmark-performance.sh > before.log

# After optimization  
./scripts/benchmark-performance.sh > after.log

# Compare results
diff before.log after.log
```

## 🔧 Troubleshooting

### Common Issues

#### 1. GitHub CLI Authentication
```bash
# Error: GitHub CLI authentication required
gh auth login

# Verify authentication
gh auth status
```

#### 2. Rate Limit Exceeded
```bash
# Check current limits
gh api rate_limit

# Wait for reset or use GitHub App token
export GITHUB_TOKEN="your-app-token"
```

#### 3. Missing Dependencies
```bash
# Install missing tools
sudo apt-get install jq bc  # Ubuntu/Debian
brew install jq bc          # macOS
```

#### 4. Permission Issues
```bash
# Fix script permissions
chmod +x scripts/*.sh
chmod +x tests/**/*.bats
```

#### 5. Test Failures
```bash
# Run tests with verbose output
./node_modules/.bin/bats -t tests/lib/test-caching.bats

# Check test environment
ls -la tests/helpers/
```

### Debug Mode

Enable debug output for troubleshooting:
```bash
# Enable debug logging
export DEBUG=1
./scripts/analyze-performance.sh

# Trace script execution
bash -x ./scripts/analyze-performance.sh
```

### Performance Issues

#### Slow Performance Analysis
1. Check GitHub API response times
2. Verify network connectivity
3. Consider using cached mode
4. Reduce analysis scope (fewer workflow runs)

#### High Memory Usage
1. Monitor with `htop` during execution
2. Clear caches regularly
3. Reduce concurrent operations in load tests
4. Check for memory leaks in long-running tests

## 📖 API Reference

### Core Functions

#### GitHub API Module
```bash
# Initialize GitHub API module
github_api_init

# Make cached API call
github_api_call "endpoint"

# Get rate limit information
github_get_rate_limit

# Get API performance metrics
github_api_get_metrics

# Clean up API module
github_api_cleanup
```

#### Performance Metrics Module
```bash
# Initialize performance metrics
performance_metrics_init

# Start timing operation
start_timer "operation_name"

# End timing operation
end_timer "operation_name" "success_status"

# Run performance benchmark
run_performance_benchmark "name" "command"

# Run load test
run_load_test "name" "command" concurrent total

# Generate performance report
generate_performance_report

# Export metrics to JSON
export_metrics_json "output_file"
```

#### Workflow Analyzer Module
```bash
# Initialize workflow analyzer
workflow_analyzer_init

# Analyze workflow runtime
analyze_workflow_runtime

# Analyze workflow efficiency
analyze_workflow_efficiency

# Analyze workflow complexity
analyze_workflow_complexity

# Get analyzer metrics
workflow_analyzer_get_metrics
```

#### Report Generator Module
```bash
# Initialize report generator
report_generator_init

# Generate API usage report
generate_api_usage_report

# Generate workflow optimization report
generate_workflow_optimization_report

# Generate comprehensive report
generate_comprehensive_report "output_file"

# Generate JSON report
generate_json_report "output_file"
```

### Configuration Variables

#### Environment Variables
```bash
# GitHub API Configuration
GITHUB_API_CACHE_DIR="/tmp/github-api-cache"
GITHUB_API_CACHE_TTL=300
GITHUB_API_RATE_LIMIT_BUFFER=100

# Performance Metrics Configuration
METRICS_DIR="/tmp/performance-metrics"
METRICS_RETENTION_DAYS=30
BENCHMARK_ITERATIONS=5

# Load Test Configuration
LOAD_TEST_CONCURRENT=10
LOAD_TEST_TOTAL=100
LOAD_TEST_DURATION=60
```

#### Script Options
```bash
# Performance Analysis Options
--benchmarks        # Enable benchmarking
--load-tests       # Enable load testing
--format FORMAT    # Output format (console, json, markdown)
--output FILE      # Output file path

# Benchmarking Options
BENCHMARK_ITERATIONS=N  # Number of benchmark iterations

# Load Testing Options
--concurrent N     # Concurrent operations
--total N         # Total operations
--duration N      # Test duration in seconds
--rate-limit      # Enable rate limit testing
--cache-test      # Enable cache testing
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Missing dependency |
| 3 | Authentication failure |
| 4 | Rate limit exceeded |
| 5 | Configuration error |

## 📚 Further Reading

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitHub API Rate Limiting](https://docs.github.com/en/rest/overview/resources-in-the-rest-api#rate-limiting)
- [Performance Testing Best Practices](https://github.com/azumag/cca-auto-workflows/blob/main/docs/BEST_PRACTICES.md)
- [Contributing Guidelines](https://github.com/azumag/cca-auto-workflows/blob/main/CONTRIBUTING.md)

---

*This documentation is generated for Claude Code Auto Workflows Performance Testing Framework v2.1.0*