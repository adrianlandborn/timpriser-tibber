# Device tiers and support plan

Long-term goal: support as many Garmin devices as possible. Strategy: make the modern, high-memory devices work first, then work backwards tier by tier. A tier is only called supported once the checks below pass on its test devices.

Memory limits come from each device's `compiler.json` in the Connect IQ SDK (`appTypes[].memoryLimit`, values in KB below). They are limits, not measured use. Devices with Connect IQ 4+ run this app as a watch-app (the manifest says `widget`; the compiler treats it as a watch-app with a glance), so the `watchApp` limit applies. Older devices use the `widget` limit.

## Tiers

| Tier | Devices | Connect IQ | Main app | Glance | Plan |
| --- | --- | --- | --- | --- | --- |
| **A** | `fenix7`, `fenix7pro`, `fenix7pronowifi`, `fenix7s`, `fenix7spro`, `fenix7x`, `fenix7xpro`, `fenix7xpronowifi`, `fenix843mm`, `fenix847mm`, `fenix8pro47mm`, `fenix8solar47mm`, `fenix8solar51mm`, `fenix943mm`, `fenix947mm`, `fenix9pro43mm`, `fenix9pro47mm`, `fenix9pro51mm`, `fenix9prosolar47mm`, `fenix9prosolar51mm`, `vivoactive5`, `vivoactive6` | 5.2 / 6.0 | 768 | 64 | First target. Full glance (price, interval, hour bar). |
| **B** | `fenix6pro`, `fenix6spro`, `fenix6xpro` | 3.4 | 1024 | 32 | Second. Glance is tight: use a placeholder glance (app name and "Open Tibber" only, system fonts). |
| **C** | `venu`, `vivoactive4`, `vivoactive4s` | 3.3 | 512 | none | Third. No glance, so none is shown. The widget opens full-screen. |

Not supported (removed from `manifest.xml` and the README):

- `fr55`: 64 KB widget limit, no glance; the app ran out of memory loading its fonts at startup.
- `fenix6`, `fenix6s` (former tier D): 64 KB limit. Even with system fonts and no logo, the app ran out of memory reading the cached price list (`PriceCache.readDailyPrices`) on 2026-11-04. Supporting them would need a much smaller cache.

## Test devices

Verify on these, not on every device in a tier.

| Tier | Device | Why |
| --- | --- | --- |
| A | `fenix847mm` | Large AMOLED (454 px) and the large-font profile. |
| A | `fenix7xpro` | MIP (280 px), the most common device. |
| A | `fenix7s` | Smallest Tier A screen (240 px MIP): catches clipping. |
| A | `vivoactive6` | Newest Connect IQ (6.0.3), 390 px AMOLED. |
| B | `fenix6pro` | The 32 KB glance: tightest workable case. |
| C | `vivoactive4` | No glance; 512 KB widget limit. |

The default `scripts/check.sh` build matrix is in `scripts/lib.sh` (`DEFAULT_CHECK_DEVICES`). Move it to one device per verified tier as tiers are verified.

## A tier counts as verified when

On each of its test devices, in the simulator (`./monkeyInstall <device>`):

1. The glance shows (where the device has one) without a crash.
2. The main price screen opens and shows the loading, error and price states.
3. The graph and settings screens open.
4. `scripts/check.sh full` passes with no new warnings.

## Status

`manifest.xml` still lists devices from every tier except `fr55`, which is more than has been checked. Update this table and the README "Supported products" list as devices are verified or dropped.

Manual simulator launches (`./monkeyInstall <device>`), reported by the maintainer:

| Date | Device | Tier | Result |
| --- | --- | --- | --- |
| 2026-11-04 | `fenix7s` | A | PASS |
| 2026-11-04 | `vivoactive6` | A | PASS |
| 2026-11-04 | `fenix6pro` | B | PASS |
| 2026-11-04 | `vivoactive4` | C | PASS after fixes: logo load made optional (it first failed with `Invalid Resource Specified`; root cause unknown), and tap-to-scroll navigation added (see "Device-specific behavior"). No glance is expected on this device. |

`fenix7xpro` and `fenix847mm`: the glance shows the interval; the other checks are not recorded here yet.

The automated smoke tests (`source/tests/StartupTest.mc`) pass on every device except those where the simulator hung, but they do not reproduce device memory limits or the glance process, so they do not replace the manual launches.

## Device-specific behavior

### Connect IQ 3.x touch devices (`venu`, `vivoactive4`, `vivoactive4s`)

Navigation differs from every other device. Found with the `vivoactive4` simulator on 2026-11-04:

- A tap on the screen reaches the app only as `onSelect`. `onTap`, `onKey`, `onRelease` and `onHold` are never delivered, so the app cannot know where the screen was tapped. Tap zones (top/middle/bottom) were tried and cannot work.
- A vertical drag arrives as `onDrag` followed by `onFlick`, and the system then **exits the widget** even when the app handles the flick and pushes a view. The sequence logged was `onFlick`, `onNextPage`, `onHide`, `onStop`. So vertical swipes cannot be used on these devices.
- `FlickEvent.getDirection()` returns an angle in degrees (observed: 0 for up, 180 for down), not a `WatchUi.SWIPE_*` constant. Remember this if flicks are ever handled.
- These devices have no glance (Connect IQ 3.3), so `getGlanceView()` is not used there.

What the app does instead: `TibberTouchScroll.isEnabled()` (`source/delegates/TouchScroll.mc`) is true on a touchscreen with no `WatchUi.GlanceView` class. When true, a tap (`onSelect`) scrolls through the screens: main, quarter-hour graph, hourly graph, then back to main. Tap does not refresh there; the price refreshes when the main screen is shown. Every other device keeps the default input. The check is a runtime capability test, not a list of device ids, so other devices with the same limits get the same behavior.

Known gaps on these devices: no way to open settings, and no manual refresh. Add a settings entry point (for example once a long-press is confirmed to reach the app) if they matter.

The simulator may differ from a real watch. Confirm on hardware when possible.

### Resources

- `WidgetView` loads the logo through `loadWidgetLogo()`, which draws without it if the device rejects the bitmap (seen on `vivoactive4` in the simulator).

## Memory design notes

- Glance code and resources must be annotated `(:glance)` / `scope="glance"` or the whole app is loaded into the glance process (a build warning says so). The glance classes are `TibberApp`, `TibberGlanceView`, `TibberPriceCache`, `TibberHourLevelBar`, `Theme` and `TibberCurrency`.
- Missing a glance dependency is not a compile error. It fails at runtime with `Symbol Not Found` or an `Illegal Access` error for `Rez`. Test the glance on a device after touching those classes.
- The glance loads the Poppins bitmap fonts only when at least 40000 bytes of glance heap are free (`POPPINS_MIN_FREE_BYTES` in `GlanceView.mc`); otherwise it uses system fonts. Measured free heap in the glance on 2026-11-04: `fenix7xpro` 44696 (Poppins, confirmed), `fenix6pro` 8416 (system fonts, confirmed). Re-measure before lowering the threshold.
- `WidgetView` loads the Medium and Large fonts on first use, not at startup.
- Tier B's placeholder glance is meant to be done at build time (for example `fenix6pro.excludeAnnotations = glanceFull` in `monkey.jungle`), so the price code is not loaded at all. A runtime check would still load that code.

## Regenerating the memory table

```sh
cd "$HOME/Library/Application Support/Garmin/ConnectIQ/Devices"
python3 -I - <<'EOF'
import json, re
ids = re.findall(r'iq:product id="([^"]+)"', open('/path/to/tibber/manifest.xml').read())
for i in ids:
    j = json.load(open(f"{i}/compiler.json"))
    lim = {a['type']: a['memoryLimit'] // 1024 for a in j['appTypes']}
    print(i, j['partNumbers'][0]['connectIQVersion'], lim.get('glance', 0), lim.get('watchApp', 0), lim.get('widget', 0))
EOF
```

Columns: device, Connect IQ version, glance, watchApp, widget (KB). Devices removed from the manifest are not listed by this snippet; read their `compiler.json` directly.
