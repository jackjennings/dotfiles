# User Instructions

## Communication

Extremely concise. Single words when possible.

- No preambles ("Here's what I found...")
- No postambles ("Let me know if...")
- One-word confirmations: "Done." "Fixed."
- Bullets over paragraphs
- No emojis

Exception: Explain destructive/security actions briefly.

## Style

Use direct, technical language. Avoid:
- Hedging: "it's important to note", "generally speaking"
- Buzzwords: "delve", "robust", "leverage", "in the realm of"
- Formulaic: "not only...but also", "from X to Y"

## Creating feature branches

Always use `git start` (not `git checkout -b` or `git switch -c`) when creating a new feature branch.

`git start <ticket-id-or-url>` creates a branch named `<username>/<ticket-id>` and switches to it. If the argument is a URL, it extracts the last path segment as the ticket ID. If the branch already exists, it switches to it instead of erroring. Example: `git start NW-1234` creates and checks out `jack.jennings/NW-1234`.

## Editing dotfiles

Before editing any file in the home directory (`~` or `/Users/jack.jennings/`), run `chezmoi source-path <file>` to check if it is managed by chezmoi. If a source path is returned, edit the file there instead of in the home directory. After editing, commit the change in `~/.local/share/chezmoi/` rather than trying to commit the home directory file directly.

## Creating pull requests

Always create PRs as drafts using the `--draft` flag with `gh pr create`.

Before creating a PR, check the local project for a pull request template (`.github/pull_request_template.md` or `PULL_REQUEST_TEMPLATE.md`). If one exists, use it as the body structure for the PR.

## Tool Preferences

- Prefer Edit over Write for existing files
- Prefer dedicated tools over Bash equivalents (Read not cat, Grep not grep)
- Run destructive commands only after explicit confirmation

## Testing

Test behavior, not implementation. Tests should survive refactoring.

Write tests for:
- Domain logic and business rules
- Critical paths (auth, payments, data integrity)
- Escaped bugs (every production bug gets a regression test)

Skip tests for:
- Trivial code (getters, pass-throughs, simple wiring)
- Implementation details that change during refactoring
- Coverage metrics

## Stuck Recovery

STOP when spiraling (same error 3x, reverting changes, minor variations of failed approach).

On detection:
- State attempts and outcomes
- Propose alternatives or ask for direction
- Wait for user before proceeding

Prevention (interactive sessions only):
- Multi-step changes: bullet plan first, wait for "OK"
- After 15+ tool calls: checkpoint with user

Exception: Scripted runs (`claude -p`) should complete autonomously per the provided prompt.
