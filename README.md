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
cp source/TibberSecrets.mc.example source/TibberSecrets.mc
```

Set your token as the return value of `TibberSecrets.getApiToken()` in `source/TibberSecrets.mc`. That local file is ignored. Never put a real token in the template or commit it. The app sends authenticated HTTPS POST requests to Tibber and requests current price data when opened; refresh is available from the watch controls.

## Build

From the project root, compile a target with the installed SDK's Monkey C compiler:

```sh
monkeyc -f monkey.jungle -o /tmp/TibberWidget.prg -y developer_key.der -d fenix6
```

Replace `fenix6` with a supported product ID below. If `monkeyc` is not on `PATH`, invoke it by its full path under the installed SDK's `bin/` directory. The Garmin Monkey C extension can also build the project and launch it in the Connect IQ simulator. Keep build output outside the repository or in ignored generated-output directories.

## Run in the simulator

On macOS, start the Connect IQ simulator from a terminal:

```sh
connectiq
```

Once the simulator is open, use a second terminal from the project root to load the existing Fenix 7X Pro build:

```sh
monkeydo bin/TibberWidget-fenix7xpro.prg fenix7xpro
```

To run a fresh build instead, compile for the same device and pass the output package to `monkeydo`:

```sh
monkeyc -f monkey.jungle -o bin/TibberWidget-fenix7xpro.prg -y developer_key.der -d fenix7xpro
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

The graph plots Tibber's `today` series and appends `tomorrow` for its second page when available. Each interval keeps its ISO `starts_at`, local `start_time`, timestamp-based plot offset, `duration_minutes`, numeric and formatted price, currency, and level. A typical quarter-hour day contains 96 intervals, though daylight-saving transitions can change the count.

## Project layout

- `source/TibberApp.mc`: widget application entry point
- `source/TibberWidgetView.mc` and `source/TibberWidgetDelegate.mc`: active widget view and input handling
- `source/TibberPriceGraphView.mc` and `source/TibberPriceGraphDelegate.mc`: two-page price graph and navigation
- `source/TibberPriceChart.mc`: reusable, rendering-only step chart
- `source/TibberApiClient.mc`: Tibber GraphQL requests, response parsing, and error handling
- `source/TibberSecrets.mc.example`: token-free local configuration template
- `experiments/`: standalone test apps and archived legacy views/delegates excluded from production builds
- `experiments/legacy/`: older views/delegates and their backups retained for reference
- `resources/`: application strings and launcher icon

## Data and privacy

The access token is sent only to Tibber's GraphQL endpoint over HTTPS. Use a personal access token only for your own account; a distributed app should use Tibber's OAuth flow rather than embedding a personal token. Follow Tibber's API terms and applicable privacy requirements.