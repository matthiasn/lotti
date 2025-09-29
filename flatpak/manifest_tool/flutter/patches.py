"""Offline build patches for Flutter applications."""

from __future__ import annotations

from pathlib import Path
import json

try:  # pragma: no cover
    from ..core import ManifestDocument, OperationResult, get_logger
except ImportError:  # pragma: no cover
    import sys

    sys.path.insert(0, str(Path(__file__).parent.parent))
    from core import ManifestDocument, OperationResult, get_logger  # type: ignore

_LOGGER = get_logger("flutter.patches")


def add_cmake_offline_patches(document: ManifestDocument) -> OperationResult:
    """Add patches for CMake-based plugins to work offline.

    This adds patch sources to replace network fetches with local files
    for plugins like sqlite3_flutter_libs that use CMake FetchContent.

    Args:
        document: The manifest document to modify

    Returns:
        OperationResult with details of changes made
    """
    modules = document.ensure_modules()
    changed = False
    messages = []

    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue

        sources = module.get("sources", [])
        if not isinstance(sources, list):
            sources = []

        # Add patch to redirect SQLite download to local file
        sqlite_patch = {
            "type": "patch",
            "path": "patches/sqlite3-offline.patch",
            "strip": 1,
        }

        # Check if patch already exists (by path, not exact dict match)
        has_sqlite_patch = any(
            s.get("path") == "patches/sqlite3-offline.patch"
            for s in sources
            if isinstance(s, dict)
        )

        if not has_sqlite_patch:
            sources.append(sqlite_patch)
            module["sources"] = sources  # Ensure it's saved back
            messages.append("Added SQLite offline patch")
            changed = True

        break

    if changed:
        document.mark_changed()
        return OperationResult.changed_result("; ".join(messages))
    return OperationResult.unchanged()


def add_cargokit_offline_patches(document: ManifestDocument) -> OperationResult:
    """Add patches for Rust-based plugins to build offline.

    This configures cargo to work in offline mode for plugins that use
    the cargokit build system.

    Args:
        document: The manifest document to modify

    Returns:
        OperationResult with details of changes made
    """
    modules = document.ensure_modules()
    changed = False
    messages = []

    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue

        # Add cargo config as an inline source
        sources = module.get("sources", [])
        if not isinstance(sources, list):
            sources = []

        cargo_config = {
            "type": "inline",
            "dest-filename": ".cargo/config.toml",
            "contents": "[net]\noffline = true\n\n[http]\nmax-retries = 0\n",
        }

        # Check if cargo config already exists
        has_cargo_config = any(
            s.get("dest-filename") == ".cargo/config.toml"
            for s in sources
            if isinstance(s, dict)
        )

        if not has_cargo_config:
            sources.append(cargo_config)
            module["sources"] = sources  # Ensure it's saved back
            messages.append("Added cargo offline config")
            changed = True

        # Add patch for cargokit scripts
        cargokit_patch = {
            "type": "patch",
            "path": "patches/cargokit-offline.patch",
            "strip": 1,
        }

        # Check if patch already exists (by path, not exact dict match)
        has_cargokit_patch = any(
            s.get("path") == "patches/cargokit-offline.patch"
            for s in sources
            if isinstance(s, dict)
        )

        if not has_cargokit_patch:
            sources.append(cargokit_patch)
            module["sources"] = sources  # Ensure it's saved back
            messages.append("Added cargokit offline patch")
            changed = True

        break

    if changed:
        document.mark_changed()
        return OperationResult.changed_result("; ".join(messages))
    return OperationResult.unchanged()


def add_offline_build_patches(document: ManifestDocument) -> OperationResult:
    """Add comprehensive offline build patches to the lotti module.

    This adds patches and configurations to ensure the build works offline:
    1. Configures CMake-based plugins to use local sources
    2. Configures Rust/cargo to build in offline mode
    3. Adds necessary patch files to redirect network fetches

    Args:
        document: The manifest document to modify

    Returns:
        OperationResult with combined results from all patch operations
    """
    results = []

    # Add CMake offline patches (for sqlite3_flutter_libs, etc)
    cmake_result = add_cmake_offline_patches(document)
    if cmake_result.changed:
        results.append(cmake_result)

    # Add cargo/Rust offline patches (for cargokit-based plugins)
    cargo_result = add_cargokit_offline_patches(document)
    if cargo_result.changed:
        results.append(cargo_result)

    if results:
        all_messages = []
        for r in results:
            all_messages.extend(r.messages)
        return OperationResult(changed=True, messages=all_messages)

    return OperationResult.unchanged()
