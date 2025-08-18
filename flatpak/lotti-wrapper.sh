#!/bin/bash
# Wrapper script to launch Lotti with proper Flutter environment

set -euo pipefail

# Define constants
readonly APP_DIR="/app"
readonly LIB_DIR="/app/lib"
readonly LOTTI_BINARY="/app/bin/lotti"

# Set the library path to include both locations
# Only append existing LD_LIBRARY_PATH if non-empty to prevent trailing colon
if [[ -n "${LD_LIBRARY_PATH:-}" ]]; then
    export LD_LIBRARY_PATH="${LIB_DIR}:${LD_LIBRARY_PATH}"
else
    export LD_LIBRARY_PATH="${LIB_DIR}"
fi

# Change to the app directory where the Flutter bundle is
cd "${APP_DIR}" || {
    echo "Error: Cannot change to app directory ${APP_DIR}" >&2
    exit 1
}

# Verify the binary exists before executing
if [[ ! -x "${LOTTI_BINARY}" ]]; then
    echo "Error: Lotti binary not found or not executable at ${LOTTI_BINARY}" >&2
    exit 1
fi

# Execute the actual application
exec "${LOTTI_BINARY}" "$@"