# cca-auto-workflows

## Sequence
- install Claude Code
- /install-github-app and install Claude Code Actions
- make & install github app with permission and set APP_ID and APP_PRIVATE_KEY to actions secrets
- create & set Personal access token with permission to secrets
- create label for state= ['pr', 'resolved', 'ci-failure', 'ci-passed', 'reviewed', 'review-fixed']

## permissions
issue, contents, pull-request: write
actions: read