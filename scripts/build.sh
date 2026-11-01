#!/usr/bin/env bash
# Compile the widget for one or more devices with terse, agent-friendly output.
#
# Usage: scripts/build.sh [--update-baseline] [device ...]
#   Default device: fenix7xpro. Full log: .cache/ciq/logs/build-<device>.log
#   Warnings are compared with .agents/baselines/warnings-<device>.txt;
#   only NEW warnings are printed. --update-baseline accepts the current set.

source "$(dirname "$0")/lib.sh"

update_baseline=0
devices=""
for arg in "$@"; do
    case "$arg" in
        --update-baseline) update_baseline=1 ;;
        -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
        -*) die "Unknown option: $arg" ;;
        *) devices="$devices $arg" ;;
    esac
done
[ -n "$devices" ] || devices="$DEFAULT_DEVICE"

setup_toolchain
cd "$REPO_ROOT"

status=0
for device in $devices; do
    log="$LOG_DIR/build-$device.log"
    out="$CACHE_DIR/TibberWidget-$device.prg"
    baseline="$BASELINE_DIR/warnings-$device.txt"
    current="$CACHE_DIR/warnings-$device.txt"
    rm -f "$out"

    start=$(date +%s)
    if "$CIQ_HOME/bin/monkeyc" -f monkey.jungle -o "$out" -y "$SIGNING_KEY" -d "$device" -w >"$log" 2>&1 \
        && [ -s "$out" ]; then
        result=OK
    else
        result=FAIL
        status=1
    fi
    secs=$(( $(date +%s) - start ))

    grep '^WARNING' "$log" | normalize_diagnostics > "$current" || true
    total=$(wc -l < "$current" | tr -d ' ')

    if [ "$result" = FAIL ]; then
        echo "FAIL build $device (${secs}s) — log: ${log#$REPO_ROOT/}"
        grep -E '^ERROR|error:' "$log" | sed "s#$REPO_ROOT/##g" | head -30
        continue
    fi

    if [ "$update_baseline" = 1 ]; then
        cp "$current" "$baseline"
        echo "OK   build $device (${secs}s) — baseline updated: $total warnings"
    elif [ -f "$baseline" ]; then
        added=$(new_lines "$current" "$baseline" | wc -l | tr -d ' ')
        fixed=$(new_lines "$baseline" "$current" | wc -l | tr -d ' ')
        label="OK  "
        if [ "$added" -gt 0 ] && [ "${CIQ_STRICT_WARNINGS:-1}" = 1 ]; then
            label="FAIL"
            status=1
        fi
        echo "$label build $device (${secs}s) — $total warnings, $added new, $fixed fixed"
        if [ "$added" -gt 0 ]; then
            new_lines "$current" "$baseline" | head -20 | sed 's/^/  + /'
        fi
        if [ "$fixed" -gt 0 ]; then
            echo "  (warnings fixed — run with --update-baseline to lock in the improvement)"
        fi
    else
        echo "OK   build $device (${secs}s) — $total warnings (no baseline; run with --update-baseline)"
    fi
done
exit $status
