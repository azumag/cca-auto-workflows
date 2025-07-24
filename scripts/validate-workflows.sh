#!/bin/bash

# Workflow Validation Script for Claude Code Auto Workflows
# This script validates GitHub Actions workflows for syntax, security, and best practices

set -euo pipefail

# Source common library
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib/common.sh"

ERRORS=0
WARNINGS=0

# Performance configuration
MAX_PARALLEL_JOBS=4  # Number of parallel validation jobs
CACHE_DIR="${TMPDIR:-/tmp}/validate-workflows-cache"
CACHE_TTL=1800  # 30 minutes cache TTL

# Override log functions to track errors/warnings
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

get_validation_cache_key() {
    local file="$1"
    local file_hash
    file_hash=$(sha256sum "$file" 2>/dev/null | cut -d' ' -f1)
    echo "${file_hash}_$(stat -c %Y "$file" 2>/dev/null || echo 0)"
}

get_validation_from_cache() {
    local file="$1"
    local cache_key
    cache_key=$(get_validation_cache_key "$file")
    local cache_file="$CACHE_DIR/$cache_key"
    
    if is_cache_valid "$cache_file" "$CACHE_TTL"; then
        cat "$cache_file"
        return 0
    fi
    return 1
}

save_validation_to_cache() {
    local file="$1"
    local result="$2"
    local cache_key
    cache_key=$(get_validation_cache_key "$file")
    
    # Use atomic save to prevent race conditions
    save_to_cache "$cache_key" "$result" "$CACHE_DIR"
}

validate_single_file() {
    local file="$1"
    local filename
    filename=$(basename "$file")
    
    # Check cache first
    local cached_result
    if cached_result=$(get_validation_from_cache "$file"); then
        echo "$cached_result"
        return 0
    fi
    
    # Perform validation
    local validation_output=""
    local file_errors=0
    local file_warnings=0
    
    # YAML syntax validation
    validation_output+="Validating: $filename\n"
    
    if command -v yq &> /dev/null; then
        local yq_output
        if ! yq_output=$(yq eval '.' "$file" 2>&1); then
            validation_output+="ERROR: YAML syntax error in: $file\n"
            validation_output+="ERROR: Error details: $yq_output\n"
            ((file_errors++))
        else
            # GitHub Actions schema validation
            if ! yq eval '.name' "$file" >/dev/null 2>&1; then
                validation_output+="WARN: Missing 'name' field in: $filename\n"
                ((file_warnings++))
            fi
            
            if ! yq eval '.on' "$file" >/dev/null 2>&1; then
                validation_output+="ERROR: Missing 'on' field in: $filename\n"
                ((file_errors++))
            fi
            
            if ! yq eval '.jobs' "$file" >/dev/null 2>&1; then
                validation_output+="ERROR: Missing 'jobs' field in: $filename\n"
                ((file_errors++))
            fi
        fi
    else
        # Fallback validation
        if command -v python3 &> /dev/null; then
            local python_output
            if ! python_output=$(python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>&1); then
                validation_output+="ERROR: YAML syntax error in: $file\n"
                validation_output+="ERROR: Error details: $python_output\n"
                ((file_errors++))
            fi
        fi
        
        # Basic structure checks
        if ! grep -q "^name:" "$file"; then
            validation_output+="WARN: Missing 'name' field in: $filename\n"
            ((file_warnings++))
        fi
        
        if ! grep -q "^on:" "$file"; then
            validation_output+="ERROR: Missing 'on' field in: $filename\n"
            ((file_errors++))
        fi
        
        if ! grep -q "^jobs:" "$file"; then
            validation_output+="ERROR: Missing 'jobs' field in: $filename\n"
            ((file_errors++))
        fi
    fi
    
    # Security checks
    if grep -q "@main\|@master\|@latest" "$file"; then
        validation_output+="WARN: Using unpinned action versions in: $filename (consider using specific versions)\n"
        ((file_warnings++))
    fi
    
    if ! grep -q "permissions:" "$file"; then
        validation_output+="WARN: No explicit permissions defined in: $filename\n"
        ((file_warnings++))
    fi
    
    # Performance checks
    if grep -q "node_modules\|npm install\|yarn install" "$file"; then
        if ! grep -q "actions/cache\|cache:" "$file"; then
            validation_output+="WARN: Consider adding dependency caching in: $filename\n"
            ((file_warnings++))
        fi
    fi
    
    # Prepare result
    local result="$validation_output|$file_errors|$file_warnings"
    
    # Cache the result
    save_validation_to_cache "$file" "$result"
    
    echo "$result"
}

validate_github_actions_schema() {
    local file="$1"
    local errors=0
    
    # Check for required GitHub Actions fields
    if ! yq eval '.name' "$file" >/dev/null 2>&1; then
        log_warn "Missing 'name' field in: $(basename "$file")"
        ((errors++))
    fi
    
    if ! yq eval '.on' "$file" >/dev/null 2>&1; then
        log_error "Missing 'on' field in: $(basename "$file")"
        ((errors++))
    fi
    
    if ! yq eval '.jobs' "$file" >/dev/null 2>&1; then
        log_error "Missing 'jobs' field in: $(basename "$file")"
        ((errors++))
    fi
    
    # Check job structure
    local job_errors
    job_errors=$(yq eval '.jobs | keys | .[]' "$file" 2>/dev/null | while read -r job_id; do
        if ! yq eval ".jobs.$job_id.runs-on" "$file" >/dev/null 2>&1; then
            echo "Missing 'runs-on' in job '$job_id' in $(basename "$file")"
        fi
        if ! yq eval ".jobs.$job_id.steps" "$file" >/dev/null 2>&1; then
            echo "Missing 'steps' in job '$job_id' in $(basename "$file")"
        fi
    done)
    
    if [[ -n "$job_errors" ]]; then
        while IFS= read -r error; do
            log_error "$error"
            ((errors++))
        done <<< "$job_errors"
    fi
    
    return $errors
}

validate_github_actions_basic() {
    local file="$1" 
    local errors=0
    
    # Basic structure checks using grep
    if ! grep -q "^name:" "$file"; then
        log_warn "Missing 'name' field in: $(basename "$file")"
        ((errors++))
    fi
    
    if ! grep -q "^on:" "$file"; then
        log_error "Missing 'on' field in: $(basename "$file")"
        ((errors++))
    fi
    
    if ! grep -q "^jobs:" "$file"; then
        log_error "Missing 'jobs' field in: $(basename "$file")"
        ((errors++))
    fi
    
    return $errors
}

parallel_validate_workflows() {
    log_header "Validating workflows in parallel..."
    
    local workflow_dir=".github/workflows"
    if [[ ! -d "$workflow_dir" ]]; then
        log_error "Workflow directory not found: $workflow_dir"
        return 1
    fi
    
    # Get all workflow files
    local workflow_files=()
    while IFS= read -r -d '' file; do
        workflow_files+=("$file")
    done < <(find "$workflow_dir" -name "*.yml" -o -name "*.yaml" -print0)
    
    local total_files=${#workflow_files[@]}
    if [[ $total_files -eq 0 ]]; then
        log_warn "No workflow files found"
        return 0
    fi
    
    log_info "Processing $total_files workflow files with up to $MAX_PARALLEL_JOBS parallel jobs..."
    
    # Process files in parallel batches
    local batch_size=$MAX_PARALLEL_JOBS
    local file_index=0
    
    while [[ $file_index -lt $total_files ]]; do
        local pids=()
        local temp_files=()
        
        # Start a batch of parallel validations
        for ((i=0; i<batch_size && file_index<total_files; i++)); do
            local file="${workflow_files[$file_index]}"
            local temp_file
            temp_file=$(mktemp)
            temp_files+=("$temp_file")
            
            # Run validation in background with secure temp file
            chmod 600 "$temp_file"
            validate_single_file "$file" > "$temp_file" 2>&1 &
            pids+=($!)
            
            ((file_index++))
        done
        
        # Wait for all jobs in this batch to complete with error handling
        local failed_jobs=0
        for ((i=0; i<${#pids[@]}; i++)); do
            if ! wait "${pids[$i]}"; then
                log_error "Validation job failed for PID ${pids[$i]}"
                ((failed_jobs++))
            fi
            
            # Process results
            local result
            result=$(cat "${temp_files[$i]}")
            local output errors warnings
            IFS='|' read -r output errors warnings <<< "$result"
            
            # Print output and update counters
            echo -e "$output"
            ERRORS=$((ERRORS + errors))
            WARNINGS=$((WARNINGS + warnings))
            
            # Clean up temp file securely
            rm -f "${temp_files[$i]}"
        done
        
        if [[ $failed_jobs -gt 0 ]]; then
            log_warn "$failed_jobs validation jobs failed in this batch"
        fi
        
        # Show progress
        local processed=$((file_index > total_files ? total_files : file_index))
        log_info "Progress: $processed/$total_files files processed"
    done
    
    if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
        log_info "✅ All workflow files passed validation"
    else
        log_info "📊 Validation completed with $ERRORS errors and $WARNINGS warnings"
    fi
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
            local yq_output
            if ! yq_output=$(yq eval '.' "$file" 2>&1); then
                log_error "YAML syntax error in: $file"
                log_error "Error details: $yq_output"
                ((syntax_errors++))
            else
                # Additional GitHub Actions schema validation
                validate_github_actions_schema "$file" || ((syntax_errors++))
            fi
        else
            # Fallback to basic YAML validation with python
            if command -v python3 &> /dev/null; then
                local python_output
                if ! python_output=$(python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>&1); then
                    log_error "YAML syntax error in: $file"
                    log_error "Error details: $python_output" 
                    ((syntax_errors++))
                else
                    # Basic GitHub Actions structure validation
                    validate_github_actions_basic "$file" || ((syntax_errors++))
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
    
    # Initialize cache and cleanup old entries
    setup_cache "$CACHE_DIR"
    cleanup_cache "$CACHE_DIR" "$CACHE_TTL"
    
    # Show cache stats
    show_cache_stats "$CACHE_DIR" "validation results"
    
    echo
    
    # Use parallel validation instead of sequential
    parallel_validate_workflows
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