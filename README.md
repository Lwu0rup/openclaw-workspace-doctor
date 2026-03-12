# openclaw-workspace-doctor

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
