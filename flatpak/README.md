# Lotti Flatpak Build

This directory contains the Flatpak manifest and build tooling for packaging Lotti as a Flatpak application for distribution on Flathub and other Flatpak repositories.

## Overview

The Flatpak build process involves several stages:
1. **Local Development**: Building and testing locally with network access
2. **Offline Preparation**: Converting to fully offline build for Flathub compliance
3. **CI/CD Pipeline**: Automated builds and testing in GitHub Actions
4. **Flathub Submission**: Final packaging for distribution

## Build Architecture

### Key Components

1. **Manifest Files**
   - `com.matthiasn.lotti.source.yml` - Source manifest template with placeholders
   - `com.matthiasn.lotti.yml` - Generated manifest with pinned commit (local builds)
   - Generated manifest in `flathub-build/output/` - Fully offline manifest for Flathub

2. **Build Tools**
   - `create_local_manifest.sh` - Pins commit for local builds
   - `prepare_flathub_submission.sh` - Generates offline build artifacts
   - `manifest_tool/` - Python utilities for manifest manipulation

3. **Dependencies**
   - Flutter SDK - Dart/Flutter framework
   - Rust toolchain - For native Rust dependencies
   - Native libraries - libmpv, libsecret, libkeybinder, etc.
   - Flutter plugins - Various plugins with native components

### Build Process Flow

```
[Source Code] → [Local Manifest] → [Local Build]
       ↓
[prepare_flathub_submission.sh]
       ↓
[Offline Manifest Generation]
       ↓
[Bundle All Dependencies]
       ↓
[CI/CD Testing]
       ↓
[Flathub Submission]
```

## Building Locally

### Prerequisites

1. Install flatpak, flatpak-builder, and required runtimes:
   ```bash
   # Install Flatpak and builder
   sudo apt install flatpak flatpak-builder

   # Install XDG Desktop Portal (required for screenshots)
   # For GNOME/GTK systems:
   sudo apt install xdg-desktop-portal xdg-desktop-portal-gtk
   # For KDE/Plasma systems:
   sudo apt install xdg-desktop-portal xdg-desktop-portal-kde

   # Add Flathub repository
   flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

   # Install required runtimes and SDK extensions
   flatpak install org.freedesktop.Platform//24.08 org.freedesktop.Sdk//24.08 \
                   org.freedesktop.Sdk.Extension.llvm20 org.freedesktop.Sdk.Extension.rust-stable
   ```

### Build and Install

```bash
cd flatpak
./create_local_manifest.sh
flatpak-builder --user --install --force-clean build-dir com.matthiasn.lotti.yml
```

**Important Notes:**
- Always run `./create_local_manifest.sh` before building
- This replaces `commit: COMMIT_PLACEHOLDER` with your current git HEAD
- The script includes safety guards to prevent building with placeholders

### Running the App

After installation:
```bash
flatpak run com.matthiasn.lotti
```

## Flathub Submission Process

### Understanding Flathub Requirements

Flathub has strict requirements for security and reproducibility:
- **No network access during build** - All dependencies must be pre-fetched
- **Reproducible builds** - Same inputs must produce same outputs
- **Source verification** - All sources must have checksums
- **No binary blobs** - Everything built from source

### Preparation Process

1. **Ensure your branch is pushed**:
   ```bash
   git push origin <your-branch>
   ```
   The branch must be accessible from GitHub for the offline build tools to work.

2. **Install Python dependencies**:
   ```bash
   sudo apt-get install python3-packaging python3-toml python3-yaml python3-requests
   ```

3. **Run the preparation script**:
   ```bash
   cd flatpak
   ./prepare_flathub_submission.sh
   ```

   The script performs these operations:

   **Version and Metadata**:
   - Extracts version from `pubspec.yaml`
   - Uses current git branch and commit
   - Substitutes version placeholders in metainfo.xml

   **Offline Conversion**:
   - Clones `flatpak-flutter` tool if needed
   - Generates offline Flutter SDK manifest
   - Creates pubspec-sources.json for Dart packages
   - Creates cargo-sources.json for Rust crates

   **Source Bundling**:
   - Creates app archive (`lotti-<commit>.tar.xz`)
   - Downloads and caches all archive sources
   - Bundles everything locally with checksums

   **Flathub Compliance**:
   - Removes `--share=network` from build-args
   - Adds `--offline` flag to `flutter pub get`
   - Adds `--no-pub` flag to `flutter build`
   - Handles plugin dependencies (mimalloc, SQLite)

4. **Test the offline build** (optional but recommended):
   ```bash
   TEST_BUILD=true ./prepare_flathub_submission.sh
   ```

5. **Submit to Flathub**:
   - Files are generated in `flatpak/flathub-build/output/`
   - Fork [flathub/flathub](https://github.com/flathub/flathub)
   - Copy generated files to your fork
   - Create pull request

### Environment Variables

Fine-tune the preparation process:

| Variable | Default | Description |
|----------|---------|-------------|
| `FLATPAK_FLUTTER_TIMEOUT` | None | Timeout for flatpak-flutter (seconds) |
| `NO_FLATPAK_FLUTTER` | false | Skip flatpak-flutter, use fallback generators |
| `PIN_COMMIT` | true | Pin app source to current commit |
| `USE_NESTED_FLUTTER` | false | Use nested Flutter SDK modules |
| `DOWNLOAD_MISSING_SOURCES` | true | Download sources not in cache |
| `CLEAN_AFTER_GEN` | true | Remove work directory after generation |
| `TEST_BUILD` | false | Run test build after preparation |

### Debugging Tips

- Monitor progress: `tail -f flatpak/flathub-build/flatpak-flutter.log`
- Check generated manifest: `flatpak/flathub-build/output/com.matthiasn.lotti.yml`
- Verify sources: `ls -la flatpak/flathub-build/output/`

## CI/CD Pipeline

### GitHub Actions Workflow

The `.github/workflows/flatpak-offline-build.yml` workflow:
1. Sets up Flatpak build environment
2. Runs manifest_tool tests
3. Prepares Flathub build artifacts
4. Attempts offline build to verify everything works

### Common CI Issues and Solutions

**Issue: Flutter pub get hangs**
- **Cause**: No network in sandbox, pub trying to fetch
- **Solution**: Added `--offline` flag to `flutter pub get`

**Issue: dart pub get --example during build**
- **Cause**: Flutter build internally runs pub get
- **Solution**: Added `--no-pub` flag to `flutter build linux`

**Issue: Plugin downloads during build (mimalloc, SQLite)**
- **Cause**: CMake FetchContent trying to download
- **Solution**: Pre-place files where CMake expects them

## Plugin Dependencies Challenge

### The Problem

Some Flutter plugins use CMake FetchContent to download dependencies during build:
- `media_kit_libs_linux` → downloads mimalloc
- `sqlite3_flutter_libs` → downloads SQLite

This violates Flathub's no-network policy.

### Current Solution

The `manifest_tool` includes functions to handle these:

1. **add_media_kit_mimalloc_source()**
   - Adds mimalloc tar.gz as a file source
   - CMake finds and extracts it during build

2. **add_sqlite3_source()**
   - Adds SQLite tar.gz for both architectures
   - Places at exact path CMake expects
   - Handles x86_64 and aarch64 separately

### Implementation Details

```yaml
# Generated manifest includes:
- type: file
  only-arches: [x86_64]
  url: https://www.sqlite.org/2025/sqlite-autoconf-3500400.tar.gz
  sha256: a3db587a1b92ee5ddac2f66b3edb41b26f9c867275782d46c3a088977d6a5b18
  dest: ./build/linux/x64/release/_deps/sqlite3-subbuild/sqlite3-populate-prefix/src
  dest-filename: sqlite-autoconf-3500400.tar.gz
```

## Permissions

The app follows the **principle of least privilege**:

### Network & System
- `--share=network` - Sync features and online functionality
- `--share=ipc` - Inter-process communication for GUI
- `--socket=pulseaudio` - Audio recording/playback
- `--socket=wayland` + `--socket=fallback-x11` - Display protocols
- `--device=dri` - Hardware-accelerated graphics

### Secure Filesystem Access
- `--filesystem=xdg-documents/Lotti:create` - App's document folder
- `--filesystem=xdg-pictures:ro` - Read-only Pictures access
- `--filesystem=xdg-download/Lotti:create` - App's download folder
- App data in `~/.var/app/com.matthiasn.lotti/` (sandboxed)

### Security Notes
- ❌ No broad home directory access
- ❌ No unnecessary system access
- ✅ Minimal permissions
- ✅ Read-only where possible

## Testing

### Python Helper Tests

The `manifest_tool/` includes comprehensive tests:

```bash
cd flatpak
python3 -m venv .venv
source .venv/bin/activate
pip install pytest pyyaml
python -m pytest manifest_tool/tests
deactivate
```

### Code Quality

Check code complexity:
```bash
./check_complexity.sh
```

This analyzes:
- Cyclomatic complexity (target: < 10)
- Cognitive complexity
- Code quality metrics

## Troubleshooting

### Common Issues

**Build fails with "Could not resolve host"**
- The build is trying network access
- Check for missing offline flags
- Verify all sources are bundled

**CMake can't find dependencies**
- Plugin trying to download during build
- Check manifest_tool plugin handlers
- Verify files placed at correct paths

**Flutter SDK not found**
- Check Flutter SDK module in manifest
- Verify offline SDK generation worked
- Check build environment paths

### Debug Commands

```bash
# Check what's in the build directory
flatpak run --command=bash com.matthiasn.lotti
ls -la /app/

# Check build logs
flatpak-builder --verbose --keep-build-dirs ...

# Verify manifest syntax
python3 -c "import yaml; yaml.safe_load(open('com.matthiasn.lotti.yml'))"
```

## Contributing

When modifying the build system:
1. Test locally first with `create_local_manifest.sh`
2. Run `prepare_flathub_submission.sh` to verify offline build
3. Check CI passes in pull request
4. Update tests if adding new manifest operations
5. Keep complexity low (< 10 cyclomatic complexity)

## Architecture Notes

### Why These Tools Exist

**manifest_tool/**: Custom Python utilities because:
- `flatpak-flutter` doesn't handle all our specific needs
- Need to manipulate manifest for Flathub compliance
- Plugin dependencies require special handling
- Automation of repetitive tasks

**Two-manifest approach**:
- Source manifest stays clean with placeholders
- Generated manifests are gitignored
- Prevents accidental commits of generated files

**Offline conversion complexity**:
- Flutter's package system assumes network
- Plugins download during build
- Everything must be pre-fetched and placed correctly