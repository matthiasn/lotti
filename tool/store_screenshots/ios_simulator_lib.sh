# Sourced by ios.sh and ios_preview.sh, not run: how the iOS store scripts
# find, boot and dress a simulator, and how they hand it back.
#
# A simulator is always addressed by the UDID resolved here, never as
# "booted" — with two simulators running, simctl picks one of them, and the
# other may be somebody's debugging session.
#
#   LOTTI_STORE_STATUS_TIME  status bar clock (default: 9:41)

STORE_STATUS_TIME=${LOTTI_STORE_STATUS_TIME:-9:41}

# "<udid> <state>" of the available simulator called $1: one already booted
# first, else the one on the newest runtime, so two runs land on the same
# iOS version when Xcode ships the same device under several. Prints nothing
# when no simulator carries that name.
device_for() {
  xcrun simctl list devices available -j | python3 -c '
import json, re, sys
name = sys.argv[1]
def version(runtime):
    return tuple(int(n) for n in re.findall(r"\d+", runtime.split(".")[-1]))
devices = [(version(runtime), d)
           for runtime, listed in json.load(sys.stdin)["devices"].items()
           for d in listed if d["name"] == name]
devices.sort(key=lambda item: (item[1]["state"] != "Booted", tuple(-n for n in item[0])))
if devices:
    print(devices[0][1]["udid"], devices[0][1]["state"])
' "$1"
}

slug_for() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g; s/^_|_$//g'
}

booted_here=()
overridden_here=()

# Boots the simulator called $1 unless it is running, waits for it, and
# overrides its status bar to Apple's marketing convention (9:41, full
# battery, full signal). Leaves its UDID in $SIM_UDID.
claim_simulator() {
  local name=$1 state
  read -r SIM_UDID state <<<"$(device_for "$name")"
  if [ -z "${SIM_UDID:-}" ]; then
    echo "No available simulator named '$name'. Available:" >&2
    xcrun simctl list devices available | grep -E '^\s+(iPhone|iPad)' >&2 || true
    exit 1
  fi
  if [ "$state" != "Booted" ]; then
    echo "Booting $name ($SIM_UDID)"
    xcrun simctl boot "$SIM_UDID"
    booted_here+=("$SIM_UDID")
  fi
  xcrun simctl bootstatus "$SIM_UDID" -b >/dev/null
  xcrun simctl status_bar "$SIM_UDID" override \
    --time "$STORE_STATUS_TIME" \
    --batteryState charged --batteryLevel 100 \
    --wifiBars 3 --cellularBars 4 --operatorName ''
  overridden_here+=("$SIM_UDID")
}

# Clears every status bar this run dressed, including on simulators that were
# already running — an early exit must not leave one at 9:41 — and shuts down
# the ones this run booted. For the caller's EXIT trap.
release_simulators() {
  local udid
  for udid in "${overridden_here[@]:-}"; do
    [ -n "$udid" ] || continue
    xcrun simctl status_bar "$udid" clear >/dev/null 2>&1 || true
  done
  for udid in "${booted_here[@]:-}"; do
    [ -n "$udid" ] || continue
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
  done
}
