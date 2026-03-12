# v0.1.0

Initial public release of **openclaw-workspace-doctor**.

## What it does
- Audits an OpenClaw workspace
- Detects missing core files
- Flags placeholder configs that were never filled in
- Checks installed skills for missing `SKILL.md`

## Why it exists
OpenClaw workspaces are easy to start and easy to drift. This tool gives maintainers a fast way to catch common setup mistakes before they turn into confusing agent behavior.

## Next up
- JSON output mode
- More detailed heartbeat/task checks
- Example CI usage for scheduled audits
