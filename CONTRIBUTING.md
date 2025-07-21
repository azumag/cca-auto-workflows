# Contributing to Claude Code Auto Workflows

Thank you for your interest in contributing to this project! This repository demonstrates automated workflows using Claude Code for GitHub Actions.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Contributing Guidelines](#contributing-guidelines)
- [Testing](#testing)
- [Documentation](#documentation)
- [Pull Request Process](#pull-request-process)
- [Code of Conduct](#code-of-conduct)

## Getting Started

This repository contains automated workflows that integrate Claude Code with GitHub Actions for:

- Automatic issue processing and resolution
- Pull request creation and management
- Code review automation
- CI/CD pipeline management

### Prerequisites

- GitHub account with appropriate repository permissions
- Understanding of GitHub Actions and YAML syntax
- Familiarity with markdown documentation

## Development Setup

### Local Development

1. Fork and clone the repository:
   ```bash
   git clone https://github.com/yourusername/cca-auto-workflows.git
   cd cca-auto-workflows
   ```

2. Create a new branch for your feature:
   ```bash
   git checkout -b feature/your-feature-name
   ```

### Configuration Files

The repository uses several configuration files:

- `.markdownlint.json` - Markdown linting rules
- `.markdown-link-check.json` - Link validation configuration
- `.yamllint.yml` - YAML validation rules
- `CLAUDE.md` - Claude Code specific instructions

### Workflow Structure

The `.github/workflows/` directory contains:

- `ci.yml` - Comprehensive CI pipeline with validation, security scanning, and performance analysis
- `claude.yml` - Claude Code integration workflow
- `daily-issue.yml` - Automatic issue creation
- Other automation workflows for issue processing and PR management

## Contributing Guidelines

### Code Quality Standards

1. **Markdown Documentation**:
   - Follow the rules defined in `.markdownlint.json`
   - Ensure all links are valid and accessible
   - Use consistent heading structure

2. **YAML Files**:
   - Follow YAML best practices
   - Use consistent indentation (2 spaces)
   - Validate syntax before committing

3. **GitHub Actions**:
   - Use semantic and descriptive job/step names
   - Include appropriate error handling
   - Follow security best practices for secrets and permissions

### Security Considerations

- Never commit secrets, tokens, or sensitive information
- Use GitHub secrets for sensitive data
- Validate external inputs in workflows
- Follow principle of least privilege for GitHub App permissions

### Documentation Requirements

- Update README.md if adding new functionality
- Document any new configuration options
- Include examples for new workflows
- Follow the repository's documentation style

## Testing

### Local Validation

Before submitting changes, run these validations locally:

```bash
# Markdown linting
markdownlint "**/*.md" --config .markdownlint.json

# Link checking
find . -name "*.md" | xargs markdown-link-check --config .markdown-link-check.json

# YAML validation
yamllint .github/workflows/

# JSON validation
python3 -m json.tool .markdownlint.json
python3 -m json.tool .markdown-link-check.json
```

### CI Pipeline

The CI pipeline automatically runs:

- **Validation & Linting**: Markdown, YAML, and JSON validation
- **Security Scan**: Trivy vulnerability scanner
- **Workflow Validation**: Structure and secrets validation
- **Performance Analysis**: Repository structure analysis

All checks must pass before merging.

## Pull Request Process

1. **Create Feature Branch**: Use descriptive branch names
2. **Make Changes**: Follow coding standards and guidelines
3. **Test Locally**: Run validation tools
4. **Commit Changes**: Use clear, descriptive commit messages
5. **Create Pull Request**: Include detailed description of changes
6. **Address Review Comments**: Collaborate on improvements
7. **Ensure CI Passes**: All automated checks must succeed

### Pull Request Template

Include the following in your PR description:

```markdown
## Description
Brief description of changes made

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Configuration change
- [ ] Workflow improvement

## Testing
- [ ] Local validation completed
- [ ] CI pipeline passes
- [ ] Manual testing performed (if applicable)

## Checklist
- [ ] Code follows project style guidelines
- [ ] Documentation updated (if applicable)
- [ ] No sensitive information committed
- [ ] Related issues referenced
```

## Workflow Permissions

This repository uses GitHub Apps with specific permissions:

### Required Permissions
- `contents: write` - For repository content access
- `issues: write` - For issue management
- `pull-requests: write` - For PR creation and management
- `metadata: read` - For repository metadata

### Permission Limitations
- Workflow files (`.github/workflows/`) require special `workflows` permission
- Some operations may require Personal Access Token (PAT) instead of GitHub App

## Troubleshooting

### Common Issues

1. **Workflow Permission Errors**:
   - Check GitHub App permissions
   - Consider using PAT for workflow modifications

2. **CI Failures**:
   - Run local validation first
   - Check workflow syntax
   - Verify configuration files

3. **Link Check Failures**:
   - Update `.markdown-link-check.json` ignore patterns
   - Check for broken external links

## Recognition

Contributors will be recognized in:
- Pull request acknowledgments
- Release notes (for significant contributions)
- Repository contributor listings

## Support

For questions or support:
- Create an issue in the repository
- Reference relevant documentation
- Follow existing patterns and examples

Thank you for contributing to the improvement of automated workflows with Claude Code!