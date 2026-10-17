#!/usr/bin/env bash
# Render homeserver.yaml and copy log.config into the Synapse data volume.
#
# Usage: render-synapse-config.sh /etc/lotti-sync/sync.env
#
# Run once before the first `docker compose up`, and again after editing the
# template. Fails if any placeholder is left unset rather than writing a
# config with an empty secret in it.
set -euo pipefail

env_file="${1:?usage: render-synapse-config.sh <env-file>}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

set -a
# shellcheck disable=SC1090
source "$env_file"
set +a

for name in SYNAPSE_SERVER_NAME MATRIX_PUBLIC_BASEURL SYNAPSE_DB_PASSWORD \
  SYNAPSE_MACAROON_SECRET SYNAPSE_FORM_SECRET SYNAPSE_REGISTRATION_SECRET; do
  if [[ -z "${!name:-}" ]]; then
    echo "missing $name in $env_file" >&2
    exit 1
  fi
done

rendered="$(mktemp)"
trap 'rm -f "$rendered"' EXIT
envsubst '${SYNAPSE_SERVER_NAME} ${MATRIX_PUBLIC_BASEURL} ${SYNAPSE_DB_PASSWORD} ${SYNAPSE_MACAROON_SECRET} ${SYNAPSE_FORM_SECRET} ${SYNAPSE_REGISTRATION_SECRET}' \
  < "$here/synapse/homeserver.yaml.template" > "$rendered"

volume="$(docker volume inspect --format '{{ .Mountpoint }}' lotti-sync_synapse-data 2>/dev/null || true)"
if [[ -z "$volume" ]]; then
  docker volume create lotti-sync_synapse-data >/dev/null
  volume="$(docker volume inspect --format '{{ .Mountpoint }}' lotti-sync_synapse-data)"
fi

# Synapse runs as UID 991 and writes its signing key and media here; a fresh
# volume on a rootful daemon is root-owned.
chown 991:991 "$volume"
install -m 0640 -o 991 -g 991 "$rendered" "$volume/homeserver.yaml"
install -m 0644 -o 991 -g 991 "$here/synapse/log.config" "$volume/log.config"

if [[ ! -f "$volume/${SYNAPSE_SERVER_NAME}.signing.key" ]]; then
  # --generate-keys writes the missing signing key and exits without
  # starting the server or touching the database.
  docker run --rm -v lotti-sync_synapse-data:/data --user 991:991 \
    --entrypoint python matrixdotorg/synapse:v1.130.0 \
    -m synapse.app.homeserver --config-path /data/homeserver.yaml --generate-keys
fi

echo "Synapse config written to $volume"
