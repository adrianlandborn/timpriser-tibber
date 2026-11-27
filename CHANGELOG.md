# Changelog

## Unreleased

- Shorter, clearer error messages that say what to fix, such as a missing or invalid Tibber token, no phone connection or Tibber being unavailable.
- The compact screen on watches without glances shows "Token missing" until a token is entered, and the glance shows "Open the app" when there is no price yet.
- A token that is obviously mistyped (too short or containing spaces) is reported before contacting Tibber.
- The glance now fetches today's prices by itself when it has none, so you no longer need to open the app first each day. It only fetches when the glance is shown and prices are missing, never on a schedule. Not available on Fenix 6 Pro, Forerunner 245 Music/745/945, Descent Mk2 and MARQ (first generation), where the glance has too little memory; there it still shows "Open the app".

## 1.2.0 - 2026-11-11

- Launcher icon is now sized for each device, so it is sharper and uses less memory on smaller devices.
- Support for Fenix 5X (`fenix5x`).
- The price graph is roomier on small-screen watches (240 px and below): the title shows only "15 MIN" or "1 HOUR", the "tomorrow missing" note is hidden, and there are fewer axis labels, no time range under the price and less padding, so the graph is larger.
- Watches without glances (Fenix 5X, Fenix 5 Plus series, Forerunner 645 Music, Vivoactive 3/4, Venu and similar) now start on a compact price screen. Press START (or tap) to open the full widget, where UP/DOWN move between the price and the graphs. BACK returns to the compact screen. The Fenix 5 series and Forerunner 645 Music use the watch's built-in fonts, so text displays correctly.

## 1.1.0 - 2026-11-05

- Support for about 50 more devices, including Forerunner 245/255/745/945/955/965/970, Fenix 5 Plus and Fenix E, Descent, Enduro 3, Marq, Venu 2/4/Sq 2/X1, Vivoactive 3 Music, Instinct 3 AMOLED/Crossover AMOLED, and Approach S50/S70.
- Support for Norwegian, German and Dutch contracts and their currencies. Network fees and energy tax are only applied for Swedish contracts.
- Defaults (price type, price interval, grid fees, energy tax) can now be set from the Garmin Connect app. The most recent change, from phone or watch, wins.
- Older touch-only devices (Vivoactive 3 Music, Vivoactive 4/4S, Venu, Venu Sq Music and the Legacy Marvel/Star Wars editions): tap to scroll through the screens.
- Fixed the glance showing empty boxes instead of the "Open Tibber" text when no price is cached.
- Fixed several crashes and display inconsistencies.
- Visual improvements and color changes.

## 1.0.0

- Initial Connect IQ Store release: Tibber prices with network fees and energy tax, price chart, glance, Swedish/English/Norwegian/German/Dutch.
