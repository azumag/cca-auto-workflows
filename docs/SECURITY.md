# Security Configuration Guide

This guide covers comprehensive security practices for configuration management in Claude Code Auto Workflows.

> ⚠️ **CRITICAL SECURITY WARNING**
> 
> Never commit secrets, tokens, or passwords to version control. Always use external secret management systems and validate configurations before deployment.

## 🔒 Security Quick Reference

| Security Area | Critical Requirements | Quick Actions |
|---|---|---|
| **Token Management** | Use minimal scopes, rotate regularly, never log tokens | `validate_github_token()`, `monitor_token_usage()` |
| **File Permissions** | 600 for config files, 400 for production | `chmod 600 config/*.conf` |
| **SSL Verification** | Always enabled in production | `VERIFY_SSL_CERTIFICATES=true` |
| **Container Security** | Non-root user, read-only filesystem | `--user 1001:1001 --read-only` |

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

> 📋 **SUMMARY: Token Management Essentials**
> 
> - **Use GitHub App tokens** for higher rate limits and better security
> - **Rotate tokens every 90 days** and document expiration dates
> - **Apply minimal scopes** - only grant necessary permissions
> - **Never log tokens** in debug output or configuration files
> - **Validate tokens** before use with `validate_github_token()`

### GitHub Token Security

> ⚠️ **WARNING:** GitHub tokens with excessive scopes pose significant security risks. Always use the principle of least privilege.

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

> 📋 **SUMMARY: Configuration Storage Essentials**
> 
> - **File permissions:** 600 for config files, 400 for production
> - **Never store secrets** in configuration files - use external secret management
> - **Encrypt sensitive configs** using GPG or similar encryption
> - **Validate no placeholders** remain in production environments

### Configuration File Security

> ⚠️ **CRITICAL:** Configuration files with world-readable permissions expose sensitive data to all system users.

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

> 💡 **BEST PRACTICE:** Use external secret management systems like AWS Secrets Manager, HashiCorp Vault, or Kubernetes secrets for production environments.

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

> ⚠️ **WARNING:** Environment variables can be exposed through process lists. Use `.env` files for local development only and never commit them to version control.

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

> 📋 **SUMMARY: Access Control Essentials**
> 
> - **Dedicated system user** for production deployments
> - **Restrictive directory permissions** (750 for install, 700 for config)
> - **Role-based access control** with defined permissions
> - **Principle of least privilege** for all user accounts

### User and Group Permissions

> ⚠️ **SECURITY REQUIREMENT:** Never run production services as root. Create dedicated system users with minimal privileges.

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

> 📋 **SUMMARY: Security Monitoring Essentials**
> 
> - **Regular security audits** using automated scripts
> - **Security event logging** to detect breaches
> - **Configuration integrity monitoring** with checksums
> - **Real-time intrusion detection** for configuration files

### Configuration Security Audit

> 💡 **BEST PRACTICE:** Run security audits regularly and after any configuration changes to maintain security posture.

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

> 📋 **SUMMARY: Network Security Essentials**
> 
> - **SSL certificate verification** must always be enabled in production
> - **Custom CA certificates** properly installed when using enterprise GitHub
> - **Secure proxy configuration** without hardcoded credentials
> - **Network traffic encryption** for all API communications

### GitHub Enterprise Server Configuration

> ⚠️ **CRITICAL:** Never disable SSL certificate verification in production environments. This exposes communications to man-in-the-middle attacks.

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

> 📋 **SUMMARY: Container Security Essentials**
> 
> - **Non-root user** (1001:1001) for all container processes
> - **Read-only root filesystem** with specific tmpfs mounts
> - **Dropped capabilities** - remove ALL, add only necessary ones
> - **Secret mounting as files** instead of environment variables

### Docker Security Best Practices

> ⚠️ **WARNING:** Running containers with `--privileged` or as root user creates significant security vulnerabilities and potential container escape risks.

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

## Security Failure Scenarios

This section covers comprehensive security failure scenarios, their detection, and recovery procedures:

### Token Authentication Failures

#### GitHub Token Validation Failures
```bash
# Failure scenario: Invalid or expired GitHub token
export GITHUB_TOKEN="ghp_invalid_token_example"
./scripts/analyze-performance.sh

# Expected error output:
┌─────────────────────────────────────────────────────────────────┐
│ [ERROR] Token Authentication: GitHub token validation failed    │
│ Code: GITHUB_TOKEN_VALIDATION_FAILED                           │
│ Detail: HTTP 401 Bad credentials                               │
│ Cause: Token may be expired, revoked, or malformed             │
│ Exit Code: 1                                                    │
└─────────────────────────────────────────────────────────────────┘

# 🕐 Estimated Time: 10-20 minutes
# 🔴 CRITICAL - Authentication required for all operations

# Recovery procedure:
# 1. Generate new GitHub token
# Refresh authentication with required scopes
gh auth refresh -h github.com -s repo,read:org

# 2. Update token securely
# Set new token (replace with actual token)
export GITHUB_TOKEN="ghp_new_valid_token"
# Verify configuration accepts new token
./scripts/validate-config.sh

# 3. Test token access
# Verify token has API access
curl -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/rate_limit

# Prevention strategy:
# - Set up token expiration monitoring
# - Use GitHub Apps for higher rate limits and better security
# - Implement token rotation procedures
# - Add token validation to CI/CD pipelines
```

#### Token Scope Insufficient Failures
```bash
# Failure scenario: GitHub token lacks required permissions
export GITHUB_TOKEN="ghp_token_with_limited_scope"
./scripts/analyze-performance.sh

# Expected error output:
┌─────────────────────────────────────────────────────────────────┐
│ [ERROR] Token Authorization: Insufficient token permissions     │
│ Code: GITHUB_TOKEN_INSUFFICIENT_SCOPE                          │
│ Detail: HTTP 403 - Token missing required scope 'repo'         │
│ Current Scopes: public_repo                                     │
│ Required Scopes: repo, read:org, actions:read, metadata:read   │
│ Exit Code: 1                                                    │
└─────────────────────────────────────────────────────────────────┘

# 🕐 Estimated Time: 15-25 minutes
# 🔴 CRITICAL - Operations blocked without proper permissions

# Recovery procedure:
# 1. Create token with required scopes
# Navigate to GitHub Settings > Developer settings > Personal access tokens
# Create new token with: repo, read:org, actions:read, metadata:read

# 2. Update configuration
# Set new token with proper scopes
export GITHUB_TOKEN="ghp_token_with_correct_scopes"

# Prevention strategy:
# - Document required token scopes clearly
# - Implement scope validation in scripts
# - Use fine-grained tokens when possible
# - Add scope checking to setup documentation
```

#### Token Exposure in Logs
```bash
# Failure scenario: Token accidentally logged in debug output
export LOG_LEVEL=DEBUG
export GITHUB_TOKEN="ghp_exposed_token_example"
./scripts/analyze-performance.sh

# Security risk: Token visible in logs
# DEBUG: Executing curl -H "Authorization: Bearer ghp_exposed_token_example"

# Immediate containment:
# 1. Stop all running processes
pkill -f "analyze-performance"

# 2. Revoke exposed token immediately
gh auth refresh  # Revoke current token
# Or manually revoke via GitHub web interface

# 3. Clear logs containing token
sudo find /var/log -name "*.log" -exec grep -l "ghp_" {} \; | xargs sudo shred -u
grep -r "ghp_" ~/.local/share/systemd/user/ 2>/dev/null | cut -d: -f1 | xargs rm -f

# 4. Generate new token
gh auth login --scopes "repo,read:org,actions:read"

# Prevention strategy:
# - Implement token redaction in all log outputs
# - Use log sanitization functions
# - Add token detection to security audits
# - Review log retention policies
```

#### Rate Limiting and API Abuse
```bash
# Failure scenario: Excessive API usage triggering GitHub security measures
export RATE_LIMIT_REQUESTS_PER_MINUTE=1000  # Excessive rate
export RATE_LIMIT_DELAY=0.1  # Too aggressive
./scripts/analyze-performance.sh

# Expected error output:
# ERROR: GitHub API rate limit exceeded (secondary limit)
# HTTP 403: You have exceeded a secondary rate limit
# Account temporarily blocked from API access
# Contact GitHub support for resolution

# Recovery procedure:
# 1. Immediately reduce API usage
export RATE_LIMIT_REQUESTS_PER_MINUTE=15
export RATE_LIMIT_DELAY=4

# 2. Wait for rate limit reset (typically 1 hour for secondary limits)
echo "Waiting for rate limit reset..."
sleep 3600

# 3. Contact GitHub support if block persists
# Provide: account details, use case, and mitigation steps taken

# Prevention strategy:
# - Implement conservative rate limiting by default
# - Add secondary rate limit detection
# - Use exponential backoff for retries
# - Monitor API usage patterns
```

### Configuration Security Breaches

#### Unauthorized Configuration Access
```bash
# Failure scenario: Configuration files compromised
# Attacker modifies config/production.conf to exfiltrate data

# Detection indicators:
# - Unexpected changes to configuration files
# - File modification timestamps don't match deployment records
# - Configuration validation fails with unknown values

# Security response:
# 1. Immediately isolate affected systems
systemctl stop cca-workflows
docker stop cca-workflows-container

# 2. Verify configuration integrity
./scripts/verify-config-integrity.sh

# Expected output for compromised config:
# ERROR: Configuration integrity check failed
# File: config/production.conf
# Expected checksum: a1b2c3d4e5f6...
# Actual checksum:   x7y8z9w0v1u2...
# File has been modified outside of normal procedures

# 3. Restore from known good backup
restore_config_from_backup config/production.conf

# 4. Rotate all sensitive credentials
./scripts/rotate-all-credentials.sh

# Prevention strategy:
# - Implement file integrity monitoring
# - Use immutable configuration in production
# - Restrict configuration file access
# - Add configuration change audit logging
```

#### Secrets Management System Failures
```bash
# Failure scenario: AWS Secrets Manager access failure
export AWS_REGION=us-east-1
export SECRET_NAME="github-app-token"
./scripts/analyze-performance.sh

# Expected error output:
# ERROR: Failed to retrieve secret from AWS Secrets Manager
# AccessDenied: User: arn:aws:iam::123456789:user/cca-workflows 
# is not authorized to perform: secretsmanager:GetSecretValue
# on resource: arn:aws:secretsmanager:us-east-1:123456789:secret:github-app-token

# Recovery procedure:
# 1. Check IAM permissions
aws iam list-attached-user-policies --user-name cca-workflows

# 2. Add required permissions
aws iam attach-user-policy \
    --user-name cca-workflows \
    --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite

# 3. Test secret access
aws secretsmanager get-secret-value --secret-id github-app-token

# 4. Fallback to environment variables temporarily
export GITHUB_TOKEN="temporary_fallback_token"

# Prevention strategy:
# - Test secrets access in staging environments
# - Implement graceful fallback to alternative secret sources
# - Add IAM permission validation to deployment scripts
# - Monitor secrets access for anomalies
```

### Network Security Failures

#### SSL Certificate Validation Bypass
```bash
# Failure scenario: SSL verification disabled in production
export VERIFY_SSL_CERTIFICATES=false
export GITHUB_API_URL="https://github.enterprise.com/api/v3"
./scripts/analyze-performance.sh

# Security risk: Man-in-the-middle attacks possible
# WARNING: SSL certificate verification is disabled
# This exposes API communications to interception
# Production environments should never disable SSL verification

# Immediate remediation:
# 1. Re-enable SSL verification
export VERIFY_SSL_CERTIFICATES=true

# 2. If custom CA is needed, install it properly
sudo cp custom-ca.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates

# 3. Test SSL connectivity
openssl s_client -connect github.enterprise.com:443 -CAfile /etc/ssl/certs/ca-certificates.crt

# Prevention strategy:
# - Never allow SSL bypass in production configurations
# - Implement certificate pinning for critical APIs
# - Add SSL configuration validation to security audits
# - Document proper CA certificate installation procedures
```

#### Proxy Configuration Vulnerabilities
```bash
# Failure scenario: Insecure proxy credentials in configuration
cat config/production.conf

# Security risk: Plaintext proxy credentials
HTTP_PROXY="http://user:password123@proxy.company.com:8080"
HTTPS_PROXY="http://user:password123@proxy.company.com:8080"

# Immediate containment:
# 1. Remove plaintext credentials from configuration
sed -i 's/user:password123@//g' config/production.conf

# 2. Use secure credential storage
export PROXY_USERNAME="user"
export PROXY_PASSWORD="$(aws secretsmanager get-secret-value --secret-id proxy-credentials --query SecretString --output text)"

# 3. Reconstruct proxy URLs securely
HTTP_PROXY="http://$PROXY_USERNAME:$PROXY_PASSWORD@proxy.company.com:8080"

# Prevention strategy:
# - Never store proxy credentials in configuration files
# - Use environment variables or secrets management
# - Implement credential scanning in CI/CD
# - Add proxy security to configuration audits
```

### Container Security Breaches

#### Container Escape Attempts
```bash
# Failure scenario: Container running with excessive privileges
docker run --privileged -v /:/host cca-workflows:latest

# Security risk: Container can access host system
# ERROR: Container security violation detected
# Container running with --privileged flag
# Host filesystem mounted at /host
# This configuration allows container escape

# Immediate response:
# 1. Stop insecure container
docker stop $(docker ps -q --filter ancestor=cca-workflows)

# 2. Run with secure configuration
docker run \
    --user 1001:1001 \
    --read-only \
    --tmpfs /tmp:size=100M,noexec \
    --security-opt no-new-privileges:true \
    --cap-drop ALL \
    --cap-add NET_CONNECT \
    cca-workflows:latest

# Prevention strategy:
# - Implement container security policies
# - Use security scanning for container images
# - Add runtime security monitoring
# - Document secure container configuration
```

#### Secrets Exposed as Environment Variables
```bash
# Failure scenario: Secrets passed as environment variables in container
docker run -e GITHUB_TOKEN="ghp_sensitive_token" cca-workflows:latest

# Security risk: Secrets visible in process list and container inspect
docker inspect cca-workflows | grep -i "ghp_"

# Immediate mitigation:
# 1. Stop container with exposed secrets
docker stop cca-workflows

# 2. Use secure secret mounting
docker run \
    -v /path/to/secrets:/etc/secrets:ro \
    --tmpfs /tmp \
    cca-workflows:latest

# 3. Update application to read from mounted files
GITHUB_TOKEN=$(cat /etc/secrets/github-token)

# Prevention strategy:
# - Always mount secrets as files, never environment variables
# - Use Kubernetes secrets for orchestrated environments
# - Implement secret scanning for container configurations
# - Add secrets management to security training
```

### Access Control Failures

#### Privilege Escalation Attempts
```bash
# Failure scenario: Service attempting to gain root privileges
sudo -u cca-workflows ./scripts/analyze-performance.sh

# During execution, script attempts:
sudo systemctl restart some-service

# Security detection:
# WARNING: Unauthorized privilege escalation attempt
# User: cca-workflows
# Command: sudo systemctl restart some-service
# This user should not have sudo privileges

# Immediate response:
# 1. Review and restrict sudo permissions
sudo visudo
# Remove any entries for cca-workflows user

# 2. Check for other privilege escalation vectors
find /usr/local/bin -perm -4000 -user cca-workflows  # Check for setuid files
ps aux | grep cca-workflows  # Monitor running processes

# 3. Implement least privilege access
# Create restricted service user
sudo useradd -r -s /bin/false -M cca-workflows-service
sudo usermod -L cca-workflows-service  # Lock password

# Prevention strategy:
# - Use principle of least privilege
# - Regular access audits
# - Implement sudo logging and monitoring
# - Use service accounts with minimal permissions
```

#### Configuration File Permission Violations
```bash
# Failure scenario: Configuration files with world-readable permissions
ls -la config/production.conf
# -rw-rw-rw- 1 cca-workflows cca-workflows 2048 Jul 24 10:00 production.conf

# Security risk: Sensitive configuration readable by all users
# Anyone on the system can read:
# - GitHub tokens
# - Database passwords
# - API keys

# Immediate remediation:
# 1. Fix file permissions
chmod 600 config/production.conf
chown cca-workflows:cca-workflows config/production.conf

# 2. Check for other exposed files
find config/ -type f -perm /o+r -exec ls -la {} \;

# 3. Audit who may have accessed files
sudo ausearch -f /path/to/config/production.conf 2>/dev/null

# Prevention strategy:
# - Set restrictive permissions by default (600 for config files)
# - Implement file permission monitoring
# - Add permission checks to deployment scripts
# - Regular security audits of file permissions
```

### Incident Response Procedures

#### Token Compromise Response
```bash
# Immediate containment procedure for token compromise
respond_to_token_compromise() {
    local compromised_token="$1"
    
    echo "SECURITY INCIDENT: Token compromise detected"
    echo "Token: ${compromised_token:0:10}..." # Only log first 10 chars
    
    # 1. Immediately revoke token
    gh auth refresh  # This revokes current token
    
    # 2. Stop all processes using the token
    pkill -f "analyze-performance"
    pkill -f "github-api"
    
    # 3. Clear token from environment and files
    unset GITHUB_TOKEN
    sed -i "s/$compromised_token/REVOKED_TOKEN/g" /var/log/cca-workflows/*.log
    
    # 4. Generate new token with limited scope
    gh auth login --scopes "repo,read:org"
    
    # 5. Update all services with new token
    systemctl restart cca-workflows
    
    # 6. Audit for potential data exposure
    audit_potential_data_exposure
    
    echo "Token compromise response completed"
}
```

#### Configuration Integrity Violation Response
```bash
# Response procedure for configuration tampering
respond_to_config_tampering() {
    local config_file="$1"
    
    echo "SECURITY INCIDENT: Configuration tampering detected"
    echo "File: $config_file"
    
    # 1. Immediately stop all services
    systemctl stop cca-workflows
    docker stop cca-workflows-container
    
    # 2. Preserve evidence
    cp "$config_file" "/var/log/security/$(basename "$config_file").$(date +%s).evidence"
    
    # 3. Restore from backup
    restore_config_from_backup "$config_file"
    
    # 4. Verify integrity of restored config
    if verify_config_integrity "$config_file"; then
        echo "Configuration restored successfully"
    else
        echo "CRITICAL: Cannot restore configuration integrity"
        exit 1
    fi
    
    # 5. Investigate tampering source
    check_file_access_logs "$config_file"
    check_system_integrity
    
    # 6. Restart services with restored configuration
    systemctl start cca-workflows
    
    echo "Configuration tampering response completed"
}
```

#### Security Monitoring and Alerting
```bash
# Continuous security monitoring implementation
monitor_security_events() {
    while true; do
        # Monitor for suspicious API activity
        if check_api_rate_anomalies; then
            alert_security_team "API_RATE_ANOMALY" "Unusual API usage patterns detected"
        fi
        
        # Monitor configuration file changes
        if check_config_file_changes; then
            alert_security_team "CONFIG_CHANGE" "Unauthorized configuration change detected"
        fi
        
        # Monitor for token exposure in logs
        if check_logs_for_secrets; then
            alert_security_team "SECRET_EXPOSURE" "Potential secret exposure in logs detected"
        fi
        
        # Monitor container security
        if check_container_security_violations; then
            alert_security_team "CONTAINER_SECURITY" "Container security violation detected"
        fi
        
        sleep 60  # Check every minute
    done
}

# Security alert function
alert_security_team() {
    local event_type="$1"
    local message="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Log security event
    echo "$timestamp [SECURITY_ALERT] $event_type: $message" >> /var/log/security/alerts.log
    
    # Send to SIEM if configured
    if [[ -n "$SIEM_ENDPOINT" ]]; then
        curl -s -X POST "$SIEM_ENDPOINT/alerts" \
            -H "Content-Type: application/json" \
            -d "{\"timestamp\":\"$timestamp\",\"type\":\"$event_type\",\"message\":\"$message\",\"severity\":\"HIGH\"}"
    fi
    
    # Email security team if configured
    if [[ -n "$SECURITY_EMAIL" ]]; then
        echo "$message" | mail -s "Security Alert: $event_type" "$SECURITY_EMAIL"
    fi
}
```

## 🔍 Security Checklist

> 📋 **SUMMARY: Complete Security Validation**
> 
> Use this comprehensive checklist before deploying to production environments. Each item must be verified to ensure security compliance.

### Pre-Deployment Security Checklist

> ⚠️ **MANDATORY:** All checklist items must be completed before production deployment. Missing security controls create critical vulnerabilities.

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

> 🚨 **EMERGENCY PROCEDURES:** In case of security incidents, follow these procedures immediately. Time is critical for minimizing exposure.

| Incident Type | Immediate Action | Recovery Steps |
|---|---|---|
| **Token Compromise** | Revoke token immediately | Generate new token, update services, audit exposure |
| **Config Tampering** | Stop services, preserve evidence | Restore from backup, verify integrity, investigate |
| **Container Breach** | Stop containers, isolate systems | Review security settings, rebuild with secure config |
| **SSL Issues** | Re-enable verification | Install proper certificates, test connectivity |

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

## 🛡️ Security Summary

> ✅ **SECURITY COMPLIANCE VERIFICATION**
> 
> Before going to production, ensure you have implemented all critical security measures outlined in this guide.

| Security Priority | Implementation Status | Validation Method |
|---|---|---|
| **Token Management** | □ Complete | Run `validate_github_token()` |
| **File Permissions** | □ Complete | Check with `find config/ -type f -perm /o+r` |
| **SSL Verification** | □ Complete | Verify `VERIFY_SSL_CERTIFICATES=true` |
| **Container Security** | □ Complete | Review Docker run parameters |
| **Access Control** | □ Complete | Audit user permissions and roles |
| **Monitoring** | □ Complete | Test security event logging |

---

This security configuration guide provides comprehensive protection for Claude Code Auto Workflows. Regular security reviews and updates to these practices are essential for maintaining a secure configuration management system.

**For additional configuration topics, see the related documentation:**
- **[CONFIGURATION.md](CONFIGURATION.md)** - Core configuration options and basic setup
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Systematic diagnosis and resolution of configuration issues
- **[ADVANCED.md](ADVANCED.md)** - Advanced configuration patterns and version compatibility