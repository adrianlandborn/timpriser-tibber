#!/usr/bin/env bash
# One-time local setup for the agent harness. Safe to re-run.
set -euo pipefail
cd "$(dirname "$0")/.."

git config core.hooksPath .githooks
chmod +x .githooks/* scripts/*.sh .agents/scripts/*.sh .agents/scripts/*.py .agents/hooks/*.py scripts/*.py
.agents/scripts/link-skills.sh
echo "Git hooks: core.hooksPath=.githooks"
scripts/check.sh fast
