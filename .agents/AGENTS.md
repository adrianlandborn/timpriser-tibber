# .agents/

Canonical, agent-agnostic configuration. Follows [AGENTS.md](https://agents.md) and the [Agent Skills](https://agentskills.io) standard. Human-oriented guide: [README.md](README.md).

## Layout

- `skills/<name>/SKILL.md`: shared skills (committed). Read natively by Copilot, Codex, Cursor and Gemini CLI; symlinked into `.claude/skills/` for Claude Code.
- `skills-local/local-<name>/`: private skills (gitignored; name must start with `local-`).
- `hooks/guard.py`: the one PreToolUse policy every agent runs (secrets, generated files, `--no-verify`).
- `baselines/`: accepted compiler warnings per device and known failing tests (ratchets).
- `scripts/link-skills.sh`: syncs Claude symlinks. `scripts/validate.py` validates all of this.

## Rules

- Edit skills here, never under `.claude/skills/`.
- Thin per-agent adapters only call into this directory: `.claude/settings.json`, `.github/hooks/guard.json`, `.cursor/hooks.json`, `.gemini/settings.json`, `.codex/hooks.json`. Change policy in `guard.py`, not in adapters.
- Changing `guard.py`: add a case to `GUARD_CASES` in `scripts/validate.py`, then run `scripts/check.sh fast`. Ask the human before loosening a rule.
- Baselines must only shrink unless the human accepts the new warnings or failures.
- Shared instructions belong in the root `AGENTS.md`. Keep it under ~150 lines, because every agent loads it on every request. Put detail in skills.

## Adding a skill

1. Create `skills/<name>/SKILL.md` with `name` (equal to the folder name, lowercase-hyphenated) and a `description` containing "Use when: ...".
2. `.agents/scripts/link-skills.sh`
3. Add a one-line entry to the root `AGENTS.md` "Skills" list.
4. `scripts/check.sh fast`, then commit the skill and its symlink.

## Adding a new agent tool

1. If it reads `AGENTS.md` and `.agents/skills/` natively, no instruction or skill work is needed. Otherwise add a pointer file or setting, like `CLAUDE.md` or `.gemini/settings.json`.
2. If it needs skills in its own folder, add that folder to `TARGETS` in `scripts/link-skills.sh`.
3. If it supports pre-tool hooks, add an adapter calling `guard.py --agent <name>`. Add an output format in `guard.py` and an entry in `ADAPTERS` and `GUARD_CASES` in `validate.py`.
