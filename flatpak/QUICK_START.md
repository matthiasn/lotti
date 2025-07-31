# Quick Start: Lotti in Kubuntu VM with Flatpak

## The Simplest Approach

### Option 1: Automated Installation (Recommended)
```bash
# Download and run the automated installer
curl -O https://raw.githubusercontent.com/matthiasn/lotti/main/flatpak/install_lotti_kubuntu.sh
chmod +x install_lotti_kubuntu.sh
./install_lotti_kubuntu.sh
```

### Option 2: Manual Installation
```bash
# 1. Install dependencies
sudo apt update
sudo apt install flatpak flatpak-builder git -y
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install org.gnome.Platform//45 org.gnome.Sdk//45

# 2. Clone and build
git clone https://github.com/matthiasn/lotti.git
cd lotti
chmod +x flatpak/build.sh
./flatpak/build.sh

# 3. Install and run
flatpak remote-add --user --if-not-exists lotti-repo repo --no-gpg-verify
flatpak install --user -y lotti-repo com.matthiasnehlsen.lotti
flatpak run com.matthiasnehlsen.lotti
```

## VM Requirements
- **OS**: Kubuntu 22.04+ 
- **RAM**: 4GB minimum (8GB recommended)
- **Storage**: 20GB free space
- **Graphics**: Enable 3D acceleration

## What This Gives You
✅ **Working Lotti app** in your Kubuntu VM  
✅ **Secure sandboxed** installation via Flatpak  
✅ **All features** including audio recording, image import, sync  
✅ **Desktop integration** with app menu and shortcuts  
✅ **Easy updates** and maintenance  

## Troubleshooting
- **Build fails**: Increase VM RAM to 8GB
- **Graphics issues**: Enable 3D acceleration in VM settings
- **Audio problems**: Install guest additions/tools
- **Slow performance**: Allocate more CPU cores to VM

## Next Steps
1. Run the installer script
2. Wait for build to complete (10-30 minutes)
3. Launch Lotti from desktop or menu
4. Start journaling!

For detailed instructions, see `KUBUNTU_VM_GUIDE.md` 