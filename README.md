# cca-auto-workflows

## Sequence
- install Claude Code
- /install-github-app and install Claude Code Actions
- make & install github app with permission and set APP_ID and APP_PRIVATE_KEY to actions secrets
- create & set Personal access token with permission to secrets
- create label for state= ['processing', 'pr-ready', 'pr-created', 'resolved', 'ci-failure', 'ci-passed', 'reviewed', 'review-fixed']

## Labels Used

### Issue Processing Flow
- **`processing`**: Issue is being processed by Claude (added by auto-issue-resolver)
- **`pr-ready`**: Implementation is complete and ready for PR creation (added by Claude)
- **`pr-created`**: PR has been created for this issue
- **`resolved`**: Issue has been resolved and closed

### PR Review Flow
- **`reviewed`**: PR has been reviewed and needs fixes
- **`review-fixed`**: PR fixes have been completed and ready for merge

### CI/CD Status
- **`ci-failure`**: CI checks have failed
- **`ci-passed`**: CI checks have passed

## permissions
issue, contents, pull-request: write
actions: read