#!/usr/bin/env bash
# Single verification gate for humans, agents, git hooks, and CI.
#
# Usage: scripts/check.sh [fast|build|full] [--staged]
#   fast   No SDK needed (~1s): agent-config validation, XML, shell syntax,
#          secret scan. Used by the pre-commit hook and CI.
#   build  fast + compile for $CHECK_DEVICES (default) — use after code edits.
#   full   build + simulator unit tests — use before finishing a task.
#   --staged  Secret-scan only staged content (pre-commit mode).

set -euo pipefail
cd "$(dirname "$0")/.."

level=build
staged=""
for arg in "$@"; do
    case "$arg" in
        fast|build|full) level="$arg" ;;
        --staged) staged="--staged" ;;
        -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
        *) echo "Unknown argument: $arg" >&2; exit 2 ;;
    esac
done

python3 .agents/scripts/validate.py
python3 scripts/lint.py $staged

if [ "$level" != fast ]; then
    # shellcheck source=lib.sh
    devices="${CHECK_DEVICES:-$(source scripts/lib.sh && echo "$DEFAULT_CHECK_DEVICES")}"
    # shellcheck disable=SC2086
    scripts/build.sh $devices
fi
if [ "$level" = full ]; then
    scripts/test.sh
fi
echo "CHECK PASSED ($level)"
