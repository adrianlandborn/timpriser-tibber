---
name: connectiq-build-test
description: "Build, test and debug the Connect IQ widget with the repo harness. Use when: a build or unit test fails, the simulator will not start or connect, monkeyc/Java/SDK cannot be found, new compiler warnings appear, baselines need updating, or choosing which devices to compile for."
---

# Connect IQ build and test

The harness lives in `scripts/` and is the only supported way to compile and test. It prints one summary line per step; full logs are in `.cache/ciq/logs/`.

## Procedure

1. Compile the device you are touching: `scripts/build.sh <device>`. The default is `fenix7xpro`.
2. Read only the summary. On `FAIL`, the script already prints the `ERROR` lines. Open the log only if they are insufficient, and use `grep -n ERROR .cache/ciq/logs/build-<device>.log` rather than reading the whole file.
3. Run tests: `scripts/test.sh` (all) or `scripts/test.sh testName`. The simulator auto-starts.
4. Before finishing, run `scripts/check.sh full`.

## Reading results

- `OK build X — N warnings, 0 new, 0 fixed`: good.
- `+ WARNING: ...` lines are new warnings you introduced. Fix them; the run fails while they exist. Set `CIQ_STRICT_WARNINGS=0` only for exploratory builds.
- `fixed > 0`: you removed warnings. Lock that in with `scripts/build.sh --update-baseline <device>` and mention it.
- Tests: `known failures` come from `.agents/baselines/test-failures.txt` and are not yours unless asked. `NEW failures` print the error, details and first stack frames.
- `Now passing`: run `scripts/test.sh --update-baseline` (full suite only) to shrink the known list.
- Baselines strip absolute paths and line numbers, so moving code does not create "new" warnings, but rewording or relocating to another file does.

## Device matrix

`scripts/check.sh build|full` compiles `fenix7xpro` (standard fonts), `fenix847mm` (large-font profile via `monkey.jungle`) and `vivoactive4` (small screen, tight memory/glance limit). Override with `CHECK_DEVICES="venu vivoactive5" scripts/check.sh build`. Each device needs its device pack installed in the SDK Manager.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `Unable to locate a Java Runtime` | Harness checks `JAVA_HOME` and Homebrew `openjdk@17`; otherwise ask the human to `brew install openjdk@17`. |
| `Connect IQ SDK not found` | SDK path comes from `~/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg`; set `CIQ_HOME` to override. |
| `Signing key not found` / `Secrets.mc missing` | Human-only setup (README "Configure local credentials"). Stop and ask. |
| `no results parsed (simulator problem?)` | Simulator not ready or hung. Ask the human to restart it, or retry once. Do not loop. |
| `Invalid device id` warning | Product listed in `manifest.xml` but unknown to the SDK; see the `add-device-target` skill. |
| `Symbol Not Found` at runtime in tests | API missing on that device or a non-static call; check API level and `has` guards. |

Never call `monkeyc`/`monkeydo` directly, and never pass `developer_key.der` on the command line; the guard hook blocks it.
