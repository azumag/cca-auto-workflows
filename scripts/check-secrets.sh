#!/bin/bash

# Security Check Script for Claude Code Auto Workflows
# This script checks for potential security issues in the repository

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

check_hardcoded_secrets() {
    log_info "Checking for hardcoded secrets..."
    
    local patterns=(
        "password\s*[:=]\s*['\"][^'\"]{8,}['\"]"
        "api_key\s*[:=]\s*['\"][^'\"]{20,}['\"]"
        "secret\s*[:=]\s*['\"][^'\"]{16,}['\"]"
        "token\s*[:=]\s*['\"][^'\"]{20,}['\"]"
        "ghp_[a-zA-Z0-9]{36}"
        "github_pat_[a-zA-Z0-9_]{82}"
        "sk-[a-zA-Z0-9]{48}"
    )
    
    local found_issues=0
    
    for pattern in "${patterns[@]}"; do
        if grep -rE "$pattern" "$REPO_ROOT" --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=tests --exclude-dir=test --exclude='*.md' --exclude='*.txt' --exclude='*.log' 2>/dev/null; then
            log_error "Potential hardcoded secret found matching pattern: $pattern"
            ((found_issues++))
        fi
    done
    
    if [[ $found_issues -eq 0 ]]; then
        log_info "✅ No hardcoded secrets detected"
    else
        log_error "❌ Found $found_issues potential security issues"
        return 1
    fi
}

check_workflow_secrets() {
    log_info "Checking workflow files for proper secret usage..."
    
    local workflow_dir="$REPO_ROOT/.github/workflows"
    local issues=0
    
    if [[ -d "$workflow_dir" ]]; then
        while IFS= read -r -d '' file; do
            if grep -q '\${{.*secrets\.' "$file"; then
                # Check for secrets other than GITHUB_TOKEN
                if grep -E '\${{.*secrets\.[^}]+}}' "$file" | grep -v 'secrets\.GITHUB_TOKEN' >/dev/null 2>&1; then
                    log_warn "⚠️  $file uses custom secrets - ensure they are properly configured"
                else
                    log_info "✅ $file uses only GITHUB_TOKEN"
                fi
            fi
        done < <(find "$workflow_dir" -name "*.yml" -o -name "*.yaml" -print0)
    fi
    
    log_info "✅ Workflow secret usage check completed"
}

check_permissions() {
    log_info "Checking for overly permissive workflow permissions..."
    
    local workflow_dir="$REPO_ROOT/.github/workflows"
    local issues=0
    
    if [[ -d "$workflow_dir" ]]; then
        while IFS= read -r -d '' file; do
            if grep -q "permissions:" "$file"; then
                if grep -q "permissions: write-all" "$file"; then
                    log_warn "⚠️  $file uses 'write-all' permissions - consider using minimal permissions"
                    ((issues++))
                fi
            else
                log_warn "⚠️  $file doesn't specify permissions - consider adding explicit permissions"
                ((issues++))
            fi
        done < <(find "$workflow_dir" -name "*.yml" -o -name "*.yaml" -print0)
    fi
    
    if [[ $issues -eq 0 ]]; then
        log_info "✅ No permission issues found"
    else
        log_warn "Found $issues permission warnings"
    fi
}

main() {
    log_info "🔒 Starting security check for Claude Code Auto Workflows..."
    
    local exit_code=0
    
    check_hardcoded_secrets || exit_code=1
    check_workflow_secrets || exit_code=1
    check_permissions || exit_code=1
    
    if [[ $exit_code -eq 0 ]]; then
        log_info "🎉 Security check completed successfully!"
    else
        log_error "❌ Security check found issues that need attention"
    fi
    
    return $exit_code
}

main "$@"