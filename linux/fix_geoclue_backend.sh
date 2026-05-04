#!/usr/bin/env bash
#
# Point GeoClue at BeaconDB (the open-source Mozilla Location Service
# replacement). The default WiFi URL on Ubuntu 24.04 still references
# location.services.mozilla.com, which Mozilla shut down in 2024 and
# now returns 404. Without this fix every GeoClue client on the host
# (Lotti's portal path, Lotti's direct path, Firefox, GNOME, etc.)
# silently fails to resolve a location.
#
# Idempotent: rerunning this just rewrites the drop-in file.
#
# Usage:
#   ./linux/fix_geoclue_backend.sh             # apply the fix
#   ./linux/fix_geoclue_backend.sh --revert    # remove the drop-in

set -euo pipefail

DROPIN=/etc/geoclue/conf.d/00-beacondb.conf

if [[ "${1:-}" == "--revert" ]]; then
  if [[ -f "$DROPIN" ]]; then
    sudo rm -v "$DROPIN"
    sudo systemctl restart geoclue
    echo "Reverted. GeoClue restarted."
  else
    echo "Nothing to revert: $DROPIN does not exist."
  fi
  exit 0
fi

if ! command -v systemctl >/dev/null 2>&1; then
  echo "Error: systemctl not found; this script targets systemd distros." >&2
  exit 1
fi

if ! systemctl list-unit-files geoclue.service >/dev/null 2>&1; then
  echo "Error: no geoclue.service unit found. Install GeoClue first:" >&2
  echo "  sudo apt install geoclue-2.0" >&2
  exit 1
fi

sudo install -d -m 0755 /etc/geoclue/conf.d
sudo tee "$DROPIN" >/dev/null <<'EOF'
# Installed by linux/fix_geoclue_backend.sh
#
# Mozilla shut down location.services.mozilla.com in 2024. BeaconDB is
# the open-source replacement that the GeoClue project recommends.
# https://beacondb.net/
[wifi]
enable=true
url=https://api.beacondb.net/v1/geolocate
submission-url=https://api.beacondb.net/v2/geosubmit
EOF

sudo systemctl restart geoclue
echo "Wrote $DROPIN and restarted geoclue."
echo "Verify with:"
echo "  journalctl -u geoclue -f"
echo "and trigger a location request from Lotti or any GeoClue client."
