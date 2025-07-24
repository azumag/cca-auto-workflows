# Security Configuration Guide

This guide covers comprehensive security practices for configuration management in Claude Code Auto Workflows.

**Related Documentation:**
- [CONFIGURATION.md](CONFIGURATION.md) - Core configuration options and basic setup
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Troubleshooting configuration issues
- [ADVANCED.md](ADVANCED.md) - Advanced configuration patterns and version compatibility

## Table of Contents

- [Token Management Best Practices](#token-management-best-practices)
- [Secure Configuration Storage Guidelines](#secure-configuration-storage-guidelines)
- [Access Control Considerations](#access-control-considerations)
- [Security Validation and Monitoring](#security-validation-and-monitoring)
- [Container Security Configuration](#container-security-configuration)
- [Network Security Configuration](#network-security-configuration)

## Token Management Best Practices

### GitHub Token Security

**GitHub Token Types and Usage:**
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

### Multi-Environment Token Strategy

**Environment-Specific Token Management:**
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

### Token Validation and Monitoring

**Token Validation Functions:**
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

## Secure Configuration Storage Guidelines

### Configuration File Security

**File Permissions and Ownership:**
```bash
# Set restrictive permissions on all configuration files
find config/ -name "*.conf" -exec chmod 600 {} \;
find config/ -name "*.conf" -exec chown $(whoami):$(whoami) {} \;

# For production systems, use even more restrictive permissions
chmod 400 config/production.conf  # Read-only for owner
chown root:root config/production.conf  # Root ownership
```

### Secrets Management Integration

**AWS Secrets Manager Integration:**
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
```

**HashiCorp Vault Integration:**
```bash
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

### Encrypted Configuration Files

**GPG Encryption for Sensitive Configurations:**
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

### Environment Variable Security

**Secure Environment Variable Handling:**
```bash
# Never commit sensitive values to configuration files
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

## Access Control Considerations

### User and Group Permissions

**System User Setup for Production:**
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

### Role-Based Access Control

**RBAC Implementation:**
```bash
# Define roles and permissions
declare -A ROLE_PERMISSIONS
ROLE_PERMISSIONS[read-only]="config:read metrics:read"
ROLE_PERMISSIONS[operator]="config:read config:validate metrics:read analysis:run"
ROLE_PERMISSIONS[admin]="config:read config:write config:validate metrics:read metrics:write analysis:run system:admin"

# Check user permissions
check_permission() {
    local required_permission="$1"
    local user_role="${USER_ROLE:-read-only}"
    
    if [[ "${ROLE_PERMISSIONS[$user_role]}" == *"$required_permission"* ]]; then
        return 0
    else
        log_error "Access denied: $required_permission permission required"
        return 1
    fi
}

# Usage in scripts
if ! check_permission "config:write"; then
    exit 1
fi
```

## Security Validation and Monitoring

### Configuration Security Audit

**Comprehensive Security Audit Script:**
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

### Security Event Logging

**Security Event Monitoring:**
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

### Intrusion Detection

**Configuration Tampering Detection:**
```bash
# Generate configuration checksums
generate_config_checksums() {
    local checksum_file="config/checksums.sha256"
    
    find config/ -name "*.conf" -exec sha256sum {} \; > "$checksum_file"
    chmod 600 "$checksum_file"
    
    log_info "Configuration checksums generated: $checksum_file"
}

# Verify configuration integrity
verify_config_integrity() {
    local checksum_file="config/checksums.sha256"
    
    if [[ ! -f "$checksum_file" ]]; then
        log_warn "Configuration checksum file not found"
        return 1
    fi
    
    if sha256sum -c "$checksum_file" --quiet; then
        log_info "Configuration integrity verified"
        return 0
    else
        log_security_event "CONFIG_INTEGRITY_VIOLATION" "Configuration files have been modified"
        return 1
    fi
}

# Monitor configuration files for changes
monitor_config_changes() {
    if command -v inotifywait >/dev/null; then
        inotifywait -m -e modify,create,delete config/ --format '%w%f %e %T' --timefmt '%Y-%m-%d %H:%M:%S' |
        while read file event time; do
            log_security_event "CONFIG_FILE_MODIFIED" "File: $file, Event: $event, Time: $time"
        done
    fi
}
```

## Network Security Configuration

### GitHub Enterprise Server Configuration

**Enterprise Security Settings:**
```bash
# GitHub Enterprise Server configuration
GITHUB_ENTERPRISE_URL="https://github.enterprise.com"
GITHUB_API_URL="$GITHUB_ENTERPRISE_URL/api/v3"

# Certificate validation (never disable in production)
VERIFY_SSL_CERTIFICATES=true

# Custom certificate authority
if [[ -n "$CUSTOM_CA_CERT" ]]; then
    export CURL_CA_BUNDLE="$CUSTOM_CA_CERT"
fi

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
    
    curl "${curl_opts[@]}" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        -X "$method" \
        "$GITHUB_API_URL/$endpoint"
}
```

### Proxy Configuration

**Corporate Proxy Security:**
```bash
# Proxy configuration for corporate environments
HTTP_PROXY="http://proxy.company.com:8080"
HTTPS_PROXY="http://proxy.company.com:8080"
NO_PROXY="localhost,127.0.0.1,.company.com"

# Secure proxy authentication
if [[ -n "$PROXY_USERNAME" && -n "$PROXY_PASSWORD" ]]; then
    HTTP_PROXY="http://$PROXY_USERNAME:$PROXY_PASSWORD@proxy.company.com:8080"
    HTTPS_PROXY="http://$PROXY_USERNAME:$PROXY_PASSWORD@proxy.company.com:8080"
fi

# Use proxy in API calls
github_api_call_with_proxy() {
    local endpoint="$1"
    local method="${2:-GET}"
    
    local curl_opts=()
    
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

## Container Security Configuration

### Docker Security Best Practices

**Secure Container Configuration:**
```bash
# Container security best practices
# Use in Dockerfile:
# FROM node:18.19-alpine
# RUN addgroup -g 1001 -S nodejs && adduser -S appuser -u 1001 -G nodejs
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

### Kubernetes Security

**Kubernetes Security Configuration:**
```yaml
# kubernetes/security-context.yaml
apiVersion: v1
kind: SecurityContext
metadata:
  name: cca-workflows-security-context
spec:
  runAsNonRoot: true
  runAsUser: 1001
  runAsGroup: 1001
  fsGroup: 1001
  seccompProfile:
    type: RuntimeDefault
  capabilities:
    drop:
      - ALL
    add:
      - NET_CONNECT
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
```

### Secret Management in Containers

**Container Secret Management:**
```bash
# Use Kubernetes secrets for sensitive data
# kubectl create secret generic github-token --from-literal=token=your-token

# Mount secrets as files (more secure than environment variables)
# In Kubernetes deployment:
# volumeMounts:
#   - name: github-token
#     mountPath: /etc/secrets
#     readOnly: true
# volumes:
#   - name: github-token
#     secret:
#       secretName: github-token
#       defaultMode: 0400

# Read secrets from mounted files
load_secret_from_file() {
    local secret_file="$1"
    
    if [[ -r "$secret_file" ]]; then
        cat "$secret_file"
    else
        log_error "Cannot read secret file: $secret_file"
        return 1
    fi
}

# Usage
GITHUB_TOKEN=$(load_secret_from_file "/etc/secrets/token")
```

## Security Checklist

### Pre-Deployment Security Checklist

- [ ] **Token Security**
  - [ ] GitHub tokens are not hardcoded in configuration files
  - [ ] Tokens use minimal required scopes
  - [ ] Token rotation schedule is documented
  - [ ] Token validation is performed before use

- [ ] **Configuration File Security**
  - [ ] Configuration files have restrictive permissions (600 or 400)
  - [ ] Sensitive values are stored in external secret management systems
  - [ ] Configuration integrity monitoring is enabled
  - [ ] No sensitive data is committed to version control

- [ ] **Access Control**
  - [ ] Dedicated system user is created for production deployments
  - [ ] Directory permissions follow the principle of least privilege
  - [ ] Role-based access control is implemented where applicable

- [ ] **Network Security**
  - [ ] SSL certificate verification is enabled
  - [ ] Proxy configuration is secure (if applicable)
  - [ ] GitHub Enterprise settings are properly configured (if applicable)

- [ ] **Container Security** (if using containers)
  - [ ] Containers run as non-root user
  - [ ] Read-only root filesystem is enabled
  - [ ] Unnecessary capabilities are dropped
  - [ ] Secrets are mounted as files, not environment variables

- [ ] **Monitoring and Auditing**
  - [ ] Security event logging is configured
  - [ ] Configuration security audit is performed
  - [ ] Intrusion detection for configuration files is enabled
  - [ ] Regular security reviews are scheduled

### Incident Response

**Security Incident Response Procedures:**
```bash
# In case of suspected token compromise
revoke_github_token() {
    local token="$1"
    log_security_event "TOKEN_REVOCATION" "Revoking potentially compromised token"
    
    # Disable token (implementation depends on token type)
    # For GitHub App tokens, regenerate the app's private key
    # For PATs, revoke through GitHub web interface or API
    
    # Update configuration with new token
    # notify_security_team "GitHub token has been revoked and replaced"
}

# In case of configuration tampering
respond_to_config_tampering() {
    log_security_event "CONFIG_TAMPERING_RESPONSE" "Responding to configuration tampering"
    
    # Stop all running processes
    pkill -f "cca-workflows" || true
    
    # Restore configuration from backup
    restore_config_from_backup
    
    # Verify configuration integrity
    if verify_config_integrity; then
        log_info "Configuration restored successfully"
    else
        log_error "Configuration restoration failed - manual intervention required"
    fi
}
```

This security configuration guide provides comprehensive protection for Claude Code Auto Workflows. Regular security reviews and updates to these practices are essential for maintaining a secure configuration management system.

For additional configuration topics, see the related documentation:
- **[CONFIGURATION.md](CONFIGURATION.md)** - Core configuration options and basic setup
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Systematic diagnosis and resolution of configuration issues
- **[ADVANCED.md](ADVANCED.md)** - Advanced configuration patterns and version compatibility