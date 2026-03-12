from __future__ import annotations

import json
import sys
from pathlib import Path

TEMPLATE_HINTS = {
    "USER.md": ["Name:", "What to call them:", "Pronouns:"],
    "tasks/QUEUE.md": ["[Task description]", "@[agent]", "[Idea that might become a task]"],
    "HEARTBEAT.md": ["Keep this file empty", "Idle time = wasted tokens"],
}

SEVERITY_PASS = "PASS"
SEVERITY_WARN = "WARN"
SEVERITY_FAIL = "FAIL"


def exists(path: Path, rel: str) -> bool:
    return (path / rel).exists()


def read_text(path: Path, rel: str) -> str:
    try:
        return (path / rel).read_text(encoding="utf-8")
    except Exception:
        return ""


def looks_like_placeholder(path: Path, rel: str) -> bool:
    text = read_text(path, rel)
    hints = TEMPLATE_HINTS.get(rel, [])
    return any(h in text for h in hints)


def is_effectively_empty_markdown(path: Path, rel: str) -> bool:
    text = read_text(path, rel)
    lines = []
    for line in text.splitlines():
        s = line.strip()
        if not s:
            continue
        if s.startswith("#"):
            continue
        if s.startswith("<!--") and s.endswith("-->"):
            continue
        lines.append(s)
    return len(lines) == 0


def iter_skill_dirs(skills_dir: Path):
    if not skills_dir.exists():
        return []
    return sorted([p for p in skills_dir.iterdir() if p.is_dir()], key=lambda p: p.name)


def record(results: list[dict], level: str, message: str, rel: str | None = None):
    results.append({"level": level, "message": message, "path": rel})


def check_workspace(target: Path) -> list[dict]:
    results: list[dict] = []
    checks = [
        ("AGENTS.md", True),
        ("SOUL.md", True),
        ("USER.md", True),
        ("HEARTBEAT.md", False),
        ("tasks/QUEUE.md", False),
        ("memory", False),
        ("skills", False),
    ]

    for rel, required in checks:
        if exists(target, rel):
            record(results, SEVERITY_PASS, f"{rel} found", rel)
        else:
            if required:
                record(results, SEVERITY_FAIL, f"{rel} missing", rel)
            else:
                record(results, SEVERITY_WARN, f"{rel} missing", rel)

    if exists(target, "USER.md"):
        if looks_like_placeholder(target, "USER.md"):
            record(results, SEVERITY_WARN, "USER.md still looks like the default template", "USER.md")
        if is_effectively_empty_markdown(target, "USER.md"):
            record(results, SEVERITY_WARN, "USER.md is effectively empty", "USER.md")

    if exists(target, "tasks/QUEUE.md"):
        if looks_like_placeholder(target, "tasks/QUEUE.md"):
            record(results, SEVERITY_WARN, "tasks/QUEUE.md still contains template placeholders", "tasks/QUEUE.md")

    if exists(target, "HEARTBEAT.md"):
        if looks_like_placeholder(target, "HEARTBEAT.md"):
            record(results, SEVERITY_WARN, "HEARTBEAT.md still contains template boilerplate", "HEARTBEAT.md")

    skills_dir = target / "skills"
    for skill_dir in iter_skill_dirs(skills_dir):
        skill_md = skill_dir / "SKILL.md"
        rel = str(skill_dir.relative_to(target))
        if skill_md.exists():
            record(results, SEVERITY_PASS, f"{rel}/SKILL.md found", f"{rel}/SKILL.md")
        else:
            record(results, SEVERITY_WARN, f"{rel} has no SKILL.md", rel)

    memory_dir = target / "memory"
    if memory_dir.exists():
        md_files = sorted(memory_dir.glob("*.md"))
        if not md_files:
            record(results, SEVERITY_WARN, "memory/ exists but has no daily markdown files", "memory")

    return results


def summarize(results: list[dict]) -> dict:
    counts = {SEVERITY_PASS: 0, SEVERITY_WARN: 0, SEVERITY_FAIL: 0}
    for r in results:
        counts[r["level"]] += 1
    return counts


def print_text(target: Path, results: list[dict]) -> None:
    print(f"Workspace: {target}")
    for r in results:
        print(f"{r['level']:<5} {r['message']}")

def print_markdown(target: Path, results: list[dict], summary: dict) -> None:
    print(f"# Workspace Audit\n")
    print(f"- Workspace: `{target}`")
    print(f"- PASS: {summary['PASS']}  WARN: {summary['WARN']}  FAIL: {summary['FAIL']}\n")
    for r in results:
        print(f"- **{r['level']}** — {r['message']}")


def parse_args(argv: list[str]):
    target = None
    json_mode = False
    markdown_mode = False
    strict = False
    for arg in argv[1:]:
        if arg == "--json":
            json_mode = True
        elif arg == "--strict":
            strict = True
        elif arg == "--markdown":
            markdown_mode = True
        elif arg.startswith("-"):
            raise SystemExit(f"Unknown option: {arg}")
        else:
            target = Path(arg)
    return (target or Path.cwd()).resolve(), json_mode, markdown_mode, strict


def main() -> int:
    target, json_mode, markdown_mode, strict = parse_args(sys.argv)
    results = check_workspace(target)
    summary = summarize(results)

    if json_mode:
        print(json.dumps({
            "workspace": str(target),
            "summary": summary,
            "results": results,
        }, ensure_ascii=False, indent=2))
    elif markdown_mode:
        print_markdown(target, results, summary)
    else:
        print_text(target, results)
        print(f"\nSummary: PASS={summary['PASS']} WARN={summary['WARN']} FAIL={summary['FAIL']}")

    if summary[SEVERITY_FAIL] > 0:
        return 2
    if strict and summary[SEVERITY_WARN] > 0:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
