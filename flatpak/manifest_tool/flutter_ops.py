"""Flutter operations module - backward compatibility wrapper.

This module imports all functions from the new modular flutter package structure
to maintain backward compatibility with existing code.
"""

# Re-export everything from the new modular structure
from .flutter import (
    # From build.py
    add_offline_build_patches,
    ensure_lotti_build_patches,
    is_build_offline,
    # From helpers.py
    ensure_setup_helper_command,
    normalize_lotti_env,
    _ensure_setup_helper_env,
    _ensure_setup_helper_sources,
    # From patches.py
    add_cargokit_offline_patches,
    add_cmake_offline_patches,
    # From plugins.py
    add_offline_sources,
    bundle_app_archive,
    discover_cargokit_packages,
    # From rust.py
    ensure_rust_sdk_env,
    remove_rustup_install,
    # From sdk.py
    ensure_nested_sdk,
    should_remove_flutter_sdk,
    normalize_flutter_sdk_module,
    normalize_sdk_copy,
    convert_flutter_git_to_archive,
    rewrite_flutter_git_url,
)

__all__ = [
    # From build.py
    "add_offline_build_patches",
    "ensure_lotti_build_patches",
    "is_build_offline",
    # From helpers.py
    "ensure_setup_helper_command",
    "normalize_lotti_env",
    # From patches.py
    "add_cargokit_offline_patches",
    "add_cmake_offline_patches",
    # From plugins.py
    "add_offline_sources",
    "bundle_app_archive",
    "discover_cargokit_packages",
    # From rust.py
    "ensure_rust_sdk_env",
    "remove_rustup_install",
    # From sdk.py
    "ensure_nested_sdk",
    "should_remove_flutter_sdk",
    "normalize_flutter_sdk_module",
    "normalize_sdk_copy",
    "convert_flutter_git_to_archive",
    "rewrite_flutter_git_url",
]
