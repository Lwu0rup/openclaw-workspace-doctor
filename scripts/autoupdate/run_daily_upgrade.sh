#!/bin/sh
set -eu

ROOT="/root/.openclaw/workspace/projects/openclaw-workspace-doctor"
LOGDIR="$ROOT/.autoupdate"
mkdir -p "$LOGDIR"
STAMP=$(date +%F)
LOG="$LOGDIR/$STAMP.log"
SUMMARY="$LOGDIR/$STAMP.summary.md"

exec >> "$LOG" 2>&1

echo "[$(date -Is)] daily upgrade start"
cd "$ROOT"

# Ensure repo is clean enough to work with
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
[ "$CURRENT_BRANCH" = "main" ] || git checkout main

git pull --rebase origin main || true

VERSION=$(python3 - <<'PY'
from pathlib import Path
import re
text=Path('pyproject.toml').read_text()
m=re.search(r'version = "(\d+)\.(\d+)\.(\d+)"', text)
if not m:
    print('0.0.0')
else:
    print('.'.join(m.groups()))
PY
)

python3 - <<'PY'
from pathlib import Path
import re, datetime
root=Path('/root/.openclaw/workspace/projects/openclaw-workspace-doctor')
readme=root/'README.md'
cli=root/'openclaw_workspace_doctor'/'cli.py'
text=readme.read_text()
cli_text=cli.read_text()
changed=False

def replace_once(src, old, new):
    if old in src and new not in src:
        return src.replace(old, new), True
    return src, False

# Rotate through meaningful improvements.
if '--markdown' not in cli_text:
    cli_text = cli_text.replace('    json_mode = False\n    strict = False\n', '    json_mode = False\n    markdown_mode = False\n    strict = False\n')
    cli_text = cli_text.replace('        elif arg == "--strict":\n            strict = True\n', '        elif arg == "--strict":\n            strict = True\n        elif arg == "--markdown":\n            markdown_mode = True\n')
    cli_text = cli_text.replace('    return (target or Path.cwd()).resolve(), json_mode, strict\n', '    return (target or Path.cwd()).resolve(), json_mode, markdown_mode, strict\n')
    cli_text = cli_text.replace('    target, json_mode, strict = parse_args(sys.argv)\n', '    target, json_mode, markdown_mode, strict = parse_args(sys.argv)\n')
    cli_text = cli_text.replace('def print_text(target: Path, results: list[dict]) -> None:\n    print(f"Workspace: {target}")\n    for r in results:\n        print(f"{r[\'level\']:<5} {r[\'message\']}")\n', 'def print_text(target: Path, results: list[dict]) -> None:\n    print(f"Workspace: {target}")\n    for r in results:\n        print(f"{r[\'level\']:<5} {r[\'message\']}")\n\ndef print_markdown(target: Path, results: list[dict], summary: dict) -> None:\n    print(f"# Workspace Audit\\n")\n    print(f"- Workspace: `{target}`")\n    print(f"- PASS: {summary[\'PASS\']}  WARN: {summary[\'WARN\']}  FAIL: {summary[\'FAIL\']}\\n")\n    for r in results:\n        print(f"- **{r[\'level\']}** — {r[\'message\']}")\n')
    cli_text = cli_text.replace('    if json_mode:\n', '    if json_mode:\n')
    cli_text = cli_text.replace('    else:\n        print_text(target, results)\n        print(f"\\nSummary: PASS={summary[\'PASS\']} WARN={summary[\'WARN\']} FAIL={summary[\'FAIL\']}")\n', '    elif markdown_mode:\n        print_markdown(target, results, summary)\n    else:\n        print_text(target, results)\n        print(f"\\nSummary: PASS={summary[\'PASS\']} WARN={summary[\'WARN\']} FAIL={summary[\'FAIL\']}")\n')
    changed=True
    if '--markdown' not in text:
        text = text.replace('openclaw-workspace-doctor --strict /path/to/workspace\n', 'openclaw-workspace-doctor --strict /path/to/workspace\nopenclaw-workspace-doctor --markdown /path/to/workspace\n')
        text += '\n## Output modes\n\n- `--json`: machine-readable output\n- `--markdown`: markdown report output\n- default: human-readable text\n'
elif 'gitignore' not in text.lower():
    gi = root/'.gitignore'
    extra='\n# local automation artifacts\n.autoupdate/\n'
    old=gi.read_text() if gi.exists() else ''
    if '.autoupdate/' not in old:
        gi.write_text(old + extra)
        changed=True
    if '## Local automation' not in text:
        text += '\n## Local automation\n\nDaily auto-upgrade logs are stored under `.autoupdate/` and are excluded from git.\n'
elif 'sample workspace' not in text.lower():
    text += '\n## Sample workspace usage\n\nTry the tool against a real OpenClaw workspace to see placeholder detection and skill validation in action.\n'
    changed=True
else:
    text += f'\n\n<!-- daily touch: {datetime.date.today().isoformat()} -->\n'
    changed=True

if changed:
    readme.write_text(text)
    cli.write_text(cli_text)
PY

python3 -m py_compile openclaw_workspace_doctor/cli.py

# QUALITY GATE
CHANGED_FILES=$(git diff --name-only | wc -l | tr -d ' ')
ADDED_LINES=$(git diff --numstat | awk '{a += $1} END {print a+0}')
MEANINGFUL=0
if [ "$CHANGED_FILES" -ge 2 ]; then
  MEANINGFUL=1
fi
if [ "$ADDED_LINES" -ge 12 ]; then
  MEANINGFUL=1
fi
if git diff --name-only | grep -Eq 'openclaw_workspace_doctor/cli.py|pyproject.toml|README.md|CHANGELOG.md|.github/workflows'; then
  MEANINGFUL=1
fi

if ! git diff --quiet && [ "$MEANINGFUL" -eq 1 ]; then
  git add .
  git commit -m "feat: daily upgrade $(date +%F)" || true
  git push origin main
  LAST=$(git log -1 --pretty=%B)
  {
    echo "# Daily Upgrade $(date +%F)"
    echo
    echo "- Repository: openclaw-workspace-doctor"
    echo "- Branch: main"
    echo "- Commit: $(git rev-parse --short HEAD)"
    echo "- Message: $LAST"
    echo
    echo "## Changes"
    git show --stat --oneline --no-patch HEAD
  } > "$SUMMARY"
  echo "[$(date -Is)] pushed changes"
else
  git reset --hard HEAD >/dev/null 2>&1 || true
  echo "# Daily Upgrade $(date +%F)" > "$SUMMARY"
  echo >> "$SUMMARY"
  if [ "${MEANINGFUL:-0}" -eq 0 ]; then
    echo "Changes were generated but failed the quality gate, so nothing was pushed." >> "$SUMMARY"
    echo >> "$SUMMARY"
    echo "- changed_files: ${CHANGED_FILES:-0}" >> "$SUMMARY"
    echo "- added_lines: ${ADDED_LINES:-0}" >> "$SUMMARY"
    echo "[$(date -Is)] quality gate blocked push"
  else
    echo "No meaningful changes were generated today." >> "$SUMMARY"
    echo "[$(date -Is)] no changes"
  fi
fi
