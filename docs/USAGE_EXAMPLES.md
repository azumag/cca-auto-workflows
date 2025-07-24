# Usage Examples

This document provides practical examples for using the Claude Code Auto Workflows performance testing framework.

## 📋 Table of Contents

- [Quick Start Examples](#quick-start-examples)
- [Performance Analysis Examples](#performance-analysis-examples)
- [Benchmarking Examples](#benchmarking-examples)
- [Load Testing Examples](#load-testing-examples)
- [CI/CD Integration Examples](#cicd-integration-examples)
- [Troubleshooting Examples](#troubleshooting-examples)
- [Advanced Usage Examples](#advanced-usage-examples)

## 🚀 Quick Start Examples

### Basic Performance Analysis
```bash
# Run a basic performance analysis
./scripts/analyze-performance.sh

# Example output:
# 📊 Starting performance analysis for Claude Code Auto Workflows...
# 🚀 Initializing performance analysis modules...
# ✅ All modules initialized successfully
# 
# [ANALYSIS] Analyzing workflow runtime performance...
# Recent workflow performance (last 50 runs):
#   📊 CI: 4min avg, 100% success rate (25 runs)
#   📊 Deploy: 12min avg, 95% success rate (8 runs)
# 
# [ANALYSIS] Analyzing GitHub API usage...
# GitHub API Usage:
#   📈 Core API: 1250/5000 used (25%)
#   🔄 Remaining: 3750 requests until reset
#   ✅ API usage is within healthy limits
```

### Generate JSON Report
```bash
# Generate a JSON report for automated processing
./scripts/analyze-performance.sh --format json --output my-performance-report.json

# View the generated report
cat my-performance-report.json | jq '.'

# Example JSON structure:
{
  "report": {
    "generated_at": "2024-07-24T10:30:00Z",
    "repository": "my-org/my-repo"
  },
  "workflows": {
    "total_count": 5
  },
  "api_usage": {
    "used": 1250,
    "limit": 5000,
    "usage_percent": 25,
    "status": "healthy"
  }
}
```

### Generate Markdown Report
```bash
# Generate a comprehensive Markdown report
./scripts/analyze-performance.sh --format markdown --output performance-report.md

# The generated report includes:
# - Executive summary
# - API usage analysis  
# - Workflow performance metrics
# - Optimization recommendations
# - Resource links
```

## 📊 Performance Analysis Examples

### Analyzing Specific Issues

#### Identify Slow Workflows
```bash
# Run analysis and look for slow workflows
./scripts/analyze-performance.sh | grep -A10 "workflow runtime performance"

# Look for warnings about slow workflows
./scripts/analyze-performance.sh 2>&1 | grep "15min average runtime"

# Example output identifying issues:
# ⚠️  Found 2 workflow(s) with >15min average runtime
# ⚠️  Found 1 workflow(s) with <90% success rate
```

#### Monitor API Usage Trends
```bash
# Check current API usage
./scripts/analyze-performance.sh | grep -A5 "GitHub API Usage"

# Set up monitoring for high usage
if ./scripts/analyze-performance.sh | grep -q "High API usage detected"; then
    echo "ALERT: High GitHub API usage detected!"
    # Send notification or take action
fi
```

#### Analyze Workflow Efficiency
```bash
# Focus on workflow configuration analysis
./scripts/analyze-performance.sh | grep -A10 "Analyzing workflow efficiency"

# Example output showing optimization opportunities:
# Workflow Configuration Analysis:
#   📁 Total workflows: 5
#   🚀 Using caching: 2/5 workflows
#   🎯 Using conditionals: 3/5 workflows
#   ⚡ Using matrix builds: 1/5 workflows
# ⚠️  Consider adding caching to more workflows for better performance
```

### Advanced Analysis Options

#### Enable All Performance Features
```bash
# Run comprehensive analysis with benchmarks and load tests
./scripts/analyze-performance.sh --benchmarks --load-tests

# Set environment variables for consistent configuration
export ENABLE_BENCHMARKS=true
export ENABLE_LOAD_TESTS=true
./scripts/analyze-performance.sh
```

#### Custom Output Configuration
```bash
# Save to custom location with timestamp
OUTPUT_FILE="reports/performance-$(date +%Y%m%d-%H%M%S).json"
./scripts/analyze-performance.sh --format json --output "$OUTPUT_FILE"

# Generate both JSON and Markdown reports
./scripts/analyze-performance.sh --format json --output analysis.json
./scripts/analyze-performance.sh --format markdown --output analysis.md
```

## 🏃 Benchmarking Examples

### Basic Benchmarking

#### Run Standard Benchmarks
```bash
# Run all standard benchmarks
./scripts/benchmark-performance.sh

# Example output:
# 🏃 Running performance benchmark: github_api_rate_limit
#   📊 Benchmark iteration 1/5
#   📊 Benchmark iteration 2/5
#   ...
# 📈 Benchmark Results for github_api_rate_limit:
#   ⏱️  Average time: 0.156s
#   🚀 Best time: 0.142s
#   🐌 Worst time: 0.178s
#   ✅ Success rate: 5/5
```

#### Custom Benchmark Configuration
```bash
# Run benchmarks with more iterations for accuracy
BENCHMARK_ITERATIONS=20 ./scripts/benchmark-performance.sh

# Run benchmarks and save detailed report
./scripts/benchmark-performance.sh
cat /tmp/performance-benchmarks/benchmark-report-*.json | jq '.benchmark_report.performance_metrics'
```

### Benchmark Comparison

#### Before/After Optimization Comparison
```bash
# Before optimization
echo "=== BEFORE OPTIMIZATION ===" > benchmark-comparison.txt
./scripts/benchmark-performance.sh >> benchmark-comparison.txt 2>&1

# Make your optimizations (add caching, etc.)
# ... implement optimizations ...

# After optimization  
echo "=== AFTER OPTIMIZATION ===" >> benchmark-comparison.txt
./scripts/benchmark-performance.sh >> benchmark-comparison.txt 2>&1

# Review comparison
cat benchmark-comparison.txt
```

#### Automated Performance Validation
```bash
#!/bin/bash
# validate-performance.sh - Automated performance validation script

echo "Running performance validation..."

# Run benchmarks and capture results
BENCHMARK_RESULTS=$(./scripts/benchmark-performance.sh 2>&1)

# Check if performance meets criteria
if echo "$BENCHMARK_RESULTS" | grep -q "Cache ops: [0-9.]*s ([0-2]\..*x baseline)"; then
    echo "✅ Cache performance within acceptable range"
else
    echo "❌ Cache performance degraded"
    exit 1
fi

if echo "$BENCHMARK_RESULTS" | grep -q "API calls: [0-9.]*s ([0-3]\..*x baseline)"; then
    echo "✅ API performance within acceptable range"  
else
    echo "❌ API performance degraded"
    exit 1
fi

echo "✅ All performance benchmarks passed"
```

## 🔥 Load Testing Examples

### Basic Load Testing

#### Run Predefined Scenarios
```bash
# Light load test (good for development)
./scripts/load-test.sh light

# Medium load test (typical production load)
./scripts/load-test.sh medium

# Heavy load test (stress testing)
./scripts/load-test.sh heavy

# Example output:
# 🔥 Running concurrent load test: medium
#   📊 Configuration: 10 concurrent, 100 total, 60s duration
#   🎯 Operation type: mixed
# 📈 Load Test Results for medium:
#   ⏱️  Duration: 58s
#   📊 Total requests: 100
#   ✅ Successful: 95 (95.0%)
#   ❌ Failed: 5
#   📈 Throughput: 1.7 req/sec
```

#### Custom Load Testing
```bash
# Custom load test parameters
./scripts/load-test.sh --concurrent 15 --total 200 --duration 120

# Focus on specific aspects
./scripts/load-test.sh --rate-limit heavy    # Test rate limiting
./scripts/load-test.sh --cache-test medium   # Test cache performance
```

### Load Test Scenarios

#### Rate Limiting Validation
```bash
# Test rate limiting behavior
./scripts/load-test.sh --rate-limit burst

# Example output showing rate limiting:
# 🚦 Running rate limiting stress test...
# 🎯 Testing rate limit detection and handling...
# ✅ Rate limiting detected after 127 requests
# 🚦 Rate Limiting Test Results:
#   📊 Total attempts: 127
#   ✅ Successful: 115
#   🚫 Rate limited: 12
#   📈 Rate limit hit ratio: 9.4%
# ✅ Rate limiting functionality is working correctly
```

#### Cache Performance Under Load
```bash
# Test cache effectiveness under concurrent access
./scripts/load-test.sh --cache-test sustained

# Example output:
# 💾 Running cache performance test under load...
# 🎯 Testing cache performance under concurrent access...
# 💾 Cache Performance Test Results:
#   📊 Total cache operations: 200
#   ✅ Successful operations: 198
#   💾 Estimated cache hits: 156 (78.0%)
#   🎯 Cache endpoints tested: 5
# ✅ Cache performance is effective (>50% hit rate)
```

#### Comprehensive Load Testing
```bash
# Run all load test scenarios
./scripts/load-test.sh all --report comprehensive-load-test.json

# This will run: light, medium, heavy, burst, sustained
# Each scenario tests different aspects:
# - Light: Basic functionality
# - Medium: Typical usage patterns  
# - Heavy: High throughput stress
# - Burst: Sudden load spikes
# - Sustained: Long-term stability
```

### Load Test Analysis

#### Parse Load Test Results
```bash
# Generate detailed load test report
./scripts/load-test.sh medium --report load-results.json

# Extract key metrics
cat load-results.json | jq '.load_test_report.scenarios_tested[0] | {
  name: .name,
  throughput: .throughput,
  success_rate: (.successful * 100 / .requests),
  failure_rate: (.failed * 100 / .requests)
}'

# Example output:
{
  "name": "medium",
  "throughput": 1.67,
  "success_rate": 95,
  "failure_rate": 5
}
```

## 🔄 CI/CD Integration Examples

### GitHub Actions Integration

#### Performance Monitoring Workflow
```yaml
# .github/workflows/performance-monitoring.yml
name: Performance Monitoring

on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours
  workflow_dispatch:       # Manual trigger

jobs:
  performance-analysis:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          
      - name: Install dependencies
        run: npm install --legacy-peer-deps
        
      - name: Run performance analysis
        run: |
          ./scripts/analyze-performance.sh --format json --output performance-report.json
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          
      - name: Upload performance report
        uses: actions/upload-artifact@v3
        with:
          name: performance-report
          path: performance-report.json
          
      - name: Check for performance issues
        run: |
          if grep -q '"status": "critical"' performance-report.json; then
            echo "::error::Critical performance issues detected!"
            exit 1
          elif grep -q '"status": "high"' performance-report.json; then
            echo "::warning::High API usage detected"
          fi
```

#### PR Performance Validation
```yaml
# .github/workflows/pr-performance-check.yml
name: PR Performance Check

on:
  pull_request:
    paths:
      - '.github/workflows/**'
      - 'scripts/**'

jobs:
  performance-validation:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        
      - name: Run performance benchmarks
        run: |
          ./scripts/benchmark-performance.sh > benchmark-results.txt
          
      - name: Validate performance
        run: |
          # Check if performance is within acceptable bounds
          if ! grep -q "✅ All modules initialized successfully" benchmark-results.txt; then
            echo "::error::Module initialization failed"
            exit 1
          fi
          
          # Check for performance regressions
          if grep -q "Slow operation detected" benchmark-results.txt; then
            echo "::warning::Performance regression detected"
          fi
          
      - name: Comment PR with results
        uses: actions/github-script@v6
        with:
          script: |
            const fs = require('fs');
            const results = fs.readFileSync('benchmark-results.txt', 'utf8');
            
            const body = `## Performance Benchmark Results
            
            \`\`\`
            ${results}
            \`\`\`
            
            Generated by [Performance Testing Framework](https://github.com/azumag/cca-auto-workflows)
            `;
            
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: body
            });
```

### Automated Alerts

#### Performance Alert Script
```bash
#!/bin/bash
# performance-alert.sh - Send alerts based on performance metrics

REPORT_FILE="performance-report.json"
WEBHOOK_URL="your-slack-webhook-url"

# Run performance analysis
./scripts/analyze-performance.sh --format json --output "$REPORT_FILE"

# Extract metrics
API_USAGE=$(cat "$REPORT_FILE" | jq -r '.api_usage.usage_percent // 0')
WORKFLOW_COUNT=$(cat "$REPORT_FILE" | jq -r '.workflows.total_count // 0')

# Check thresholds and send alerts
if [[ $API_USAGE -gt 80 ]]; then
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"🚨 High GitHub API usage detected: ${API_USAGE}%\"}" \
        "$WEBHOOK_URL"
fi

if [[ $WORKFLOW_COUNT -gt 20 ]]; then
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"📊 Large number of workflows detected: ${WORKFLOW_COUNT}. Consider optimization.\"}" \
        "$WEBHOOK_URL"
fi
```

## 🔧 Troubleshooting Examples

### Common Issue Resolution

#### GitHub CLI Authentication Issues
```bash
# Check authentication status
gh auth status

# If not authenticated:
gh auth login

# For CI/CD, use token authentication:
export GITHUB_TOKEN="your-token-here"
gh auth status

# Verify token has correct permissions:
gh api user
```

#### Rate Limit Exceeded
```bash
# Check current rate limit status
gh api rate_limit

# Example response:
{
  "rate": {
    "limit": 5000,
    "used": 4998,
    "remaining": 2,
    "reset": 1640995200
  }
}

# Wait for reset or use different token
RESET_TIME=$(gh api rate_limit | jq -r '.rate.reset')
CURRENT_TIME=$(date +%s)
WAIT_TIME=$((RESET_TIME - CURRENT_TIME))
echo "Waiting ${WAIT_TIME} seconds for rate limit reset..."
sleep $WAIT_TIME
```

#### Performance Analysis Failures
```bash
# Debug mode for troubleshooting
DEBUG=1 ./scripts/analyze-performance.sh

# Check for missing dependencies
command -v gh >/dev/null || echo "GitHub CLI not found"
command -v jq >/dev/null || echo "jq not found"
command -v bc >/dev/null || echo "bc not found (optional)"

# Verify workflow directory exists
if [[ ! -d ".github/workflows" ]]; then
    echo "No .github/workflows directory found"
    echo "Current directory: $(pwd)"
    echo "Contents: $(ls -la)"
fi
```

#### Test Failures
```bash
# Run tests with verbose output
./node_modules/.bin/bats -t tests/lib/test-caching.bats

# Run specific test case
./node_modules/.bin/bats -f "cache_integration" tests/lib/test-caching.bats

# Check test environment
echo "Test temp dir: $TEST_TEMP_DIR"
ls -la "$TEST_TEMP_DIR" 2>/dev/null || echo "Test temp dir not found"

# Verify test helpers
ls -la tests/helpers/test-helpers.bash
```

## 🚀 Advanced Usage Examples

### Custom Module Development

#### Creating a Custom Analysis Module
```bash
# Create custom module: scripts/lib/custom-analyzer.sh
cat > scripts/lib/custom-analyzer.sh << 'EOF'
#!/bin/bash
# Custom Analysis Module

# Source dependencies
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/common.sh"

# Custom analysis function
analyze_custom_metrics() {
    log_header "Running custom analysis..."
    
    # Your custom analysis logic here
    local custom_data
    custom_data=$(gh api repos/:owner/:repo/stats/contributors)
    
    echo "$custom_data" | jq -r '.[] | "Contributor: \(.author.login), Commits: \(.total)"'
}

# Export functions
export -f analyze_custom_metrics
EOF

# Use custom module in main script
source scripts/lib/custom-analyzer.sh
analyze_custom_metrics
```

#### Custom Benchmark
```bash
# Add custom benchmark to benchmark-performance.sh
cat >> scripts/benchmark-performance.sh << 'EOF'

# Custom benchmark function
benchmark_custom_operation() {
    log_header "Running custom operation benchmark..."
    
    run_performance_benchmark "custom_operation" "
        # Your custom operation here
        echo 'Custom benchmark operation'
        sleep 0.1
    "
}
EOF
```

### Integration with External Tools

#### Prometheus Metrics Export
```bash
# Export metrics to Prometheus format
cat > export-prometheus-metrics.sh << 'EOF'
#!/bin/bash

# Run analysis and extract metrics
./scripts/analyze-performance.sh --format json --output metrics.json

# Convert to Prometheus format
cat metrics.json | jq -r '
  "# HELP github_api_usage_percent GitHub API usage percentage",
  "# TYPE github_api_usage_percent gauge",
  "github_api_usage_percent \(.api_usage.usage_percent // 0)",
  "",
  "# HELP workflow_count Total number of workflows",  
  "# TYPE workflow_count gauge",
  "workflow_count \(.workflows.total_count // 0)"
' > metrics.prom

echo "Prometheus metrics exported to metrics.prom"
EOF

chmod +x export-prometheus-metrics.sh
./export-prometheus-metrics.sh
```

#### Integration with InfluxDB
```bash
# Send metrics to InfluxDB
cat > send-to-influxdb.sh << 'EOF'
#!/bin/bash

INFLUX_URL="http://localhost:8086"
INFLUX_DB="performance_metrics"

# Run analysis
./scripts/analyze-performance.sh --format json --output metrics.json

# Extract metrics
API_USAGE=$(cat metrics.json | jq -r '.api_usage.usage_percent // 0')
WORKFLOW_COUNT=$(cat metrics.json | jq -r '.workflows.total_count // 0')
TIMESTAMP=$(date +%s)

# Send to InfluxDB
curl -i -XPOST "${INFLUX_URL}/write?db=${INFLUX_DB}" --data-binary "
github_api_usage,host=$(hostname) value=${API_USAGE} ${TIMESTAMP}000000000
workflow_count,host=$(hostname) value=${WORKFLOW_COUNT} ${TIMESTAMP}000000000
"
EOF
```

### Custom Reporting

#### HTML Report Generation
```bash
# Generate HTML report
cat > generate-html-report.sh << 'EOF'
#!/bin/bash

# Run analysis
./scripts/analyze-performance.sh --format json --output report-data.json

# Generate HTML
cat > performance-report.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>Performance Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .metric { background: #f5f5f5; padding: 10px; margin: 10px 0; border-radius: 5px; }
        .good { border-left: 5px solid green; }
        .warning { border-left: 5px solid orange; }
        .critical { border-left: 5px solid red; }
    </style>
</head>
<body>
    <h1>GitHub Actions Performance Report</h1>
    <div id="report-content"></div>
    
    <script>
        // Load and display report data
        fetch('report-data.json')
            .then(response => response.json())
            .then(data => {
                const content = document.getElementById('report-content');
                
                // API Usage
                const apiUsage = data.api_usage?.usage_percent || 0;
                const apiClass = apiUsage > 80 ? 'critical' : apiUsage > 60 ? 'warning' : 'good';
                
                content.innerHTML += `
                    <div class="metric ${apiClass}">
                        <h3>GitHub API Usage</h3>
                        <p>Current usage: ${apiUsage}%</p>
                    </div>
                `;
                
                // Workflow Count
                const workflowCount = data.workflows?.total_count || 0;
                content.innerHTML += `
                    <div class="metric good">
                        <h3>Workflows</h3>
                        <p>Total workflows: ${workflowCount}</p>
                    </div>
                `;
            });
    </script>
</body>
</html>
HTML

echo "HTML report generated: performance-report.html"
EOF
```

### Scheduled Monitoring

#### Cron-based Monitoring
```bash
# Add to crontab for automated monitoring
# crontab -e

# Daily performance analysis at 9 AM
0 9 * * * cd /path/to/repo && ./scripts/analyze-performance.sh --format json --output daily-$(date +\%Y\%m\%d).json

# Weekly comprehensive analysis on Mondays at 6 AM  
0 6 * * 1 cd /path/to/repo && ./scripts/analyze-performance.sh --benchmarks --load-tests --format markdown --output weekly-report-$(date +\%Y\%m\%d).md

# Hourly API usage check
0 * * * * cd /path/to/repo && ./scripts/analyze-performance.sh | grep "High API usage" && echo "ALERT: High API usage" | mail -s "GitHub API Alert" admin@company.com
```

### Performance Regression Detection

#### Automated Regression Testing
```bash
# regression-test.sh - Detect performance regressions
cat > regression-test.sh << 'EOF'
#!/bin/bash

BASELINE_FILE="performance-baseline.json"
CURRENT_FILE="performance-current.json"
THRESHOLD=20  # 20% regression threshold

# Run current performance analysis
./scripts/benchmark-performance.sh > /dev/null 2>&1
cp /tmp/performance-benchmarks/benchmark-report-*.json "$CURRENT_FILE"

# Check if baseline exists
if [[ ! -f "$BASELINE_FILE" ]]; then
    echo "No baseline found, creating baseline..."
    cp "$CURRENT_FILE" "$BASELINE_FILE"
    exit 0
fi

# Compare performance
check_regression() {
    local metric="$1"
    local baseline current regression
    
    baseline=$(cat "$BASELINE_FILE" | jq -r ".$metric // 0")
    current=$(cat "$CURRENT_FILE" | jq -r ".$metric // 0")
    
    if [[ $(echo "$baseline > 0" | bc -l) -eq 1 ]]; then
        regression=$(echo "scale=1; ($current - $baseline) * 100 / $baseline" | bc -l)
        
        if [[ $(echo "$regression > $THRESHOLD" | bc -l) -eq 1 ]]; then
            echo "⚠️  Regression detected in $metric: ${regression}% slower"
            return 1
        fi
    fi
    return 0
}

# Check various metrics
REGRESSION_FOUND=0

check_regression "benchmark_report.performance_metrics.api_calls_total" || REGRESSION_FOUND=1
check_regression "benchmark_report.performance_metrics.cache_hit_rate_percent" || REGRESSION_FOUND=1

if [[ $REGRESSION_FOUND -eq 1 ]]; then
    echo "❌ Performance regression detected!"
    exit 1
else
    echo "✅ No significant performance regression"
    exit 0
fi
EOF

chmod +x regression-test.sh
```

## 🔧 Configuration Examples

### Using Different Configuration Files

#### Development Configuration
```bash
# Create development-specific configuration
cat > config/development.conf << 'EOF'
# Development Configuration
MAX_PARALLEL_JOBS=2
CACHE_TTL=300
LOG_LEVEL=DEBUG
ENABLE_BENCHMARKS=true
COLORED_OUTPUT=true
OUTPUT_FORMAT=console
EOF

# Use development configuration
CONFIG_FILE="config/development.conf" ./scripts/analyze-performance.sh
```

#### Production Configuration
```bash
# Create production-optimized configuration  
cat > config/production.conf << 'EOF'
# Production Configuration
MAX_PARALLEL_JOBS=8
CACHE_TTL=3600
LOG_LEVEL=WARN
ENABLE_BENCHMARKS=false
COLORED_OUTPUT=false
OUTPUT_FORMAT=json
RATE_LIMIT_REQUESTS_PER_MINUTE=15
DEFAULT_KEEP_DAYS=90
EOF

# Use production configuration
CONFIG_FILE="config/production.conf" ./scripts/analyze-performance.sh --output prod-report.json
```

#### Environment Variable Overrides
```bash
# Override specific settings via environment variables
export MAX_PARALLEL_JOBS=16
export LOG_LEVEL=DEBUG
export ENABLE_BENCHMARKS=true

# Run with overrides
./scripts/analyze-performance.sh

# Temporary override for single execution
CACHE_TTL=300 LOG_LEVEL=DEBUG ./scripts/analyze-performance.sh
```

### Dynamic Configuration Examples

#### Auto-Optimized Configuration
```bash
# Create adaptive configuration script
cat > scripts/auto-optimize-config.sh << 'EOF'
#!/bin/bash

# Auto-detect optimal settings
CPU_CORES=$(nproc)
MEMORY_GB=$(($(free -m | awk 'NR==2{print $2}') / 1024))

# Set parallel jobs based on CPU cores
if [[ $CPU_CORES -ge 8 ]]; then
    export MAX_PARALLEL_JOBS=8
elif [[ $CPU_CORES -ge 4 ]]; then
    export MAX_PARALLEL_JOBS=4
else
    export MAX_PARALLEL_JOBS=2
fi

# Set cache TTL based on available memory
if [[ $MEMORY_GB -ge 8 ]]; then
    export CACHE_TTL=3600
elif [[ $MEMORY_GB -ge 4 ]]; then
    export CACHE_TTL=1800
else
    export CACHE_TTL=900
fi

echo "Auto-optimized configuration:"
echo "  CPU cores: $CPU_CORES → MAX_PARALLEL_JOBS: $MAX_PARALLEL_JOBS"
echo "  Memory: ${MEMORY_GB}GB → CACHE_TTL: $CACHE_TTL"

# Run analysis with optimized settings
./scripts/analyze-performance.sh "$@"
EOF

chmod +x scripts/auto-optimize-config.sh

# Use auto-optimized configuration
./scripts/auto-optimize-config.sh --benchmarks
```

#### Environment-Specific Configuration Loading
```bash
# Create environment detection script
detect_and_run() {
    local config_file
    
    if [[ "${CI:-false}" == "true" ]]; then
        config_file="config/ci.conf"
        echo "Detected CI environment, using: $config_file"
    elif [[ "${NODE_ENV:-}" == "production" ]]; then
        config_file="config/production.conf"
        echo "Detected production environment, using: $config_file"
    else
        config_file="config/development.conf"
        echo "Using development environment: $config_file"
    fi
    
    CONFIG_FILE="$config_file" ./scripts/analyze-performance.sh "$@"
}

# Use environment detection
detect_and_run --format json --output environment-report.json
```

## 🔄 Workflow Integration Examples

### GitHub Actions Integration

#### Scheduled Performance Monitoring
```yaml
# .github/workflows/performance-monitoring.yml
name: Performance Monitoring

on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours
  workflow_dispatch:

jobs:
  performance-analysis:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        
      - name: Setup configuration
        run: |
          # Create CI-optimized configuration
          cat > config/ci-monitoring.conf << 'EOF'
          MAX_PARALLEL_JOBS=4
          CACHE_TTL=1800
          LOG_LEVEL=INFO
          OUTPUT_FORMAT=json
          ENABLE_BENCHMARKS=false
          COLORED_OUTPUT=false
          EOF
          
      - name: Run performance analysis
        run: |
          CONFIG_FILE="config/ci-monitoring.conf" \
          ./scripts/analyze-performance.sh \
            --format json \
            --output performance-report.json
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          
      - name: Process results
        run: |
          # Extract key metrics
          API_USAGE=$(jq -r '.api_usage.usage_percent // 0' performance-report.json)
          
          if (( $(echo "$API_USAGE > 80" | bc -l) )); then
            echo "::warning::High API usage detected: $API_USAGE%"
          fi
          
      - name: Upload performance report
        uses: actions/upload-artifact@v3
        with:
          name: performance-report-${{ github.run_id }}
          path: performance-report.json
```

#### PR Performance Validation
```yaml
# .github/workflows/pr-performance-check.yml
name: PR Performance Check

on:
  pull_request:
    paths:
      - 'scripts/**'
      - '.github/workflows/**'

jobs:
  performance-validation:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout PR
        uses: actions/checkout@v4
        
      - name: Run performance benchmarks
        run: |
          # Use development configuration for PR testing
          export MAX_PARALLEL_JOBS=2
          export CACHE_TTL=300
          export LOG_LEVEL=INFO
          export ENABLE_BENCHMARKS=true
          
          ./scripts/benchmark-performance.sh > pr-benchmark-results.txt
          
      - name: Compare with baseline
        run: |
          # Create simple performance comparison
          if grep -q "Performance regression detected" pr-benchmark-results.txt; then
            echo "::error::Performance regression detected in PR"
            cat pr-benchmark-results.txt
            exit 1
          else
            echo "✅ No performance regressions detected"
          fi
          
      - name: Comment PR with results
        uses: actions/github-script@v6
        with:
          script: |
            const fs = require('fs');
            const results = fs.readFileSync('pr-benchmark-results.txt', 'utf8');
            
            const body = `## Performance Benchmark Results
            
            \`\`\`
            ${results}
            \`\`\`
            
            Generated by Performance Testing Framework
            `;
            
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: body
            });
```

### Pre-commit Hook Integration

#### Performance Validation Pre-commit Hook
```bash
# Create .git/hooks/pre-commit
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash

echo "Running performance validation before commit..."

# Quick performance check with minimal configuration
export MAX_PARALLEL_JOBS=2
export CACHE_TTL=300
export LOG_LEVEL=WARN
export ENABLE_BENCHMARKS=false

# Run quick analysis
if ! ./scripts/analyze-performance.sh > /dev/null 2>&1; then
    echo "❌ Performance analysis failed. Please check your changes."
    exit 1
fi

# Validate configuration if config files changed
if git diff --cached --name-only | grep -q "config/\|scripts/config/"; then
    echo "Configuration files changed, validating..."
    if ! ./scripts/validate-config.sh; then
        echo "❌ Configuration validation failed."
        exit 1
    fi
fi

echo "✅ Performance validation passed"
EOF

chmod +x .git/hooks/pre-commit
```

## 📊 Monitoring and Alerting Examples

### Slack Integration
```bash
# Create Slack notification script
cat > scripts/notify-slack.sh << 'EOF'
#!/bin/bash

WEBHOOK_URL="${SLACK_WEBHOOK_URL}"
REPORT_FILE="$1"

if [[ -z "$WEBHOOK_URL" || -z "$REPORT_FILE" ]]; then
    echo "Usage: $0 <report-file>"
    echo "Set SLACK_WEBHOOK_URL environment variable"
    exit 1
fi

# Extract key metrics
API_USAGE=$(jq -r '.api_usage.usage_percent // 0' "$REPORT_FILE")
WORKFLOWS_COUNT=$(jq -r '.workflows.total_count // 0' "$REPORT_FILE")

# Create alert message
MESSAGE="Performance Report:
• API Usage: ${API_USAGE}%
• Workflows: ${WORKFLOWS_COUNT}
• Generated: $(date)"

# Add warning if high usage
if (( $(echo "$API_USAGE > 80" | bc -l) )); then
    MESSAGE="🚨 HIGH API USAGE ALERT!\n$MESSAGE"
fi

# Send to Slack
curl -X POST -H 'Content-type: application/json' \
    --data "{\"text\":\"$MESSAGE\"}" \
    "$WEBHOOK_URL"
EOF

chmod +x scripts/notify-slack.sh

# Use Slack notifications
./scripts/analyze-performance.sh --format json --output daily-report.json
./scripts/notify-slack.sh daily-report.json
```

### Email Alerts
```bash
# Create email notification script
cat > scripts/email-alert.sh << 'EOF'
#!/bin/bash

EMAIL_TO="${ALERT_EMAIL:-admin@company.com}"
REPORT_FILE="$1"

if [[ -z "$REPORT_FILE" ]]; then
    echo "Usage: $0 <report-file>"
    exit 1
fi

# Extract metrics
API_USAGE=$(jq -r '.api_usage.usage_percent // 0' "$REPORT_FILE")

# Send email if high usage
if (( $(echo "$API_USAGE > 80" | bc -l) )); then
    {
        echo "Subject: GitHub API Usage Alert - ${API_USAGE}%"
        echo "From: monitoring@company.com"
        echo
        echo "High GitHub API usage detected: ${API_USAGE}%"
        echo
        echo "Full report:"
        jq '.' "$REPORT_FILE"
    } | sendmail "$EMAIL_TO"
fi
EOF

chmod +x scripts/email-alert.sh

# Use email alerts
./scripts/analyze-performance.sh --format json --output hourly-report.json
./scripts/email-alert.sh hourly-report.json
```

## 🏗️ Custom Workflow Examples

### Multi-Repository Analysis
```bash
# Create multi-repo analysis script
cat > scripts/analyze-multiple-repos.sh << 'EOF'
#!/bin/bash

REPOSITORIES=(
    "org/repo1"
    "org/repo2"
    "org/repo3"
)

RESULTS_DIR="multi-repo-analysis-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULTS_DIR"

# Configure for multi-repo analysis
export MAX_PARALLEL_JOBS=2  # Conservative for multiple repos
export CACHE_TTL=3600       # Longer cache for batch processing
export LOG_LEVEL=INFO
export OUTPUT_FORMAT=json

for repo in "${REPOSITORIES[@]}"; do
    echo "Analyzing repository: $repo"
    
    # Set repository context
    export GITHUB_REPOSITORY="$repo"
    
    # Run analysis for this repository
    ./scripts/analyze-performance.sh \
        --output "$RESULTS_DIR/${repo//\//-}-report.json"
done

# Generate combined report
echo "Generating combined report..."
jq -s '.' "$RESULTS_DIR"/*.json > "$RESULTS_DIR/combined-report.json"

echo "Multi-repository analysis complete: $RESULTS_DIR/"
EOF

chmod +x scripts/analyze-multiple-repos.sh

# Run multi-repo analysis
./scripts/analyze-multiple-repos.sh
```

### Continuous Performance Testing
```bash
# Create continuous testing script
cat > scripts/continuous-performance-test.sh << 'EOF'
#!/bin/bash

INTERVAL_MINUTES=${1:-60}  # Default: every hour
TEST_DURATION_HOURS=${2:-24}  # Default: run for 24 hours

echo "Starting continuous performance testing..."
echo "Interval: $INTERVAL_MINUTES minutes"
echo "Duration: $TEST_DURATION_HOURS hours"

RESULTS_DIR="continuous-test-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULTS_DIR"

# Configure for continuous testing
export MAX_PARALLEL_JOBS=2
export CACHE_TTL=1800
export LOG_LEVEL=WARN
export OUTPUT_FORMAT=json

# Calculate end time
END_TIME=$(($(date +%s) + (TEST_DURATION_HOURS * 3600)))

while [[ $(date +%s) -lt $END_TIME ]]; do
    TIMESTAMP=$(date -Iseconds)
    echo "[$TIMESTAMP] Running performance test..."
    
    # Run analysis
    ./scripts/analyze-performance.sh \
        --benchmarks \
        --output "$RESULTS_DIR/test-$TIMESTAMP.json"
    
    # Check for performance issues
    API_USAGE=$(jq -r '.api_usage.usage_percent // 0' "$RESULTS_DIR/test-$TIMESTAMP.json")
    
    if (( $(echo "$API_USAGE > 90" | bc -l) )); then
        echo "[$TIMESTAMP] ALERT: Critical API usage: $API_USAGE%"
    fi
    
    # Wait for next interval
    sleep $((INTERVAL_MINUTES * 60))
done

echo "Continuous testing completed. Results in: $RESULTS_DIR/"
EOF

chmod +x scripts/continuous-performance-test.sh

# Run continuous testing (every 30 minutes for 12 hours)
./scripts/continuous-performance-test.sh 30 12
```

### Custom Report Generation
```bash
# Create custom report generator
cat > scripts/generate-custom-report.sh << 'EOF'
#!/bin/bash

REPORT_TYPE="${1:-daily}"
OUTPUT_FILE="${2:-custom-report.html}"

echo "Generating custom $REPORT_TYPE report..."

# Run analysis with appropriate configuration
case "$REPORT_TYPE" in
    daily)
        export CACHE_TTL=1800
        export WORKFLOW_ANALYSIS_LIMIT=50
        ;;
    weekly)
        export CACHE_TTL=3600
        export WORKFLOW_ANALYSIS_LIMIT=200
        ;;
    monthly)
        export CACHE_TTL=7200
        export WORKFLOW_ANALYSIS_LIMIT=500
        ;;
esac

# Generate data
./scripts/analyze-performance.sh --format json --output temp-data.json

# Create HTML report
cat > "$OUTPUT_FILE" << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>Performance Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .metric { background: #f8f9fa; padding: 15px; margin: 10px 0; border-radius: 8px; }
        .good { border-left: 5px solid #28a745; }
        .warning { border-left: 5px solid #ffc107; }
        .danger { border-left: 5px solid #dc3545; }
        .chart { width: 100%; height: 300px; margin: 20px 0; }
    </style>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
    <h1>Performance Report - REPORT_TYPE</h1>
    <div id="content"></div>
    
    <script>
        fetch('temp-data.json')
            .then(response => response.json())
            .then(data => {
                const content = document.getElementById('content');
                
                // API Usage metric
                const apiUsage = data.api_usage?.usage_percent || 0;
                const apiClass = apiUsage > 80 ? 'danger' : apiUsage > 60 ? 'warning' : 'good';
                
                content.innerHTML += `
                    <div class="metric ${apiClass}">
                        <h3>GitHub API Usage</h3>
                        <p><strong>${apiUsage}%</strong> of rate limit used</p>
                        <p>Remaining: ${data.api_usage?.remaining || 0} requests</p>
                    </div>
                `;
                
                // Workflow metrics
                content.innerHTML += `
                    <div class="metric good">
                        <h3>Workflow Analysis</h3>
                        <p><strong>${data.workflows?.total_count || 0}</strong> workflows analyzed</p>
                        <p>Generated: ${new Date().toLocaleString()}</p>
                    </div>
                `;
            });
    </script>
</body>
</html>
HTML

# Replace template variables
sed -i "s/REPORT_TYPE/$REPORT_TYPE/g" "$OUTPUT_FILE"

echo "Custom report generated: $OUTPUT_FILE"
EOF

chmod +x scripts/generate-custom-report.sh

# Generate different types of reports
./scripts/generate-custom-report.sh daily daily-report.html
./scripts/generate-custom-report.sh weekly weekly-report.html
```

This comprehensive set of examples should help users understand how to effectively use the performance testing framework in various scenarios, from basic usage to advanced integrations.

## 📚 Additional Resources

### Configuration Examples Repository
For more configuration examples and templates, see:
- `config/` directory for sample configurations
- [Configuration Guide](CONFIGURATION.md) for detailed configuration options
- [Performance Tuning Guide](PERFORMANCE_TUNING.md) for optimization strategies

### Integration Patterns
- **CI/CD Integration**: See examples above for GitHub Actions integration
- **Monitoring Integration**: Slack, email, and custom alerting examples
- **Multi-repository Analysis**: Batch processing across multiple repositories
- **Custom Reporting**: HTML, JSON, and dashboard integration examples

### Best Practices
- Use environment-specific configurations
- Implement proper error handling and alerting  
- Monitor API usage to avoid rate limiting
- Regular performance regression testing
- Automated configuration validation

---

*For more examples and advanced usage patterns, see the [Performance Testing Documentation](PERFORMANCE_TESTING.md), [Architecture Overview](ARCHITECTURE.md), and [Configuration Guide](CONFIGURATION.md).*