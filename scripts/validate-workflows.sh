#!/bin/bash

# Workflow Validation Script for Claude Code Auto Workflows
# This script validates GitHub Actions workflows for syntax, security, and best practices

set -euo pipefail

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
    ((WARNINGS++))
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
    ((ERRORS++))
}

log_header() {
    echo -e "${BLUE}[VALIDATION]${NC} $*"
}

check_yaml_syntax() {
    log_header "Checking YAML syntax..."
    
    local workflow_dir=".github/workflows"
    if [[ ! -d "$workflow_dir" ]]; then
        log_error "Workflow directory not found: $workflow_dir"
        return 1
    fi
    
    local syntax_errors=0
    
    while IFS= read -r -d '' file; do
        log_info "Validating: $(basename "$file")"
        
        # Check YAML syntax with yq if available
        if command -v yq &> /dev/null; then
            if ! yq eval '.' "$file" > /dev/null 2>&1; then
                log_error "YAML syntax error in: $file"
                ((syntax_errors++))
            fi
        else
            # Fallback to basic YAML validation with python
            if command -v python3 &> /dev/null; then
                if ! python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
                    log_error "YAML syntax error in: $file"
                    ((syntax_errors++))
                fi
            else
                log_warn "No YAML validator available (install yq or python3)"
            fi
        fi
    done < <(find "$workflow_dir" -name "*.yml" -o -name "*.yaml" -print0)
    
    if [[ $syntax_errors -eq 0 ]]; then
        log_info "✅ All workflow files have valid YAML syntax"
    else
        log_error "❌ Found $syntax_errors YAML syntax errors"
    fi
}

check_required_fields() {
    log_header "Checking required workflow fields..."
    
    local workflow_dir=".github/workflows"
    
    while IFS= read -r -d '' file; do
        local filename
        filename=$(basename "$file")
        
        # Check for required top-level fields
        if ! grep -q "^name:" "$file"; then
            log_warn "Missing 'name' field in: $filename"
        fi
        
        if ! grep -q "^on:" "$file"; then
            log_error "Missing 'on' field in: $filename"
        fi
        
        if ! grep -q "^jobs:" "$file"; then
            log_error "Missing 'jobs' field in: $filename"
        fi
        
    done < <(find "$workflow_dir" -name "*.yml" -o -name "*.yaml" -print0)
}

check_security_best_practices() {
    log_header "Checking security best practices..."
    
    local workflow_dir=".github/workflows"
    
    while IFS= read -r -d '' file; do
        local filename
        filename=$(basename "$file")
        
        # Check for pinned action versions
        if grep -q "@main\|@master\|@latest" "$file"; then
            log_warn "Using unpinned action versions in: $filename (consider using specific versions)"
        fi
        
        # Check for proper permissions
        if ! grep -q "permissions:" "$file"; then
            log_warn "No explicit permissions defined in: $filename"
        fi
        
        # Check for hardcoded secrets (basic check)
        if grep -qE "(password|secret|token|key).*=.*['\"][^'\"]{8,}['\"]" "$file"; then
            log_error "Potential hardcoded secret in: $filename"
        fi
        
        # Check for proper secret usage
        if grep -q '\${{.*secrets\.' "$file"; then
            if ! grep -q 'secrets\.' "$file" | head -1 | grep -q 'secrets\.GITHUB_TOKEN\|secrets\.'; then
                log_info "✅ Proper secret usage in: $filename"
            fi
        fi
        
    done < <(find "$workflow_dir" -name "*.yml" -o -name "*.yaml" -print0)
}

check_performance_optimizations() {
    log_header "Checking performance optimizations..."
    
    local workflow_dir=".github/workflows"
    
    while IFS= read -r -d '' file; do
        local filename
        filename=$(basename "$file")
        
        # Check for caching
        if grep -q "node_modules\|npm install\|yarn install" "$file"; then
            if ! grep -q "actions/cache\|cache:" "$file"; then
                log_warn "Consider adding dependency caching in: $filename"
            fi
        fi
        
        # Check for conditional execution
        if ! grep -q "if:" "$file"; then
            log_warn "Consider adding conditional execution in: $filename"
        fi
        
        # Check for parallel execution opportunities
        if grep -q "runs-on:" "$file"; then
            local job_count
            job_count=$(grep -c "runs-on:" "$file")
            if [[ $job_count -gt 1 ]]; then
                if ! grep -q "needs:" "$file"; then
                    log_info "✅ Multiple jobs detected in: $filename (check if they can run in parallel)"
                fi
            fi
        fi
        
    done < <(find "$workflow_dir" -name "*.yml" -o -name "*.yaml" -print0)
}

check_workflow_naming() {
    log_header "Checking workflow naming conventions..."
    
    local workflow_dir=".github/workflows"
    
    while IFS= read -r -d '' file; do
        local filename
        filename=$(basename "$file" .yml)
        filename=$(basename "$filename" .yaml)
        
        # Check for descriptive names
        if [[ ${#filename} -lt 3 ]]; then
            log_warn "Very short filename: $(basename "$file") (consider more descriptive names)"
        fi
        
        # Check for consistent naming (kebab-case)
        if [[ ! "$filename" =~ ^[a-z0-9-]+$ ]]; then
            log_warn "Non-standard filename format: $(basename "$file") (consider kebab-case)"
        fi
        
    done < <(find "$workflow_dir" -name "*.yml" -o -name "*.yaml" -print0)
}

check_dependencies() {
    log_header "Checking workflow dependencies..."
    
    local workflow_dir=".github/workflows"
    local used_actions=()
    
    # Extract all used actions
    while IFS= read -r -d '' file; do
        while IFS= read -r line; do
            if [[ "$line" =~ uses:.*([a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+@.*) ]]; then
                used_actions+=("${BASH_REMATCH[1]}")
            fi
        done < "$file"
    done < <(find "$workflow_dir" -name "*.yml" -o -name "*.yaml" -print0)
    
    # Check for common actions and suggest alternatives
    local unique_actions
    mapfile -t unique_actions < <(printf '%s\n' "${used_actions[@]}" | sort -u)
    
    log_info "📦 Actions used in workflows:"
    for action in "${unique_actions[@]}"; do
        log_info "   • $action"
        
        # Suggest improvements for common actions
        case "$action" in
            *"@main"|*"@master"|*"@latest")
                log_warn "     Consider pinning to a specific version for $action"
                ;;
        esac
    done
}

generate_summary() {
    log_header "Validation Summary"
    
    log_info "📊 Validation Results:"
    log_info "   Errors: $ERRORS"
    log_info "   Warnings: $WARNINGS"
    
    if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
        log_info "🎉 All workflows passed validation!"
    elif [[ $ERRORS -eq 0 ]]; then
        log_warn "⚠️  Workflows have warnings but no critical errors"
    else
        log_error "❌ Workflows have critical errors that need to be fixed"
    fi
    
    echo
    log_info "💡 General Recommendations:"
    log_info "   • Pin action versions to specific commits or tags"
    log_info "   • Use minimal permissions for security"
    log_info "   • Add caching for dependencies"
    log_info "   • Use conditional execution to skip unnecessary steps"
    log_info "   • Keep workflow files well-documented"
    log_info "   • Regularly update action versions"
}

main() {
    log_info "🔍 Starting workflow validation for Claude Code Auto Workflows..."
    echo
    
    check_yaml_syntax
    echo
    
    check_required_fields
    echo
    
    check_security_best_practices
    echo
    
    check_performance_optimizations
    echo
    
    check_workflow_naming
    echo
    
    check_dependencies
    echo
    
    generate_summary
    
    # Return appropriate exit code
    if [[ $ERRORS -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

main "$@"