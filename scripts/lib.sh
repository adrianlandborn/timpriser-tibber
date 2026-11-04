# shellcheck shell=bash
# Shared helpers for the build/test harness. Source, don't execute.
# Compatible with macOS bash 3.2.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="$REPO_ROOT/.cache/ciq"
LOG_DIR="$CACHE_DIR/logs"
BASELINE_DIR="$REPO_ROOT/.agents/baselines"
DEFAULT_DEVICE="fenix7xpro"
# Standard fonts, large-font profile, small screen / tight memory.
DEFAULT_CHECK_DEVICES="fenix7xpro fenix847mm vivoactive4"

mkdir -p "$LOG_DIR"

die() { echo "ERROR: $*" >&2; exit 1; }

resolve_sdk() {
    if [ -n "${CIQ_HOME:-}" ] && [ -x "$CIQ_HOME/bin/monkeyc" ]; then
        return
    fi
    local cfg="$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg"
    if [ -f "$cfg" ]; then
        CIQ_HOME="$(tr -d '\n' < "$cfg")"
        CIQ_HOME="${CIQ_HOME%/}"
    elif command -v monkeyc >/dev/null 2>&1; then
        CIQ_HOME="$(cd "$(dirname "$(command -v monkeyc)")/.." && pwd)"
    fi
    [ -n "${CIQ_HOME:-}" ] && [ -x "$CIQ_HOME/bin/monkeyc" ] \
        || die "Connect IQ SDK not found. Install it with the SDK Manager or set CIQ_HOME."
    export CIQ_HOME
}

resolve_java() {
    if java -version >/dev/null 2>&1; then
        return
    fi
    local candidate
    for candidate in \
        "${JAVA_HOME:-}/bin" \
        /opt/homebrew/opt/openjdk@17/bin \
        /opt/homebrew/opt/openjdk/bin \
        /usr/local/opt/openjdk@17/bin \
        /usr/local/opt/openjdk/bin; do
        if [ -x "$candidate/java" ]; then
            export PATH="$candidate:$PATH"
            return
        fi
    done
    die "No Java runtime found. Install one (e.g. 'brew install openjdk@17') or set JAVA_HOME."
}

resolve_key() {
    SIGNING_KEY="${CIQ_SIGNING_KEY:-$REPO_ROOT/developer_key.der}"
    [ -f "$SIGNING_KEY" ] || die "Signing key not found at $SIGNING_KEY (see README: Configure local credentials)."
    [ -f "$REPO_ROOT/source/config/Secrets.mc" ] \
        || die "source/config/Secrets.mc missing. Copy it from Secrets.mc.example (human step; agents must not create it)."
}

setup_toolchain() {
    resolve_sdk
    resolve_java
    resolve_key
}

# Strip absolute paths and line/column numbers so baselines survive edits.
normalize_diagnostics() {
    sed -e "s#$REPO_ROOT/##g" \
        -e 's#\(\.[a-z]*\):[0-9][0-9]*,[0-9][0-9]*:#\1:#' \
        -e 's#\(\.[a-z]*\):[0-9][0-9]*:#\1:#' \
        -e 's#[0-9][0-9]* bytes used out of#N bytes used out of#' \
        | LC_ALL=C sort
}

# Lines in sorted file $1 that are not in sorted file $2 (duplicates count).
new_lines() {
    LC_ALL=C comm -23 "$1" "$2"
}

simulator_running() {
    pgrep -f "ConnectIQ.app/Contents/MacOS/simulator" >/dev/null 2>&1
}

# run_with_timeout <seconds> <cmd...>; returns 124 on timeout (bash 3.2, no coreutils).
run_with_timeout() {
    local secs="$1"; shift
    local flag="$CACHE_DIR/.timeout.$$"
    rm -f "$flag"
    "$@" &
    local pid=$!
    (
        sleep "$secs"
        if kill -0 "$pid" 2>/dev/null; then
            touch "$flag"
            pkill -TERM -P "$pid" 2>/dev/null
            kill -TERM "$pid" 2>/dev/null
        fi
    ) &
    local watcher=$!
    local rc=0
    wait "$pid" || rc=$?
    kill "$watcher" 2>/dev/null || true
    wait "$watcher" 2>/dev/null || true
    if [ -f "$flag" ]; then
        rm -f "$flag"
        return 124
    fi
    return $rc
}

ensure_simulator() {
    simulator_running && return
    [ "${CIQ_NO_SIM_START:-0}" = "1" ] && die "Simulator not running and CIQ_NO_SIM_START=1."
    echo "Starting Connect IQ simulator..."
    "$CIQ_HOME/bin/connectiq" >/dev/null 2>&1 &
    local i
    for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
        sleep 1
        if simulator_running; then
            sleep 2
            return
        fi
    done
    die "Simulator did not start within 15s."
}
