# Flatpak Build - Direct Approach

This documents the simplified `prepare_flathub_build.sh` workflow for generating Flathub manifests.

## Quick Start

```bash
cd flatpak
./prepare_flathub_build.sh <commit-hash>
# Output in direct-build/output/
```

## How It Works

The script uses [flatpak-flutter](https://github.com/TheAppgineer/flatpak-flutter) (pinned to v0.11.0) to generate offline build manifests. This replaces the complex 12,000+ line `manifest_tool` Python orchestrator with a ~110-line bash wrapper plus a local foreign-dependency overlay.

### What It Does

1. Clones flatpak-flutter if not present
2. Applies the `flatpak_flutter_extra/` overlay: copies its mirrored patch subdirectories into flatpak-flutter's `foreign_deps/` tree, then deep-merges `flatpak_flutter_extra/foreign_deps.json` into flatpak-flutter's bundled foreign dependency database
3. Substitutes commit hash into manifest template
4. Copies `foreign.json` for custom plugin support
5. Runs flatpak-flutter to generate all dependency manifests
6. Outputs everything to `direct-build/output/`
7. Copies output to `../com.matthiasn.lotti` flathub repo (if present)

### Output Structure

```
direct-build/output/
├── com.matthiasn.lotti.yml          # Main manifest
├── generated/
│   ├── sources/
│   │   ├── cargo.json               # Rust crates (~880 entries)
│   │   └── pubspec.json             # Dart packages
│   ├── modules/
│   │   ├── flutter-sdk-X.X.X.json   # Flutter SDK + Dart SDK
│   │   └── rustup-X.X.X.json        # Rust toolchain
│   └── patches/                     # Offline build patches
└── cargokit/                        # Cargokit patches
```

## Release Workflow

### Automated (primary path)

The primary release path is the `.github/workflows/flathub-release-pr.yml`
GitHub Actions workflow ("Flathub Release PR"). It triggers on any tag push
(`on: push: tags: ['**']`) and can also be run manually via
`workflow_dispatch` (with optional `commit_sha`, `version_override`, and
`dry_run` inputs).

The workflow:
1. Checks out Lotti into `lotti/` and `flathub/com.matthiasn.lotti` into a
   sibling `com.matthiasn.lotti/`, matching the layout
   `prepare_flathub_build.sh` expects.
2. Resolves the version from `pubspec.yaml` (or `version_override`) and
   validates it as a git branch name.
3. Creates/resets a release branch named after the version from
   `origin/master` in the Flathub clone.
4. Clones flatpak-flutter at the version pinned in
   `prepare_flathub_build.sh`, installs its Python requirements, then runs
   `./flatpak/prepare_flathub_build.sh`, which copies the generated manifest
   and sources into the sibling Flathub checkout.
5. Commits and force-pushes (`--force-with-lease`) the release branch.
6. Opens (or reuses) a PR against `flathub/com.matthiasn.lotti` `master`
   using `gh` and the `FLATHUB_PAT` secret.

Once the PR is open, trigger the Flathub build by commenting `bot, build` on
it.

### Manual (local fallback)

To generate and submit a release locally instead of via the workflow:

```bash
# 1. Ensure the flathub repo is cloned as a sibling of the lotti2 repo root
#    (only needed once). prepare_flathub_build.sh looks for it at
#    <lotti2-parent>/com.matthiasn.lotti.
cd <lotti2-parent>   # the directory that contains the lotti2 checkout
git clone git@github.com:flathub/com.matthiasn.lotti.git

# 2. Generate manifest and copy to flathub repo
cd lotti2/flatpak
./prepare_flathub_build.sh <commit-hash>
# Script automatically copies output to ../../com.matthiasn.lotti/

# 3. Commit and create PR
cd ../../com.matthiasn.lotti
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
            ".pub-cache/hosted/pub.dev/flutter_vodozemac-0.5.0/rust"
        ],
        "extra_pubspecs": [
            ".pub-cache/hosted/pub.dev/flutter_vodozemac-0.5.0/cargokit/build_tool"
        ],
        "manifest": {
            "sources": [
                {
                    "type": "patch",
                    "path": "cargokit/run_build_tool.sh.patch",
                    "dest": ".pub-cache/hosted/pub.dev/flutter_vodozemac-0.5.0/cargokit"
                }
            ]
        }
    }
}
```

**When to update:**
- When `flutter_vodozemac` version changes in `pubspec.lock`
- Update all paths from `flutter_vodozemac-0.5.0` to the new version

**How to check current version:**
```bash
# Run from the repo root. The version line is 7 lines below the
# package header, so use -A8 (or pipe to grep "version:").
grep -A8 "flutter_vodozemac:" pubspec.lock | grep "version:"
```

### flatpak_flutter_extra/foreign_deps.json

This overlay extends flatpak-flutter's versioned `foreign_deps.json` without
forking the tool. Use it when a dependency in `pubspec.lock` needs extra
offline sources, hashes, or patches and the pinned flatpak-flutter release does
not know that dependency version yet.

Keep overlay versions exact and ordered from oldest to newest. `flatpak-flutter`
will otherwise reuse an older compatible entry for a newer locked package
version, which is risky for native archives and CMake patches because upstream
package contents and line endings can change.

Run this before tagging or after dependency updates:

```bash
make check_flatpak_foreign_deps
```

The check parses `pubspec.lock`, verifies that local overlay entries match the
locked versions, and dry-runs every Flatpak patch against the actual Pub cache
package directory. CI runs the same check for pull requests touching Flatpak or
dependency files.

Some upstream packages ship patched files with CRLF line endings. Keep those
patches generated from the upstream file's real line endings so the Flathub
builder's plain `patch -p1` invocation applies them.

### com.matthiasn.lotti.flatpak-flutter.yml

The source manifest template. Uses `COMMIT_PLACEHOLDER` which gets replaced by `prepare_flathub_build.sh`.

**When to update:**
- Adding/removing permissions (finish-args)
- Adding/removing native library dependencies (modules)
- Changing build commands
- Updating runtime version

## Troubleshooting

### Missing Rust dependencies in cargo.json

**Symptom:** cargo.json has far fewer entries than the healthy baseline (~880)

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
    "0.5.0": {
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
VERSION=$(grep -A8 "flutter_vodozemac:" pubspec.lock | grep "version:" | awk '{print $2}' | tr -d '"')
sed -i "s/flutter_vodozemac-[0-9.]*/flutter_vodozemac-$VERSION/g" flatpak/foreign.json
```

## Files Reference

| File | Purpose |
|------|---------|
| `prepare_flathub_build.sh` | Main script (~110 lines) |
| `check_foreign_deps.py` | Cheap PR-safe validation for foreign dependency patch drift |
| `foreign.json` | Custom plugin definitions |
| `flatpak_flutter_extra/foreign_deps.json` | Versioned overlay for flatpak-flutter's dependency database |
| `com.matthiasn.lotti.flatpak-flutter.yml` | Manifest template |
| `flatpak-flutter/` | Cloned tool (gitignored) |
| `direct-build/` | Work/output directory (gitignored) |

## Why This Approach?

The previous `manifest_tool` grew to 12,000+ lines of Python attempting to handle every edge case. This direct approach:

- Uses flatpak-flutter as intended
- ~110 lines of bash vs 12,000+ lines of Python
- Easier to understand and maintain
- Delegates complexity to upstream tool
- Only maintains what's truly custom (foreign.json)
