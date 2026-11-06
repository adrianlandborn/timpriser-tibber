# Connect IQ Store Release Readiness

Status snapshot: 2026-11-03. Version 1.0.0 has been submitted to the Connect IQ Store and is awaiting review. Store requirements can change; recheck the linked official guidance if review feedback arrives.

## Authentication Decision (open risk)

Store users create a personal Tibber token at developer.tibber.com and paste it into the **Tibber API token** app setting in Garmin Connect (`resources/settings/settings.xml`). The watch shows a prompt until a token is set. Release builds (`monkey-release.jungle`, `scripts/release.sh`) swap the local token class for an empty stub and check that the developer's token is not in the package.

Tibber distinguishes personal access tokens from distributed apps, which should register an OAuth client. Whether the personal-token model is acceptable for a distributed app has **not been confirmed with Tibber**. This is the main remaining risk: if Garmin or Tibber objects during review, the fallback is the OAuth path:

1. Register a Tibber OAuth client; confirm redirect URI, scopes, token lifetime, refresh flow and PKCE/public-client support.
2. If a client secret is required, add a small backend for code exchange and refresh (secrets and refresh tokens stay server-side).
3. Use `Communications.makeOAuthRequest()` for a **Connect Tibber** flow with connect/reconnect/disconnect and clear error states.
4. Never ask for Tibber usernames or passwords.

## Done

- [x] Release build that excludes the developer token (`scripts/release.sh`, `release/config/ReleaseSecrets.mc`).
- [x] User token setting and "enter token" prompt.
- [x] Manifest languages: `swe` and `eng` shipped in 1.0.0. `nob`, `deu` and `dut` are in the repo for the next release.
- [x] Store assets: cover, hero, icons and screenshots in `docs/store/`.
- [x] Non-affiliation disclaimer, MIT license, Poppins OFL license (`resources/fonts/OFL.txt`).
- [x] Request logging does not print real tokens (only endpoint/request kind; the mock path prints a fake token).
- [x] Submitted v1.0.0 for review.

## Open Items

- [ ] **Privacy notice and support contact:** Garmin expects developers to provide their own privacy notice. The README "Data and privacy" section is developer-oriented. Publish a user-facing page (data read, token stored in Connect IQ settings on device/phone, cached prices on the watch, no backend, how to revoke the token) and link it with a support contact from the store listing.
- [ ] **Asset rights:** confirm the license/permission for `resources/lightning.svg` and the derived launcher/store artwork, and keep proof.
- [ ] **FR55 / small-device retest:** FR55 had historical daily-price failures; verify cold start, graph, glance and memory on FR55, Fenix 7S and Vivoactive 4.
- [ ] **Clean-install test:** install via the normal Connect IQ path with a non-developer Tibber account and verify onboarding, wrong/empty token and revoked-token messages.
- [ ] **Edge cases:** no homes, multiple homes, no active subscription, unavailable tomorrow prices, midnight and DST boundaries, offline and rate-limit behavior.
- [ ] **Tibber policy:** ask Tibber whether the personal-token model is acceptable for a distributed app (see above).
- [ ] **Release record:** note the submitted package version and product list, and the support/rollback plan.
- [ ] **No CI:** there is no CI or release workflow; releases are prepared locally via `scripts/release-prepare.sh` (see `docs/RELEASING.md`), by design, so the signing key stays on this machine.

## If Review Feedback Arrives

Fix, bump `version` in `manifest.xml`, run `scripts/check.sh full` and `scripts/release.sh`, then resubmit.

## Official References

- [Garmin: Submit an App](https://developer.garmin.com/connect-iq/submit-an-app/)
- [Garmin: App Review Guidelines](https://developer.garmin.com/connect-iq/app-review-guidelines/)
- [Garmin: Communications API](https://developer.garmin.com/connect-iq/api-docs/Toybox/Communications.html)
- [Garmin: Application Properties](https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/Properties.html)
- [Tibber: Communicating with the API](https://developer.tibber.com/docs/guides/calling-api)
- [Tibber: API overview](https://developer.tibber.com/docs/overview)
- [Tibber: GraphQL schema reference](https://developer.tibber.com/docs/reference)
