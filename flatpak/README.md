# Lotti Flatpak

This directory contains the Flatpak configuration for distributing Lotti on Linux.

## Files

- `com.matthiasnehlsen.lotti.yml` - Main Flatpak manifest
- `com.matthiasnehlsen.lotti.desktop` - Desktop entry file
- `com.matthiasnehlsen.lotti.metainfo.xml` - AppStream metadata
- `build.sh` - Build script

## Prerequisites

1. Install Flatpak and flatpak-builder:
   ```bash
   sudo apt install flatpak flatpak-builder
   ```

2. Add the Flutter runtime (if not already added):
   ```bash
   flatpak install org.gnome.Platform//45 org.gnome.Sdk//45
   ```

## Configuration

The build process supports environment variables for customization:

- `LOTTI_REPO_URL` - Git repository URL (default: https://github.com/matthiasn/lotti.git)
- `LOTTI_VERSION` - Version/tag to build (default: v0.9.645)
- `LOTTI_RELEASE_DATE` - Release date in YYYY-MM-DD format (default: 2025-01-26)

### Example Configuration
```bash
export LOTTI_REPO_URL="https://github.com/yourusername/lotti.git"
export LOTTI_VERSION="v1.0.0"
export LOTTI_RELEASE_DATE="2025-02-01"
```

Or copy and customize the example file:
```bash
cp flatpak/env.example .env
# Edit .env file with your values
source .env
```

## Building

### Quick Build (Recommended)
```bash
./flatpak/build.sh
```

### Manual Build
The template files contain placeholders that need variable substitution. You have two options:

```bash
# Option 1: Use the build script (recommended)
./flatpak/build.sh

# Option 2: Manual substitution (advanced users)
# First, set environment variables
export LOTTI_REPO_URL="https://github.com/matthiasn/lotti.git"
export LOTTI_VERSION="v0.9.645" 
export LOTTI_RELEASE_DATE="2025-01-26"

# Generate manifest with substituted variables
sed -e "s|{{LOTTI_REPO_URL}}|$LOTTI_REPO_URL|g" \
    -e "s|{{LOTTI_VERSION}}|$LOTTI_VERSION|g" \
    flatpak/com.matthiasnehlsen.lotti.yml > flatpak/com.matthiasnehlsen.lotti.generated.yml

# Generate metainfo with substituted variables  
sed -e "s|{{LOTTI_VERSION}}|$LOTTI_VERSION|g" \
    -e "s|{{LOTTI_RELEASE_DATE}}|$LOTTI_RELEASE_DATE|g" \
    flatpak/com.matthiasnehlsen.lotti.metainfo.xml > flatpak/com.matthiasnehlsen.lotti.generated.metainfo.xml

# Build with generated manifest
flatpak-builder --force-clean --repo=repo build-dir flatpak/com.matthiasnehlsen.lotti.generated.yml
```

## Installing

### Install Locally
The build script will show you the correct installation command. Alternatively, you can use:

**Option 1: Use the build script (recommended)**
```bash
./flatpak/build.sh
# Follow the installation instructions shown by the script
```

**Option 2: Manual installation after build**
```bash
# After running ./flatpak/build.sh successfully, install with the generated manifest
flatpak-builder --user --install --force-clean build-dir com.matthiasnehlsen.lotti.generated.yml
```

**Option 3: Install from template (requires environment variables)**
```bash
# Set your environment variables first
export LOTTI_REPO_URL="https://github.com/matthiasn/lotti.git"
export LOTTI_VERSION="v0.9.645"
export LOTTI_RELEASE_DATE="2025-01-26"

# Install directly from template
flatpak-builder --user --install --force-clean build-dir flatpak/com.matthiasnehlsen.lotti.yml
```

Note: The `com.matthiasnehlsen.lotti.generated.yml` file is generated in the project root by the build script.

### Create Bundle
```bash
flatpak build-bundle repo lotti.flatpak com.matthiasnehlsen.lotti
```

## Distribution

### Flathub
To submit to Flathub:
1. Fork the [Flathub repository](https://github.com/flathub/flathub)
2. Add the manifest to `com.matthiasnehlsen.lotti.yml` (filename must match app-id)
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
- **App data**: Automatically stored in `~/.var/app/com.matthiasnehlsen.lotti/` (secure default)

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