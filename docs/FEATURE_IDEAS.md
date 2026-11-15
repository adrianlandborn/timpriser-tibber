# Tibber Widget Feature Ideas

Research notes: 2026-10-23. These proposals are based on the current app, Tibber's public API documentation, and feature patterns from energy-management integrations. They do not include the existing current-price display, resolution toggle, or today's/tomorrow's price graphs.

## Main Widget

Keep the current price as the primary element. Treat the following as optional secondary information rather than trying to display everything at once.

1. **Cheap/expensive indicator** — Show Tibber's `Price.level` alongside the current price, for example `CHEAP`. The current client already requests `level` but does not display it. Low effort and no larger response needed. This is a comparison against Tibber's trailing average, not today's price range.
2. **Next price and change** — Show the next interval's price and whether it rises or falls, such as `Next 14:30: 82 öre · down 23`. Compare adjacent entries in `priceInfo.today`/`tomorrow`. Low-to-medium effort.
3. **Today's price position** — Add today's low, high, and duration-weighted average, then indicate where the current price sits. Uses the daily price series already fetched. Low-to-medium effort.
4. **Next cheap window** — Show the start of the next interval below a configurable price threshold. Scan upcoming published intervals and say when no suitable interval exists in the available forecast. Medium effort.
5. **Upcoming-price sparkline** — Display a compact trend for the next several hours, reusing the existing price series and charting approach. Medium effort; adapt the density and labels for smaller watches.

## New Screens

1. **Cheapest-Run Planner** — Find the cheapest continuous block for a chosen duration, optionally before a deadline. Show its average price and savings compared with starting now. Uses quarter-hourly `today`/`tomorrow` prices; no extra hardware. Medium effort and the recommended first new screen.
2. **Consumption and Cost Summary** — Show yesterday's kWh and energy cost, a seven-day trend, and month-to-date totals. Uses `Home.consumption` fields such as `consumption`, `cost`, and connection summary data. Medium effort, depending on account data availability. Readings can be delayed, and energy cost should not be presented as the complete electricity bill.
3. **Price History and Comparison** — Show recent prices and how today compares with recent days, adding historical context beyond the existing forecast screens. Use `currentSubscription.priceInfoRange`, preferably at daily resolution to keep requests small. Medium effort. Avoid deprecated `priceRating` and `priceInfo.range`.
4. **Live Home Power** — Show current watts, consumption since midnight, today's peak, and optionally solar export. GraphQL `liveMeasurement` exposes these fields for Pulse/Watty homes. High effort: the live stream needs a phone or backend bridge in this Garmin architecture. Mark readings with their age and handle missing fields.
5. **Connected Devices Overview** — Display available EV charging/battery, home battery, solar inverter, or heating-device state. Tibber's newer Data API exposes paired devices and capabilities. High effort: requires a separate OAuth2 client, the right scopes, supported paired devices, and defensive handling of varying device capabilities. Keep an initial implementation read-only; the Data API does not expose Tibber's proprietary optimization schedules.

## Graph Interaction (touch)

Status: idea, not scheduled. Origin: a user review asking to scrub the price graph and to choose the start screen. Analysed 2026-11-15; no code written.

1. **Scrub the graph** — Drag horizontally on the quarter-hour or hourly graph to move the marker and read price and interval from the existing footer. No new data or API calls: `_priceIntervals` is already in memory. Low-to-medium effort (about 100 lines plus tests).
   - Code touchpoints: `PriceChart.draw`/`drawCurrentMarker` take an optional selected minute (null = now); `PriceGraphView` holds the scrub state and a reset timer; `PriceGraphDelegate` gets a guarded `onDrag`. `onDrag` is API 3.3.0, above the 3.2.0 minimum, so guard with `WatchUi has :DragEvent` and type the parameter loosely.
   - UX: use relative dragging with snapping to the nearest interval. A finger covers about 40 px, and the quarter-hour chart has only about 1.7 px per interval on 240 px screens and about 3.5 px on 454 px screens (hourly chart: 3.4–7 px per hour), so tapping an absolute position is not precise enough. Make the scrubbed state obvious: accent-colored interval, a faint "now" dot and a hairline cursor.
   - Reset: timeout (about 8 s), tap or START, first BACK, page change and `onShow`. Clamp at both ends.
   - Gesture conflicts to verify on a real watch: a horizontal drag may end as swipeRight (BACK near the left edge) or, with a slight vertical wobble, as a page change. Swallow swipes shortly after a drag.
   - Device gating by capability, not size: `isTouchScreen && WatchUi has :DragEvent && !TibberTouchScroll.isEnabled()`. 53 of the 79 listed products have touch, including MIP touch devices (Fenix 7, Fenix 8/9 Solar, Enduro 3, Forerunner 955). Button-only devices are unaffected. Limiting it to 51 mm or AMOLED watches would exclude the Fenix 7 users who asked.
2. **Scrub on the main screen** (alternative, higher cost) — Drag over the flat hour-level bar to change the large price. The bar is 6 px high and holds 24 level codes, not prices, so this needs the daily cache on the main screen (memory risk on small devices) and one shared fee and tax calculation (today duplicated in `PriceGraphView.onPricesReceived` and `TibberPriceCache.getDisplayPrice`; follow the pricing-change rules). Tap on the main screen already refreshes the price, which conflicts with tap-to-reset. Build the graph version first.
3. **Start-screen choice** — A phone setting to open directly on the quarter-hour or hourly graph. Open the graph after the first `onShow`, not in `getInitialView`, otherwise BACK from a root graph exits the app. Confirm with the reviewer that this is what they meant.

## Inspiration and Sources

- [Tibber GraphQL API reference](https://developer.tibber.com/docs/reference) — Price, consumption, production, price range, and live-measurement schema.
- [Tibber API overview](https://developer.tibber.com/docs/overview) — GraphQL usage, daily price publication, caching guidance, and rate limit.
- [Tibber API changelog](https://developer.tibber.com/docs/changelog) — Quarter-hour prices and the newer `priceInfoRange` field. The changelog recommends fetching and caching daily prices rather than repeatedly requesting `current`.
- [Tibber Data API overview](https://data-api.tibber.com/docs/) — OAuth2 access to paired vehicles, chargers, thermostats, inverters, and batteries; device history and live events.
- [Home Assistant Tibber integration](https://www.home-assistant.io/integrations/tibber/) — Examples of accumulated consumption/cost, peak power, solar production, and device state sensors.
- [Cheapest Energy Hours](https://github.com/TheFes/cheapest-energy-hours) — Inspiration for scheduling a continuous appliance run: the cheapest single interval is not necessarily the cheapest block of the required duration.
- [Garmin Communications API](https://developer.garmin.com/connect-iq/api-docs/Toybox/Communications.html) — Connect IQ supports asynchronous web requests, but this app's Garmin-side architecture has no direct WebSocket client for Tibber's GraphQL subscription stream.

## Feasibility Notes

- Price-only features are the best fit for the existing API token and should be feasible across the declared watch range. Keep additional data compact, reuse fetched price arrays, and avoid loading duplicate fonts or chart data.
- Tibber supports both hourly and quarter-hourly price resolution. Consumption and production currently use separate resolutions; do not assume quarter-hourly consumption is available.
- Tomorrow's prices may not yet be published. Any planner or forecast display should show its available horizon and avoid implying predictions beyond it.
- Handle home time zones and daylight-saving transitions when finding interval boundaries and durations.
- Preserve small-watch layouts while adding information; keep the main price dominant and make secondary details optional or compact. Validate changes on both smaller devices and Fenix 7X-class displays.
- The FR55 daily-price loading issue has not been resolved, so keep it as a validation gate for any feature that increases price response size or processing.

## Suggested Order

1. Show the existing price-level rating.
2. Add the next interval and price change.
3. Build the cheapest continuous-run planner.
4. Add a compact consumption summary.
5. Consider live power and connected-device screens only after resolving the bridge, authentication, and compatibility requirements.
6. Touch scrubbing in the graphs and a start-screen choice: decide after the items above.