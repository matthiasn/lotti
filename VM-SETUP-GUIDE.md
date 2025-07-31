# Lotti Flatpak Setup Guide for Kubuntu VM

This guide provides a direct, working solution to run the Lotti Flutter app in a Kubuntu VM using Flatpak.

## Prerequisites

Your VM should have:
- Kubuntu 22.04 or later
- At least 4GB RAM
- At least 10GB free disk space
- Flutter SDK installed
- Git installed

## Step-by-Step Instructions

### 1. Clone the Repository

```bash
cd ~
git clone https://github.com/matthiasn/lotti.git
cd lotti
```

### 2. Install Flutter Dependencies

```bash
# Update system packages
sudo apt update

# Install Flutter dependencies
sudo apt install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    libsecret-1-dev \
    libjsoncpp-dev \
    libsecret-1-0 \
    sqlite3 \
    libsqlite3-dev \
    pulseaudio-utils \
    build-essential \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev
```

### 3. Install Flutter (if not already installed)

```bash
# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "Installing Flutter..."
    cd ~
    wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.16.5-stable.tar.xz
    tar xf flutter_linux_3.16.5-stable.tar.xz
    echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
    export PATH="$PATH:$HOME/flutter/bin"
    cd ~/lotti
fi
```

### 4. Run the Working Flatpak Build Script

```bash
# Make sure you're in the lotti directory
cd ~/lotti

# Run the working build script
./flatpak/build-working.sh
```

### 5. Install and Run the Flatpak

After the build completes successfully, install the Flatpak:

```bash
# Add the local repository
flatpak remote-add --user --if-not-exists lotti-repo flatpak/repo --no-gpg-verify

# Install the app
flatpak install --user -y lotti-repo com.matthiasnehlsen.lotti

# Run the app
flatpak run com.matthiasnehlsen.lotti
```

## Alternative: Direct Flutter Build (if Flatpak fails)

If the Flatpak build fails, you can run the app directly:

```bash
# Get dependencies
flutter pub get

# Generate code
make build_runner

# Build for Linux
flutter build linux --release

# Run the app
./build/linux/x64/release/bundle/lotti
```

## Troubleshooting

### Common Issues and Solutions

1. **"Invalid buildsystem: flutter" error**
   - Solution: Use the working script which uses `simple` buildsystem instead

2. **CMake/ninja build failures**
   - Solution: Install required dependencies listed in step 2
   - Make sure you have enough disk space (at least 10GB free)

3. **Flutter not found**
   - Solution: Install Flutter as shown in step 3
   - Restart your terminal or run `source ~/.bashrc`

4. **Permission denied errors**
   - Solution: Make sure the build script is executable: `chmod +x flatpak/build-working.sh`

5. **Flatpak build fails with dependency errors**
   - Solution: Make sure GNOME SDK is installed: `flatpak install -y flathub org.gnome.Sdk//45 org.gnome.Platform//45`

### Verification Steps

To verify everything is working:

1. **Check Flutter installation:**
   ```bash
   flutter --version
   ```

2. **Check Flatpak installation:**
   ```bash
   flatpak --version
   ```

3. **Check GNOME SDK:**
   ```bash
   flatpak list | grep gnome
   ```

4. **Test the app:**
   ```bash
   flatpak run com.matthiasnehlsen.lotti
   ```

## What the Working Script Does

The `build-working.sh` script:

1. **Builds the Flutter app first** using standard Flutter commands
2. **Creates a simple Flatpak manifest** that uses the `simple` buildsystem (not `flutter`)
3. **Packages the built executable** as a Flatpak
4. **Handles all dependencies** automatically
5. **Provides clear installation instructions**

## Key Differences from Original Approach

- Uses `simple` buildsystem instead of `flutter` (which doesn't exist in Flatpak)
- Builds Flutter app separately, then packages it
- No complex variable substitution or git dependencies
- Direct file-based approach that works reliably

## Success Indicators

You'll know it's working when:
- The script completes without errors
- You see "=== Flatpak Build Completed Successfully! ==="
- The app launches with `flatpak run com.matthiasnehlsen.lotti`
- The Lotti journal interface appears

This approach bypasses the "Invalid buildsystem: flutter" error by using the standard `simple` buildsystem and pre-building the Flutter app. 