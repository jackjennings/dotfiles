# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

```sh
chezmoi apply              # Apply all managed files to ~
chezmoi diff               # Preview what apply would change (excludes externals)
chezmoi add ~/.some/file   # Start tracking a new file
chezmoi edit ~/.some/file  # Edit a managed file in place
chezmoi data               # Inspect template variables
```

After editing files in this repo directly, run `chezmoi apply` to push changes to `~`.

## Architecture

The chezmoi source root is `home/` (set by `.chezmoiroot`). Everything inside maps to `~`.

**File naming conventions** (chezmoi decodes these to produce target paths):
- `dot_foo` → `.foo`
- `private_` prefix → file created with mode 600
- `executable_` prefix → file created with mode 755
- `.tmpl` suffix → rendered as a Go template before writing

**Template data** is defined in `home/.chezmoi.toml.tmpl`, prompted once and cached. Key variables:
- `.email`, `.name` — personal identity
- `.features.asdf` — boolean flag (currently false) controlling asdf vs. Homebrew for runtime versions
- `.github.username`, `.onepassword.account_id` — used in git configs and scripts

**Shell config layering:**
- `dot_zprofile` — login shell only (Homebrew env)
- `dot_zshrc.tmpl` — interactive shell bootstrap (oh-my-zsh setup, sources `.zshrc.local`)
- `dot_oh-my-zsh-custom/*.zsh` — auto-sourced by oh-my-zsh; this is where tool integrations live (one file per tool)

**`run_onchange_` scripts** re-execute whenever their rendered content changes. Scripts that should re-run when a config file changes embed a sha256 hash of that file in a comment:
```sh
# Brewfile hash: {{ include "Brewfile.tmpl" | sha256sum }}
```
Scripts are run in lexicographic order — `run_onchange_000_brew-bundle.sh.tmpl` runs before others.

**`home/.chezmoiexternal.toml`** pulls external content (oh-my-zsh archive, Hammerspoon spoons, zsh-completions, agent-browser skill) on `chezmoi apply`. Externals are excluded from `chezmoi diff`.

**Package management** flows through `Brewfile.tmpl` → `run_onchange_000_brew-bundle.sh.tmpl`. Editing `Brewfile.tmpl` and running `chezmoi apply` installs/removes packages via `brew bundle`.

**Agent config:**
- `private_dot_claude/` — Claude Code settings
- `dot_pi/agent/` — Pi coding agent settings and packages; `run_onchange_pi-install.sh.tmpl` runs `pi install` when `settings.json` changes
