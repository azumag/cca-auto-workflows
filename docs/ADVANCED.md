# Advanced Configuration Guide

This guide covers advanced configuration patterns, version compatibility, and dynamic configurations for Claude Code Auto Workflows.

**Related Documentation:**
- [CONFIGURATION.md](CONFIGURATION.md) - Core configuration options and basic setup
- [SECURITY-OVERVIEW.md](../SECURITY-OVERVIEW.md) - Security overview and quick start guide
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Troubleshooting configuration issues

## Table of Contents

- [Version Compatibility](#version-compatibility)
- [Dynamic Configuration](#dynamic-configuration)
- [Profile-Based Configuration](#profile-based-configuration)
- [Configuration Templates](#configuration-templates)
- [Container and Orchestration](#container-and-orchestration)
- [Performance Optimization](#performance-optimization)

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

### Platform-Specific Installation

#### Linux Distributions

```bash
# Ubuntu/Debian - Install required dependencies
sudo apt update
sudo apt install curl jq git bc

# Add GitHub CLI repository
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

# Install GitHub CLI
sudo apt update
sudo apt install gh

# RHEL/CentOS/Fedora - Install required dependencies
sudo dnf install curl jq git bc

# Add GitHub CLI repository and install
sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
sudo dnf install gh

# Alpine Linux - Install all dependencies in one command
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

## Dynamic Configuration

### Adaptive Configuration

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

### Environment Detection

**Automatic environment detection and configuration:**

```bash
# detect-environment.sh
# Auto-detect environment and apply appropriate configuration

detect_environment() {
    # Check for CI/CD environments
    if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        echo "github-actions"
    elif [[ -n "${GITLAB_CI:-}" ]]; then
        echo "gitlab-ci"
    elif [[ -n "${JENKINS_URL:-}" ]]; then
        echo "jenkins"
    elif [[ -n "${CIRCLECI:-}" ]]; then
        echo "circleci"
    # Check for development environments
    elif [[ -n "${CODESPACES:-}" ]]; then
        echo "codespaces"
    elif [[ -n "${VSCODE_INJECTION:-}" ]]; then
        echo "vscode"
    # Check for containerized environments
    elif [[ -f /.dockerenv ]]; then
        echo "docker"
    elif [[ -n "${KUBERNETES_SERVICE_HOST:-}" ]]; then
        echo "kubernetes"
    # Default to local development
    else
        echo "local"
    fi
}

# Apply environment-specific configuration
apply_environment_config() {
    local environment="$1"
    local config_dir="config"
    
    case "$environment" in
        github-actions|gitlab-ci|jenkins|circleci)
            export CONFIG_FILE="$config_dir/ci.conf"
            export COLORED_OUTPUT=false
            export OUTPUT_FORMAT=json
            ;;
        codespaces|vscode)
            export CONFIG_FILE="$config_dir/development.conf"
            export LOG_LEVEL=DEBUG
            ;;
        docker|kubernetes)
            export CONFIG_FILE="$config_dir/container.conf"
            export COLORED_OUTPUT=false
            ;;
        local)
            export CONFIG_FILE="$config_dir/development.conf"
            ;;
    esac
    
    log_info "Detected environment: $environment, using config: $CONFIG_FILE"
}

# Auto-configure based on detected environment
DETECTED_ENV=$(detect_environment)
apply_environment_config "$DETECTED_ENV"
```

### Runtime Configuration Adjustment

**Adjust configuration based on runtime conditions:**

```bash
# runtime-tuning.sh
# Adjust configuration based on runtime performance

monitor_and_adjust() {
    local initial_parallel_jobs="$MAX_PARALLEL_JOBS"
    local adjustment_count=0
    local max_adjustments=3
    
    while [[ $adjustment_count -lt $max_adjustments ]]; do
        # Monitor system load
        local load_avg
        load_avg=$(uptime | awk -F'load average:' '{print $2}' | cut -d',' -f1 | xargs)
        
        # Get CPU count for comparison
        local cpu_count=$(nproc)
        
        # Adjust if load is too high
        if (( $(echo "$load_avg > $cpu_count * 1.5" | bc -l) )); then
            if [[ $MAX_PARALLEL_JOBS -gt 1 ]]; then
                MAX_PARALLEL_JOBS=$((MAX_PARALLEL_JOBS - 1))
                log_warn "High system load ($load_avg), reducing MAX_PARALLEL_JOBS to $MAX_PARALLEL_JOBS"
                ((adjustment_count++))
            fi
        # Increase if load is low and we had reduced it
        elif (( $(echo "$load_avg < $cpu_count * 0.5" | bc -l) )) && [[ $MAX_PARALLEL_JOBS -lt $initial_parallel_jobs ]]; then
            MAX_PARALLEL_JOBS=$((MAX_PARALLEL_JOBS + 1))
            log_info "Low system load ($load_avg), increasing MAX_PARALLEL_JOBS to $MAX_PARALLEL_JOBS"
            ((adjustment_count++))
        fi
        
        sleep 30  # Check every 30 seconds
    done
}

# Start monitoring in background
monitor_and_adjust &
MONITOR_PID=$!

# Cleanup on exit
trap 'kill $MONITOR_PID 2>/dev/null || true' EXIT
```

## Profile-Based Configuration

### Multi-Profile Configuration

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

### Hierarchical Profiles

**Nested profile inheritance:**

```bash
# config/hierarchical-profiles.conf
# Hierarchical profile configuration

# Base profile - common settings
PROFILE_BASE() {
    ENABLE_CACHE=true
    VALIDATE_SCHEMA=true
    CHECK_SECURITY=true
    DEFAULT_KEEP_DAYS=30
}

# Environment-specific base profiles
PROFILE_DEV_BASE() {
    PROFILE_BASE
    LOG_LEVEL=DEBUG
    COLORED_OUTPUT=true
    OUTPUT_FORMAT=console
    ENABLE_BENCHMARKS=true
}

PROFILE_PROD_BASE() {
    PROFILE_BASE
    LOG_LEVEL=WARN
    COLORED_OUTPUT=false
    OUTPUT_FORMAT=json
    ENABLE_BENCHMARKS=false
    DEFAULT_KEEP_DAYS=90
}

# Specific profiles that inherit from base profiles
PROFILE_DEV_LOCAL() {
    PROFILE_DEV_BASE
    MAX_PARALLEL_JOBS=2
    CACHE_TTL=300
    RATE_LIMIT_REQUESTS_PER_MINUTE=20
}

PROFILE_DEV_CONTAINER() {
    PROFILE_DEV_BASE
    MAX_PARALLEL_JOBS=4
    CACHE_TTL=600
    GITHUB_API_CACHE_DIR="/tmp/cache"
}

PROFILE_PROD_SMALL() {
    PROFILE_PROD_BASE
    MAX_PARALLEL_JOBS=4
    CACHE_TTL=1800
    RATE_LIMIT_REQUESTS_PER_MINUTE=15
}

PROFILE_PROD_LARGE() {
    PROFILE_PROD_BASE
    MAX_PARALLEL_JOBS=16
    CACHE_TTL=7200
    RATE_LIMIT_REQUESTS_PER_MINUTE=60
    WORKFLOW_ANALYSIS_LIMIT=200
}

# Load hierarchical profile
PROFILE=${CONFIG_PROFILE:-DEV_LOCAL}
case "$PROFILE" in
    DEV_LOCAL)     PROFILE_DEV_LOCAL ;;
    DEV_CONTAINER) PROFILE_DEV_CONTAINER ;;
    PROD_SMALL)    PROFILE_PROD_SMALL ;;
    PROD_LARGE)    PROFILE_PROD_LARGE ;;
    *)             echo "Unknown profile: $PROFILE"; exit 1 ;;
esac
```

## Configuration Templates

### Template Generation

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

### Interactive Configuration Builder

**Interactive configuration generation:**

```bash
# interactive-config.sh - Interactive configuration builder

build_interactive_config() {
    local output_file="$1"
    
    echo "Interactive Configuration Builder"
    echo "================================"
    echo
    
    # Environment type
    echo "1. Select environment type:"
    echo "   1) Development"
    echo "   2) Production"
    echo "   3) CI/CD"
    read -p "Choice (1-3): " env_choice
    
    case "$env_choice" in
        1) ENVIRONMENT="development" ;;
        2) ENVIRONMENT="production" ;;
        3) ENVIRONMENT="ci" ;;
        *) echo "Invalid choice"; exit 1 ;;
    esac
    
    # System specifications
    echo
    echo "2. System specifications:"
    read -p "CPU cores (default: $(nproc)): " cpu_cores
    cpu_cores=${cpu_cores:-$(nproc)}
    
    read -p "Available memory in GB (default: 4): " memory_gb
    memory_gb=${memory_gb:-4}
    
    # Calculate recommendations
    if [[ $memory_gb -lt 4 ]]; then
        MAX_PARALLEL_JOBS=$((cpu_cores / 2))
        CACHE_TTL=900
    elif [[ $memory_gb -lt 8 ]]; then
        MAX_PARALLEL_JOBS=$cpu_cores
        CACHE_TTL=1800
    else
        MAX_PARALLEL_JOBS=$((cpu_cores * 2))
        CACHE_TTL=3600
    fi
    
    # Ensure within valid range
    [[ $MAX_PARALLEL_JOBS -lt 1 ]] && MAX_PARALLEL_JOBS=1
    [[ $MAX_PARALLEL_JOBS -gt 32 ]] && MAX_PARALLEL_JOBS=32
    
    # Performance preferences
    echo
    echo "3. Performance preferences:"
    read -p "Enable benchmarks? (y/n, default: n): " enable_benchmarks
    [[ "$enable_benchmarks" =~ ^[Yy] ]] && ENABLE_BENCHMARKS=true || ENABLE_BENCHMARKS=false
    
    read -p "Cache TTL in seconds (default: $CACHE_TTL): " cache_ttl_input
    CACHE_TTL=${cache_ttl_input:-$CACHE_TTL}
    
    # Output preferences
    echo
    echo "4. Output preferences:"
    if [[ "$ENVIRONMENT" == "development" ]]; then
        LOG_LEVEL="DEBUG"
        OUTPUT_FORMAT="console"
        COLORED_OUTPUT=true
    else
        LOG_LEVEL="INFO"
        OUTPUT_FORMAT="json"
        COLORED_OUTPUT=false
    fi
    
    # Generate configuration file
    cat > "$output_file" << EOF
# Configuration generated by interactive builder
# Environment: $ENVIRONMENT
# Generated: $(date)

# Core settings
MAX_PARALLEL_JOBS=$MAX_PARALLEL_JOBS
CACHE_TTL=$CACHE_TTL
LOG_LEVEL=$LOG_LEVEL

# Output settings
OUTPUT_FORMAT=$OUTPUT_FORMAT
COLORED_OUTPUT=$COLORED_OUTPUT

# Performance settings
ENABLE_BENCHMARKS=$ENABLE_BENCHMARKS
VALIDATE_SCHEMA=true
CHECK_SECURITY=true

# Environment-specific settings
EOF
    
    if [[ "$ENVIRONMENT" == "production" ]]; then
        cat >> "$output_file" << EOF
CHECK_PERFORMANCE=false
DEFAULT_KEEP_DAYS=90
DEFAULT_MAX_RUNS=500
RATE_LIMIT_REQUESTS_PER_MINUTE=30
RATE_LIMIT_DELAY=2
EOF
    else
        cat >> "$output_file" << EOF
CHECK_PERFORMANCE=true
DEFAULT_KEEP_DAYS=30
DEFAULT_MAX_RUNS=100
RATE_LIMIT_REQUESTS_PER_MINUTE=20
RATE_LIMIT_DELAY=3
EOF
    fi
    
    echo
    echo "Configuration file generated: $output_file"
    echo "Review and customize as needed."
}

# Usage: ./interactive-config.sh config/my-config.conf
build_interactive_config "$1"
```

## Container and Orchestration

### Kubernetes Configuration

**Kubernetes ConfigMaps and Secrets:**

```yaml
# kubernetes/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cca-workflows-config
  namespace: default
data:
  production.conf: |
    # Kubernetes Production Configuration
    MAX_PARALLEL_JOBS=8
    CACHE_TTL=3600
    LOG_LEVEL=INFO
    OUTPUT_FORMAT=json
    COLORED_OUTPUT=false
    ENABLE_BENCHMARKS=false
    VALIDATE_SCHEMA=true
    CHECK_SECURITY=true
    CHECK_PERFORMANCE=false
    RATE_LIMIT_REQUESTS_PER_MINUTE=30
    RATE_LIMIT_DELAY=2
    DEFAULT_KEEP_DAYS=90
    DEFAULT_MAX_RUNS=500
    
    # Kubernetes-specific paths
    GITHUB_API_CACHE_DIR=/tmp/cache
    METRICS_DIR=/tmp/metrics

---
apiVersion: v1
kind: Secret
metadata:
  name: cca-workflows-secrets
  namespace: default
type: Opaque
data:
  github-token: <base64-encoded-token>
```

**Kubernetes Deployment with Configuration:**

```yaml
# kubernetes/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cca-workflows
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cca-workflows
  template:
    metadata:
      labels:
        app: cca-workflows
    spec:
      containers:
      - name: cca-workflows
        image: cca-workflows:latest
        env:
        - name: CONFIG_FILE
          value: "/config/production.conf"
        - name: GITHUB_TOKEN
          valueFrom:
            secretKeyRef:
              name: cca-workflows-secrets
              key: github-token
        volumeMounts:
        - name: config-volume
          mountPath: /config
          readOnly: true
        - name: cache-volume
          mountPath: /tmp/cache
        - name: metrics-volume
          mountPath: /tmp/metrics
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
      volumes:
      - name: config-volume
        configMap:
          name: cca-workflows-config
      - name: cache-volume
        emptyDir:
          sizeLimit: 1Gi
      - name: metrics-volume
        emptyDir:
          sizeLimit: 500Mi
```

### Docker Compose Configuration

**Multi-service configuration with Docker Compose:**

```yaml
# docker-compose.yml
version: '3.8'

services:
  cca-workflows:
    build:
      context: .
      dockerfile: Dockerfile
    environment:
      - CONFIG_FILE=/config/production.conf
      - GITHUB_TOKEN=${GITHUB_TOKEN}
    volumes:
      - ./config:/config:ro
      - cache-volume:/tmp/cache
      - metrics-volume:/tmp/metrics
    depends_on:
      - redis
    networks:
      - cca-network

  redis:
    image: redis:7-alpine
    volumes:
      - redis-data:/data
    networks:
      - cca-network

  monitoring:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml:ro
    networks:
      - cca-network

volumes:
  cache-volume:
  metrics-volume:
  redis-data:

networks:
  cca-network:
    driver: bridge
```

## Performance Optimization

### Performance Profiling

**Profile configuration performance impact:**

```bash
# profile-config.sh - Profile configuration performance

profile_configuration() {
    local config_file="$1"
    local iterations="${2:-5}"
    
    echo "Profiling configuration: $config_file"
    echo "Iterations: $iterations"
    echo
    
    local total_time=0
    local max_memory=0
    
    for ((i=1; i<=iterations; i++)); do
        echo "Iteration $i/$iterations..."
        
        # Start memory monitoring
        local memory_monitor_pid
        {
            while kill -0 $$ 2>/dev/null; do
                local current_memory
                current_memory=$(ps -o rss= -p $$ | tr -d ' ')
                [[ $current_memory -gt $max_memory ]] && max_memory=$current_memory
                sleep 0.1
            done
        } &
        memory_monitor_pid=$!
        
        # Time the configuration loading and execution
        local start_time=$(date +%s.%3N)
        CONFIG_FILE="$config_file" ./scripts/analyze-performance.sh --quiet > /dev/null 2>&1
        local end_time=$(date +%s.%3N)
        
        # Stop memory monitoring
        kill $memory_monitor_pid 2>/dev/null || true
        
        local iteration_time=$(echo "$end_time - $start_time" | bc)
        total_time=$(echo "$total_time + $iteration_time" | bc)
        
        echo "  Time: ${iteration_time}s"
    done
    
    local avg_time=$(echo "scale=3; $total_time / $iterations" | bc)
    local max_memory_mb=$(echo "scale=1; $max_memory / 1024" | bc)
    
    echo
    echo "Performance Profile Results:"
    echo "  Average execution time: ${avg_time}s"
    echo "  Peak memory usage: ${max_memory_mb}MB"
    echo "  Total test time: ${total_time}s"
}

# Compare multiple configurations
compare_config_performance() {
    echo "Configuration Performance Comparison"
    echo "===================================="
    echo
    
    local configs=("config/default.conf" "config/optimized.conf" "config/high-performance.conf")
    
    for config in "${configs[@]}"; do
        if [[ -f "$config" ]]; then
            profile_configuration "$config" 3
            echo
        fi
    done
}

# Usage: ./profile-config.sh config/production.conf 5
profile_configuration "$1" "${2:-5}"
```

### Automated Performance Tuning

**Automatically tune configuration for optimal performance:**

```bash
# auto-tune.sh - Automatically tune configuration

auto_tune_configuration() {
    local base_config="$1"
    local output_config="$2"
    
    echo "Auto-tuning configuration based on system performance"
    echo "Base config: $base_config"
    echo "Output config: $output_config"
    echo
    
    # Load base configuration
    source "$base_config"
    
    # Test different MAX_PARALLEL_JOBS values
    local best_parallel_jobs=$MAX_PARALLEL_JOBS
    local best_time=9999
    
    echo "Testing MAX_PARALLEL_JOBS values..."
    for parallel_jobs in 2 4 8 16; do
        if [[ $parallel_jobs -le $(nproc) ]]; then
            echo "  Testing MAX_PARALLEL_JOBS=$parallel_jobs"
            
            # Create temporary config
            local temp_config="/tmp/tune-config-$parallel_jobs.conf"
            cp "$base_config" "$temp_config"
            echo "MAX_PARALLEL_JOBS=$parallel_jobs" >> "$temp_config"
            
            # Time execution
            local start_time=$(date +%s.%3N)
            CONFIG_FILE="$temp_config" timeout 60 ./scripts/analyze-performance.sh --quiet > /dev/null 2>&1
            local end_time=$(date +%s.%3N)
            
            local execution_time=$(echo "$end_time - $start_time" | bc)
            echo "    Time: ${execution_time}s"
            
            if (( $(echo "$execution_time < $best_time" | bc -l) )); then
                best_time=$execution_time
                best_parallel_jobs=$parallel_jobs
            fi
            
            rm -f "$temp_config"
        fi
    done
    
    # Test different CACHE_TTL values
    local best_cache_ttl=$CACHE_TTL
    echo
    echo "Testing CACHE_TTL values..."
    for cache_ttl in 300 900 1800 3600; do
        echo "  Testing CACHE_TTL=$cache_ttl"
        
        # Create temporary config
        local temp_config="/tmp/tune-cache-$cache_ttl.conf"
        cp "$base_config" "$temp_config"
        echo "MAX_PARALLEL_JOBS=$best_parallel_jobs" >> "$temp_config"
        echo "CACHE_TTL=$cache_ttl" >> "$temp_config"
        
        # Time execution (shorter test for cache tuning)
        local start_time=$(date +%s.%3N)
        CONFIG_FILE="$temp_config" timeout 30 ./scripts/analyze-performance.sh --quiet > /dev/null 2>&1
        local end_time=$(date +%s.%3N)
        
        local execution_time=$(echo "$end_time - $start_time" | bc)
        echo "    Time: ${execution_time}s"
        
        if (( $(echo "$execution_time < $best_time" | bc -l) )); then
            best_time=$execution_time
            best_cache_ttl=$cache_ttl
        fi
        
        rm -f "$temp_config"
    done
    
    # Generate optimized configuration
    cp "$base_config" "$output_config"
    cat >> "$output_config" << EOF

# Auto-tuned performance settings
# Generated: $(date)
# Best performance: ${best_time}s

MAX_PARALLEL_JOBS=$best_parallel_jobs
CACHE_TTL=$best_cache_ttl

# Performance optimization flags
ENABLE_CACHE=true
CHECK_PERFORMANCE=false  # Disabled for production speed
VALIDATE_SCHEMA=false    # Disabled for production speed
EOF
    
    echo
    echo "Auto-tuning completed!"
    echo "Optimized configuration saved to: $output_config"
    echo "Best performance settings:"
    echo "  MAX_PARALLEL_JOBS: $best_parallel_jobs"
    echo "  CACHE_TTL: $best_cache_ttl"
    echo "  Execution time: ${best_time}s"
}

# Usage: ./auto-tune.sh config/base.conf config/optimized.conf
auto_tune_configuration "$1" "$2"
```

## Advanced Configuration Failure Scenarios

Advanced configuration setups introduce complexity that can lead to sophisticated failure modes. This section covers error handling for complex scenarios:

### Version Compatibility Failures

#### Node.js Version Incompatibility
```bash
# Failure scenario: Unsupported Node.js version
node --version
# v16.20.0 (below required 18.0.0)

./scripts/analyze-performance.sh

# Expected error output:
┌─────────────────────────────────────────────────────────────────┐
│ [ERROR] Version Compatibility: Node.js version not supported    │
│ Code: NODE_VERSION_UNSUPPORTED                                  │
│ Detail: Version 16.20.0 lacks required ES2022 features         │
│ Required: Node.js 18.0.0 or higher                             │
│ Exit Code: 1                                                    │
└─────────────────────────────────────────────────────────────────┘

# 🕐 Estimated Time: 10-15 minutes
# 🔴 CRITICAL - System will not function without proper Node.js version

# Recovery procedure:
# 1. Install Node.js 18.x or higher
# Download and install Node.js 18.x repository
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
# Install Node.js
sudo apt-get install -y nodejs

# 2. Verify installation
# Check Node.js version (should show 18.x.x or higher)
node --version

# 3. Clear any cached modules to prevent conflicts
# Clean npm cache
npm cache clean --force
# Remove existing modules and lock file
rm -rf node_modules package-lock.json
# Reinstall dependencies with correct Node.js version
npm install

# Prevention strategy:
# - Use .nvmrc file to specify Node.js version
echo "18.19.0" > .nvmrc
# - Add version check to CI/CD pipelines
# - Use Docker containers with pinned Node.js versions
```

#### GitHub CLI Version Conflicts
```bash
# Failure scenario: Legacy GitHub CLI causing API errors
gh --version
# gh version 1.14.0 (2021-09-27)

./scripts/analyze-performance.sh

# Expected error output:
┌─────────────────────────────────────────────────────────────────┐
│ [ERROR] Version Compatibility: GitHub CLI version not supported │
│ Code: GH_CLI_VERSION_UNSUPPORTED                                │
│ Detail: Legacy API endpoints may have rate limiting issues      │
│ Required: gh 2.0.0 or higher for advanced GraphQL features     │
│ Exit Code: 1                                                    │
└─────────────────────────────────────────────────────────────────┘

# 🕐 Estimated Time: 5-10 minutes
# 🟡 WARNING - API functionality may be limited with legacy version

# Recovery procedure:
# 1. Remove old version
# Uninstall legacy GitHub CLI
sudo apt remove gh

# 2. Install latest version
# Add GitHub CLI repository key
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
# Add repository to sources
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
# Update and install latest GitHub CLI
sudo apt update && sudo apt install gh

# 3. Re-authenticate
# Login with new GitHub CLI version
gh auth login

# Prevention strategy:
# - Pin GitHub CLI version in Docker containers
# - Add version checks to setup scripts
# - Document minimum versions in README
```

### Dynamic Configuration Failures

#### Adaptive Configuration Calculation Errors
```bash
# Failure scenario: System resource detection fails
export CONFIG_FILE="config/adaptive.conf"
./scripts/analyze-performance.sh

# Expected error output:
┌─────────────────────────────────────────────────────────────────┐
│ [ERROR] Resource Detection: Cannot determine system resources   │
│ Code: SYSTEM_RESOURCE_DETECTION_FAILED                         │
│ Detail: CPU detection failed - nproc command not available     │
│         Memory detection failed - free command not available   │
│ Fallback: Using conservative defaults                          │
│ Exit Code: 0 (continues with defaults)                        │
└─────────────────────────────────────────────────────────────────┘

# 🕐 Estimated Time: 5-8 minutes
# 🔵 INFO - System continues with safe defaults

# Recovery procedure:
# 1. Install missing system tools
# Install process and system utilities
sudo apt-get install procps util-linux coreutils

# 2. Or provide manual overrides
# Set parallel jobs based on your system
export MAX_PARALLEL_JOBS=4
# Set cache TTL (30 minutes)
export CACHE_TTL=1800
# Run with manual configuration
./scripts/analyze-performance.sh

# Prevention strategy:
# - Test adaptive configuration on target platforms
# - Provide fallback values for all calculations
# - Add system tool availability checks
```

#### Network Latency Detection Failures
```bash
# Failure scenario: Network latency check fails
export CONFIG_FILE="config/adaptive.conf"
./scripts/analyze-performance.sh

# Expected error output:
┌─────────────────────────────────────────────────────────────────┐
│ [WARNING] Network Detection: Network latency detection failed   │
│ Code: NETWORK_LATENCY_DETECTION_FAILED                         │
│ Detail: Could not resolve host api.github.com                  │
│ Fallback: Using default rate limiting settings                 │
│ Impact: May result in suboptimal performance                   │
└─────────────────────────────────────────────────────────────────┘

# 🕐 Estimated Time: 10-20 minutes  
# 🟡 WARNING - Network issues may impact performance

# Recovery procedure:
# 1. Check network connectivity
# Test basic connectivity to GitHub API
ping api.github.com

# 2. Check DNS resolution
# Verify DNS can resolve GitHub domains
nslookup api.github.com

# 3. Configure proxy if needed
# Set HTTP proxy for corporate networks
export HTTP_PROXY="http://proxy.company.com:8080"
export HTTPS_PROXY="http://proxy.company.com:8080"

# 4. Or override rate limiting manually
# Use conservative rate limiting
export RATE_LIMIT_REQUESTS_PER_MINUTE=15
export RATE_LIMIT_DELAY=4

# Prevention strategy:
# - Add network connectivity checks
# - Provide offline configuration modes
# - Document proxy configuration requirements
```

### Profile-Based Configuration Failures

#### Profile Loading Errors
```bash
# Failure scenario: Invalid profile specification
export CONFIG_PROFILE=STAGING
export CONFIG_FILE="config/profiles.conf"
./scripts/analyze-performance.sh

# Expected error output:
# ERROR: Unknown configuration profile: STAGING
# Available profiles: DEVELOPMENT, PRODUCTION, CI
# Check CONFIG_PROFILE environment variable

# Recovery procedure:
export CONFIG_PROFILE=PRODUCTION
./scripts/validate-config.sh

# Prevention strategy:
# - Add profile validation with helpful error messages
# - Document available profiles clearly
# - Provide profile auto-detection based on environment
```

#### Hierarchical Profile Inheritance Failures
```bash
# Failure scenario: Circular profile inheritance
# In config/hierarchical-profiles.conf:
# PROFILE_A() { PROFILE_B; }
# PROFILE_B() { PROFILE_A; }

export CONFIG_PROFILE=A
export CONFIG_FILE="config/hierarchical-profiles.conf"
./scripts/analyze-performance.sh

# Expected error output:
# ERROR: Circular profile inheritance detected
# Profile inheritance chain: A -> B -> A
# This creates an infinite loop during configuration loading

# Recovery procedure:
# 1. Fix profile inheritance in configuration file
# Edit config/hierarchical-profiles.conf to remove circular dependencies

# 2. Test profile loading
./scripts/validate-config.sh

# Prevention strategy:
# - Implement inheritance cycle detection
# - Document profile inheritance patterns
# - Use profile dependency graphs for complex setups
```

### Container and Orchestration Failures

#### Container Resource Constraint Failures
```bash
# Failure scenario: Container memory limits causing OOM kills
# docker-compose.yml has: mem_limit: 512m
# Configuration uses: MAX_PARALLEL_JOBS=16, CACHE_TTL=7200

docker-compose up cca-workflows

# Expected error output:
# Container killed due to memory limit (exit code 137)
# Memory usage exceeded 512MB limit
# Large cache and high parallelism consuming excessive memory

# Recovery procedure:
# 1. Reduce resource usage
export MAX_PARALLEL_JOBS=2
export CACHE_TTL=900
export ENABLE_BENCHMARKS=false

# 2. Or increase container limits
# In docker-compose.yml:
# mem_limit: 2g

# 3. Monitor actual usage
docker stats cca-workflows

# Prevention strategy:
# - Use memory-appropriate configuration profiles
# - Add resource monitoring to containers
# - Test configurations under resource constraints
```

#### Kubernetes ConfigMap Update Failures
```bash
# Failure scenario: ConfigMap update not propagated to pods
kubectl apply -f kubernetes/configmap.yaml

# Expected behavior: Pods should pick up new configuration
# Actual behavior: Pods still using old configuration

# Recovery procedure:
# 1. Check ConfigMap update
kubectl get configmap cca-workflows-config -o yaml

# 2. Restart pods to pick up changes
kubectl rollout restart deployment/cca-workflows

# 3. Verify configuration in running pod
kubectl exec deployment/cca-workflows -- cat /config/production.conf

# Prevention strategy:
# - Use rolling updates for configuration changes
# - Implement configuration reload mechanisms
# - Add configuration versioning to ConfigMaps
```

### Performance Optimization Failures

#### Auto-Tuning Algorithm Failures
```bash
# Failure scenario: Auto-tuning produces worse performance
./scripts/auto-tune.sh config/base.conf config/optimized.conf

# Expected: Optimized configuration with better performance
# Actual: Auto-tuned configuration performs worse than original

# Diagnosis output:
# Auto-tuning completed!
# Best performance settings:
#   MAX_PARALLEL_JOBS: 32 (system only has 4 cores)
#   CACHE_TTL: 300 (very short, causing frequent API calls)
#   Execution time: 180s (worse than original 45s)

# Recovery procedure:
# 1. Revert to known good configuration
cp config/base.conf config/optimized.conf

# 2. Manual tuning with system awareness
export MAX_PARALLEL_JOBS=$(nproc)  # 4 cores
export CACHE_TTL=1800  # 30 minutes
./scripts/benchmark-performance.sh

# Prevention strategy:
# - Add sanity checks to auto-tuning algorithms
# - Use conservative tuning boundaries
# - Implement performance regression detection
```

#### Benchmark Inconsistency Issues
```bash
# Failure scenario: Benchmark results vary significantly between runs
./scripts/profile-config.sh config/production.conf 5

# Expected: Consistent timing results
# Actual: High variance in measurements

# Sample output:
# Iteration 1/5... Time: 45.234s
# Iteration 2/5... Time: 78.901s  # Significant variance
# Iteration 3/5... Time: 43.123s
# Average execution time: 55.753s (high standard deviation)

# Root causes:
# - System load fluctuations
# - Network latency variations
# - Cache state differences between runs

# Recovery procedure:
# 1. Run benchmarks under controlled conditions
export MAX_PARALLEL_JOBS=1  # Reduce system load impact
./scripts/profile-config.sh config/production.conf 10  # More iterations

# 2. Clear caches between runs
rm -rf /tmp/github-api-cache/* /tmp/performance-metrics/*

# 3. Use statistical analysis
./scripts/benchmark-with-statistics.sh config/production.conf

# Prevention strategy:
# - Implement warmup phases for benchmarks
# - Use median instead of average for timing
# - Add confidence intervals to results
```

### Error Recovery and Fallback Strategies

#### Graceful Degradation Patterns
```bash
# Implementation: Fallback configuration loading
load_config_with_fallback() {
    local primary_config="$1"
    local fallback_config="$2"
    
    if [[ -f "$primary_config" ]] && validate_config_file "$primary_config"; then
        source "$primary_config"
        log_info "Loaded configuration from: $primary_config"
    elif [[ -f "$fallback_config" ]] && validate_config_file "$fallback_config"; then
        source "$fallback_config"
        log_warn "Primary config failed, using fallback: $fallback_config"
    else
        log_error "Both primary and fallback configurations failed"
        use_safe_defaults
    fi
}

# Usage example:
load_config_with_fallback "config/production.conf" "config/safe-defaults.conf"
```

#### Configuration Rollback Mechanisms
```bash
# Implementation: Configuration versioning and rollback
backup_current_config() {
    local config_file="$1"
    local backup_dir="config/backups"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    mkdir -p "$backup_dir"
    cp "$config_file" "$backup_dir/$(basename "$config_file").$timestamp"
    
    # Keep only last 10 backups
    ls -t "$backup_dir"/$(basename "$config_file").* | tail -n +11 | xargs rm -f
}

rollback_config() {
    local config_file="$1"
    local backup_dir="config/backups"
    
    # Get most recent backup
    local latest_backup=$(ls -t "$backup_dir"/$(basename "$config_file").* | head -n1)
    
    if [[ -f "$latest_backup" ]]; then
        cp "$latest_backup" "$config_file"
        log_info "Configuration rolled back to: $latest_backup"
    else
        log_error "No backup found for rollback"
        return 1
    fi
}
```

This advanced configuration guide provides sophisticated configuration management capabilities for expert users and complex deployment scenarios. The patterns and techniques described here enable fine-tuned performance optimization and flexible configuration management across diverse environments.

For foundational configuration topics, see the related documentation:
- **[CONFIGURATION.md](CONFIGURATION.md)** - Core configuration options and basic setup
- **[SECURITY-OVERVIEW.md](../SECURITY-OVERVIEW.md)** - Security overview and quick start guide
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Troubleshooting configuration issues