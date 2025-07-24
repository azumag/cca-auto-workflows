#!/bin/bash

# Report generation module for Claude Code Auto Workflows
# This module provides comprehensive reporting and recommendations

# Source dependencies
report_generator_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$report_generator_script_dir/common.sh"
source "$report_generator_script_dir/github-api.sh"

# Report configuration
REPORT_OUTPUT_DIR="${TMPDIR:-/tmp}/performance-reports"
REPORT_TEMPLATE_VERSION="1.0.0"

# Initialize report generator
report_generator_init() {
    setup_cache "$REPORT_OUTPUT_DIR"
    log_info "Report generator initialized"
}

# Generate API usage analysis report
generate_api_usage_report() {
    log_header "Analyzing GitHub API usage..."
    
    local rate_limit_info
    if ! rate_limit_info=$(github_get_rate_limit); then
        log_error "Cannot access GitHub API rate limit information"
        return 1
    fi
    
    local core_used core_limit core_remaining reset_time
    core_used=$(echo "$rate_limit_info" | jq -r '.rate.used')
    core_limit=$(echo "$rate_limit_info" | jq -r '.rate.limit')
    core_remaining=$(echo "$rate_limit_info" | jq -r '.rate.remaining')
    reset_time=$(echo "$rate_limit_info" | jq -r '.rate.reset')
    
    local usage_percent
    usage_percent=$((core_used * 100 / core_limit))
    
    # Calculate time until reset
    local current_time reset_in_minutes
    current_time=$(date +%s)
    reset_in_minutes=$((((reset_time - current_time) + 59) / 60))  # Round up
    
    log_info "GitHub API Usage Analysis:"
    log_info "  📈 Core API: $core_used/$core_limit used ($usage_percent%)"
    log_info "  🔄 Remaining: $core_remaining requests"
    log_info "  ⏰ Reset in: ${reset_in_minutes} minutes"
    
    # Provide usage-based recommendations
    if [[ $usage_percent -gt 90 ]]; then
        log_error "🚨 Critical API usage detected ($usage_percent%)"
        _suggest_critical_api_optimizations
    elif [[ $usage_percent -gt 80 ]]; then
        log_warn "⚠️  High API usage detected ($usage_percent%)"
        _suggest_api_optimizations
    elif [[ $usage_percent -gt 60 ]]; then
        log_warn "⚠️  Moderate API usage ($usage_percent%)"
        _suggest_moderate_api_optimizations
    else
        log_info "✅ API usage is within healthy limits"
        _suggest_api_best_practices
    fi
    
    # Return structured data for further processing
    cat << EOF
{
  "api_usage": {
    "used": $core_used,
    "limit": $core_limit,
    "remaining": $core_remaining,
    "usage_percent": $usage_percent,
    "reset_time": $reset_time,
    "reset_in_minutes": $reset_in_minutes,
    "status": "$([ $usage_percent -gt 90 ] && echo "critical" || [ $usage_percent -gt 80 ] && echo "high" || [ $usage_percent -gt 60 ] && echo "moderate" || echo "healthy")"
  }
}
EOF
}

# Suggest API optimizations based on usage level
_suggest_api_optimizations() {
    log_info "💡 API Optimization Suggestions:"
    log_info "   • Implement aggressive caching for repeated API calls"
    log_info "   • Use GitHub App tokens for higher rate limits (5000 → 15000/hour)"
    log_info "   • Batch API operations where possible"
    log_info "   • Consider reducing workflow trigger frequency"
    log_info "   • Use conditional execution to avoid unnecessary API calls"
    log_info "   • Implement exponential backoff for retries"
}

_suggest_critical_api_optimizations() {
    log_error "🚨 CRITICAL API Optimization Actions:"
    log_error "   • IMMEDIATELY reduce API calls or script execution will fail"
    log_error "   • Enable caching for ALL API endpoints"
    log_error "   • Switch to GitHub App authentication for higher limits"
    log_error "   • Implement circuit breaker pattern to prevent rate limit exhaustion"
    log_error "   • Consider delaying non-critical operations until reset"
}

_suggest_moderate_api_optimizations() {
    log_info "💡 Moderate API Usage Suggestions:"
    log_info "   • Monitor API usage trends"
    log_info "   • Implement caching for frequently accessed endpoints" 
    log_info "   • Use conditional requests with ETags where possible"
    log_info "   • Consider GitHub App authentication for future growth"
}

_suggest_api_best_practices() {
    log_info "💡 API Best Practices:"
    log_info "   • Continue monitoring API usage trends"
    log_info "   • Implement proactive caching strategies"
    log_info "   • Use webhooks instead of polling where possible"
    log_info "   • Plan for scaling with GitHub App authentication"
}

# Generate workflow optimization recommendations
generate_workflow_optimization_report() {
    log_header "Generating workflow optimization recommendations..."
    
    local workflow_issues=0
    local recommendations=()
    
    # Check if workflows directory exists
    if [[ ! -d ".github/workflows" ]]; then
        log_warn "No .github/workflows directory found"
        return 0
    fi
    
    local workflow_count
    workflow_count=$(find ".github/workflows" -name "*.yml" -o -name "*.yaml" 2>/dev/null | wc -l)
    
    if [[ $workflow_count -eq 0 ]]; then
        log_warn "No workflow files found"
        return 0
    fi
    
    log_info "💡 Workflow Optimization Recommendations:"
    
    # Check for common optimization opportunities
    local workflows_without_cache=0
    local workflows_without_permissions=0
    local workflows_with_outdated_actions=0
    
    while IFS= read -r -d '' file; do
        local workflow_name
        workflow_name=$(basename "$file" .yml)
        workflow_name=$(basename "$workflow_name" .yaml)
        
        # Check for caching
        if ! grep -q "cache:" "$file" && ! grep -q "actions/cache" "$file"; then
            ((workflows_without_cache++))
        fi
        
        # Check for explicit permissions
        if ! grep -q "permissions:" "$file"; then
            ((workflows_without_permissions++))
        fi
        
        # Check for outdated action references
        if grep -q "@main\|@master" "$file"; then
            ((workflows_with_outdated_actions++))
        fi
        
    done < <(find ".github/workflows" -name "*.yml" -o -name "*.yaml" -print0 2>/dev/null)
    
    # Generate specific recommendations
    if [[ $workflows_without_cache -gt 0 ]]; then
        log_info "   1. 🚀 Enable dependency caching in $workflows_without_cache workflow(s)"
        log_info "      • Use actions/cache@v3 for node_modules, pip cache, etc."
        log_info "      • Cache build artifacts and dependencies"
        ((workflow_issues++))
    fi
    
    if [[ $workflows_without_permissions -gt 0 ]]; then
        log_info "   2. 🔒 Add explicit permissions to $workflows_without_permissions workflow(s)"
        log_info "      • Follow principle of least privilege"
        log_info "      • Specify only required permissions (contents: read, etc.)"
        ((workflow_issues++))
    fi
    
    if [[ $workflows_with_outdated_actions -gt 0 ]]; then
        log_info "   3. 📌 Pin action versions in $workflows_with_outdated_actions workflow(s)"
        log_info "      • Replace @main/@master with specific version tags"
        log_info "      • Use @v3, @v4 instead of floating references"
        ((workflow_issues++))
    fi
    
    # Additional generic recommendations
    log_info "   4. 🎯 Use conditional job execution to skip unnecessary work"
    log_info "   5. ⚡ Implement matrix strategies for parallel execution"
    log_info "   6. 📦 Use smaller, specific Docker images for faster starts"
    log_info "   7. 🔄 Consider workflow_dispatch for manual triggers"
    log_info "   8. 📊 Monitor and clean up old workflow runs regularly"
    log_info "   9. 🏷️  Use labels efficiently to control workflow triggers"
    log_info "   10. 🚦 Implement proper error handling and retry logic"
    
    return 0
}

# Generate comprehensive performance report
generate_comprehensive_report() {
    local output_file="${1:-${REPORT_OUTPUT_DIR}/performance-report-$(date +%Y%m%d-%H%M%S).md}"
    
    log_info "📝 Generating comprehensive performance report..."
    
    # Create report header
    cat > "$output_file" << EOF
# GitHub Actions Performance Analysis Report

**Generated:** $(date -Iseconds)  
**Template Version:** $REPORT_TEMPLATE_VERSION  
**Repository:** \${GITHUB_REPOSITORY:-$(git remote get-url origin 2>/dev/null | sed 's/.*github.com[:/]\([^/]*\/[^/]*\).*/\1/' || echo "N/A")}

## Executive Summary

This report provides a comprehensive analysis of GitHub Actions workflow performance, API usage patterns, and optimization opportunities.

## 📊 API Usage Analysis

EOF
    
    # Add API usage section
    local api_data
    if api_data=$(generate_api_usage_report 2>/dev/null); then
        local usage_percent status
        usage_percent=$(echo "$api_data" | jq -r '.api_usage.usage_percent')
        status=$(echo "$api_data" | jq -r '.api_usage.status')
        
        cat >> "$output_file" << EOF
- **Current Usage:** $usage_percent% of rate limit
- **Status:** $status
- **Remaining Requests:** $(echo "$api_data" | jq -r '.api_usage.remaining')
- **Reset Time:** $(echo "$api_data" | jq -r '.api_usage.reset_in_minutes') minutes

EOF
    else
        echo "- **Status:** Unable to retrieve API usage data" >> "$output_file"
        echo "" >> "$output_file"
    fi
    
    # Add workflow analysis section
    cat >> "$output_file" << EOF
## 🔧 Workflow Analysis

EOF
    
    # Count workflows and provide summary
    local workflow_count=0
    if [[ -d ".github/workflows" ]]; then
        workflow_count=$(find ".github/workflows" -name "*.yml" -o -name "*.yaml" 2>/dev/null | wc -l)
    fi
    
    cat >> "$output_file" << EOF
- **Total Workflows:** $workflow_count
- **Analysis Date:** $(date -Iseconds)

## 📈 Performance Metrics

EOF
    
    # Add performance metrics if available
    if command -v generate_performance_report &>/dev/null; then
        echo '```' >> "$output_file"
        generate_performance_report 2>&1 | sed 's/\x1b\[[0-9;]*m//g' >> "$output_file"
        echo '```' >> "$output_file"
        echo "" >> "$output_file"
    fi
    
    # Add recommendations section
    cat >> "$output_file" << EOF
## 💡 Optimization Recommendations

### High Priority
1. **Enable Dependency Caching** - Add caching to workflows that install packages
2. **Implement Explicit Permissions** - Follow principle of least privilege
3. **Pin Action Versions** - Use specific version tags instead of @main/@master

### Medium Priority
4. **Use Conditional Execution** - Skip unnecessary jobs with \`if:\` conditions
5. **Implement Matrix Strategies** - Run tests in parallel across different environments
6. **Monitor API Usage** - Set up alerts for high API usage

### Low Priority
7. **Clean Up Old Runs** - Regularly remove old workflow runs
8. **Optimize Docker Images** - Use smaller, more specific base images
9. **Review Trigger Conditions** - Ensure workflows only run when necessary

## 🔗 Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Workflow Optimization Guide](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [API Rate Limiting](https://docs.github.com/en/rest/overview/resources-in-the-rest-api#rate-limiting)

---
*Report generated by Claude Code Auto Workflows Performance Analyzer*
EOF
    
    log_info "📄 Comprehensive report saved to: $output_file"
    echo "$output_file"
}

# Generate JSON summary report
generate_json_report() {
    local output_file="${1:-${REPORT_OUTPUT_DIR}/performance-summary-$(date +%Y%m%d-%H%M%S).json}"
    
    log_info "📊 Generating JSON performance summary..."
    
    # Collect all metrics
    local api_data workflow_count
    api_data=$(generate_api_usage_report 2>/dev/null || echo '{"api_usage":{"status":"unavailable"}}')
    
    if [[ -d ".github/workflows" ]]; then
        workflow_count=$(find ".github/workflows" -name "*.yml" -o -name "*.yaml" 2>/dev/null | wc -l)
    else
        workflow_count=0
    fi
    
    # Create JSON report
    cat > "$output_file" << EOF
{
  "report": {
    "generated_at": "$(date -Iseconds)",
    "template_version": "$REPORT_TEMPLATE_VERSION",
    "repository": "\${GITHUB_REPOSITORY:-N/A}"
  },
  "workflows": {
    "total_count": $workflow_count
  },
  "api_usage": $(echo "$api_data" | jq '.api_usage // {}'),
  "recommendations": {
    "high_priority": [
      "Enable dependency caching",
      "Implement explicit permissions",
      "Pin action versions"
    ],
    "medium_priority": [
      "Use conditional execution",
      "Implement matrix strategies",
      "Monitor API usage"
    ],
    "low_priority": [
      "Clean up old runs",
      "Optimize Docker images",
      "Review trigger conditions"
    ]
  }
}
EOF
    
    log_info "📊 JSON report saved to: $output_file"
    echo "$output_file"
}

# Clean up report generator
report_generator_cleanup() {
    # Clean up old reports (keep last 10)
    if [[ -d "$REPORT_OUTPUT_DIR" ]]; then
        find "$REPORT_OUTPUT_DIR" -name "*.md" -o -name "*.json" | sort | head -n -10 | xargs rm -f 2>/dev/null || true
    fi
    
    log_info "Report generator cleanup completed"
}