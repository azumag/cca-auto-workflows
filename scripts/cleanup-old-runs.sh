#!/bin/bash

# Cleanup Old Workflow Runs Script for Claude Code Auto Workflows
# This script helps manage and cleanup old workflow runs to optimize repository performance

set -euo pipefail

# Default settings
DEFAULT_KEEP_DAYS=30
DEFAULT_MAX_RUNS=100
DRY_RUN=false
FORCE=false

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
    
    local deleted_count=0
    local cutoff_date
    cutoff_date=$(date -d "$keep_days days ago" --iso-8601)
    
    # Clean up old runs
    log_info "🗑️  Deleting runs older than $keep_days days..."
    while IFS= read -r run_id; do
        if [[ -n "$run_id" ]]; then
            if gh run delete "$run_id" --yes 2>/dev/null; then
                ((deleted_count++))
                log_info "   Deleted run ID: $run_id"
            else
                log_warn "   Failed to delete run ID: $run_id"
            fi
        fi
    done < <(gh run list --limit 1000 --json databaseId,createdAt --jq "
        map(select(.createdAt < \"$cutoff_date\")) | 
        map(.databaseId) | 
        .[]
    ")
    
    # Clean up excess runs per workflow
    log_info "🗑️  Cleaning up excess runs per workflow..."
    while IFS= read -r workflow_name; do
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
            while IFS= read -r run_id; do
                if [[ -n "$run_id" ]]; then
                    if gh run delete "$run_id" --yes 2>/dev/null; then
                        ((deleted_count++))
                        log_info "     Deleted run ID: $run_id"
                    else
                        log_warn "     Failed to delete run ID: $run_id"
                    fi
                fi
            done <<< "$runs_to_delete"
        fi
    done < <(gh workflow list --json name --jq '.[].name')
    
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