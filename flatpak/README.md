# Lotti Flatpak Build

This directory contains the Flatpak manifest and related files for building Lotti as a Flatpak application.

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

Note:
- Always run `./create_local_manifest.sh` before building — it pins the manifest by replacing `commit: COMMIT_PLACEHOLDER` with your current git HEAD (or a commit you pass in) and writes the result to `com.matthiasn.lotti.yml`.
- The script includes a guard: if it detects an empty `commit:` field or cannot find `COMMIT_PLACEHOLDER`, it will exit and print a clear message so you get immediate feedback.
- The build tooling also fails fast if any `COMMIT_PLACEHOLDER` or `branch:` entries remain in the final manifest used for submission.

You can also specify a different commit: `./create_local_manifest.sh <commit-hash>`

### Running the App

After installation:
```bash
flatpak run com.matthiasn.lotti
```

### Notes for ARM64/Apple Silicon

The manifest automatically handles architecture differences:
- Flutter SDK is cloned from Git (architecture-independent)
- Rust toolchain is installed during build
- All native dependencies are compiled for the target architecture

## Flathub Submission

### Prerequisites

The Flathub build requires all dependencies to be available offline. We use `flatpak-flutter` to generate the offline manifest and dependencies.

1. **Install Python dependencies**:
   ```bash
   sudo apt-get install python3-packaging python3-toml python3-yaml python3-requests
   ```

### Preparation Process

1. **flatpak-flutter**
   - The preparation script will clone `flatpak-flutter` automatically if needed.
   - Optional manual install:
     ```bash
     cd flatpak
     git clone https://github.com/TheAppgineer/flatpak-flutter.git
     ```

2. **Ensure your branch is pushed**:
   ```bash
   git push origin <your-branch>
   ```

   **Important**: Your branch must be pushed to GitHub before running the script, as flatpak-flutter needs to clone from the remote repository.

3. **Run the preparation script**:
   ```bash
   cd flatpak
   ./prepare_flathub_submission.sh
   ```

   The script automatically:
   - Extracts version from `pubspec.yaml` (e.g., `0.9.665+3266` → `0.9.665`)
   - Uses the current git branch (must be pushed)
   - Sets release date to today

   Or override with custom version/date:
   ```bash
   LOTTI_VERSION=1.0.0 LOTTI_RELEASE_DATE=2025-02-01 ./prepare_flathub_submission.sh
   ```

   To also test the build:
   ```bash
   TEST_BUILD=true ./prepare_flathub_submission.sh
   ```

The script will:
   - Create a clean work directory at `flatpak/flathub-build/`
   - Use version from pubspec.yaml (or override)
   - Use current git HEAD commit
   - Generate offline manifest and all dependencies using flatpak-flutter
   - Always create fully offline builds as required by Flathub:
     - Process Flutter SDK for offline use
     - Bundle all archive/file sources locally
     - Create app source archive (`lotti-<commit>.tar.xz`)
     - **Removes --share=network from build-args** (prohibited by Flathub policy)
     - **Adds --offline flag to flutter pub get** (ensures offline dependency resolution)
   - Process the metainfo.xml with version substitution
   - Output all files to `flatpak/flathub-build/output/`

#### Tuning & Env Vars

You can influence the preparation behavior with these environment variables:

- `FLATPAK_FLUTTER_TIMEOUT` — seconds to allow `flatpak-flutter` to run; unset by default (no timeout). Example: `FLATPAK_FLUTTER_TIMEOUT=1800 ./prepare_flathub_submission.sh`
- `NO_FLATPAK_FLUTTER` — set to `true` to skip running `flatpak-flutter` entirely and use the script’s fallback generators. Example: `NO_FLATPAK_FLUTTER=true ./prepare_flathub_submission.sh`
- `PIN_COMMIT` — `true` (default) to pin the app source to the current commit in the output manifest.
- `USE_NESTED_FLUTTER` — `false` (default). When `true`, references Flutter SDK JSONs as nested modules under the `lotti` module and removes the top-level `flutter-sdk` module when safe.
- `DOWNLOAD_MISSING_SOURCES` — `true` (default) to allow downloading sources that aren't found in local caches; set to `false` for strictly offline generation.
- `CLEAN_AFTER_GEN` — `true` (default) to remove the work `.flatpak-builder` directory after generation.

Tips:
- Logs are written to `flatpak/flathub-build/flatpak-flutter.log`. Use `tail -f` while preparing to monitor progress.
- If network is constrained, try `NO_FLATPAK_FLUTTER=true` to rely on fallback generators; or keep `flatpak-flutter` and set a larger `FLATPAK_FLUTTER_TIMEOUT`.

4. **Submit to Flathub**:
   - Fork the [Flathub repository](https://github.com/flathub/flathub)
   - Copy the generated files from `flatpak/flathub-build/output/` to your fork
   - Create a pull request

### Key Files

- `com.matthiasn.lotti.source.yml` - Base manifest (kept pristine; still contains COMMIT_PLACEHOLDER)
- `com.matthiasn.lotti.yml` - Generated manifest with a pinned commit (created by `create_local_manifest.sh`)
- `com.matthiasn.lotti.metainfo.xml` - App metadata with version placeholders
- `create_local_manifest.sh` - Updates COMMIT_PLACEHOLDER with actual commit hash in the manifest copy
- `prepare_flathub_submission.sh` - Prepares everything for Flathub (generates offline manifest)
- `check_complexity.sh` - Analyzes code complexity metrics for the manifest_tool Python code
- `manifest_tool/` - Python tooling for manifest manipulation and build preparation
  - `cli.py` - Command-line interface for all manifest operations
  - `flutter_ops.py` - Flutter SDK and environment manipulation functions
  - `manifest_ops.py` - Manifest modification operations (pinning, module management)
  - `sources_ops.py` - Sources manipulation (bundling, URL replacement)
  - `build_utils.py` - Build utilities (Flutter SDK copying, directory preparation)

## Creating a Bundle

To create a distributable Flatpak bundle:
```bash
# First update the manifest with desired commit
./create_local_manifest.sh

# Build into a repo
flatpak-builder --repo=repo build-dir com.matthiasn.lotti.yml

# Create the bundle
flatpak build-bundle repo lotti.flatpak com.matthiasn.lotti
```

Users can then install with:
```bash
flatpak install lotti.flatpak
```


## Permissions

The app follows the **principle of least privilege** and requests only necessary permissions:

### Network & System
- `--share=network` - For sync features and online functionality
- `--share=ipc` - Inter-process communication for GUI
- `--socket=pulseaudio` - Audio recording/playback for voice notes
- `--socket=wayland` + `--socket=fallback-x11` - Display protocols
- `--device=dri` - Hardware-accelerated graphics

### Secure Filesystem Access
- `--filesystem=xdg-documents:rw` - Read/write access to Documents folder for importing/exporting journal data
- `--filesystem=xdg-pictures:ro` - Read-only access to Pictures for importing images
- `--filesystem=xdg-download:rw` - Read/write access to Downloads for saving exports
- **App data**: Automatically stored in `~/.var/app/com.matthiasn.lotti/` (secure default)

### Security Notes
- ❌ **No `--filesystem=home`** - Removed broad home directory access for security
- ❌ **No `--socket=gpg-agent`** - Removed unnecessary GPG access
- ✅ **Minimal permissions** - Only specific directories needed for functionality
- ✅ **Read-only where possible** - Pictures access is read-only for security

## Screenshot Support

### Portal-Based Screenshots (Recommended)

When running in Flatpak, Lotti uses the XDG Desktop Portal for screenshots, which provides secure access without requiring additional tools inside the sandbox.

**Requirements on the host system:**
- `xdg-desktop-portal` - The portal service
- A backend implementation:
  - `xdg-desktop-portal-gtk` for GNOME/GTK desktops
  - `xdg-desktop-portal-kde` for KDE Plasma
  - `xdg-desktop-portal-wlr` for wlroots-based compositors

### Screenshot Tools Outside Flatpak

When running outside of Flatpak, Lotti can use traditional screenshot tools:
- `spectacle` (KDE)
- `gnome-screenshot` (GNOME)
- `scrot` (lightweight)
- `import` (ImageMagick)

## Future Improvements

### Icon Optimization
Currently, the Flatpak uses a single 1024px icon file for all sizes. For better quality and performance:
- Create pre-scaled icons: 512px, 256px, 128px, 64px, 48px, 32px, 16px
- Update the manifest to use appropriately sized icons
- This will improve rendering quality and reduce memory usage 

## Python Helper Tests

The helper scripts under `flatpak/manifest_tool/` now ship with a pytest suite. To run it locally without touching the system Python, create a virtual environment in the flatpak directory:

```bash
# Install the venv tooling once (Ubuntu/Debian only)
sudo apt install python3-venv

# Navigate to the flatpak directory (all commands should be run from here)
cd flatpak

# Create and activate the virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install test dependencies inside the venv
python -m pip install --upgrade pip
pip install pytest pyyaml

# Run the tests
python -m pytest manifest_tool/tests

# When finished
deactivate
```

> Tip: keep the `.venv/` directory out of version control (it is already covered by the root `.gitignore`).

### Code Complexity Analysis

To analyze code complexity (similar to CodeFactor):

```bash
# From the flatpak directory
./check_complexity.sh
```

This will:
- Check cyclomatic complexity (functions with complexity > 10)
- Check cognitive complexity
- Provide a summary of complex functions
- Install required tools (radon, flake8) automatically if not present
