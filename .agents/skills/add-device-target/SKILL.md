---
name: add-device-target
description: "Add, remove or validate supported Garmin products. Use when: editing iq:product entries in manifest.xml, fixing 'Invalid device id' warnings, adding device-specific resource overrides in monkey.jungle, or updating the supported products list."
---

# Device targets

## Procedure

0. Check [docs/device-tiers.md](../../../docs/device-tiers.md) for the device's tier and test-device plan.
1. Confirm the product ID exists in the installed SDK: `ls "$HOME/Library/Application Support/Garmin/ConnectIQ/Devices" | grep -x <id>`. If it doesn't, the device pack is missing (human installs via SDK Manager) or the ID is wrong.
2. Check the device supports the app's minimum API version (3.2.0, from `minSdkVersion` in `manifest.xml`) and widgets/glances: grep `Devices/<id>/compiler.json` for `connectIQVersion` and the `appTypes` block (which includes per-type memory limits). Don't read the whole file.
3. Add `<iq:product id="..."/>` to `manifest.xml`, keeping the list alphabetical.
4. If the device needs the large-font profile, add `<id>.resourcePath = $(base.resourcePath);resources-large` to `monkey.jungle`, and only after visual validation.
5. `scripts/build.sh <id>`. For a first build of a new device, run `scripts/build.sh --update-baseline <id>`, then review the baseline file before committing. Look especially for glance memory and launcher icon warnings.
6. Update the README "Supported products" list and the tier table in [docs/device-tiers.md](../../../docs/device-tiers.md).
7. Add the new (or removed) devices to the unreleased section of [CHANGELOG.md](../../../CHANGELOG.md), one line per batch, with the marketing name and the product ids.
8. `scripts/check.sh build`.

## Trying many devices at once

`scripts/device-smoke.sh [--candidates | device ...]` adds each device to `manifest.xml`, builds, launches it in the simulator, presses DOWN + SELECT to open the widget from its glance, screenshots only the simulator window (`.cache/ciq/smoke/shots/`), and keeps the devices that start without an error. Devices that fail are removed again and recorded with the reason in [docs/device-smoke-failures.md](../../../docs/device-smoke-failures.md). Use `--dry-run` to change nothing, `--list` to see the candidates. It needs the simulator GUI and screen-recording and accessibility permission for the terminal. Passing only means "no crash"; look at the screenshots, then do steps 6 and 7 for the kept devices.
