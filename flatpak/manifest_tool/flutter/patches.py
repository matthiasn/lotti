"""Offline build patches for Flutter applications."""

from __future__ import annotations

from pathlib import Path

try:  # pragma: no cover
    from ..core import ManifestDocument, OperationResult, get_logger
except ImportError:  # pragma: no cover
    import sys

    sys.path.insert(0, str(Path(__file__).parent.parent))
    from core import ManifestDocument, OperationResult, get_logger  # type: ignore

_LOGGER = get_logger("flutter.patches")


def add_cmake_offline_patches(document: ManifestDocument) -> OperationResult:
    """Add patches for CMake-based plugins to work offline.

    Note: SQLite patches are handled by flatpak-flutter which generates
    sqlite3_flutter_libs/0.5.34-CMakeLists.txt.patch automatically.

    Args:
        document: The manifest document to modify

    Returns:
        OperationResult with details of changes made
    """
    # SQLite patches are handled by flatpak-flutter's generated patches
    # No additional patches needed here
    return OperationResult.unchanged()


def _find_cargokit_packages(document: ManifestDocument) -> list[str]:
    """Find all packages that use cargokit by looking for Cargo.lock files.

    Returns:
        List of package names with versions that have cargokit
    """
    import json
    from pathlib import Path

    cargokit_packages = []
    modules = document.ensure_modules()

    # First, try to detect from Cargo.lock files in sources
    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue

        sources = module.get("sources", [])
        for source in sources:
            if isinstance(source, dict) and source.get("type") == "file":
                path = source.get("path", "")
                if "Cargo.lock" in path and "-Cargo.lock" in path:
                    # Extract package name from path like "flutter_vodozemac-Cargo.lock"
                    pkg_name = path.replace("-Cargo.lock", "")
                    cargokit_packages.append(pkg_name)
        break

    # If we found packages from Cargo.lock files, look up their versions from pubspec-sources.json
    if cargokit_packages:
        # Try to read pubspec-sources.json to get exact versions
        pubspec_sources = []
        for module in modules:
            if not isinstance(module, dict) or module.get("name") != "lotti":
                continue
            sources = module.get("sources", [])
            for source in sources:
                if source == "pubspec-sources.json" or (
                    isinstance(source, dict)
                    and source.get("path") == "pubspec-sources.json"
                ):
                    # Try to load the file if it exists
                    manifest_dir = (
                        Path(document.path).parent
                        if hasattr(document, "path")
                        else Path.cwd()
                    )
                    pubspec_path = manifest_dir / "pubspec-sources.json"
                    if pubspec_path.exists():
                        try:
                            with open(pubspec_path, "r") as f:
                                pubspec_data = json.load(f)
                                # Find packages with matching names
                                versioned_packages = []
                                for pkg_base in cargokit_packages:
                                    for item in pubspec_data:
                                        if (
                                            isinstance(item, dict)
                                            and item.get("type") == "file"
                                        ):
                                            dest = item.get("dest", "")
                                            if pkg_base in dest and "/pub.dev/" in dest:
                                                # Extract full package name with version
                                                parts = dest.split("/")
                                                if len(parts) > 0:
                                                    pkg_full = parts[-1]
                                                    if pkg_base in pkg_full:
                                                        versioned_packages.append(
                                                            pkg_full
                                                        )
                                                        break
                                if versioned_packages:
                                    return versioned_packages
                        except (IOError, json.JSONDecodeError):
                            pass
                    break

    # Fallback to known packages if detection fails
    if not cargokit_packages:
        _LOGGER.debug("Using fallback list of known cargokit packages")
        return [
            "super_native_extensions-0.9.1",
            "flutter_vodozemac-0.2.2",
            "irondash_engine_context-0.5.5",
        ]

    # Return packages without versions if we couldn't find versions
    return cargokit_packages


def add_cargokit_offline_patches(document: ManifestDocument) -> OperationResult:
    """Add patches for Rust-based plugins to build offline.

    Dynamically finds all cargokit-using packages and adds patches for them.
    Also adds cargo configuration for offline mode.

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

        # Find all cargokit packages
        cargokit_packages = _find_cargokit_packages(document)

        # Add patch for each cargokit package
        for package in cargokit_packages:
            patch_dest = f".pub-cache/hosted/pub.dev/{package}/cargokit"

            # Check if patch already exists
            has_patch = any(
                s.get("type") == "patch" and s.get("dest") == patch_dest
                for s in sources
                if isinstance(s, dict)
            )

            if not has_patch:
                patch_source = {
                    "type": "patch",
                    "path": "cargokit/run_build_tool.sh.patch",
                    "dest": patch_dest,
                }
                # Find position to insert patch (after other patches, before cargo-sources.json)
                insert_pos = len(sources)
                for i, s in enumerate(sources):
                    if isinstance(s, dict) and s.get("path") == "cargo-sources.json":
                        insert_pos = i
                        break
                    elif isinstance(s, str) and "cargo-sources.json" in s:
                        insert_pos = i
                        break

                sources.insert(insert_pos, patch_source)
                messages.append(f"Added cargokit patch for {package}")
                changed = True

        # Add cargo config as an inline source for offline mode
        cargo_config = {
            "type": "inline",
            "dest": ".cargo",
            "dest-filename": "config.toml",
            "contents": "[net]\noffline = true\n\n[http]\nmax-retries = 0\n",
        }

        # Check if cargo config already exists
        has_cargo_config = any(
            (s.get("dest") == ".cargo" and s.get("dest-filename") == "config.toml")
            or s.get("dest-filename") == ".cargo/config.toml"  # old format
            for s in sources
            if isinstance(s, dict)
        )

        if not has_cargo_config:
            sources.append(cargo_config)
            messages.append("Added cargo offline config")
            changed = True

        if changed:
            module["sources"] = sources

        break

    if changed:
        document.mark_changed()
        return OperationResult.changed_result("; ".join(messages))
    return OperationResult.unchanged()


def add_offline_build_patches(document: ManifestDocument) -> OperationResult:
    """Add comprehensive offline build patches to the lotti module.

    This adds configurations to ensure the build works offline:
    1. Cargo configuration for offline mode
    2. Relies on flatpak-flutter generated patches for SQLite and cargokit

    Args:
        document: The manifest document to modify

    Returns:
        OperationResult with combined results from all patch operations
    """
    results = []

    # Add CMake offline patches (handled by flatpak-flutter)
    cmake_result = add_cmake_offline_patches(document)
    if cmake_result.changed:
        results.append(cmake_result)

    # Add cargo/Rust offline configuration
    cargo_result = add_cargokit_offline_patches(document)
    if cargo_result.changed:
        results.append(cargo_result)

    if results:
        all_messages = []
        for r in results:
            all_messages.extend(r.messages)
        return OperationResult(changed=True, messages=all_messages)

    return OperationResult.unchanged()
