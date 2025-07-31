#!/bin/bash

# Lotti Flatpak Installation Script for Kubuntu VM
# This script automates the installation of Lotti in a Kubuntu VM using Flatpak

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root"
        exit 1
    fi
}

# Check system requirements
check_requirements() {
    log_info "Checking system requirements..."
    
    # Check if running on Ubuntu/Debian
    if ! command -v apt &> /dev/null; then
        log_error "This script is designed for Ubuntu/Debian-based systems"
        exit 1
    fi
    
    # Check available memory
    local mem_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$mem_gb" -lt 4 ]; then
        log_warning "Less than 4GB RAM detected. Build may fail or be very slow."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check available disk space
    local disk_gb=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$disk_gb" -lt 20 ]; then
        log_warning "Less than 20GB free space detected. Build may fail."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log_success "System requirements check passed"
}

# Install system dependencies
install_dependencies() {
    log_info "Installing system dependencies..."
    
    sudo apt update
    
    # Install essential packages
    sudo apt install -y \
        flatpak \
        flatpak-builder \
        git \
        curl \
        wget \
        build-essential \
        mesa-utils \
        pulseaudio \
        pulseaudio-utils
    
    log_success "System dependencies installed"
}

# Setup Flatpak
setup_flatpak() {
    log_info "Setting up Flatpak..."
    
    # Add Flathub repository
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    
    # Install GNOME Platform runtime
    flatpak install -y org.gnome.Platform//45 org.gnome.Sdk//45
    
    log_success "Flatpak setup completed"
}

# Clone repository
clone_repository() {
    log_info "Cloning Lotti repository..."
    
    if [ -d "lotti" ]; then
        log_warning "Lotti directory already exists. Updating..."
        cd lotti
        git pull origin main
    else
        git clone https://github.com/matthiasn/lotti.git
        cd lotti
    fi
    
    log_success "Repository cloned/updated"
}

# Build Flatpak
build_flatpak() {
    log_info "Building Lotti Flatpak (this may take 10-30 minutes)..."
    
    # Make build script executable
    chmod +x flatpak/build.sh
    
    # Build the Flatpak
    if ./flatpak/build.sh; then
        log_success "Flatpak build completed successfully"
    else
        log_error "Flatpak build failed"
        exit 1
    fi
}

# Install Lotti
install_lotti() {
    log_info "Installing Lotti..."
    
    # Add local repository
    flatpak remote-add --user --if-not-exists lotti-repo repo --no-gpg-verify
    
    # Install Lotti
    flatpak install --user -y lotti-repo com.matthiasnehlsen.lotti
    
    log_success "Lotti installed successfully"
}

# Test installation
test_installation() {
    log_info "Testing Lotti installation..."
    
    # Check if app is installed
    if flatpak list | grep -q "com.matthiasnehlsen.lotti"; then
        log_success "Lotti is properly installed"
        
        # Test launch (non-blocking)
        log_info "Testing app launch..."
        timeout 10s flatpak run com.matthiasnehlsen.lotti || true
        
        log_success "Installation test completed"
    else
        log_error "Lotti installation verification failed"
        exit 1
    fi
}

# Create desktop shortcut
create_shortcut() {
    log_info "Creating desktop shortcut..."
    
    # Create desktop entry
    cat > ~/Desktop/Lotti.desktop << EOF
[Desktop Entry]
Name=Lotti
Comment=A smart journal and life management app
Exec=flatpak run com.matthiasnehlsen.lotti
Icon=com.matthiasnehlsen.lotti
Terminal=false
Type=Application
Categories=Productivity;Office;
StartupWMClass=lotti
EOF
    
    # Make executable
    chmod +x ~/Desktop/Lotti.desktop
    
    log_success "Desktop shortcut created"
}

# Show usage instructions
show_instructions() {
    log_success "Installation completed successfully!"
    echo
    echo "You can now run Lotti using one of these methods:"
    echo "1. Command line: flatpak run com.matthiasnehlsen.lotti"
    echo "2. Desktop shortcut: Double-click the Lotti icon on your desktop"
    echo "3. Application menu: Look for Lotti in the Productivity or Office category"
    echo
    echo "To update Lotti in the future:"
    echo "1. cd lotti"
    echo "2. git pull"
    echo "3. ./flatpak/build.sh"
    echo "4. flatpak install --user -y lotti-repo com.matthiasnehlsen.lotti"
    echo
    echo "To uninstall: flatpak uninstall com.matthiasnehlsen.lotti"
}

# Main installation process
main() {
    echo "=========================================="
    echo "Lotti Flatpak Installation for Kubuntu VM"
    echo "=========================================="
    echo
    
    check_root
    check_requirements
    install_dependencies
    setup_flatpak
    clone_repository
    build_flatpak
    install_lotti
    test_installation
    create_shortcut
    show_instructions
}

# Run main function
main "$@" 