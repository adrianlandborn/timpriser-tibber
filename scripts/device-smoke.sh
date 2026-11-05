#!/usr/bin/env bash
# Try devices in the simulator and keep the ones that start without crashing.
#
# Usage: scripts/device-smoke.sh [options] [device ...]
#   --candidates   use every installed watch device that is not in manifest.xml and has
#                  a main-app memory limit of at least 512 KB (see --list)
#   --list         print the candidates and exit
#   --dry-run      do not keep anything: restore manifest.xml and the failures doc at the end
#   --wait <sec>   seconds to let each app run before judging it (default 25)
#
# For each device: add it to manifest.xml, build, launch with monkeydo, scan the log for
# "Error:" / crashes, screenshot ONLY the simulator window (glance, then the widget after
# sending DOWN + SELECT, on devices that have a glance), then stop the app. A failure is
# retried once (a first launch can fail when the simulator was in a bad state). Passing
# devices stay in manifest.xml (sorted); failing ones are removed and recorded with their
# reason in docs/device-smoke-failures.md (a device that later passes is removed from it).
# Needs the simulator GUI and screen-recording permission for the terminal. It does not check
# the glance or layout: look at the screenshots, then update docs/device-tiers.md and README.md.
#
# Output (under .cache/ciq/smoke/): results.tsv, shots/<device>-glance|widget.png (300 px wide),
# sheet-N.png (contact sheets of the widget shots), logs/. A pass means "no error in the log": DOWN +
# SELECT does not open the widget on touch watches and some newer models, so review the sheets.

source "$(dirname "$0")/lib.sh"
cd "$REPO_ROOT"

wait_seconds=25
list_only=0
use_candidates=0
dry_run=0
devices=()
while [ $# -gt 0 ]; do
    case "$1" in
        --candidates) use_candidates=1 ;;
        --list) use_candidates=1; list_only=1 ;;
        --dry-run) dry_run=1 ;;
        --wait) wait_seconds="$2"; shift ;;
        -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
        -*) die "Unknown option: $1" ;;
        *) devices+=("$1") ;;
    esac
    shift
done

devices_dir="$HOME/Library/Application Support/Garmin/ConnectIQ/Devices"
failures_doc="docs/device-smoke-failures.md"

candidates() {
    python3 -I - "$devices_dir" manifest.xml <<'PY'
import json, os, re, sys
devices_dir, manifest = sys.argv[1], sys.argv[2]
have = set(re.findall(r'iq:product id="([^"]+)"', open(manifest).read()))
skip = ("edge", "gpsmap", "oregon", "montana", "rino", "etrex")
for name in sorted(os.listdir(devices_dir)):
    if name in have or name.startswith(skip):
        continue
    try:
        info = json.load(open(os.path.join(devices_dir, name, "compiler.json")))
    except (OSError, ValueError):
        continue
    limits = {a["type"]: a["memoryLimit"] // 1024 for a in info["appTypes"]}
    if max(limits.get("watchApp", 0), limits.get("widget", 0)) >= 512:
        print(name)
PY
}

if [ "$use_candidates" = 1 ]; then
    while IFS= read -r line; do devices+=("$line"); done < <(candidates)
fi
if [ "$list_only" = 1 ]; then printf '%s\n' "${devices[@]}"; exit 0; fi
[ ${#devices[@]} -gt 0 ] || die "No devices given. Use --candidates or list device ids."

setup_toolchain
ensure_simulator
command -v swiftc >/dev/null || die "swiftc is needed to find the simulator window (Xcode command line tools)."
out="$REPO_ROOT/.cache/ciq/smoke"
mkdir -p "$out/shots" "$out/logs" "$REPO_ROOT/bin"
helper="$REPO_ROOT/.cache/ciq/simwindow"
[ "$helper" -nt tools/simwindow.swift ] || swiftc -O tools/simwindow.swift -o "$helper" || die "Could not build tools/simwindow.swift"
: > "$out/results.tsv"

backup_dir=$(mktemp -d)
cp manifest.xml "$backup_dir/manifest.xml"
[ -f "$failures_doc" ] && cp "$failures_doc" "$backup_dir/failures.md"
monkeydo_pid=""
# lib.sh sets -e: every kill/pkill here must tolerate "nothing to kill".
stop_app() {
    if [ -n "$monkeydo_pid" ]; then
        pkill -P "$monkeydo_pid" 2>/dev/null || true
        kill "$monkeydo_pid" 2>/dev/null || true
    fi
    pkill -f MonkeyDoDeux 2>/dev/null || true
    monkeydo_pid=""
}
cleanup() {
    stop_app
    if [ "$dry_run" = 1 ]; then
        cp "$backup_dir/manifest.xml" manifest.xml
        if [ -f "$backup_dir/failures.md" ]; then cp "$backup_dir/failures.md" "$failures_doc"; else rm -f "$failures_doc"; fi
    fi
    rm -rf "$backup_dir"
}

# Screenshot only the simulator window, shrunk to 300 px wide. Returns 1 if there is no window.
snap() {
    local window; window=$("$helper")
    [ -n "$window" ] || return 1
    screencapture -x -o -l "$window" "$out/shots/$1.png" 2>/dev/null || return 1
    sips --resampleWidth 300 "$out/shots/$1.png" >/dev/null 2>&1 || true
}

has_glance() {
    python3 -I - "$devices_dir/$1/compiler.json" <<'PY'
import json, sys
info = json.load(open(sys.argv[1]))
sys.exit(0 if any(a["type"] == "glance" and a["memoryLimit"] > 0 for a in info["appTypes"]) else 1)
PY
}

# Press DOWN (arrow) then SELECT (return) in the simulator, like the watch's DOWN and START buttons.
press_down_select() {
    # `set frontmost` does not work for the simulator (it stays behind the editor, and the keys
    # would go to the wrong app); opening the app bundle does bring it to the front.
    open "$CIQ_HOME/bin/ConnectIQ.app" || return 0
    sleep 1.5
    # The first SELECT after focusing does nothing visible (it only focuses the view); the
    # DOWN + SELECT that follow open the widget. Pauses matter: shorter ones missed it.
    osascript >/dev/null 2>&1 <<'OSA' || true
tell application "System Events"
    key code 36
    delay 3
    key code 125
    delay 2
    key code 36
end tell
OSA
}

crash_in() {
    grep -qE '^Error:|Encountered an app crash|Unhandled|Out Of Memory' "$1"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

reason=""
try_device() {
    local dev="$1" log="$out/logs/$dev.log" prg="bin/TibberWidget-$dev.prg"
    rm -f "$prg"
    if ! "$CIQ_HOME/bin/monkeyc" -f monkey.jungle -o "$prg" -y "$SIGNING_KEY" -d "$dev" >"$out/logs/$dev.build.log" 2>&1 || [ ! -s "$prg" ]; then
        reason="build failed: $(grep -m1 -i 'error' "$out/logs/$dev.build.log" | cut -c1-120)"
        return 1
    fi
    "$CIQ_HOME/bin/monkeydo" "$prg" "$dev" >"$log" 2>&1 &
    monkeydo_pid=$!
    sleep "$wait_seconds"
    local ok=0 stage="glance/start"
    # Stage 1: the app as launched (the glance on devices that have one). Stage 2: after
    # DOWN + SELECT, which opens the widget from its glance.
    if has_glance "$dev"; then
        snap "$dev-glance" || true
        press_down_select
        sleep 8
        stage="widget (after DOWN + SELECT)"
        snap "$dev-widget" || true
    else
        snap "$dev-widget" || true
    fi
    if crash_in "$log"; then
        reason="crash in $stage: $(grep -m1 -E '^Error:|Unhandled|Out Of Memory' "$log" | cut -c1-100) $(grep -m1 '^Details:' "$log" | cut -c1-100)"
    elif ! kill -0 "$monkeydo_pid" 2>/dev/null; then
        reason="monkeydo exited ($stage): $(tail -2 "$log" | tr '\n' ' ' | cut -c1-140)"
    elif [ ! -s "$out/shots/$dev-widget.png" ]; then
        reason="no simulator window to screenshot"
    elif [ -f "$out/shots/$dev-glance.png" ] && cmp -s "$out/shots/$dev-glance.png" "$out/shots/$dev-widget.png"; then
        reason="DOWN + SELECT did not open the widget (screenshot unchanged)"
    else
        ok=1
    fi
    stop_app
    sleep 2
    [ "$ok" = 1 ]
}

for dev in "${devices[@]}"; do
    if [ ! -d "$devices_dir/$dev" ]; then echo "skip $dev (device pack not installed)"; continue; fi
    if grep -q "id=\"$dev\"" manifest.xml; then echo "skip $dev (already in manifest.xml)"; continue; fi
    cp manifest.xml "$backup_dir/before.xml"
    sed -i '' "s|^\( *\)</iq:products>|\1    <iq:product id=\"$dev\"/>\n\1</iq:products>|" manifest.xml
    if try_device "$dev" || { echo "retry $dev ($reason)"; try_device "$dev"; }; then
        printf '%s\tPASS\t\n' "$dev" >>"$out/results.tsv"; echo "PASS $dev"
    else
        printf '%s\tFAIL\t%s\n' "$dev" "$reason" >>"$out/results.tsv"; echo "FAIL $dev: $reason"
        cp "$backup_dir/before.xml" manifest.xml
    fi
done

# Keep the product list sorted, and record failures / clear passes in the failures doc.
python3 -I - manifest.xml "$out/results.tsv" "$failures_doc" <<'PY'
import datetime, re, sys
manifest, results, doc = sys.argv[1:4]
text = open(manifest).read()
block = re.search(r'(?:^ *<iq:product id="[^"]+"/>\n)+', text, re.M)
if block:
    lines = sorted(set(re.findall(r'^ *<iq:product id="[^"]+"/>\n', block.group(0), re.M)))
    open(manifest, "w").write(text[:block.start()] + "".join(lines) + text[block.end():])

rows = {}
try:
    for line in open(doc):
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) == 3 and cells[0].startswith("`"):
            rows[cells[0].strip("`")] = (cells[1], cells[2])
except OSError:
    pass
today = datetime.date.today().isoformat()
for line in open(results):
    device, status, reason = (line.rstrip("\n").split("\t") + ["", ""])[:3]
    if status == "PASS":
        rows.pop(device, None)
    elif status == "FAIL":
        rows[device] = (today, reason.replace("|", "/") or "unknown")
header = (
    "# Devices that failed the simulator smoke test\n\n"
    "Written by `scripts/device-smoke.sh`: devices that were tried and left out of `manifest.xml`, "
    "with the first error seen. A device that passes a later run is removed from this list. "
    "The simulator may differ from a real watch.\n\n"
    "| Device | Last tried | Reason |\n| --- | --- | --- |\n"
)
if rows:
    open(doc, "w").write(header + "".join(f"| `{d}` | {t} | {r} |\n" for d, (t, r) in sorted(rows.items())))
PY
# Contact sheets (24 widget screenshots per image) so many devices can be reviewed in one look.
rm -f "$out"/sheet-*.png
sheet_tool="$REPO_ROOT/.cache/ciq/contactsheet"
if [ "$sheet_tool" -nt tools/contactsheet.swift ] || swiftc -O tools/contactsheet.swift -o "$sheet_tool" 2>/dev/null; then
    shots=()
    for dev in "${devices[@]}"; do [ -f "$out/shots/$dev-widget.png" ] && shots+=("$out/shots/$dev-widget.png"); done
    n=0
    while [ ${#shots[@]} -gt 0 ]; do
        n=$((n + 1))
        "$sheet_tool" "$out/sheet-$n.png" "${shots[@]:0:24}" || true
        shots=("${shots[@]:24}")
    done
fi
echo "Results: $out/results.tsv  Screenshots: $out/shots/  Failures: $failures_doc"
