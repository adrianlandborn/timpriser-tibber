# Tibber Energy Widget for Connect IQ

A Garmin Connect IQ widget for displaying current Tibber electricity prices using the Tibber GraphQL API.

Press START/STOP to open the price graph and BACK to return. On the graph, UP shows today's quarter-hour prices and DOWN shows hourly prices for today plus tomorrow when available. START/STOP or MENU refreshes the active graph page. On the main screen, MENU toggles the current-price resolution.

## Requirements

- Garmin Connect IQ SDK 9.3.0 or newer, with device packs for the selected target
- Garmin Monkey C VS Code extension (optional if using the SDK command line)
- A local Garmin developer signing key (`developer_key.der`) for compilation
- A Tibber API access token with permission to read home data

The application minimum API version is 3.2.0 for compatibility with retained older devices. Fenix 7 products have a higher device API baseline.

## Configure local credentials

Signing keys and local credentials are not stored in Git. Keep `developer_key.der` in the project root as a local file; `.gitignore` excludes it.

Create a local secrets source from the template if one is not already present:

```sh
cp source/config/Secrets.mc.example source/config/Secrets.mc
```

Set your token as the return value of `TibberSecrets.getApiToken()` in `source/config/Secrets.mc`. That local file is ignored. Never put a real token in the template or commit it. The app sends authenticated HTTPS POST requests to Tibber and requests current price data when opened; refresh is available from the watch controls.

## Build

From the project root, compile a target with the installed SDK's Monkey C compiler:

```sh
monkeyc -f monkey.jungle -o /tmp/TibberWidget.prg -y developer_key.der -d fenix6
```

Replace `fenix6` with a supported product ID below. If `monkeyc` is not on `PATH`, invoke it by its full path under the installed SDK's `bin/` directory. The Garmin Monkey C extension can also build the project and launch it in the Connect IQ simulator. Keep build output outside the repository or in ignored generated-output directories.

## Run in the simulator

On macOS, start the Connect IQ simulator in one terminal and leave it open:

```sh
connectiq
```

Once the simulator is open, run the local `tibber-sim` alias in a second terminal. It changes to this project, removes the old package, compiles for Fenix 7X Pro, verifies and timestamps the new package, then launches that package:

```sh
tibber-sim
```

The alias is defined in `~/.zshrc`. After adding or changing it, reload it in an existing terminal with `source ~/.zshrc`; new terminals load it automatically. Its `cd` command should point to `<project_folder>`; update that path if your checkout is elsewhere.

Without the alias, build and run manually from the project root. Removing the old package first ensures a failed compile cannot leave an older build to launch:

```sh
rm -f bin/TibberWidget-fenix7xpro.prg &&
monkeyc -f monkey.jungle -o bin/TibberWidget-fenix7xpro.prg -y developer_key.der -d fenix7xpro &&
test -s bin/TibberWidget-fenix7xpro.prg &&
stat -f 'Compiled: %Sm %N' bin/TibberWidget-fenix7xpro.prg &&
monkeydo bin/TibberWidget-fenix7xpro.prg fenix7xpro
```

If `connectiq`, `monkeyc`, or `monkeydo` is not on `PATH`, invoke the command from the installed SDK's `bin/` directory. Keep the simulator open while launching the package.

## Supported products

- Fenix 6: `fenix6`, `fenix6pro`
- Fenix 7: `fenix7`, `fenix7s`, `fenix7x`
- Fenix 7 Pro: `fenix7pro`, `fenix7spro`, `fenix7xpro`
- Fenix 7 Pro Solar (no Wi-Fi): `fenix7pronowifi`, `fenix7xpronowifi`
- Venu: `venu`
- Forerunner 55: `fr55`
- Vivoactive 4: `vivoactive4`

The Fenix 7 products are declared in the manifest. A device pack must be installed to compile or simulate its specific target.

## Price intervals

The main screen defaults to Tibber's `QUARTER_HOURLY` resolution. Its MENU button toggles between `QUARTER_HOURLY` and `HOURLY`. The graph pages use fixed resolutions: `QUARTER_HOURLY` for today, then `HOURLY` for today and tomorrow. If tomorrow's prices are not published yet, the second page shows today's hourly prices and an availability note. Both `getCurrentPrice(callback, resolution)` and `getDailyPrices(callback, resolution, includeTomorrow)` accept a resolution.

The graph plots Tibber's `today` series and appends `tomorrow` for its second page when available. Its compact interval data stores timestamp-based plot offsets and numeric price values, with resolution and currency kept once per series to limit memory use on smaller watches. A typical quarter-hour day contains 96 intervals, though daylight-saving transitions can change the count.

## Typography

All app-drawn text uses bundled Poppins SemiBold bitmap fonts sized for watch displays, including Swedish characters and common symbols. The font is from Google Fonts and is distributed under the SIL Open Font License 1.1; see `resources/fonts/OFL.txt`. Rebuild the font resources after changing the source font with `python3 tools/build_poppins_price_font.py`.

## Project layout

- `source/app/App.mc`: application lifecycle and entry point
- `source/screens/`: `WidgetView.mc` and `PriceGraphView.mc`
- `source/delegates/`: `WidgetDelegate.mc` and `PriceGraphDelegate.mc`
- `source/network/ApiClient.mc`: Tibber GraphQL requests and response parsing
- `source/config/`: local secrets source and token-free template
- `source/charts/PriceChart.mc`: reusable, rendering-only price chart
- `experiments/`: standalone test apps and archived legacy views/delegates excluded from production builds
- `experiments/legacy/`: older views/delegates and their backups retained for reference
- `resources/`: application strings and launcher icon

## Data and privacy

The access token is sent only to Tibber's GraphQL endpoint over HTTPS. Use a personal access token only for your own account; a distributed app should use Tibber's OAuth flow rather than embedding a personal token. Follow Tibber's API terms and applicable privacy requirements.