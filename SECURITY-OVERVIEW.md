# Security Overview

## Security Quick Start - CRITICAL

> **CRITICAL PRIORITY**: These items must be implemented before production deployment

For immediate security, focus on these critical items first:

### 1. Token and Secret Management
- **Never commit secrets or credentials** to the repository
- Store all tokens and API keys in GitHub repository secrets
- See **SECURITY-ADVANCED.md** for detailed implementation

### 2. API Security Setup
- Ensure all API calls use HTTPS
- Store Claude Code OAuth tokens as repository secrets  
- See **SECURITY-ADVANCED.md** for complete setup guide

### 3. Vulnerability Reporting Process
- Set up security advisory reporting through GitHub Security tab
- Never report vulnerabilities through public issues
- Establish 48-hour acknowledgment timeline

**Implementation Timeline**: Complete within 1-2 days before any production use.
**Verification**: Run security checklist in **SECURITY-INCIDENT-RESPONSE.md** to confirm completion.

---

## Supported Versions

We support security updates for the following versions of this project:

| Version | Supported          |
| ------- | ------------------ |
| Latest  | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability - CRITICAL

> **CRITICAL PRIORITY**: Essential for security incident response

The security of our project is a top priority. If you discover a security vulnerability, we appreciate your help in disclosing it to us responsibly.

### How to Report

**Do not report security vulnerabilities through public GitHub issues.**

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

For detailed response procedures and timelines, see **SECURITY-INCIDENT-RESPONSE.md**.

## Essential Security Considerations

### GitHub Actions Security

This project uses GitHub Actions workflows which have specific security considerations:

- All workflows use minimal required permissions
- Repository secrets are used for sensitive data
- We use pinned versions of third-party actions

### Claude Code Integration

- Claude Code OAuth tokens are stored as repository secrets
- API calls are made over HTTPS
- Code execution is limited to repository scope

For detailed configuration information, see **SECURITY-ADVANCED.md**.

## Quick Reference

- **Detailed configurations**: See SECURITY-ADVANCED.md
- **Incident response procedures**: See SECURITY-INCIDENT-RESPONSE.md
- **Security tools and best practices**: See SECURITY-ADVANCED.md

---

**Security Reminder**: Security is everyone's responsibility. When in doubt about any security decision, consult the security team or create a discussion thread for community guidance.