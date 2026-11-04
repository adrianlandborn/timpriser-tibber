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
6. Update the README "Supported products" list.
7. `scripts/check.sh build`.
