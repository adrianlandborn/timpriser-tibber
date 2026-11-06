#!/usr/bin/env python3
"""Shared PreToolUse guard for every coding agent in this repo.

Usage: python3 .agents/hooks/guard.py --agent <claude|copilot>

Reads the hook payload (JSON) on stdin and blocks:
  - any read/write/shell access to signing keys and local secrets
  - writes to generated build output and generated font assets
  - `git ... --no-verify` (bypasses the pre-commit gate)

Contract shared by both supported agents: exit 0 + JSON = allow,
exit 2 + reason on stderr (and JSON) = deny. Never crash: an internal error
allows the call, because some agents fail closed on hook errors.
"""
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

SECRET_PATH = re.compile(
    r"(^|/)(developer_key\.(pem|der)|[^/]*\.(pem|key|p12|pfx)|\.env(\.(?!example$)[^/]+)?)$"
    r"|^secrets/(?!README\.md$|Secrets\.mc\.example$)"
)
SECRET_IN_COMMAND = re.compile(
    r"developer_key\.(pem|der)|[^\s'\"]*\.(pem|p12|pfx)\b|Secrets\.mc(?!\.example)\b"
    r"|(^|[\s/'\"=])\.env(\.(?!example\b)[\w-]+)?(?=$|[\s'\";|&)])"
)
GENERATED_PATH = re.compile(
    r"^(bin|gen|mir|internal-mir|external-mir|\.cache)/"
    r"|\.prg(\.debug\.xml)?$"
    r"|^resources(-large)?/fonts/Poppins[^/]*\.(fnt|png)$"
)
NO_VERIFY = re.compile(r"\bgit\b[^;&|]*\s--no-verify\b")
WRITE_TOOL = re.compile(r"edit|write|create|replace|patch|insert|delete|remove|move|rename|notebook", re.I)
SHELL_TOOL = re.compile(r"^(bash|shell|run_in_terminal|run_shell_command|exec_command|local_shell|terminal)$", re.I)
PATH_KEYS = {"file_path", "filePath", "path", "absolute_path", "target_file", "file", "notebook_path",
             "paths", "filePaths", "files", "dir_path"}
PATCH_HEADER = re.compile(r"^\*\*\* (?:Add|Update|Delete) File: (.+)$|^\*\*\* Move to: (.+)$", re.M)

FIX_HINTS = {
    "secret": "Signing keys and local secrets are human-only. Use scripts/build.sh or scripts/test.sh, "
              "which pass the key to the compiler without exposing it.",
    "generated": "This is generated output. Change the source (source/, resources/, "
                 "tools/build_poppins_price_font.py) and rebuild with scripts/build.sh instead.",
    "no-verify": "Do not bypass the pre-commit gate. Fix the reported problem; run scripts/check.sh fast.",
}


def rel(path_str, cwd):
    p = Path(os.path.expanduser(path_str.strip().strip("'\"")))
    if not p.is_absolute():
        p = Path(cwd) / p
    try:
        return p.resolve().relative_to(ROOT).as_posix()
    except (ValueError, OSError):
        return None


def collect(obj, paths, commands, texts):
    if isinstance(obj, dict):
        for key, value in obj.items():
            if key in PATH_KEYS:
                values = value if isinstance(value, list) else [value]
                paths.extend(v for v in values if isinstance(v, str))
            elif key in ("command", "cmd") and isinstance(value, (str, list)):
                commands.append(value if isinstance(value, str) else " ".join(map(str, value)))
            elif isinstance(value, str):
                texts.append(value)
                if value[:1] in "{[":
                    try:
                        collect(json.loads(value), paths, commands, texts)
                    except ValueError:
                        pass
            else:
                collect(value, paths, commands, texts)
    elif isinstance(obj, list):
        for item in obj:
            collect(item, paths, commands, texts)


def evaluate(payload):
    tool = str(payload.get("tool_name") or payload.get("toolName") or "")
    tool_input = payload.get("tool_input", payload.get("toolArgs", payload.get("toolInput", {})))
    if isinstance(tool_input, str):
        try:
            tool_input = json.loads(tool_input)
        except ValueError:
            tool_input = {"command": tool_input}
    cwd = payload.get("cwd") or os.getcwd()

    paths, commands, texts = [], [], []
    collect(tool_input, paths, commands, texts)
    collect(payload.get("attachments") or [], paths, [], [])
    for key in ("file_path", "filePath"):
        if isinstance(payload.get(key), str):
            paths.append(payload[key])
    if isinstance(payload.get("command"), str) and not tool:
        commands.append(payload["command"])

    is_write = bool(WRITE_TOOL.search(tool))
    for blob in commands + texts:
        if "*** Begin Patch" in blob:
            is_write = True
            for m in PATCH_HEADER.finditer(blob):
                paths.append(m.group(1) or m.group(2))
    commands = [c for c in commands if "*** Begin Patch" not in c]

    for raw in paths:
        r = rel(raw, cwd)
        if r is None:
            continue
        if SECRET_PATH.search(r):
            return "secret", f"Access to '{r}' is blocked."
        if is_write and GENERATED_PATH.search(r):
            return "generated", f"Editing '{r}' is blocked."

    if commands or SHELL_TOOL.match(tool):
        for cmd in commands:
            if SECRET_IN_COMMAND.search(cmd):
                return "secret", "Shell command references a signing key or local secret."
            if NO_VERIFY.search(cmd):
                return "no-verify", "'--no-verify' is blocked."
    return None


def deny_output(agent, reason):
    if agent == "copilot":
        return {"permissionDecision": "deny", "permissionDecisionReason": reason,
                "hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny",
                                       "permissionDecisionReason": reason}}
    return {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny",
                                   "permissionDecisionReason": reason}}


def main():
    agent = "claude"
    if "--agent" in sys.argv:
        idx = sys.argv.index("--agent")
        if idx + 1 < len(sys.argv):
            agent = sys.argv[idx + 1]
    try:
        payload = json.loads(sys.stdin.read() or "{}")
        verdict = evaluate(payload) if isinstance(payload, dict) else None
    except Exception:  # noqa: BLE001 - must never break the agent loop
        verdict = None
    if verdict is None:
        print(json.dumps({}))
        return 0
    kind, message = verdict
    reason = f"[repo guard] {message} {FIX_HINTS[kind]}"
    print(json.dumps(deny_output(agent, reason)))
    print(reason, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
