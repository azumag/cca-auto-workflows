#!/bin/bash

# Create Labels Script for Claude Code Auto Workflows
# This script creates all required labels for the automated workflow system

set -e

echo "🏷️  Creating required labels for Claude Code Auto Workflows..."

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed. Please install it first:"
    echo "   https://cli.github.com/"
    exit 1
fi

# Check if user is authenticated
if ! gh auth status &> /dev/null; then
    echo "❌ Not authenticated with GitHub CLI. Please run: gh auth login"
    exit 1
fi

# Function to create label with error handling
create_label() {
    local name="$1"
    local color="$2" 
    local description="$3"
    
    echo "Creating label: $name"
    if gh label create "$name" --color "$color" --description "$description" 2>/dev/null; then
        echo "✅ Created: $name"
    else
        echo "⚠️  Label already exists or failed to create: $name"
    fi
}

echo ""
echo "📋 Creating issue processing labels..."

# Issue Processing Labels
create_label "processing" "FFA500" "Issue is being processed by Claude"
create_label "pr-ready" "0052CC" "Implementation complete, ready for PR creation"
create_label "pr-created" "0E8A16" "PR has been created for this issue"
create_label "resolved" "6F42C1" "Issue has been resolved and closed"

echo ""
echo "🔍 Creating PR review labels..."

# PR Review Labels
create_label "reviewed" "D93F0B" "PR has been reviewed and needs fixes"
create_label "review-fixed" "0052CC" "PR fixes completed, ready for merge"

echo ""
echo "🔧 Creating CI/CD status labels..."

# CI/CD Status Labels
create_label "ci-failure" "D93F0B" "CI checks have failed"
create_label "ci-passed" "0E8A16" "CI checks have passed"

echo ""
echo "🏷️  Creating additional useful labels..."

# Additional useful labels for issue management
create_label "claude" "7B68EE" "Issues that should be processed by Claude Code"
create_label "enhancement" "A2EEEF" "New feature or request"
create_label "bug" "D73A4A" "Something isn't working"
create_label "documentation" "0075CA" "Improvements or additions to documentation"
create_label "good first issue" "7057FF" "Good for newcomers"
create_label "help wanted" "008672" "Extra attention is needed"
create_label "question" "D876E3" "Further information is requested"
create_label "wontfix" "FFFFFF" "This will not be worked on"
create_label "duplicate" "CFD3D7" "This issue or pull request already exists"
create_label "invalid" "E4E669" "This doesn't seem right"
create_label "dependencies" "0366D6" "Pull requests that update a dependency file"

echo ""
echo "✅ Label creation completed!"
echo ""
echo "📊 Current labels in repository:"
gh label list --limit 50

echo ""
echo "🎉 All required labels have been created successfully!"
echo "   The automated workflow system is now ready to use these labels."