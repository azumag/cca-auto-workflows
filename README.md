# Claude Code Automated Workflows

An automated issue processing system that combines Claude Code Actions with intelligent workflow automation to streamline issue resolution and pull request creation.

## Overview

This repository demonstrates a sophisticated automated issue processing system that:

1. **Automatically selects and processes issues** using Claude Code Actions
2. **Creates intelligent responses** through @claude mentions
3. **Manages issue states** using a comprehensive labeling system
4. **Automates pull request creation** when implementations are ready

## System Architecture

### Core Components

#### 1. Claude Code Action Workflow (`claude.yml`)
- **Triggers**: Responds to @claude mentions in issues, comments, and PR reviews
- **Purpose**: Processes requests and implements solutions using Claude Code
- **Features**: 
  - Automatic branch creation and management
  - Intelligent code analysis and implementation
  - Progress tracking through GitHub comments
  - PR creation with comprehensive descriptions

#### 2. Auto Issue Resolver (`auto-issue-resolver.yml`)
- **Schedule**: Runs hourly to process open issues
- **Logic**: 
  - Searches for issues with 'pr' label to create pull requests
  - Randomly selects open issues for processing if none are PR-ready
  - Posts @claude mentions to trigger automated resolution
- **Output**: Creates PRs automatically or initiates issue processing

### Issue State Management

The system uses labels to track issue progress:

- **`pr`**: Issue is ready for pull request creation
- **`resolved`**: Issue has been completed and should be closed
- **`ci-failure`**: Continuous integration checks failed
- **`ci-passed`**: All CI checks passed successfully
- **`reviewed`**: Code has been reviewed
- **`review-fixed`**: Review feedback has been addressed

## Setup Instructions

### Prerequisites

1. **Claude Code Account**: Active Claude Code subscription
2. **GitHub App**: Custom GitHub App with appropriate permissions
3. **Personal Access Token**: GitHub PAT with repo access

### Installation Steps

1. **Install Claude Code**
   ```bash
   # Follow Claude Code installation instructions
   ```

2. **Install Claude Code Actions GitHub App**
   - Navigate to `/install-github-app` 
   - Install Claude Code Actions to your repository

3. **Create and Configure GitHub App**
   - Create a GitHub App with required permissions
   - Generate and securely store private key
   - Set `APP_ID` and `APP_PRIVATE_KEY` in Actions secrets

4. **Configure Personal Access Token**
   - Generate PAT with repository access
   - Set `PERSONAL_ACCESS_TOKEN` in Actions secrets
   - Set `CLAUDE_CODE_OAUTH_TOKEN` in Actions secrets

5. **Create Issue Labels**
   Create the following labels in your repository:
   ```
   pr, resolved, ci-failure, ci-passed, reviewed, review-fixed
   ```

### Required Permissions

The system requires the following GitHub permissions:

- **Issues**: write (create comments, manage labels)
- **Contents**: write (create branches, commit changes)
- **Pull Requests**: write (create and manage PRs)
- **Actions**: read (access workflow results)

## Usage

### Manual Processing

To manually trigger issue processing:

1. **Mention Claude**: Add `@claude` to any issue or comment
2. **Provide Context**: Include specific instructions or questions
3. **Monitor Progress**: Claude will update comments with progress
4. **Review Results**: Check generated branches and PR links

### Automated Processing

The system automatically:

1. **Scans Issues**: Hourly check for open issues
2. **Prioritizes PR-Ready**: Issues with 'pr' label get PR creation
3. **Random Selection**: Picks random issues for processing
4. **Triggers Claude**: Posts @claude mentions to start resolution

### Example Workflow

```
Issue Created → Auto-Resolver Selects → @claude Mention → 
Claude Processes → Branch Created → PR Ready → Auto-PR Creation
```

## Advanced Configuration

### Customizing Claude Behavior

Edit the `claude.yml` workflow to:

- **Change trigger phrase**: Modify `trigger_phrase` parameter
- **Adjust model**: Switch between Claude Sonnet 4 and Opus 4
- **Add custom instructions**: Include project-specific guidelines
- **Configure allowed tools**: Specify which tools Claude can use

### Monitoring and Debugging

- **Workflow Logs**: Check Actions tab for detailed execution logs
- **Issue Comments**: Monitor Claude's progress updates
- **Label States**: Track issue progression through state labels
- **PR Links**: Verify automatic PR creation and content

## Troubleshooting

### Common Issues

1. **Claude Not Responding**: Check CLAUDE_CODE_OAUTH_TOKEN configuration
2. **PR Creation Failing**: Verify GitHub App permissions and APP_ID/APP_PRIVATE_KEY
3. **Random Selection Not Working**: Ensure PERSONAL_ACCESS_TOKEN has proper scope
4. **Labels Missing**: Create all required state labels manually

### Support Resources

- **GitHub Actions Logs**: Detailed execution information
- **Claude Code Documentation**: Official setup guides
- **Issue Templates**: Use consistent formatting for better processing

## Contributing

### Issue Processing Guidelines

1. **Clear Descriptions**: Provide specific, actionable issue descriptions
2. **Appropriate Labels**: Use state labels to track progress
3. **Context Information**: Include relevant background and requirements
4. **Testing Instructions**: Specify how to verify implementations

### Best Practices

- **Single Responsibility**: One issue per specific task or bug
- **Descriptive Titles**: Clear, concise issue titles
- **Step-by-Step**: Break complex requests into smaller issues
- **Documentation**: Update README when adding new features

## License

This project serves as a template for automated issue processing systems. Adapt and modify according to your specific requirements and compliance needs.