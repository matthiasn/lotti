#!/bin/bash

# Lotti Flatpak Build and Run Script
# This script automates the entire process of building and running Lotti as a Flatpak

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Determine script directory and repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Function to clean up stuck mounts
cleanup_mounts() {
    print_warning "Cleaning up any stuck mounts..."
    # Try to unmount any stuck rofiles
    if [ -d "$SCRIPT_DIR/.flatpak-builder/rofiles" ]; then
        for mount in "$SCRIPT_DIR"/.flatpak-builder/rofiles/rofiles-*; do
            if [ -d "$mount" ]; then
                fusermount3 -u "$mount" 2>/dev/null || true
            fi
        done
    fi
    # Remove rofiles directory if it exists
    rm -rf "$SCRIPT_DIR/.flatpak-builder/rofiles" 2>/dev/null || true
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check for Flutter
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter is not installed. Please install Flutter first."
        exit 1
    fi
    
    # Check for flatpak-builder
    if ! command -v flatpak-builder &> /dev/null; then
        print_error "flatpak-builder is not installed. Installing..."
        sudo apt install -y flatpak-builder
    fi
    
    # Check for required Flatpak runtime
    if ! flatpak list | grep -q "org.freedesktop.Platform.*24.08"; then
        print_warning "Required runtime not found. Installing..."
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        flatpak install -y flathub org.freedesktop.Sdk//24.08 org.freedesktop.Platform//24.08
    fi
    
    print_status "Prerequisites check complete!"
}

# Function to clean build artifacts
clean_build() {
    print_status "Cleaning previous build artifacts..."
    
    # Work from script directory
    pushd "$SCRIPT_DIR" > /dev/null
    
    # Clean up any stuck mounts first
    cleanup_mounts
    
    # Remove build directories
    rm -rf flutter-bundle
    rm -rf build-dir
    rm -rf repo
    rm -rf .flatpak-builder
    
    popd > /dev/null
    
    print_status "Clean complete!"
}

# Function to build Flutter app
build_flutter() {
    print_status "Building Flutter Linux release..."
    
    # Navigate to project root
    pushd "$REPO_ROOT" > /dev/null
    
    # Build Flutter app
    if ! flutter build linux --release; then
        # Return to original directory on failure
        popd > /dev/null
        print_error "Flutter build failed!"
        exit 1
    fi
    
    # Return to original directory
    popd > /dev/null
    
    print_status "Flutter build complete!"
}

# Function to prepare Flutter bundle
prepare_bundle() {
    print_status "Preparing Flutter bundle..."
    
    # Create flutter-bundle directory
    mkdir -p "$SCRIPT_DIR/flutter-bundle"
    
    # Copy Flutter build output
    cp -r "$REPO_ROOT/build/linux/x64/release/bundle/." "$SCRIPT_DIR/flutter-bundle/"
    
    # Remove 1024x1024 icons from hicolor directory (Flatpak limit is 512x512)
    # Only target the specific hicolor/1024x1024 path to avoid accidentally removing other assets
    if [ -d "$SCRIPT_DIR/flutter-bundle/data/icons/hicolor/1024x1024" ]; then
        rm -rf "$SCRIPT_DIR/flutter-bundle/data/icons/hicolor/1024x1024"
    fi
    
    # Ensure MaterialIcons font is present
    if [ ! -f "$SCRIPT_DIR/flutter-bundle/data/flutter_assets/fonts/MaterialIcons-Regular.otf" ]; then
        print_warning "MaterialIcons font not found in bundle, app might have display issues"
    fi
    
    print_status "Bundle preparation complete!"
}

# Function to build Flatpak
build_flatpak() {
    print_status "Building Flatpak package..."
    
    # Work from script directory
    pushd "$SCRIPT_DIR" > /dev/null
    
    # Clean up any stuck mounts before building
    cleanup_mounts
    
    # Build using local manifest
    if ! flatpak-builder --repo=repo --force-clean build-dir com.matthiasnehlsen.lotti.local.yml; then
        print_error "Flatpak build failed!"
        # Try to clean up and retry once
        print_warning "Attempting to clean up and retry..."
        cleanup_mounts
        sleep 2
        if ! flatpak-builder --repo=repo --force-clean build-dir com.matthiasnehlsen.lotti.local.yml; then
            print_error "Flatpak build failed after retry!"
            popd > /dev/null
            exit 1
        fi
    fi
    
    popd > /dev/null
    
    print_status "Flatpak build complete!"
}

# Function to run the app
run_app() {
    print_status "Running Lotti app..."
    
    # Work from script directory
    pushd "$SCRIPT_DIR" > /dev/null
    
    # Check if there are stuck mounts
    # Iterate over rofiles directories since mountpoint doesn't expand globs
    local has_mounts=false
    for rofile_path in .flatpak-builder/rofiles/rofiles-*; do
        # Check if the glob actually matched something (not the literal pattern)
        if [ -e "$rofile_path" ]; then
            if mountpoint -q "$rofile_path" 2>/dev/null; then
                has_mounts=true
                break
            fi
        fi
    done
    
    if [ "$has_mounts" = true ]; then
        print_warning "Detected stuck mounts, cleaning up..."
        cleanup_mounts
        sleep 1
    fi
    
    # Run the app from build directory
    if ! flatpak-builder --run build-dir com.matthiasnehlsen.lotti.local.yml /app/lotti; then
        print_warning "App failed to start. Trying cleanup and retry..."
        cleanup_mounts
        sleep 2
        flatpak-builder --run build-dir com.matthiasnehlsen.lotti.local.yml /app/lotti
    fi
    
    popd > /dev/null
}

# Function to install to system (optional)
install_flatpak() {
    print_status "Installing Flatpak to system..."
    
    # Work from script directory
    pushd "$SCRIPT_DIR" > /dev/null
    
    # Install from repo
    flatpak --user remote-add --no-gpg-verify lotti-repo repo
    flatpak --user install -y lotti-repo com.matthiasnehlsen.lotti
    
    popd > /dev/null
    
    print_status "Installation complete! You can now run: flatpak run com.matthiasnehlsen.lotti"
}

# Main script
main() {
    echo "=========================================="
    echo "   Lotti Flatpak Build and Run Script    "
    echo "=========================================="
    echo ""
    
    # Parse command line arguments
    case "${1:-build-run}" in
        clean)
            clean_build
            ;;
        build)
            check_prerequisites
            clean_build
            build_flutter
            prepare_bundle
            build_flatpak
            print_status "Build complete! Run './build_and_run.sh run' to test the app"
            ;;
        run)
            run_app
            ;;
        build-run)
            check_prerequisites
            clean_build
            build_flutter
            prepare_bundle
            build_flatpak
            run_app
            ;;
        install)
            install_flatpak
            ;;
        help)
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  build-run  - Build and run the app (default)"
            echo "  build      - Build only, don't run"
            echo "  run        - Run the already built app"
            echo "  clean      - Clean all build artifacts"
            echo "  install    - Install the Flatpak to system"
            echo "  help       - Show this help message"
            ;;
        *)
            print_error "Unknown command: $1"
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
    
    echo ""
    print_status "All done!"
}

# Run main function with all arguments
main "$@"