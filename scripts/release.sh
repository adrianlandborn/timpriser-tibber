#!/usr/bin/env bash
# Build the Connect IQ store package (.iq) without any local development token.
#
# Usage: scripts/release.sh [device]
#   With a device (e.g. fenix7xpro) builds a single .prg for a quick leak check
#   instead of the full .iq (which needs every manifest product known to the SDK).
#   Uses monkey-release.jungle (token-less stub instead of the local ignored token class),
#   then unpacks the .iq and fails if the local token appears anywhere in it.
#   Output: .cache/ciq/TibberWidget.iq plus a versioned copy dist/TibberWidget-<version>.iq
#   (upload it in the Connect IQ developer dashboard; see docs/RELEASING.md).

source "$(dirname "$0")/lib.sh"

setup_toolchain
cd "$REPO_ROOT"

version="$(sed -n '/<iq:application /s/.* version="\([0-9.]*\)".*/\1/p' manifest.xml | head -1)"
[ -n "$version" ] || die "Could not read application version from manifest.xml"

device="${1:-}"
if [ -n "$device" ]; then
    out="$CACHE_DIR/TibberWidget-release-$device.prg"
    build_flags="-d $device"
else
    out="$CACHE_DIR/TibberWidget.iq"
    build_flags="-e"
fi
log="$LOG_DIR/release.log"
rm -f "$out"

if ! "$CIQ_HOME/bin/monkeyc" $build_flags -r -f monkey-release.jungle -o "$out" -y "$SIGNING_KEY" -w >"$log" 2>&1 \
    || [ ! -s "$out" ]; then
    echo "FAIL release build — log: ${log#$REPO_ROOT/}"
    grep -E '^ERROR|error:' "$log" | sed "s#$REPO_ROOT/##g" | head -30
    exit 1
fi

# Leak check: the value is read here and never printed.
token="$(sed -n 's/.*return "\(.\{1,\}\)";.*/\1/p' "$REPO_ROOT/secrets/Secrets.mc" | head -1)"
if [ -n "$token" ]; then
    unpacked="$(mktemp -d)"
    trap 'rm -rf "$unpacked"' EXIT
    cp "$out" "$unpacked/"
    if [ -z "$device" ]; then
        # The .iq is compressed, so also scan an uncompressed per-device build of the same jungle.
        "$CIQ_HOME/bin/monkeyc" -d "$DEFAULT_DEVICE" -r -f monkey-release.jungle -o "$unpacked/check.prg" \
            -y "$SIGNING_KEY" >"$LOG_DIR/release-check.log" 2>&1 || { echo "FAIL leak-check build"; exit 1; }
    fi
    if grep -raFq -- "$token" "$unpacked"; then
        rm -f "$out"
        echo "FAIL release package contains the local token — package deleted"
        exit 1
    fi
    echo "OK   leak check: local token not found in package"
else
    echo "WARN no local token found to check against"
fi

echo "OK   release package: ${out#$REPO_ROOT/} ($(wc -c < "$out" | tr -d ' ') bytes), version $version"
if [ -z "$device" ]; then
    mkdir -p "$REPO_ROOT/dist"
    cp "$out" "$REPO_ROOT/dist/TibberWidget-$version.iq"
    echo "OK   versioned copy: dist/TibberWidget-$version.iq (sha256 $(shasum -a 256 "$out" | cut -d' ' -f1))"
fi
