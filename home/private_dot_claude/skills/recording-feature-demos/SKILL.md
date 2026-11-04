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
   The script MUST call `agent-browser set viewport 1440 900 2` (or
   similar) BEFORE `record start`. `record start` records the already-open
   page as-is (no new context) and fixes the frame size to the viewport at
   that moment. agent-browser's default headless viewport is a
   non-standard 1280×577; setting the viewport after `record start`
   leaves the video at 1280×578 and scales the page into it, which
   squishes it. Note the output is viewport × deviceScaleFactor (1440×900
   at `2` gives 2880×1800). Chain values with shell, not reasoning:
   pull a bounding box into a var with `get box --json | jq`, feed it to
   the next `mouse move`, instead of reading CLI output yourself and
   deciding the next command.
4. **Execute the script in one Bash call.** No snapshot/click/wait tool
   calls interleaved with your own reasoning during capture — the script
   already resolved all of that.
5. **Verify & clean up** — `ls -la` + `file` on the output, and
   `ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0`
   to confirm the aspect ratio matches the viewport (extract a frame with
   `ffmpeg -sseof -2 -i out.mp4 -frames:v 1 f.png` and look at it). Revert any
   temporary feature-flag/env overrides, close the browser session.

## PHI Blur

If the data is not confirmed synthetic, blur patient text in the live page
so it never reaches the video. Selectors are per project; for impression-ui:
`imp-discharge-summary-editor-on-demand, imp-problem-list,
imp-ds-on-demand-citations, imp-suggested-diagnoses-section`.

1. After `record start`, inject a style (page-only: never committed, lost on
   reload). Time it with `date +%s.%N` before and after:

   ```bash
   agent-browser eval "if(!document.getElementById('phi-blur')){const s=document.createElement('style');s.id='phi-blur';s.textContent='<selectors>{filter:blur(7px)!important}';document.head.appendChild(s)};1"
   ```
2. Take screenshots only after injecting.
3. Trim the unblurred lead-in (`<t>` = seconds from `record start` to the
   end of injection):
   `ffmpeg -ss <t> -i raw.mp4 -c:v libx264 -pix_fmt yuv420p -an out.mp4`
4. Verify: view a contact sheet
   (`ffmpeg -i out.mp4 -vf "fps=1,scale=800:-1,tile=3x6" -frames:v 1 sheet.png`),
   the first frame, and every screenshot. Confirm no patient text is readable.

## Quick Reference

| Gotcha | Fix |
|---|---|
| `record start` fixes the frame size to the viewport at that moment (it does not open a new context) | Set viewport/scale *before* `record start`; changing it afterward squishes the video |
| Need a mobile/other aspect ratio | Aspect comes from the viewport, not the format; `.mp4` handles any ratio. Use e.g. `set viewport 390 844 2` (→ 780×1688) before `record start`. Keep width/height even (or scale ≥2): H.264 rounds odd sizes up and slightly stretches. `set device <name>` (mobile UA/touch) is untested with recording |
| `agent-browser close` as the first step of a script can leave the daemon unreachable ("Failed to connect") | Don't close/reopen at script start; reuse the running session |
| `get box --json` nests under `.data` (`{"success","data":{"x",...},"error"}`) | Use `.data.x`, not `.x` — a bare `.x` silently returns `null` and breaks downstream arithmetic |
| Fixed `wait <ms>` guesses wrong under load | Prefer `wait "<selector>"` (condition-based) before reading that element's box/text |
| `@eN` refs from the investigation phase | Don't hardcode them into the script — use `find role/text/testid` or a CSS attribute selector instead |
| Low-res/blurry/squished capture | Step 3 requires `set viewport` before `record start` — don't skip it. `1440 900 2` (third arg = deviceScaleFactor; `2` = retina-sharp). Verify with `ffprobe` |
| App behind a staging/VPN-gated backend won't load (blank page, DNS errors) | Check VPN/network before assuming the app or your script is broken |

## Template

`record-plan.sh.template` in this skill directory — copy it, fill in the
URL/selectors/actions found during investigation, `chmod +x`, run once.
