# Configuration Guide

This comprehensive guide covers all configuration options, environment variables, and best practices for Claude Code Auto Workflows.

## Table of Contents

- [Version Compatibility](#version-compatibility)
- [Configuration Overview](#configuration-overview)
- [Configuration Files](#configuration-files)
- [Environment Variables](#environment-variables)
- [Configuration Options Reference](#configuration-options-reference)
- [Configuration Validation](#configuration-validation)
- [Environment-Specific Configurations](#environment-specific-configurations)
- [Advanced Configuration](#advanced-configuration)
- [Configuration Best Practices](#configuration-best-practices)
  - [Security Considerations](#security-considerations)
    - [Token Management Best Practices](#token-management-best-practices)
    - [Secure Configuration Storage Guidelines](#secure-configuration-storage-guidelines)
    - [Access Control Considerations](#access-control-considerations)
    - [Security Validation and Monitoring](#security-validation-and-monitoring)
- [Troubleshooting Configuration Issues](#troubleshooting-configuration-issues)

## Version Compatibility

Claude Code Auto Workflows is designed to work across different environments and platforms. This section provides detailed compatibility information for all dependencies and system requirements.

### System Requirements

#### Minimum Requirements

| Component | Minimum Version | Recommended Version | Notes |
|-----------|----------------|-------------------|-------|
| **Operating System** | Linux (kernel 3.2+), macOS 10.15+, Windows with WSL2 | Latest LTS versions | Full functionality on Unix-like systems |
| **Bash** | 4.0+ | 5.0+ | Required for all shell scripts |
| **Node.js** | 18.0.0 | 18.19.0+ (LTS) | JavaScript runtime for tooling |
| **npm** | 9.0.0 | 10.2.3+ | Package manager |
| **Memory** | 2GB RAM | 4GB+ RAM | Higher memory improves parallel processing |
| **Disk Space** | 1GB free | 2GB+ free | For caching and temporary files |

#### Required Dependencies

| Dependency | Minimum Version | Installation Method | Purpose |
|------------|----------------|-------------------|---------|
| **GitHub CLI (gh)** | 2.0.0+ | [GitHub CLI Installation](https://cli.github.com/) | Core GitHub API operations |
| **jq** | 1.6+ | `apt install jq` / `brew install jq` | JSON processing |
| **git** | 2.20+ | System package manager | Version control operations |
| **curl** | 7.0+ | Usually pre-installed | HTTP requests |

#### Optional Dependencies

| Dependency | Purpose | Fallback Behavior |
|------------|---------|------------------|
| **bc** | Mathematical calculations | Fallback to shell arithmetic |
| **sar** | CPU monitoring | Uses alternative tools (vmstat, top) |
| **vmstat** | Resource monitoring | Uses alternative monitoring tools |
| **timeout** | Process timeouts | Basic timeout handling |
| **realpath** | Path resolution | Fallback to relative paths |

### Environment Compatibility Matrix

#### Development Environments

| Environment | Node.js | System Tools | Performance | Recommended Config |
|-------------|---------|--------------|-------------|-------------------|
| **Local Development** | 18.19.0+ | All optional tools | Full features | `config/development.conf` |
| **VS Code Dev Containers** | 18.19.0+ | Pre-configured | Optimized | Built-in configuration |
| **GitHub Codespaces** | 18.19.0+ | Pre-installed | Cloud-optimized | Automatic detection |
| **Docker Containers** | 18.19.0+ | Minimal set | Container-optimized | See Docker section |

#### Production Environments

| Environment | Compatibility | Special Considerations |
|-------------|---------------|----------------------|
| **Ubuntu 20.04+ LTS** | ✅ Full | Recommended for production |
| **Ubuntu 18.04 LTS** | ⚠️ Limited | Node.js 18+ requires manual installation |
| **RHEL/CentOS 8+** | ✅ Full | Use EPEL repository for jq |
| **Alpine Linux** | ✅ Full | Lightweight, good for containers |
| **macOS 11+** | ✅ Full | Use Homebrew for dependencies |
| **Windows WSL2** | ✅ Full | Requires WSL2, not WSL1 |

#### CI/CD Environments

| Platform | Compatibility | Configuration Notes |
|----------|---------------|-------------------|
| **GitHub Actions** | ✅ Full | Pre-installed tools, use `ubuntu-latest` |
| **GitLab CI** | ✅ Full | Use `ubuntu:20.04` or newer images |
| **Azure DevOps** | ✅ Full | Use `ubuntu-latest` agents |
| **CircleCI** | ✅ Full | Use `cimg/node:18.19` images |
| **Jenkins** | ✅ Full | Ensure agent has required dependencies |

### Version-Specific Features

#### Node.js Version Features

| Node.js Version | Features Available | Limitations |
|----------------|-------------------|-------------|
| **18.0.0 - 18.12.x** | Basic functionality | Some ES2022 features unavailable |
| **18.13.0+** | Full feature set | Recommended minimum |
| **18.19.0+ (LTS)** | Optimized performance | Recommended for production |
| **20.x** | Enhanced performance | Supported but not required |
| **21.x+** | Latest features | Not yet tested extensively |

#### GitHub CLI Version Features

| gh Version | API Features | Rate Limit Handling |
|------------|--------------|-------------------|
| **2.0.0 - 2.10.x** | Basic API access | Manual rate limiting |
| **2.11.0+** | Enhanced GraphQL | Improved rate limit detection |
| **2.20.0+** | Full feature set | Automatic retry handling |
| **2.40.0+** | Latest features | Recommended version |

### Platform-Specific Considerations

#### Linux Distributions

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install curl jq git bc
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh

# RHEL/CentOS/Fedora
sudo dnf install curl jq git bc
sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
sudo dnf install gh

# Alpine Linux
apk add curl jq git bc github-cli
```

#### macOS

```bash
# Using Homebrew (recommended)
brew install gh jq git bc curl

# Using MacPorts
sudo port install github-cli jq git bc curl
```

#### Windows (WSL2)

```bash
# Install WSL2 first, then use Ubuntu instructions
# Ensure WSL2 is running Ubuntu 20.04+ for best compatibility
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
sudo apt update && sudo apt install gh jq git bc curl
```

### Docker Compatibility

#### Base Images

| Image | Size | Compatibility | Use Case |
|-------|------|---------------|----------|
| `node:18.19-alpine` | ~40MB | ✅ Full | Production containers |
| `node:18.19-slim` | ~80MB | ✅ Full | Balanced size/features |
| `node:18.19` | ~400MB | ✅ Full | Development containers |
| `ubuntu:22.04` | ~30MB | ⚠️ Manual setup | Custom builds |

#### Container Configuration

```dockerfile
# Minimal production container
FROM node:18.19-alpine

RUN apk add --no-cache \
    bash \
    curl \
    git \
    jq \
    bc \
    github-cli

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

COPY . .
USER 1000:1000
```

### Compatibility Testing

#### Automated Testing Matrix

```yaml
# .github/workflows/compatibility.yml
strategy:
  matrix:
    os: [ubuntu-20.04, ubuntu-22.04, macos-11, macos-12]
    node-version: [18.13.0, 18.19.0, 20.x]
    include:
      - os: windows-latest
        node-version: 18.19.0
        shell: bash
```

#### Manual Testing

```bash
# Test script for compatibility verification
./scripts/test-compatibility.sh --node-version 18.19.0 --os ubuntu-22.04

# Version check command
npm run health-check
```

### Migration Guide

#### Upgrading from v1.x to v2.x

| Component | v1.x Requirement | v2.x Requirement | Migration Notes |
|-----------|------------------|------------------|----------------|
| Node.js | 16.x+ | 18.0.0+ | Update Node.js version |
| GitHub CLI | 1.x | 2.0.0+ | Reinstall GitHub CLI |
| Configuration | Basic variables | Enhanced validation | Review config files |

#### Breaking Changes

- **Node.js 16.x support removed** in v2.1.0 - Upgrade to Node.js 18.0.0+
- **Legacy GitHub CLI (v1.x) support removed** - Upgrade to gh 2.0.0+
- **Configuration validation** now enforces stricter rules

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

### Manual Configuration Validation

```bash
# Validate current configuration
./scripts/validate-config.sh

# Validate specific configuration file
CONFIG_FILE="config/production.conf" ./scripts/validate-config.sh

# Validate with environment overrides
MAX_PARALLEL_JOBS=16 CACHE_TTL=300 ./scripts/validate-config.sh
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

## Advanced Configuration

### Dynamic Configuration

**Configuration that adapts to system resources:**

```bash
# config/adaptive.conf
# Dynamic configuration based on system capabilities

# Auto-detect optimal parallel jobs
if command -v nproc >/dev/null; then
    MAX_PARALLEL_JOBS=$(nproc)
    XARGS_PARALLEL_JOBS=$(nproc)
else
    MAX_PARALLEL_JOBS=4
    XARGS_PARALLEL_JOBS=4
fi

# Adapt cache TTL based on available memory
AVAILABLE_MB=$(free -m 2>/dev/null | awk 'NR==2{print $7}' || echo 1024)
if [[ $AVAILABLE_MB -gt 4096 ]]; then
    CACHE_TTL=3600  # High memory: longer cache
elif [[ $AVAILABLE_MB -gt 2048 ]]; then
    CACHE_TTL=1800  # Medium memory: standard cache
else
    CACHE_TTL=900   # Low memory: shorter cache
fi

# Adapt based on network conditions
if command -v curl >/dev/null; then
    NETWORK_LATENCY=$(curl -o /dev/null -s -w "%{time_total}" https://api.github.com/rate_limit 2>/dev/null || echo "1.0")
    if (( $(echo "$NETWORK_LATENCY > 0.5" | bc -l 2>/dev/null || echo 0) )); then
        # High latency: increase cache TTL and reduce request rate
        CACHE_TTL=$((CACHE_TTL * 2))
        RATE_LIMIT_REQUESTS_PER_MINUTE=15
    fi
fi
```

### Profile-Based Configuration

**Multiple configuration profiles in a single file:**

```bash
# config/profiles.conf
# Multi-profile configuration file

# Common base configuration
BASE_CONFIG() {
    ENABLE_CACHE=true
    VALIDATE_SCHEMA=true
    COLORED_OUTPUT=true
}

# Development profile
PROFILE_DEVELOPMENT() {
    BASE_CONFIG
    MAX_PARALLEL_JOBS=2
    CACHE_TTL=300
    LOG_LEVEL=DEBUG
    ENABLE_BENCHMARKS=true
}

# Production profile
PROFILE_PRODUCTION() {
    BASE_CONFIG
    MAX_PARALLEL_JOBS=8
    CACHE_TTL=3600
    LOG_LEVEL=WARN
    OUTPUT_FORMAT=json
    COLORED_OUTPUT=false
}

# CI profile
PROFILE_CI() {
    BASE_CONFIG
    MAX_PARALLEL_JOBS=4
    CACHE_TTL=1800
    LOG_LEVEL=INFO
    OUTPUT_FORMAT=json
    COLORED_OUTPUT=false
    ENABLE_BENCHMARKS=false
}

# Load profile based on environment
PROFILE=${CONFIG_PROFILE:-DEVELOPMENT}
case "$PROFILE" in
    DEVELOPMENT) PROFILE_DEVELOPMENT ;;
    PRODUCTION)  PROFILE_PRODUCTION ;;
    CI)          PROFILE_CI ;;
    *)           echo "Unknown profile: $PROFILE"; exit 1 ;;
esac
```

**Usage:**
```bash
# Use development profile
CONFIG_PROFILE=DEVELOPMENT CONFIG_FILE="config/profiles.conf" ./scripts/analyze-performance.sh

# Use production profile
CONFIG_PROFILE=PRODUCTION CONFIG_FILE="config/profiles.conf" ./scripts/analyze-performance.sh
```

### Configuration Templates

**Template-based configuration generation:**

```bash
# generate-config.sh - Configuration template generator

generate_config_template() {
    local environment="$1"
    local output_file="$2"
    
    case "$environment" in
        development)
            cat > "$output_file" << 'EOF'
# Development Configuration
# Generated automatically - customize as needed

# Core settings
MAX_PARALLEL_JOBS=2
CACHE_TTL=300
LOG_LEVEL=DEBUG

# Development-specific
ENABLE_BENCHMARKS=true
VALIDATE_SCHEMA=true
CHECK_PERFORMANCE=true
COLORED_OUTPUT=true
OUTPUT_FORMAT=console

# Conservative rate limiting for development
RATE_LIMIT_REQUESTS_PER_MINUTE=20
RATE_LIMIT_DELAY=3
EOF
            ;;
        production)
            cat > "$output_file" << 'EOF'
# Production Configuration
# Generated automatically - customize as needed

# Core settings
MAX_PARALLEL_JOBS=8
CACHE_TTL=3600
LOG_LEVEL=WARN

# Production-specific
ENABLE_BENCHMARKS=false
VALIDATE_SCHEMA=true
CHECK_PERFORMANCE=false
COLORED_OUTPUT=false
OUTPUT_FORMAT=json

# Production rate limiting
RATE_LIMIT_REQUESTS_PER_MINUTE=30
RATE_LIMIT_DELAY=2

# Extended retention
DEFAULT_KEEP_DAYS=90
DEFAULT_MAX_RUNS=500
EOF
            ;;
    esac
    
    echo "Configuration template generated: $output_file"
}

# Usage: ./generate-config.sh development config/my-dev.conf
generate_config_template "$1" "$2"
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

### 5. Security Considerations

**Comprehensive security practices for configuration management:**

#### Token Management Best Practices

**GitHub Token Security:**
```bash
# Use GitHub App tokens when possible (higher rate limits, scoped permissions)
export GITHUB_TOKEN="$GITHUB_APP_TOKEN"

# For Personal Access Tokens (PATs), use fine-grained tokens with minimal scopes
# Required scopes: contents:read, metadata:read, actions:read
export GITHUB_TOKEN="github_pat_11ABCD..."

# Rotate tokens regularly (recommended: every 90 days)
# Document token expiration dates
TOKEN_EXPIRY="2024-12-31"  # Include in secure documentation

# Never log tokens in debug output
log_debug() {
    local message="$1"
    # Redact tokens from log messages
    message="${message//github_pat_[0-9A-Za-z_]*/[REDACTED]}"
    message="${message//ghp_[0-9A-Za-z]*/[REDACTED]}"
    echo "[DEBUG] $message" >&2
}
```

**Multi-Environment Token Strategy:**
```bash
# Development: Use PAT with read-only scopes
export GITHUB_TOKEN_DEV="github_pat_11DEV..."

# Staging: Use GitHub App token with limited repository access
export GITHUB_TOKEN_STAGING="$GITHUB_APP_STAGING_TOKEN"

# Production: Use GitHub App token with production-specific permissions
export GITHUB_TOKEN_PROD="$GITHUB_APP_PROD_TOKEN"

# Load appropriate token based on environment
case "${ENVIRONMENT:-development}" in
    development)
        export GITHUB_TOKEN="$GITHUB_TOKEN_DEV"
        ;;
    staging)
        export GITHUB_TOKEN="$GITHUB_TOKEN_STAGING"
        ;;
    production)
        export GITHUB_TOKEN="$GITHUB_TOKEN_PROD"
        ;;
esac
```

**Token Validation and Monitoring:**
```bash
# Validate token before use
validate_github_token() {
    local token="$1"
    
    if [[ -z "$token" || "$token" == "PLACEHOLDER" ]]; then
        log_error "GitHub token not configured"
        return 1
    fi
    
    # Check token format
    if [[ ! "$token" =~ ^(ghp_|github_pat_|ghs_) ]]; then
        log_error "Invalid GitHub token format"
        return 1
    fi
    
    # Test token with minimal API call
    local response
    response=$(curl -s -H "Authorization: Bearer $token" \
        "https://api.github.com/rate_limit" 2>/dev/null)
    
    if [[ $? -ne 0 ]] || ! echo "$response" | grep -q '"limit"'; then
        log_error "GitHub token validation failed"
        return 1
    fi
    
    log_info "GitHub token validated successfully"
    return 0
}

# Monitor token usage and remaining rate limits
monitor_token_usage() {
    local response
    response=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
        "https://api.github.com/rate_limit")
    
    local remaining used reset_time
    remaining=$(echo "$response" | jq -r '.rate.remaining')
    used=$(echo "$response" | jq -r '.rate.used')
    reset_time=$(echo "$response" | jq -r '.rate.reset')
    
    if [[ "$remaining" -lt 100 ]]; then
        log_warn "Low GitHub API rate limit remaining: $remaining"
    fi
    
    log_debug "GitHub API usage: $used used, $remaining remaining, resets at $(date -d @$reset_time)"
}
```

#### Secure Configuration Storage Guidelines

**Configuration File Security:**
```bash
# Set restrictive permissions on all configuration files
find config/ -name "*.conf" -exec chmod 600 {} \;
find config/ -name "*.conf" -exec chown $(whoami):$(whoami) {} \;

# For production systems, use even more restrictive permissions
chmod 400 config/production.conf  # Read-only for owner
chown root:root config/production.conf  # Root ownership
```

**Secrets Management Integration:**
```bash
# AWS Secrets Manager integration
load_aws_secrets() {
    local secret_name="$1"
    local region="${AWS_REGION:-us-east-1}"
    
    if command -v aws >/dev/null; then
        aws secretsmanager get-secret-value \
            --secret-id "$secret_name" \
            --region "$region" \
            --query SecretString \
            --output text 2>/dev/null
    else
        log_error "AWS CLI not available for secrets management"
        return 1
    fi
}

# Example usage in production configuration
if [[ "$ENVIRONMENT" == "production" ]]; then
    GITHUB_TOKEN=$(load_aws_secrets "github-app-token")
    DATABASE_PASSWORD=$(load_aws_secrets "database-password")
fi

# HashiCorp Vault integration
load_vault_secrets() {
    local secret_path="$1"
    local field="$2"
    
    if command -v vault >/dev/null && [[ -n "$VAULT_TOKEN" ]]; then
        vault kv get -field="$field" "$secret_path" 2>/dev/null
    else
        log_error "Vault CLI not available or token not set"
        return 1
    fi
}

# Example Vault usage
if [[ "$ENVIRONMENT" == "production" && -n "$VAULT_ADDR" ]]; then
    GITHUB_TOKEN=$(load_vault_secrets "secret/github" "app-token")
fi
```

**Encrypted Configuration Files:**
```bash
# Use GPG for sensitive configuration encryption
encrypt_config() {
    local config_file="$1"
    local recipient="$2"
    
    gpg --trust-model always --encrypt \
        --recipient "$recipient" \
        --output "${config_file}.gpg" \
        "$config_file"
    
    # Remove unencrypted file
    shred -u "$config_file"
}

# Decrypt configuration at runtime
decrypt_config() {
    local encrypted_file="$1"
    local output_file="${encrypted_file%.gpg}"
    
    if [[ -f "$encrypted_file" ]]; then
        gpg --quiet --decrypt "$encrypted_file" > "$output_file"
        chmod 600 "$output_file"
        return 0
    else
        log_error "Encrypted configuration not found: $encrypted_file"
        return 1
    fi
}

# Use in configuration loading
if [[ -f "config/production.conf.gpg" ]]; then
    decrypt_config "config/production.conf.gpg"
    load_config "config/production.conf"
    # Schedule cleanup of decrypted file
    trap 'shred -u config/production.conf 2>/dev/null || true' EXIT
fi
```

#### Access Control Considerations

**User and Group Permissions:**
```bash
# Create dedicated system user for production deployments
# sudo useradd -r -s /bin/bash -m -d /opt/cca-workflows cca-workflows

# Set up proper directory permissions
setup_secure_directories() {
    local install_dir="/opt/cca-workflows"
    local config_dir="$install_dir/config"
    local cache_dir="/var/cache/cca-workflows"
    local log_dir="/var/log/cca-workflows"
    
    # Create directories with secure permissions
    sudo mkdir -p "$config_dir" "$cache_dir" "$log_dir"
    
    # Set ownership
    sudo chown -R cca-workflows:cca-workflows "$install_dir"
    sudo chown -R cca-workflows:cca-workflows "$cache_dir"
    sudo chown -R cca-workflows:cca-workflows "$log_dir"
    
    # Set permissions
    chmod 750 "$install_dir"          # Owner: rwx, Group: r-x, Other: ---
    chmod 700 "$config_dir"           # Owner: rwx, Group: ---, Other: ---
    chmod 755 "$cache_dir"            # Owner: rwx, Group: r-x, Other: r-x
    chmod 755 "$log_dir"              # Owner: rwx, Group: r-x, Other: r-x
    
    # Restrict configuration files
    find "$config_dir" -name "*.conf" -exec chmod 600 {} \;
}
```

**Network Security Configuration:**
```bash
# GitHub Enterprise Server configuration
GITHUB_ENTERPRISE_URL="https://github.enterprise.com"
GITHUB_API_URL="$GITHUB_ENTERPRISE_URL/api/v3"

# Certificate validation (never disable in production)
VERIFY_SSL_CERTIFICATES=true

# Proxy configuration for corporate environments
HTTP_PROXY="http://proxy.company.com:8080"
HTTPS_PROXY="http://proxy.company.com:8080"
NO_PROXY="localhost,127.0.0.1,.company.com"

# Validate SSL certificates in API calls
github_api_call() {
    local endpoint="$1"
    local method="${2:-GET}"
    
    local curl_opts=()
    
    if [[ "$VERIFY_SSL_CERTIFICATES" == "true" ]]; then
        curl_opts+=("--fail-with-body")
    else
        curl_opts+=("--insecure")
        log_warn "SSL certificate verification disabled"
    fi
    
    if [[ -n "$HTTP_PROXY" ]]; then
        curl_opts+=("--proxy" "$HTTP_PROXY")
    fi
    
    curl "${curl_opts[@]}" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        -X "$method" \
        "$GITHUB_API_URL/$endpoint"
}
```

**Container Security Configuration:**
```bash
# Docker security best practices
# Use in Dockerfile:
# USER 1001:1001  # Non-root user
# COPY --chown=1001:1001 config/ /app/config/

# Container runtime security
docker_security_run() {
    docker run \
        --read-only \
        --tmpfs /tmp:size=100M,noexec \
        --tmpfs /var/cache/cca-workflows:size=500M \
        --security-opt no-new-privileges:true \
        --cap-drop ALL \
        --cap-add NET_CONNECT \
        --user 1001:1001 \
        -e GITHUB_TOKEN \
        -v "$(pwd)/config:/app/config:ro" \
        cca-workflows:latest
}
```

#### Security Validation and Monitoring

**Configuration Security Audit:**
```bash
# Security audit script
audit_configuration_security() {
    local audit_results=()
    local security_score=100
    
    # Check file permissions
    while IFS= read -r -d '' config_file; do
        local perms
        perms=$(stat -c "%a" "$config_file")
        if [[ "$perms" -gt 600 ]]; then
            audit_results+=("FAIL: $config_file has overly permissive permissions ($perms)")
            ((security_score -= 10))
        fi
    done < <(find config/ -name "*.conf" -print0 2>/dev/null)
    
    # Check for hardcoded secrets
    if grep -r -i "password\s*=" config/ 2>/dev/null | grep -v PLACEHOLDER; then
        audit_results+=("FAIL: Hardcoded passwords found in configuration")
        ((security_score -= 25))
    fi
    
    if grep -r "github_pat_\|ghp_" config/ 2>/dev/null; then
        audit_results+=("FAIL: Hardcoded GitHub tokens found in configuration")
        ((security_score -= 25))
    fi
    
    # Check token configuration
    if [[ -z "$GITHUB_TOKEN" || "$GITHUB_TOKEN" == "PLACEHOLDER" ]]; then
        audit_results+=("WARN: GitHub token not configured")
        ((security_score -= 5))
    fi
    
    # Check SSL verification
    if [[ "$VERIFY_SSL_CERTIFICATES" == "false" ]]; then
        audit_results+=("WARN: SSL certificate verification disabled")
        ((security_score -= 10))
    fi
    
    # Output results
    echo "Security Audit Results:"
    echo "======================"
    echo "Security Score: $security_score/100"
    echo
    
    if [[ ${#audit_results[@]} -eq 0 ]]; then
        echo "✅ No security issues found"
    else
        printf '%s\n' "${audit_results[@]}"
    fi
    
    return $((100 - security_score))
}

# Run security audit
./scripts/audit-security.sh
```

**Security Monitoring Integration:**
```bash
# Log security events
log_security_event() {
    local event_type="$1"
    local details="$2"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Log to security log file
    echo "$timestamp [SECURITY] $event_type: $details" >> /var/log/cca-workflows/security.log
    
    # Send to SIEM if configured
    if [[ -n "$SIEM_ENDPOINT" ]]; then
        curl -s -X POST "$SIEM_ENDPOINT" \
            -H "Content-Type: application/json" \
            -d "{\"timestamp\":\"$timestamp\",\"event\":\"$event_type\",\"details\":\"$details\"}"
    fi
}

# Monitor for security events
monitor_security() {
    # Token usage monitoring
    if ! validate_github_token "$GITHUB_TOKEN"; then
        log_security_event "TOKEN_VALIDATION_FAILED" "GitHub token validation failed"
    fi
    
    # Rate limit monitoring
    local rate_limit_response
    rate_limit_response=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
        "https://api.github.com/rate_limit")
    
    local remaining
    remaining=$(echo "$rate_limit_response" | jq -r '.rate.remaining')
    
    if [[ "$remaining" -lt 50 ]]; then
        log_security_event "RATE_LIMIT_LOW" "GitHub API rate limit low: $remaining remaining"
    fi
    
    # Configuration file integrity
    if [[ -f config/production.conf.sha256 ]]; then
        if ! sha256sum -c config/production.conf.sha256 2>/dev/null; then
            log_security_event "CONFIG_INTEGRITY_FAILED" "Production configuration integrity check failed"
        fi
    fi
}

# Run security monitoring
monitor_security
```

**Never commit sensitive values to configuration files:**
```bash
# Use placeholders in version-controlled files
GITHUB_TOKEN="${GITHUB_TOKEN:-PLACEHOLDER}"
DATABASE_PASSWORD="${DATABASE_PASSWORD:-PLACEHOLDER}"
API_SECRET="${API_SECRET:-PLACEHOLDER}"

# Use .env files for local development (add to .gitignore)
if [[ -f .env.local ]]; then
    source .env.local
fi

# Validate that placeholders are replaced in production
validate_no_placeholders() {
    if [[ "$ENVIRONMENT" == "production" ]]; then
        local placeholder_vars=()
        
        [[ "$GITHUB_TOKEN" == "PLACEHOLDER" ]] && placeholder_vars+=("GITHUB_TOKEN")
        [[ "$DATABASE_PASSWORD" == "PLACEHOLDER" ]] && placeholder_vars+=("DATABASE_PASSWORD")
        
        if [[ ${#placeholder_vars[@]} -gt 0 ]]; then
            log_error "Production environment has placeholder values: ${placeholder_vars[*]}"
            return 1
        fi
    fi
    return 0
}
```

### 6. Performance Testing Configuration Changes

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

## Troubleshooting Configuration Issues

### Configuration Troubleshooting Decision Tree

Use this decision tree to systematically diagnose and resolve configuration issues:

```mermaid
flowchart TD
    CONFIG_ISSUE([Configuration Issue]) --> SYMPTOM_CHECK{What is the problem?}
    
    SYMPTOM_CHECK -->|Validation Errors| VALIDATION{Check validation type}
    SYMPTOM_CHECK -->|Values Not Applied| OVERRIDE{Check override priority}
    SYMPTOM_CHECK -->|Performance Issues| PERFORMANCE{Check performance impact}
    SYMPTOM_CHECK -->|Unexpected Behavior| BEHAVIOR{Check configuration logic}
    
    %% Validation Path
    VALIDATION -->|Invalid Range| RANGE_FIX[Check valid ranges:<br/>MAX_PARALLEL_JOBS: 1-32<br/>CACHE_TTL: 60-86400<br/>RATE_LIMIT_REQUESTS_PER_MINUTE: 1-120<br/><br/>**Example**: MAX_PARALELL_JOBS=50 (common typo)<br/>→ Validation error: "Invalid MAX_PARALLEL_JOBS: 50 (must be 1-32)"<br/>→ Solution: export MAX_PARALLEL_JOBS=8<br/><br/>**Example**: CACHE_TTL=30 (too short)<br/>→ Validation error: "CACHE_TTL must be 60-86400 seconds"<br/>→ Solution: export CACHE_TTL=300 # 5 minutes minimum]
    VALIDATION -->|Invalid Enum| ENUM_FIX[Check valid values:<br/>LOG_LEVEL: DEBUG,INFO,WARN,ERROR<br/>OUTPUT_FORMAT: console,json,markdown<br/>Boolean: true,false only<br/><br/>**Example**: LOG_LEVEL=VERBOSE (invalid)<br/>→ Script exits with "Invalid LOG_LEVEL: VERBOSE"<br/>→ Solution: export LOG_LEVEL=DEBUG<br/><br/>**Example**: ENABLE_CACHE=yes (wrong format)<br/>→ Validation fails, expects true/false<br/>→ Solution: export ENABLE_CACHE=true]
    VALIDATION -->|Missing Dependencies| DEPENDENCY_FIX[Check relationships:<br/>BENCHMARK_ITERATIONS >= 3 if benchmarks enabled<br/>RATE_LIMIT_DELAY appropriate for request rate<br/><br/>**Example**: ENABLE_BENCHMARKS=true + BENCHMARK_ITERATIONS=1<br/>→ Error: "BENCHMARK_ITERATIONS must be at least 3"<br/>→ Solution: export BENCHMARK_ITERATIONS=5<br/><br/>**Example**: RATE_LIMIT_REQUESTS_PER_MINUTE=100 + RATE_LIMIT_DELAY=10<br/>→ Warning: "High delay with high rate may cause issues"<br/>→ Solution: Reduce delay to 1-2 seconds]
    
    %% Override Path
    OVERRIDE -->|Environment Not Working| ENV_CHECK{Check environment variables}
    OVERRIDE -->|Config File Ignored| FILE_CHECK{Check config file}
    OVERRIDE -->|Precedence Issues| PRECEDENCE_CHECK{Check loading order}
    
    ENV_CHECK -->|Not Exported| EXPORT_FIX[Use: export VAR=value<br/>Not: VAR=value<br/>Check with: env | grep VAR<br/><br/>**Example**: Configuration not overriding defaults<br/>→ Used: MAX_PARALLEL_JOBS=8 ./script.sh<br/>→ Variable not in environment for subprocess<br/>→ Solution: export MAX_PARALLEL_JOBS=8; ./script.sh]
    ENV_CHECK -->|Wrong Name| NAME_FIX[Verify exact variable names<br/>Check for typos<br/>Case-sensitive matching<br/><br/>**Example**: MAX_PARALELL_JOBS=8 (double L typo)<br/>→ Scripts still uses default MAX_PARALLEL_JOBS=4<br/>→ Solution: export MAX_PARALLEL_JOBS=8<br/><br/>**Example**: cache_ttl=1800 (lowercase)<br/>→ Scripts expects CACHE_TTL (uppercase)<br/>→ Solution: export CACHE_TTL=1800]
    ENV_CHECK -->|Wrong Value| VALUE_FIX[Check value format<br/>Boolean: true/false<br/>Numbers: numeric only<br/><br/>**Example**: ENABLE_CACHE=True (capital T)<br/>→ Script validation fails, needs lowercase<br/>→ Solution: export ENABLE_CACHE=true<br/><br/>**Example**: MAX_PARALLEL_JOBS="8" (quoted)<br/>→ Numeric comparison fails with quotes<br/>→ Solution: export MAX_PARALLEL_JOBS=8]
    
    FILE_CHECK -->|File Not Found| PATH_FIX[Check CONFIG_FILE path<br/>Verify file exists<br/>Use absolute paths<br/><br/>**Example**: CONFIG_FILE="config/prod.conf" but file missing<br/>→ Error: "config/prod.conf: No such file or directory"<br/>→ Solution: Create file or fix path: CONFIG_FILE="config/production.conf"<br/><br/>**Example**: Relative path issues in CI/CD<br/>→ CONFIG_FILE="./config.conf" fails in different working dir<br/>→ Solution: Use absolute path: CONFIG_FILE="/workspace/config/production.conf"]
    FILE_CHECK -->|Wrong Syntax| SYNTAX_FIX[Check bash syntax<br/>No spaces around =<br/>Quote string values<br/><br/>**Example**: MAX_PARALLEL_JOBS = 8 (spaces around =)<br/>→ Bash syntax error during config loading<br/>→ Solution: MAX_PARALLEL_JOBS=8<br/><br/>**Example**: LOG_LEVEL=INFO DEBUG (space in value)<br/>→ Only "INFO" is set, "DEBUG" treated as command<br/>→ Solution: LOG_LEVEL="INFO DEBUG" or separate variables]
    FILE_CHECK -->|Permissions| PERM_FIX[Check read permissions<br/>chmod +r config_file<br/>Verify ownership<br/><br/>**Example**: "Permission denied" when loading config<br/>→ Config file has 600 permissions, script running as different user<br/>→ Solution: chmod 644 config/production.conf<br/><br/>**Example**: Config file owned by root in container<br/>→ Application running as non-root can't read<br/>→ Solution: chown appuser:appuser config/production.conf]
    
    PRECEDENCE_CHECK -->|Wrong Order| ORDER_FIX[Remember priority:<br/>1. default.conf<br/>2. Environment vars<br/>3. Custom config<br/>4. Command-line args<br/><br/>**Example**: Expected env var to override config file<br/>→ Custom config loaded after environment variables<br/>→ Check script loading order in common.sh<br/>→ Solution: Move env var loading after config file load<br/><br/>**Example**: Default value still used despite custom config<br/>→ Typo in variable name in config file<br/>→ Solution: Verify exact variable names match]
    
    %% Performance Path
    PERFORMANCE -->|Too Slow| SLOW_CONFIG[Check settings:<br/>MAX_PARALLEL_JOBS too low<br/>CACHE_TTL too short<br/>Too many validations enabled<br/><br/>**Example**: Analysis takes 10+ minutes on 8-core system<br/>→ MAX_PARALLEL_JOBS=2 underutilizing CPU<br/>→ Solution: export MAX_PARALLEL_JOBS=8<br/><br/>**Example**: Frequent API rate limit warnings<br/>→ CACHE_TTL=60 causing excessive API calls<br/>→ Solution: export CACHE_TTL=1800 # 30 minutes]
    PERFORMANCE -->|Too Resource Intensive| RESOURCE_CONFIG[Check settings:<br/>MAX_PARALLEL_JOBS too high<br/>CACHE_TTL too long<br/>Memory constraints<br/><br/>**Example**: System freezes during analysis<br/>→ MAX_PARALLEL_JOBS=32 on 4-core system causes thrashing<br/>→ Solution: export MAX_PARALLEL_JOBS=4<br/><br/>**Example**: Memory usage reaches 8GB on 4GB system<br/>→ Long CACHE_TTL=86400 with large repository<br/>→ Solution: Reduce cache TTL or increase system memory]
    PERFORMANCE -->|Inconsistent Results| CONSISTENCY_CONFIG[Check settings:<br/>Cache configuration<br/>Parallel job conflicts<br/>Race conditions<br/><br/>**Example**: Different results on repeated runs<br/>→ Cache files corrupted by parallel writes<br/>→ Solution: Reduce MAX_PARALLEL_JOBS or add file locking<br/><br/>**Example**: GitHub API errors sporadically<br/>→ Rate limiting with parallel requests causes timing issues<br/>→ Solution: Adjust RATE_LIMIT_DELAY to add buffer time]
    
    %% Behavior Path
    BEHAVIOR -->|Wrong Output Format| OUTPUT_CHECK[Check OUTPUT_FORMAT value<br/>Verify COLORED_OUTPUT setting<br/>Check OUTPUT_FILE permissions<br/><br/>**Example**: Expected JSON but got plain text<br/>→ OUTPUT_FORMAT=console instead of json<br/>→ Solution: export OUTPUT_FORMAT=json<br/><br/>**Example**: No colors in terminal despite setting<br/>→ COLORED_OUTPUT=true but terminal doesn't support colors<br/>→ Solution: Check TERM variable or force colors off]
    BEHAVIOR -->|Logging Issues| LOG_CHECK[Check LOG_LEVEL setting<br/>Verify log file permissions<br/>Check COLORED_OUTPUT for terminals<br/><br/>**Example**: No debug output despite LOG_LEVEL=DEBUG<br/>→ Actually set to INFO due to config file override<br/>→ Solution: Check config precedence, export LOG_LEVEL=DEBUG<br/><br/>**Example**: Garbled colors in CI/CD logs<br/>→ COLORED_OUTPUT=true in non-interactive environment<br/>→ Solution: export COLORED_OUTPUT=false for CI]
    BEHAVIOR -->|Cache Not Working| CACHE_CHECK[Check ENABLE_CACHE=true<br/>Verify CACHE_TTL > 0<br/>Check cache directory permissions<br/><br/>**Example**: Same API calls repeated every run<br/>→ ENABLE_CACHE=false disabling cache entirely<br/>→ Solution: export ENABLE_CACHE=true<br/><br/>**Example**: Cache directory errors<br/>→ /tmp/github-api-cache not writable by script user<br/>→ Solution: mkdir -p /tmp/github-api-cache; chmod 755 /tmp/github-api-cache]
    BEHAVIOR -->|Rate Limiting Problems| RATE_CHECK[Check rate limit settings<br/>Verify GitHub token type<br/>Monitor actual usage vs limits<br/><br/>**Example**: Hit rate limits with low request rate<br/>→ RATE_LIMIT_REQUESTS_PER_MINUTE=60 but only using PAT (5000/hr limit)<br/>→ Should be hitting limit, check if other processes using same token<br/>→ Solution: Use GitHub App token for higher limits<br/><br/>**Example**: Delays much longer than expected<br/>→ RATE_LIMIT_DELAY=10 causing 10-second delays between requests<br/>→ Solution: Reduce to RATE_LIMIT_DELAY=2 for better performance]
    
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

### Common Configuration Problems

#### 1. Invalid Configuration Values

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

#### 2. Configuration Override Issues

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

#### 3. Performance Degradation After Configuration Changes

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

#### 4. Cache-Related Issues

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

### Configuration Debugging Tools

#### Debug Configuration Script

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

This comprehensive configuration guide provides all the information needed to effectively configure and customize Claude Code Auto Workflows for any environment or use case.