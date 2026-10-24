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