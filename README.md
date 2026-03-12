# openclaw-workspace-doctor

[![CI](https://github.com/Lwu0rup/openclaw-workspace-doctor/actions/workflows/python-check.yml/badge.svg)](https://github.com/Lwu0rup/openclaw-workspace-doctor/actions/workflows/python-check.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Python](https://img.shields.io/badge/python-3.10%2B-blue)](./pyproject.toml)

A small CLI that audits an OpenClaw workspace and reports common setup issues.

## What it checks

- Required core files: `AGENTS.md`, `SOUL.md`, `USER.md`
- Presence of `HEARTBEAT.md`
- Presence of `skills/` and `tasks/QUEUE.md`
- Whether installed skills contain `SKILL.md`
- Whether heartbeat/task queue are still template placeholders
- Basic memory directory presence

## Install

```bash
pip install .
```

## Usage

```bash
openclaw-workspace-doctor /path/to/workspace
openclaw-workspace-doctor --json /path/to/workspace
openclaw-workspace-doctor --strict /path/to/workspace
openclaw-workspace-doctor --markdown /path/to/workspace
openclaw-workspace-doctor --summary-only /path/to/workspace
```

If no path is given, it uses the current directory.

## Example output

```text
Workspace: /root/.openclaw/workspace
PASS  AGENTS.md found
PASS  SOUL.md found
WARN  USER.md is still empty template
PASS  HEARTBEAT.md found
WARN  tasks/QUEUE.md still contains placeholders
PASS  skills/self-improving/SKILL.md found
```

## Why this exists

OpenClaw workspaces are easy to get running, but they drift. This tool gives a quick sanity check so maintainers can catch missing files, placeholder configs, and half-installed skills.

## License

MIT



## Demo

```text
$ openclaw-workspace-doctor /root/.openclaw/workspace
Workspace: /root/.openclaw/workspace
PASS  AGENTS.md found
PASS  SOUL.md found
PASS  USER.md found
PASS  HEARTBEAT.md found
WARN  USER.md still looks like the default template
WARN  tasks/QUEUE.md still contains template placeholders
PASS  skills/self-improving/SKILL.md found
```

## Why someone would star this

- Useful for anyone running OpenClaw in a real workspace
- Turns fuzzy setup mistakes into concrete audit output
- Small, readable, hackable utility instead of a big framework
- Easy place to contribute more checks for the ecosystem

## Roadmap

- [ ] Add JSON output mode
- [ ] Add exit-code profiles for CI usage
- [ ] Add checks for empty placeholder files
- [ ] Add tests with sample workspaces
- [ ] Add GitHub Action example for scheduled workspace audits

## Positioning

This project is intentionally narrow: it does one thing well—sanity-check an OpenClaw workspace.
That makes it easy to adopt, easy to review, and easy to extend.

## Exit codes

- `0`: no failures (warnings allowed unless `--strict`)
- `1`: warnings present in `--strict` mode
- `2`: one or more hard failures

## Output modes

- `--json`: machine-readable output
- `--markdown`: markdown report output
- default: human-readable text
