# Claude Code Auto Workflows

[![GitHub Issues](https://img.shields.io/github/issues/azumag/cca-auto-workflows)](https://github.com/azumag/cca-auto-workflows/issues)
[![GitHub Pull Requests](https://img.shields.io/github/issues-pr/azumag/cca-auto-workflows)](https://github.com/azumag/cca-auto-workflows/pulls)
[![License](https://img.shields.io/github/license/azumag/cca-auto-workflows)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Powered%20by-Claude%20Code-orange)](https://claude.ai/code)

A comprehensive GitHub Actions workflow system that automates issue processing, code review, and pull request management using Claude Code.

> **⚡ Fully Automated Development Workflow**: This repository demonstrates a complete automation pipeline where issues are automatically selected, processed by Claude Code, converted to pull requests, reviewed, and merged without manual intervention.

## Table of Contents
- [Workflow Overview](#workflow-overview)
- [Detailed Workflow Processes](#detailed-workflow-processes)
- [Setup Instructions](#setup-instructions)
- [Required Labels](#required-labels)
- [Required Permissions](#required-permissions)
- [GitHub App Configuration](#github-app-configuration)
- [Personal Access Token Configuration](#personal-access-token-configuration)
- [Workflow Files](#workflow-files)

## Workflow Overview

This repository implements an automated development workflow that processes issues, creates pull requests, runs CI checks, performs code reviews, and auto-merges approved changes.

```mermaid
graph TD
    A[Open Issue] --> B{Has @claude?}
    B -->|No| C[Auto Issue Resolver<br/>Hourly Cron]
    B -->|Yes| D[Claude Code Workflow]
    C --> E[Add 'processing' label<br/>to random issue]
    E --> F[Issue Processor Workflow]
    D --> G[Claude processes request]
    F --> H[Claude solves issue]
    G --> I{Implementation complete?}
    H --> I
    I -->|Yes| J[Add 'pr-ready' label]
    I -->|No| K[Continue processing]
    J --> L[Issue Processor creates PR]
    L --> M[Add 'pr-created' label]
    M --> N[CI Workflow runs]
    N --> O{CI Success?}
    O -->|Yes| P[Add 'ci-passed' label]
    O -->|No| Q[Add 'ci-failure' label]
    P --> R[Claude Code Review]
    R --> S[Add 'reviewed' label]
    S --> T[Claude Review Fix]
    T --> U{Review fixed?}
    U -->|Yes| V[Add 'review-fixed' label]
    U -->|No| W[Continue fixing]
    V --> X[Auto-approve & merge PR]
    X --> Y[Close issue as resolved]
```

## Detailed Workflow Processes

### 1. Issue Processing Flow

```mermaid
sequenceDiagram
    participant User
    participant AutoResolver as Auto Issue Resolver
    participant IssueProcessor as Issue Processor
    participant Claude
    participant GitHub

    Note over AutoResolver: Runs every hour (cron: '0 * * * *')
    AutoResolver->>GitHub: List open issues
    AutoResolver->>GitHub: Filter issues without 'processing' label
    AutoResolver->>GitHub: Select random issue
    AutoResolver->>GitHub: Add 'processing' label
    
    Note over IssueProcessor: Triggered by 'processing' label
    IssueProcessor->>Claude: Execute with direct_prompt
    Claude->>Claude: Analyze and implement solution
    Claude->>GitHub: Create commits and push changes
    Claude->>GitHub: Add 'pr-ready' label
    
    IssueProcessor->>GitHub: Remove 'processing' label
    IssueProcessor->>GitHub: Check for 'pr-ready' label or PR link
    IssueProcessor->>GitHub: Create Pull Request
    IssueProcessor->>GitHub: Add 'pr-created' label
```

### 2. Code Review and Merge Flow

```mermaid
sequenceDiagram
    participant CI
    participant CIHandler as CI Result Handler
    participant CodeReview as Claude Code Review
    participant ReviewFix as Claude Review Fix
    participant GitHub

    CI->>CI: Run tests and checks
    CI->>CIHandler: Workflow completion event
    
    alt CI Success
        CIHandler->>GitHub: Remove 'ci-failure' label
        CIHandler->>GitHub: Add 'ci-passed' label
        
        Note over CodeReview: Triggered by 'ci-passed' label
        CodeReview->>Claude: Perform comprehensive code review
        CodeReview->>GitHub: Add review comments
        CodeReview->>GitHub: Add 'reviewed' label
        
        Note over ReviewFix: Triggered by 'reviewed' label
        ReviewFix->>GitHub: Remove 'reviewed' label
        ReviewFix->>Claude: Fix review issues
        Claude->>Claude: Apply fixes and commit
        Claude->>GitHub: Add 'review-fixed' label
        
        ReviewFix->>GitHub: Auto-approve PR
        ReviewFix->>GitHub: Auto-merge PR
    else CI Failure
        CIHandler->>GitHub: Remove 'ci-passed' and 'review-fixed' labels
        CIHandler->>GitHub: Add 'ci-failure' label
    end
```

### 3. Manual Claude Interaction Flow

```mermaid
graph LR
    A[User mentions @claude] --> B[Claude Code Workflow]
    B --> C{Event Type}
    C -->|issue_comment| D[Process comment request]
    C -->|issues opened/assigned| E[Process issue]
    C -->|PR review| F[Handle PR review]
    D --> G[Claude analyzes and responds]
    E --> G
    F --> G
    G --> H[Update comments/files]
    H --> I[Commit changes if needed]
```

## Setup Instructions

### Quick Setup Sequence
1. **Install Claude Code CLI**: `npm install -g @anthropic-ai/claude-code`
2. **Setup OAuth**: Run `claude setup-token` to get your OAuth token
3. **Install GitHub App**: Run `/install-github-app` in Claude Code CLI
4. **Create Custom GitHub App** (for advanced permissions):
   - Follow the detailed GitHub App Configuration section below
   - Set `APP_ID` and `APP_PRIVATE_KEY` in repository secrets
5. **Create Personal Access Token** with required scopes
6. **Add Repository Secrets**:
   - `PERSONAL_ACCESS_TOKEN`: Your PAT
   - `CLAUDE_CODE_OAUTH_TOKEN`: From step 2
   - `APP_ID` & `APP_PRIVATE_KEY`: From step 4
7. **Create Labels**: Run the label creation commands provided below
8. **Copy Workflow Files**: Add the workflow files from this repository to `.github/workflows/`

> **⚠️ Important**: Complete all steps in order. Missing secrets or labels will cause workflow failures.

## Required Labels

The system uses the following labels to track workflow state:

### Issue Processing Labels
| Label | Purpose | Added By |
|-------|---------|----------|
| `processing` | Issue is being processed by Claude | auto-issue-resolver.yml |
| `pr-ready` | Implementation complete, ready for PR creation | Claude Code |
| `pr-created` | PR has been created for this issue | issue-processor.yml |
| `resolved` | Issue has been resolved and closed | Manual/Auto |

### PR Review Labels
| Label | Purpose | Added By |
|-------|---------|----------|
| `reviewed` | PR has been reviewed and needs fixes | claude-code-review.yml |
| `review-fixed` | PR fixes completed, ready for merge | claude-review-fix.yml |

### CI/CD Status Labels
| Label | Purpose | Added By |
|-------|---------|----------|
| `ci-failure` | CI checks have failed | ci-result-handler.yml |
| `ci-passed` | CI checks have passed | ci-result-handler.yml |

### Label Creation Command
```bash
# Create all required labels at once
gh label create "processing" --color "FFA500" --description "Issue is being processed by Claude"
gh label create "pr-ready" --color "0052CC" --description "Implementation complete, ready for PR creation"
gh label create "pr-created" --color "0E8A16" --description "PR has been created for this issue"
gh label create "resolved" --color "6F42C1" --description "Issue has been resolved and closed"
gh label create "reviewed" --color "D93F0B" --description "PR has been reviewed and needs fixes"
gh label create "review-fixed" --color "0052CC" --description "PR fixes completed, ready for merge"
gh label create "ci-failure" --color "D93F0B" --description "CI checks have failed"
gh label create "ci-passed" --color "0E8A16" --description "CI checks have passed"
```

## Required Permissions

### GitHub App Permissions
The GitHub App requires the following permissions:

#### Repository Permissions
- **Contents**: `write` - Read and write repository contents
- **Issues**: `write` - Create, edit, and manage issues
- **Pull Requests**: `write` - Create, edit, and manage pull requests
- **Actions**: `read` - Read workflow run results for CI status
- **Metadata**: `read` - Read repository metadata

#### Account Permissions
- **Email addresses**: `read` - Access user email for commits

### Workflow Permissions
Each workflow requires specific permissions:

```yaml
permissions:
  contents: write        # For code changes and commits
  issues: write         # For issue management and labeling
  pull-requests: write  # For PR creation and management
  actions: read         # For reading CI results
  id-token: write       # For authentication
```

## GitHub App Configuration

### 1. Create GitHub App
1. Go to GitHub Settings > Developer Settings > GitHub Apps
2. Click "New GitHub App"
3. Fill in the app details:
   - **App name**: `claude-code-automation` (or your preferred name)
   - **Homepage URL**: Your repository URL
   - **Webhook URL**: Leave blank (not needed for this setup)

### 2. Set Permissions
Configure the following permissions:

#### Repository permissions:
- Contents: Read and write
- Issues: Read and write
- Pull requests: Read and write
- Actions: Read
- Metadata: Read

#### Subscribe to events:
- Issues
- Pull requests
- Push

### 3. Generate Private Key
1. Scroll down to "Private keys" section
2. Click "Generate a private key"
3. Download the `.pem` file

### 4. Install App
1. Go to "Install App" tab
2. Install on your account/organization
3. Select repositories or choose "All repositories"

### 5. Get App ID
- Find your App ID on the app settings page

## Personal Access Token Configuration

### Required Scopes
Create a Personal Access Token with the following scopes:

- `repo` (Full control of private repositories)
  - `repo:status` - Access commit status
  - `repo_deployment` - Access deployment status
  - `public_repo` - Access public repositories
- `workflow` - Update GitHub Action workflows
- `write:packages` - Upload packages to GitHub Package Registry (optional)
- `read:packages` - Download packages from GitHub Package Registry (optional)

> **Security Note**: For production environments, consider using fine-grained personal access tokens with minimal required permissions.

### Token Creation Steps
1. Go to GitHub Settings > Developer Settings > Personal Access Tokens > Tokens (classic)
2. Click "Generate new token (classic)"
3. Select the required scopes listed above
4. Set expiration (recommend 90 days or no expiration for automation)
5. Generate token and copy it immediately

## Repository Secrets Configuration

Add the following secrets to your repository:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `APP_ID` | Your GitHub App ID | Found on GitHub App settings page |
| `APP_PRIVATE_KEY` | Contents of downloaded `.pem` file | GitHub App private key |
| `PERSONAL_ACCESS_TOKEN` | Your PAT | Personal Access Token with required scopes |
| `CLAUDE_CODE_OAUTH_TOKEN` | Your Claude Code OAuth token | Obtained from Claude Code CLI |

### Setting Secrets
```bash
# Using GitHub CLI
gh secret set APP_ID --body "123456"
gh secret set APP_PRIVATE_KEY --body "$(cat path/to/your-app.pem)"
gh secret set PERSONAL_ACCESS_TOKEN --body "ghp_your_token_here"
gh secret set CLAUDE_CODE_OAUTH_TOKEN --body "your_claude_oauth_token"
```

## Workflow Files

### Core Workflows

| File | Purpose | Trigger |
|------|---------|---------|
| `.github/workflows/auto-issue-resolver.yml` | Automatically adds 'processing' label to random issues | Cron (hourly) |
| `.github/workflows/issue-processor.yml` | Processes issues with Claude and creates PRs | Label: 'processing' |
| `.github/workflows/claude.yml` | Main Claude Code integration | @claude mentions |
| `.github/workflows/ci.yml` | Continuous Integration | PR events |
| `.github/workflows/ci-result-handler.yml` | Handles CI results and updates labels | CI workflow completion |
| `.github/workflows/claude-code-review.yml` | Automated code review | Label: 'ci-passed' |
| `.github/workflows/claude-review-fix.yml` | Handles review fixes and auto-merge | Label: 'reviewed' |

### Workflow Dependencies

```mermaid
graph TD
    A[auto-issue-resolver.yml] --> B[issue-processor.yml]
    B --> C[ci.yml]
    C --> D[ci-result-handler.yml]
    D --> E[claude-code-review.yml]
    E --> F[claude-review-fix.yml]
    
    G[claude.yml] --> H[Manual Claude interaction]
    
    style A fill:#ff9999
    style B fill:#99ccff
    style C fill:#99ff99
    style D fill:#ffcc99
    style E fill:#cc99ff
    style F fill:#ffff99
    style G fill:#ff99cc
    style H fill:#ccffcc
```

## Troubleshooting

### Common Issues

#### Workflow Not Triggering
- **Issue**: Claude doesn't respond to @claude mentions
- **Solution**: Check that the triggering user has write permissions to the repository
- **Check**: Verify `CLAUDE_CODE_OAUTH_TOKEN` is correctly set in repository secrets

#### Label Processing Issues
- **Issue**: Issues stuck in 'processing' state
- **Solution**: Check that all required labels are created in the repository
- **Command**: Use the label creation script provided in the setup section

#### Permission Errors
- **Issue**: "Resource not accessible" errors in workflows
- **Solution**: Verify GitHub App has all required permissions listed in the setup
- **Check**: Ensure Personal Access Token has sufficient scopes

#### CI Integration Problems
- **Issue**: CI status not updating properly
- **Solution**: Check that `actions: read` permission is granted to workflows
- **Verify**: Ensure CI workflow names match those expected by the handlers

### Debug Mode
To enable detailed logging in workflows, add the following secret:
```
ACTIONS_STEP_DEBUG=true
```

## Important Notes

### anthropics/claude-code-action@beta Limitations
When using `anthropics/claude-code-action@beta`, the following are not supported:
- `workflow_run` events
- `repository_dispatch` events

These limitations only apply to the Claude Code Action. Regular `github-script` actions can still use these events.

### Auto-Generated Content Restrictions
Automatic comments, labels, and other content created by GitHub Actions workflows cannot trigger additional action workflows. Use Personal Access Token (PAT) for actions that need to trigger other workflows.

### Rate Limiting
Be aware of GitHub API rate limits when running frequent automated workflows. The hourly cron job helps distribute load, but monitor usage in high-activity repositories.