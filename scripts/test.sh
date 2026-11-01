#!/usr/bin/env bash
# Build with unit tests and run them in the Connect IQ simulator.
#
# Usage: scripts/test.sh [--device <id>] [--update-baseline] [testName]
#   Starts the simulator if needed (set CIQ_NO_SIM_START=1 to disable).
#   Failures listed in .agents/baselines/test-failures.txt are reported as
#   "known" and do not fail the run; only NEW failures fail. Full log:
#   .cache/ciq/logs/test-<device>.log

source "$(dirname "$0")/lib.sh"

device="$DEFAULT_DEVICE"
update_baseline=0
test_name=""
while [ $# -gt 0 ]; do
    case "$1" in
        --device) device="$2"; shift ;;
        --update-baseline) update_baseline=1 ;;
        -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
        -*) die "Unknown option: $1" ;;
        *) test_name="$1" ;;
    esac
    shift
done

setup_toolchain
cd "$REPO_ROOT"

prg="$CACHE_DIR/TibberWidget-tests-$device.prg"
build_log="$LOG_DIR/test-build-$device.log"
log="$LOG_DIR/test-$device.log"
baseline="$BASELINE_DIR/test-failures.txt"
rm -f "$prg"

if ! "$CIQ_HOME/bin/monkeyc" -f monkey.jungle -o "$prg" -y "$SIGNING_KEY" -d "$device" -t >"$build_log" 2>&1; then
    echo "FAIL test build $device — log: ${build_log#$REPO_ROOT/}"
    grep -E '^ERROR|error:' "$build_log" | sed "s#$REPO_ROOT/##g" | head -30
    exit 1
fi

ensure_simulator
timeout_secs="${CIQ_TEST_TIMEOUT:-90}"
rc=0
# shellcheck disable=SC2086
run_with_timeout "$timeout_secs" "$CIQ_HOME/bin/monkeydo" "$prg" "$device" -t $test_name >"$log" 2>&1 || rc=$?
if [ "$rc" = 124 ]; then
    echo "FAIL tests $device — monkeydo timed out after ${timeout_secs}s (simulator hung?)."
    echo "  Ask the human to restart the simulator, then retry once. Do not loop."
    exit 1
fi

results="$CACHE_DIR/test-results.txt"
grep -E '^test[A-Za-z0-9_]+ +(PASS|FAIL|ERROR)$' "$log" | awk '{print $1, $2}' > "$results" || true
run=$(wc -l < "$results" | tr -d ' ')
if [ "$run" -eq 0 ]; then
    echo "FAIL tests $device — no results parsed (simulator problem?). Log tail:"
    tail -15 "$log" | sed "s#$REPO_ROOT/##g"
    exit 1
fi

failing="$CACHE_DIR/test-failing.txt"
awk '$2 != "PASS" {print $1}' "$results" | LC_ALL=C sort > "$failing"
passed=$(awk '$2 == "PASS"' "$results" | wc -l | tr -d ' ')

if [ "$update_baseline" = 1 ]; then
    [ -z "$test_name" ] || die "--update-baseline requires running the full suite."
    cp "$failing" "$baseline"
    echo "OK   tests $device — baseline updated: $(wc -l < "$failing" | tr -d ' ') known failures"
    exit 0
fi

known_file="$CACHE_DIR/test-known.txt"
if [ -f "$baseline" ]; then LC_ALL=C sort "$baseline" > "$known_file"; else : > "$known_file"; fi
new=$(new_lines "$failing" "$known_file")
ran_names="$CACHE_DIR/test-ran.txt"
awk '{print $1}' "$results" | LC_ALL=C sort > "$ran_names"
now_passing=$(LC_ALL=C comm -12 "$known_file" "$ran_names" | LC_ALL=C comm -23 - "$failing")
known_count=$(LC_ALL=C comm -12 "$failing" "$known_file" | wc -l | tr -d ' ')

if [ -z "$new" ]; then
    echo "OK   tests $device — $run run, $passed passed, $known_count known failures, 0 new"
    status=0
else
    echo "FAIL tests $device — $run run, $passed passed, $known_count known, NEW failures:"
    for name in $new; do
        echo "  - $name"
        awk -v t="Executing test $name..." '
            index($0, t) == 1 {on=1; next}
            on && (/^-----/ || /^(PASS|FAIL|ERROR)$/) {exit}
            on && NF {print "      " $0; if (++n >= 8) exit}
        ' "$log" | sed "s#$REPO_ROOT/##g"
    done
    status=1
fi
if [ -n "$now_passing" ]; then
    echo "  Now passing (remove from .agents/baselines/test-failures.txt):" $now_passing
fi
exit $status
