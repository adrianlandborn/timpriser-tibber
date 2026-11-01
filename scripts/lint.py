#!/usr/bin/env python3
"""Fast repository hygiene checks (no Connect IQ SDK required).

Usage: python3 scripts/lint.py [--staged]

- XML well-formedness for the manifest and resource XML files
- Syntax of shell and Python helper scripts
- Secret scan: forbidden paths, private keys, and token-like literals.
  --staged scans the git index (pre-commit); default scans tracked and
  untracked, non-ignored files.
"""
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

FORBIDDEN_PATH = re.compile(
    r"(^|/)(developer_key\.(pem|der)|[^/]*\.(pem|key|p12|pfx)|\.env(\.(?!example$)[^/]+)?)$"
    r"|^source/config/Secrets\.mc$"
    r"|(^|/)[^/]*\.prg(\.debug\.xml)?$"
    r"|^(bin|gen|mir|internal-mir|external-mir|\.cache)/"
)
PRIVATE_KEY = re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")
TOKEN_LITERAL = re.compile(r"\"[A-Za-z0-9_\-.]{40,}\"")
TOKEN_SCAN_EXEMPT = {"source/config/Secrets.mc.example"}


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, check=True).stdout


def candidate_files(staged):
    if staged:
        names = git("diff", "--cached", "--name-only", "--diff-filter=ACMR").split("\n")
    else:
        names = git("ls-files", "--cached", "--others", "--exclude-standard").split("\n")
    return [n for n in names if n]


def read(name, staged):
    try:
        if staged:
            data = subprocess.run(["git", "show", f":{name}"], cwd=ROOT, capture_output=True, check=True).stdout
        else:
            path = ROOT / name
            if not path.is_file():
                return None
            data = path.read_bytes()
        return data.decode("utf-8")
    except (UnicodeDecodeError, subprocess.CalledProcessError):
        return None


def secret_scan(staged):
    errors = []
    for name in candidate_files(staged):
        if FORBIDDEN_PATH.search(name):
            errors.append(f"{name}: secret or generated file must not be committed")
            continue
        text = read(name, staged)
        if text is None:
            continue
        if PRIVATE_KEY.search(text):
            errors.append(f"{name}: contains a private key")
        if name.endswith(".mc") and name not in TOKEN_SCAN_EXEMPT:
            for lineno, line in enumerate(text.splitlines(), 1):
                if TOKEN_LITERAL.search(line):
                    errors.append(f"{name}:{lineno}: token-like string literal (move secrets to Secrets.mc)")
    return errors


def xml_check():
    errors = []
    files = [ROOT / "manifest.xml"]
    for res_dir in ROOT.glob("resources*"):
        files += [p for p in res_dir.rglob("*.xml")]
    for path in files:
        try:
            ET.parse(path)
        except ET.ParseError as exc:
            errors.append(f"{path.relative_to(ROOT)}: invalid XML: {exc}")
    return errors


def script_check():
    errors = []
    shell = list((ROOT / "scripts").glob("*.sh")) + list((ROOT / ".agents/scripts").glob("*.sh"))
    shell += [p for p in (ROOT / ".githooks").glob("*") if p.is_file()]
    shell.append(ROOT / "monkeyInstall")
    for path in shell:
        result = subprocess.run(["bash", "-n", str(path)], capture_output=True, text=True)
        if result.returncode:
            errors.append(f"{path.relative_to(ROOT)}: {result.stderr.strip()}")
    for base in ("scripts", "tools", ".agents"):
        for path in (ROOT / base).rglob("*.py"):
            try:
                compile(path.read_text(encoding="utf-8"), str(path), "exec")
            except SyntaxError as exc:
                errors.append(f"{path.relative_to(ROOT)}:{exc.lineno}: {exc.msg}")
    return errors


def main():
    staged = "--staged" in sys.argv[1:]
    errors = secret_scan(staged) + xml_check() + script_check()
    if errors:
        print(f"FAIL lint — {len(errors)} problem(s):")
        for err in errors[:40]:
            print(f"  - {err}")
        return 1
    print("OK   lint (secrets, XML, scripts)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
