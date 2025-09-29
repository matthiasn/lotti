"""Offline build patches for Flutter applications."""

from __future__ import annotations

import json

from pathlib import Path
from typing import Any, Iterable, List, Optional

try:  # pragma: no cover
    from ..core import ManifestDocument, OperationResult, get_logger
except ImportError:  # pragma: no cover
    import sys

    sys.path.insert(0, str(Path(__file__).parent.parent))
    from core import ManifestDocument, OperationResult, get_logger  # type: ignore

_LOGGER = get_logger("flutter.patches")

_FALLBACK_CARGOKIT_PACKAGES = [
    "super_native_extensions-0.9.1",
    "flutter_vodozemac-0.2.2",
    "irondash_engine_context-0.5.5",
]


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


def _get_lotti_module(modules: Iterable[Any]) -> Optional[dict]:
    """Return the lotti module if present in ``modules``."""

    for module in modules:
        if isinstance(module, dict) and module.get("name") == "lotti":
            return module
    return None


def _collect_cargokit_basenames(module: dict) -> List[str]:
    """Collect package basenames from Cargo.lock sources."""

    sources = module.get("sources", [])
    basenames: List[str] = []
    for source in sources:
        if not (isinstance(source, dict) and source.get("type") == "file"):
            continue
        path = source.get("path", "")
        if path.endswith("-Cargo.lock") and "Cargo.lock" in path:
            basename = path[: -len("-Cargo.lock")]
            if basename and basename not in basenames:
                basenames.append(basename)
    return basenames


def _load_pubspec_sources(document: ManifestDocument) -> Optional[List[Any]]:
    """Load pubspec-sources.json if it exists alongside the manifest."""

    manifest_path = getattr(document, "path", None)
    manifest_dir = Path(manifest_path).parent if manifest_path else Path.cwd()
    pubspec_path = manifest_dir / "pubspec-sources.json"
    if not pubspec_path.exists():
        return None

    try:
        with pubspec_path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:  # pragma: no cover - diagnostics
        _LOGGER.debug("Failed to read pubspec-sources.json: %s", exc)
        return None


def _find_package_in_pubspec(
    package_base: str, entries: Iterable[Any]
) -> Optional[str]:
    """Return ``package-version`` entry for ``package_base`` if available."""

    for item in entries:
        if not (isinstance(item, dict) and item.get("type") == "file"):
            continue
        dest = item.get("dest", "")
        if "/pub.dev/" not in dest:
            continue
        if package_base in dest:
            candidate = dest.split("/")[-1]
            if package_base in candidate:
                return candidate
    return None


def _match_packages_with_versions(
    package_bases: Iterable[str], pubspec_entries: Iterable[Any]
) -> List[str]:
    """Return versioned package names when pubspec data provides them."""

    matched: List[str] = []
    for base in package_bases:
        candidate = _find_package_in_pubspec(base, pubspec_entries)
        if candidate and candidate not in matched:
            matched.append(candidate)
    return matched


def _has_cargokit_patch(sources: Iterable[Any], package: str) -> bool:
    """Return True if the sources already include the cargokit patch."""

    dest_path = f".pub-cache/hosted/pub.dev/{package}/cargokit"
    for source in sources:
        if (
            isinstance(source, dict)
            and source.get("type") == "patch"
            and source.get("dest") == dest_path
        ):
            return True
    return False


def _cargokit_patch_entry(package: str) -> dict:
    """Build the patch definition for the given package."""

    return {
        "type": "patch",
        "path": "cargokit/run_build_tool.sh.patch",
        "dest": f".pub-cache/hosted/pub.dev/{package}/cargokit",
    }


def _patch_insert_position(sources: List[Any]) -> int:
    """Return index before which cargokit patches should be inserted."""

    for idx, source in enumerate(sources):
        if isinstance(source, dict) and source.get("path") == "cargo-sources.json":
            return idx
        if isinstance(source, str) and "cargo-sources.json" in source:
            return idx
    return len(sources)


def _find_cargokit_packages(document: ManifestDocument) -> list[str]:
    """Find packages that use cargokit by inspecting manifest sources."""

    modules = document.ensure_modules()
    lotti_module = _get_lotti_module(modules)
    if not lotti_module:
        _LOGGER.debug("Using fallback list of known cargokit packages")
        return list(_FALLBACK_CARGOKIT_PACKAGES)

    package_bases = _collect_cargokit_basenames(lotti_module)
    if not package_bases:
        _LOGGER.debug("No Cargo.lock sources detected; using fallback list")
        return list(_FALLBACK_CARGOKIT_PACKAGES)

    pubspec_entries = _load_pubspec_sources(document)
    if pubspec_entries:
        versioned = _match_packages_with_versions(package_bases, pubspec_entries)
        if versioned:
            return versioned

    return package_bases


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
    lotti_module = _get_lotti_module(modules)
    if not lotti_module:
        return OperationResult.unchanged()

    sources = lotti_module.get("sources", [])
    if not isinstance(sources, list):
        sources = []

    cargokit_packages = _find_cargokit_packages(document)
    messages: List[str] = []
    changed = False

    for package in cargokit_packages:
        if _has_cargokit_patch(sources, package):
            continue

        insert_pos = _patch_insert_position(sources)
        sources.insert(insert_pos, _cargokit_patch_entry(package))
        messages.append(f"Added cargokit patch for {package}")
        changed = True

    if changed:
        lotti_module["sources"] = sources
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
