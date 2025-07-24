#!/bin/bash

# Cleanup Old Workflow Runs Script for Claude Code Auto Workflows
# This script helps manage and cleanup old workflow runs to optimize repository performance

set -euo pipefail

# Default settings
DEFAULT_KEEP_DAYS=30
DEFAULT_MAX_RUNS=100
DRY_RUN=false
FORCE=false

# Rate limiting configuration
RATE_LIMIT_REQUESTS_PER_MINUTE=30
RATE_LIMIT_DELAY=2  # seconds between operations
BURST_SIZE=5  # allow burst of operations before applying delay

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
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

log_header() {
    echo -e "${BLUE}[CLEANUP]${NC} $*"
}

show_progress() {
    local current=$1
    local total=$2
    local operation=$3
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\r${BLUE}[PROGRESS]${NC} %s: [" "$operation"
    printf "%*s" $filled | tr ' ' '█'
    printf "%*s" $empty | tr ' ' '░'
    printf "] %d/%d (%d%%)" "$current" "$total" "$percent"
    
    if [[ $current -eq $total ]]; then
        echo
    fi
}

# Rate limiting state
OPERATION_COUNT=0
LAST_RESET_TIME=$(date +%s)

apply_rate_limit() {
    ((OPERATION_COUNT++))
    
    local current_time
    current_time=$(date +%s)
    local time_elapsed=$((current_time - LAST_RESET_TIME))
    
    # Reset counter every minute
    if [[ $time_elapsed -ge 60 ]]; then
        OPERATION_COUNT=0
        LAST_RESET_TIME=$current_time
    fi
    
    # Apply rate limiting if we exceed burst size
    if [[ $OPERATION_COUNT -gt $BURST_SIZE ]]; then
        local operations_per_second=$((OPERATION_COUNT / (time_elapsed + 1)))
        local target_ops_per_second=$((RATE_LIMIT_REQUESTS_PER_MINUTE / 60))
        
        if [[ $operations_per_second -gt $target_ops_per_second ]]; then
            sleep $RATE_LIMIT_DELAY
        fi
    fi
}

check_api_rate_limit() {
    # Check GitHub API rate limit if possible
    if command -v gh &> /dev/null && gh auth status &> /dev/null; then
        local rate_limit_info
        if rate_limit_info=$(gh api rate_limit 2>/dev/null); then
            local remaining
            remaining=$(echo "$rate_limit_info" | jq -r '.rate.remaining' 2>/dev/null || echo "unknown")
            
            if [[ "$remaining" != "unknown" && "$remaining" -lt 100 ]]; then
                log_warn "⚠️  Low GitHub API rate limit remaining: $remaining requests"
                log_warn "   Applying additional rate limiting..."
                RATE_LIMIT_DELAY=$((RATE_LIMIT_DELAY * 2))
            fi
        fi
    fi
}

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Cleanup old GitHub Actions workflow runs to optimize repository performance.

OPTIONS:
    --days DAYS        Keep runs from last DAYS days (default: $DEFAULT_KEEP_DAYS)
    --max-runs RUNS    Keep maximum RUNS per workflow (default: $DEFAULT_MAX_RUNS)
    --dry-run          Show what would be deleted without making changes
    --force            Skip confirmation prompts
    --help, -h         Show this help message

EXAMPLES:
    $0 --dry-run                    # Preview what would be cleaned up
    $0 --days 7 --max-runs 50      # Keep only last 7 days, max 50 runs per workflow
    $0 --force                     # Cleanup without confirmation

EOF
}

parse_arguments() {
    local keep_days=$DEFAULT_KEEP_DAYS
    local max_runs=$DEFAULT_MAX_RUNS
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --days)
                if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then
                    keep_days=$2
                    shift 2
                else
                    log_error "Invalid or missing value for --days"
                    exit 1
                fi
                ;;
            --max-runs)
                if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then
                    max_runs=$2
                    shift 2
                else
                    log_error "Invalid or missing value for --max-runs"
                    exit 1
                fi
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    echo "$keep_days $max_runs"
}

check_prerequisites() {
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) is required for workflow cleanup"
        log_error "Install it from: https://cli.github.com/"
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        log_error "Not authenticated with GitHub CLI. Please run: gh auth login"
        exit 1
    fi
    
    if ! gh repo view &> /dev/null; then
        log_error "Cannot access repository. Please check your permissions."
        exit 1
    fi
}

analyze_workflow_runs() {
    local keep_days=$1
    local max_runs=$2
    
    log_header "Analyzing workflow runs..."
    
    # Get total run count
    local total_runs
    total_runs=$(gh run list --limit 1000 --json databaseId | jq length)
    
    log_info "📊 Repository Statistics:"
    log_info "   Total workflow runs: $total_runs"
    
    # Calculate cutoff date
    local cutoff_date
    cutoff_date=$(date -d "$keep_days days ago" '+%Y-%m-%d')
    
    log_info "   Keeping runs newer than: $cutoff_date"
    log_info "   Max runs per workflow: $max_runs"
    
    # Analyze runs by workflow
    log_info ""
    log_info "📋 Runs by workflow:"
    
    gh run list --limit 1000 --json name,status,createdAt | jq -r '
        group_by(.name) | 
        map({
            name: .[0].name,
            total: length,
            success: map(select(.status == "completed")) | length,
            failed: map(select(.status == "failed")) | length
        }) | 
        sort_by(.total) | 
        reverse |
        .[] | 
        "   \(.name): \(.total) runs (\(.success) success, \(.failed) failed)"
    '
}

identify_cleanup_candidates() {
    local keep_days=$1
    local max_runs=$2
    
    log_header "Identifying runs for cleanup..."
    
    # Find old runs
    local cutoff_date
    cutoff_date=$(date -d "$keep_days days ago" --iso-8601)
    
    local old_runs
    old_runs=$(gh run list --limit 1000 --json databaseId,name,createdAt,status,conclusion --jq "
        map(select(.createdAt < \"$cutoff_date\")) | 
        map(.databaseId) | 
        .[]
    " | wc -l)
    
    log_info "📅 Runs older than $keep_days days: $old_runs"
    
    # Find excess runs per workflow
    local excess_runs=0
    while IFS= read -r workflow_name; do
        local workflow_run_count
        workflow_run_count=$(gh run list --limit 1000 --workflow="$workflow_name" --json databaseId | jq length)
        
        if [[ $workflow_run_count -gt $max_runs ]]; then
            local excess=$((workflow_run_count - max_runs))
            excess_runs=$((excess_runs + excess))
            log_info "   $workflow_name: $excess excess runs (total: $workflow_run_count)"
        fi
    done < <(gh workflow list --json name --jq '.[].name')
    
    log_info "📊 Total excess runs: $excess_runs"
    
    local total_candidates=$((old_runs + excess_runs))
    log_info "🎯 Total cleanup candidates: $total_candidates runs"
    
    return $total_candidates
}

perform_cleanup() {
    local keep_days=$1
    local max_runs=$2
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_header "DRY RUN: Showing what would be cleaned up"
        return 0
    fi
    
    if [[ "$FORCE" != "true" ]]; then
        log_warn "⚠️  This will permanently delete workflow runs!"
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Cleanup cancelled by user"
            return 0
        fi
    fi
    
    log_header "Starting cleanup process..."
    
    # Check API rate limit before starting
    check_api_rate_limit
    
    local deleted_count=0
    local cutoff_date
    cutoff_date=$(date -d "$keep_days days ago" --iso-8601)
    
    # Clean up old runs
    log_info "🗑️  Deleting runs older than $keep_days days..."
    
    # First, get all old run IDs to show progress
    local old_run_ids
    mapfile -t old_run_ids < <(gh run list --limit 1000 --json databaseId,createdAt --jq "
        map(select(.createdAt < \"$cutoff_date\")) | 
        map(.databaseId) | 
        .[]
    ")
    
    local total_old_runs=${#old_run_ids[@]}
    local processed_old_runs=0
    
    if [[ $total_old_runs -gt 0 ]]; then
        for run_id in "${old_run_ids[@]}"; do
            if [[ -n "$run_id" ]]; then
                ((processed_old_runs++))
                show_progress "$processed_old_runs" "$total_old_runs" "Deleting old runs"
                
                if gh run delete "$run_id" --yes 2>/dev/null; then
                    ((deleted_count++))
                else
                    log_warn "   Failed to delete run ID: $run_id"
                fi
                
                # Apply rate limiting
                apply_rate_limit
            fi
        done
    else
        log_info "   No old runs to delete"
    fi
    
    # Clean up excess runs per workflow
    log_info "🗑️  Cleaning up excess runs per workflow..."
    
    # Get all workflow names for progress tracking
    local workflow_names
    mapfile -t workflow_names < <(gh workflow list --json name --jq '.[].name')
    local total_workflows=${#workflow_names[@]}
    local processed_workflows=0
    
    for workflow_name in "${workflow_names[@]}"; do
        ((processed_workflows++))
        show_progress "$processed_workflows" "$total_workflows" "Processing workflows"
        
        local runs_to_delete
        # Use compatible jq syntax that works across versions
        runs_to_delete=$(gh run list --limit 1000 --workflow="$workflow_name" --json databaseId | jq -r --arg max_runs "$max_runs" '
            if length > ($max_runs | tonumber) then 
                . as $all | 
                ($max_runs | tonumber) as $skip |
                [range($skip; length)] | map($all[.].databaseId) | .[]
            else 
                empty 
            end
        ')
        
        if [[ -n "$runs_to_delete" ]]; then
            log_info "   Cleaning up excess runs for: $workflow_name"
            
            # Convert to array for progress tracking
            local run_ids_array
            mapfile -t run_ids_array <<< "$runs_to_delete"
            local total_excess_runs=${#run_ids_array[@]}
            local processed_excess_runs=0
            
            for run_id in "${run_ids_array[@]}"; do
                if [[ -n "$run_id" ]]; then
                    ((processed_excess_runs++))
                    show_progress "$processed_excess_runs" "$total_excess_runs" "   Deleting excess runs"
                    
                    if gh run delete "$run_id" --yes 2>/dev/null; then
                        ((deleted_count++))
                    else
                        log_warn "     Failed to delete run ID: $run_id"
                    fi
                    
                    # Apply rate limiting
                    apply_rate_limit
                fi
            done
        fi
    done
    
    log_info "✅ Cleanup completed! Deleted $deleted_count workflow runs"
}

main() {
    log_info "🧹 Starting workflow runs cleanup for Claude Code Auto Workflows..."
    
    # Parse arguments
    local parsed_args
    parsed_args=$(parse_arguments "$@")
    local keep_days max_runs
    read -r keep_days max_runs <<< "$parsed_args"
    
    # Check prerequisites
    check_prerequisites
    
    echo
    analyze_workflow_runs "$keep_days" "$max_runs"
    
    echo
    local total_candidates
    if ! identify_cleanup_candidates "$keep_days" "$max_runs"; then
        total_candidates=$?
    else
        total_candidates=0
    fi
    
    if [[ $total_candidates -eq 0 ]]; then
        log_info "🎉 No cleanup needed! Repository is already optimized."
        return 0
    fi
    
    echo
    perform_cleanup "$keep_days" "$max_runs"
    
    echo
    log_info "🎉 Workflow cleanup process completed!"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "   Run without --dry-run to perform actual cleanup"
    else
        log_info "   Repository workflow runs have been optimized"
    fi
}

main "$@"