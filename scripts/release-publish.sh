#!/usr/bin/env bash
# Create a GitHub Release for an existing tag, using the CHANGELOG.md entry as notes
# and attaching the packaged .iq as an archive of what was shipped.
#
# Usage: scripts/release-publish.sh <version> [--no-asset]     e.g. scripts/release-publish.sh 1.1.0
#   Run after 'git push origin main v<version>'. See docs/RELEASING.md.

source "$(dirname "$0")/lib.sh"
cd "$REPO_ROOT"

version="${1:-}"
echo "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || die "Usage: $0 <major.minor.patch> [--no-asset]"
tag="v$version"
asset=".cache/ciq/TibberWidget-$version.iq"

command -v gh >/dev/null || die "GitHub CLI (gh) not found."
git rev-parse -q --verify "refs/tags/$tag" >/dev/null || die "Tag $tag does not exist; run scripts/release-prepare.sh first."
git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null 2>&1 || die "Tag $tag is not pushed; run 'git push origin main $tag' first."

# Notes = the "## <version>" section of CHANGELOG.md, without its heading.
notes="$(mktemp)"
trap 'rm -f "$notes"' EXIT
awk -v v="$version" '
    /^## / { if (found) exit; if ($2 == v) { found = 1; next } }
    found { print }
' CHANGELOG.md | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' > "$notes"
[ -s "$notes" ] || die "No '## $version' section found in CHANGELOG.md."

args=(--title "$version" --notes-file "$notes" --verify-tag)
if [ "${2:-}" != "--no-asset" ]; then
    [ -f "$asset" ] || die "$asset missing; rebuild with scripts/release.sh or pass --no-asset."
    args+=("$asset")
fi

gh release create "$tag" "${args[@]}"
echo "OK   GitHub Release $tag created."
