---
name: stuck-recovery
description: Use when encountering the same error 3+ times, reverting changes repeatedly, or trying minor variations of a failed approach — before attempting another fix
---

# Stuck Recovery

## Triggers

STOP immediately if any of these are true:
- Same error 3+ times
- Reverting changes
- Minor variations of a failed approach

## On Detection

1. State attempts and outcomes
2. Propose alternatives or ask for direction
3. Wait for user before proceeding

## Prevention (interactive sessions only)

- Multi-step changes: bullet plan first, wait for "OK"
- After 15+ tool calls: checkpoint with user

## Exception

Scripted runs (`claude -p`) complete autonomously per the provided prompt.
