#!/bin/bash

# Test script for building Lotti on Kubuntu
echo "=== Lotti Kubuntu Build Test ==="

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "Error: pubspec.yaml not found. Please run this script from the lotti project root."
    exit 1
fi

# Check if Flutter is available
if ! command -v flutter &> /dev/null; then
    echo "Error: Flutter not found in PATH"
    exit 1
fi

# Check if Rust is available
if ! command -v rustc &> /dev/null; then
    echo "Error: Rust not found in PATH. Please install Rust first:"
    echo "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    exit 1
fi

echo "✓ Flutter and Rust are available"

# Clean previous builds
echo "Cleaning previous builds..."
flutter clean

# Get dependencies
echo "Getting dependencies..."
flutter pub get

# Try to build for Linux
echo "Building for Linux..."
flutter run -d linux --verbose

echo "=== Build test completed ===" 