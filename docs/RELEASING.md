# Releasing to the Connect IQ Store

Releases are prepared locally; the signing key never leaves the machine. The store has no upload API, so the upload is manual.

## Where release history lives

- **`CHANGELOG.md` is the single source of truth.** Every released version keeps its own `## X.Y.Z - YYYY-MM-DD` section, newest first. Never delete old sections.
- Between releases, collect user-visible changes under `## X.Y.Z (unreleased)`. During step 1 that section becomes the dated release entry.
- Entries are public: describe what users get, not how it was done (no script names, tooling or internal docs).
- The same entry is reused for the store release notes (step 3) and the GitHub Release (step 5). Do not write separate notes.

## 1. Prepare (automated)

```sh
scripts/release-prepare.sh 1.1.0
```

This requires a clean `main` and a version greater than the last `vX.Y.Z` tag, then:

1. runs `scripts/check.sh full` (lint, 3-device build, simulator tests);
2. bumps `version` in `manifest.xml`;
3. prepends a `CHANGELOG.md` entry from commit subjects since the last tag and pauses so you can edit it;
4. runs `scripts/release.sh` (token-less `.iq` build plus leak check, writes `dist/TibberWidget-<version>.iq`);
5. commits `Release <version>` and creates an annotated tag `v<version>`.

**At the pause in step 3 of the script**, open `CHANGELOG.md` and:

- replace the generated commit-subject list with the curated bullets from the `(unreleased)` section;
- delete the now-empty `## X.Y.Z (unreleased)` heading, so the version appears only once, as `## X.Y.Z - YYYY-MM-DD`.

If a step fails, `manifest.xml` and `CHANGELOG.md` are restored. Nothing is pushed.

## 2. Release testing (manual)

- Install the `.prg`/`.iq` on at least one real watch (and FR55 or the simulator for the smallest profile). Check cold start, glance, graph, refresh, and the "enter token" prompt on a clean install with no token set.
- Enter a valid token via Garmin Connect settings; verify prices and a wrong-token error message.
- Also exercise whatever is new in this release (see the changelog entry).
- Review the open items in `RELEASE_READINESS.md` (in this folder).

## 3. Upload (manual)

1. In the [Connect IQ developer dashboard](https://apps.garmin.com/developer/) open the app, choose **Upload a New Version**, and upload `dist/TibberWidget-<version>.iq`.
2. Paste the `CHANGELOG.md` entry for this version as the release notes; update the description and screenshots (`docs/store/`) only if they changed.
3. Submit for review.

## 4. Publish the tag

```sh
git push origin main v<version>
```

Push only after the upload is submitted, so the tag matches what was shipped. If review requests changes, fix, then re-run with the next patch version.

## 5. GitHub Release (archive)

```sh
scripts/release-publish.sh <version>
```

Creates a GitHub Release for the pushed tag. The notes are the version's `CHANGELOG.md` section, and the `dist/TibberWidget-<version>.iq` is attached as a permanent record of exactly what was shipped (`dist/` is not tracked by git). The `.iq` is token-less and leak-checked in step 1, but if the repository is public the attachment is downloadable by anyone; pass `--no-asset` to publish notes only.

Requires the GitHub CLI (`gh`) to be authenticated. The script refuses to run if the tag is missing locally or not yet pushed, or if the changelog has no section for the version.
