#!/bin/bash

# Workflow analysis module for Claude Code Auto Workflows
# This module provides workflow runtime and efficiency analysis

# Source dependencies
workflow_analyzer_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$workflow_analyzer_script_dir/common.sh"
source "$workflow_analyzer_script_dir/github-api.sh"

# Workflow analysis configuration
WORKFLOW_ANALYSIS_LIMIT=50
WORKFLOW_MIN_CACHE_PERCENTAGE=50

# Performance metrics for workflow analysis
WORKFLOWS_ANALYZED=0
PERFORMANCE_ISSUES_FOUND=0

# Initialize workflow analyzer
workflow_analyzer_init() {
    log_info "Workflow analyzer module initialized"
    github_api_init
}

# Analyze workflow runtime performance
analyze_workflow_runtime() {
    log_header "Analyzing workflow runtime performance..."
    
    # Get recent workflow runs with timing data
    local runs_data
    if ! runs_data=$(github_run_list "--limit $WORKFLOW_ANALYSIS_LIMIT --json name,status,conclusion,createdAt,updatedAt,databaseId"); then
        log_error "Failed to retrieve workflow run data"
        return 1
    fi
    
    if [[ "$runs_data" == "[]" || -z "$runs_data" ]]; then
        log_warn "No workflow run data available"
        return 0
    fi
    
    # Calculate performance metrics by workflow
    log_info "Recent workflow performance (last $WORKFLOW_ANALYSIS_LIMIT runs):"
    
    local workflow_stats
    workflow_stats=$(echo "$runs_data" | jq -r '
        group_by(.name) | 
        map({
            name: .[0].name,
            count: length,
            avg_duration: (
                map(
                    if .updatedAt and .createdAt then
                        (((.updatedAt | fromdateiso8601) - (.createdAt | fromdateiso8601)) / 60) | floor
                    else 0 end
                ) | add / length
            ),
            success_rate: (
                map(select(.conclusion == "success")) | length
            ) * 100 / length,
            failure_rate: (
                map(select(.conclusion == "failure")) | length
            ) * 100 / length
        }) | 
        sort_by(.avg_duration) | 
        reverse'
    )
    
    # Display results and identify performance issues
    echo "$workflow_stats" | jq -r '.[] | 
        "  📊 \(.name): \(.avg_duration)min avg, \(.success_rate | floor)% success rate (\(.count) runs)"'
    
    # Count workflows and performance issues
    local workflow_count
    workflow_count=$(echo "$workflow_stats" | jq '. | length')
    ((WORKFLOWS_ANALYZED += workflow_count))
    
    # Identify performance issues
    local slow_workflows
    slow_workflows=$(echo "$workflow_stats" | jq '[.[] | select(.avg_duration > 15)] | length')
    
    local unreliable_workflows  
    unreliable_workflows=$(echo "$workflow_stats" | jq '[.[] | select(.success_rate < 90)] | length')
    
    ((PERFORMANCE_ISSUES_FOUND += slow_workflows + unreliable_workflows))
    
    if [[ $slow_workflows -gt 0 ]]; then
        log_warn "⚠️  Found $slow_workflows workflow(s) with >15min average runtime"
    fi
    
    if [[ $unreliable_workflows -gt 0 ]]; then
        log_warn "⚠️  Found $unreliable_workflows workflow(s) with <90% success rate"
    fi
    
    return 0
}

# Analyze workflow efficiency and configuration
analyze_workflow_efficiency() {
    log_header "Analyzing workflow efficiency..."
    
    local workflow_dir=".github/workflows"
    if [[ ! -d "$workflow_dir" ]]; then
        log_warn "No workflow directory found"
        return 0
    fi
    
    # Count workflow files
    local workflow_files
    workflow_files=$(find "$workflow_dir" -name "*.yml" -o -name "*.yaml" 2>/dev/null)
    local workflow_count
    workflow_count=$(echo "$workflow_files" | wc -l)
    
    if [[ $workflow_count -eq 0 ]]; then
        log_warn "No workflow files found"
        return 0
    fi
    
    log_info "Workflow Configuration Analysis:"
    log_info "  📁 Total workflows: $workflow_count"
    
    # Analyze optimization patterns
    local caching_workflows=0
    local conditional_workflows=0
    local matrix_workflows=0
    local permission_workflows=0
    local outdated_actions=0
    
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        
        # Check for caching
        if grep -q "cache:" "$file" || grep -q "actions/cache" "$file"; then
            ((caching_workflows++))
        fi
        
        # Check for conditionals
        if grep -q "if:" "$file"; then
            ((conditional_workflows++))
        fi
        
        # Check for matrix builds
        if grep -q "strategy:" "$file" && grep -q "matrix:" "$file"; then
            ((matrix_workflows++))
        fi
        
        # Check for permissions
        if grep -q "permissions:" "$file"; then
            ((permission_workflows++))
        fi
        
        # Check for outdated actions (using @main or @master)
        if grep -q "@main\|@master" "$file"; then
            ((outdated_actions++))
        fi
        
    done <<< "$workflow_files"
    
    # Report findings
    log_info "  🚀 Using caching: $caching_workflows/$workflow_count workflows"
    log_info "  🎯 Using conditionals: $conditional_workflows/$workflow_count workflows"
    log_info "  ⚡ Using matrix builds: $matrix_workflows/$workflow_count workflows"
    log_info "  🔒 Using explicit permissions: $permission_workflows/$workflow_count workflows"
    
    # Identify optimization opportunities
    local issues_found=0
    
    if [[ $caching_workflows -lt $((workflow_count * WORKFLOW_MIN_CACHE_PERCENTAGE / 100)) ]]; then
        log_warn "⚠️  Consider adding caching to more workflows for better performance"
        ((issues_found++))
    fi
    
    if [[ $permission_workflows -lt $((workflow_count / 2)) ]]; then
        log_warn "⚠️  Consider adding explicit permissions to workflows for security"
        ((issues_found++))
    fi
    
    if [[ $outdated_actions -gt 0 ]]; then
        log_warn "⚠️  Found $outdated_actions workflow(s) using @main/@master - consider pinning to specific versions"
        ((issues_found++))
    fi
    
    ((PERFORMANCE_ISSUES_FOUND += issues_found))
    
    return 0
}

# Analyze workflow dependencies and complexity
analyze_workflow_complexity() {
    local workflow_dir=".github/workflows"
    if [[ ! -d "$workflow_dir" ]]; then
        return 0
    fi
    
    log_header "Analyzing workflow complexity..."
    
    local total_jobs=0
    local total_steps=0
    local complex_workflows=0
    
    while IFS= read -r -d '' file; do
        local jobs_count steps_count
        
        # Count jobs in workflow
        jobs_count=$(grep -c "^  [a-zA-Z].*:$" "$file" 2>/dev/null || echo 0)
        
        # Count steps in workflow
        steps_count=$(grep -c "- name:\|- uses:" "$file" 2>/dev/null || echo 0)
        
        ((total_jobs += jobs_count))
        ((total_steps += steps_count))
        
        # Flag complex workflows (>5 jobs or >20 steps)
        if [[ $jobs_count -gt 5 || $steps_count -gt 20 ]]; then
            ((complex_workflows++))
            local workflow_name
            workflow_name=$(basename "$file" .yml)
            workflow_name=$(basename "$workflow_name" .yaml)
            log_info "  🔍 Complex workflow detected: $workflow_name ($jobs_count jobs, $steps_count steps)"
        fi
        
    done < <(find "$workflow_dir" -name "*.yml" -o -name "*.yaml" -print0 2>/dev/null)
    
    local workflow_count
    workflow_count=$(find "$workflow_dir" -name "*.yml" -o -name "*.yaml" 2>/dev/null | wc -l)
    
    if [[ $workflow_count -gt 0 ]]; then
        local avg_jobs avg_steps
        avg_jobs=$((total_jobs / workflow_count))
        avg_steps=$((total_steps / workflow_count))
        
        log_info "Workflow Complexity Metrics:"
        log_info "  📊 Average jobs per workflow: $avg_jobs"
        log_info "  📋 Average steps per workflow: $avg_steps"
        log_info "  🔧 Complex workflows: $complex_workflows/$workflow_count"
        
        if [[ $complex_workflows -gt 0 ]]; then
            log_warn "💡 Consider breaking down complex workflows into smaller, focused workflows"
        fi
    fi
}

# Get workflow analyzer metrics
workflow_analyzer_get_metrics() {
    cat << EOF
{
  "workflows_analyzed": $WORKFLOWS_ANALYZED,
  "performance_issues_found": $PERFORMANCE_ISSUES_FOUND
}
EOF
}

# Reset workflow analyzer metrics
workflow_analyzer_reset_metrics() {
    WORKFLOWS_ANALYZED=0
    PERFORMANCE_ISSUES_FOUND=0
}

# Cleanup workflow analyzer
workflow_analyzer_cleanup() {
    github_api_cleanup
    log_info "Workflow analyzer cleanup completed"
}