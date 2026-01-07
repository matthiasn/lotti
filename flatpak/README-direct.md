# Flatpak Build - Direct Approach

This documents the simplified `prepare_direct.sh` workflow for generating Flathub manifests.

## Quick Start

```bash
cd flatpak
./prepare_direct.sh <commit-hash>
# Output in direct-build/output/
```

## How It Works

The script uses [flatpak-flutter](https://github.com/TheAppgineer/flatpak-flutter) directly to generate offline build manifests. This replaces the complex 12,000+ line `manifest_tool` Python orchestrator with ~50 lines of bash.

### What It Does

1. Clones flatpak-flutter if not present
2. Substitutes commit hash into manifest template
3. Copies `foreign.json` for custom plugin support
4. Runs flatpak-flutter to generate all dependency manifests
5. Outputs everything to `direct-build/output/`

### Output Structure

```
direct-build/output/
├── com.matthiasn.lotti.yml          # Main manifest
├── generated/
│   ├── sources/
│   │   ├── cargo.json               # Rust crates (~3500 entries)
│   │   └── pubspec.json             # Dart packages
│   ├── modules/
│   │   ├── flutter-sdk-X.X.X.json   # Flutter SDK + Dart SDK
│   │   └── rustup-X.X.X.json        # Rust toolchain
│   └── patches/                     # Offline build patches
└── cargokit/                        # Cargokit patches
```

## Release Workflow

```bash
# 1. Generate manifest for new commit
cd flatpak
./prepare_direct.sh <commit-hash>

# 2. Copy to flathub repo
cp direct-build/output/com.matthiasn.lotti.yml /path/to/flathub-repo/
cp -r direct-build/output/generated/* /path/to/flathub-repo/generated/

# 3. Commit and create PR
cd /path/to/flathub-repo
git add -A
git commit -m "chore: release X.X.X"
git push

# 4. Trigger build on PR
# Comment: bot, build
```

## Manual Maintenance

### foreign.json

This file tells flatpak-flutter about plugins not in its built-in database.

**Current contents:**
```json
{
    "flutter_vodozemac": {
        "cargo_locks": [
            ".pub-cache/hosted/pub.dev/flutter_vodozemac-0.4.1/rust"
        ],
        "extra_pubspecs": [
            ".pub-cache/hosted/pub.dev/flutter_vodozemac-0.4.1/cargokit/build_tool"
        ],
        "manifest": {
            "sources": [
                {
                    "type": "patch",
                    "path": "cargokit/run_build_tool.sh.patch",
                    "dest": ".pub-cache/hosted/pub.dev/flutter_vodozemac-0.4.1/cargokit"
                }
            ]
        }
    }
}
```

**When to update:**
- When `flutter_vodozemac` version changes in `pubspec.lock`
- Update all paths from `flutter_vodozemac-0.4.1` to the new version

**How to check current version:**
```bash
grep -A5 "flutter_vodozemac:" pubspec.lock
```

### com.matthiasn.lotti.flatpak-flutter.yml

The source manifest template. Uses `COMMIT_PLACEHOLDER` which gets replaced by `prepare_direct.sh`.

**When to update:**
- Adding/removing permissions (finish-args)
- Adding/removing native library dependencies (modules)
- Changing build commands
- Updating runtime version

## Troubleshooting

### Missing Rust dependencies in cargo.json

**Symptom:** cargo.json has ~400 entries instead of ~3500

**Cause:** `foreign.json` missing or has wrong version

**Fix:** Ensure `flatpak/foreign.json` exists with correct flutter_vodozemac version

### Build hangs on "Resolving dependencies..."

**Cause:** Missing `--no-pub` flag

**Fix:** Ensure build command is `flutter build linux --release --no-pub --verbose`

### "setup-flutter.sh: command not found"

**Cause:** Flutter bin not in PATH

**Fix:** Ensure manifest has `/var/lib/flutter/bin` in `append-path`

### Dart SDK download fails

**Cause:** Flutter SDK module missing pre-cached Dart SDK

**Fix:** Use flatpak-flutter's generated `flutter-sdk-*.json` (includes Dart SDK)

## Future Improvements

### Contribute flutter_vodozemac upstream

The ideal fix is adding `flutter_vodozemac` to flatpak-flutter's built-in `foreign_deps.json`:

```json
"flutter_vodozemac": {
    "0.4.1": {
        "cargo_locks": ["$PUB_DEV/rust"],
        "extra_pubspecs": ["$PUB_DEV/cargokit/build_tool"],
        "manifest": {
            "sources": [
                {
                    "type": "patch",
                    "path": "cargokit/run_build_tool.sh.patch",
                    "dest": "$PUB_DEV/cargokit"
                }
            ]
        }
    }
}
```

This would eliminate the need for local `foreign.json` maintenance.

**PR target:** https://github.com/TheAppgineer/flatpak-flutter

### Auto-detect foreign.json version

Could add a script to automatically update foreign.json paths when pubspec.lock changes:

```bash
VERSION=$(grep -A3 "flutter_vodozemac:" pubspec.lock | grep "version:" | awk '{print $2}' | tr -d '"')
sed -i "s/flutter_vodozemac-[0-9.]*/flutter_vodozemac-$VERSION/g" flatpak/foreign.json
```

## Files Reference

| File | Purpose |
|------|---------|
| `prepare_direct.sh` | Main script (~50 lines) |
| `foreign.json` | Custom plugin definitions |
| `com.matthiasn.lotti.flatpak-flutter.yml` | Manifest template |
| `flatpak-flutter/` | Cloned tool (gitignored) |
| `direct-build/` | Work/output directory (gitignored) |

## Why This Approach?

The previous `manifest_tool` grew to 12,000+ lines of Python attempting to handle every edge case. This direct approach:

- Uses flatpak-flutter as intended
- ~50 lines of bash vs 12,000+ lines of Python
- Easier to understand and maintain
- Delegates complexity to upstream tool
- Only maintains what's truly custom (foreign.json)
