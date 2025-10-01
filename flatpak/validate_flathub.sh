#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
FLATPAK_DIR="${REPO_ROOT}/flatpak"
OUTPUT_DIR="${FLATPAK_DIR}/flathub-build/output"

echo "[1/6] Resetting generated inputs"
rm -rf "${FLATPAK_DIR}/flathub-build" "${FLATPAK_DIR}/flatpak-flutter"

echo "[2/6] Preparing Flathub submission artifacts"
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
  --force-clean \
  --repo=repo \
  --mirror-screenshots-url=https://dl.flathub.org/media \
  build-dir com.matthiasn.lotti.yml

echo "[4/6] Committing screenshots to OSTree"
ARCH="$(uname -m)"
if [[ "${ARCH}" == "x86_64" ]]; then
  OSTREE_ARCH="x86_64"
elif [[ "${ARCH}" == "aarch64" || "${ARCH}" == "arm64" ]]; then
  OSTREE_ARCH="aarch64"
else
  echo "Warning: Unknown architecture ${ARCH}, defaulting to x86_64" >&2
  OSTREE_ARCH="x86_64"
fi

ostree commit \
  --repo=repo \
  --canonical-permissions \
  --branch=screenshots/${OSTREE_ARCH} \
  build-dir/files/share/app-info/media

echo "[5/6] Linting manifest"
flatpak run --command=flatpak-builder-lint org.flatpak.Builder//stable manifest com.matthiasn.lotti.yml

echo "[6/6] Linting repo"
flatpak run --command=flatpak-builder-lint org.flatpak.Builder//stable repo repo
popd >/dev/null

echo "Validation complete"
