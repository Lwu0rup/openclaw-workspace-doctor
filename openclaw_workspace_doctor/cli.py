from __future__ import annotations

import sys
from pathlib import Path

TEMPLATE_HINTS = {
    "USER.md": ["Name:", "What to call them:", "Pronouns:"],
    "tasks/QUEUE.md": ["[Task description]", "@[agent]", "[Idea that might become a task]"],
}


def exists(path: Path, rel: str):
    return (path / rel).exists()


def read_text(path: Path, rel: str) -> str:
    try:
        return (path / rel).read_text(encoding="utf-8")
    except Exception:
        return ""


def check_placeholder(path: Path, rel: str):
    text = read_text(path, rel)
    hints = TEMPLATE_HINTS.get(rel, [])
    return any(h in text for h in hints)


def iter_skill_dirs(skills_dir: Path):
    if not skills_dir.exists():
        return []
    return [p for p in skills_dir.iterdir() if p.is_dir()]


def report(level: str, msg: str):
    print(f"{level:<5} {msg}")


def main() -> int:
    target = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    target = target.resolve()
    print(f"Workspace: {target}")

    checks = [
        ("AGENTS.md", True),
        ("SOUL.md", True),
        ("USER.md", True),
        ("HEARTBEAT.md", False),
        ("tasks/QUEUE.md", False),
        ("memory", False),
        ("skills", False),
    ]

    failed = 0
    for rel, required in checks:
        if exists(target, rel):
            report("PASS", f"{rel} found")
        else:
            if required:
                report("FAIL", f"{rel} missing")
                failed += 1
            else:
                report("WARN", f"{rel} missing")

    if exists(target, "USER.md") and check_placeholder(target, "USER.md"):
        report("WARN", "USER.md still looks like the default template")

    if exists(target, "tasks/QUEUE.md") and check_placeholder(target, "tasks/QUEUE.md"):
        report("WARN", "tasks/QUEUE.md still contains template placeholders")

    skills_dir = target / "skills"
    for skill_dir in iter_skill_dirs(skills_dir):
        skill_md = skill_dir / "SKILL.md"
        if skill_md.exists():
            report("PASS", f"{skill_dir.relative_to(target) / 'SKILL.md'} found")
        else:
            report("WARN", f"{skill_dir.relative_to(target)} has no SKILL.md")

    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
