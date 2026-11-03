# Releasing to the Connect IQ Store

Releases are prepared locally; the signing key never leaves the machine. The store has no upload API, so the upload is manual.

## 1. Prepare (automated)

```sh
scripts/release-prepare.sh 1.0.1
```

This requires a clean `main` and a version greater than the last `vX.Y.Z` tag, then:

1. runs `scripts/check.sh full` (lint, 3-device build, simulator tests);
2. bumps `version` in `manifest.xml`;
3. prepends a `CHANGELOG.md` entry from commit subjects since the last tag and pauses so you can edit it;
4. runs `scripts/release.sh` (token-less `.iq` build plus leak check, writes `.cache/ciq/TibberWidget-<version>.iq`);
5. commits `Release <version>` and creates an annotated tag `v<version>`.

If a step fails, `manifest.xml` and `CHANGELOG.md` are restored. Nothing is pushed.

## 2. Release testing (manual)

- Install the `.prg`/`.iq` on at least one real watch (and FR55 or the simulator for the smallest profile). Check cold start, glance, graph, refresh, and the "enter token" prompt on a clean install with no token set.
- Enter a valid token via Garmin Connect settings; verify prices and a wrong-token error message.
- Review the open items in `RELEASE_READINESS.md`.

## 3. Upload (manual)

1. In the [Connect IQ developer dashboard](https://apps.garmin.com/developer/) open the app, choose **Upload a New Version**, and upload `.cache/ciq/TibberWidget-<version>.iq`.
2. Paste the `CHANGELOG.md` entry as the release notes; update the description and screenshots (`docs/store/`) only if they changed.
3. Submit for review.

## 4. Publish the tag

```sh
git push origin main v<version>
```

Push only after the upload is submitted, so the tag matches what was shipped. If review requests changes, fix, then re-run with the next patch version.
