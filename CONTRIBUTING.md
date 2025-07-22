# Contributing to Claude Code Auto Workflows

Thank you for your interest in contributing to this project! This document provides guidelines and information for contributors.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Code Quality Standards](#code-quality-standards)
- [Testing](#testing)
- [Pull Request Process](#pull-request-process)
- [Issue Reporting](#issue-reporting)
- [Code of Conduct](#code-of-conduct)

## Getting Started

### Prerequisites

- GitHub account
- Basic understanding of GitHub Actions and YAML
- Claude Code CLI (for testing Claude interactions)
- Git command line tools

### Development Environment

This project consists primarily of:
- GitHub Actions workflows (`.github/workflows/`)
- Markdown documentation
- Configuration files for various tools

No complex build process or runtime environment is required.

## Development Setup

1. **Fork the repository**
   ```bash
   gh repo fork azumag/cca-auto-workflows
   ```

2. **Clone your fork**
   ```bash
   git clone https://github.com/YOUR_USERNAME/cca-auto-workflows.git
   cd cca-auto-workflows
   ```

3. **Install development dependencies** (optional)
   ```bash
   npm install -g markdownlint-cli
   npm install -g markdown-link-check
   pip install yamllint
   ```

4. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Code Quality Standards

### YAML Workflows

- Use 2-space indentation
- Follow GitHub Actions best practices
- Include descriptive names for all jobs and steps
- Use `continue-on-error: true` for non-critical steps
- Add proper permissions declarations
- Include timeout settings for long-running jobs

**Example:**
```yaml
name: Example Workflow

on:
  push:
    branches: [main]

permissions:
  contents: read
  issues: write

jobs:
  example:
    name: Example Job
    runs-on: ubuntu-latest
    timeout-minutes: 10
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
```

### Markdown Documentation

- Follow the existing markdownlint configuration
- Use ATX-style headers (`#` instead of `===`)
- Keep line length under 120 characters
- Include table of contents for long documents
- Use relative links for internal references

### Configuration Files

- Validate JSON files before committing
- Use consistent formatting and indentation
- Include comments where helpful
- Follow the established patterns in existing config files

## Testing

### Local Validation

Before submitting a pull request, run these checks:

```bash
# Validate YAML files
yamllint .github/workflows/

# Check markdown formatting
markdownlint .

# Validate JSON files
for file in *.json; do python -m json.tool "$file" > /dev/null; done

# Check markdown links
find . -name "*.md" -exec markdown-link-check {} \;
```

### Workflow Testing

- Test workflow changes in your fork before submitting
- Ensure workflows don't fail due to missing secrets or permissions
- Use `continue-on-error: true` for steps that might fail in forks
- Document any required secrets or setup steps

## Pull Request Process

### Before Submitting

1. **Test your changes thoroughly**
   - Run local validation scripts
   - Test workflows in your fork if applicable
   - Verify documentation is accurate and up-to-date

2. **Follow commit conventions**
   ```bash
   # Examples of good commit messages
   git commit -m "feat: add new workflow for dependency updates"
   git commit -m "fix: resolve issue with label processing"
   git commit -m "docs: update contributing guidelines"
   git commit -m "ci: improve error handling in validation jobs"
   ```

3. **Update documentation**
   - Update README.md if adding new features
   - Document any new configuration requirements
   - Include examples for new workflows or features

### Pull Request Template

```markdown
## Summary
Brief description of what this PR does.

## Changes Made
- List of specific changes
- Include configuration updates
- Note any breaking changes

## Testing
- [ ] Local validation passes
- [ ] Workflows tested in fork (if applicable)
- [ ] Documentation updated
- [ ] Examples provided

## Related Issues
Closes #issue_number (if applicable)
```

### Review Process

1. All PRs require review before merging
2. Automated CI checks must pass
3. Documentation should be clear and complete
4. Changes should follow established patterns

## Issue Reporting

### Bug Reports

When reporting bugs, please include:

- **Description**: Clear description of the problem
- **Steps to reproduce**: Detailed steps to reproduce the issue
- **Expected behavior**: What you expected to happen
- **Actual behavior**: What actually happened
- **Environment**: Relevant details about your setup
- **Logs**: Any relevant error messages or logs

### Feature Requests

For feature requests, please include:

- **Use case**: Why this feature would be useful
- **Proposed solution**: How you think it should work
- **Alternatives**: Other solutions you've considered
- **Additional context**: Any other relevant information

### Labels

We use the following labels to categorize issues:

- `bug`: Something isn't working correctly
- `enhancement`: New feature or improvement
- `documentation`: Documentation improvements
- `question`: Questions about usage or functionality
- `good first issue`: Good for new contributors

## Code of Conduct

### Our Standards

- **Be respectful**: Treat all contributors with respect
- **Be collaborative**: Work together towards common goals
- **Be inclusive**: Welcome contributors from all backgrounds
- **Be constructive**: Provide helpful feedback and suggestions

### Unacceptable Behavior

- Harassment or discrimination of any kind
- Trolling, insulting, or derogatory comments
- Publishing private information without consent
- Any conduct that would be inappropriate in a professional setting

### Reporting Issues

If you experience or witness unacceptable behavior, please report it by:
- Opening a GitHub issue
- Contacting the project maintainers directly

## Recognition

Contributors will be recognized in several ways:

- Listed in the project's contributor list
- Mentioned in release notes for significant contributions
- GitHub's built-in contribution tracking

## Questions and Support

If you have questions about contributing:

1. Check the existing documentation
2. Search existing issues for similar questions
3. Open a new issue with the `question` label
4. Join project discussions if available

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [YAML Specification](https://yaml.org/spec/)
- [Markdown Guide](https://www.markdownguide.org/)

Thank you for contributing to Claude Code Auto Workflows! 🚀