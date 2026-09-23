#!/usr/bin/env bash
# Model-check the TLA+ specs in this directory with TLC.
#
#   specs/tla/tlc.sh                      # every *.cfg next to its spec
#   specs/tla/tlc.sh SyncSequenceCrash    # one configuration
#
# A configuration `<Spec><Variant>.cfg` checks `<Spec>.tla`; the spec name is
# the longest `*.tla` basename the configuration name starts with.
#
# Needs Java 11 or newer on PATH (or JAVA=/path/to/java). The pinned
# tla2tools.jar is downloaded once, checksum-verified, and cached in
# TLA_TOOLS_DIR (default: ~/.cache/lotti-tla).
set -euo pipefail

TLA_VERSION="1.7.4"
TLA_SHA256="936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tools_dir="${TLA_TOOLS_DIR:-$HOME/.cache/lotti-tla}"
jar="$tools_dir/tla2tools-$TLA_VERSION.jar"
java_bin="${JAVA:-java}"

if [[ ! -f "$jar" ]]; then
  mkdir -p "$tools_dir"
  curl -fsSL -o "$jar.part" \
    "https://github.com/tlaplus/tlaplus/releases/download/v$TLA_VERSION/tla2tools.jar"
  mv "$jar.part" "$jar"
fi
echo "$TLA_SHA256  $jar" | sha256sum --check --quiet

spec_for() {
  local config="$1" best=""
  for tla in "$here"/*.tla; do
    local name
    name="$(basename "$tla" .tla)"
    if [[ "$config" == "$name"* && ${#name} -gt ${#best} ]]; then
      best="$name"
    fi
  done
  if [[ -z "$best" ]]; then
    echo "no spec matches configuration $config" >&2
    exit 1
  fi
  echo "$best"
}

if [[ $# -gt 0 ]]; then
  configs=("$@")
else
  configs=()
  for cfg in "$here"/*.cfg; do
    configs+=("$(basename "$cfg" .cfg)")
  done
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

for config in "${configs[@]}"; do
  spec="$(spec_for "$config")"
  echo "== $config ($spec.tla)"
  # TLC writes its state files next to the spec; keep them out of the tree.
  cp "$here/$spec.tla" "$here/$config.cfg" "$work/"
  (
    cd "$work"
    "$java_bin" -XX:+UseParallelGC -cp "$jar" tlc2.TLC \
      -workers auto -cleanup -config "$config.cfg" "$spec.tla"
  )
done
