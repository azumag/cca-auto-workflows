# Security Policy

## Supported Versions

We support security updates for the following versions of this project:

| Version | Supported          |
| ------- | ------------------ |
| Latest  | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

The security of our project is a top priority. If you discover a security vulnerability, we appreciate your help in disclosing it to us responsibly.

### How to Report

**Please do NOT report security vulnerabilities through public GitHub issues.**

Instead, please report security vulnerabilities through one of the following methods:

1. **GitHub Security Advisories** (Preferred)
   - Go to the [Security tab](https://github.com/azumag/cca-auto-workflows/security) of this repository
   - Click "Report a vulnerability"
   - Fill out the advisory form with details

2. **Email**
   - Send details to the repository maintainers
   - Include "SECURITY" in the subject line
   - Provide as much information as possible

### What to Include

Please include the following information in your report:

- **Type of vulnerability** (e.g., workflow injection, secrets exposure)
- **Location** of the vulnerability (file, line number, or workflow)
- **Step-by-step instructions** to reproduce the issue
- **Potential impact** of the vulnerability
- **Suggested fix** (if you have one)

### Response Timeline

- **Acknowledgment**: We will acknowledge receipt within 48 hours
- **Assessment**: Initial assessment within 5 business days
- **Updates**: Regular updates on our progress
- **Resolution**: Target resolution within 30 days for high-severity issues

## Security Considerations

### GitHub Actions Security

This project uses GitHub Actions workflows which have specific security considerations:

#### Workflow Permissions

- All workflows use minimal required permissions
- `permissions` blocks are explicitly defined
- Sensitive operations require elevated permissions

#### Secret Management

- Repository secrets are used for sensitive data
- Personal Access Tokens have minimal required scopes
- Secrets are never logged or exposed in workflow outputs

#### Third-Party Actions

- We use pinned versions of third-party actions
- Actions are regularly reviewed for security updates
- Only trusted and well-maintained actions are used

### Claude Code Integration

#### API Security

- Claude Code OAuth tokens are stored as repository secrets
- API calls are made over HTTPS
- Rate limiting is respected to prevent abuse

#### Code Execution

- Claude Code executes with limited permissions
- File system access is restricted to the repository
- Network access is limited to necessary APIs

### Dependency Security

#### Automated Scanning

- Trivy vulnerability scanner runs on all changes
- SARIF reports are uploaded to GitHub Security tab
- Dependencies are regularly updated

#### Monitoring

- Automated security alerts for dependencies
- Regular security audits of the codebase
- Continuous monitoring for new vulnerabilities

## Security Best Practices

### For Contributors

1. **Never commit secrets or credentials**
   - Use `.gitignore` for sensitive files
   - Use repository secrets for tokens and keys
   - Scan commits before pushing

2. **Validate inputs in workflows**
   - Sanitize user inputs in workflow parameters
   - Use shell escaping for dynamic values
   - Avoid eval-style operations

3. **Follow least privilege principle**
   - Request minimal required permissions
   - Limit scope of access tokens
   - Use specific branch protections

4. **Review workflow changes carefully**
   - Check for injection vulnerabilities
   - Verify third-party action versions
   - Test changes in forks first

### For Users

1. **Keep your environment secure**
   - Use strong passwords and 2FA
   - Keep your local Git installation updated
   - Use signed commits when possible

2. **Review permissions carefully**
   - Understand what permissions workflows request
   - Monitor repository access logs
   - Report suspicious activity

3. **Use secure authentication**
   - Use GitHub Apps instead of PATs when possible
   - Rotate tokens regularly
   - Limit token scopes

## Known Security Limitations

### GitHub Actions Limitations

1. **Workflow Modification Restrictions**
   - GitHub Apps cannot modify workflow files without explicit permission
   - This is a security feature, not a bug
   - Manual review required for workflow changes

2. **Fork Restrictions**
   - Some workflows may not work in forks due to secret access
   - This is intentional for security
   - Use `continue-on-error` for fork compatibility

### Claude Code Limitations

1. **API Rate Limits**
   - Claude API has usage limits
   - May affect availability during high usage
   - Not a security issue but worth noting

2. **Generated Code Review**
   - AI-generated code should be reviewed
   - May introduce unexpected behavior
   - Human oversight is recommended

## Security Updates

### Notification Process

- Security updates are announced in release notes
- Critical vulnerabilities are communicated via GitHub Security Advisories
- Subscribers to the repository will be notified

### Update Timeline

- **Critical**: Within 24 hours
- **High**: Within 72 hours
- **Medium**: Within 1 week
- **Low**: Next regular release

## Compliance and Standards

### Standards Followed

- GitHub Security Best Practices
- OWASP Top 10 considerations
- Principle of least privilege
- Defense in depth

### Regular Reviews

- Monthly security review of workflows
- Quarterly dependency updates
- Annual comprehensive security audit

## Security Tools

### Automated Tools

- **Trivy**: Vulnerability scanning
- **GitHub Security Alerts**: Dependency monitoring
- **CodeQL**: Static analysis (when applicable)
- **Secret Scanning**: GitHub native secret detection

### Manual Reviews

- Code review process for all changes
- Security-focused reviews for sensitive changes
- Regular audit of permissions and access

## Contact Information

For security-related questions or concerns:

- **GitHub Issues**: For general security questions (non-sensitive)
- **Security Advisories**: For vulnerability reports
- **Repository Discussions**: For community security discussions

## Acknowledgments

We thank the security community for helping keep our project secure:

- Researchers who responsibly disclose vulnerabilities
- Contributors who improve our security posture
- Users who report potential security issues

---

**Remember**: Security is everyone's responsibility. When in doubt, err on the side of caution and ask questions.