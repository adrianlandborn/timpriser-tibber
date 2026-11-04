---
name: localization
description: "Add or change translated UI strings. Use when: editing resources*/strings/strings.xml, adding a language to manifest.xml iq:languages, or adding any user-visible text."
---

# Localization

Currency units (öre/øre/cent) are not translated: they come from the API currency via `TibberCurrency.unitLabel` (`source/network/Currency.mc`), never from `strings.xml`, so the watch language cannot change them.

Swedish is the default (`resources/strings/strings.xml`); English lives in `resources-eng/strings/strings.xml`. Other languages follow the same `resources-<iso3>/strings/` pattern plus an `iq:language` entry in `manifest.xml`.

## Procedure

1. Add the string to `resources/strings/strings.xml` first, then to every other language file with the same `id`. `scripts/check.sh fast` fails if IDs differ.
2. Translation is mechanical work: use the cheapest model available. In Claude Code, delegate it to a subagent with `model: haiku` and pass only the XML file(s) and the rules below; do not translate with the main model.
3. Review the result yourself for placeholders, `&amp;` escapes and meaning, then run `scripts/check.sh fast`.
4. Run `scripts/build.sh vivoactive4 fenix7xpro` after adding long strings.

## Rules for translators

- Keep IDs, `&amp;`, leading/trailing spaces (e.g. `StatusSeparator`, `ErrorHttpPrefix`) and units (`öre`, `kWh`, `%`) unchanged.
- Match the original's length or shorter: small displays (`vivoactive4`) clip long text.
- Keep Tibber and Swedish grid/tax terms accurate (nätavgift = grid fee, energiskatt = energy tax).
- Poppins bitmap fonts only cover the characters already used; check `tools/build_poppins_price_font.py` before adding new glyphs (e.g. other accents).
