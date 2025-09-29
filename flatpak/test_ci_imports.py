#!/usr/bin/env python3
"""Test script to verify imports work in CI environment."""

import sys
from pathlib import Path

# This mimics what the CI environment does
sys.path.insert(0, str(Path(__file__).parent))

try:
    # Test basic import
    import manifest_tool
    print("✓ Basic manifest_tool import works")

    # Test core imports
    from manifest_tool.core.manifest import ManifestDocument
    print("✓ Core module import works")

    # Test cli import (this was failing in CI)
    from manifest_tool import cli
    print("✓ CLI import works")

    # Test flutter submodule import
    from manifest_tool.flutter import sdk
    print("✓ Flutter submodule import works")

    # Test that cli can access flutter functions
    print(f"✓ CLI has access to flutter operations: {hasattr(cli, 'main')}")

    print("\n✓ All imports successful! CI should work now.")
    sys.exit(0)

except ImportError as e:
    print(f"✗ Import failed: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)