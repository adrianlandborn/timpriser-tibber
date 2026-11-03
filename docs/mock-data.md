# Testing with mock data (NO / DE / NL / SE)

The widget can answer from built-in fake Tibber data, so you can try Norwegian, German and Dutch
contracts in the simulator without an account in those countries. No network request is made.

Two things are independent and you combine them yourself:

| What | Where it comes from | How you set it in the simulator |
| --- | --- | --- |
| **Country / currency / prices** | The Tibber API (here: the mock) | The mock **token** (below) |
| **UI language** | The watch language | The simulator's language setting |

A Swedish contract on a German watch is therefore `mock-se` + German, and must still show `öre`.

## 1. Pick a scenario with the token

Enter one of these as the **Tibber API token**:

| Token | Currency shown | Meaning |
| --- | --- | --- |
| `mock-se` | öre (SEK) | Swedish contract. Grid fees / energy tax available |
| `mock-no` | øre (NOK) | Norwegian contract. Tibber's own price only |
| `mock-de` | cent (EUR) | German contract. Tibber's own price only |
| `mock-nl` | cent (EUR) | Dutch contract. Tibber's own price only |
| `mock-us` | `USD` | Unknown currency: raw code, no minor-unit conversion |

Append `-today` (e.g. `mock-no-today`) to leave out tomorrow's prices and see the "tomorrow missing" state.

Both resolutions work (hourly = 24 prices, 15 min = 96 prices per day). Prices are generated around
the current date and clock, so "now", the price graph and the hour bar always line up. Total prices use a
plausible per-country VAT/tax markup; the numbers are fake and only meant for checking layout and units.

### Where to enter the token

Pick one:

- **Simulator app settings (no files touched):** run the widget, then in the simulator open the
  application settings editor (menu `File → Edit Persistent Storage → Edit Application.Properties`; the exact
  menu name differs slightly between SDK versions) and set `tibberToken` to e.g. `mock-no`.
  Then restart the app (or choose the menu entry that applies the settings).
- **Local `source/config/Secrets.mc` (git-ignored):** make `getApiToken()` return `"mock-no"`. An app
  setting that is non-empty takes precedence over this file, so leave the setting empty.

Do not commit the token change; `Secrets.mc` is ignored by git.

## 2. Pick the watch language

In the simulator set the device language (menu `Settings → Language`, or the equivalent for your SDK
version) to `Deutsch`, `Norsk bokmål` or `Nederlands`. Anything else falls back to Swedish (default) or English.

## 3. Run

Run the widget in the simulator as usual (VS Code: *Run Without Debugging* on a device, e.g. `fenix7xpro`;
check `fr55` and `fenix847mm` too, since German labels are the longest). The console prints
`Tibber MOCK <token> <kind> <resolution>` for each simulated request.

## What to look for

- Unit follows the **contract**, not the language: `mock-se` + German watch → `öre`; `mock-de` + Swedish watch → `cent`.
- NO/DE/NL: the settings screen only shows the price-type and interval controls (no grid fees / energy tax),
  and the status line reads "As per Tibber" (localized) instead of "Taxes incl. | Grid excl.".
- `mock-se`: grid fees / energy tax behave as before.
- Long German/Dutch labels do not clip on small displays.

## Good to know

- While a `mock-` token is active the price cache is bypassed. When you switch back to a real token, all
  app Storage is cleared **once** (this also resets the price type, fee settings and interval), so mock
  prices are never shown as real ones.
- The mock is development-only. The store build (`monkey-release.jungle`, `scripts/release.sh`) replaces
  `source/mock/TibberMock.mc` with the stub `release/config/ReleaseMock.mc`, which never activates, so a
  `mock-…` token on a shipped app is just sent to Tibber and rejected.
- Code: `source/mock/TibberMock.mc` (scenarios and data), hook in `source/network/ApiClient.mc`
  (`makeRequest`, `onMockResponse`). Unit tests: `source/tests/CurrencyTest.mc` (`testMock…`).
