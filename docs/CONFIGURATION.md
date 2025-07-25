# Configuration Guide

This guide covers core configuration options, environment variables, and basic setup for Claude Code Auto Workflows.

**Related Documentation:**
- [SECURITY-OVERVIEW.md](../SECURITY-OVERVIEW.md) - Security overview and quick start guide
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Troubleshooting configuration issues
- [ADVANCED.md](ADVANCED.md) - Advanced configuration patterns and version compatibility

## Table of Contents

- [Configuration Overview](#configuration-overview)
- [Quick Start](#quick-start)
- [Configuration Files](#configuration-files)
- [Environment Variables](#environment-variables)
- [Configuration Options Reference](#configuration-options-reference)
- [Configuration Validation](#configuration-validation)
- [Environment-Specific Configurations](#environment-specific-configurations)
- [Configuration Best Practices](#configuration-best-practices)

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

## Quick Start

This section provides essential configuration setup for common scenarios to help you get started quickly.

### Prerequisites

Before getting started, ensure you have the following:

- **Bash shell environment** (Linux, macOS, or WSL on Windows)
- **Git repository** with GitHub API access
- **GitHub Personal Access Token** with appropriate permissions
- **curl or similar HTTP client** (usually pre-installed)
- **Basic familiarity with environment variables and command-line usage**

### 5-Minute Setup for Development Environment

Get up and running in the development environment with these minimal configuration steps:

```bash
# 1. Clone and navigate to your project
cd your-project-directory

# 2. Copy the development configuration template (if available)
if [ -f "config/development.conf.example" ]; then
  cp config/development.conf.example config/development.conf
  echo "✅ Copied development configuration template"
else
  # Create a basic development config:
  echo "📝 Creating basic development configuration..."
cat > config/development.conf << 'EOF'
# Development Configuration
MAX_PARALLEL_JOBS=2
CACHE_TTL=300
LOG_LEVEL=DEBUG
COLORED_OUTPUT=true
OUTPUT_FORMAT=console
ENABLE_BENCHMARKS=true
VALIDATE_SCHEMA=true
CHECK_SECURITY=true
EOF

# 3. Set your GitHub Personal Access Token (required for GitHub API access)
# Generate at: https://github.com/settings/tokens
# Required scopes: repo (for private repos) or public_repo (for public repos)
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"  # Replace with your actual token

# 4. Validate the configuration
if CONFIG_FILE="config/development.conf" ./scripts/validate-config.sh; then
  echo "✅ Configuration validation passed"
else
  echo "❌ Configuration validation failed - check the error messages above"
  exit 1
fi

# 5. Run your first analysis
if CONFIG_FILE="config/development.conf" ./scripts/analyze-performance.sh; then
  echo "✅ Performance analysis completed successfully"
else
  echo "❌ Performance analysis failed - check the logs for details"
  exit 1
fi
```

**Expected output when validation succeeds:** Configuration validation should pass, and you should see debug-level logging with colored output.

### Common Production Settings

Essential production configuration template for reliable operation:

```bash
# config/production.conf
# Production-ready settings for stable operation

# Core Performance Settings
MAX_PARALLEL_JOBS=8              # Adjust based on server CPU cores
CACHE_TTL=3600                   # 1 hour - balance performance vs freshness
XARGS_PARALLEL_JOBS=8            # Match parallel job count

# Logging and Output
LOG_LEVEL=WARN                   # Minimal noise, important messages only
COLORED_OUTPUT=false             # Disable colors for log processing
OUTPUT_FORMAT=json               # Structured output for automation

# Rate Limiting (Conservative for shared environments)
RATE_LIMIT_REQUESTS_PER_MINUTE=15
RATE_LIMIT_DELAY=4
BURST_SIZE=3

# Reliability Settings
ENABLE_BENCHMARKS=false          # Skip benchmarks in production
ENABLE_CACHE=true                # Essential for performance
VALIDATE_SCHEMA=true             # Prevent configuration errors

# Retention Settings
DEFAULT_KEEP_DAYS=90             # Extended retention for production
DEFAULT_MAX_RUNS=500             # More historical data

# Security Settings
# (See Security Checklist below for additional settings)
```

**Deployment Verification:**
```bash
# Test production config before deployment
if CONFIG_FILE="config/production.conf" ./scripts/validate-config.sh; then
  echo "✅ Production configuration validated successfully"
else
  echo "❌ Production configuration validation failed"
  exit 1
fi

# Deploy with production settings
export CONFIG_FILE="config/production.conf"
if ./scripts/analyze-performance.sh --output production-report.json; then
  echo "✅ Production analysis completed successfully"
  echo "📄 Report saved to: production-report.json"
else
  echo "❌ Production analysis failed"
  exit 1
fi
```

### Essential Security Checklist

Critical security configurations that must be set up properly:

#### ✅ **Authentication & Tokens**
```bash
# ✅ DO: Use environment variables for sensitive data
# Generate Personal Access Token at: https://github.com/settings/tokens
# Required scopes: 'repo' for private repositories, 'public_repo' for public repositories
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# ❌ DON'T: Hard-code tokens in configuration files
# GITHUB_TOKEN="ghp_example123"  # Never do this - tokens will be exposed in version control
```

#### ✅ **File Permissions**
```bash
# Set secure permissions for configuration files
# Set secure permissions for production config (contains sensitive settings)
chmod 600 config/production.conf      # Owner read/write only
# Set standard permissions for development config (typically non-sensitive)
chmod 644 config/development.conf     # Standard permissions for shared configs

# Verify permissions
ls -la config/
```

#### ✅ **Environment Separation**
```bash
# Use different configurations for each environment
config/
├── development.conf     # Development settings
├── staging.conf        # Staging environment  
├── production.conf     # Production settings (secure)
└── ci.conf            # CI/CD pipeline settings
```

#### ✅ **Configuration Validation**
```bash
# Always validate before deployment
if CONFIG_FILE="config/production.conf" ./scripts/validate-config.sh; then
  echo "✅ Production configuration validated"
else
  echo "❌ Production configuration validation failed"
  exit 1
fi

# Enable all security checks
export CHECK_SECURITY=true
export VALIDATE_SCHEMA=true
```

#### ✅ **Log Security**
```bash
# Production: Avoid debug logs that might expose sensitive data
export LOG_LEVEL=WARN

# Development: Use debug logs safely in isolated environments
export LOG_LEVEL=DEBUG
```

#### ⚠️ **Security Warnings**
- Never commit `GITHUB_TOKEN` or other secrets to version control
- Use secure secret management systems in production (e.g., GitHub Secrets, HashiCorp Vault)
- Regularly rotate access tokens and API keys
- Review configuration files for accidentally committed secrets

### Quick Reference Table

Most commonly used configuration options for quick setup:

| Setting | Development | Production | CI/CD | Description |
|---------|-------------|------------|-------|-------------|
| **Core Settings** |
| `MAX_PARALLEL_JOBS` | `2` | `8` | `4` | Parallel processing limit |
| `CACHE_TTL` | `300` (5min) | `3600` (1hr) | `1800` (30min) | Cache duration in seconds |
| `LOG_LEVEL` | `DEBUG` | `WARN` | `INFO` | Logging verbosity level |
| **Output & Format** |
| `OUTPUT_FORMAT` | `console` | `json` | `json` | Output format type |
| `COLORED_OUTPUT` | `true` | `false` | `false` | Enable colored console output |
| **Performance** |
| `ENABLE_BENCHMARKS` | `true` | `false` | `false` | Run performance benchmarks |
| `ENABLE_CACHE` | `true` | `true` | `true` | Enable caching system |
| **Rate Limiting** |
| `RATE_LIMIT_REQUESTS_PER_MINUTE` | `30` | `15` | `30` | GitHub API rate limit |
| `RATE_LIMIT_DELAY` | `2` | `4` | `2` | Delay between requests (seconds) |
| **Validation** |
| `VALIDATE_SCHEMA` | `true` | `true` | `true` | Enable configuration validation |
| `CHECK_SECURITY` | `true` | `true` | `true` | Enable security checks |
| `CHECK_PERFORMANCE` | `true` | `false` | `false` | Enable performance validation |

#### **Quick Environment Setup**
```bash
# Development
export CONFIG_FILE="config/development.conf"
export MAX_PARALLEL_JOBS=2 LOG_LEVEL=DEBUG COLORED_OUTPUT=true

# Production  
export CONFIG_FILE="config/production.conf"
export MAX_PARALLEL_JOBS=8 LOG_LEVEL=WARN OUTPUT_FORMAT=json

# CI/CD
export CONFIG_FILE="config/ci.conf"  
export MAX_PARALLEL_JOBS=4 LOG_LEVEL=INFO OUTPUT_FORMAT=json
```

#### **Common Command Patterns**
```bash
# Validate configuration
CONFIG_FILE="config/your-env.conf" ./scripts/validate-config.sh

# Run with custom config
CONFIG_FILE="config/your-env.conf" ./scripts/analyze-performance.sh

# Override specific settings
MAX_PARALLEL_JOBS=4 CACHE_TTL=600 ./scripts/analyze-performance.sh

# Run with benchmarks
ENABLE_BENCHMARKS=true ./scripts/analyze-performance.sh --benchmarks
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

This core configuration guide provides the essential information needed to configure Claude Code Auto Workflows effectively. For additional topics, see the related documentation:

- **[SECURITY-OVERVIEW.md](../SECURITY-OVERVIEW.md)** - Comprehensive security practices for configuration management
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Systematic diagnosis and resolution of configuration issues
- **[ADVANCED.md](ADVANCED.md)** - Advanced configuration patterns, version compatibility, and dynamic configurations