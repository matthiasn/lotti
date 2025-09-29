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
   - `prepare_flathub_submission.sh` - Orchestrates entire offline build preparation
   - `manifest_tool/` - Python utilities for manifest manipulation (see below)
   - `download_cargo_locks.sh` - Downloads Cargo.lock files from build cache

3. **manifest_tool Python Utilities**
   - **Core Operations**: Read, validate, and manipulate YAML manifests
   - **Flutter Operations**: Handle Flutter SDK, pub packages, and plugin patches
   - **Rust Operations**: Process Cargo dependencies and vendor configurations
   - **Archive Operations**: Create and manage source archives
   - **Compliance Operations**: Ensure Flathub requirements are met

4. **Dependencies**
   - Flutter SDK - Dart/Flutter framework
   - Rust toolchain - For native Rust dependencies
   - Native libraries - libmpv, libsecret, libkeybinder, libplacebo, libass
   - Flutter plugins - Various plugins with native components

### Build Process Flow

```
[Source Code] → [Local Manifest] → [Local Build]
       ↓
[prepare_flathub_submission.sh]
       ↓
[Initial Build with Network]
       ↓
[Extract Dependencies from Build Cache]
       ↓
[Generate Offline Manifests]
       ↓
[Apply Compliance Patches]
       ↓
[Bundle All Sources]
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

   **Phase 1: Initial Build with Network**:
   - Performs test build to populate dependency cache
   - Downloads all Dart packages via pub
   - Downloads all Cargo crates
   - Caches Flutter tools dependencies

   **Phase 2: Dependency Extraction**:
   - Locates pubspec.lock files (app, flutter_tools, cargokit)
   - Finds Cargo.lock files for Rust plugins
   - Extracts dependency information from build cache
   - Downloads missing source archives

   **Phase 3: Manifest Generation**:
   - Uses flatpak-flutter tool (or fallback generators)
   - Creates flutter-sdk module manifest
   - Generates pubspec-sources.json for Dart packages
   - Generates cargo-sources.json for Rust crates
   - Creates rustup configuration

   **Phase 4: Offline Patches**:
   - Adds SQLite3 URL hash for offline verification
   - Patches cargokit scripts to use --offline flag
   - Configures Cargo to use vendored sources
   - Pre-places CMake FetchContent dependencies

   **Phase 5: Compliance Enforcement**:
   - Removes all --share=network from build-args (not finish-args)
   - Adds --offline to all flutter pub get commands
   - Adds --no-pub to flutter build commands
   - Removes flutter config commands
   - Validates no network access remains

   **Phase 6: Source Bundling**:
   - Creates app archive (`lotti-<commit>.tar.xz`)
   - Downloads all referenced sources
   - Verifies checksums
   - Copies everything to output directory

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

### CI Assertions

The script includes fail-fast assertions that will exit with error if:
- Application pubspec.lock is missing
- Python manifest_tool operations fail
- Flathub compliance violations are detected
- Required source files cannot be generated

## manifest_tool Details

### Architecture

The `manifest_tool/` directory contains modular Python utilities:

```
manifest_tool/
├── cli.py              # Command-line interface
├── manifest_ops.py     # Core YAML manipulation
├── flutter_ops.py      # Flutter-specific operations
├── rust_ops.py         # Rust/Cargo operations
├── archive_ops.py      # Source archive handling
└── tests/             # Comprehensive test suite
```

### Available Commands

```bash
# Add offline build patches (SQLite3, cargokit, Cargo config)
python3 manifest_tool/cli.py add-offline-build-patches --manifest output.yml

# Add media kit mimalloc source
python3 manifest_tool/cli.py add-media-kit-mimalloc-source --manifest output.yml

# Add SQLite3 source for CMake
python3 manifest_tool/cli.py add-sqlite3-source --manifest output.yml

# Remove network access from build-args
python3 manifest_tool/cli.py remove-network-from-build-args --manifest output.yml

# Add offline flags
python3 manifest_tool/cli.py ensure-flutter-pub-get-offline --manifest output.yml
python3 manifest_tool/cli.py ensure-dart-pub-offline-in-build --manifest output.yml

# Validate manifest
python3 manifest_tool/cli.py validate --manifest output.yml
```

### Key Functions

**add_offline_build_patches()**: Comprehensive offline patch that:
- Adds SQLite3 URL hash for CMake verification
- Patches all cargokit build scripts for offline pub
- Configures Cargo vendor sources
- Is fully idempotent (safe to run multiple times)

**Plugin Dependency Handlers**:
- Handle CMake FetchContent downloads
- Pre-place archives at expected paths
- Support multi-architecture builds

## Testing

### Python Helper Tests

The `manifest_tool/` includes comprehensive tests:

```bash
cd flatpak/manifest_tool
python3 -m venv .venv
source .venv/bin/activate
pip install pytest pyyaml
python -m pytest tests/ -v
deactivate
```

Test coverage includes:
- Manifest manipulation operations
- Idempotency verification
- Command insertion and ordering
- Edge cases and error handling
- Compliance validation

### Integration Testing

```bash
# Full end-to-end test
TEST_BUILD=true ./prepare_flathub_submission.sh

# Verify generated files
ls -la flathub-build/output/
```

## Troubleshooting

### Common Issues

**"FATAL: Application pubspec.lock not found"**
- Run a local build first to generate pubspec.lock
- Ensure you're in the correct directory

**"Failed to generate pubspec-sources.json"**
- Check Python error output in console
- Verify pubspec.lock files exist
- Ensure Python dependencies installed

**Build fails with network errors**
- Check all --offline flags are present
- Verify sources are properly bundled
- Review CI assertions output

**CMake can't find dependencies**
- Check manifest_tool plugin handlers
- Verify files placed at correct paths
- Check architecture-specific paths

### Debug Commands

```bash
# Check generated manifest
python3 -c "import yaml; yaml.safe_load(open('flathub-build/output/com.matthiasn.lotti.yml'))"

# Verify sources
find flathub-build/output -name "*.tar.*" -o -name "*.zip" | sort

# Check for network access
grep -n "share=network" flathub-build/output/com.matthiasn.lotti.yml

# Verify offline flags
grep -n "pub get" flathub-build/output/com.matthiasn.lotti.yml
```

## Permissions

The app follows the **principle of least privilege**:

### Network & System
- `--share=network` - Sync features and online functionality (runtime only - this is allowed in finish-args)
  - Note: Network access is forbidden during build (build-args) but allowed at runtime (finish-args)
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
- Ensure idempotent operations

**Two-manifest approach**:
- Source manifest stays clean with placeholders
- Generated manifests are gitignored
- Prevents accidental commits of generated files

**Offline conversion complexity**:
- Flutter's package system assumes network
- Plugins download during build
- Everything must be pre-fetched and placed correctly
- Multiple dependency systems (pub, cargo, cmake)