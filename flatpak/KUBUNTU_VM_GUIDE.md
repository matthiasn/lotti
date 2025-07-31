# Running Lotti in Kubuntu VM with Flatpak

This guide provides step-by-step instructions to run the Lotti Flutter app in a Kubuntu VM using Flatpak.

## Prerequisites

### 1. Kubuntu VM Setup
- **OS**: Kubuntu 22.04 LTS or newer
- **RAM**: Minimum 4GB (8GB recommended)
- **Storage**: At least 20GB free space
- **Graphics**: Enable 3D acceleration in VM settings

### 2. VM Guest Additions
Install VirtualBox Guest Additions or VMware Tools for better performance:
```bash
# For VirtualBox
sudo apt update
sudo apt install virtualbox-guest-utils virtualbox-guest-dkms

# For VMware
sudo apt update
sudo apt install open-vm-tools open-vm-tools-desktop
```

## Step-by-Step Installation

### Step 1: Update System
```bash
sudo apt update && sudo apt upgrade -y
```

### Step 2: Install Flatpak
```bash
# Install Flatpak
sudo apt install flatpak -y

# Add Flathub repository
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Restart system or log out/in to ensure Flatpak is properly initialized
```

### Step 3: Install Required Dependencies
```bash
# Install build tools
sudo apt install git curl wget build-essential -y

# Install Flatpak builder
sudo apt install flatpak-builder -y

# Install GNOME Platform runtime (required for Flutter apps)
flatpak install org.gnome.Platform//45 org.gnome.Sdk//45
```

### Step 4: Clone and Build Lotti
```bash
# Clone the repository
git clone https://github.com/matthiasn/lotti.git
cd lotti

# Make build script executable
chmod +x flatpak/build.sh

# Build the Flatpak (this will take 10-30 minutes depending on VM performance)
./flatpak/build.sh
```

### Step 5: Install Lotti
After successful build, install the app:
```bash
# Add local repository
flatpak remote-add --user --if-not-exists lotti-repo repo --no-gpg-verify

# Install Lotti
flatpak install --user -y lotti-repo com.matthiasnehlsen.lotti
```

### Step 6: Run Lotti
```bash
# Launch Lotti
flatpak run com.matthiasnehlsen.lotti
```

Or find it in your application menu under "Productivity" or "Office" category.

## Troubleshooting

### Common Issues and Solutions

#### 1. Build Fails with Memory Issues
If the build fails due to insufficient memory:
```bash
# Increase swap space
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

#### 2. Graphics Issues
If you experience graphics glitches:
```bash
# Install additional graphics drivers
sudo apt install mesa-utils -y

# For VirtualBox, enable 3D acceleration in VM settings
# For VMware, install VMware Tools properly
```

#### 3. Audio Issues
If audio doesn't work:
```bash
# Install PulseAudio (usually already installed)
sudo apt install pulseaudio pulseaudio-utils -y

# Restart audio service
pulseaudio --kill
pulseaudio --start
```

#### 4. Permission Issues
If you get permission errors:
```bash
# Check Flatpak permissions
flatpak info com.matthiasnehlsen.lotti

# Grant additional permissions if needed
flatpak override --user com.matthiasnehlsen.lotti --filesystem=home
```

#### 5. Network Issues in VM
If network connectivity is poor:
```bash
# Check network configuration
ip addr show

# Restart network service
sudo systemctl restart NetworkManager
```

### Performance Optimization

#### 1. VM Settings
- **CPU**: Allocate at least 2 cores
- **RAM**: Minimum 4GB, 8GB recommended
- **Graphics**: Enable 3D acceleration
- **Storage**: Use SSD if possible

#### 2. Flatpak Performance
```bash
# Clean up old builds
flatpak-builder --force-clean build-dir flatpak/com.matthiasnehlsen.lotti.yml

# Update runtimes
flatpak update
```

#### 3. System Optimization
```bash
# Disable unnecessary services
sudo systemctl disable bluetooth.service
sudo systemctl disable cups.service

# Optimize swap usage
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
```

## Alternative Installation Methods

### Method 1: Direct Bundle Installation
If you have a `.flatpak` bundle:
```bash
flatpak install lotti.flatpak
```

### Method 2: Development Build
For testing changes:
```bash
# Run directly from build directory
flatpak-builder --run build-dir flatpak/com.matthiasnehlsen.lotti.yml lotti
```

### Method 3: Flathub Installation (Future)
Once available on Flathub:
```bash
flatpak install flathub com.matthiasnehlsen.lotti
```

## Verification

### Check Installation
```bash
# Verify Flatpak installation
flatpak list | grep lotti

# Check app info
flatpak info com.matthiasnehlsen.lotti

# Test launch
flatpak run com.matthiasnehlsen.lotti
```

### Test Features
1. **Journal Creation**: Create a new journal entry
2. **Audio Recording**: Test voice note functionality
3. **Image Import**: Import an image from Pictures folder
4. **Data Export**: Export data to Documents folder
5. **Sync**: Test synchronization features

## Security Considerations

The Flatpak version of Lotti follows the principle of least privilege:
- ✅ Only necessary filesystem access
- ✅ Secure sandboxing
- ✅ No broad home directory access
- ✅ Read-only access where possible

## Support

If you encounter issues:
1. Check the [main Lotti repository](https://github.com/matthiasn/lotti)
2. Review [Flatpak documentation](https://docs.flatpak.org/)
3. Check VM-specific issues in your hypervisor documentation

## Quick Reference Commands

```bash
# Build and install
./flatpak/build.sh
flatpak install --user -y lotti-repo com.matthiasnehlsen.lotti

# Run
flatpak run com.matthiasnehlsen.lotti

# Update
flatpak update com.matthiasnehlsen.lotti

# Remove
flatpak uninstall com.matthiasnehlsen.lotti
``` 