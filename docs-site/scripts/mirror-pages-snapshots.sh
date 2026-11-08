#!/usr/bin/env bash
# Mirror the manual site snapshots a GitHub Pages deploy keeps.
#
# Usage: mirror-pages-snapshots.sh <bucket> <endpoint-url> <pages-output-root>
#
# Every `.snapshot.json` marker comes down first (a few bytes each); the
# assembler's plan then names the snapshots Pages keeps (`development` and the
# newest releases), and only those are downloaded in full. Pruned snapshots
# stay in R2 untouched and are never fetched.
set -euo pipefail

bucket="$1"
endpoint="$2"
output_root="$3"
script_dir="$(cd "$(dirname "$0")" && pwd)"
manual="${output_root}/manual"

aws s3 sync "s3://${bucket}/manual-site" "$manual" \
  --endpoint-url "$endpoint" --no-progress \
  --exclude '*' --include '*/.snapshot.json'

retained="$(node "${script_dir}/assemble-pages-site.mjs" \
  --list-retained --output-root "$output_root")"
echo "Snapshots kept on Pages: ${retained//$'\n'/, }"

while IFS= read -r version; do
  [[ -n "$version" ]] || continue
  aws s3 sync "s3://${bucket}/manual-site/${version}" "${manual}/${version}" \
    --endpoint-url "$endpoint" --no-progress
done <<< "$retained"
