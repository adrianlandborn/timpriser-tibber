#!/usr/bin/env bash
# Prepare a store release locally: verify, bump version, changelog, build .iq, commit and tag.
#
# Usage: scripts/release-prepare.sh <version>      e.g. scripts/release-prepare.sh 1.0.1
#   Does not push and does not upload (the Connect IQ store has no upload API);
#   see docs/RELEASING.md for the remaining manual steps.

source "$(dirname "$0")/lib.sh"
cd "$REPO_ROOT"

version="${1:-}"
echo "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || die "Usage: $0 <major.minor.patch>"
tag="v$version"

[ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] || die "Release from main (currently $(git rev-parse --abbrev-ref HEAD))."
[ -z "$(git status --porcelain)" ] || die "Working tree not clean; commit or stash first."
git rev-parse -q --verify "refs/tags/$tag" >/dev/null && die "Tag $tag already exists."

last_tag="$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || true)"
if [ -n "$last_tag" ]; then
    newest="$(printf '%s\n%s\n' "${last_tag#v}" "$version" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)"
    [ "$newest" = "$version" ] && [ "${last_tag#v}" != "$version" ] || die "Version $version must be greater than $last_tag."
    range="$last_tag..HEAD"
else
    range="HEAD"
fi
[ -n "$(git log --no-merges --pretty=%s $range)" ] || die "No commits since ${last_tag:-the start}; nothing to release."

echo "== 1/5 verify (check.sh full)"
scripts/check.sh full

# Anything below modifies tracked files; restore them if a step fails.
rollback() { git checkout -- manifest.xml CHANGELOG.md 2>/dev/null || true; }
trap 'rc=$?; [ $rc -ne 0 ] && { echo "Release preparation failed; restoring manifest.xml and CHANGELOG.md"; rollback; }; exit $rc' EXIT

echo "== 2/5 bump version to $version"
sed -E '/<iq:application /s/ version="[0-9.]+"/ version="'"$version"'"/' manifest.xml > manifest.xml.tmp \
    && mv manifest.xml.tmp manifest.xml
grep -q "version=\"$version\"" manifest.xml || die "Version bump in manifest.xml failed."

echo "== 3/5 changelog"
entry="$(mktemp)"
{
    echo "## $version - $(date +%Y-%m-%d)"
    echo
    git log --no-merges --pretty='- %s' $range
    echo
} > "$entry"
{ sed -n '1,/^$/p' CHANGELOG.md; cat "$entry"; sed '1,/^$/d' CHANGELOG.md; } > CHANGELOG.md.tmp \
    && mv CHANGELOG.md.tmp CHANGELOG.md
rm -f "$entry"
if [ -t 0 ]; then
    echo "Review/edit CHANGELOG.md (commit subjects are a starting point), then press Enter."
    read -r _
fi

echo "== 4/5 release build + leak check"
scripts/release.sh

echo "== 5/5 commit and tag"
git add manifest.xml CHANGELOG.md
git commit -m "Release $version"
git tag -a "$tag" -m "Release $version"

trap - EXIT
echo
echo "OK   $tag prepared. Package: dist/TibberWidget-$version.iq"
echo "Next: smoke-test on a device, upload to the store, then 'git push origin main $tag'."
echo "      (full steps in docs/RELEASING.md)"
