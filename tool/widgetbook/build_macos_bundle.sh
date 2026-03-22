#!/usr/bin/env bash
set -euo pipefail

upload_release=false
skip_build=false
release_tag="widgetbook-macos-latest"
release_title="Widgetbook macOS Latest"
release_notes="Latest local Widgetbook macOS bundle."

while (($# > 0)); do
  case "$1" in
    --upload-release)
      upload_release=true
      shift
      ;;
    --skip-build)
      skip_build=true
      shift
      ;;
    --release-tag)
      release_tag="${2:?Missing value for --release-tag}"
      shift 2
      ;;
    --release-title)
      release_title="${2:?Missing value for --release-title}"
      shift 2
      ;;
    --release-notes)
      release_notes="${2:?Missing value for --release-notes}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script must be run on macOS." >&2
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

if command -v fvm >/dev/null 2>&1; then
  flutter_cmd=(fvm flutter)
else
  flutter_cmd=(flutter)
fi

product_name="$(
  sed -n 's/^[[:space:]]*PRODUCT_NAME[[:space:]]*=[[:space:]]*//p' \
    macos/Runner/Configs/AppInfo.xcconfig | head -n 1
)"

if [[ -z "$product_name" ]]; then
  echo "Could not determine PRODUCT_NAME from macOS app config." >&2
  exit 1
fi

export_root="$repo_root/build/widgetbook_macos_export"
source_app="$repo_root/build/macos/Build/Products/Release/$product_name.app"
bundle_name="Lotti_Widgetbook.app"
bundle_path="$export_root/$bundle_name"
zip_path="$export_root/Lotti_Widgetbook.app.zip"

mkdir -p "$export_root"

if [[ "$skip_build" == false ]]; then
  rm -rf "$bundle_path"
  rm -f "$zip_path"

  "${flutter_cmd[@]}" pub get

  "${flutter_cmd[@]}" build macos \
    --target lib/widgetbook.dart \
    --release

  if [[ ! -d "$source_app" ]]; then
    echo "Expected macOS app bundle was not produced at: $source_app" >&2
    exit 1
  fi

  cp -R "$source_app" "$bundle_path"

  ditto -c -k --keepParent --sequesterRsrc "$bundle_path" "$zip_path"
elif [[ ! -f "$zip_path" ]]; then
  echo "Expected existing zip was not found at: $zip_path" >&2
  echo "Run the build first, or omit --skip-build." >&2
  exit 1
fi

if [[ -d "$bundle_path" ]]; then
  bundle_size="$(du -sh "$bundle_path" | awk '{print $1}')"
else
  bundle_size="not present"
fi
zip_size="$(du -sh "$zip_path" | awk '{print $1}')"

echo "Widgetbook macOS bundle ready."
echo "App: $bundle_path ($bundle_size)"
echo "Zip: $zip_path ($zip_size)"

if [[ "$upload_release" == true ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "gh CLI is required for --upload-release." >&2
    exit 1
  fi

  current_ref="$(git rev-parse HEAD)"

  git tag -f "$release_tag" "$current_ref"
  git push origin "refs/tags/$release_tag" --force

  if gh release view "$release_tag" >/dev/null 2>&1; then
    gh release edit "$release_tag" \
      --title "$release_title" \
      --notes "$release_notes" \
      --prerelease
  else
    gh release create "$release_tag" \
      --target "$current_ref" \
      --title "$release_title" \
      --notes "$release_notes" \
      --prerelease
  fi

  gh release upload "$release_tag" "$zip_path" --clobber

  echo "Uploaded $zip_path to GitHub release $release_tag."
fi
