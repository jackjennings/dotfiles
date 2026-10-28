---
name: adversarial-pr-review
description: Interactive, adversarial, ticket-aware review of a GitHub PR, walked through finding by finding with the user. Use when pointed at any PR and asked for an "adversarial review" or a "go deep" review, or to review a PR against its ticket, epic, and design doc. Differs from the built-in code-review skill - it reads ticket/epic/design/producer-consumer context, verifies every candidate finding with a refutation subagent before presenting, then discusses findings one at a time and acts only on the user's decisions. Hard gates: no finding is presented without a subagent verdict, and findings are presented one per message, never as a list.
---

# Adversarial PR review

Goal: find issues introduced by the PR (critical bugs, ticket/contract deviations, duplication of existing code, unidiomatic patterns). Verify before presenting. Discuss one finding at a time. Act only when told.

Works on any repo. Take project-specific conventions (accounts, branch helpers, PR rules, test commands) from that project's `CLAUDE.md` / `AGENTS.md`, not from assumptions.

Typical request: "Perform an adversarial review of <PR url>. Look at the associated ticket, epic, and design doc. Look for unidiomatic patterns, duplicated code, critical bugs. Go deep."

## Rules

HARD GATES (not negotiable):
- No candidate is presented without a verdict from its own refutation subagent (Phase 2). Your own reading does not count, however obvious the finding looks. About 40% of candidates were refuted on investigation.
- Never present more than one finding with detail per message. No findings list, no previews of later findings. After each finding, stop and wait for the user (Phase 4).

Red flags that mean you are about to violate a gate:

| Thought | Reality |
|---------|---------|
| "This one is obviously real" | Obvious ones were refuted too. Spawn the agent. |
| "I already read the code" | You are anchored on your claim. The agent tries to refute it. |
| "Too many agents" | One per candidate is the requirement. |
| "A short list is more efficient" | The user interrogates one finding at a time. Present one. |
| "I'll show the rest so they have context" | Do not mention later findings until the user advances. |

Other rules:
- Only report issues introduced by the PR. Pre-existing quirks the PR moves or consolidates are dropped (at most one cleanup-idea line).
- Never claim "verified" unless data was read. State what was not verified.
- Do not post, edit, or file anything until the user says so (Phase 5).
- Questions from the user are questions. Never edit anything in response to one.
- Output style: extremely concise. No preambles or postambles, bullets over paragraphs, no emojis, no hedging filler. Findings need enough detail to be interrogated; keep prose tight.

## Phase 0: Gather context (parallelize all of it)

PR and diff:
- If the project's instructions name a specific `gh` account or token, use it on every `gh` call.
- `gh pr view <n> --json title,body,headRefName,baseRefName,author,files,commits,comments,reviews`
- `gh pr diff <n>`
- `git fetch origin <base> && git fetch origin pull/<n>/head:pr-<n>` (base is usually `main`).
- Read files with `git show "pr-<n>:path/to/file"`.
- Diff against the freshly fetched `origin/<base>`, never a stale local branch (a stale base makes unrelated files look changed): `git diff origin/<base>...pr-<n> --stat`.

Ticket, epic, design:
- Find the ticket from the PR body, branch name, and commit messages. Read it, its parent epic, and sibling/blocking/blocked tickets with whatever tracker tooling is available (Jira/Linear MCP tools, `gh issue view`, etc.).
- Find the design doc or spec linked from the ticket or epic (Notion, Confluence, Google Docs, in-repo docs). Read the section covering this work fully.
- If a fetch result is too large and gets saved to a file with very long lines, slice it with python by character range or heading rather than Read offset/limit.

Contract-defining sources outside the repo:
- Identify producers and consumers of anything the PR depends on (backend/agent services, shared libraries, other repos). Find their PRs tied to this work and the CURRENT code on their default branch: `gh api repos/<org>/<repo>/contents/<path> --jq .content | base64 -d`; `gh api "repos/<org>/<repo>/commits?path=<path>"`; `gh pr list -R <org>/<repo> --state merged`.
- LESSON: ticket text and PR descriptions go stale. In a reference review, a backend changed one day before the PR's last commit (it moved from saving per item to saving once after all items), so a per-item event no longer meant "saved" and the client's trigger raced the write. That was the most serious finding and was found only by reading the producer's latest merged PRs and current code. Always check recent merged changes in producer and consumer repos for contract drift.

CI:
- `gh pr checks <n>`. For failures, pull failed-step logs (`gh run view <id> --log-failed`) and classify each as caused-by-PR or infrastructure/flaky.
- Report both facts when relevant (e.g. every E2E shard failed on a setup timeout = infra, but the refactored paths never ran under E2E).

Repo conventions:
- Read `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING`, and lint / module-boundary / dependency-rule config before judging layering or idiom claims.

## Phase 1: Triage

- Read all changed source, not just the diff stat. Classify each changed area: new code, refactor of existing code, tests, wiring.
- List candidates in four buckets: correctness bugs, contract/ticket deviations, duplication of existing code, unidiomatic patterns.
- For every candidate record: file:line, mechanism, who is affected, and "introduced by this PR?" Answer by comparing the same code on `origin/<base>` vs `pr-<n>`.
- Compare against precedent: how do sibling implementations (similar features, other modules of the same kind) handle the same state?
  - No sibling handles it gracefully: say so; usually downgrades the finding.
  - A sibling does: name the file to copy.

GATE: Do not present any candidate to the user yet. Go to Phase 2.

## Phase 2: Verify each candidate with its own subagent BEFORE presenting

LESSON: about 40% of initial findings fell apart on investigation. Examples: a "duplicate" was intentional per the design doc; a "leftover hand-rolled helper" was a separate deprecated path; a "perf problem" was negligible because rendering was a single text node; a "content vanishes" mismatch did not exist because the producer persisted the same text. Do not present unverified candidates.

First write a verification ledger in chat: `candidate | agent | verdict`, one row per candidate, verdicts blank.

Then spawn one Agent subagent per candidate, ALL in parallel in a single message (N candidates = N Agent calls in one block). Subagents are read-only. Self-verification does not substitute for a subagent, even for a candidate that looks certain. Each prompt must be self-contained: repo, PR number, local ref (`pr-<n>`), the claim, file:line, and where the ticket/design/producer sources are. Ask it to try to REFUTE the claim.

Prompt template:

```
You are verifying one claim from an adversarial review of <org>/<repo> PR <n> (local ref pr-<n>; compare against a freshly fetched origin/<base>). Read-only: do not edit, post, or commit anything.

Claim: <one-sentence claim>
Location: <file:line on pr-<n>>
Context sources: ticket <KEY> (<summary>), epic <KEY>, design doc <url or saved file path>, producer/consumer repo <org>/<repo> (check current default branch and recent merged PRs).

Try to REFUTE the claim. Report a verdict: CONFIRMED, WEAKENED (state the narrower true claim), or REFUTED. Give evidence: file:line, quoted code, commands run. Answer:
1. Introduced by this PR or pre-existing? (diff the same code against origin/<base>)
2. Intentional per code comments, ticket, design doc, or repo conventions?
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

Wait for every subagent to report before ending your turn or writing anything user-facing.

GATE: Do not start Phase 3 until every ledger row has a verdict from a subagent. A blank row means stop and spawn it.

## Phase 3: Handoff (no list)

Output one line only: "N candidates, M confirmed/weakened, K refuted." Optionally add numbered titles (no mechanism, no consequence). Do not repeat the ledger; the count line replaces it.

Rank survivors by the subagent's severity: blocking first, then non-blocking, then nit. Within a severity, CONFIRMED above WEAKENED, then bugs, ticket/contract deviations, duplication/idiom. Go straight to Finding 1 of M in the same message.

Do not present the full summary, mechanisms, or the "checked and fine" list here; those go in Phase 6. Track the walk-through with one task per surviving finding if a task tool is available (e.g. TaskCreate); otherwise keep the numbered list as the tracker.

## Phase 4: Walk through findings one at a time

Each message contains exactly one finding. Present "Finding N of M" with:
- Location
- How it works
- When it fires and when it does not
- Evidence checked (name the data actually read)
- Introduced by this PR? (yes/no, with the comparison)
- Caveats and what was not verified
- Recommended action

End with a plain-chat prompt: "Comment / ticket / drop / question?" Then STOP. Do not mention or preview later findings. Let the user interrogate.
- Answer follow-ups with fresh evidence from code. "How do other modules handle this?" means go read them.
- Do not use AskUserQuestion for the per-finding decision. The user wants plain chat.
- Move to the next finding only when the user says to; mark the finding done in the tracker then.
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
- Gloss any ticket number with a short description and link it to the tracker (never a bare `ABC-1234` in prose). Edit an already-posted comment with `gh api .../pulls/comments/<id> -X PATCH -f body=...`.

Tickets (use the tracker tooling available; the Jira specifics below apply if the project uses Jira):
- Create in the same epic/parent as the PR's ticket, sentence-case title with no conventional-commit prefix, description as markdown with REAL newlines (no escaped `\n` text).
- Jira link semantics: link type `Blocks`, `inwardIssue` blocks `outwardIssue`. "New ticket is blocked by X" = inwardIssue X, outwardIssue new.
- Before editing an existing ticket, RE-FETCH it immediately before writing (others edit concurrently). Jira description edits replace the whole field: resend it in full and change only the targeted sentences.
- Link every ticket key mentioned in descriptions you write or edit.

Design docs (Notion, Confluence, etc.):
- Re-fetch immediately before writing. Make minimal exact-string replacements, not full rewrites. Re-fetch and verify afterward.
- When a finding proves ticket or design-doc contract wording wrong, update that wording.

Stacked / follow-up PRs:
- Create the branch the way the project's instructions prescribe (e.g. a documented branch helper keyed on the ticket id); otherwise a descriptive branch off the PR head.
- Work in a worktree off the PR head so the user's checkout is untouched: `git worktree add --detach <path> pr-<n>`.
- Worktrees lack untracked dependencies. Link or install `node_modules` (or the language equivalent). If the project resolves workspace packages through symlinks inside the dependency directory, rebase those links to the worktree; a whole-directory symlink to the main checkout can make tooling resolve files back into the main checkout and fail.
- Run the project's test target for the affected package, run the formatter on changed files, commit, push the branch.
- Open with `gh pr create --draft --base <original PR head branch>`, plus any assignee/label rules from the project's instructions. Always draft. Body follows the repo's PR template if one exists. Title: sentence case, no ticket key, no conventional-commit type; the ticket key goes in the body references.
- Then comment on the original PR linking the new one.

## Phase 6: Close

Present the full summary here for the first time: the table below, then "Checked and fine" (one line per refuted candidate) and open questions needing a human decision. End with a compact table:

| # | Finding (one line) | Outcome |
|---|--------------------|---------|
| 1 | ... | comment posted / ticket filed / dropped / skipped |

Below it: what remains for the PR author, and open product questions recorded (where).

## Gotchas

- zsh treats `$VAR:path` as a modifier. Write `"pr-<n>:path/to/file"` or `${VAR}:path`.
- `echo =====` errors in zsh. Quote it.
- Inline PR comments attach only to lines in the diff. Use file-level for others.
- Ticket description edits usually replace the whole field. Re-fetch first.
- A stale local base branch produces phantom changes. Fetch `origin/<base>` first.
