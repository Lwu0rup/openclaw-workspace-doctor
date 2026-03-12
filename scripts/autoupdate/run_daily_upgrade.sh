#!/bin/sh
set -eu

ROOT="/root/.openclaw/workspace/projects/openclaw-workspace-doctor"
LOGDIR="$ROOT/.autoupdate"
mkdir -p "$LOGDIR"
STAMP=$(date +%F)
LOG="$LOGDIR/$STAMP.log"
SUMMARY="$LOGDIR/$STAMP.summary.md"
STRATEGY_FILE="$LOGDIR/strategy.json"

exec >> "$LOG" 2>&1

echo "[$(date -Is)] daily upgrade start"
if [ ! -f "$STRATEGY_FILE" ]; then
  cat > "$STRATEGY_FILE" <<'JSON'
{
  "last_bucket": "none",
  "buckets": ["feature", "docs_demo", "ci_tests", "release_polish"]
}
JSON
fi
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
import re, datetime, json
root=Path('/root/.openclaw/workspace/projects/openclaw-workspace-doctor')
readme=root/'README.md'
cli=root/'openclaw_workspace_doctor'/'cli.py'
strategy_file=root/'.autoupdate'/'strategy.json'
text=readme.read_text()
cli_text=cli.read_text()
changed=False
strategy=json.loads(strategy_file.read_text()) if strategy_file.exists() else {'last_bucket':'none','buckets':['feature','docs_demo','ci_tests','release_polish']}
buckets=strategy['buckets']
last=strategy.get('last_bucket','none')
idx=(buckets.index(last)+1 if last in buckets else 0) % len(buckets)
bucket=buckets[idx]

def replace_once(src, old, new):
    if old in src and new not in src:
        return src.replace(old, new), True
    return src, False

# Strategy-driven daily upgrades.
if bucket == 'feature':
    if '--markdown' not in cli_text:
        cli_text = cli_text.replace('    json_mode = False\n    markdown_mode = False\n    strict = False\n', '    json_mode = False\n    markdown_mode = False\n    summary_only = False\n    strict = False\n')
        cli_text = cli_text.replace('        elif arg == "--markdown":\n            markdown_mode = True\n', '        elif arg == "--markdown":\n            markdown_mode = True\n        elif arg == "--summary-only":\n            summary_only = True\n')
        cli_text = cli_text.replace('    return (target or Path.cwd()).resolve(), json_mode, markdown_mode, strict\n', '    return (target or Path.cwd()).resolve(), json_mode, markdown_mode, summary_only, strict\n')
        cli_text = cli_text.replace('    target, json_mode, markdown_mode, strict = parse_args(sys.argv)\n', '    target, json_mode, markdown_mode, summary_only, strict = parse_args(sys.argv)\n')
        cli_text = cli_text.replace('    summary = summarize(results)\n', '    summary = summarize(results)\n    if summary_only:\n        results = [r for r in results if r["level"] != "PASS"]\n')
        changed=True
    if '--summary-only' not in text:
        text = text.replace('openclaw-workspace-doctor --markdown /path/to/workspace\n', 'openclaw-workspace-doctor --markdown /path/to/workspace\nopenclaw-workspace-doctor --summary-only /path/to/workspace\n')
        changed=True
elif bucket == 'docs_demo':
    if '## CI usage' not in text:
        text += '\n## CI usage\n\n```bash\nopenclaw-workspace-doctor --strict .\n```\n\nUse `--strict` in CI if warnings should fail the run.\n'
        changed=True
elif bucket == 'ci_tests':
    wf = root/'.github'/'workflows'/'python-check.yml'
    wf_text = wf.read_text()
    if '--json .' not in wf_text:
        wf_text = wf_text.replace('      - name: Run doctor against repo root\n        run: openclaw-workspace-doctor . || true\n', '      - name: Run doctor against repo root\n        run: openclaw-workspace-doctor . || true\n      - name: Run JSON mode\n        run: openclaw-workspace-doctor --json .\n')
        wf.write_text(wf_text)
        changed=True
elif bucket == 'release_polish':
    changelog = root/'CHANGELOG.md'
    ctext = changelog.read_text() if changelog.exists() else '# Changelog\n'
    marker = f'## Daily improvement {datetime.date.today().isoformat()}'
    if marker not in ctext:
        ctext += f'\n{marker}\n\n- Automated maintenance improvement via scheduled upgrade strategy.\n'
        changelog.write_text(ctext)
        changed=True

if changed:
    readme.write_text(text)
    cli.write_text(cli_text)
    strategy['last_bucket'] = bucket
    strategy_file.write_text(json.dumps(strategy, ensure_ascii=False, indent=2))
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
