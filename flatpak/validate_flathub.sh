#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
FLATPAK_DIR="${REPO_ROOT}/flatpak"
OUTPUT_DIR="${FLATPAK_DIR}/flathub-build/output"

echo "[1/5] Resetting generated inputs"
rm -rf "${FLATPAK_DIR}/flathub-build" "${FLATPAK_DIR}/flatpak-flutter"

echo "[2/5] Preparing Flathub submission artifacts"
pushd "${FLATPAK_DIR}" >/dev/null
./prepare_flathub_submission.sh "$@"
popd >/dev/null

if [[ ! -d "${OUTPUT_DIR}" ]]; then
  echo "Error: expected output directory at ${OUTPUT_DIR}" >&2
  exit 1
fi

echo "[3/6] Building from offline manifest"
pushd "${OUTPUT_DIR}" >/dev/null
flatpak-builder \
  --sandbox \
  --user \
  --install \
  --mirror-screenshots-url=https://dl.flathub.org/media \
  --force-clean \
  --repo=repo \
  build-dir com.matthiasn.lotti.yml

echo "[4/6] Exporting icons and screenshots"
flatpak build-export \
  --include-icons \
  --include-screenshots \
  repo build-dir >/dev/null

echo "[5/6] Updating local repo metadata"
flatpak build-update-repo repo >/dev/null

echo "[6/6] Linting manifest"
flatpak run --command=flatpak-builder-lint org.flatpak.Builder//stable manifest com.matthiasn.lotti.yml

echo "[7/6] Linting repo"
flatpak run --command=flatpak-builder-lint org.flatpak.Builder//stable repo repo
popd >/dev/null

echo "Validation complete"
