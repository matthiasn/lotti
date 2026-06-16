#!/usr/bin/env bash
#
# Runs the full lint suite reliably from the command line.
#
# Why this exists: `flutter analyze` now drives the LSP analysis server, which
# loads the custom_lint (riverpod_lint) plugin in-process. On a project this
# size that overwhelms the server and the OS kills it — surfacing as
# "analysis server exited with code -9" (SIGKILL). So we run the core + Very
# Good Analysis lints with the plugin TEMPORARILY disabled, then run
# custom_lint in its own process, where it is stable. custom_lint stays
# enabled in analysis_options.yaml so the IDE keeps its live riverpod lints.
#
# Commands are taken from the FLUTTER / DART env vars (set by the Makefile so
# the FVM wrapper is used on macOS); they default to the fvm-wrapped tools.
set -euo pipefail

cd "$(dirname "$0")/.."

FLUTTER="${FLUTTER:-fvm flutter}"
DART="${DART:-fvm dart}"

OPTIONS="analysis_options.yaml"
BACKUP="$(mktemp)"
cp "$OPTIONS" "$BACKUP"
restore() { cp "$BACKUP" "$OPTIONS"; rm -f "$BACKUP"; }
trap restore EXIT INT TERM

# Comment out `plugins:` / `- custom_lint` for the core analyze pass only.
sed -E -i.sedbak \
  's/^([[:space:]]*)(plugins:|- custom_lint)/\1# \2/' "$OPTIONS"
rm -f "$OPTIONS.sedbak"

echo "==> Core + Very Good Analysis lints (custom_lint temporarily disabled)"
# shellcheck disable=SC2086  # word-splitting on FLUTTER/DART is intentional
$FLUTTER analyze

# Restore the real config before running custom_lint in its own process.
restore
trap - EXIT INT TERM

echo "==> custom_lint (riverpod_lint)"
# shellcheck disable=SC2086
$DART run custom_lint
