# Connect IQ Store Release Readiness

Status snapshot: 2026-10-24. This checklist reflects the current repository and the published Garmin and Tibber documentation. Store requirements can change; recheck the linked official guidance before submission.

## Release Decision: Authentication

The current app reads a local token from `TibberSecrets.getApiToken()` in `source/config/Secrets.mc`. That is suitable for local development only; the developer's personal token must never be included in a Store package.

Tibber explicitly distinguishes personal access tokens from distributed applications: a personal token accesses only its owner's data, while a distributed third-party app should register a Tibber OAuth client. Therefore, **do not plan to ship a settings field that asks every customer to paste a personal token unless Tibber confirms that distribution model is acceptable**. Do not ask for Tibber usernames or passwords.

Recommended implementation path:

1. Register a Tibber OAuth client for the app and confirm its allowed redirect URI, scopes, token lifetime, refresh flow, and whether a public client/PKCE flow is supported.
2. Confirm with Tibber whether its token exchange can be completed securely from a Connect IQ app. Garmin's `Communications.makeOAuthRequest()` can initiate phone-assisted OAuth, but it does not make it safe to embed a confidential client secret in the watch binary.
3. If Tibber requires a confidential client secret, implement a small backend for the authorization-code exchange and token refresh. Keep the secret and refresh tokens server-side; define hosting, availability, privacy, and support responsibilities before release.
4. Add a user-facing **Connect Tibber** flow, connection state, reconnect/disconnect controls, and clear messages for cancellation, expired/revoked access, missing home scope, and network failure.
5. Replace the local-only `TibberSecrets` implementation with the production token provider. Verify that no developer token or client secret is present in exported `.iq` files or logs.

Garmin Connect IQ settings are appropriate for non-secret preferences such as price mode or interval. They are not the recommended production substitute for Tibber's OAuth authorization. If Tibber explicitly approves a personal-token onboarding model, use a clearly labelled Connect IQ app setting, explain how users create/revoke the token, store it only as necessary, and never log it. Do not add this fallback before confirming Tibber's policy.

## P0: Required Before Submission

- [ ] **Production authentication:** complete the OAuth decision above; no local `Secrets.mc`, personal developer token, client secret, or placeholder token in the release package.
- [ ] **OAuth failure and lifecycle:** test user cancellation, denied scopes, invalid/revoked access, refresh or reauthorization, disconnect, and app restart. Remove user tokens and cached user price data on disconnect.
- [ ] **Data-access scope:** request only the Tibber home-reading scopes required by the GraphQL queries. Verify behavior for no homes, multiple homes, no active subscription, and missing price data.
- [ ] **Privacy notice and support:** publish a privacy notice and support contact. Describe data read, where tokens and cached prices are stored, whether a backend receives data, retention/deletion behavior, and how users disconnect. Garmin says developers must provide their own privacy notice for data they process.
- [ ] **Asset rights:** verify the license/permission for `resources/lightning.svg` and the derived launcher/widget artwork; retain proof or replace the asset before submission. Also verify all bundled font assets and retain their license notices.
- [ ] **Store listing:** prepare accurate app name, Swedish/English descriptions, supported-device list, screenshots, setup/auth instructions, limitations, and support contact. Do not imply Garmin or Tibber endorsement.
- [ ] **Export and signing:** export the Connect IQ `.iq` package using Garmin's Monkey C extension/export workflow for every declared product. Confirm the package uses the release version and contains no signing key, local secrets, debug files, or development-only data.

## P1: Product and Reliability Checks

- [ ] **Manifest and language:** decide the release language set and align `manifest.xml`, localized strings, UI copy, and store metadata. The current manifest declares English while much of the interface is Swedish.
- [ ] **Device support:** confirm each product in `manifest.xml` against installed SDK device packs and actual runtime behavior. Current declared products are Fenix 6/7 variants, Venu, Forerunner 55, and Vivoactive 4.
- [ ] **Small-device layout:** visually verify every screen and glance on FR55 and Fenix 7S as well as Fenix 7X Pro. Check clipping, scroll selection, switch/segment focus, chart labels, and cache/error states.
- [ ] **Input/navigation:** verify UP/DOWN cycles among main widget and graph pages as documented; START/STOP refreshes the active screen; BACK returns/exits; touch actions match the same behavior where supported.
- [ ] **Price correctness:** verify total vs spot selection, currency conversion (including SEK to öre), tax/moms and network-fee labels, quarter-hour/hourly intervals, and chart footer/legend match the selected mode.
- [ ] **Time boundaries:** test cache reuse across interval boundaries, midnight, daylight-saving changes, unavailable tomorrow prices, and changes to selected price mode/resolution. Never show a prior interval as current when the needed cache entry is absent.
- [ ] **API resilience:** test HTTP and GraphQL errors, malformed/empty payloads, offline behavior, rate limits, and repeated opens. Tibber asks clients to set a descriptive User-Agent and use jitter/exponential backoff for retries; avoid repeatedly fetching prices that are already cached.
- [ ] **Memory/runtime:** measure peak memory and launch stability on the lowest-memory supported device, especially FR55. Confirm no crashes when opening the graph or glance after a cold start.
- [ ] **No debug output:** keep only intentional endpoint/request diagnostics for development; remove verbose traces and ensure authorization headers/tokens are never logged in a release build.

## P2: Release Process

- [ ] Set the release version and verify the manifest application ID/name/product list.
- [ ] Run clean builds for every declared product, not just representative devices.
- [ ] Install the exported `.iq` package through the normal Connect IQ distribution path and test onboarding on a clean install with a non-developer Tibber account.
- [ ] Capture final screenshots from supported watch profiles and review them at store size.
- [ ] Complete Garmin's current app review/submission workflow and respond to review feedback.
- [ ] Record the submitted package version, supported products, OAuth client configuration owner, and rollback/support plan.

## Current Repository Gaps

- `source/config/Secrets.mc` is local and ignored; production authentication is not implemented.
- No Connect IQ settings XML or OAuth onboarding UI is present.
- The manifest currently declares `eng`, despite Swedish UI strings.
- No CI/release workflow or store-export checklist is present in the repository.
- Runtime coverage is not yet equivalent to the full declared-device matrix; FR55 has had historical daily-price failures that must be retested.
- The lightning artwork's license has not been verified.

## Official References

- [Garmin: Submit an App](https://developer.garmin.com/connect-iq/submit-an-app/)
- [Garmin: App Review Guidelines](https://developer.garmin.com/connect-iq/app-review-guidelines/)
- [Garmin: Communications API](https://developer.garmin.com/connect-iq/api-docs/Toybox/Communications.html)
- [Garmin: Application Properties](https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/Properties.html)
- [Tibber: Communicating with the API](https://developer.tibber.com/docs/guides/calling-api)
- [Tibber: API overview](https://developer.tibber.com/docs/overview)
- [Tibber: GraphQL schema reference](https://developer.tibber.com/docs/reference)