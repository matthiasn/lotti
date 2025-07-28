# Ubuntu Linux Icon Display Fix

This directory contains the solution for fixing the app icon display issue in Ubuntu Linux VM for the Lotti Flutter app.

## Problem

The Lotti Flutter app was showing a generic gear/settings icon in the Ubuntu sidebar/dock instead of the actual Lotti app icon when running from Android Studio in a VirtualBox Ubuntu VM.

## Root Causes Identified

1. **Missing Desktop Integration**: No proper `.desktop` file for Linux desktop environments
2. **Incorrect Icon Paths**: Icon path in `my_application.cc` was relative and didn't work from development environment
3. **Missing WM_CLASS**: Window manager couldn't properly identify the application
4. **No Icon Installation**: Icons weren't installed in standard Linux locations

## Solution Components

### 1. Enhanced Linux Runner (`my_application.cc`)

- **Added WM_CLASS setting**: `gtk_window_set_wmclass(window, "lotti", "Lotti")`
- **Multi-path icon loading**: Tries multiple icon paths for development and production environments
- **Icon name fallback**: Sets icon name for desktop integration fallback
- **Debug logging**: Prints icon loading status for troubleshooting

### 2. Desktop File (`com.matthiasnehlsen.lotti.desktop`)

- Proper Linux desktop entry file with correct APPLICATION_ID
- Includes all necessary metadata (Name, Comment, Categories, Keywords)
- Sets correct `StartupWMClass` to match the GTK application

### 3. Icon System (`icons/` directory)

- Generated icons in all standard Linux sizes (16x16 to 1024x1024)
- Proper naming convention: `com.matthiasnehlsen.lotti.png`
- Organized in standard hicolor icon theme structure

### 4. CMake Integration (`CMakeLists.txt`)

- Automatically installs desktop file and icons during build
- Copies icons to Flutter assets for runtime access
- Creates proper directory structure for desktop integration

### 5. Development Script (`install_dev_desktop_integration.sh`)

- Installs desktop integration files for development environment
- Updates desktop database and icon cache
- Provides absolute paths for development builds
- Includes instructions and troubleshooting tips

## Usage Instructions

### For Development Environment (Android Studio + Ubuntu VM)

1. **Build the Linux app first**:
   ```bash
   flutter build linux
   ```

2. **Run the desktop integration script**:
   ```bash
   ./linux/install_dev_desktop_integration.sh
   ```

3. **Launch the app from Android Studio or command line**:
   ```bash
   # From Android Studio: Just run/debug as usual
   # Or from command line:
   ./build/linux/x64/debug/bundle/lotti
   ```

4. **Check the Ubuntu dock/sidebar** - the correct Lotti icon should now appear

### For Production Builds

The CMake configuration automatically handles desktop integration:

```bash
flutter build linux
# The build process will install desktop files and icons automatically
```

## File Structure

```
linux/
├── com.matthiasnehlsen.lotti.desktop     # Desktop entry file
├── install_dev_desktop_integration.sh    # Development setup script
├── icons/                                # Icon files in standard Linux structure
│   └── hicolor/
│       ├── 16x16/apps/
│       ├── 32x32/apps/
│       ├── 48x48/apps/
│       ├── 64x64/apps/
│       ├── 128x128/apps/
│       ├── 256x256/apps/
│       ├── 512x512/apps/
│       └── 1024x1024/apps/
├── runner/
│   ├── my_application.cc                 # Enhanced with icon fixes
│   └── ...
└── CMakeLists.txt                        # Updated with desktop integration
```

## Technical Details

### Window Manager Integration

- **APPLICATION_ID**: `com.matthiasnehlsen.lotti` (defined in CMakeLists.txt)
- **WM_CLASS**: Set to `"lotti", "Lotti"` for proper window identification
- **Icon Name**: `com.matthiasnehlsen.lotti` for desktop theme integration

### Icon Loading Strategy

The application tries multiple icon paths in order:
1. `data/flutter_assets/assets/icon/app_icon_1024.png` (Production)
2. `assets/icon/app_icon_1024.png` (Development)
3. `../assets/icon/app_icon_1024.png` (Alternative development)
4. Falls back to icon name: `com.matthiasnehlsen.lotti`

### Desktop File Standards

The `.desktop` file follows freedesktop.org standards:
- **Type**: Application
- **Categories**: Office;Productivity;
- **StartupWMClass**: Matches GTK WM_CLASS for proper window grouping
- **Icon**: Uses standard icon naming convention

## Troubleshooting

### Icon Still Not Showing

1. **Check if desktop integration script ran successfully**:
   ```bash
   ./linux/install_dev_desktop_integration.sh
   ```

2. **Verify files are installed**:
   ```bash
   ls -la ~/.local/share/applications/com.matthiasnehlsen.lotti.desktop
   ls -la ~/.local/share/icons/hicolor/*/apps/com.matthiasnehlsen.lotti.png
   ```

3. **Update desktop database manually**:
   ```bash
   update-desktop-database ~/.local/share/applications
   gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor
   ```

4. **Restart desktop session** (logout/login or restart VM)

### Debug Icon Loading

The application prints debug messages about icon loading:
```bash
./build/linux/x64/debug/bundle/lotti
# Look for messages like:
# "Successfully loaded icon from: ..."
# "Failed to load icon from ..."
```

### VM-Specific Issues

If running in VirtualBox Ubuntu VM:
1. Ensure VM has sufficient graphics acceleration enabled
2. Install Guest Additions for better desktop integration
3. Verify the desktop environment supports custom icons

## Testing Checklist

- [ ] App builds successfully with `flutter build linux`
- [ ] Desktop integration script runs without errors
- [ ] App launches from Android Studio
- [ ] Correct icon appears in Ubuntu dock/sidebar when app is running
- [ ] Icon persists when app is minimized/restored
- [ ] Desktop file appears in application menus (if applicable)

## Notes

- This solution works for both development (Android Studio) and production environments
- The fix is compatible with different Ubuntu desktop environments (GNOME, Unity, etc.)
- Icons are generated from the existing `assets/icon/app_icon_1024.png`
- The solution follows Linux desktop integration best practices 