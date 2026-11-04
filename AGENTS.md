# AGENTS.md

Garmin Connect IQ widget (Monkey C) that shows Tibber electricity prices with optional Swedish network fees and energy tax. Single source of truth for every coding agent (Copilot, Claude Code, Codex, Cursor, Gemini CLI). Agent config lives in [.agents/](.agents/AGENTS.md); human guide: [.agents/README.md](.agents/README.md).

## Verify with the harness, not ad-hoc commands

Always use these scripts. They locate the SDK/Java/signing key, keep full logs in `.cache/ciq/logs/`, and print only a short summary plus **new** warnings/failures compared with `.agents/baselines/`. Do not run raw `monkeyc`/`monkeydo`, and do not paste or re-read full logs unless a summary line points you there.

| When | Command | Cost |
| --- | --- | --- |
| Docs, agent config, or XML only | `scripts/check.sh fast` | ~1 s, no SDK |
| After any `.mc`/resource/jungle edit | `scripts/build.sh [device ...]` (default `fenix7xpro`) | ~5 s/device |
| Before declaring a code task done | `scripts/check.sh full` (fast + 3-device build + simulator tests) | ~30 s |
| Iterating on one test | `scripts/test.sh <testName>` | ~10 s |

- Pre-existing warnings and test failures are baselined; they are not your task unless asked. Only `new`/`NEW` lines need action.
- If you intentionally fix or accept warnings/failures, update the baseline with `--update-baseline` and mention it in your summary.
- If the simulator or SDK is unavailable, say so and stop at `scripts/check.sh fast` + `scripts/build.sh` — do not guess.

## Repository map

- `source/app/` lifecycle · `screens/` views · `delegates/` input · `network/` GraphQL client + `PriceCache` (pricing math) · `charts/` · `components/` · `theme/Theme.mc` shared colors · `config/` secrets (template only) · `tests/` `(:test)` unit tests
- `resources/` strings, bitmaps, fonts (standard); `resources-large/` overrides for the large-font profile (`fenix847mm`, see `monkey.jungle`)
- `manifest.xml` products/permissions · `monkey.jungle` build config · `tools/` font generator
- `experiments/` is excluded from builds; do not edit or reference it from `source/`
- Ignore generated output: `bin/`, `gen/`, `mir/`, `internal-mir/`, `external-mir/`, `.cache/`, `*.prg`. Don't read or search them.

## Conventions

- Monkey C with `import Toybox.*`; classes prefixed `Tibber` (e.g. `TibberPriceCache`); `Application.Storage` keys prefixed `tibber_`.
- Minimum API 3.2.0 and devices down to `vivoactive4`: check `has`/API level before newer APIs, keep allocations small, avoid large dictionaries/arrays.
- Colors in `Theme`; chart geometry constants at the top of `PriceChart`. No hard-coded per-device pixel values — derive from `dc` size and font heights.
- User-visible text goes in `resources/strings/strings.xml` (Swedish, default) and `resources-eng/strings/strings.xml` (English). Both files must define the same IDs (enforced by lint).
- Tests: top-level `(:test) function testXxx(logger)`; fakes are `(:test)` classes. Tests must restore any `Storage` values they change and never call the network.
- Keep changes surgical; update [README.md](README.md) when behavior, controls, devices, or pricing math change.

## Guardrails (enforced by hooks in every agent)

- Never read, print, create, or commit `developer_key.*`, `source/config/Secrets.mc`, or `.env*`. Ask the human. The template `Secrets.mc.example` is fine.
- Never hand-edit generated output or `resources*/fonts/Poppins*.fnt|png` (regenerate with `python3 tools/build_poppins_price_font.py [--profile large]`).
- Never use `git commit --no-verify`. The pre-commit hook runs `scripts/check.sh fast --staged`.
- Don't commit or push unless asked.

## Skills (load on demand)

Located in [.agents/skills/](.agents/skills/). Load the matching one instead of exploring:

- `connectiq-build-test` — build/test failures, simulator issues, baselines, device matrix
- `pricing-change` — anything touching prices, VAT, network fees, energy tax, cache
- `ui-layout-change` — screens, charts, fonts, layout on round/small/large displays
- `localization` — adding/changing translated strings or languages (use a cheap model)
- `add-device-target` — adding or removing products in `manifest.xml`

## Definition of done

1. `scripts/check.sh full` passes (or `fast` for docs-only), with no new warnings or failures.
2. README updated if user-visible behavior changed.
3. Final summary: what changed, the check level run and its result, and any baseline updates.
