#!/bin/bash

# Create Labels Script for Claude Code Auto Workflows
# This script creates all required labels for the automated workflow system
# 
# Usage: ./create-labels.sh [--dry-run] [--force] [--quiet]
#   --dry-run: Show what would be created without making changes
#   --force: Force update existing labels with new colors/descriptions
#   --quiet: Suppress output except errors

set -euo pipefail

# Default options
DRY_RUN=false
FORCE_UPDATE=false
QUIET=false
EXIT_CODE=0

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE_UPDATE=true
            shift
            ;;
        --quiet)
            QUIET=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--dry-run] [--force] [--quiet]"
            echo "  --dry-run: Show what would be created without making changes"
            echo "  --force: Force update existing labels with new colors/descriptions"
            echo "  --quiet: Suppress output except errors"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Logging functions
log_info() {
    if [[ "$QUIET" != "true" ]]; then
        echo "$@"
    fi
}

log_error() {
    echo "$@" >&2
}

log_info "🏷️  Creating required labels for Claude Code Auto Workflows..."

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
    log_error "❌ GitHub CLI (gh) is not installed. Please install it first:"
    log_error "   https://cli.github.com/"
    exit 1
fi

# Check if user is authenticated
if ! gh auth status &> /dev/null; then
    log_error "❌ Not authenticated with GitHub CLI. Please run: gh auth login"
    exit 1
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir &> /dev/null; then
    log_error "❌ Not in a git repository. Please run this script from within a repository."
    exit 1
fi

# Verify we can access the repository
if ! gh repo view &> /dev/null; then
    log_error "❌ Cannot access repository. Please check your permissions."
    exit 1
fi

# Function to create or update label with comprehensive error handling
create_label() {
    local name="$1"
    local color="$2" 
    local description="$3"
    local action="Creating"
    
    # Validate inputs
    if [[ -z "$name" || -z "$color" || -z "$description" ]]; then
        log_error "❌ Invalid label parameters: name='$name', color='$color', description='$description'"
        EXIT_CODE=1
        return 1
    fi
    
    # Validate color format (hex without #)
    if [[ ! "$color" =~ ^[0-9A-Fa-f]{6}$ ]]; then
        log_error "❌ Invalid color format for '$name': '$color' (should be 6-character hex without #)"
        EXIT_CODE=1
        return 1
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "📋 Would create label: $name (color: #$color, description: $description)"
        return 0
    fi
    
    log_info "Creating label: $name"
    
    # Check if label already exists
    if gh label list --limit 1000 --json name --jq '.[].name' | grep -q "^$name$"; then
        if [[ "$FORCE_UPDATE" == "true" ]]; then
            action="Updating"
            log_info "🔄 Label exists, updating: $name"
            if gh label edit "$name" --color "$color" --description "$description" 2>/dev/null; then
                log_info "✅ Updated: $name"
                return 0
            else
                log_error "❌ Failed to update label: $name"
                EXIT_CODE=1
                return 1
            fi
        else
            log_info "⚠️  Label already exists (use --force to update): $name"
            return 0
        fi
    fi
    
    # Create new label
    if gh label create "$name" --color "$color" --description "$description" 2>/dev/null; then
        log_info "✅ Created: $name"
        return 0
    else
        local error_msg
        error_msg=$(gh label create "$name" --color "$color" --description "$description" 2>&1 || true)
        log_error "❌ Failed to create label '$name': $error_msg"
        EXIT_CODE=1
        return 1
    fi
}

# Label definitions (name, color, description)
declare -a ISSUE_PROCESSING_LABELS=(
    "processing|FFA500|Issue is being processed by Claude"
    "pr-ready|0052CC|Implementation complete, ready for PR creation"
    "pr-created|0E8A16|PR has been created for this issue"
    "resolved|6F42C1|Issue has been resolved and closed"
)

declare -a PR_REVIEW_LABELS=(
    "reviewed|D93F0B|PR has been reviewed and needs fixes"
    "review-fixed|0052CC|PR fixes completed, ready for merge"
)

declare -a CI_STATUS_LABELS=(
    "ci-failure|D93F0B|CI checks have failed"
    "ci-passed|0E8A16|CI checks have passed"
)

declare -a ADDITIONAL_LABELS=(
    "claude|7B68EE|Issues that should be processed by Claude Code"
    "enhancement|A2EEEF|New feature or request"
    "bug|D73A4A|Something isn't working"
    "documentation|0075CA|Improvements or additions to documentation"
    "good first issue|7057FF|Good for newcomers"
    "help wanted|008672|Extra attention is needed"
    "question|D876E3|Further information is requested"
    "wontfix|FFFFFF|This will not be worked on"
    "duplicate|CFD3D7|This issue or pull request already exists"
    "invalid|E4E669|This doesn't seem right"
    "dependencies|0366D6|Pull requests that update a dependency file"
)

# Function to process label array
process_labels() {
    local -n labels_ref=$1
    local category_name=$2
    local created=0
    local updated=0
    local failed=0
    
    log_info ""
    log_info "$category_name"
    
    for label_def in "${labels_ref[@]}"; do
        IFS='|' read -r name color description <<< "$label_def"
        if create_label "$name" "$color" "$description"; then
            if [[ "$DRY_RUN" != "true" ]]; then
                if gh label list --limit 1000 --json name --jq '.[].name' | grep -q "^$name$" && [[ "$FORCE_UPDATE" == "true" ]]; then
                    ((updated++))
                else
                    ((created++))
                fi
            fi
        else
            ((failed++))
        fi
    done
    
    if [[ "$DRY_RUN" != "true" ]]; then
        log_info "   📊 Summary: $created created, $updated updated, $failed failed"
    fi
}

# Process all label categories
process_labels ISSUE_PROCESSING_LABELS "📋 Creating issue processing labels..."
process_labels PR_REVIEW_LABELS "🔍 Creating PR review labels..."
process_labels CI_STATUS_LABELS "🔧 Creating CI/CD status labels..."
process_labels ADDITIONAL_LABELS "🏷️  Creating additional useful labels..."

log_info ""
if [[ "$DRY_RUN" == "true" ]]; then
    log_info "📋 Dry run completed! Use the script without --dry-run to create labels."
else
    log_info "✅ Label creation completed!"
    
    if [[ "$QUIET" != "true" ]]; then
        log_info ""
        log_info "📊 Current labels in repository:"
        if ! gh label list --limit 50; then
            log_error "⚠️ Could not retrieve label list"
        fi
    fi
    
    log_info ""
    if [[ $EXIT_CODE -eq 0 ]]; then
        log_info "🎉 All required labels have been processed successfully!"
        log_info "   The automated workflow system is now ready to use these labels."
    else
        log_error "⚠️  Some labels failed to process. Check the errors above."
        log_error "   You may want to run the script again or fix the issues manually."
    fi
fi

exit $EXIT_CODE