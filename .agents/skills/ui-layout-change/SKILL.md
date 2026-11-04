---
name: ui-layout-change
description: "Change screens, charts, components, fonts or layout of the watch UI. Use when: editing source/screens, source/charts, source/components, source/theme, resources fonts/strings/drawables, monkey.jungle resource paths, or fixing clipping/overlap on round, small, AMOLED or large-font devices."
---

# UI and layout changes

## Constraints

- Screens range from small MIP watches (`vivoactive4`) to large AMOLED (`fenix847mm`, `fenix9prosolar51mm`). Derive positions from `dc.getWidth()/getHeight()` and `dc.getFontHeight()`; no per-device pixel constants.
- Fonts are custom Poppins bitmap fonts with identical resource IDs in `resources/` (standard) and `resources-large/` (large profile, `fenix847mm` via `monkey.jungle`). Never edit `.fnt`/`_0.png` by hand; regenerate with `python3 tools/build_poppins_price_font.py [--profile large]`.
- Colors come from `source/theme/Theme.mc`. Chart geometry constants live at the top of `source/charts/PriceChart.mc`.
- UI text in `resources/strings/strings.xml` (Swedish).
- Input differs by device class: older touch-only devices (`venu`, `vivoactive4`) deliver taps only as `onSelect` and exit the widget on vertical swipes, so a tap scrolls through screens there. See [docs/device-tiers.md](../../../docs/device-tiers.md) before changing delegates.
- Glance (`GlanceView`) has a tight memory limit on small devices; keep it lean.
- Physical buttons and touch must both work (see README "Controls").

## Procedure

1. Change the code. For chart or settings layout, update the layout tests in `source/tests/PriceChartTest.mc` or `WidgetSettingsTest.mc`. They use fake `Dc` classes, so no real rendering is needed.
2. `scripts/build.sh fenix7xpro fenix847mm vivoactive4` to cover standard fonts, the large-font AMOLED profile, and a small target.
3. `scripts/check.sh full`.
4. Visual check is a human step: ask the user to run `./monkeyInstall <device>` (for example `fenix7xpro`, `fenix847mm`, `vivoactive4`) and confirm. Don't claim visual correctness you couldn't observe.
5. If the UI visibly changed, mention that the `docs/screenshots/` may need refreshing (human step).
