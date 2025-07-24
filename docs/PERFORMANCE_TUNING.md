# Performance Tuning Guide

This comprehensive guide provides detailed instructions for optimizing the performance of Claude Code Auto Workflows, including configuration tuning, resource optimization, and troubleshooting performance issues.

## Table of Contents

- [Quick Performance Checklist](#quick-performance-checklist)
- [Configuration Tuning](#configuration-tuning)
- [Resource Optimization](#resource-optimization)
- [Caching Strategies](#caching-strategies)
- [Rate Limit Management](#rate-limit-management)
- [Parallel Processing Optimization](#parallel-processing-optimization)
- [Workflow Optimization](#workflow-optimization)
- [Monitoring and Profiling](#monitoring-and-profiling)
- [Troubleshooting Performance Issues](#troubleshooting-performance-issues)
- [Advanced Optimization Techniques](#advanced-optimization-techniques)

## Performance Optimization Flowchart

Use this flowchart to systematically identify and resolve performance issues:

```mermaid
flowchart TD
    START([Performance Issue Detected]) --> IDENTIFY{Identify Issue Type}
    
    IDENTIFY -->|High API Usage| API_CHECK{Check API Rate Limits}
    IDENTIFY -->|Slow Execution| EXECUTION_CHECK{Check System Resources}
    IDENTIFY -->|Memory Issues| MEMORY_CHECK{Check Memory Usage}
    IDENTIFY -->|Cache Issues| CACHE_CHECK{Check Cache Performance}
    
    %% API Usage Path
    API_CHECK -->|Rate Limited| API_SOLUTIONS[**⏱️ 15-30 minutes | ✅ 85% success rate**<br/><br/>Increase Cache TTL<br/>Use GitHub App Token<br/>Reduce Request Rate<br/><br/>**Example**: "Error: API rate limit exceeded (5000/5000)"<br/>→ Using PAT with 5000/hour limit<br/>→ Solution: Switch to GitHub App token (15,000/hour)<br/><br/>**Example**: 2GB RAM system hitting rate limits frequently<br/>→ Short CACHE_TTL=300 causing excessive API calls<br/>→ Solution: Increase CACHE_TTL=1800 for better caching]
    API_CHECK -->|High Usage| API_OPTIMIZE[**⏱️ 30-60 minutes | ⚠️ 70% success rate**<br/><br/>Enable Request Batching<br/>Optimize API Calls<br/>Implement Intelligent Scheduling<br/><br/>**Example**: 3000+ API calls for 50 workflow runs<br/>→ Making individual calls for each workflow detail<br/>→ Solution: Use GraphQL to batch workflow queries<br/><br/>**Example**: Peak usage times causing failures<br/>→ Multiple repositories using same token during CI<br/>→ Solution: Stagger cron schedules (0 7 * * * vs 0 */6 * * *)]
    
    %% Execution Performance Path
    EXECUTION_CHECK -->|High CPU| CPU_OPTIMIZE[**⏱️ 10-20 minutes | ✅ 90% success rate**<br/><br/>Adjust Parallel Jobs<br/>Optimize Process Affinity<br/>Use Process Priority<br/><br/>**Example**: 100% CPU usage on 4-core system<br/>→ MAX_PARALLEL_JOBS=16 causing excessive context switching<br/>→ Solution: Set MAX_PARALLEL_JOBS=4 to match CPU cores<br/><br/>**Example**: System becomes unresponsive during analysis<br/>→ Analysis process competing with other services<br/>→ Solution: Use nice -n 10 to lower process priority]
    EXECUTION_CHECK -->|High I/O Wait| IO_OPTIMIZE[**⏱️ 20-45 minutes | ⚠️ 75% success rate**<br/><br/>Use Faster Storage<br/>Optimize Cache Location<br/>Clean Temp Files<br/><br/>**Example**: Analysis takes 20+ minutes with high iowait<br/>→ Cache directory on slow HDD with frequent writes<br/>→ Solution: Move cache to SSD or RAM disk (/dev/shm)<br/><br/>**Example**: Disk space errors during large analysis<br/>→ /tmp filling up with 2GB+ of temporary files<br/>→ Solution: Clean old files: find /tmp -name "*.tmp.*" -mmin +60 -delete]
    EXECUTION_CHECK -->|Network Latency| NETWORK_OPTIMIZE[**⏱️ 15-35 minutes | ⚠️ 80% success rate**<br/><br/>Increase Cache TTL<br/>Use Local Mirror<br/>Batch Network Requests<br/><br/>**Example**: API calls taking 2+ seconds each<br/>→ High latency connection to GitHub API<br/>→ Solution: Increase CACHE_TTL=3600 to reduce API frequency<br/><br/>**Example**: Timeouts in corporate network<br/>→ Firewall/proxy adding latency to GitHub API<br/>→ Solution: Configure proxy settings or use GitHub Enterprise]
    
    %% Memory Issues Path
    MEMORY_CHECK -->|Out of Memory| MEMORY_SOLUTIONS[**⏱️ 10-25 minutes | ✅ 85% success rate**<br/><br/>Reduce Parallel Jobs<br/>Use Streaming Processing<br/>Clean Temp Files<br/><br/>**Example**: "Killed" message with 4GB system<br/>→ MAX_PARALLEL_JOBS=8 consuming 6GB+ RAM<br/>→ Solution: Reduce to MAX_PARALLEL_JOBS=2<br/><br/>**Example**: GitHub Actions runner out of memory<br/>→ Processing 1000+ workflow runs simultaneously<br/>→ Solution: Set WORKFLOW_ANALYSIS_LIMIT=25 to process in batches]
    MEMORY_CHECK -->|Memory Leaks| MEMORY_DEBUG[**⏱️ 30-90 minutes | ❌ 50% success rate**<br/><br/>Run Memory Profiling<br/>Check for Resource Leaks<br/>Implement Cleanup Functions<br/><br/>**Example**: Memory usage grows from 500MB to 4GB<br/>→ Cache files not being cleaned up properly<br/>→ Solution: Implement proper cache cleanup with TTL enforcement<br/><br/>**Example**: Processes not terminating after script ends<br/>→ Background processes left running consuming memory<br/>→ Solution: Add proper signal handling and cleanup traps]
    
    %% Cache Performance Path
    CACHE_CHECK -->|Low Hit Rate| CACHE_IMPROVE[**⏱️ 25-45 minutes | ⚠️ 65% success rate**<br/><br/>Optimize Cache Keys<br/>Pre-warm Cache<br/>Adjust Cache Strategy<br/><br/>**Example**: Cache hit rate < 30% on repeated runs<br/>→ Cache keys include timestamps causing misses<br/>→ Solution: Use stable parameters for cache key generation<br/><br/>**Example**: Fresh repository analysis always misses cache<br/>→ No pre-warming for common GitHub API endpoints<br/>→ Solution: Run pre-warm script before main analysis]
    CACHE_CHECK -->|Cache Corruption| CACHE_FIX[**⏱️ 10-25 minutes | ✅ 80% success rate**<br/><br/>Clear Cache Directory<br/>Fix Atomic Operations<br/>Check Permissions<br/><br/>**Example**: "Invalid JSON" errors from cache reads<br/>→ Parallel processes corrupting cache files<br/>→ Solution: Implement atomic writes with temporary files<br/><br/>**Example**: Cache files owned by root, script runs as user<br/>→ Permission denied errors when accessing cache<br/>→ Solution: chown -R $USER:$USER /tmp/github-api-cache]
    
    %% Solution Validation
    API_SOLUTIONS --> VALIDATE{Test Performance}
    API_OPTIMIZE --> VALIDATE
    CPU_OPTIMIZE --> VALIDATE
    IO_OPTIMIZE --> VALIDATE
    NETWORK_OPTIMIZE --> VALIDATE
    MEMORY_SOLUTIONS --> VALIDATE
    MEMORY_DEBUG --> VALIDATE
    CACHE_IMPROVE --> VALIDATE
    CACHE_FIX --> VALIDATE
    
    VALIDATE -->|Improved| SUCCESS([Performance Optimized ✅])
    VALIDATE -->|Still Issues| ADVANCED[Apply Advanced Techniques<br/>Custom Cache Implementation<br/>Auto-tuning Scripts]
    ADVANCED --> VALIDATE
    
    %% Styling
    style START fill:#e1f5fe
    style SUCCESS fill:#e8f5e8
    style IDENTIFY fill:#fff3e0
    style VALIDATE fill:#f3e5f5
    style ADVANCED fill:#ffebee
```

## Quick Performance Checklist

### Immediate Optimizations (5 minutes)
- [ ] **Enable caching**: Set `ENABLE_CACHE=true` in configuration
- [ ] **Optimize parallel jobs**: Set `MAX_PARALLEL_JOBS` to CPU count
- [ ] **Check API rate limits**: Monitor current usage with `gh api rate_limit`
- [ ] **Enable performance benchmarks**: Set `ENABLE_BENCHMARKS=true`

### Short-term Optimizations (30 minutes)
- [ ] **Review cache TTL settings**: Adjust `CACHE_TTL` based on data freshness needs
- [ ] **Configure rate limiting**: Set appropriate `RATE_LIMIT_REQUESTS_PER_MINUTE`
- [ ] **Optimize workflow triggers**: Review GitHub Actions workflow frequency
- [ ] **Clean up old data**: Run `./scripts/cleanup-old-runs.sh`

### Long-term Optimizations (1-2 hours)
- [ ] **Implement GitHub App authentication**: Higher rate limits vs PAT
- [ ] **Set up monitoring dashboards**: Automated performance tracking
- [ ] **Configure custom cache strategies**: Optimize for your specific usage patterns
- [ ] **Implement performance regression testing**: Automated performance validation

## Configuration Tuning

### Core Configuration Options

All configuration options are defined in `scripts/config/default.conf` and can be overridden by environment variables.

#### Parallel Processing Configuration

```bash
# Optimal settings for different system specifications

# For systems with 2-4 CPU cores
MAX_PARALLEL_JOBS=4
XARGS_PARALLEL_JOBS=4

# For systems with 8+ CPU cores  
MAX_PARALLEL_JOBS=8
XARGS_PARALLEL_JOBS=8

# For systems with limited memory (<4GB)
MAX_PARALLEL_JOBS=2
XARGS_PARALLEL_JOBS=2

# For high-performance systems with 16+ cores
MAX_PARALLEL_JOBS=16
XARGS_PARALLEL_JOBS=16
```

**Performance Impact:**
- **Too low**: Underutilizes system resources, slower execution
- **Too high**: Resource contention, increased context switching overhead
- **Sweet spot**: Usually 1-2x CPU core count

#### Cache Configuration

```bash
# Cache Time-To-Live (TTL) settings
CACHE_TTL=1800              # 30 minutes (default)
CACHE_CLEANUP_INTERVAL=3600 # 1 hour cleanup

# Performance vs. freshness trade-offs:

# High-frequency analysis (development)
CACHE_TTL=300               # 5 minutes - fresher data, more API calls

# Production monitoring
CACHE_TTL=3600              # 1 hour - better performance, less API usage

# Batch processing
CACHE_TTL=7200              # 2 hours - maximum performance
```

**Tuning Guidelines:**
- **Development environments**: Shorter TTL (5-15 minutes) for fresh data
- **Production monitoring**: Longer TTL (30-60 minutes) for efficiency
- **Batch processing**: Longest TTL (1-2 hours) for maximum performance

#### Rate Limiting Configuration

```bash
# GitHub API rate limiting
RATE_LIMIT_REQUESTS_PER_MINUTE=30  # Conservative default
RATE_LIMIT_DELAY=2                 # Seconds between requests
BURST_SIZE=5                       # Burst allowance

# Aggressive settings (with GitHub App token)
RATE_LIMIT_REQUESTS_PER_MINUTE=100
RATE_LIMIT_DELAY=1
BURST_SIZE=10

# Conservative settings (with PAT or shared environment)
RATE_LIMIT_REQUESTS_PER_MINUTE=15
RATE_LIMIT_DELAY=4
BURST_SIZE=3
```

### Environment-Specific Tuning

#### CI/CD Environment
```bash
# Optimized for GitHub Actions runners
export MAX_PARALLEL_JOBS=4
export CACHE_TTL=1800
export ENABLE_BENCHMARKS=false  # Skip benchmarks in CI
export OUTPUT_FORMAT=json       # Structured output for processing
```

#### Development Environment
```bash
# Optimized for local development
export MAX_PARALLEL_JOBS=2
export CACHE_TTL=300
export ENABLE_BENCHMARKS=true
export OUTPUT_FORMAT=console
export COLORED_OUTPUT=true
```

#### Production Monitoring
```bash
# Optimized for production monitoring
export MAX_PARALLEL_JOBS=8
export CACHE_TTL=3600
export ENABLE_LOAD_TESTS=true
export OUTPUT_FORMAT=json
export LOG_LEVEL=WARN  # Reduce log noise
```

## Resource Optimization

### Memory Optimization

#### Cache Size Management
```bash
# Monitor cache usage
du -sh /tmp/github-api-cache
du -sh /tmp/performance-metrics

# Automated cache cleanup (add to cron)
# Clean caches older than 2 hours every hour
0 * * * * find /tmp/github-api-cache -mmin +120 -delete
0 * * * * find /tmp/performance-metrics -mmin +120 -delete
```

#### Memory-Efficient Processing
```bash
# For large repositories, process in batches
export WORKFLOW_ANALYSIS_LIMIT=25  # Reduce from default 50
export MAX_PARALLEL_JOBS=2         # Reduce parallel processing

# Use streaming processing for large datasets
./scripts/analyze-performance.sh --format json | jq -c '.' | \
    while read -r line; do
        # Process each line individually
        echo "$line" >> processed_data.json
    done
```

### Disk I/O Optimization

#### Cache Location Optimization
```bash
# Use faster storage for caches (if available)
export GITHUB_API_CACHE_DIR="/dev/shm/github-api-cache"  # RAM disk
export METRICS_DIR="/dev/shm/performance-metrics"

# Or use SSD for better performance
export GITHUB_API_CACHE_DIR="/fast-ssd/cache/github-api"
```

#### Temporary File Management
```bash
# Clean up temporary files regularly
find /tmp -name "*.tmp.*" -mmin +60 -delete

# Use memory-mapped files for large temporary data
export TMPDIR="/dev/shm"  # Use RAM disk for temporary files
```

### CPU Optimization

#### Process Affinity (Linux)
```bash
# Bind analysis processes to specific CPU cores
# Use taskset to limit CPU core usage
taskset -c 0-3 ./scripts/analyze-performance.sh

# Or set CPU affinity for the entire script
export OMP_NUM_THREADS=4
export PARALLEL_JOBS=4
```

#### Process Priority
```bash
# Run analysis with lower priority to avoid system impact
nice -n 10 ./scripts/analyze-performance.sh

# Or higher priority for critical monitoring
nice -n -5 ./scripts/analyze-performance.sh
```

## Caching Strategies

### Multi-Level Caching

The system implements multiple cache levels for optimal performance:

#### Level 1: API Response Cache
- **TTL**: 5 minutes (github-api.sh)
- **Purpose**: Reduce GitHub API calls
- **Key format**: `api_endpoint_hash`

#### Level 2: Analysis Result Cache  
- **TTL**: 30 minutes (performance-metrics.sh)
- **Purpose**: Cache computed analysis results
- **Key format**: `analysis_type_parameters_hash`

#### Level 3: Report Cache
- **TTL**: 15 minutes (report-generator.sh)
- **Purpose**: Cache generated reports
- **Key format**: `report_format_parameters_hash`

### Cache Optimization Strategies

#### Cache Hit Rate Optimization
```bash
# Monitor cache effectiveness
./scripts/analyze-performance.sh | grep "cache hit rate"

# Optimize cache keys for better hit rates
# Use stable, predictable cache keys
get_optimized_cache_key() {
    local endpoint="$1"
    local params="$2"
    # Sort parameters for consistent keys
    local sorted_params
    sorted_params=$(echo "$params" | tr '&' '\n' | sort | tr '\n' '&')
    echo "api_${endpoint}_${sorted_params}" | sha256sum | cut -d' ' -f1
}
```

#### Cache Warming
```bash
# Pre-warm caches with common queries
./scripts/pre-warm-cache.sh

# Example pre-warming script
pre_warm_common_queries() {
    # Common workflow queries
    gh run list --limit 25 >/dev/null
    gh api repos/:owner/:repo/actions/workflows >/dev/null
    
    # Common repository queries
    gh api repos/:owner/:repo >/dev/null
    gh api rate_limit >/dev/null
}
```

#### Cache Partitioning
```bash
# Partition caches by data type for better organization
export GITHUB_API_CACHE_DIR="/tmp/cache/github-api"
export WORKFLOW_CACHE_DIR="/tmp/cache/workflows"
export METRICS_CACHE_DIR="/tmp/cache/metrics"

# Separate cache cleanup policies
cleanup_api_cache() {
    find "$GITHUB_API_CACHE_DIR" -mmin +5 -delete
}

cleanup_analysis_cache() {
    find "$WORKFLOW_CACHE_DIR" -mmin +30 -delete
}
```

## Rate Limit Management

### GitHub API Rate Limits

#### Understanding Rate Limits
- **Personal Access Token**: 5,000 requests/hour
- **GitHub App**: 15,000 requests/hour  
- **GitHub App Installation**: 15,000 requests/hour per installation

#### Rate Limit Monitoring
```bash
# Check current rate limit status
gh api rate_limit

# Monitor rate limit usage over time
monitor_rate_limits() {
    while true; do
        local rate_info
        rate_info=$(gh api rate_limit)
        local used remaining reset
        used=$(echo "$rate_info" | jq -r '.rate.used')
        remaining=$(echo "$rate_info" | jq -r '.rate.remaining')
        reset=$(echo "$rate_info" | jq -r '.rate.reset')
        
        echo "$(date): Used: $used, Remaining: $remaining, Reset: $(date -d @$reset)"
        sleep 300  # Check every 5 minutes
    done
}
```

#### Rate Limit Optimization Strategies

##### 1. GitHub App Authentication
```bash
# Setup GitHub App for higher rate limits
export GITHUB_TOKEN="your-github-app-token"

# Verify higher limits
gh api rate_limit | jq '.rate.limit'  # Should show 15000
```

##### 2. Request Batching
```bash
# Batch multiple queries into single GraphQL requests
batch_workflow_queries() {
    gh api graphql -f query='
    query {
        repository(owner: "owner", name: "repo") {
            defaultBranchRef {
                target {
                    ... on Commit {
                        checkSuites(first: 10) {
                            nodes {
                                workflowRun {
                                    workflow {
                                        name
                                    }
                                    status
                                    conclusion
                                    createdAt
                                    updatedAt
                                }
                            }
                        }
                    }
                }
            }
        }
    }'
}
```

##### 3. Intelligent Request Scheduling
```bash
# Distribute requests across time
schedule_requests() {
    local requests=("$@")
    local delay=$((3600 / RATE_LIMIT_REQUESTS_PER_MINUTE))
    
    for request in "${requests[@]}"; do
        eval "$request"
        sleep "$delay"
    done
}
```

## Parallel Processing Optimization

### Optimal Parallelism Configuration

#### CPU-Bound Tasks
```bash
# Set parallel jobs to CPU core count
OPTIMAL_JOBS=$(nproc)
export MAX_PARALLEL_JOBS=$OPTIMAL_JOBS

# For CPU-intensive analysis
export XARGS_PARALLEL_JOBS=$OPTIMAL_JOBS
```

#### I/O-Bound Tasks
```bash
# I/O-bound tasks can use more workers
OPTIMAL_JOBS=$(($(nproc) * 2))
export MAX_PARALLEL_JOBS=$OPTIMAL_JOBS

# For network-heavy operations
export GITHUB_API_PARALLEL_JOBS=$OPTIMAL_JOBS
```

#### Memory-Constrained Systems
```bash
# Calculate based on available memory
AVAILABLE_MB=$(free -m | awk 'NR==2{print $7}')
JOBS_PER_GB=2
OPTIMAL_JOBS=$((AVAILABLE_MB / 1024 * JOBS_PER_GB))
export MAX_PARALLEL_JOBS=$OPTIMAL_JOBS
```

### Load Balancing Strategies

#### Work Distribution
```bash
# Distribute work evenly across processes
distribute_work() {
    local files=("$@")
    local num_files=${#files[@]}
    local jobs_per_worker=$((num_files / MAX_PARALLEL_JOBS))
    
    for ((i=0; i<MAX_PARALLEL_JOBS; i++)); do
        local start=$((i * jobs_per_worker))
        local end=$(((i + 1) * jobs_per_worker))
        
        # Process subset in background
        process_file_subset "${files[@]:$start:$((end - start))}" &
    done
    
    wait  # Wait for all background jobs to complete
}
```

#### Dynamic Load Balancing
```bash
# Adjust parallelism based on system load
adjust_parallelism() {
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    
    if (( $(echo "$load_avg > $(nproc)" | bc -l) )); then
        # High load, reduce parallelism
        export MAX_PARALLEL_JOBS=$((MAX_PARALLEL_JOBS / 2))
    elif (( $(echo "$load_avg < $(nproc) / 2" | bc -l) )); then
        # Low load, increase parallelism
        export MAX_PARALLEL_JOBS=$((MAX_PARALLEL_JOBS * 2))
    fi
}
```

## Workflow Optimization

### GitHub Actions Workflow Optimization

#### Caching Strategy for Workflows
```yaml
# Optimize GitHub Actions caching
steps:
  - name: Cache dependencies
    uses: actions/cache@v3
    with:
      path: |
        ~/.npm
        ~/.cache
        node_modules
        scripts/lib/cache
      key: ${{ runner.os }}-deps-${{ hashFiles('**/package-lock.json', 'scripts/**/*.sh') }}
      restore-keys: |
        ${{ runner.os }}-deps-
```

#### Conditional Execution
```yaml
# Skip expensive operations when not needed
steps:
  - name: Performance Analysis
    if: contains(github.event.head_commit.message, '[analyze]') || github.event_name == 'schedule'
    run: ./scripts/analyze-performance.sh --benchmarks
```

#### Matrix Strategy Optimization
```yaml
# Parallel testing across multiple configurations
strategy:
  matrix:
    os: [ubuntu-latest, macos-latest]
    node-version: [18, 20]
    test-suite: [unit, integration, performance]
  fail-fast: false  # Don't cancel other jobs on failure
```

### Workflow Trigger Optimization

#### Intelligent Scheduling
```yaml
# Optimize cron schedules to distribute load
on:
  schedule:
    # Stagger schedules to avoid peak times
    - cron: '7 */6 * * *'  # Every 6 hours at 7 minutes past
    - cron: '23 2 * * 1'   # Weekly on Monday at 2:23 AM
```

#### Event-Based Optimization
```yaml
# Optimize triggers based on actual needs
on:
  push:
    branches: [main]
    paths:
      - 'scripts/**'
      - '.github/workflows/**'
  pull_request:
    types: [opened, synchronize, ready_for_review]
    paths-ignore:
      - 'docs/**'
      - '*.md'
```

## Monitoring and Profiling

### Performance Monitoring Setup

#### Automated Performance Tracking
```bash
# Set up automated performance monitoring
create_monitoring_script() {
    cat > monitor-performance.sh << 'EOF'
#!/bin/bash
TIMESTAMP=$(date -Iseconds)
LOG_FILE="performance-logs/${TIMESTAMP}.json"

# Run performance analysis
./scripts/analyze-performance.sh --format json --output "$LOG_FILE"

# Extract key metrics
API_USAGE=$(jq -r '.api_usage.usage_percent' "$LOG_FILE")
CACHE_HIT_RATE=$(jq -r '.cache.hit_rate_percent' "$LOG_FILE")

# Alert on performance issues
if (( $(echo "$API_USAGE > 80" | bc -l) )); then
    echo "ALERT: High API usage: $API_USAGE%"
fi

if (( $(echo "$CACHE_HIT_RATE < 50" | bc -l) )); then
    echo "ALERT: Low cache hit rate: $CACHE_HIT_RATE%"
fi
EOF
    chmod +x monitor-performance.sh
}
```

#### Performance Dashboard
```bash
# Generate performance dashboard
create_performance_dashboard() {
    cat > dashboard.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Performance Dashboard</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
    <canvas id="apiUsageChart"></canvas>
    <canvas id="cacheHitRateChart"></canvas>
    
    <script>
        // Load performance data and create charts
        fetch('performance-data.json')
            .then(response => response.json())
            .then(data => {
                // Create API usage chart
                new Chart(document.getElementById('apiUsageChart'), {
                    type: 'line',
                    data: {
                        labels: data.timestamps,
                        datasets: [{
                            label: 'API Usage %',
                            data: data.api_usage,
                            borderColor: 'rgb(75, 192, 192)',
                            tension: 0.1
                        }]
                    }
                });
                
                // Create cache hit rate chart
                new Chart(document.getElementById('cacheHitRateChart'), {
                    type: 'line',
                    data: {
                        labels: data.timestamps,
                        datasets: [{
                            label: 'Cache Hit Rate %',
                            data: data.cache_hit_rates,
                            borderColor: 'rgb(255, 99, 132)',
                            tension: 0.1
                        }]
                    }
                });
            });
    </script>
</body>
</html>
EOF
}
```

### Profiling Tools

#### Script Execution Profiling
```bash
# Profile script execution time
profile_script() {
    local script="$1"
    
    echo "Profiling $script..."
    time bash -x "$script" 2>&1 | tee "profile-${script##*/}.log"
    
    # Analyze most time-consuming operations
    grep "^+" "profile-${script##*/}.log" | \
        awk '{print $2}' | sort | uniq -c | sort -nr | head -10
}
```

#### Memory Usage Profiling
```bash
# Monitor memory usage during execution
profile_memory() {
    local script="$1"
    local pid
    
    # Start script in background
    "$script" &
    pid=$!
    
    # Monitor memory usage
    while kill -0 "$pid" 2>/dev/null; do
        ps -p "$pid" -o pid,vsz,rss,pcpu,pmem,time,comm
        sleep 5
    done
}
```

## Troubleshooting Performance Issues

### Performance Troubleshooting Decision Tree

Use this decision tree to systematically diagnose and resolve performance issues:

```mermaid
flowchart TD
    PROBLEM([Performance Issue]) --> SYMPTOMS{What are the symptoms?}
    
    SYMPTOMS -->|Errors/Warnings| ERROR_PATH{Check error type}
    SYMPTOMS -->|Slow Performance| SLOW_PATH{Measure execution time}
    SYMPTOMS -->|High Resource Usage| RESOURCE_PATH{Check system resources}
    SYMPTOMS -->|Inconsistent Results| CONSISTENCY_PATH{Check data consistency}
    
    %% Error Path
    ERROR_PATH -->|Rate Limit 429| RATE_LIMIT[Check: gh api rate_limit<br/>Solution: Increase cache TTL<br/>Use GitHub App token<br/><br/>**Example**: "Rate limit exceeded: 5000/5000 requests used"<br/>→ PAT hitting hourly limit during peak usage<br/>→ Solution: Switch to GitHub App token (15,000/hour limit)<br/><br/>**Example**: Multiple repositories sharing same token<br/>→ Combined usage exceeding rate limit<br/>→ Solution: Create dedicated tokens per repository]
    ERROR_PATH -->|Timeout Errors| TIMEOUT[Check: Network latency<br/>Solution: Increase timeouts<br/>Optimize requests<br/><br/>**Example**: "Request timeout after 30 seconds"<br/>→ Corporate firewall/proxy causing delays<br/>→ Solution: Configure HTTP_PROXY and increase timeout<br/><br/>**Example**: Large repository analysis timing out<br/>→ GitHub API calls for 500+ workflow runs taking too long<br/>→ Solution: Reduce WORKFLOW_ANALYSIS_LIMIT to 50]
    ERROR_PATH -->|Permission Errors| PERMISSION[Check: Token permissions<br/>Solution: Update token scope<br/>Verify repository access<br/><br/>**Example**: "Error 403: Resource not accessible by token"<br/>→ PAT missing 'repo' scope for private repository<br/>→ Solution: Regenerate token with full 'repo' scope<br/><br/>**Example**: "Error 404: Not Found" on valid repository<br/>→ Token doesn't have access to organization repository<br/>→ Solution: Request access or use organization token]
    ERROR_PATH -->|Cache Errors| CACHE_ERROR[Check: Cache directory permissions<br/>Solution: Clear cache<br/>Fix atomic operations<br/><br/>**Example**: "Permission denied: /tmp/github-api-cache"<br/>→ Cache directory created by root, script runs as user<br/>→ Solution: sudo chown -R $USER:$USER /tmp/github-api-cache<br/><br/>**Example**: "Invalid JSON in cache file"<br/>→ Parallel processes writing to same cache file<br/>→ Solution: Implement file locking or reduce parallelism]
    
    %% Performance Path
    SLOW_PATH -->|>5 minutes| VERY_SLOW{Is analysis limit high?}
    SLOW_PATH -->|2-5 minutes| MODERATE_SLOW{Check parallel jobs}
    SLOW_PATH -->|<2 minutes normal| MICRO_OPTIMIZE[Fine-tune cache TTL<br/>Optimize request patterns<br/>Use faster storage]
    
    VERY_SLOW -->|Yes| REDUCE_SCOPE[Reduce WORKFLOW_ANALYSIS_LIMIT<br/>Limit to recent runs<br/>Use sampling]
    VERY_SLOW -->|No| CHECK_BOTTLENECK[Profile with strace<br/>Check API call patterns<br/>Monitor system resources]
    
    MODERATE_SLOW -->|Too few jobs| INCREASE_PARALLEL[Increase MAX_PARALLEL_JOBS<br/>Match CPU core count<br/>Test optimal value]
    MODERATE_SLOW -->|Jobs optimal| CHECK_CACHE_SLOW[Check cache hit rate<br/>Verify cache performance<br/>Optimize cache keys]
    
    %% Resource Path
    RESOURCE_PATH -->|High CPU| CPU_ISSUE[Check: htop, top<br/>Solution: Adjust process priority<br/>Optimize parallel jobs]
    RESOURCE_PATH -->|High Memory| MEMORY_ISSUE[Check: free -h, ps aux<br/>Solution: Reduce parallel jobs<br/>Use streaming processing]
    RESOURCE_PATH -->|High Disk I/O| DISK_ISSUE[Check: iostat, iotop<br/>Solution: Use faster storage<br/>Optimize cache location]
    RESOURCE_PATH -->|High Network| NETWORK_ISSUE[Check: API call frequency<br/>Solution: Batch requests<br/>Increase cache TTL]
    
    %% Consistency Path
    CONSISTENCY_PATH -->|Cache Inconsistency| CACHE_INCONSISTENT[Clear cache directory<br/>Check cache key generation<br/>Verify TTL settings]
    CONSISTENCY_PATH -->|Data Freshness| DATA_FRESH[Adjust cache TTL<br/>Force cache refresh<br/>Check API rate limits]
    CONSISTENCY_PATH -->|Parallel Conflicts| PARALLEL_CONFLICT[Check race conditions<br/>Add proper locking<br/>Reduce parallelism]
    
    %% Validation Steps
    RATE_LIMIT --> VALIDATE_FIX{Test fix}
    TIMEOUT --> VALIDATE_FIX
    PERMISSION --> VALIDATE_FIX
    CACHE_ERROR --> VALIDATE_FIX
    REDUCE_SCOPE --> VALIDATE_FIX
    CHECK_BOTTLENECK --> VALIDATE_FIX
    INCREASE_PARALLEL --> VALIDATE_FIX
    CHECK_CACHE_SLOW --> VALIDATE_FIX
    MICRO_OPTIMIZE --> VALIDATE_FIX
    CPU_ISSUE --> VALIDATE_FIX
    MEMORY_ISSUE --> VALIDATE_FIX
    DISK_ISSUE --> VALIDATE_FIX
    NETWORK_ISSUE --> VALIDATE_FIX
    CACHE_INCONSISTENT --> VALIDATE_FIX
    DATA_FRESH --> VALIDATE_FIX
    PARALLEL_CONFLICT --> VALIDATE_FIX
    
    VALIDATE_FIX -->|Fixed| SUCCESS([Problem Resolved ✅])
    VALIDATE_FIX -->|Still Issues| ESCALATE[Run comprehensive benchmark<br/>Create performance profile<br/>Check advanced optimization]
    ESCALATE --> SYMPTOMS
    
    %% Styling
    style PROBLEM fill:#ffebee
    style SUCCESS fill:#e8f5e8
    style SYMPTOMS fill:#e1f5fe
    style VALIDATE_FIX fill:#f3e5f5
    style ESCALATE fill:#fff3e0
```

### Common Performance Problems

#### 1. High API Usage
**Symptoms:**
- Rate limit warnings in logs
- `429 Too Many Requests` errors
- Slow response times

**Diagnosis:**
```bash
# Check current API usage
gh api rate_limit

# Monitor API calls over time
./scripts/analyze-performance.sh | grep "API Usage"

# Check for inefficient API usage patterns
grep "github_api_call" /tmp/debug.log | sort | uniq -c | sort -nr
```

**Solutions:**
```bash
# Increase cache TTL
export CACHE_TTL=3600

# Reduce request frequency
export RATE_LIMIT_REQUESTS_PER_MINUTE=15

# Use GitHub App token
export GITHUB_TOKEN="your-github-app-token"

# Implement request batching
batch_api_requests() {
    # Group related requests together
    local requests=("$@")
    for request in "${requests[@]}"; do
        eval "$request"
        sleep 2  # Rate limiting delay
    done
}
```

#### 2. Poor Cache Performance
**Symptoms:**
- Low cache hit rates (<50%)
- Frequent API calls for same data
- Slow analysis performance

**Diagnosis:**
```bash
# Check cache statistics
./scripts/analyze-performance.sh | grep -A5 "Cache Performance"

# Monitor cache directory
watch "du -sh /tmp/github-api-cache; ls -la /tmp/github-api-cache | wc -l"

# Check cache key distribution
find /tmp/github-api-cache -type f -exec basename {} \; | \
    cut -c1-8 | sort | uniq -c | sort -nr
```

**Solutions:**
```bash
# Optimize cache keys for consistency
improve_cache_key_generation() {
    # Use normalized, sorted parameters
    local params="$1"
    echo "$params" | tr '&' '\n' | sort | tr '\n' '&' | \
        sha256sum | cut -d' ' -f1
}

# Increase cache TTL for stable data
export CACHE_TTL=1800  # 30 minutes

# Pre-warm cache with common queries
./scripts/pre-warm-cache.sh
```

#### 3. Memory Issues
**Symptoms:**
- Out of memory errors
- System slowdown during analysis
- Process killed by system

**Diagnosis:**
```bash
# Monitor memory usage
free -h
ps aux --sort=-%mem | head -10

# Check for memory leaks
valgrind --tool=memcheck --leak-check=full ./scripts/analyze-performance.sh
```

**Solutions:**
```bash
# Reduce parallel processing
export MAX_PARALLEL_JOBS=2

# Use streaming processing
process_large_datasets() {
    # Process data in chunks instead of loading all at once
    while read -r line; do
        process_line "$line"
    done < large_dataset.json
}

# Clean up temporary files
cleanup_temp_files() {
    find /tmp -name "*.tmp.*" -mmin +30 -delete
}
```

#### 4. Slow Workflow Analysis
**Symptoms:**
- Analysis takes >5 minutes
- Timeout errors
- High CPU usage

**Diagnosis:**
```bash
# Profile analysis performance
time ./scripts/analyze-performance.sh --benchmarks

# Check bottlenecks
strace -c ./scripts/analyze-performance.sh

# Monitor system resources
htop
```

**Solutions:**
```bash
# Limit analysis scope
export WORKFLOW_ANALYSIS_LIMIT=25  # Reduce from 50

# Optimize parallel processing
export MAX_PARALLEL_JOBS=$(nproc)

# Use faster storage for caches
export GITHUB_API_CACHE_DIR="/dev/shm/github-api-cache"
```

### Performance Regression Detection

#### Automated Performance Testing
```bash
# Create performance regression test
create_regression_test() {
    cat > test-performance-regression.sh << 'EOF'
#!/bin/bash

BASELINE_FILE="performance-baseline.json"
CURRENT_FILE="performance-current.json"

# Run performance benchmark
./scripts/benchmark-performance.sh > /dev/null 2>&1
cp /tmp/performance-benchmarks/benchmark-report-*.json "$CURRENT_FILE"

# Compare with baseline
if [[ -f "$BASELINE_FILE" ]]; then
    python3 - << PYTHON
import json
import sys

with open('$BASELINE_FILE') as f:
    baseline = json.load(f)
with open('$CURRENT_FILE') as f:
    current = json.load(f)

# Check for regressions (>20% slower)
threshold = 0.20
regressions = []

for metric in ['api_calls_avg', 'cache_operations_avg']:
    if metric in baseline and metric in current:
        base_time = baseline[metric]
        curr_time = current[metric]
        if curr_time > base_time * (1 + threshold):
            regression = (curr_time - base_time) / base_time * 100
            regressions.append(f"{metric}: {regression:.1f}% slower")

if regressions:
    print("Performance regressions detected:")
    for r in regressions:
        print(f"  - {r}")
    sys.exit(1)
else:
    print("No performance regressions detected")
PYTHON

else
    echo "No baseline found, creating baseline..."
    cp "$CURRENT_FILE" "$BASELINE_FILE"
fi
EOF
    chmod +x test-performance-regression.sh
}
```

## Advanced Optimization Techniques

### Custom Cache Implementations

#### Redis Cache Backend
```bash
# Implement Redis caching for distributed systems
redis_cache_get() {
    local key="$1"
    redis-cli GET "cca:$key" 2>/dev/null || return 1
}

redis_cache_set() {
    local key="$1"
    local value="$2"
    local ttl="$3"
    redis-cli SETEX "cca:$key" "$ttl" "$value" >/dev/null
}

# Override default cache functions
get_from_cache() {
    redis_cache_get "$1"
}

save_to_cache() {
    redis_cache_set "$1" "$2" "${3:-$CACHE_TTL}"
}
```

#### Content-Based Caching
```bash
# Cache based on content hash instead of time
content_based_cache() {
    local content="$1"
    local content_hash
    content_hash=$(echo "$content" | sha256sum | cut -d' ' -f1)
    
    local cache_file="/tmp/content-cache/$content_hash"
    
    if [[ -f "$cache_file" ]]; then
        cat "$cache_file"
        return 0
    fi
    
    # Process content and cache result
    local result
    result=$(process_content "$content")
    
    mkdir -p "$(dirname "$cache_file")"
    echo "$result" > "$cache_file"
    echo "$result"
}
```

### Performance Optimization Automation

#### Auto-Tuning Script
```bash
# Automatically optimize configuration based on system resources
auto_tune_performance() {
    local cpu_cores mem_gb
    cpu_cores=$(nproc)
    mem_gb=$(($(free -m | awk 'NR==2{print $2}') / 1024))
    
    # CPU-based optimization
    if [[ $cpu_cores -ge 8 ]]; then
        export MAX_PARALLEL_JOBS=8
        export XARGS_PARALLEL_JOBS=8
    elif [[ $cpu_cores -ge 4 ]]; then
        export MAX_PARALLEL_JOBS=4
        export XARGS_PARALLEL_JOBS=4
    else
        export MAX_PARALLEL_JOBS=2
        export XARGS_PARALLEL_JOBS=2
    fi
    
    # Memory-based optimization
    if [[ $mem_gb -ge 8 ]]; then
        export CACHE_TTL=3600
        export WORKFLOW_ANALYSIS_LIMIT=100
    elif [[ $mem_gb -ge 4 ]]; then
        export CACHE_TTL=1800
        export WORKFLOW_ANALYSIS_LIMIT=50
    else
        export CACHE_TTL=900
        export WORKFLOW_ANALYSIS_LIMIT=25
    fi
    
    # Network-based optimization
    if command -v curl >/dev/null; then
        local latency
        latency=$(curl -o /dev/null -s -w "%{time_total}" https://api.github.com/rate_limit)
        
        if (( $(echo "$latency > 0.5" | bc -l) )); then
            # High latency, increase cache TTL
            export CACHE_TTL=$((CACHE_TTL * 2))
        fi
    fi
    
    echo "Auto-tuned configuration:"
    echo "  MAX_PARALLEL_JOBS: $MAX_PARALLEL_JOBS"
    echo "  CACHE_TTL: $CACHE_TTL"
    echo "  WORKFLOW_ANALYSIS_LIMIT: $WORKFLOW_ANALYSIS_LIMIT"
}
```

### Performance Testing Framework

#### Comprehensive Performance Suite
```bash
# Run complete performance test suite
run_performance_suite() {
    local results_dir="performance-results-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$results_dir"
    
    echo "Running comprehensive performance test suite..."
    
    # Baseline performance test
    echo "1. Baseline performance test..."
    time ./scripts/analyze-performance.sh > "$results_dir/baseline.log" 2>&1
    
    # Cache performance test
    echo "2. Cache performance test..."
    ./scripts/load-test.sh --cache-test medium > "$results_dir/cache.log" 2>&1
    
    # Rate limiting test
    echo "3. Rate limiting test..."
    ./scripts/load-test.sh --rate-limit heavy > "$results_dir/rate-limit.log" 2>&1
    
    # Parallel processing test
    echo "4. Parallel processing test..."
    for jobs in 1 2 4 8; do
        echo "  Testing with $jobs parallel jobs..."
        MAX_PARALLEL_JOBS=$jobs time ./scripts/analyze-performance.sh \
            > "$results_dir/parallel-$jobs.log" 2>&1
    done
    
    # Memory usage test
    echo "5. Memory usage test..."
    /usr/bin/time -v ./scripts/analyze-performance.sh \
        > "$results_dir/memory.log" 2>&1
    
    # Generate summary report
    generate_performance_summary "$results_dir"
}
```

This comprehensive performance tuning guide provides the tools and knowledge needed to optimize Claude Code Auto Workflows for maximum efficiency across different environments and use cases. Regular application of these optimization techniques will ensure optimal system performance and resource utilization.