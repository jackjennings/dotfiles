---
name: recording-feature-demos
description: Use when asked to record a screen capture, demo, or video of a UI feature/PR/bug with agent-browser — especially when the capture itself needs to run as one smooth take instead of pausing for reasoning between every click
---

# Recording Feature Demos

## Overview

Recording has two phases with opposite needs: **investigation** (uncertain,
needs reasoning, one command at a time) and **capture** (sequence is now
known — must run as a single uninterrupted take). Interleaving reasoning
into the capture phase produces slow, jerky, expensive-to-produce videos.
Separate them: investigate and plan first, execute the whole capture in
one Bash call.

## The Shape

1. **Locate & launch** — find the code/PR for the feature, start it running
   (e.g. this project's `run` skill / a dev server / a worktree). Note any
   feature flag that gates the feature.
2. **Investigate interactively** — open the app with `agent-browser`,
   snapshot, click around to find: the exact route/URL, any flag that must
   be forced on, and **stable selectors** (`aria-label`, `data-test-id`,
   `find role/text/testid`). Do NOT plan to reuse `@eN` refs inside the
   capture script — they die the instant the page changes, and a capture
   script changes the page many times with no snapshot in between to
   refresh them.

   **The page you land on is usually not the feature.** Opening an app's
   default/dev URL typically lands on a generic default view, not the
   feature you're asked to record. Screenshot and confirm the actual
   target UI is visible — by name, not just "a page loaded" — before
   writing the plan. If it's behind a feature flag, find and use this
   project's mechanism for forcing it locally (env config, local override
   file, etc.) rather than recording whatever loaded by default.
3. **Write the plan as a shell script** (e.g. `/tmp/<feature>-recording.sh`)
   containing every `agent-browser` command in order — see
   `record-plan.sh.template`. Output to `/tmp/<feature>-demo.mp4` —
   despite `record start --help` saying `<path.webm>`, the output
   container/codec actually follows the file extension you pass; `.mp4`
   produces a real h264 MP4, more broadly playable/shareable than WebM.
   The script MUST call `record start` immediately followed by
   `agent-browser set viewport 1920 1080 2` (or similar) before any
   interaction — agent-browser's default headless viewport is a
   non-standard 1280×577, which produces a squished/wrong-aspect-ratio
   recording if this is skipped. Chain values with shell, not reasoning:
   pull a bounding box into a var with `get box --json | jq`, feed it to
   the next `mouse move`, instead of reading CLI output yourself and
   deciding the next command.
4. **Execute the script in one Bash call.** No snapshot/click/wait tool
   calls interleaved with your own reasoning during capture — the script
   already resolved all of that.
5. **Verify & clean up** — `ls -la` + `file` on the output, revert any
   temporary feature-flag/env overrides, close the browser session.

## Quick Reference

| Gotcha | Fix |
|---|---|
| `record start` opens a **fresh browser context** | Set viewport/scale *after* `record start`, not before |
| `get box --json` nests under `.data` (`{"success","data":{"x",...},"error"}`) | Use `.data.x`, not `.x` — a bare `.x` silently returns `null` and breaks downstream arithmetic |
| Fixed `wait <ms>` guesses wrong under load | Prefer `wait "<selector>"` (condition-based) before reading that element's box/text |
| `@eN` refs from the investigation phase | Don't hardcode them into the script — use `find role/text/testid` or a CSS attribute selector instead |
| Low-res/blurry/squished capture | Step 3 requires `set viewport` right after `record start` — don't skip it. `1920 1080 2` (third arg = deviceScaleFactor; `2` = retina-sharp) |
| App behind a staging/VPN-gated backend won't load (blank page, DNS errors) | Check VPN/network before assuming the app or your script is broken |

## Template

`record-plan.sh.template` in this skill directory — copy it, fill in the
URL/selectors/actions found during investigation, `chmod +x`, run once.
