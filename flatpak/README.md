# Lotti Flatpak Build

This directory contains the Flatpak manifest and related files for building Lotti as a Flatpak application.

## Quick Start with Build Script

The easiest way to build and run Lotti as a Flatpak is using the provided build script:

```bash
cd flatpak
./flatpak_lotti_build.sh        # Build and run (default)
./flatpak_lotti_build.sh build   # Build only
./flatpak_lotti_build.sh run     # Run already built app
./flatpak_lotti_build.sh clean   # Clean build artifacts
./flatpak_lotti_build.sh install # Install to system
./flatpak_lotti_build.sh help    # Show all options
```

The script automatically:
- Checks and installs prerequisites
- Builds the Flutter app
- Prepares the bundle correctly
- Builds the Flatpak package
- Handles common issues (like stuck mounts)
- Runs the app

## Manual Build Process

If you prefer to build manually:

### Prerequisites

Before building the Flatpak, you need to prepare the Flutter bundle:

1. Build the Flutter Linux application:
   ```bash
   flutter build linux --release
   ```

2. Create the `flutter-bundle` directory structure:
   ```bash
   mkdir -p flatpak/flutter-bundle
   cp -r build/linux/x64/release/bundle/. flatpak/flutter-bundle/
   ```

3. Ensure the MaterialIcons font is included:
   ```bash
   cp fonts/MaterialIcons-Regular.otf flatpak/flutter-bundle/data/flutter_assets/fonts/
   ```

### Building the Flatpak build

1. Install flatpak & flatpak-builder & runtimes:
   ```bash
   sudo apt install flatpak flatpak-builder
   flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
   flatpak install org.freedesktop.Platform//24.08 org.freedesktop.Sdk//24.08 org.freedesktop.Sdk.Extension.llvm20 org.freedesktop.Sdk.Extension.rust-stable
   ```

2Build and install:
   ```bash
   cd flatpak
   flatpak-builder --user --install --force-clean build-dir com.matthiasn.lotti.yml
   ```

## Directory Structure

The build expects this structure in `flutter-bundle/`:
```
flutter-bundle/
├── lotti                    # Main executable
├── lib/                     # Shared libraries (.so files)
├── data/                    # Flutter runtime data
│   ├── flutter_assets/      # Flutter assets
│   │   └── fonts/          # Including MaterialIcons-Regular.otf
│   └── icudtl.dat          # ICU data
└── share/                   # Desktop integration files
```

## Manifest Improvements

The new manifest uses a maintainable approach:
- **Single source**: `type: dir` pointing to `flutter-bundle/`
- **Automatic**: Captures all Flutter build outputs without manual listing
- **Future-proof**: Works with any Flutter build changes
- **Clean**: Reduced from 200+ lines to ~10 lines for the main module

This eliminates the need to manually maintain lists of individual files and makes the build process more robust.

### Create Bundle
```bash
flatpak build-bundle repo lotti.flatpak com.matthiasn.lotti
```

## Distribution

### Flathub
To submit to Flathub:
1. Fork the [Flathub repository](https://github.com/flathub/flathub)
2. Add the manifest to `com.matthiasn.lotti.yml` (filename must match app-id)
3. Submit a pull request

### Direct Distribution
Users can install the bundle with:
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

## Screenshot Tools

The app includes support for multiple screenshot tools:
- spectacle (KDE)
- gnome-screenshot (GNOME)
- scrot (lightweight)
- import (ImageMagick)

These are handled by the app's internal screenshot functionality.

## Future Improvements

### Icon Optimization
Currently, the Flatpak uses a single 1024px icon file for all sizes. For better quality and performance:
- Create pre-scaled icons: 512px, 256px, 128px, 64px, 48px, 32px, 16px
- Update the manifest to use appropriately sized icons
- This will improve rendering quality and reduce memory usage 