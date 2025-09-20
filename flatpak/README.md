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
flatpak-builder --user --install --force-clean build-dir com.matthiasn.lotti.yml
```

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

The Flathub build requires all dependencies to be available offline. The `prepare_flathub_submission.sh` script handles this preparation.

### Preparation Process

1. **Run the preparation script**:
   ```bash
   cd flatpak
   ./prepare_flathub_submission.sh
   ```

   Or with custom version:
   ```bash
   LOTTI_VERSION=v1.0.0 LOTTI_RELEASE_DATE=2025-02-01 ./prepare_flathub_submission.sh
   ```

   The script will:
   - Automatically detect version from git tags (or use provided version)
   - Generate Flutter SDK configuration
   - Download and prepare all dependencies for offline build
   - Process the metainfo.xml with version substitution
   - Copy all necessary files to the flathub repository

2. **Submit to Flathub**:
   - Fork the [Flathub repository](https://github.com/flathub/flathub)
   - Follow the instructions shown by the preparation script
   - Create a pull request

### Key Files

- `com.matthiasn.lotti.yml` - Local build manifest (requires network)
- `com.matthiasn.lotti.flathub.yml` - Flathub manifest (offline build)
- `com.matthiasn.lotti.metainfo.xml` - App metadata with version placeholders
- `prepare_flathub_submission.sh` - Prepares everything for Flathub

## Creating a Bundle

To create a distributable Flatpak bundle:
```bash
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

### Troubleshooting Screenshot Issues

If screenshots aren't working in the Flatpak version:

1. **Check portal installation:**
   ```bash
   # Check if portal service is running
   systemctl --user status xdg-desktop-portal

   # Restart portal service if needed
   systemctl --user restart xdg-desktop-portal
   ```

2. **Verify portal backend:**
   ```bash
   # Check which portal backend is installed
   ls /usr/share/xdg-desktop-portal/portals/
   ```

3. **Test portal availability:**
   ```bash
   # Test if screenshot portal works
   gdbus call --session \
     --dest org.freedesktop.portal.Desktop \
     --object-path /org/freedesktop/portal/desktop \
     --method org.freedesktop.portal.Screenshot.Screenshot \
     "" "{}"
   ```

### Fallback Screenshot Tools

If the portal isn't available, Lotti can fall back to traditional screenshot tools when running outside of Flatpak:
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