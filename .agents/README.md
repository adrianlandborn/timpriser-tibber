# Agent setup guide

This repo works with any AI coding agent (GitHub Copilot, Claude Code, Codex, Cursor, Gemini CLI) without duplicating instructions. It is adapted from [the agent-agnostic repository guide](https://gist.github.com/davidgibsonp/337be9b80b3f03eccd188235c287bb05), with a build/test **harness** added so agents can verify their own work cheaply.

## Mental model

Every piece of agent configuration is one of:

| Category | Strategy here |
| --- | --- |
| **Portable**: the same file works for every agent | Stored once: `AGENTS.md`, `.agents/skills/` |
| **Adapter**: same intent, different format per agent | Thin per-agent files that only point to `.agents/`: `CLAUDE.md`, `.gemini/settings.json`, and the hook JSON files |
| **Agent-specific**: no equivalent elsewhere | Left in the agent's folder, for example Claude `permissions` in `.claude/settings.json` |

### What each agent reads

| | Instructions | Skills | Pre-tool guard hook |
| --- | --- | --- | --- |
| Copilot (VS Code / CLI / cloud) | `AGENTS.md` | `.agents/skills/` | `.github/hooks/guard.json` (also reads `.claude/settings.json`) |
| Claude Code | `CLAUDE.md` → `@AGENTS.md` | `.claude/skills/` → symlinks | `.claude/settings.json` |
| Codex | `AGENTS.md` | `.agents/skills/` | `.codex/hooks.json` (trust it with `/hooks`) |
| Cursor | `AGENTS.md` | `.agents/skills/` | `.cursor/hooks.json` |
| Gemini CLI | `.gemini/settings.json` → `AGENTS.md` | `.agents/skills/` | `.gemini/settings.json` (approve on first run) |

There is no MCP layer yet because the project uses no MCP servers. If you add one, follow the gist's pattern: a canonical `.agents/mcp/servers.json` and a sync script that generates each agent's file.

## The agentic harness

An agent is a model running in a loop: **instructions → act → observe feedback → repeat until done**. The *harness* is everything around the model that makes that loop reliable and cheap. Its parts here:

| Harness part | Purpose | Where |
| --- | --- | --- |
| Context | Short always-on rules plus on-demand detail | `AGENTS.md` (short), skills (loaded only when relevant) |
| Tools | Deterministic commands with **terse** output | `scripts/build.sh`, `test.sh`, `check.sh` |
| Feedback / ratchets | Show only what *this change* broke | `.agents/baselines/` for warnings and known test failures |
| Guardrails | Block what must never happen, whatever the prompt says | `.agents/hooks/guard.py` via every agent's hook |
| Gate | One definition of done for agents, humans, git and CI | `scripts/check.sh fast|build|full`, `.githooks/pre-commit`, `.github/workflows/agent-checks.yml` |

### Why this saves credits

- **Small always-on context.** `AGENTS.md` is read on every request, so it holds only routing and rules (validated to stay under ~150 lines). Pricing, UI and device knowledge are skills that cost about 50 tokens each until needed.
- **Summaries instead of logs.** A raw `monkeyc -w` build prints 70+ warnings for `fr55`. The harness prints one line, plus only *new* warnings. Logs stay on disk for targeted `grep`.
- **No rediscovery.** SDK, Java and key resolution are scripted, so agents don't spend turns finding `monkeyc` or fixing `Unable to locate a Java Runtime`.
- **No wild-goose chases.** Five existing test errors and existing warnings are baselined. Agents are told they are not their task, and are alerted when they get fixed.
- **Tiered checks.** `fast` takes about 1 s and needs no SDK (docs/config edits); `build` takes ~15 s; `full` takes ~30 s with tests.
- **Fewer approval round-trips.** Harness commands are pre-allowed for Claude, while hooks block anything dangerous.

## Setup (one time per clone)

```sh
scripts/setup-agents.sh   # sets core.hooksPath, links skills, runs the fast check
scripts/check.sh full     # confirm SDK, simulator and baselines work on this machine
```

Then, per tool:

- **Codex:** trust the project and review hooks with `/hooks`.
- **Gemini CLI:** approve the project hook when prompted.
- **Cursor:** hooks reload automatically. Check them in Settings → Hooks.
- **VS Code Copilot:** make sure `chat.useAgentsMdFile` is enabled (the default).

## Daily workflow

1. Ask the agent for the task. It reads `AGENTS.md`, loads a skill if relevant, edits, and runs the harness.
2. Expect the agent's final summary to state which check level it ran, the result, and any baseline changes.
3. Commit. The pre-commit hook re-runs the fast gate and secret scan.

## Maintaining

| Task | How |
| --- | --- |
| New repeated workflow | Add a skill (see [AGENTS.md](AGENTS.md) "Adding a skill") |
| Agent keeps making the same mistake | Add **one line** to root `AGENTS.md`. If it's task-specific, put it in the skill instead |
| Must *never* happen | Add a rule plus a test case to `guard.py` / `validate.py`. Instructions alone are not enforcement |
| Fixed warnings or tests | `scripts/build.sh --update-baseline <device>` / `scripts/test.sh --update-baseline` |
| Personal experiments | `.agents/skills-local/local-<name>/` (gitignored) |
| New agent tool | See [AGENTS.md](AGENTS.md) "Adding a new agent tool" |

## Suggested next steps

1. Fix the 5 baselined test errors (`abs` symbol missing in `PriceChartTest`, null colour in `WidgetSettingsTest`), then shrink the baseline.
2. Review the `fr55` baseline: the glance exceeds that device's memory limit, and `fenix7xpronowifi` is an invalid product ID.
3. Add a `release-check` skill that walks through `RELEASE_READINESS.md` when you approach Store submission.
4. Optionally add a `Stop` hook that reminds the agent to run `scripts/check.sh` if `.mc` files changed. It's left out for now to keep the setup simple and portable.
