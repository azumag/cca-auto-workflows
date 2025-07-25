# Configuration Troubleshooting Guide

This guide provides systematic diagnosis and resolution of configuration issues in Claude Code Auto Workflows.

**Related Documentation:**
- [CONFIGURATION.md](CONFIGURATION.md) - Core configuration options and basic setup
- [SECURITY-OVERVIEW.md](../SECURITY-OVERVIEW.md) - Security overview and quick start guide
- [ADVANCED.md](ADVANCED.md) - Advanced configuration patterns and version compatibility

## Table of Contents

- [Configuration Troubleshooting Decision Tree](#configuration-troubleshooting-decision-tree)
- [Common Configuration Problems](#common-configuration-problems)
- [Configuration Debugging Tools](#configuration-debugging-tools)
- [Performance Issues](#performance-issues)
- [Environment Variable Issues](#environment-variable-issues)
- [File Permission Issues](#file-permission-issues)

## Configuration Troubleshooting Decision Tree

Use this decision tree to systematically diagnose and resolve configuration issues:

```mermaid
flowchart TD
    CONFIG_ISSUE([Configuration Issue]) --> SYMPTOM_CHECK{What is the problem?}
    
    SYMPTOM_CHECK -->|Validation Errors| VALIDATION{Check validation type}
    SYMPTOM_CHECK -->|Values Not Applied| OVERRIDE{Check override priority}
    SYMPTOM_CHECK -->|Performance Issues| PERFORMANCE{Check performance impact}
    SYMPTOM_CHECK -->|Unexpected Behavior| BEHAVIOR{Check configuration logic}
    
    %% Validation Path
    VALIDATION -->|Invalid Range| RANGE_FIX[**🕐 Estimated Time: 2-5 minutes**<br/><br/>Check valid ranges:<br/>MAX_PARALLEL_JOBS: 1-32<br/>CACHE_TTL: 60-86400<br/>RATE_LIMIT_REQUESTS_PER_MINUTE: 1-120<br/><br/>**Example**: MAX_PARALELL_JOBS=50 (common typo)<br/>→ Validation error: "Invalid MAX_PARALLEL_JOBS: 50 (must be 1-32)"<br/>→ Solution: export MAX_PARALLEL_JOBS=8<br/><br/>**Example**: CACHE_TTL=30 (too short)<br/>→ Validation error: "CACHE_TTL must be 60-86400 seconds"<br/>→ Solution: export CACHE_TTL=300 # 5 minutes minimum]
    VALIDATION -->|Invalid Enum| ENUM_FIX[**🕐 Estimated Time: 1-3 minutes**<br/><br/>Check valid values:<br/>LOG_LEVEL: DEBUG,INFO,WARN,ERROR<br/>OUTPUT_FORMAT: console,json,markdown<br/>Boolean: true,false only<br/><br/>**Example**: LOG_LEVEL=VERBOSE (invalid)<br/>→ Script exits with "Invalid LOG_LEVEL: VERBOSE"<br/>→ Solution: export LOG_LEVEL=DEBUG<br/><br/>**Example**: ENABLE_CACHE=yes (wrong format)<br/>→ Validation fails, expects true/false<br/>→ Solution: export ENABLE_CACHE=true]
    VALIDATION -->|Missing Dependencies| DEPENDENCY_FIX[**🕐 Estimated Time: 5-10 minutes**<br/><br/>Check relationships:<br/>BENCHMARK_ITERATIONS >= 3 if benchmarks enabled<br/>RATE_LIMIT_DELAY appropriate for request rate<br/><br/>**Example**: ENABLE_BENCHMARKS=true + BENCHMARK_ITERATIONS=1<br/>→ Error: "BENCHMARK_ITERATIONS must be at least 3"<br/>→ Solution: export BENCHMARK_ITERATIONS=5<br/><br/>**Example**: RATE_LIMIT_REQUESTS_PER_MINUTE=100 + RATE_LIMIT_DELAY=10<br/>→ Warning: "High delay with high rate may cause issues"<br/>→ Solution: Reduce delay to 1-2 seconds]
    
    %% Override Path
    OVERRIDE -->|Environment Not Working| ENV_CHECK{Check environment variables}
    OVERRIDE -->|Config File Ignored| FILE_CHECK{Check config file}
    OVERRIDE -->|Precedence Issues| PRECEDENCE_CHECK{Check loading order}
    
    ENV_CHECK -->|Not Exported| EXPORT_FIX[**🕐 Estimated Time: 2-5 minutes**<br/><br/>Use: export VAR=value<br/>Not: VAR=value<br/>Check with: env | grep VAR<br/><br/>**Example**: Configuration not overriding defaults<br/>→ Used: MAX_PARALLEL_JOBS=8 ./script.sh<br/>→ Variable not in environment for subprocess<br/>→ Solution: export MAX_PARALLEL_JOBS=8; ./script.sh]
    ENV_CHECK -->|Wrong Name| NAME_FIX[**🕐 Estimated Time: 1-3 minutes**<br/><br/>Verify exact variable names<br/>Check for typos<br/>Case-sensitive matching<br/><br/>**Example**: MAX_PARALELL_JOBS=8 (double L typo)<br/>→ Scripts still uses default MAX_PARALLEL_JOBS=4<br/>→ Solution: export MAX_PARALLEL_JOBS=8<br/><br/>**Example**: cache_ttl=1800 (lowercase)<br/>→ Scripts expects CACHE_TTL (uppercase)<br/>→ Solution: export CACHE_TTL=1800]
    ENV_CHECK -->|Wrong Value| VALUE_FIX[**🕐 Estimated Time: 2-5 minutes**<br/><br/>Check value format<br/>Boolean: true/false<br/>Numbers: numeric only<br/><br/>**Example**: ENABLE_CACHE=True (capital T)<br/>→ Script validation fails, needs lowercase<br/>→ Solution: export ENABLE_CACHE=true<br/><br/>**Example**: MAX_PARALLEL_JOBS="8" (quoted)<br/>→ Numeric comparison fails with quotes<br/>→ Solution: export MAX_PARALLEL_JOBS=8]
    
    FILE_CHECK -->|File Not Found| PATH_FIX[**🕐 Estimated Time: 3-8 minutes**<br/><br/>Check CONFIG_FILE path<br/>Verify file exists<br/>Use absolute paths<br/><br/>**Example**: CONFIG_FILE="config/prod.conf" but file missing<br/>→ Error: "config/prod.conf: No such file or directory"<br/>→ Solution: Create file or fix path: CONFIG_FILE="config/production.conf"<br/><br/>**Example**: Relative path issues in CI/CD<br/>→ CONFIG_FILE="./config.conf" fails in different working dir<br/>→ Solution: Use absolute path: CONFIG_FILE="/workspace/config/production.conf"]
    FILE_CHECK -->|Wrong Syntax| SYNTAX_FIX[**🕐 Estimated Time: 3-7 minutes**<br/><br/>Check bash syntax<br/>No spaces around =<br/>Quote string values<br/><br/>**Example**: MAX_PARALLEL_JOBS = 8 (spaces around =)<br/>→ Bash syntax error during config loading<br/>→ Solution: MAX_PARALLEL_JOBS=8<br/><br/>**Example**: LOG_LEVEL=INFO DEBUG (space in value)<br/>→ Only "INFO" is set, "DEBUG" treated as command<br/>→ Solution: LOG_LEVEL="INFO DEBUG" or separate variables]
    FILE_CHECK -->|Permissions| PERM_FIX[**🕐 Estimated Time: 5-15 minutes**<br/><br/>Check read permissions<br/>chmod +r config_file<br/>Verify ownership<br/><br/>**Example**: "Permission denied" when loading config<br/>→ Config file has 600 permissions, script running as different user<br/>→ Solution: chmod 644 config/production.conf<br/><br/>**Example**: Config file owned by root in container<br/>→ Application running as non-root can't read<br/>→ Solution: chown appuser:appuser config/production.conf]
    
    PRECEDENCE_CHECK -->|Wrong Order| ORDER_FIX[**🕐 Estimated Time: 10-20 minutes**<br/><br/>Remember priority:<br/>1. default.conf<br/>2. Environment vars<br/>3. Custom config<br/>4. Command-line args<br/><br/>**Example**: Expected env var to override config file<br/>→ Custom config loaded after environment variables<br/>→ Check script loading order in common.sh<br/>→ Solution: Move env var loading after config file load<br/><br/>**Example**: Default value still used despite custom config<br/>→ Typo in variable name in config file<br/>→ Solution: Verify exact variable names match]
    
    %% Performance Path
    PERFORMANCE -->|Too Slow| SLOW_CONFIG[**🕐 Estimated Time: 10-25 minutes**<br/><br/>Check settings:<br/>MAX_PARALLEL_JOBS too low<br/>CACHE_TTL too short<br/>Too many validations enabled<br/><br/>**Example**: Analysis takes 10+ minutes on 8-core system<br/>→ MAX_PARALLEL_JOBS=2 underutilizing CPU<br/>→ Solution: export MAX_PARALLEL_JOBS=8<br/><br/>**Example**: Frequent API rate limit warnings<br/>→ CACHE_TTL=60 causing excessive API calls<br/>→ Solution: export CACHE_TTL=1800 # 30 minutes]
    PERFORMANCE -->|Too Resource Intensive| RESOURCE_CONFIG[**🕐 Estimated Time: 15-30 minutes**<br/><br/>Check settings:<br/>MAX_PARALLEL_JOBS too high<br/>CACHE_TTL too long<br/>Memory constraints<br/><br/>**Example**: System freezes during analysis<br/>→ MAX_PARALLEL_JOBS=32 on 4-core system causes thrashing<br/>→ Solution: export MAX_PARALLEL_JOBS=4<br/><br/>**Example**: Memory usage reaches 8GB on 4GB system<br/>→ Long CACHE_TTL=86400 with large repository<br/>→ Solution: Reduce cache TTL or increase system memory]
    PERFORMANCE -->|Inconsistent Results| CONSISTENCY_CONFIG[**🕐 Estimated Time: 20-45 minutes**<br/><br/>Check settings:<br/>Cache configuration<br/>Parallel job conflicts<br/>Race conditions<br/><br/>**Example**: Different results on repeated runs<br/>→ Cache files corrupted by parallel writes<br/>→ Solution: Reduce MAX_PARALLEL_JOBS or add file locking<br/><br/>**Example**: GitHub API errors sporadically<br/>→ Rate limiting with parallel requests causes timing issues<br/>→ Solution: Adjust RATE_LIMIT_DELAY to add buffer time]
    
    %% Behavior Path
    BEHAVIOR -->|Wrong Output Format| OUTPUT_CHECK[**🕐 Estimated Time: 3-8 minutes**<br/><br/>Check OUTPUT_FORMAT value<br/>Verify COLORED_OUTPUT setting<br/>Check OUTPUT_FILE permissions<br/><br/>**Example**: Expected JSON but got plain text<br/>→ OUTPUT_FORMAT=console instead of json<br/>→ Solution: export OUTPUT_FORMAT=json<br/><br/>**Example**: No colors in terminal despite setting<br/>→ COLORED_OUTPUT=true but terminal doesn't support colors<br/>→ Solution: Check TERM variable or force colors off]
    BEHAVIOR -->|Logging Issues| LOG_CHECK[**🕐 Estimated Time: 5-12 minutes**<br/><br/>Check LOG_LEVEL setting<br/>Verify log file permissions<br/>Check COLORED_OUTPUT for terminals<br/><br/>**Example**: No debug output despite LOG_LEVEL=DEBUG<br/>→ Actually set to INFO due to config file override<br/>→ Solution: Check config precedence, export LOG_LEVEL=DEBUG<br/><br/>**Example**: Garbled colors in CI/CD logs<br/>→ COLORED_OUTPUT=true in non-interactive environment<br/>→ Solution: export COLORED_OUTPUT=false for CI]
    BEHAVIOR -->|Cache Not Working| CACHE_CHECK[**🕐 Estimated Time: 8-20 minutes**<br/><br/>Check ENABLE_CACHE=true<br/>Verify CACHE_TTL > 0<br/>Check cache directory permissions<br/><br/>**Example**: Same API calls repeated every run<br/>→ ENABLE_CACHE=false disabling cache entirely<br/>→ Solution: export ENABLE_CACHE=true<br/><br/>**Example**: Cache directory errors<br/>→ /tmp/github-api-cache not writable by script user<br/>→ Solution: mkdir -p /tmp/github-api-cache; chmod 755 /tmp/github-api-cache]
    BEHAVIOR -->|Rate Limiting Problems| RATE_CHECK[**🕐 Estimated Time: 10-25 minutes**<br/><br/>Check rate limit settings<br/>Verify GitHub token type<br/>Monitor actual usage vs limits<br/><br/>**Example**: Hit rate limits with low request rate<br/>→ RATE_LIMIT_REQUESTS_PER_MINUTE=60 but only using PAT (5000/hr limit)<br/>→ Should be hitting limit, check if other processes using same token<br/>→ Solution: Use GitHub App token for higher limits<br/><br/>**Example**: Delays much longer than expected<br/>→ RATE_LIMIT_DELAY=10 causing 10-second delays between requests<br/>→ Solution: Reduce to RATE_LIMIT_DELAY=2 for better performance]
    
    %% Solution Validation
    RANGE_FIX --> VALIDATE_FIX{Test configuration}
    ENUM_FIX --> VALIDATE_FIX
    DEPENDENCY_FIX --> VALIDATE_FIX
    EXPORT_FIX --> VALIDATE_FIX
    NAME_FIX --> VALIDATE_FIX
    VALUE_FIX --> VALIDATE_FIX
    PATH_FIX --> VALIDATE_FIX
    SYNTAX_FIX --> VALIDATE_FIX
    PERM_FIX --> VALIDATE_FIX
    ORDER_FIX --> VALIDATE_FIX
    SLOW_CONFIG --> VALIDATE_FIX
    RESOURCE_CONFIG --> VALIDATE_FIX
    CONSISTENCY_CONFIG --> VALIDATE_FIX
    OUTPUT_CHECK --> VALIDATE_FIX
    LOG_CHECK --> VALIDATE_FIX
    CACHE_CHECK --> VALIDATE_FIX
    RATE_CHECK --> VALIDATE_FIX
    
    VALIDATE_FIX -->|Fixed| SUCCESS([Configuration Working ✅])
    VALIDATE_FIX -->|Still Issues| DEBUG_CONFIG[Run ./scripts/debug-config.sh<br/>Enable DEBUG logging<br/>Check complete configuration dump]
    DEBUG_CONFIG --> SYMPTOM_CHECK
    
    %% Styling
    style CONFIG_ISSUE fill:#ffebee
    style SUCCESS fill:#e8f5e8
    style SYMPTOM_CHECK fill:#e1f5fe
    style VALIDATE_FIX fill:#f3e5f5
    style DEBUG_CONFIG fill:#fff3e0
```

## Common Configuration Problems

### 1. Invalid Configuration Values

**Problem:** Configuration validation fails with error messages.

**Diagnosis:**
```bash
# Run configuration validation
./scripts/validate-config.sh

# Check specific configuration file
CONFIG_FILE="config/problematic.conf" ./scripts/validate-config.sh

# Debug configuration loading
DEBUG=1 ./scripts/analyze-performance.sh
```

**Solutions:**
```bash
# Fix common validation errors

# Invalid numeric range
MAX_PARALLEL_JOBS=0    # ❌ Too low
MAX_PARALLEL_JOBS=100  # ❌ Too high
MAX_PARALLEL_JOBS=8    # ✅ Valid

# Invalid boolean value
ENABLE_CACHE=yes       # ❌ Invalid
ENABLE_CACHE=true      # ✅ Valid

# Invalid enum value
LOG_LEVEL=VERBOSE      # ❌ Invalid
LOG_LEVEL=DEBUG        # ✅ Valid
```

### 2. Configuration Override Issues

**Problem:** Environment variables not overriding configuration file values.

**Diagnosis:**
```bash
# Check configuration loading order
echo "Config file: $CONFIG_FILE"
echo "Environment override: $MAX_PARALLEL_JOBS"

# Verify environment variable is set
env | grep MAX_PARALLEL_JOBS

# Check configuration after loading
./scripts/debug-config.sh
```

**Solutions:**
```bash
# Ensure environment variables are exported
export MAX_PARALLEL_JOBS=8  # Not just MAX_PARALLEL_JOBS=8

# Check for typos in variable names
export MAX_PARALELL_JOBS=8  # ❌ Typo
export MAX_PARALLEL_JOBS=8  # ✅ Correct

# Verify variable precedence
unset MAX_PARALLEL_JOBS  # Clear environment override if needed
```

### 3. Performance Degradation After Configuration Changes

**Problem:** System performance decreased after configuration changes.

**Diagnosis:**
```bash
# Compare performance before/after
./scripts/benchmark-performance.sh > before-config-change.log
# Apply configuration changes
./scripts/benchmark-performance.sh > after-config-change.log

# Compare results
diff before-config-change.log after-config-change.log
```

**Solutions:**
```bash
# Common performance fixes

# Too many parallel jobs causing contention
MAX_PARALLEL_JOBS=16   # ❌ May cause contention on 4-core system
MAX_PARALLEL_JOBS=4    # ✅ Better for 4-core system

# Cache TTL too short causing frequent API calls
CACHE_TTL=60           # ❌ Too short, causes frequent API calls
CACHE_TTL=1800         # ✅ Better balance

# Aggressive rate limiting causing delays
RATE_LIMIT_DELAY=10    # ❌ Too long, slows down execution
RATE_LIMIT_DELAY=2     # ✅ Reasonable delay
```

### 4. Cache-Related Issues

**Problem:** Caching not working as expected.

**Diagnosis:**
```bash
# Check cache directory and permissions
ls -la /tmp/github-api-cache/
ls -la /tmp/performance-metrics/

# Check cache statistics
./scripts/analyze-performance.sh | grep -A5 "Cache Performance"

# Monitor cache directory during execution
watch "du -sh /tmp/github-api-cache; ls /tmp/github-api-cache | wc -l"
```

**Solutions:**
```bash
# Common cache fixes

# Cache directory doesn't exist or wrong permissions
mkdir -p /tmp/github-api-cache
chmod 700 /tmp/github-api-cache

# Cache TTL too short
CACHE_TTL=60           # ❌ Very short TTL
CACHE_TTL=1800         # ✅ More reasonable TTL

# Caching disabled
ENABLE_CACHE=false     # ❌ Caching disabled
ENABLE_CACHE=true      # ✅ Enable caching
```

## Configuration Debugging Tools

### Debug Configuration Script

```bash
#!/bin/bash
# debug-config.sh - Debug configuration loading and values

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib/common.sh"

echo "Configuration Debug Report"
echo "========================="
echo

echo "1. Configuration Loading:"
echo "   CONFIG_FILE: ${CONFIG_FILE:-'(not set)'}"
echo "   Default config: $script_dir/config/default.conf"
echo

# Load configuration with debug output
echo "2. Loading configuration..."
load_config "${CONFIG_FILE:-}"

echo "3. Final Configuration Values:"
echo "   MAX_PARALLEL_JOBS: $MAX_PARALLEL_JOBS"
echo "   CACHE_TTL: $CACHE_TTL"
echo "   LOG_LEVEL: $LOG_LEVEL"
echo "   OUTPUT_FORMAT: $OUTPUT_FORMAT"
echo "   ENABLE_CACHE: $ENABLE_CACHE"
echo "   ENABLE_BENCHMARKS: $ENABLE_BENCHMARKS"
echo

echo "4. Environment Variable Overrides:"
env | grep -E '^(MAX_PARALLEL_JOBS|CACHE_TTL|LOG_LEVEL|OUTPUT_FORMAT|ENABLE_CACHE|ENABLE_BENCHMARKS)=' || echo "   (none)"
echo

echo "5. Configuration Validation:"
if validate_config; then
    echo "   ✅ Configuration is valid"
else
    echo "   ❌ Configuration validation failed"
fi
```

### Configuration Diff Tool

```bash
#!/bin/bash
# config-diff.sh - Compare configuration values between files

compare_configurations() {
    local config1="$1"
    local config2="$2"
    
    echo "Comparing configurations:"
    echo "  File 1: $config1"
    echo "  File 2: $config2"
    echo
    
    # Create temporary files with extracted variables
    local temp1=$(mktemp)
    local temp2=$(mktemp)
    
    # Extract configuration variables
    grep -E '^[A-Z_]+=.*' "$config1" | sort > "$temp1" 2>/dev/null || true
    grep -E '^[A-Z_]+=.*' "$config2" | sort > "$temp2" 2>/dev/null || true
    
    # Show differences
    if cmp -s "$temp1" "$temp2"; then
        echo "✅ Configurations are identical"
    else
        echo "❌ Configuration differences found:"
        diff -u "$temp1" "$temp2" | grep -E '^[+-]' | grep -v '^[+-]{3}' || true
    fi
    
    # Cleanup
    rm -f "$temp1" "$temp2"
}

# Usage: ./config-diff.sh config/dev.conf config/prod.conf
compare_configurations "$1" "$2"
```

### Configuration History Tracker

```bash
#!/bin/bash
# config-history.sh - Track configuration changes over time

log_config_change() {
    local config_file="$1"
    local change_reason="$2"
    local history_file="config/history.log"
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local user=$(whoami)
    local checksum=$(sha256sum "$config_file" | cut -d' ' -f1)
    
    echo "$timestamp|$user|$config_file|$checksum|$change_reason" >> "$history_file"
    
    echo "Configuration change logged:"
    echo "  File: $config_file"
    echo "  User: $user"
    echo "  Reason: $change_reason"
    echo "  Checksum: $checksum"
}

# View configuration history
view_config_history() {
    local config_file="${1:-all}"
    local history_file="config/history.log"
    
    if [[ ! -f "$history_file" ]]; then
        echo "No configuration history found"
        return 1
    fi
    
    echo "Configuration Change History"
    echo "==========================="
    echo
    
    if [[ "$config_file" == "all" ]]; then
        cat "$history_file"
    else
        grep "$config_file" "$history_file"
    fi | while IFS='|' read -r timestamp user file checksum reason; do
        echo "[$timestamp] $user changed $file"
        echo "  Reason: $reason"
        echo "  Checksum: $checksum"
        echo
    done
}

# Usage examples:
# log_config_change "config/production.conf" "Increased cache TTL for performance"
# view_config_history "config/production.conf"
```

## Performance Issues

### Identifying Performance Bottlenecks

```bash
# Monitor system resources during configuration loading
monitor_config_performance() {
    local config_file="$1"
    
    echo "Monitoring performance for config: $config_file"
    
    # Start monitoring
    local monitor_pid
    {
        while true; do
            echo "$(date '+%H:%M:%S') CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)% MEM: $(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')%"
            sleep 1
        done
    } &
    monitor_pid=$!
    
    # Load configuration
    local start_time=$(date +%s.%3N)
    CONFIG_FILE="$config_file" load_config
    local end_time=$(date +%s.%3N)
    
    # Stop monitoring
    kill $monitor_pid 2>/dev/null || true
    
    local duration=$(echo "$end_time - $start_time" | bc)
    echo "Configuration loading took: ${duration}s"
}
```

### Performance Tuning Recommendations

```bash
# Auto-tune configuration based on system resources
auto_tune_config() {
    local cpu_cores=$(nproc)
    local memory_gb=$(free -g | awk 'NR==2{print $2}')
    
    echo "System Resources:"
    echo "  CPU cores: $cpu_cores"
    echo "  Memory: ${memory_gb}GB"
    echo
    
    # Recommend MAX_PARALLEL_JOBS
    local recommended_parallel_jobs
    if [[ $memory_gb -lt 4 ]]; then
        recommended_parallel_jobs=$((cpu_cores / 2))
    elif [[ $memory_gb -lt 8 ]]; then
        recommended_parallel_jobs=$cpu_cores
    else
        recommended_parallel_jobs=$((cpu_cores * 2))
    fi
    
    # Ensure within valid range
    [[ $recommended_parallel_jobs -lt 1 ]] && recommended_parallel_jobs=1
    [[ $recommended_parallel_jobs -gt 32 ]] && recommended_parallel_jobs=32
    
    echo "Recommended Configuration:"
    echo "  MAX_PARALLEL_JOBS=$recommended_parallel_jobs"
    
    # Recommend CACHE_TTL based on memory
    local recommended_cache_ttl
    if [[ $memory_gb -lt 2 ]]; then
        recommended_cache_ttl=900   # 15 minutes
    elif [[ $memory_gb -lt 8 ]]; then
        recommended_cache_ttl=1800  # 30 minutes
    else
        recommended_cache_ttl=3600  # 1 hour
    fi
    
    echo "  CACHE_TTL=$recommended_cache_ttl"
}
```

## Environment Variable Issues

### Environment Variable Debugging

```bash
# Debug environment variable issues
debug_env_vars() {
    echo "Environment Variable Debug Report"
    echo "================================"
    echo
    
    # Check if variables are exported
    echo "1. Exported Configuration Variables:"
    env | grep -E '^(MAX_PARALLEL_JOBS|CACHE_TTL|LOG_LEVEL|OUTPUT_FORMAT|ENABLE_CACHE)=' || echo "   (none found)"
    echo
    
    # Check for common typos
    echo "2. Checking for Common Typos:"
    local typos_found=false
    
    if env | grep -i "paralell" >/dev/null; then
        echo "   ❌ Found 'PARALELL' (should be 'PARALLEL')"
        typos_found=true
    fi
    
    if env | grep -i "cahce" >/dev/null; then
        echo "   ❌ Found 'CAHCE' (should be 'CACHE')"
        typos_found=true
    fi
    
    if ! $typos_found; then
        echo "   ✅ No common typos found"
    fi
    echo
    
    # Check variable types
    echo "3. Variable Type Validation:"
    
    if [[ -n "${MAX_PARALLEL_JOBS:-}" ]]; then
        if [[ "$MAX_PARALLEL_JOBS" =~ ^[0-9]+$ ]]; then
            echo "   ✅ MAX_PARALLEL_JOBS is numeric: $MAX_PARALLEL_JOBS"
        else
            echo "   ❌ MAX_PARALLEL_JOBS is not numeric: $MAX_PARALLEL_JOBS"
        fi
    fi
    
    if [[ -n "${ENABLE_CACHE:-}" ]]; then
        case "$ENABLE_CACHE" in
            true|false)
                echo "   ✅ ENABLE_CACHE is boolean: $ENABLE_CACHE"
                ;;
            *)
                echo "   ❌ ENABLE_CACHE is not boolean: $ENABLE_CACHE"
                ;;
        esac
    fi
}
```

## File Permission Issues

### File Permission Diagnostics

```bash
# Diagnose file permission issues
diagnose_file_permissions() {
    echo "File Permission Diagnostic Report"
    echo "================================"
    echo
    
    # Check configuration directory
    local config_dir="config"
    if [[ -d "$config_dir" ]]; then
        echo "1. Configuration Directory Permissions:"
        ls -la "$config_dir/" | head -5
        echo
        
        # Check individual config files
        echo "2. Configuration File Permissions:"
        find "$config_dir" -name "*.conf" -exec ls -la {} \; 2>/dev/null | while read -r perms links owner group size date time file; do
            local octal_perms=$(stat -c "%a" "$file" 2>/dev/null)
            if [[ "$octal_perms" -gt 644 ]]; then
                echo "   ⚠️  $file has overly permissive permissions: $octal_perms"
            elif [[ "$octal_perms" -lt 600 ]]; then
                echo "   ❌ $file has insufficient permissions: $octal_perms"
            else
                echo "   ✅ $file has appropriate permissions: $octal_perms"
            fi
        done
    else
        echo "❌ Configuration directory not found: $config_dir"
    fi
    echo
    
    # Check cache directories
    echo "3. Cache Directory Permissions:"
    for cache_dir in "/tmp/github-api-cache" "/tmp/performance-metrics"; do
        if [[ -d "$cache_dir" ]]; then
            local perms=$(stat -c "%a" "$cache_dir")
            local owner=$(stat -c "%U" "$cache_dir")
            echo "   $cache_dir: permissions=$perms, owner=$owner"
            
            if [[ ! -w "$cache_dir" ]]; then
                echo "   ❌ Cache directory is not writable"
            else
                echo "   ✅ Cache directory is writable"
            fi
        else
            echo "   ❌ Cache directory does not exist: $cache_dir"
        fi
    done
}

# Fix common permission issues
fix_common_permission_issues() {
    echo "Fixing Common Permission Issues"
    echo "=============================="
    echo
    
    # Fix configuration file permissions
    if [[ -d "config" ]]; then
        echo "1. Fixing configuration file permissions..."
        find config/ -name "*.conf" -exec chmod 644 {} \;
        echo "   ✅ Configuration files set to 644"
    fi
    
    # Create and fix cache directories
    echo "2. Creating and fixing cache directories..."
    for cache_dir in "/tmp/github-api-cache" "/tmp/performance-metrics"; do
        mkdir -p "$cache_dir"
        chmod 755 "$cache_dir"
        echo "   ✅ $cache_dir created with 755 permissions"
    done
    
    echo
    echo "Permission fixes completed. Re-run diagnostics to verify."
}
```

## Monitoring Troubleshooting

Monitoring integrations can experience various issues related to metrics collection, alerting, and dashboard functionality. This section provides systematic diagnosis and resolution for monitoring-specific problems.

### Metrics Collection Issues

#### Metrics Not Being Generated

**Problem:** Metrics files are empty or not being created.

**Diagnosis:**
```bash
# Check if metrics collection is enabled
echo "ENABLE_METRICS: ${ENABLE_METRICS:-'not set'}"
echo "METRICS_DIR: ${METRICS_DIR:-'not set'}"

# Check metrics directory exists and is writable
ls -la "${METRICS_DIR:-/var/metrics/cca-workflows}"

# Check if metrics library is loaded
grep -n "source.*metrics.sh" scripts/analyze-performance.sh

# Monitor metrics generation in real-time
watch "ls -la ${METRICS_DIR:-/var/metrics/cca-workflows}; echo '---'; tail -5 ${METRICS_DIR:-/var/metrics/cca-workflows}/cca_workflows.prom"
```

**Solutions:**
```bash
# Enable metrics collection
export ENABLE_METRICS=true
export METRICS_DIR="/var/metrics/cca-workflows"

# Create metrics directory with proper permissions
mkdir -p "$METRICS_DIR"
chmod 755 "$METRICS_DIR"

# Verify metrics library is sourced in scripts
if ! grep -q "source.*metrics.sh" scripts/analyze-performance.sh; then
    echo "Metrics library not loaded - add to script:"
    echo "source \"\$script_dir/lib/metrics.sh\""
fi

# Initialize metrics manually if needed
if [[ "$ENABLE_METRICS" == "true" ]]; then
    source scripts/lib/metrics.sh
    init_metrics
fi
```

#### Prometheus Scraping Failures

**Problem:** Prometheus cannot scrape metrics from the application.

**Diagnosis:**
```bash
# Check if metrics endpoint is accessible
curl -s "http://localhost:9090/metrics" | head -10

# Check Prometheus configuration
grep -A 10 "job_name.*cca-workflows" monitoring/prometheus.yml

# Verify Prometheus is running and can reach targets
docker logs prometheus-container 2>&1 | grep -i error
# Or if running directly:
journalctl -u prometheus | tail -20

# Check Prometheus targets status
curl -s "http://localhost:9090/api/v1/targets" | jq '.data.activeTargets[] | select(.labels.job=="cca-workflows")'
```

**Solutions:**
```bash
# Fix metrics endpoint accessibility
# Ensure metrics server is running on correct port
netstat -tlnp | grep :9090

# Start simple HTTP server for metrics
if ! pgrep -f "python.*SimpleHTTPServer" > /dev/null; then
    cd "$METRICS_DIR" && python -m SimpleHTTPServer 9090 &
fi

# Fix Prometheus configuration
cat > monitoring/prometheus-fix.yml << 'EOF'
scrape_configs:
  - job_name: 'cca-workflows'
    static_configs:
      - targets: ['localhost:9090']
    scrape_interval: 30s
    metrics_path: /cca_workflows.prom
    scrape_timeout: 10s
EOF

# Restart Prometheus with corrected config
docker restart prometheus-container
# Or reload configuration:
curl -X POST http://localhost:9090/-/reload
```

#### Incomplete or Corrupted Metrics Data

**Problem:** Metrics data is incomplete, contains errors, or has inconsistent values.

**Diagnosis:**
```bash
# Check metrics file format
head -20 "${METRICS_DIR}/cca_workflows.prom"

# Validate Prometheus format
promtool check metrics "${METRICS_DIR}/cca_workflows.prom"

# Check for common formatting issues
grep -n "^[^#]" "${METRICS_DIR}/cca_workflows.prom" | grep -v "^[a-zA-Z_][a-zA-Z0-9_]*{.*} [0-9.-]\+$"

# Monitor metrics updates
ls -la "${METRICS_DIR}"/*.prom
stat "${METRICS_DIR}/cca_workflows.prom"

# Check for concurrent write issues
lsof "${METRICS_DIR}/cca_workflows.prom"
```

**Solutions:**
```bash
# Fix metrics file permissions
chmod 644 "${METRICS_DIR}"/*.prom

# Implement atomic writes to prevent corruption
cat > scripts/lib/safe-metrics.sh << 'EOF'
safe_write_metrics() {
    local metrics_file="$1"
    local temp_file="${metrics_file}.tmp.$$"
    
    # Write to temporary file first
    cat > "$temp_file"
    
    # Validate format
    if promtool check metrics "$temp_file" 2>/dev/null; then
        # Atomic move
        mv "$temp_file" "$metrics_file"
    else
        echo "Invalid metrics format, discarding update"
        rm -f "$temp_file"
        return 1
    fi
}
EOF

# Use file locking for concurrent access
flock -x "${METRICS_DIR}/metrics.lock" -c "update_metrics_function"

# Reset corrupted metrics file
if [[ -f "${METRICS_DIR}/cca_workflows.prom" ]]; then
    cp "${METRICS_DIR}/cca_workflows.prom" "${METRICS_DIR}/cca_workflows.prom.backup"
    source scripts/lib/metrics.sh
    init_metrics
fi
```

### Alerting Issues

#### Alerts Not Firing

**Problem:** Expected alerts are not triggering despite meeting conditions.

**Diagnosis:**
```bash
# Check alert rules syntax
promtool check rules monitoring/alert_rules.yml

# Verify alert rules are loaded in Prometheus
curl -s "http://localhost:9090/api/v1/rules" | jq '.data.groups[].rules[] | select(.type=="alerting")'

# Check current alert status
curl -s "http://localhost:9090/api/v1/alerts" | jq '.data.alerts[] | {name: .labels.alertname, state: .state, value: .value}'

# Test alert expressions manually
curl -s "http://localhost:9090/api/v1/query" \
  --data-urlencode 'query=rate(cca_workflows_github_api_requests_total{status="error"}[5m]) / rate(cca_workflows_github_api_requests_total[5m])' | \
  jq '.data.result[].value[1]'

# Check Alertmanager connectivity
curl -s "http://localhost:9093/api/v1/status" | jq '.data.configYAML'
```

**Solutions:**
```bash
# Fix alert rule syntax errors
promtool check rules monitoring/alert_rules.yml
# Edit and fix any syntax errors identified

# Ensure alert rules are properly loaded
# Reload Prometheus configuration
curl -X POST http://localhost:9090/-/reload

# Verify alert evaluation interval
grep -A 5 "evaluation_interval" monitoring/prometheus.yml

# Check for data availability issues
# Ensure metrics have data in the time range alert is checking
curl -s "http://localhost:9090/api/v1/query_range" \
  --data-urlencode 'query=cca_workflows_github_api_requests_total' \
  --data-urlencode 'start=2024-01-01T00:00:00Z' \
  --data-urlencode 'end=2024-12-31T23:59:59Z' \
  --data-urlencode 'step=3600s'

# Test with simpler alert rule
cat > monitoring/test-alert.yml << 'EOF'
groups:
  - name: test_alerts
    rules:
      - alert: TestAlert
        expr: up{job="cca-workflows"} == 0
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Test alert for troubleshooting"
EOF
```

#### Alert Notifications Not Delivered

**Problem:** Alerts are firing but notifications are not being sent.

**Diagnosis:**
```bash
# Check Alertmanager logs
docker logs alertmanager-container 2>&1 | tail -50
# Or: journalctl -u alertmanager | tail -20

# Verify Alertmanager configuration
curl -s "http://localhost:9093/api/v1/status" | jq '.data.configYAML'

# Check alert routing
curl -s "http://localhost:9093/api/v1/alerts" | jq '.data[] | {fingerprint, status, receiver}'

# Test notification channels
# For email:
telnet smtp.company.com 587

# For Slack webhook:
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Test message"}' \
  https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
```

**Solutions:**
```bash
# Fix SMTP configuration
cat > monitoring/alertmanager-fix.yml << 'EOF'
global:
  smtp_smarthost: 'smtp.company.com:587'
  smtp_from: 'alerts@company.com'
  smtp_auth_username: 'alerts@company.com'
  smtp_auth_password: 'password'
  smtp_require_tls: true

route:
  receiver: 'default'
  group_wait: 10s
  group_interval: 5m
  repeat_interval: 12h

receivers:
  - name: 'default'
    email_configs:
      - to: 'devops@company.com'
        subject: 'Test Alert'
        body: 'Alert: {{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
EOF

# Test email configuration
echo "Subject: Test Alert" | sendmail -v devops@company.com

# Fix Slack webhook URL
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/CORRECT/WEBHOOK"

# Restart Alertmanager with fixed configuration
docker restart alertmanager-container

# Check silence status (alerts might be silenced)
curl -s "http://localhost:9093/api/v1/silences" | jq '.data[] | {comment, matchers, status}'
```

#### False Positive Alerts

**Problem:** Alerts are firing incorrectly due to noisy data or incorrect thresholds.

**Diagnosis:**
```bash
# Analyze alert frequency
curl -s "http://localhost:9090/api/v1/query_range" \
  --data-urlencode 'query=ALERTS{alertname="HighErrorRate"}' \
  --data-urlencode 'start=2024-01-01T00:00:00Z' \
  --data-urlencode 'end=2024-12-31T23:59:59Z' \
  --data-urlencode 'step=3600s'

# Check metric values around alert times
curl -s "http://localhost:9090/api/v1/query_range" \
  --data-urlencode 'query=rate(cca_workflows_github_api_requests_total{status="error"}[5m])' \
  --data-urlencode 'start=2024-01-01T00:00:00Z' \
  --data-urlencode 'end=2024-12-31T23:59:59Z' \
  --data-urlencode 'step=300s'

# Analyze alert rule sensitivity
grep -A 10 "HighErrorRate" monitoring/alert_rules.yml
```

**Solutions:**
```bash
# Adjust alert thresholds based on historical data
# Increase error rate threshold from 5% to 10%
sed -i 's/> 0.05/> 0.10/' monitoring/alert_rules.yml

# Add longer evaluation period to reduce noise
sed -i 's/for: 5m/for: 10m/' monitoring/alert_rules.yml

# Use moving averages for smoother alerting
cat > monitoring/improved-alerts.yml << 'EOF'
- alert: HighErrorRate
  expr: |
    (
      avg_over_time(
        rate(cca_workflows_github_api_requests_total{status="error"}[5m])[10m:]
      ) /
      avg_over_time(
        rate(cca_workflows_github_api_requests_total[5m])[10m:]
      )
    ) > 0.08
  for: 15m
  labels:
    severity: warning
  annotations:
    summary: "Sustained high error rate detected"
    description: "Error rate has been {{ $value | humanizePercentage }} for 15+ minutes"
EOF

# Add alert inhibition rules
cat >> monitoring/alert_rules.yml << 'EOF'
- alert: GitHubAPIDown
  expr: up{job="github-api"} == 0
  for: 5m
  labels:
    severity: critical
    inhibits: "HighErrorRate"
  annotations:
    summary: "GitHub API is down"
    description: "This will cause high error rates in dependent services"
EOF
```

### Dashboard Issues

#### Grafana Dashboard Not Loading Data

**Problem:** Grafana dashboard panels show "No data" or fail to load.

**Diagnosis:**
```bash
# Check Grafana datasource configuration
curl -s -u admin:admin "http://localhost:3000/api/datasources" | jq '.[] | {name, url, type}'

# Test Prometheus connectivity from Grafana
curl -s -u admin:admin "http://localhost:3000/api/datasources/proxy/1/api/v1/query?query=up"

# Check Grafana logs
docker logs grafana-container 2>&1 | grep -i error
# Or: journalctl -u grafana-server | tail -20

# Verify panel queries
curl -s -u admin:admin "http://localhost:3000/api/dashboards/uid/cca-workflows" | jq '.dashboard.panels[].targets'

# Test queries directly against Prometheus
curl -s "http://localhost:9090/api/v1/query" \
  --data-urlencode 'query=rate(cca_workflows_github_api_requests_total[5m])'
```

**Solutions:**
```bash
# Fix Grafana datasource configuration
curl -X POST -u admin:admin \
  -H "Content-Type: application/json" \
  "http://localhost:3000/api/datasources" \
  -d '{
    "name": "Prometheus",
    "type": "prometheus", 
    "url": "http://localhost:9090",
    "access": "proxy",
    "isDefault": true
  }'

# Fix network connectivity between Grafana and Prometheus
# Check if both services can communicate
docker exec grafana-container curl -s http://prometheus:9090/api/v1/targets

# Update dashboard panel queries
# Fix metric names or adjust query syntax
cat > dashboard-fix.json << 'EOF'
{
  "targets": [
    {
      "expr": "rate(cca_workflows_github_api_requests_total[5m])",
      "legendFormat": "{{status}} - {{endpoint}}",
      "refId": "A"
    }
  ]
}
EOF

# Import corrected dashboard
curl -X POST -u admin:admin \
  -H "Content-Type: application/json" \
  "http://localhost:3000/api/dashboards/db" \
  -d @dashboard-fix.json
```

#### Dashboard Performance Issues

**Problem:** Dashboard loads slowly or times out.

**Diagnosis:**
```bash
# Check query performance
time curl -s "http://localhost:9090/api/v1/query_range" \
  --data-urlencode 'query=rate(cca_workflows_github_api_requests_total[5m])' \
  --data-urlencode 'start=2024-01-01T00:00:00Z' \
  --data-urlencode 'end=2024-12-31T23:59:59Z' \
  --data-urlencode 'step=60s'

# Check Prometheus query stats
curl -s "http://localhost:9090/api/v1/status/runtimeinfo" | jq

# Monitor Grafana query performance
curl -s -u admin:admin "http://localhost:3000/api/admin/stats" | jq '.dashboards'

# Check system resources during dashboard load
top -p $(pgrep -f "grafana\|prometheus")
```

**Solutions:**
```bash
# Optimize dashboard queries
# Use recording rules for expensive queries
cat > monitoring/recording-rules.yml << 'EOF'
groups:
  - name: cca_workflows_recording_rules
    interval: 30s
    rules:
      - record: cca_workflows:api_request_rate
        expr: rate(cca_workflows_github_api_requests_total[5m])
        
      - record: cca_workflows:error_rate
        expr: |
          rate(cca_workflows_github_api_requests_total{status="error"}[5m]) /
          rate(cca_workflows_github_api_requests_total[5m])
EOF

# Update dashboard to use recording rules
sed -i 's/rate(cca_workflows_github_api_requests_total\[5m\])/cca_workflows:api_request_rate/g' dashboards/overview.json

# Reduce dashboard refresh rate
sed -i 's/"refresh": "30s"/"refresh": "1m"/' dashboards/overview.json

# Limit time range for heavy queries
sed -i 's/"from": "now-24h"/"from": "now-1h"/' dashboards/overview.json

# Increase Prometheus memory if needed
docker update --memory=2g prometheus-container
```

### Integration-Specific Issues

#### Datadog Integration Failures

**Problem:** Metrics export to Datadog fails or shows incorrect data.

**Diagnosis:**
```bash
# Test Datadog API connectivity
curl -X POST "https://api.datadoghq.com/api/v1/validate" \
  -H "DD-API-KEY: $DATADOG_API_KEY" \
  -H "Content-Type: application/json"

# Check metrics export logs
grep -A 5 "Exporting metrics to Datadog" /var/log/cca-workflows.log

# Verify metrics format conversion
head -5 "${METRICS_DIR}/cca_workflows_detailed.prom"

# Test metric submission manually
curl -X POST "https://api.datadoghq.com/api/v1/series" \
  -H "Content-Type: application/json" \
  -H "DD-API-KEY: $DATADOG_API_KEY" \
  -d '{
    "series": [{
      "metric": "cca_workflows.test_metric",
      "points": [[1640995200, 42]],
      "tags": ["service:cca-workflows", "environment:test"]
    }]
  }'
```

**Solutions:**
```bash
# Fix API key configuration
export DATADOG_API_KEY="your_actual_api_key_here"

# Fix metric naming for Datadog
# Convert Prometheus naming to Datadog naming
sed -i 's/cca_workflows_/cca_workflows./g' scripts/export-metrics.sh

# Add error handling to export script
cat > scripts/export-metrics-safe.sh << 'EOF'
export_to_datadog_safe() {
    local metrics_file="$1"
    local api_key="$2"
    local failed_count=0
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^cca_workflows_ ]]; then
            local response_code=$(curl -w "%{http_code}" -s -o /dev/null \
                -X POST "https://api.datadoghq.com/api/v1/series" \
                -H "Content-Type: application/json" \
                -H "DD-API-KEY: $api_key" \
                -d "$(format_datadog_payload "$line")")
            
            if [[ "$response_code" -ne 202 ]]; then
                ((failed_count++))
                echo "Failed to send metric, HTTP code: $response_code"
            fi
        fi
    done < "$metrics_file"
    
    echo "Export completed. Failed: $failed_count metrics"
}
EOF

# Set up retry mechanism
export_with_retry() {
    local max_retries=3
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        if export_to_datadog_safe "$@"; then
            break
        else
            ((retry_count++))
            echo "Retry $retry_count/$max_retries after 30 seconds..."
            sleep 30
        fi
    done
}
```

#### AWS CloudWatch Integration Failures

**Problem:** Metrics export to CloudWatch fails with permission or format errors.

**Diagnosis:**
```bash
# Test AWS credentials and permissions
aws sts get-caller-identity
aws cloudwatch describe-alarms --region us-east-1 --max-records 1

# Check IAM permissions
aws iam simulate-principal-policy \
  --policy-source-arn "$(aws sts get-caller-identity --query Arn --output text)" \
  --action-names cloudwatch:PutMetricData \
  --resource-arns "*"

# Test CloudWatch API directly
aws cloudwatch put-metric-data \
  --region us-east-1 \
  --namespace "CCAWorkflows/Test" \
  --metric-data MetricName=TestMetric,Value=1,Unit=Count

# Check export script logs
grep -A 10 "Exporting metrics to CloudWatch" /var/log/cca-workflows.log
```

**Solutions:**
```bash
# Fix AWS credentials
aws configure set aws_access_key_id YOUR_ACCESS_KEY
aws configure set aws_secret_access_key YOUR_SECRET_KEY
aws configure set region us-east-1

# Add required IAM permissions
cat > cloudwatch-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "cloudwatch:PutMetricData"
            ],
            "Resource": "*"
        }
    ]
}
EOF

# Fix metric format for CloudWatch
# Ensure proper unit types
sed -i 's/Unit=Count/Unit=None/' scripts/export-metrics.sh

# Add batch processing for better performance
cat > scripts/export-cloudwatch-batch.sh << 'EOF'
export_to_cloudwatch_batch() {
    local metrics_file="$1"
    local aws_region="$2"
    local batch_size=20
    local metric_data="[]"
    local count=0
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^cca_workflows_ ]]; then
            local metric_name=$(echo "$line" | awk '{print $1}')
            local metric_value=$(echo "$line" | awk '{print $2}')
            local timestamp=$(echo "$line" | awk '{print $3}')
            
            metric_data=$(echo "$metric_data" | jq \
                --arg name "$metric_name" \
                --arg value "$metric_value" \
                --arg ts "$timestamp" \
                '. += [{"MetricName": $name, "Value": ($value | tonumber), "Timestamp": ($ts | tonumber), "Unit": "None"}]')
            
            ((count++))
            
            if [[ $count -ge $batch_size ]]; then
                aws cloudwatch put-metric-data \
                    --region "$aws_region" \
                    --namespace "CCAWorkflows" \
                    --metric-data "$metric_data"
                
                metric_data="[]"
                count=0
            fi
        fi
    done < "$metrics_file"
    
    # Send remaining metrics
    if [[ $count -gt 0 ]]; then
        aws cloudwatch put-metric-data \
            --region "$aws_region" \
            --namespace "CCAWorkflows" \
            --metric-data "$metric_data"
    fi
}
EOF
```

## Extended Failure Case Library

### GitHub API Integration Failures

#### GitHub Enterprise Server Connection Issues
```bash
# Failure scenario: Cannot connect to GitHub Enterprise Server
export GITHUB_API_URL="https://github.internal.company.com/api/v3"
export GITHUB_TOKEN="ghp_valid_token"
./scripts/analyze-performance.sh

# Expected error output:
┌─────────────────────────────────────────────────────────────────┐
│ [ERROR] Network Connection: GitHub Enterprise Server unreachable│
│ Code: GITHUB_ENTERPRISE_CONNECTION_FAILED                      │
│ Detail: Could not resolve host github.internal.company.com     │
│ Cause: Network unreachable or DNS resolution failure           │
│ Exit Code: 1                                                    │
└─────────────────────────────────────────────────────────────────┘

# 🕐 Estimated Time: 15-30 minutes
# 🔴 CRITICAL - Cannot access GitHub without network connectivity

# Diagnosis steps:
# 1. Test DNS resolution
# Verify DNS can resolve the enterprise server hostname
nslookup github.internal.company.com

# 2. Test network connectivity
# Test basic network reachability
ping github.internal.company.com
# Test HTTPS port connectivity
telnet github.internal.company.com 443

# 3. Check enterprise-specific configuration
# Test HTTPS response (ignoring SSL for diagnosis)
curl -k -I https://github.internal.company.com

# Recovery procedures:
# Option 1: Fix DNS/network issues
# Restart DNS resolution service
sudo systemctl restart systemd-resolved
# Add fallback DNS server  
echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf

# Option 2: Use IP address temporarily
# Use direct IP if DNS fails (get IP from network admin)
export GITHUB_API_URL="https://192.168.1.100/api/v3"

# Option 3: Configure proxy if required
# Set corporate proxy settings
export HTTP_PROXY="http://proxy.company.com:8080"
export HTTPS_PROXY="http://proxy.company.com:8080"

# Prevention strategies:
# - Test connectivity in deployment scripts
# - Implement fallback GitHub endpoints
# - Add network monitoring to CI/CD pipelines
# - Document network requirements clearly
```

#### GitHub API Rate Limit Edge Cases
```bash
# Failure scenario: Multiple concurrent processes hitting rate limits
# Process 1: ./scripts/analyze-performance.sh &
# Process 2: ./scripts/generate-reports.sh &
# Process 3: ./scripts/cache-cleanup.sh &

# Expected error output:
# ERROR: GitHub API rate limit exceeded
# HTTP 403: API rate limit exceeded for token
# Limit: 5000 requests per hour
# Used: 5000, Remaining: 0, Reset: 2024-07-24T19:00:00Z
# Multiple processes are competing for the same rate limit

# Diagnosis steps:
# 1. Identify all processes using the same token
ps aux | grep -E "(analyze-performance|generate-reports|cache-cleanup)"

# 2. Check current rate limit status
curl -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/rate_limit | jq .

# Recovery procedures:
# 1. Stop competing processes
pkill -f "analyze-performance"
pkill -f "generate-reports"
pkill -f "cache-cleanup"

# 2. Implement process coordination
# Use lock file to prevent concurrent access
if ! flock -xn 200; then
    echo "Another process is using GitHub API"
    exit 1
fi 200>/var/lock/github-api.lock

# 3. Distribute API usage across time
# Stagger process execution
./scripts/analyze-performance.sh
sleep 1800  # 30 minute delay
./scripts/generate-reports.sh

# Prevention strategies:
# - Implement API usage coordination
# - Use separate tokens for different processes
# - Add process-aware rate limiting
# - Monitor API usage across all processes
```

### System Resource Exhaustion Failures

#### Memory Exhaustion During Large Repository Analysis
```bash
# Failure scenario: Large repository causes out-of-memory errors
export GITHUB_REPOSITORY="kubernetes/kubernetes"  # Very large repo
export MAX_PARALLEL_JOBS=32  # Too aggressive for available memory
./scripts/analyze-performance.sh

# Expected error output:
# ERROR: Process killed due to memory exhaustion (OOMKilled)
# Exit code: 137
# Available memory: 4GB, Required memory: ~8GB
# Large repository with 100,000+ workflow runs

# Diagnosis steps:
# 1. Check system memory
free -h
cat /proc/meminfo | grep -E "(MemTotal|MemAvailable)"

# 2. Monitor memory usage during execution
./scripts/analyze-performance.sh &
PID=$!
while kill -0 $PID 2>/dev/null; do
    ps -p $PID -o pid,vsz,rss,comm --no-headers
    sleep 1
done

# 3. Check for memory leaks
valgrind --tool=memcheck --leak-check=full ./scripts/analyze-performance.sh

# Recovery procedures:
# 1. Reduce memory usage
export MAX_PARALLEL_JOBS=2  # Reduce parallelism
export WORKFLOW_ANALYSIS_LIMIT=25  # Limit data processed
export CACHE_TTL=900  # Shorter cache to free memory sooner

# 2. Increase available memory (if possible)
# Add swap space temporarily
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 3. Process in chunks
# Implement batch processing for large repositories
export WORKFLOW_BATCH_SIZE=100
./scripts/analyze-performance-chunked.sh

# Prevention strategies:
# - Add memory usage monitoring
# - Implement adaptive memory management
# - Use streaming processing for large datasets
# - Document memory requirements per repository size
```

#### Disk Space Exhaustion in Cache Directories
```bash
# Failure scenario: Cache directory fills up disk space
./scripts/analyze-performance.sh

# Expected error output:
# ERROR: No space left on device
# Failed to write cache file: /tmp/github-api-cache/workflow_123.json
# Disk usage: /tmp 100% (0 bytes available)

# Diagnosis steps:
# 1. Check disk space
df -h /tmp
du -sh /tmp/github-api-cache /tmp/performance-metrics

# 2. Identify largest cache files
find /tmp/github-api-cache -type f -size +10M -exec ls -lh {} \; | sort -k5 -hr

# Recovery procedures:
# 1. Clean up old cache files immediately
find /tmp/github-api-cache -type f -mtime +1 -delete
find /tmp/performance-metrics -type f -mtime +7 -delete

# 2. Temporarily reduce cache TTL
export CACHE_TTL=300  # 5 minutes only

# 3. Move cache to different location with more space
export GITHUB_API_CACHE_DIR="/var/cache/cca-workflows/github-api"
export METRICS_DIR="/var/cache/cca-workflows/metrics"
mkdir -p "$GITHUB_API_CACHE_DIR" "$METRICS_DIR"

# 4. Implement cache size limits
# Add to cache management
MAX_CACHE_SIZE_MB=1024  # 1GB limit
while [[ $(du -sm /tmp/github-api-cache | cut -f1) -gt $MAX_CACHE_SIZE_MB ]]; do
    find /tmp/github-api-cache -type f -printf '%T@ %p\n' | sort -n | head -n1 | cut -d' ' -f2- | xargs rm -f
done

# Prevention strategies:
# - Implement proactive cache cleanup
# - Monitor disk space usage
# - Set cache size limits
# - Use log rotation for all output files
```

### Networking and Connectivity Failures

#### Corporate Firewall Blocking GitHub API
```bash
# Failure scenario: Corporate firewall blocks GitHub API access
./scripts/analyze-performance.sh

# Expected error output:
# ERROR: Connection to GitHub API failed
# curl: (7) Failed to connect to api.github.com port 443: Connection refused
# Corporate firewall may be blocking HTTPS traffic

# Diagnosis steps:
# 1. Test direct connectivity
curl -I https://api.github.com
telnet api.github.com 443

# 2. Check if proxy is required
curl -I https://api.github.com --proxy-headers
env | grep -i proxy

# 3. Test with alternative endpoints
curl -I https://github.com  # Web interface
curl -I https://raw.githubusercontent.com  # Raw content

# Recovery procedures:
# 1. Configure corporate proxy
export HTTP_PROXY="http://proxy.corporate.com:8080"
export HTTPS_PROXY="http://proxy.corporate.com:8080"
export NO_PROXY="localhost,127.0.0.1,.corporate.com"

# 2. Use proxy with authentication
read -p "Proxy username: " PROXY_USER
read -s -p "Proxy password: " PROXY_PASS
export HTTP_PROXY="http://$PROXY_USER:$PROXY_PASS@proxy.corporate.com:8080"
export HTTPS_PROXY="http://$PROXY_USER:$PROXY_PASS@proxy.corporate.com:8080"

# 3. Try alternative GitHub API endpoints
export GITHUB_API_URL="https://api.github.com"  # Try different base URL
# Or use GitHub Enterprise if available internally

# Prevention strategies:
# - Document proxy requirements in setup guides
# - Add connectivity tests to deployment scripts
# - Provide offline mode for restricted environments
# - Include firewall requirements in documentation
```

#### DNS Resolution Failures
```bash
# Failure scenario: DNS cannot resolve GitHub domains
./scripts/analyze-performance.sh

# Expected error output:
# ERROR: DNS resolution failed for api.github.com
# curl: (6) Could not resolve host: api.github.com
# Name resolution temporarily failed

# Diagnosis steps:
# 1. Test DNS resolution
nslookup api.github.com
dig api.github.com
host api.github.com

# 2. Check DNS configuration
cat /etc/resolv.conf
systemd-resolve --status

# 3. Test with different DNS servers
nslookup api.github.com 8.8.8.8
nslookup api.github.com 1.1.1.1

# Recovery procedures:
# 1. Use alternative DNS servers temporarily
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf.backup
echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf.backup
sudo cp /etc/resolv.conf.backup /etc/resolv.conf

# 2. Restart DNS resolution service
sudo systemctl restart systemd-resolved
sudo systemctl restart networking

# 3. Use IP addresses as fallback
# Get GitHub API IP addresses
nslookup api.github.com 8.8.8.8
# Use IP directly (not recommended for production)
export GITHUB_API_URL="https://140.82.114.5/api/v3"

# 4. Configure DNS caching
sudo apt-get install dnsmasq
echo "server=8.8.8.8" | sudo tee -a /etc/dnsmasq.conf
sudo systemctl restart dnsmasq

# Prevention strategies:
# - Use multiple DNS servers in configuration
# - Implement DNS health checks
# - Add DNS fallback mechanisms
# - Monitor DNS resolution performance
```

### Concurrent Process Management Failures

#### Process Deadlock in Parallel Execution
```bash
# Failure scenario: Multiple processes deadlock on shared resources
export MAX_PARALLEL_JOBS=8
./scripts/analyze-performance.sh

# Symptoms:
# - Multiple processes hang indefinitely
# - No progress in analysis
# - System load remains high but no output

# Diagnosis steps:
# 1. Identify hanging processes
ps aux | grep -E "(analyze-performance|github-api)" | grep -v grep

# 2. Check for file locks
lsof | grep -E "(github-api-cache|performance-metrics)"

# 3. Check process status
for pid in $(pgrep -f "analyze-performance"); do
    echo "Process $pid:"
    cat /proc/$pid/status | grep -E "(State|SigQ|SigPnd)"
    cat /proc/$pid/stack 2>/dev/null || echo "  Stack not available"
done

# Recovery procedures:
# 1. Kill hanging processes
pkill -TERM -f "analyze-performance"
sleep 10
pkill -KILL -f "analyze-performance"  # Force kill if needed

# 2. Clear any lock files
find /tmp -name "*.lock" -type f -delete
find /var/lock -name "*github*" -type f -delete

# 3. Restart with single process to test
export MAX_PARALLEL_JOBS=1
./scripts/analyze-performance.sh

# 4. Implement proper file locking
# Add to scripts:
(
    flock -x 200
    # Critical section code here
) 200>/var/lock/github-api-cache.lock

# Prevention strategies:
# - Implement proper file locking mechanisms
# - Add deadlock detection and recovery
# - Use process coordination tools
# - Add timeout mechanisms for all operations
```

#### Resource Contention Between Processes
```bash
# Failure scenario: Multiple processes compete for limited resources
# Terminal 1: ./scripts/analyze-performance.sh &
# Terminal 2: ./scripts/generate-reports.sh &
# Terminal 3: ./scripts/cache-cleanup.sh &

# Expected symptoms:
# - Processes run much slower than expected
# - High system load average
# - Frequent context switching
# - Cache corruption or inconsistent results

# Diagnosis steps:
# 1. Monitor system load
uptime
vmstat 1 5

# 2. Check process priorities
ps -eo pid,ni,pri,comm,args | grep -E "(analyze|generate|cleanup)"

# 3. Monitor resource usage
iostat -x 1 5
sar -u 1 5

# Recovery procedures:
# 1. Prioritize critical processes
sudo renice -n -10 $(pgrep -f "analyze-performance")
sudo renice -n 5 $(pgrep -f "cache-cleanup")

# 2. Limit concurrent processes
# Use process semaphore
CONCURRENT_LIMIT=2
(
    # Acquire semaphore
    exec 200>/var/lock/process-semaphore
    while ! flock -n 200; do
        sleep 1
    done
    
    # Run process
    ./scripts/analyze-performance.sh
    
    # Release semaphore automatically on exit
) 200>/var/lock/process-semaphore

# 3. Implement process scheduling
# Create job queue system
echo "./scripts/analyze-performance.sh" >> /tmp/job-queue
echo "./scripts/generate-reports.sh" >> /tmp/job-queue
./scripts/job-runner.sh  # Process one job at a time

# Prevention strategies:
# - Implement process coordination mechanisms
# - Add resource usage monitoring
# - Use job scheduling systems for batch processing
# - Document resource requirements for concurrent operations
```

### Data Integrity and Corruption Issues

#### Cache Corruption Detection and Recovery
```bash
# Failure scenario: Cache files become corrupted
./scripts/analyze-performance.sh

# Expected error output:
# ERROR: Cache file corruption detected
# File: /tmp/github-api-cache/workflow_12345.json
# JSON parse error: Unexpected character at position 1024
# Cache integrity check failed

# Diagnosis steps:
# 1. Verify cache file integrity
find /tmp/github-api-cache -name "*.json" -exec jq empty {} \; 2>&1 | grep -v "parse error" || echo "Corrupted files found"

# 2. Check file sizes for anomalies
find /tmp/github-api-cache -name "*.json" -size 0 -o -size +100M

# 3. Verify checksums if available
if [[ -f /tmp/github-api-cache/checksums.sha256 ]]; then
    cd /tmp/github-api-cache && sha256sum -c checksums.sha256
fi

# Recovery procedures:
# 1. Remove corrupted cache files
find /tmp/github-api-cache -name "*.json" -exec sh -c 'jq empty "$1" 2>/dev/null || rm "$1"' _ {} \;

# 2. Clear entire cache if corruption is widespread
rm -rf /tmp/github-api-cache/*
rm -rf /tmp/performance-metrics/*

# 3. Regenerate cache with integrity checking
export ENABLE_CACHE=true
export CACHE_TTL=1800
./scripts/analyze-performance.sh --regenerate-cache

# 4. Implement cache integrity verification
# Add to cache writing:
write_cache_with_integrity() {
    local cache_file="$1"
    local content="$2"
    
    # Write content
    echo "$content" > "$cache_file.tmp"
    
    # Verify JSON validity
    if jq empty "$cache_file.tmp" 2>/dev/null; then
        # Generate checksum
        sha256sum "$cache_file.tmp" > "$cache_file.sha256"
        # Atomic move
        mv "$cache_file.tmp" "$cache_file"
    else
        rm -f "$cache_file.tmp"
        return 1
    fi
}

# Prevention strategies:
# - Implement atomic cache writes
# - Add cache integrity verification
# - Use checksums for cache validation
# - Implement cache auto-repair mechanisms
```

### Emergency Recovery Procedures

#### Complete System Recovery from Failed State
```bash
# Scenario: System is in completely broken state
# - Configuration validation fails
# - Caches are corrupted
# - Processes are hanging
# - Network connectivity issues

# Emergency recovery procedure:
emergency_recovery() {
    echo "Starting emergency recovery procedure..."
    
    # 1. Stop all running processes
    pkill -TERM -f "cca-workflows"
    pkill -TERM -f "analyze-performance"
    pkill -TERM -f "github-api"
    sleep 5
    pkill -KILL -f "cca-workflows"
    pkill -KILL -f "analyze-performance"
    pkill -KILL -f "github-api"
    
    # 2. Clear all caches and temporary files
    rm -rf /tmp/github-api-cache/* 2>/dev/null
    rm -rf /tmp/performance-metrics/* 2>/dev/null
    rm -f /var/lock/*github* 2>/dev/null
    rm -f /var/lock/*cca-workflows* 2>/dev/null
    
    # 3. Reset environment variables
    unset CONFIG_FILE
    unset MAX_PARALLEL_JOBS CACHE_TTL LOG_LEVEL OUTPUT_FORMAT
    unset ENABLE_CACHE ENABLE_BENCHMARKS COLORED_OUTPUT
    unset GITHUB_TOKEN
    
    # 4. Test basic connectivity
    if ! curl -s -o /dev/null https://api.github.com; then
        echo "WARNING: GitHub API connectivity issues detected"
        echo "Check network connectivity and firewall settings"
    fi
    
    # 5. Load minimal configuration
    export MAX_PARALLEL_JOBS=1
    export CACHE_TTL=300
    export LOG_LEVEL=INFO
    export OUTPUT_FORMAT=console
    export ENABLE_CACHE=false  # Disable cache initially
    
    # 6. Test basic functionality
    if ./scripts/validate-config.sh; then
        echo "Basic configuration validation passed"
    else
        echo "ERROR: Cannot achieve basic working state"
        return 1
    fi
    
    echo "Emergency recovery completed. System should be in minimal working state."
    echo "Gradually re-enable features and increase parallelism as needed."
}

# Run emergency recovery
emergency_recovery
```

This comprehensive troubleshooting guide should help you systematically diagnose and resolve most configuration issues in Claude Code Auto Workflows. 

## Feedback and Time Validation

### Help Improve This Guide! 📝

The time estimates in this troubleshooting guide are based on typical scenarios, but actual troubleshooting times can vary. Your feedback helps improve the accuracy of these estimates for everyone.

#### Quick Feedback Collection

When working through troubleshooting steps, you can contribute timing data using our feedback collection tool:

```bash
# Start tracking your troubleshooting session
./scripts/troubleshooting-feedback.sh start <step_id> "Brief description of your issue"

# Work through the troubleshooting steps...

# End the session when done
./scripts/troubleshooting-feedback.sh end <session_id> success|failure
```

#### Interactive Mode (Recommended)

For new users, the interactive mode guides you through the feedback process:

```bash
./scripts/troubleshooting-feedback.sh interactive
```

This will:
1. Show available troubleshooting steps
2. Start timing your session  
3. Wait for you to complete the troubleshooting
4. Collect feedback on difficulty and effectiveness
5. Compare your actual time with estimates

#### Available Step IDs

Common troubleshooting step IDs that correspond to sections in this guide:

| Step ID | Description | Current Estimate |
|---------|-------------|------------------|
| `range_fix` | Configuration value range errors | 2-5 minutes |
| `enum_fix` | Invalid enum/boolean values | 1-3 minutes |
| `dependency_fix` | Missing dependency errors | 5-10 minutes |
| `export_fix` | Environment variable export issues | 2-5 minutes |
| `auth_failure` | GitHub authentication problems | 10-20 minutes |
| `rate_failure` | API rate limiting issues | 15-30 minutes |
| `claude_response` | Claude Code not responding | 10-25 minutes |
| `cache_check` | Cache-related problems | 8-20 minutes |

Use `./scripts/troubleshooting-feedback.sh list-steps` to see all available step IDs.

#### Example Workflow

```bash
# Starting a troubleshooting session
$ ./scripts/troubleshooting-feedback.sh start cache_check "Cache files seem corrupted"
🚀 Started troubleshooting session: troubleshooting_cache_check_1647890123
   Step: cache_check (estimated: 8-20 minutes)
   Description: Cache files seem corrupted
   Use 'end_troubleshooting_session troubleshooting_cache_check_1647890123 [success|failure]' when done

# ... work through the troubleshooting steps in this guide ...

# Ending the session
$ ./scripts/troubleshooting-feedback.sh end troubleshooting_cache_check_1647890123 success
✅ Completed troubleshooting session: troubleshooting_cache_check_1647890123
   Outcome: success
   Actual time: 12.3 minutes
   Estimated time: 8-20 minutes
   🎯 Within estimated time range

📝 Optional: Help improve our time estimates!

How difficult was this troubleshooting step? (1=very easy, 5=very hard) [3]: 2
Were there any blockers or issues not covered in the documentation? (optional): 
What resources or tools were most helpful? (optional): The cache cleanup commands in the guide
Should the time estimate be adjusted? (shorter/longer/accurate) [accurate]: accurate
✅ Thank you for your feedback! This helps improve our documentation.
```

#### For Documentation Maintainers

Maintainers can access comprehensive analytics to understand feedback trends and improve estimates:

```bash
# View analytics dashboard
./scripts/troubleshooting-analytics.sh dashboard

# Get specific recommendations  
./scripts/troubleshooting-analytics.sh recommendations

# Export data for analysis
./scripts/troubleshooting-analytics.sh export json analytics.json
```

The analytics include:
- Success/failure rates per troubleshooting step
- Actual vs estimated time comparisons
- User difficulty ratings and common blockers
- Recommendations for updating time estimates
- Trend analysis over time

#### Privacy and Data Usage

The feedback collection system only stores:
- Troubleshooting step ID and outcome (success/failure)
- Actual time taken (not what you worked on)
- Optional difficulty rating and general feedback
- No personal information or specific system details

All data is stored locally and used only to improve documentation accuracy.

---

For additional configuration topics, see the related documentation:
- **[CONFIGURATION.md](CONFIGURATION.md)** - Core configuration options and basic setup
- **[SECURITY-OVERVIEW.md](../SECURITY-OVERVIEW.md)** - Comprehensive security practices for configuration management
- **[ADVANCED.md](ADVANCED.md)** - Advanced configuration patterns and version compatibility