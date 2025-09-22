#!/bin/bash

# Update the commit placeholder in the Flatpak manifest.
# - Validates the manifest before touching it
# - Replaces 'COMMIT_PLACEHOLDER' with the current (or provided) commit

set -euo pipefail

# Resolve paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_FILE="$SCRIPT_DIR/com.matthiasn.lotti.source.yml"
PYTHON_CLI="$SCRIPT_DIR/python/cli.py"

if [ ! -f "$MANIFEST_FILE" ]; then
  echo "Error: Manifest not found: $MANIFEST_FILE" >&2
  exit 1
fi

# Detect pull_request context to pin to the PR head commit and repo
PR_MODE=false
PR_HEAD_SHA=""
PR_HEAD_REF=""
PR_HEAD_URL=""
if [ "${GITHUB_EVENT_NAME:-}" = "pull_request" ] && [ -n "${GITHUB_EVENT_PATH:-}" ] && [ -f "${GITHUB_EVENT_PATH}" ]; then
  echo "Pull request context detected; extracting head repo + SHA from event payload"
  eval "$(python3 "$PYTHON_CLI" pr-aware-pin \
    --event-name "${GITHUB_EVENT_NAME:-}" \
    --event-path "$GITHUB_EVENT_PATH")"
fi

if [ "$PR_MODE" = true ] && [ -n "$PR_HEAD_SHA" ] && [ -n "$PR_HEAD_URL" ]; then
  echo "Updating manifest for PR head: $PR_HEAD_SHA from $PR_HEAD_URL"
  # Update URL to PR head repo (handles forks) and pin commit to PR head SHA
  # Replace the first occurrence of the app repo URL under the lotti module
  sed -i "0,/url: https:\/\/github.com\/matthiasn\/lotti/s||url: $PR_HEAD_URL|" "$MANIFEST_FILE"
  # Replace placeholder with PR head SHA
  if grep -q 'commit: COMMIT_PLACEHOLDER' "$MANIFEST_FILE"; then
    sed -i "s|commit: COMMIT_PLACEHOLDER|commit: $PR_HEAD_SHA|" "$MANIFEST_FILE"
  else
    # Fallback: replace the first 'commit:' after the URL occurrence
    awk -v sha="$PR_HEAD_SHA" '
      BEGIN{changed=0}
      /url: / && $0 ~ /github.com/ && $0 ~ /lotti/ {seen_url=1}
      {
        if (seen_url && !changed && $0 ~ /^[[:space:]]*commit:[[:space:]]*/) {
          sub(/commit:.*/, "commit: " sha)
          changed=1
        }
        print $0
      }
    ' "$MANIFEST_FILE" > "$MANIFEST_FILE.tmp" && mv "$MANIFEST_FILE.tmp" "$MANIFEST_FILE"
  fi
  echo "Updated $MANIFEST_FILE for PR head commit"
else
  # Determine commit to pin for non-PR contexts
  COMMIT_HASH="${1:-$(git -C "$SCRIPT_DIR/.." rev-parse HEAD)}"
  echo "Updating Flatpak manifest with commit: $COMMIT_HASH"
  # Preflight: guard against bad states and give immediate feedback
  if grep -qE '^[[:space:]]*commit:[[:space:]]*$' "$MANIFEST_FILE"; then
    echo "Error: Empty 'commit:' field detected in $MANIFEST_FILE. Please restore 'commit: COMMIT_PLACEHOLDER' before running this script." >&2
    exit 1
  fi
  if ! grep -q 'commit: COMMIT_PLACEHOLDER' "$MANIFEST_FILE"; then
    echo "Error: No COMMIT_PLACEHOLDER found in $MANIFEST_FILE; aborting to avoid using stale commit." >&2
    exit 1
  fi
  # Replace the placeholder with the commit hash
  sed -i "s|commit: COMMIT_PLACEHOLDER|commit: $COMMIT_HASH|" "$MANIFEST_FILE"
  echo "Updated $MANIFEST_FILE with commit $COMMIT_HASH"
fi

# Show the change context
echo "Modified source configuration:"
grep -n -A3 -B1 "name: lotti" "$MANIFEST_FILE" | sed -n '1,40p' || true
