# Configuration Guide

This guide covers core configuration options, environment variables, and basic setup for Claude Code Auto Workflows.

**Related Documentation:**

- [SECURITY-OVERVIEW.md](../SECURITY-OVERVIEW.md) - Security overview and quick start guide
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Troubleshooting configuration issues
- [ADVANCED.md](ADVANCED.md) - Advanced configuration patterns and version compatibility
- [PERFORMANCE_TUNING.md](PERFORMANCE_TUNING.md) - Performance optimization using configuration settings

**Cross-References:**

- [Main README Troubleshooting](../README.md#troubleshooting-guide) - General troubleshooting workflow
- [Performance Tuning - Configuration Tuning](PERFORMANCE_TUNING.md#configuration-tuning) - Performance-focused configuration

## Table of Contents

- [Configuration Overview](#configuration-overview)
- [Configuration Files](#configuration-files)
- [Environment Variables](#environment-variables)
- [Configuration Options Reference](#configuration-options-reference)
- [Configuration Validation](#configuration-validation)
- [Environment-Specific Configurations](#environment-specific-configurations)
- [Configuration Best Practices](#configuration-best-practices)
- [Configuration Migration Guide](#configuration-migration-guide)

## Configuration Overview

Claude Code Auto Workflows uses a hierarchical configuration system that allows for flexible customization while providing sensible defaults.

### Configuration Hierarchy

Configuration values are loaded in the following order (later values override earlier ones):

1. **Default Configuration** (`scripts/config/default.conf`)
2. **Environment Variables**
3. **Custom Configuration File** (if specified)
4. **Command-line Arguments** (where applicable)

```mermaid
graph TB
    subgraph "Configuration Sources (Priority Order)"
        A[default.conf<br/>Base configuration]
        B[Environment Variables<br/>Runtime overrides]
        C[Custom Config File<br/>Environment-specific]
        D[Command-line Args<br/>Execution-specific]
    end
    
    subgraph "Configuration Categories"
        CORE[Core Settings<br/>• MAX_PARALLEL_JOBS<br/>• LOG_LEVEL<br/>• OUTPUT_FORMAT]
        CACHE[Cache Settings<br/>• CACHE_TTL<br/>• ENABLE_CACHE<br/>• CACHE_CLEANUP_INTERVAL]
        RATE[Rate Limiting<br/>• RATE_LIMIT_REQUESTS_PER_MINUTE<br/>• RATE_LIMIT_DELAY<br/>• BURST_SIZE]
        ANALYSIS[Analysis Settings<br/>• WORKFLOW_ANALYSIS_LIMIT<br/>• ENABLE_BENCHMARKS<br/>• BENCHMARK_ITERATIONS]
        VALIDATION[Validation Settings<br/>• VALIDATE_SCHEMA<br/>• CHECK_SECURITY<br/>• CHECK_PERFORMANCE]
    end
    
    subgraph "Environment Profiles"
        DEV[Development<br/>• Debug logging<br/>• Fresh cache<br/>• All validations]
        PROD[Production<br/>• Minimal logging<br/>• Efficient cache<br/>• Conservative limits]
        CI[CI/CD<br/>• Structured output<br/>• Fast execution<br/>• No benchmarks]
    end
    
    subgraph "Validation & Loading"
        LOAD[Configuration Loader<br/>load_config()]
        VALIDATE[Configuration Validator<br/>validate_config()]
        FINAL[Final Configuration<br/>Ready for use]
    end
    
    %% Configuration flow
    A --> LOAD
    B --> LOAD
    C --> LOAD
    D --> LOAD
    
    LOAD --> VALIDATE
    VALIDATE --> FINAL
    
    %% Category relationships
    FINAL --> CORE
    FINAL --> CACHE
    FINAL --> RATE
    FINAL --> ANALYSIS
    FINAL --> VALIDATION
    
    %% Profile examples
    DEV -.-> C
    PROD -.-> C
    CI -.-> C
    
    %% Error handling
    VALIDATE -->|Validation Errors| ERROR[Configuration Error<br/>Exit with error code]
    
    %% Styling
    style A fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    style B fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    style C fill:#e8f5e8,stroke:#388e3c,stroke-width:2px
    style D fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    style FINAL fill:#ffebee,stroke:#d32f2f,stroke-width:3px
    style ERROR fill:#ffcdd2,stroke:#c62828,stroke-width:2px
    style LOAD fill:#e1f5fe
    style VALIDATE fill:#f1f8e9
```

### Configuration Loading Process

```bash
# Configuration is loaded via the common.sh module
load_config() {
    local config_file="${1:-}"
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    local default_config="$script_dir/config/default.conf"
    
    # 1. Load default configuration
    if [[ -f "$default_config" ]]; then
        source "$default_config"
    fi
    
    # 2. Environment variables are automatically available
    
    # 3. Load custom config if specified
    if [[ -n "$config_file" && -f "$config_file" ]]; then
        source "$config_file"
    fi
    
    # 4. Validate all configuration
    validate_config
}
```

## Configuration Files

### Default Configuration (`scripts/config/default.conf`)

The default configuration file contains all standard settings with production-ready defaults:

```bash
# scripts/config/default.conf

# Parallel processing configuration
MAX_PARALLEL_JOBS=4
XARGS_PARALLEL_JOBS=4

# Cache configuration
CACHE_TTL=1800  # 30 minutes in seconds
CACHE_CLEANUP_INTERVAL=3600  # 1 hour in seconds

# Rate limiting configuration
RATE_LIMIT_REQUESTS_PER_MINUTE=30
RATE_LIMIT_DELAY=2
BURST_SIZE=5

# Cleanup script defaults
DEFAULT_KEEP_DAYS=30
DEFAULT_MAX_RUNS=100

# Performance analysis configuration
ENABLE_BENCHMARKS=false
ENABLE_LOAD_TESTS=false
OUTPUT_FORMAT=console

# Validation configuration
ENABLE_CACHE=true
VALIDATE_SCHEMA=true
CHECK_SECURITY=true
CHECK_PERFORMANCE=true

# Logging configuration
LOG_LEVEL=INFO  # DEBUG, INFO, WARN, ERROR
COLORED_OUTPUT=true
```

### Custom Configuration Files

You can create custom configuration files for different environments:

#### Development Configuration (`config/development.conf`)

```bash
# Development-specific settings
MAX_PARALLEL_JOBS=2
CACHE_TTL=300  # 5 minutes for fresh data
ENABLE_BENCHMARKS=true
LOG_LEVEL=DEBUG
COLORED_OUTPUT=true
OUTPUT_FORMAT=console

# Enable all validation for development
VALIDATE_SCHEMA=true
CHECK_SECURITY=true
CHECK_PERFORMANCE=true
```

#### Production Configuration (`config/production.conf`)

```bash
# Production-optimized settings
MAX_PARALLEL_JOBS=8
CACHE_TTL=3600  # 1 hour for efficiency
ENABLE_BENCHMARKS=false
LOG_LEVEL=WARN
COLORED_OUTPUT=false
OUTPUT_FORMAT=json

# Conservative rate limiting
RATE_LIMIT_REQUESTS_PER_MINUTE=15
RATE_LIMIT_DELAY=4

# Extended retention for production
DEFAULT_KEEP_DAYS=90
DEFAULT_MAX_RUNS=500
```

#### CI/CD Configuration (`config/ci.conf`)

```bash
# CI/CD environment settings
MAX_PARALLEL_JOBS=4
CACHE_TTL=1800
ENABLE_BENCHMARKS=false
ENABLE_LOAD_TESTS=false
LOG_LEVEL=INFO
COLORED_OUTPUT=false
OUTPUT_FORMAT=json

# Faster execution for CI
WORKFLOW_ANALYSIS_LIMIT=25
BENCHMARK_ITERATIONS=3
```

### Using Custom Configuration Files

```bash
# Specify custom configuration file
CONFIG_FILE="config/production.conf" ./scripts/analyze-performance.sh

# Or export as environment variable
export CONFIG_FILE="config/development.conf"
./scripts/analyze-performance.sh

# Multiple custom configs (later overrides earlier)
CONFIG_FILE="config/base.conf:config/local.conf" ./scripts/analyze-performance.sh
```

## Environment Variables

All configuration options can be overridden using environment variables. Environment variables take precedence over configuration files.

### Core Environment Variables

#### Parallel Processing

```bash
# Number of parallel jobs for CPU-intensive tasks
export MAX_PARALLEL_JOBS=8

# Number of parallel jobs for xargs-based operations
export XARGS_PARALLEL_JOBS=8

# Override in specific contexts
export GITHUB_API_PARALLEL_JOBS=4  # Specific to API operations
```

#### Caching

```bash
# Cache time-to-live in seconds
export CACHE_TTL=1800

# Cache cleanup interval in seconds
export CACHE_CLEANUP_INTERVAL=3600

# Cache directory locations
export GITHUB_API_CACHE_DIR="/tmp/github-api-cache"
export METRICS_DIR="/tmp/performance-metrics"

# Enable/disable caching
export ENABLE_CACHE=true
```

#### Rate Limiting

```bash
# GitHub API rate limiting
export RATE_LIMIT_REQUESTS_PER_MINUTE=30
export RATE_LIMIT_DELAY=2
export BURST_SIZE=5

# Rate limit buffer (requests to keep in reserve)
export GITHUB_API_RATE_LIMIT_BUFFER=100
```

#### Analysis Configuration

```bash
# Workflow analysis settings
export WORKFLOW_ANALYSIS_LIMIT=50
export WORKFLOW_MIN_CACHE_PERCENTAGE=50

# Performance testing
export ENABLE_BENCHMARKS=false
export ENABLE_LOAD_TESTS=false
export BENCHMARK_ITERATIONS=5

# Load testing configuration
export LOAD_TEST_CONCURRENT=10
export LOAD_TEST_TOTAL=100
export LOAD_TEST_DURATION=60
```

#### Output Configuration

```bash
# Output format: console, json, markdown
export OUTPUT_FORMAT=console

# Output file (optional)
export OUTPUT_FILE=""

# Logging configuration
export LOG_LEVEL=INFO  # DEBUG, INFO, WARN, ERROR
export COLORED_OUTPUT=true
```

#### Validation Configuration

```bash
# Enable/disable various validation checks
export VALIDATE_SCHEMA=true
export CHECK_SECURITY=true
export CHECK_PERFORMANCE=true
```

#### Cleanup Configuration

```bash
# Default retention settings
export DEFAULT_KEEP_DAYS=30
export DEFAULT_MAX_RUNS=100

# Metrics retention
export METRICS_RETENTION_DAYS=30
```

### GitHub-Specific Variables

```bash
# GitHub authentication
export GITHUB_TOKEN="your-github-token"

# GitHub API configuration
export GITHUB_API_URL="https://api.github.com"
export GITHUB_ENTERPRISE_URL=""  # For GitHub Enterprise

# Repository context (usually auto-detected)
export GITHUB_REPOSITORY="owner/repo"
export GITHUB_REF="refs/heads/main"
```

### System-Specific Variables

```bash
# Temporary directory location
export TMPDIR="/tmp"

# Timezone for timestamps
export TZ="UTC"

# Process priority adjustment
export NICE_LEVEL=0

# Memory constraints
export MAX_MEMORY_MB=1024
```

## Configuration Options Reference

### Parallel Processing Options

| Option | Type | Default | Description | Valid Range |
|--------|------|---------|-------------|-------------|
| `MAX_PARALLEL_JOBS` | Integer | 4 | Maximum number of parallel processes | 1-32 |
| `XARGS_PARALLEL_JOBS` | Integer | 4 | Parallel jobs for xargs operations | 1-32 |

**Usage Examples:**

```bash
# Conservative setting for low-resource systems
export MAX_PARALLEL_JOBS=2

# Aggressive setting for high-performance systems
export MAX_PARALLEL_JOBS=16

# Auto-detect optimal setting
export MAX_PARALLEL_JOBS=$(nproc)
```

**Performance Impact:**

- **Too low**: Underutilizes system resources
- **Too high**: Can cause resource contention and system instability
- **Optimal**: Usually 1-2x CPU core count

**See also:** [Performance Tuning - Parallel Processing Optimization](PERFORMANCE_TUNING.md#parallel-processing-optimization)

### Cache Configuration Options

| Option | Type | Default | Description | Valid Range |
|--------|------|---------|-------------|-------------|
| `CACHE_TTL` | Integer | 1800 | Cache time-to-live in seconds | 60-86400 |
| `CACHE_CLEANUP_INTERVAL` | Integer | 3600 | Cache cleanup frequency in seconds | 300-86400 |
| `ENABLE_CACHE` | Boolean | true | Enable/disable caching | true, false |

**Cache TTL Guidelines:**

```bash
# Development: Short TTL for fresh data
export CACHE_TTL=300    # 5 minutes

# Production: Longer TTL for efficiency
export CACHE_TTL=3600   # 1 hour

# Batch processing: Maximum TTL
export CACHE_TTL=7200   # 2 hours
```

**See also:**

- [Performance Tuning - Caching Strategies](PERFORMANCE_TUNING.md#caching-strategies)
- [Performance Tuning - Cache Performance Issues](PERFORMANCE_TUNING.md#2-poor-cache-performance)

### Rate Limiting Options

| Option | Type | Default | Description | Valid Range |
|--------|------|---------|-------------|-------------|
| `RATE_LIMIT_REQUESTS_PER_MINUTE` | Integer | 30 | Maximum API requests per minute | 1-120 |
| `RATE_LIMIT_DELAY` | Integer | 2 | Delay between requests in seconds | 1-10 |
| `BURST_SIZE` | Integer | 5 | Number of burst requests allowed | 1-20 |

**Rate Limiting Strategies:**

```bash
# Conservative (shared environments)
export RATE_LIMIT_REQUESTS_PER_MINUTE=15
export RATE_LIMIT_DELAY=4

# Balanced (typical usage)
export RATE_LIMIT_REQUESTS_PER_MINUTE=30  
export RATE_LIMIT_DELAY=2

# Aggressive (with GitHub App token)
export RATE_LIMIT_REQUESTS_PER_MINUTE=60
export RATE_LIMIT_DELAY=1
```

**See also:**

- [Performance Tuning - Rate Limit Management](PERFORMANCE_TUNING.md#rate-limit-management)
- [Main README - Rate Limiting Troubleshooting](../README.md#troubleshooting-guide)

### Logging Configuration Options

#### LOG_LEVEL Enum Documentation

The `LOG_LEVEL` configuration option controls the verbosity of logging output.

| LOG_LEVEL | Description | Use Case | Output Content |
|-----------|-------------|----------|----------------|
| `DEBUG` | Most verbose logging | Development, troubleshooting | All messages including debug traces |
| `INFO` | Informational messages | Normal operation, monitoring | Standard operational messages |
| `WARN` | Warning messages only | Production with minimal noise | Warnings and errors only |
| `ERROR` | Error messages only | Critical monitoring | Error messages only |

**LOG_LEVEL Examples:**

```bash
# Development environment - see everything
export LOG_LEVEL=DEBUG

# Production monitoring - balanced output
export LOG_LEVEL=INFO

# Production with minimal logging
export LOG_LEVEL=WARN

# Error-only logging for critical systems
export LOG_LEVEL=ERROR
```

**LOG_LEVEL Validation:**

```bash
# The configuration validation ensures LOG_LEVEL is valid
validate_log_level() {
    case "$LOG_LEVEL" in
        DEBUG|INFO|WARN|ERROR)
            return 0
            ;;
        *)
            log_error "Invalid LOG_LEVEL: '$LOG_LEVEL'. Must be one of: DEBUG, INFO, WARN, ERROR"
            return 1
            ;;
    esac
}
```

#### Other Logging Options

| Option | Type | Default | Description | Valid Values |
|--------|------|---------|-------------|--------------|
| `COLORED_OUTPUT` | Boolean | true | Enable colored console output | true, false |

### Analysis Configuration Options

| Option | Type | Default | Description | Valid Range |
|--------|------|---------|-------------|-------------|
| `WORKFLOW_ANALYSIS_LIMIT` | Integer | 50 | Number of workflow runs to analyze | 10-200 |
| `ENABLE_BENCHMARKS` | Boolean | false | Enable performance benchmarking | true, false |
| `ENABLE_LOAD_TESTS` | Boolean | false | Enable load testing | true, false |
| `BENCHMARK_ITERATIONS` | Integer | 5 | Number of benchmark iterations | 3-20 |

### Output Configuration Options

| Option | Type | Default | Description | Valid Values |
|--------|------|---------|-------------|--------------|
| `OUTPUT_FORMAT` | String | console | Output format | console, json, markdown |
| `OUTPUT_FILE` | String | "" | Output file path (optional) | Any valid file path |

**Output Format Examples:**

```bash
# Console output with colors (default)
export OUTPUT_FORMAT=console
export COLORED_OUTPUT=true

# JSON output for automation
export OUTPUT_FORMAT=json
export OUTPUT_FILE="analysis-report.json"

# Markdown for documentation
export OUTPUT_FORMAT=markdown
export OUTPUT_FILE="analysis-report.md"
```

### Validation Configuration Options

| Option | Type | Default | Description | Impact |
|--------|------|---------|-------------|---------|
| `VALIDATE_SCHEMA` | Boolean | true | Validate configuration schema | Performance: Low |
| `CHECK_SECURITY` | Boolean | true | Perform security checks | Performance: Medium |
| `CHECK_PERFORMANCE` | Boolean | true | Perform performance validation | Performance: High |

## Configuration Validation

The system performs comprehensive configuration validation to ensure all settings are valid and compatible.

**See also:** [Performance Tuning - Troubleshooting Performance Issues](PERFORMANCE_TUNING.md#troubleshooting-performance-issues)

### Validation Process

```bash
validate_config() {
    local validation_errors=0
    
    # Validate numeric values
    if [[ ! "$MAX_PARALLEL_JOBS" =~ ^[0-9]+$ ]] || [[ "$MAX_PARALLEL_JOBS" -lt 1 ]] || [[ "$MAX_PARALLEL_JOBS" -gt 32 ]]; then
        log_error "Invalid MAX_PARALLEL_JOBS: $MAX_PARALLEL_JOBS (must be 1-32)"
        ((validation_errors++))
    fi
    
    if [[ ! "$CACHE_TTL" =~ ^[0-9]+$ ]] || [[ "$CACHE_TTL" -lt 60 ]] || [[ "$CACHE_TTL" -gt 86400 ]]; then
        log_error "Invalid CACHE_TTL: $CACHE_TTL (must be 60-86400 seconds)"
        ((validation_errors++))
    fi
    
    # Validate boolean values
    case "$ENABLE_CACHE" in
        true|false) ;;
        *) log_error "Invalid ENABLE_CACHE: $ENABLE_CACHE (must be true or false)"; ((validation_errors++)) ;;
    esac
    
    # Validate enum values
    case "$LOG_LEVEL" in
        DEBUG|INFO|WARN|ERROR) ;;
        *) log_error "Invalid LOG_LEVEL: $LOG_LEVEL (must be DEBUG, INFO, WARN, or ERROR)"; ((validation_errors++)) ;;
    esac
    
    case "$OUTPUT_FORMAT" in
        console|json|markdown) ;;
        *) log_error "Invalid OUTPUT_FORMAT: $OUTPUT_FORMAT (must be console, json, or markdown)"; ((validation_errors++)) ;;
    esac
    
    # Validate relationships between options
    if [[ "$ENABLE_BENCHMARKS" == "true" && "$BENCHMARK_ITERATIONS" -lt 3 ]]; then
        log_error "BENCHMARK_ITERATIONS must be at least 3 when ENABLE_BENCHMARKS is true"
        ((validation_errors++))
    fi
    
    if [[ "$RATE_LIMIT_REQUESTS_PER_MINUTE" -gt 60 && "$RATE_LIMIT_DELAY" -lt 1 ]]; then
        log_warn "High request rate with low delay may cause rate limiting issues"
    fi
    
    # Return validation status
    return $validation_errors
}
```

### Configuration Validation Failure Scenarios

The following comprehensive examples demonstrate common validation failures, their causes, and recovery procedures:

#### Numeric Range Validation Failures

**Scenario 1: MAX_PARALLEL_JOBS Out of Range**

```bash
# Failure case: Value too high
export MAX_PARALLEL_JOBS=50
./scripts/analyze-performance.sh

# Expected error output:
┌─────────────────────────────────────────────────────────────────┐
│ [ERROR] Configuration Validation: Invalid MAX_PARALLEL_JOBS     │
│ Code: INVALID_PARALLEL_JOBS_RANGE                               │
│ Detail: Value 50 exceeds maximum allowed (must be 1-32)        │
│ Cause: System resource limit exceeded                          │
│ Exit Code: 1                                                    │
└─────────────────────────────────────────────────────────────────┘

# 🕐 Estimated Time: 2-5 minutes
# 🔴 CRITICAL - Invalid configuration prevents system startup

# Recovery procedure:
# Set to system-appropriate value (typically 1x-2x CPU cores)
export MAX_PARALLEL_JOBS=8
# Verify configuration is now valid
./scripts/validate-config.sh

# Prevention strategy:
# - Use auto-detection: export MAX_PARALLEL_JOBS=$(nproc)
# - Document valid ranges in configuration files
# - Implement configuration templates with safe defaults
```

**Scenario 2: CACHE_TTL Invalid Range**

```bash
# Failure case: Value too low
export CACHE_TTL=30
CONFIG_FILE="config/production.conf" ./scripts/validate-config.sh

# Expected error output:
┌─────────────────────────────────────────────────────────────────┐
│ [ERROR] Configuration Validation: Invalid CACHE_TTL             │
│ Code: INVALID_CACHE_TTL_RANGE                                   │
│ Detail: Value 30 below minimum threshold (must be 60-86400)    │
│ Cause: Cache TTL too short for effective caching               │
│ Exit Code: 1                                                    │
└─────────────────────────────────────────────────────────────────┘

# 🕐 Estimated Time: 1-3 minutes
# 🔴 CRITICAL - Invalid configuration prevents system startup

# Recovery procedure:
# Set to minimum acceptable value (5 minutes)
export CACHE_TTL=300
# Verify configuration is now valid
./scripts/validate-config.sh

# Prevention strategy:
# - Use environment-specific minimums (dev: 300s, prod: 1800s)
# - Add validation comments in configuration files
# - Implement configuration profiles with validated defaults
```

#### Boolean Value Validation Failures

**Scenario 3: Invalid Boolean Format**

```bash
# Failure case: Wrong boolean format
export ENABLE_CACHE=yes
export COLORED_OUTPUT=1
./scripts/analyze-performance.sh

# Expected error output:
┌─────────────────────────────────────────────────────────────────┐
│ [ERROR] Configuration Validation: Invalid boolean format        │
│ Code: INVALID_BOOLEAN_FORMAT                                    │
│ Detail: ENABLE_CACHE='yes' (must be true or false)             │
│         COLORED_OUTPUT='1' (must be true or false)             │
│ Cause: Non-standard boolean values used                        │
│ Exit Code: 1                                                    │
└─────────────────────────────────────────────────────────────────┘

# 🕐 Estimated Time: 1-2 minutes
# 🔴 CRITICAL - Invalid configuration prevents system startup

# Recovery procedure:
# Set boolean values using standard format (true/false)
export ENABLE_CACHE=true
export COLORED_OUTPUT=true
# Verify configuration is now valid
./scripts/validate-config.sh

# Prevention strategy:
# - Document boolean format requirements clearly
# - Use configuration validation in CI/CD pipelines
# - Provide boolean conversion helper functions
```

#### Enum Value Validation Failures

**Scenario 4: Invalid LOG_LEVEL**

```bash
# Failure case: Invalid log level
export LOG_LEVEL=VERBOSE
CONFIG_FILE="config/development.conf" ./scripts/validate-config.sh

# Expected error output:
┌─────────────────────────────────────────────────────────────────┐
│ [ERROR] Configuration Validation: Invalid LOG_LEVEL             │
│ Code: INVALID_LOG_LEVEL_ENUM                                    │
│ Detail: Value 'VERBOSE' not supported                          │
│ Valid Options: DEBUG, INFO, WARN, ERROR                        │
│ Exit Code: 1                                                    │
└─────────────────────────────────────────────────────────────────┘

# 🕐 Estimated Time: 1-2 minutes
# 🔴 CRITICAL - Invalid configuration prevents system startup

# Recovery procedure:
# Set to valid log level (DEBUG for verbose logging)
export LOG_LEVEL=DEBUG
# Verify configuration is now valid
./scripts/validate-config.sh

# Prevention strategy:
# - Provide enum validation with helpful error messages
# - List all valid options in error messages
# - Use configuration templates with valid examples
```

**Scenario 5: Invalid OUTPUT_FORMAT**

```bash
# Failure case: Unsupported output format
export OUTPUT_FORMAT=xml
./scripts/analyze-performance.sh --format xml

# Expected error output:
┌─────────────────────────────────────────────────────────────────┐
│ [ERROR] Configuration Validation: Invalid OUTPUT_FORMAT         │
│ Code: INVALID_OUTPUT_FORMAT_ENUM                                │
│ Detail: Format 'xml' not supported                             │
│ Valid Options: console, json, markdown                         │
│   • console: Human-readable output with colors                 │
│   • json: Structured output for automation                     │
│   • markdown: Documentation-friendly format                    │
│ Exit Code: 1                                                    │
└─────────────────────────────────────────────────────────────────┘

# 🕐 Estimated Time: 1-2 minutes
# 🔴 CRITICAL - Invalid configuration prevents system startup

# Recovery procedure:
# Set to valid output format (json for structured data)
export OUTPUT_FORMAT=json
# Verify configuration is now valid
./scripts/validate-config.sh

# Prevention strategy:
# - Provide format examples in documentation
# - Implement format auto-detection based on environment
# - Add format validation early in script execution
```

#### Configuration Dependency Failures

**Scenario 6: Conflicting Configuration Dependencies**

```bash
# Failure case: Benchmark enabled but insufficient iterations
export ENABLE_BENCHMARKS=true
export BENCHMARK_ITERATIONS=1
./scripts/analyze-performance.sh --benchmarks

# Expected error output:
# ERROR: BENCHMARK_ITERATIONS must be at least 3 when ENABLE_BENCHMARKS is true
# Current value: 1, minimum required: 3
# Benchmarking requires multiple iterations for statistical accuracy

# Recovery procedure:
export BENCHMARK_ITERATIONS=5  # Use recommended value
./scripts/validate-config.sh

# Prevention strategy:
# - Implement dependency validation rules
# - Provide configuration profiles with validated combinations
# - Document configuration dependencies clearly
```

**Scenario 7: Rate Limiting Configuration Conflicts**

```bash
# Failure case: Aggressive rate limiting with high delay
export RATE_LIMIT_REQUESTS_PER_MINUTE=60
export RATE_LIMIT_DELAY=10
./scripts/analyze-performance.sh

# Expected error output:
# WARNING: High request rate (60/min) with high delay (10s) may cause performance issues
# This configuration allows 60 requests per minute but delays 10 seconds between requests
# Effective rate will be much lower than configured limit

# Recovery procedure:
export RATE_LIMIT_DELAY=1  # Use appropriate delay for high rate
./scripts/validate-config.sh

# Prevention strategy:
# - Implement rate limiting calculation validation
# - Provide rate limiting configuration examples
# - Add warnings for suboptimal configurations
```

#### File and Permission Validation Failures

**Scenario 8: Configuration File Access Issues**

```bash
# Failure case: Configuration file not readable
CONFIG_FILE="/etc/cca-workflows/restricted.conf" ./scripts/validate-config.sh

# Expected error output:
# ERROR: Cannot read configuration file: /etc/cca-workflows/restricted.conf
# Permission denied (check file permissions and ownership)
# Current user: developer, File owner: root, Permissions: 600

# Recovery procedure:
# Option 1: Fix permissions
sudo chmod 644 /etc/cca-workflows/restricted.conf

# Option 2: Use accessible configuration file
CONFIG_FILE="config/development.conf" ./scripts/validate-config.sh

# Prevention strategy:
# - Use consistent file permissions (644 for shared configs)
# - Document required permissions in deployment guides
# - Implement permission checking in configuration loading
```

#### Environment-Specific Validation Failures

**Scenario 9: Production Configuration Missing Required Values**

```bash
# Failure case: Production environment with placeholder values
export ENVIRONMENT=production
export GITHUB_TOKEN="PLACEHOLDER"
./scripts/analyze-performance.sh

# Expected error output:
# ERROR: Production environment detected with placeholder values
# The following variables must be set in production:
#   - GITHUB_TOKEN: Currently set to 'PLACEHOLDER'
# Use environment variables or secure configuration management

# Recovery procedure:
export GITHUB_TOKEN="your-actual-github-token"
./scripts/validate-config.sh

# Prevention strategy:
# - Implement environment-specific validation rules
# - Use secret management systems in production
# - Add pre-deployment validation checks
```

#### Configuration Loading Sequence Failures

**Scenario 10: Configuration Override Precedence Issues**

```bash
# Failure case: Environment variable not overriding config file
echo "MAX_PARALLEL_JOBS=2" > config/test.conf
export MAX_PARALLEL_JOBS=8
CONFIG_FILE="config/test.conf" ./scripts/debug-config.sh

# Expected output shows precedence issue:
# Configuration loaded from: config/test.conf
# Final MAX_PARALLEL_JOBS value: 2 (expected: 8)
# Issue: Configuration file loaded after environment variables

# Recovery procedure:
# Check configuration loading order in load_config() function
# Ensure environment variables are processed after config files

# Prevention strategy:
# - Document configuration precedence clearly
# - Test configuration loading order
# - Provide configuration debugging tools
```

### Configuration Validation Recovery Procedures

#### Generic Recovery Steps

1. **Identify the Specific Error**: Run `./scripts/validate-config.sh` to get detailed error messages
2. **Check Configuration Precedence**: Use `./scripts/debug-config.sh` to see final values
3. **Fix the Root Cause**: Address the specific validation failure
4. **Re-validate**: Run validation again to confirm the fix
5. **Test Functionality**: Run a basic operation to ensure configuration works

#### Emergency Recovery

```bash
# Reset to safe defaults if configuration is completely broken
unset CONFIG_FILE
unset MAX_PARALLEL_JOBS CACHE_TTL LOG_LEVEL OUTPUT_FORMAT
unset ENABLE_CACHE ENABLE_BENCHMARKS COLORED_OUTPUT

# Use default configuration
./scripts/validate-config.sh

# If defaults work, gradually add custom settings
export MAX_PARALLEL_JOBS=4
./scripts/validate-config.sh

export CACHE_TTL=1800  
./scripts/validate-config.sh
# Continue adding settings one by one
```

### Manual Configuration Validation

```bash
# Validate current configuration
./scripts/validate-config.sh

# Validate specific configuration file
CONFIG_FILE="config/production.conf" ./scripts/validate-config.sh

# Validate with environment overrides
MAX_PARALLEL_JOBS=16 CACHE_TTL=300 ./scripts/validate-config.sh

# Debug configuration issues
./scripts/debug-config.sh
```

### Configuration Test Script

```bash
#!/bin/bash
# validate-config.sh - Standalone configuration validation

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib/common.sh"

# Load configuration
load_config "${CONFIG_FILE:-}"

echo "Configuration Validation Report"
echo "==============================="
echo
echo "Core Configuration:"
echo "  MAX_PARALLEL_JOBS: $MAX_PARALLEL_JOBS"
echo "  CACHE_TTL: $CACHE_TTL"
echo "  LOG_LEVEL: $LOG_LEVEL"
echo "  OUTPUT_FORMAT: $OUTPUT_FORMAT"
echo
echo "Cache Configuration:"
echo "  ENABLE_CACHE: $ENABLE_CACHE"
echo "  CACHE_CLEANUP_INTERVAL: $CACHE_CLEANUP_INTERVAL"
echo
echo "Rate Limiting:"
echo "  RATE_LIMIT_REQUESTS_PER_MINUTE: $RATE_LIMIT_REQUESTS_PER_MINUTE"
echo "  RATE_LIMIT_DELAY: $RATE_LIMIT_DELAY"
echo "  BURST_SIZE: $BURST_SIZE"
echo

# Perform validation
if validate_config; then
    echo "✅ Configuration validation passed"
    exit 0
else
    echo "❌ Configuration validation failed"
    exit 1
fi
```

## Environment-Specific Configurations

### Development Environment

**Optimized for rapid iteration and debugging:**

```bash
# config/development.conf
MAX_PARALLEL_JOBS=2              # Conservative for development machines
CACHE_TTL=300                    # 5 minutes - fresh data for development
ENABLE_BENCHMARKS=true           # Enable for performance monitoring
ENABLE_LOAD_TESTS=false          # Skip expensive load tests
LOG_LEVEL=DEBUG                  # Verbose logging for debugging
COLORED_OUTPUT=true              # Enhanced readability
OUTPUT_FORMAT=console            # Human-readable output
VALIDATE_SCHEMA=true             # Catch configuration errors early
CHECK_SECURITY=true              # Important for security awareness
CHECK_PERFORMANCE=true           # Monitor development performance

# Development-specific settings
WORKFLOW_ANALYSIS_LIMIT=25       # Smaller dataset for faster iteration
BENCHMARK_ITERATIONS=3           # Fewer iterations for speed
```

**Usage:**

```bash
export CONFIG_FILE="config/development.conf"
./scripts/analyze-performance.sh
```

### Production Environment

**Optimized for reliability and efficiency:**

```bash
# config/production.conf
MAX_PARALLEL_JOBS=8              # Higher parallelism for production
CACHE_TTL=3600                   # 1 hour - efficient caching
ENABLE_BENCHMARKS=false          # Skip benchmarks in production
ENABLE_LOAD_TESTS=false          # Skip load tests in production
LOG_LEVEL=WARN                   # Minimal logging noise
COLORED_OUTPUT=false             # No colors for log processing
OUTPUT_FORMAT=json               # Structured output for automation
VALIDATE_SCHEMA=true             # Prevent configuration errors
CHECK_SECURITY=true              # Critical for production security
CHECK_PERFORMANCE=false          # Skip expensive performance checks

# Production reliability settings
DEFAULT_KEEP_DAYS=90             # Longer retention
DEFAULT_MAX_RUNS=500             # More historical data
RATE_LIMIT_REQUESTS_PER_MINUTE=15 # Conservative rate limiting
RATE_LIMIT_DELAY=4               # Slower, more reliable
```

**Usage:**

```bash
export CONFIG_FILE="config/production.conf"
./scripts/analyze-performance.sh --output production-report.json
```

### CI/CD Environment

**Optimized for fast, reliable automated execution:**

```bash
# config/ci.conf
MAX_PARALLEL_JOBS=4              # Match typical CI runner specs
CACHE_TTL=1800                   # 30 minutes - balance speed and freshness
ENABLE_BENCHMARKS=false          # Skip benchmarks in CI
ENABLE_LOAD_TESTS=false          # Skip load tests in CI
LOG_LEVEL=INFO                   # Informational logging for CI logs
COLORED_OUTPUT=false             # No colors in CI logs
OUTPUT_FORMAT=json               # Structured output for CI processing
VALIDATE_SCHEMA=true             # Catch configuration errors in CI
CHECK_SECURITY=true              # Important for CI security
CHECK_PERFORMANCE=false          # Skip expensive checks in CI

# CI-specific optimizations
WORKFLOW_ANALYSIS_LIMIT=25       # Faster execution
BENCHMARK_ITERATIONS=3           # Minimal benchmarking if needed
CACHE_CLEANUP_INTERVAL=1800      # More frequent cleanup
```

**Usage in GitHub Actions:**

```yaml
- name: Run Performance Analysis
  run: |
    export CONFIG_FILE="config/ci.conf"
    ./scripts/analyze-performance.sh --format json --output ci-report.json
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### High-Performance Environment

**Optimized for maximum throughput:**

```bash
# config/high-performance.conf
MAX_PARALLEL_JOBS=16             # Maximum parallelism
CACHE_TTL=7200                   # 2 hours - maximum caching
ENABLE_BENCHMARKS=true           # Monitor high-performance optimizations
ENABLE_LOAD_TESTS=true           # Stress test the system
LOG_LEVEL=ERROR                  # Minimal logging overhead
COLORED_OUTPUT=false            # No color processing overhead
OUTPUT_FORMAT=json               # Efficient structured output

# High-performance optimizations
WORKFLOW_ANALYSIS_LIMIT=100      # Process more data
BENCHMARK_ITERATIONS=10          # More accurate benchmarks
RATE_LIMIT_REQUESTS_PER_MINUTE=60 # Aggressive rate limiting
RATE_LIMIT_DELAY=1               # Minimal delays
BURST_SIZE=15                    # Larger burst allowance

# Resource optimization
GITHUB_API_CACHE_DIR="/dev/shm/github-api-cache"  # RAM disk caching
METRICS_DIR="/dev/shm/performance-metrics"        # RAM disk for metrics
```

## Configuration Best Practices

### 1. Environment Separation

**Use separate configurations for each environment:**

```bash
# Recommended directory structure
config/
├── default.conf         # Base configuration
├── development.conf     # Development overrides
├── staging.conf        # Staging environment
├── production.conf     # Production settings
└── ci.conf            # CI/CD pipeline settings
```

### 2. Version Control

**Track configuration changes:**

```bash
# Add all config files to version control
git add config/*.conf

# Use meaningful commit messages for config changes
git commit -m "config: increase cache TTL for production performance"

# Tag configuration releases
git tag -a config-v1.2 -m "Configuration release 1.2"
```

### 3. Configuration Documentation

**Document configuration decisions:**

```bash
# config/production.conf
# Production Configuration
# Last updated: 2024-07-24
# 
# Performance tuning decisions:
# - MAX_PARALLEL_JOBS=8: Based on production server specs (8-core CPU)
# - CACHE_TTL=3600: Balances performance vs data freshness for hourly reports
# - LOG_LEVEL=WARN: Reduces log noise while preserving important warnings
#
# Rate limiting decisions:
# - RATE_LIMIT_REQUESTS_PER_MINUTE=30: Conservative limit to avoid rate limiting
# - RATE_LIMIT_DELAY=2: Provides buffer time between requests

MAX_PARALLEL_JOBS=8
CACHE_TTL=3600
LOG_LEVEL=WARN
# ... rest of configuration
```

### 4. Configuration Validation in CI

**Validate configurations in CI/CD:**

```yaml
# .github/workflows/config-validation.yml
name: Configuration Validation
on:
  pull_request:
    paths:
      - 'config/**'
      - 'scripts/config/**'

jobs:
  validate-config:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Validate all configurations
        run: |
          for config_file in config/*.conf; do
            echo "Validating $config_file"
            CONFIG_FILE="$config_file" ./scripts/validate-config.sh
          done
```

### 5. Performance Testing Configuration Changes

**Test configuration changes systematically:**

```bash
# test-config-performance.sh
# Performance test for configuration changes

run_performance_test() {
    local config_file="$1"
    local test_name="$2"
    
    echo "Testing configuration: $test_name"
    
    # Run performance analysis with specific config
    local start_time end_time duration
    start_time=$(date +%s)
    CONFIG_FILE="$config_file" ./scripts/analyze-performance.sh --benchmarks > "test-results-$test_name.log" 2>&1
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    echo "  Duration: ${duration}s"
    
    # Extract key metrics
    if grep -q "✅ All modules initialized successfully" "test-results-$test_name.log"; then
        echo "  Status: SUCCESS"
    else
        echo "  Status: FAILURE"
    fi
}

# Test different configurations
run_performance_test "config/default.conf" "default"
run_performance_test "config/optimized.conf" "optimized"
run_performance_test "config/high-performance.conf" "high-performance"
```

## Configuration Migration Guide

This section provides comprehensive guidance for upgrading configurations between different versions of Claude Code Auto Workflows.

### Migration Overview

Claude Code Auto Workflows uses a versioned configuration system that ensures backward compatibility while introducing new features and optimizations. Migration between versions typically involves:

1. **Configuration Schema Updates**: New configuration options with sensible defaults
2. **Deprecation Handling**: Gradual phase-out of obsolete settings
3. **Performance Optimizations**: Enhanced default values for better performance
4. **Security Enhancements**: Improved security-related configuration options

### Version Migration Paths

#### From Version 1.x to 2.0.0

**Overview:** Version 2.0.0 introduced system health monitoring, enhanced CI pipeline, and performance optimizations.

**Key Changes:**

- Enhanced error handling and retry mechanisms
- New performance monitoring configuration
- Improved rate limiting and caching strategies
- Enhanced security scanning integration

**Step-by-Step Migration:**

1. **Backup Current Configuration**

   ```bash
   # Backup existing configuration files
   cp config/production.conf config/production.conf.v1.backup
   cp scripts/config/default.conf scripts/config/default.conf.v1.backup
   ```

2. **Update Configuration Schema**

   ```bash
   # No breaking changes - existing configurations remain valid
   # New defaults are automatically applied
   
   # Optional: Update to take advantage of new features
   # Enhanced rate limiting (optional)
   export RATE_LIMIT_REQUESTS_PER_MINUTE=30  # Was 20 in 1.x
   export BURST_SIZE=5  # New option in 2.0.0
   
   # Enhanced caching (optional)
   export CACHE_CLEANUP_INTERVAL=3600  # New automatic cleanup
   ```

3. **Validate Migration**

   ```bash
   # Test configuration loading
   ./scripts/validate-config.sh
   
   # Test basic functionality
   ./scripts/analyze-performance.sh --dry-run
   ```

**Configuration Examples:**

```bash
# Version 1.x configuration
MAX_PARALLEL_JOBS=4
CACHE_TTL=1800
LOG_LEVEL=INFO

# Version 2.0.0 enhanced configuration (backward compatible)
MAX_PARALLEL_JOBS=4
CACHE_TTL=1800
CACHE_CLEANUP_INTERVAL=3600  # New: automatic cache cleanup
LOG_LEVEL=INFO
BURST_SIZE=5  # New: improved rate limiting
```

#### From Version 2.0.0 to 2.1.0

**Overview:** Version 2.1.0 introduced resource monitoring, enhanced utility scripts, and advanced parallel processing controls.

**Key Changes:**

- **Resource Monitoring**: Intelligent system resource management
- **Advanced Parallel Processing**: CPU and memory-aware job control
- **Enhanced Utility Scripts**: Comprehensive tooling with new configuration options
- **Development Dependencies**: New tools requiring configuration updates

**Step-by-Step Migration:**

1. **Backup Current Configuration**

   ```bash
   # Backup existing configuration
   cp config/production.conf config/production.conf.v2.0.backup
   cp scripts/config/default.conf scripts/config/default.conf.v2.0.backup
   ```

2. **Update Configuration Schema**

   **Add Resource Monitoring Configuration:**

   ```bash
   # Add to your configuration file or set as environment variables
   
   # Resource monitoring (recommended for production)
   export RESOURCE_MONITOR_ENABLED=true
   export MEMORY_LIMIT_PERCENT=80
   export CPU_LIMIT_PERCENT=90
   export MIN_PARALLEL_JOBS=1
   export MAX_SYSTEM_PARALLEL_JOBS=16
   export RESOURCE_CHECK_INTERVAL=5
   export PARALLEL_JOB_TIMEOUT=300
   ```

   **Update Existing Parallel Processing Settings:**

   ```bash
   # Enhanced parallel processing with resource awareness
   # Your existing MAX_PARALLEL_JOBS setting is still valid
   # But now it works with resource monitoring
   
   # Before (2.0.0): Fixed parallel jobs
   MAX_PARALLEL_JOBS=8
   
   # After (2.1.0): Resource-aware parallel jobs
   MAX_PARALLEL_JOBS=8  # Maximum allowed
   RESOURCE_MONITOR_ENABLED=true  # Enable dynamic adjustment
   MEMORY_LIMIT_PERCENT=80  # Reduce jobs if memory > 80%
   CPU_LIMIT_PERCENT=90     # Reduce jobs if CPU > 90%
   MIN_PARALLEL_JOBS=2      # Never go below 2 jobs
   ```

3. **Validate Migration**

   ```bash
   # Validate new configuration options
   ./scripts/validate-config.sh
   
   # Test resource monitoring
   export LOG_LEVEL=DEBUG
   ./scripts/analyze-performance.sh --benchmarks
   # Should see resource monitoring messages in debug output
   ```

**Configuration Examples:**

```bash
# Version 2.0.0 configuration
MAX_PARALLEL_JOBS=8
XARGS_PARALLEL_JOBS=8
CACHE_TTL=1800
CACHE_CLEANUP_INTERVAL=3600
RATE_LIMIT_REQUESTS_PER_MINUTE=30
BURST_SIZE=5
LOG_LEVEL=INFO

# Version 2.1.0 enhanced configuration
MAX_PARALLEL_JOBS=8
XARGS_PARALLEL_JOBS=8

# New: Resource monitoring configuration
RESOURCE_MONITOR_ENABLED=true
MEMORY_LIMIT_PERCENT=80
CPU_LIMIT_PERCENT=90
MIN_PARALLEL_JOBS=1
MAX_SYSTEM_PARALLEL_JOBS=16
RESOURCE_CHECK_INTERVAL=5
PARALLEL_JOB_TIMEOUT=300

# Existing configuration (unchanged)
CACHE_TTL=1800
CACHE_CLEANUP_INTERVAL=3600
RATE_LIMIT_REQUESTS_PER_MINUTE=30
BURST_SIZE=5
LOG_LEVEL=INFO
```

### Migration Troubleshooting

#### Common Migration Issues

**Issue 1: Configuration Validation Errors After Upgrade**

*Symptoms:*

```bash
./scripts/validate-config.sh
# ERROR: Invalid configuration option: RESOURCE_MONITOR_ENABLED
```

*Cause:* Using an old validation script that doesn't recognize new options.

*Solution:*

```bash
# Ensure you're using the latest scripts
git pull origin main
git status  # Verify you have the latest files

# Re-run validation
./scripts/validate-config.sh
```

**Issue 2: Resource Monitoring Not Working**

*Symptoms:*

```bash
# No resource monitoring messages in debug logs
export LOG_LEVEL=DEBUG
./scripts/analyze-performance.sh
# Expected: Resource monitoring messages
# Actual: No resource monitoring output
```

*Diagnosis:*

```bash
# Check if resource monitoring is enabled
echo "RESOURCE_MONITOR_ENABLED: $RESOURCE_MONITOR_ENABLED"

# Check if required tools are available
which ps awk || echo "Missing system monitoring tools"
```

*Solution:*

```bash
# Enable resource monitoring explicitly
export RESOURCE_MONITOR_ENABLED=true

# Verify system tools are available (usually pre-installed)
# On minimal containers, you may need to install:
# apt-get update && apt-get install -y procps

# Test resource monitoring
./scripts/debug-config.sh
```

**Issue 3: Performance Regression After Migration**

*Symptoms:*

- Scripts run slower after upgrading to 2.1.0
- Frequent "reducing parallel jobs due to resource constraints" messages

*Diagnosis:*

```bash
# Check resource limits
echo "Memory limit: $MEMORY_LIMIT_PERCENT%"
echo "CPU limit: $CPU_LIMIT_PERCENT%"
echo "Current parallel jobs: $MAX_PARALLEL_JOBS"

# Monitor actual resource usage
export LOG_LEVEL=DEBUG
./scripts/analyze-performance.sh --benchmarks
# Look for resource monitoring messages
```

*Solution:*

```bash
# Option 1: Adjust resource limits for your system
export MEMORY_LIMIT_PERCENT=90  # Allow higher memory usage
export CPU_LIMIT_PERCENT=95     # Allow higher CPU usage

# Option 2: Disable resource monitoring if not needed
export RESOURCE_MONITOR_ENABLED=false

# Option 3: Increase minimum parallel jobs
export MIN_PARALLEL_JOBS=4  # Maintain higher minimum performance
```

**Issue 4: Environment Variable Precedence Changes**

*Symptoms:*

- Configuration values not being applied as expected
- Custom configuration file settings ignored

*Diagnosis:*

```bash
# Debug configuration loading
./scripts/debug-config.sh

# Check loading order
export LOG_LEVEL=DEBUG
CONFIG_FILE="config/production.conf" ./scripts/validate-config.sh
# Look for configuration loading messages
```

*Solution:*

```bash
# Verify configuration precedence (unchanged in migrations):
# 1. default.conf (base configuration)
# 2. Environment variables 
# 3. Custom configuration file
# 4. Command-line arguments

# If custom config isn't applied, check:
export CONFIG_FILE="/absolute/path/to/config/production.conf"
./scripts/validate-config.sh

# Verify environment variables are exported:
export MAX_PARALLEL_JOBS=8  # Use 'export', not just assignment
echo $MAX_PARALLEL_JOBS     # Should output: 8
```

#### Migration-Specific Validation Failures

**Resource Monitoring Validation Errors:**

```bash
# Common validation errors and solutions:

# Error: Invalid MEMORY_LIMIT_PERCENT range
export MEMORY_LIMIT_PERCENT=50  # Valid range: 50-95

# Error: Invalid CPU_LIMIT_PERCENT range  
export CPU_LIMIT_PERCENT=70     # Valid range: 50-99

# Error: MIN_PARALLEL_JOBS > MAX_PARALLEL_JOBS
export MIN_PARALLEL_JOBS=2      # Must be ≤ MAX_PARALLEL_JOBS
export MAX_PARALLEL_JOBS=8

# Error: RESOURCE_CHECK_INTERVAL too low
export RESOURCE_CHECK_INTERVAL=5  # Minimum: 5 seconds
```

### Migration Validation Steps

#### Pre-Migration Validation

1. **Document Current Configuration**

   ```bash
   # Export current configuration to file
   ./scripts/debug-config.sh > pre-migration-config.txt
   
   # Test current functionality
   ./scripts/analyze-performance.sh --dry-run > pre-migration-test.log 2>&1
   ```

2. **Check System Compatibility**

   ```bash
   # Verify system requirements for new features
   
   # For resource monitoring (v2.1.0+):
   which ps awk free df || echo "Missing system monitoring tools"
   
   # Check available system resources
   free -m  # Memory available
   nproc    # CPU cores available
   df -h /tmp  # Temporary space for caching
   ```

#### Post-Migration Validation

1. **Configuration Schema Validation**

   ```bash
   # Validate all configuration options
   ./scripts/validate-config.sh
   
   # Test with custom configuration
   CONFIG_FILE="config/production.conf" ./scripts/validate-config.sh
   
   # Validate environment variable overrides
   MAX_PARALLEL_JOBS=16 ./scripts/validate-config.sh
   ```

2. **Functional Testing**

   ```bash
   # Test basic functionality
   ./scripts/analyze-performance.sh --dry-run
   
   # Test new features (v2.1.0+)
   export RESOURCE_MONITOR_ENABLED=true
   export LOG_LEVEL=DEBUG
   ./scripts/analyze-performance.sh --benchmarks
   
   # Verify resource monitoring messages appear in output
   grep -i "resource monitor" /tmp/performance-analysis.log
   ```

3. **Performance Validation**

   ```bash
   # Compare performance before and after migration
   
   # Run performance benchmark
   time ./scripts/analyze-performance.sh --benchmarks > post-migration-test.log 2>&1
   
   # Compare results
   echo "Pre-migration performance:"
   grep "Total execution time" pre-migration-test.log
   
   echo "Post-migration performance:"  
   grep "Total execution time" post-migration-test.log
   
   # Resource monitoring should maintain or improve performance
   ```

4. **Integration Testing**

   ```bash
   # Test integration with CI/CD pipelines
   export CONFIG_FILE="config/ci.conf"
   ./scripts/validate-workflows.sh
   
   # Test integration with different environments
   for env in development staging production; do
       echo "Testing $env configuration..."
       CONFIG_FILE="config/$env.conf" ./scripts/validate-config.sh
   done
   ```

#### Migration Rollback Procedures

If migration issues occur, you can rollback safely:

1. **Immediate Rollback**

   ```bash
   # Restore backup configuration
   cp config/production.conf.v2.0.backup config/production.conf
   cp scripts/config/default.conf.v2.0.backup scripts/config/default.conf
   
   # Clear new environment variables
   unset RESOURCE_MONITOR_ENABLED MEMORY_LIMIT_PERCENT CPU_LIMIT_PERCENT
   unset MIN_PARALLEL_JOBS MAX_SYSTEM_PARALLEL_JOBS RESOURCE_CHECK_INTERVAL
   
   # Validate rollback
   ./scripts/validate-config.sh
   ```

2. **Selective Feature Rollback**

   ```bash
   # Disable only problematic features
   export RESOURCE_MONITOR_ENABLED=false  # Disable resource monitoring
   
   # Keep other v2.1.0 enhancements
   # Resource monitoring is the main new feature in 2.1.0
   ```

#### Migration Success Criteria

A successful migration should meet these criteria:

✅ **Configuration Validation**: `./scripts/validate-config.sh` passes without errors  
✅ **Functional Testing**: All existing workflows continue to work  
✅ **Performance**: Performance is maintained or improved  
✅ **New Features**: New features work as documented (if enabled)  
✅ **Error Handling**: Enhanced error handling works correctly  
✅ **Documentation**: Configuration matches documented examples  

This core configuration guide provides the essential information needed to configure Claude Code Auto Workflows effectively. For additional topics, see the related documentation:

- **[SECURITY-OVERVIEW.md](../SECURITY-OVERVIEW.md)** - Comprehensive security practices for configuration management
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Systematic diagnosis and resolution of configuration issues
- **[ADVANCED.md](ADVANCED.md)** - Advanced configuration patterns, version compatibility, and dynamic configurations
- **[PERFORMANCE_TUNING.md](PERFORMANCE_TUNING.md)** - Performance optimization strategies using configuration settings
- **[Main README Troubleshooting](../README.md#troubleshooting-guide)** - General troubleshooting workflow and decision tree
