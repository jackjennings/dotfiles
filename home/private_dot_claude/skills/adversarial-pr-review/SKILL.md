---
name: adversarial-pr-review
description: Interactive, adversarial, ticket-aware review of a GitHub PR, walked through finding by finding with the user. Use when asked for an "adversarial review", "go deep" review, or to review a PR against its Jira ticket, epic, and design doc (TDD). Differs from the built-in code-review skill - it reads ticket/epic/TDD/backend context, verifies every candidate finding with a refutation subagent before presenting, then discusses findings one at a time and acts only on the user's decisions.
---

# Adversarial PR review

Goal: find issues introduced by the PR (critical bugs, ticket/contract deviations, duplication of existing code, unidiomatic patterns). Verify before presenting. Discuss one finding at a time. Act only when told.

Typical request: "Perform an adversarial review of <PR url>. Look at the associated ticket, epic, and TDD. Look for unidiomatic patterns, duplicated code, critical bugs. Go deep."

## Rules

- Only report issues introduced by the PR. Pre-existing quirks the PR moves or consolidates are dropped (at most one cleanup-idea line).
- Never claim "verified" unless data was read. State what was not verified.
- Do not post, edit, or file anything until the user says so (Phase 5).
- Questions from the user are questions. Never edit anything in response to one.
- Output style: extremely concise. No preambles or postambles, bullets over paragraphs, no emojis, no hedging filler. Findings need enough detail to be interrogated; keep prose tight.

## Phase 0: Gather context (parallelize all of it)

PR and diff:
- Work repos under `~/code/smarterdx`: prefix every `gh` call with `GH_TOKEN=$(gh auth token --user jack-jennings-sdx)`.
- `gh pr view <n> --json title,body,headRefName,baseRefName,author,files,commits,comments,reviews`
- `gh pr diff <n>`
- `git fetch origin main && git fetch origin pull/<n>/head:pr-<n>`
- Read files with `git show "pr-<n>:path/to/file"`.
- Diff against freshly fetched `origin/main`, never a stale local `main` (stale main makes unrelated files look changed): `git diff origin/main...pr-<n> --stat`.

Ticket, epic, design:
- Jira via Atlassian MCP: `getAccessibleAtlassianResources` once for cloudId, then `getJiraIssue` (ticket, epic, sibling/blocking/blocked tickets), `searchJiraIssuesUsingJql` for epic children.
- TDD/design doc linked from the epic: Notion `notion-fetch`. Large pages are saved to a file with lines too long for Read. Slice the saved text with python by character range or heading, and read the relevant phase/section fully.

Contract-defining sources outside the repo:
- Find backend/agent repo PRs tied to the work and the CURRENT code on that repo's main: `gh api repos/<org>/<repo>/contents/<path> --jq .content | base64 -d`; `gh api "repos/<org>/<repo>/commits?path=<path>"`; `gh pr list -R <org>/<repo> --state merged`.
- LESSON: ticket text and PR descriptions go stale. In the reference review the backend changed one day before the last commit (saved once per section -> once after all sections), so a per-section event no longer meant "saved" and the UI hand-over trigger raced the save. This was the most serious finding and was found only by reading the backend's latest merged PRs and current main. Always check recent merged changes in producer and consumer repos for contract drift.

CI:
- `gh pr checks <n>`. For failures, pull failed-step logs (`gh run view <id> --log-failed`) and classify each as caused-by-PR or infrastructure/flaky.
- Report both facts when relevant (e.g. E2E shards all failed on a seeding timeout = infra, but the refactored paths never ran under E2E).

Repo conventions:
- Read `AGENTS.md`, `libs/AGENTS.md` (or similar), and Nx tags / module-boundary config before judging layering claims.

## Phase 1: Triage

- Read all changed source, not just the diff stat. Classify each changed area: new code, refactor of existing code, tests, wiring.
- List candidates in four buckets: correctness bugs, contract/ticket deviations, duplication of existing code, unidiomatic patterns.
- For every candidate record: file:line, mechanism, who is affected, and "introduced by this PR?" Answer by comparing the same function on `origin/main` vs `pr-<n>`.
- Compare against precedent: how do sibling implementations (other note types, other features) handle the same state?
  - No sibling handles it gracefully: say so; usually downgrades the finding.
  - A sibling does: name the file to copy.

## Phase 2: Verify each candidate with its own subagent BEFORE presenting

LESSON: about 40% of initial findings fell apart on investigation. Examples: a "duplicate" was intentional per the design doc; a "leftover hand-rolled stream" was a separate deprecated path; a "perf problem" was negligible because the editor was a plain text span; a "stream then vanish" mismatch did not exist because the backend persisted the same text. Do not present unverified candidates.

Spawn one Agent subagent per candidate, all in parallel in a single message. Subagents are read-only. Each prompt must be self-contained: repo, PR number, local ref (`pr-<n>`), the claim, file:line, and where the ticket/TDD/backend sources are. Ask it to try to REFUTE the claim.

Prompt template:

```
You are verifying one claim from an adversarial review of <org>/<repo> PR <n> (local ref pr-<n>; compare against a freshly fetched origin/main). Read-only: do not edit, post, or commit anything.

Claim: <one-sentence claim>
Location: <file:line on pr-<n>>
Context sources: ticket <KEY> (<summary>), epic <KEY>, TDD <url or saved file path>, backend repo <org>/<repo> (check current main and recent merged PRs).

Try to REFUTE the claim. Report a verdict: CONFIRMED, WEAKENED (state the narrower true claim), or REFUTED. Give evidence: file:line, quoted code, commands run. Answer:
1. Introduced by this PR or pre-existing? (diff the same code against origin/main)
2. Intentional per code comments, ticket, TDD phases, or repo conventions?
3. How do sibling implementations handle it?
4. Does current producer/consumer code in other repos change the picture?
5. Covered or contradicted by existing tests? Would the PR's own tests catch it?
6. Concrete failure scenario: inputs, observable wrong outcome. Reachable today (feature flags, missing triggers)?
7. Severity (blocking / non-blocking / nit) and recommended action.
Say explicitly what you did not verify.
```

After results:
- Only CONFIRMED and WEAKENED go forward (use the narrowed claim for WEAKENED).
- Keep REFUTED ones for a one-line "checked and fine" list.
- If a refutation changes the story elsewhere, correct the earlier claims explicitly and say so.

## Phase 3: Summary

Present a short ranked list, surviving findings only, most severe first. One line each: location and consequence. Group as:
- Bugs
- Ticket/contract deviations
- Duplication / idiom

Then: "Checked and fine" (one line each) and open questions needing a human decision. Post nothing, edit nothing.

## Phase 4: Walk through findings one at a time

Present "Finding N of M" with:
- Location
- How it works
- When it fires and when it does not
- Evidence checked (name the data actually read)
- Introduced by this PR? (yes/no, with the comparison)
- Caveats and what was not verified
- Recommended action

Then STOP. Let the user interrogate.
- Answer follow-ups with fresh evidence from code. "How do other note types handle this?" means go read them.
- Do not use AskUserQuestion for the per-finding decision. The user wants plain chat.
- Move to the next finding only when the user says to.
- If investigation shows a finding is weaker than claimed, say so plainly and revise the recommendation. Do not defend it.
- If the user says skip or ignore, drop it without argument and move on.

## Phase 5: Execute only what the user decides, per finding

Outward-facing actions need explicit instruction.

PR comments:
- Inline (line in the diff): `gh api repos/<org>/<repo>/pulls/<n>/comments -X POST -f commit_id=<head sha> -f path=<file> -F line=<n> -f side=RIGHT -f body=...`
- Range: add `-F start_line=<m> -f start_side=RIGHT`.
- Unchanged line in a changed file: `-f subject_type=file` (file-level comment).
- General note: `gh pr comment <n> --body-file <file>`.
- First line marks "Blocking" or "Non-blocking". Keep short and concrete: what happens, why, suggested fix.
- Gloss any ticket number with a short description. Never a bare `NW-1234` in prose.

Jira (Atlassian MCP):
- Create with `createJiraIssue`: same epic via `parent`, sentence-case title with no conventional-commit prefix, description as markdown with REAL newlines (no escaped `\n` text).
- Link with `executeWrite` name `createJiraIssueLink`, linkType `Blocks`: `inwardIssue` blocks `outwardIssue`. "New ticket is blocked by X" = inwardIssue X, outwardIssue new.
- Before editing an existing ticket, RE-FETCH it immediately before writing (others edit concurrently). `editJiraIssue` replaces the whole description: resend it in full and change only the targeted sentences.

Notion:
- Re-fetch immediately before writing. Use `notion-update-page` with `update_content` and minimal exact `old_str` replacements. Re-fetch and verify afterward.
- When a finding proves ticket or TDD contract wording wrong, update that wording.

Stacked / follow-up PRs:
- `git start <ticket-id>` (never `git checkout -b` / `git switch -c`); it creates `<username>/<ticket-id>`.
- Work in a worktree off the PR head so the user's checkout is untouched: `git worktree add --detach <path> pr-<n>`, then run `git start` inside it.
- Worktrees have no node_modules. Make `node_modules` a real directory of symlinks to each top-level entry of the main checkout's `node_modules`, EXCEPT `node_modules/@sdx/local-workspaces`, which must symlink to the worktree's own `../../tools/vitest`. A whole-directory symlink makes vitest resolve setup files into the main checkout and fail.
- Test: `NX_DAEMON=false npx nx test <project> --skip-nx-cache`. Run prettier on changed files. Commit, push the branch.
- Open: `gh pr create --draft --assignee @me --base <original PR head branch>`. Always draft. Body follows `.github/pull_request_template.md`. Title: sentence case, no Jira key, no conventional-commit type. Jira key only in body references.
- Then comment on the original PR linking the new one.

## Phase 6: Close

End with a compact table:

| # | Finding (one line) | Outcome |
|---|--------------------|---------|
| 1 | ... | comment posted / ticket filed / dropped / skipped |

Below it: what remains for the PR author, and open product questions recorded (where).

## Gotchas

- zsh treats `$VAR:path` as a modifier. Write `"pr-741:path/to/file"` or `${B}:path`.
- `echo =====` errors in zsh. Quote it.
- Notion `fetch` of long pages errors with a file path. Read it with python slicing, not Read offset/limit.
- Inline PR comments attach only to lines in the diff. Use file-level for others.
- Jira description edits replace the whole field. Re-fetch first.
- Stale local `main` produces phantom changes. Fetch `origin/main` first.
- If `git start` misbehaves, check `git config --get alias.start` and `~/.config/git/bin/git-start`.
