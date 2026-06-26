#!/usr/bin/env bash
#
# Runs the analyzer from the command line.
#
# Commands are taken from the FLUTTER env var (set by the Makefile so the FVM
# wrapper is used on macOS); it defaults to the fvm-wrapped tool.
set -euo pipefail

cd "$(dirname "$0")/.."

FLUTTER="${FLUTTER:-fvm flutter}"

echo "==> Flutter analyzer"
# shellcheck disable=SC2086  # word-splitting on FLUTTER is intentional
$FLUTTER analyze
