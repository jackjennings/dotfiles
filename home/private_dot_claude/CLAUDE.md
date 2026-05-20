# User Instructions

## Creating feature branches

Always use `git start` (not `git checkout -b` or `git switch -c`) when creating a new feature branch.

`git start <ticket-id-or-url>` creates a branch named `<username>/<ticket-id>` and switches to it. If the argument is a URL, it extracts the last path segment as the ticket ID. If the branch already exists, it switches to it instead of erroring. Example: `git start NW-1234` creates and checks out `jack.jennings/NW-1234`.

## Creating pull requests

Before creating a PR, check the local project for a pull request template (`.github/pull_request_template.md` or `PULL_REQUEST_TEMPLATE.md`). If one exists, use it as the body structure for the PR.
