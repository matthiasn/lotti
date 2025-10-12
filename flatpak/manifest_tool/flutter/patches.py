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


def _find_package_in_pubspec(package_base: str, entries: Iterable[Any]) -> Optional[str]:
    """Return ``package-version`` dest for ``package_base`` from pubspec entries.

    The pubspec-sources.json emitted by flatpak-flutter lists entries as
    type: "archive" with a dest like ".pub-cache/hosted/pub.dev/<package>-<version>".
    We consider any mapping with a matching dest regardless of the "type".
    """

    for item in entries:
        if not isinstance(item, dict):
            continue
        dest = str(item.get("dest", ""))
        if "/pub.dev/" not in dest:
            continue
        # Match exact base name followed by a dash and version
        needle = f"/{package_base}-"
        if needle in dest:
            candidate = dest.split("/")[-1]
            if candidate.startswith(f"{package_base}-"):
                return candidate
    return None


def _match_packages_with_versions(package_bases: Iterable[str], pubspec_entries: Iterable[Any]) -> List[str]:
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
        if isinstance(source, dict) and source.get("type") == "patch" and source.get("dest") == dest_path:
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

    cargo_index: Optional[int] = None
    pubspec_index: Optional[int] = None

    for idx, source in enumerate(sources):
        if isinstance(source, dict) and source.get("path") == "cargo-sources.json":
            cargo_index = idx
        elif isinstance(source, str) and "cargo-sources.json" in source:
            cargo_index = idx
        if isinstance(source, dict) and source.get("path") == "pubspec-sources.json":
            pubspec_index = idx
        elif isinstance(source, str) and "pubspec-sources.json" in source:
            pubspec_index = idx

    insert_index = len(sources) if cargo_index is None else cargo_index
    if pubspec_index is not None:
        insert_index = max(insert_index, pubspec_index + 1)
    return insert_index


def _find_cargokit_packages(document: ManifestDocument) -> list[str]:
    """Detect versioned cargokit packages to patch.

    Preferred detection reads pubspec-sources.json and extracts the exact
    `<package>-<version>` directory names under `.pub-cache/hosted/pub.dev/` for
    known cargokit users. Falls back to scanning manifest sources and then to a
    static list if nothing is found.
    """

    # 1) Prefer pubspec-sources.json (most reliable and version-accurate)
    entries = _load_pubspec_sources(document)
    if entries:
        # Patch known cargokit-based plugins that ship run_build_tool.sh
        bases = [
            "super_native_extensions",
            "flutter_vodozemac",
            "irondash_engine_context",
        ]
        detected = _match_packages_with_versions(bases, entries)
        if detected:
            return detected

    # 2) Fallback: infer from -Cargo.lock file sources (older flow)
    modules = document.ensure_modules()
    lotti_module = _get_lotti_module(modules)
    if lotti_module:
        bases = _collect_cargokit_basenames(lotti_module)
        # Filter to the known cargokit plugins
        bases = [
            b
            for b in bases
            if b in ("super_native_extensions", "flutter_vodozemac", "irondash_engine_context")
        ]
        if bases and entries:
            versioned = _match_packages_with_versions(bases, entries)
            if versioned:
                return versioned
        if bases:
            return bases

    # 3) Last resort: static list (may not match current versions)
    return [
        p
        for p in _FALLBACK_CARGOKIT_PACKAGES
        if p.split("-")[0] in ("super_native_extensions", "flutter_vodozemac", "irondash_engine_context")
    ]


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
