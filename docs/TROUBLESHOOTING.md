# Configuration Troubleshooting Guide

This guide provides systematic diagnosis and resolution of configuration issues in Claude Code Auto Workflows.

**Related Documentation:**
- [CONFIGURATION.md](CONFIGURATION.md) - Core configuration options and basic setup
- [SECURITY.md](SECURITY.md) - Security considerations and best practices
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

This comprehensive troubleshooting guide should help you systematically diagnose and resolve most configuration issues in Claude Code Auto Workflows. 

For additional configuration topics, see the related documentation:
- **[CONFIGURATION.md](CONFIGURATION.md)** - Core configuration options and basic setup
- **[SECURITY.md](SECURITY.md)** - Comprehensive security practices for configuration management
- **[ADVANCED.md](ADVANCED.md)** - Advanced configuration patterns and version compatibility