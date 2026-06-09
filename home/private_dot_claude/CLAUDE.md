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
