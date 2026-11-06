#!/usr/bin/env python3
"""Validate the agent-agnostic configuration (fast, no SDK, no network).

Usage: python3 .agents/scripts/validate.py

Checks instruction entry points, skills (agentskills.io rules), Claude skill
symlinks, per-agent hook adapters, relative Markdown links, and runs the
guard hook against sample payloads from both supported agents.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AGENTS = ROOT / ".agents"
GUARD = ".agents/hooks/guard.py"
AGENTS_MD_SOFT_LIMIT = 150  # lines; AGENTS.md is loaded on every request
SKILL_BODY_LIMIT = 500
NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
LINK_RE = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")

ADAPTERS = {
    ".claude/settings.json": "claude",
    ".github/hooks/guard.json": "copilot",
}

errors, warnings = [], []


def frontmatter(text):
    if not text.startswith("---\n"):
        return None, text
    end = text.find("\n---", 4)
    if end < 0:
        return None, text
    meta = {}
    for line in text[4:end].splitlines():
        m = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if m:
            meta[m.group(1)] = m.group(2).strip().strip("'\"")
    return meta, text[end + 4:]


def check_links(md_path):
    text = md_path.read_text(encoding="utf-8")
    text = re.sub(r"```.*?```", "", text, flags=re.S)
    for target in LINK_RE.findall(text):
        if re.match(r"^[a-z]+:", target) or target.startswith("#"):
            continue
        path = (md_path.parent / target.split("#")[0]).resolve()
        if not path.exists():
            errors.append(f"{md_path.relative_to(ROOT)}: broken link -> {target}")


def check_instructions():
    agents_md = ROOT / "AGENTS.md"
    if not agents_md.is_file():
        errors.append("AGENTS.md missing at repo root")
        return
    lines = len(agents_md.read_text(encoding="utf-8").splitlines())
    if lines > AGENTS_MD_SOFT_LIMIT:
        warnings.append(f"AGENTS.md has {lines} lines (> {AGENTS_MD_SOFT_LIMIT}); move detail into skills")
    claude = ROOT / "CLAUDE.md"
    if not claude.is_file() or "@AGENTS.md" not in claude.read_text(encoding="utf-8"):
        errors.append("CLAUDE.md must exist and import @AGENTS.md")
    for md in [agents_md, AGENTS / "AGENTS.md", AGENTS / "README.md"]:
        if md.is_file():
            check_links(md)
        else:
            errors.append(f"{md.relative_to(ROOT)} missing")


def check_skills():
    for base, local in ((AGENTS / "skills", False), (AGENTS / "skills-local", True)):
        for skill_dir in sorted(p for p in base.glob("*") if p.is_dir()):
            rel = skill_dir.relative_to(ROOT)
            skill_md = skill_dir / "SKILL.md"
            if not skill_md.is_file():
                errors.append(f"{rel}: missing SKILL.md")
                continue
            meta, body = frontmatter(skill_md.read_text(encoding="utf-8"))
            if meta is None:
                errors.append(f"{rel}/SKILL.md: missing YAML frontmatter")
                continue
            name, desc = meta.get("name", ""), meta.get("description", "")
            if name != skill_dir.name:
                errors.append(f"{rel}/SKILL.md: name '{name}' must match folder '{skill_dir.name}'")
            if not NAME_RE.match(name) or len(name) > 64:
                errors.append(f"{rel}/SKILL.md: name must be lowercase-hyphenated, max 64 chars")
            if local and not name.startswith("local-"):
                errors.append(f"{rel}: private skills must be named 'local-*' (keeps symlinks gitignored)")
            if not desc or len(desc) > 1024:
                errors.append(f"{rel}/SKILL.md: description required, max 1024 chars")
            elif "use when" not in desc.lower():
                warnings.append(f"{rel}/SKILL.md: description should say 'Use when ...' for discovery")
            if len(body.splitlines()) > SKILL_BODY_LIMIT:
                errors.append(f"{rel}/SKILL.md: body over {SKILL_BODY_LIMIT} lines; split into references/")
            check_links(skill_md)
    result = subprocess.run([str(AGENTS / "scripts/link-skills.sh"), "--check"], capture_output=True, text=True)
    if result.returncode:
        errors.append("skill symlinks out of date: " + (result.stdout + result.stderr).strip().replace("\n", "; "))


def check_adapters():
    for rel, agent in ADAPTERS.items():
        path = ROOT / rel
        if not path.is_file():
            errors.append(f"{rel}: missing adapter for {agent}")
            continue
        try:
            text = path.read_text(encoding="utf-8")
            json.loads(text)
        except ValueError as exc:
            errors.append(f"{rel}: invalid JSON: {exc}")
            continue
        if GUARD not in text or f"--agent {agent}" not in text:
            errors.append(f"{rel}: must call {GUARD} --agent {agent}")


GUARD_CASES = [
    # (agent, payload, expect_block)
    ("claude", {"tool_name": "Read", "tool_input": {"file_path": str(ROOT / "developer_key.pem")}}, True),
    ("claude", {"tool_name": "Edit", "tool_input": {"file_path": "source/app/App.mc"}}, False),
    ("claude", {"tool_name": "Edit", "tool_input": {"file_path": "README.md",
                                                     "new_string": "see bin/ and developer_key.der"}}, False),
    ("claude", {"tool_name": "Bash", "tool_input": {"command": "cat secrets/Secrets.mc"}}, True),
    ("claude", {"tool_name": "Bash", "tool_input": {"command": "cat secrets/Secrets.mc.example"}}, False),
    ("claude", {"tool_name": "Read", "tool_input": {"file_path": str(ROOT / "secrets" / "notes.txt")}}, True),
    ("claude", {"tool_name": "Read", "tool_input": {"file_path": str(ROOT / "secrets" / "README.md")}}, False),
    ("claude", {"tool_name": "Bash", "tool_input": {"command": "git commit --no-verify -m x"}}, True),
    ("claude", {"tool_name": "Bash", "tool_input": {"command": "scripts/check.sh full"}}, False),
    ("copilot", {"tool_name": "replace_string_in_file", "tool_input": {"filePath": "bin/x.prg"}}, True),
    ("copilot", {"toolName": "view", "toolArgs": json.dumps({"path": "developer_key.der"})}, True),
    ("copilot", {"tool_name": "read_file", "tool_input": {"filePath": "gen/resources/x.mc"}}, False),
    ("copilot", {"tool_name": "apply_patch", "tool_input": {
        "command": "*** Begin Patch\n*** Update File: bin/TibberWidget.prg\n*** End Patch"}}, True),
    ("copilot", {"tool_name": "apply_patch", "tool_input": {
        "command": "*** Begin Patch\n*** Update File: source/app/App.mc\n+bin/\n*** End Patch"}}, False),
    ("copilot", {"tool_name": "run_in_terminal", "tool_input": {"command": "cp .env /tmp"}}, True),
    ("copilot", {"tool_name": "run_in_terminal", "tool_input": {"command": "echo hi"}}, False),
    ("claude", "not-a-dict", False),
]


def check_guard():
    for agent, payload, expect_block in GUARD_CASES:
        result = subprocess.run([sys.executable, str(ROOT / GUARD), "--agent", agent],
                                input=json.dumps(payload), capture_output=True, text=True, cwd=ROOT)
        blocked = result.returncode == 2
        try:
            json.loads(result.stdout)
        except ValueError:
            errors.append(f"guard ({agent}) printed non-JSON stdout for {payload}")
        if result.returncode not in (0, 2):
            errors.append(f"guard ({agent}) crashed: {result.stderr.strip()}")
        elif blocked != expect_block:
            errors.append(f"guard ({agent}) {'blocked' if blocked else 'allowed'} {json.dumps(payload)[:120]}")


def main():
    check_instructions()
    check_skills()
    check_adapters()
    check_guard()
    for w in warnings:
        print(f"WARN {w}")
    if errors:
        print(f"FAIL agent config — {len(errors)} problem(s):")
        for e in errors:
            print(f"  - {e}")
        return 1
    print(f"OK   agent config ({len(GUARD_CASES)} guard cases)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
