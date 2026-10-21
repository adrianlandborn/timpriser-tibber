# Tibber Energy Widget for Connect IQ

A Garmin Connect IQ widget prototype for displaying Tibber electricity prices. The current data callbacks return mock values; live GraphQL request code is present but disabled.

## Requirements

- Garmin Connect IQ SDK 9.3.0 or newer, with device packs for the selected target
- Garmin Monkey C VS Code extension (optional if using the SDK command line)
- A local Garmin developer signing key (`developer_key.der`) for compilation
- A Tibber API token only if live API requests are enabled

The application minimum API version is 3.2.0 for compatibility with retained older devices. Fenix 7 products have a higher device API baseline.

## Configure local credentials

Signing keys and local credentials are not stored in Git. Keep `developer_key.der` in the project root as a local file; `.gitignore` excludes it.

The current app uses mock data, so a Tibber token is not needed to build or run it. If enabling the live request path, create a local secrets source from the template:

```sh
cp source/TibberSecrets.mc.example source/TibberSecrets.mc
```

Then return your token from `TibberSecrets.getApiToken()` in `source/TibberSecrets.mc`. That local file is ignored. Never put a real token in the template or commit it.

## Build

From the project root, compile a target with the installed SDK's Monkey C compiler:

```sh
monkeyc -f monkey.jungle -o /tmp/TibberWidget.prg -y developer_key.der -d fenix6
```

Replace `fenix6` with a supported product ID below. If `monkeyc` is not on `PATH`, invoke it by its full path under the installed SDK's `bin/` directory. The Garmin Monkey C extension can also build the project and launch it in the Connect IQ simulator. Keep build output outside the repository or in ignored generated-output directories.

## Supported products

- Fenix 6: `fenix6`, `fenix6pro`
- Fenix 7: `fenix7`, `fenix7s`, `fenix7x`
- Fenix 7 Pro: `fenix7pro`, `fenix7spro`, `fenix7xpro`
- Fenix 7 Pro Solar (no Wi-Fi): `fenix7pronowifi`, `fenix7xpronowifi`
- Venu: `venu`
- Forerunner 55: `fr55`
- Vivoactive 4: `vivoactive4`

The Fenix 7 products are declared in the manifest. A device pack must be installed to compile or simulate its specific target.

## Project layout

- `source/TibberApp.mc`: widget application entry point
- `source/TibberWidgetView.mc` and `source/TibberWidgetDelegate.mc`: active widget view and input handling
- `source/TibberApiClient.mc`: mock data and disabled live API request implementation
- `source/TibberSecrets.mc.example`: token-free local configuration template
- `experiments/`: standalone test apps and archived legacy views/delegates excluded from production builds
- `experiments/legacy/`: older views/delegates and their backups retained for reference
- `resources/`: application strings and launcher icon

## Data and privacy

Mock data is returned by default. The disabled live request implementation sends a Tibber API token to Tibber's GraphQL endpoint. Only enable it for an account and device you control, and follow Tibber's API terms and applicable privacy requirements.