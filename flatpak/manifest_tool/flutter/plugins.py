"""Flutter plugin dependency management."""

from __future__ import annotations

from pathlib import Path

try:  # pragma: no cover
    from ..core import ManifestDocument, OperationResult, get_logger
except ImportError:  # pragma: no cover
    import sys

    sys.path.insert(0, str(Path(__file__).parent.parent))
    from core import ManifestDocument, OperationResult, get_logger  # type: ignore

_LOGGER = get_logger("flutter.plugins")


def _sqlite_matches_version(source: dict, version: str) -> bool:
    """Check if a source matches a specific SQLite version.

    Args:
        source: Source dictionary to check
        version: SQLite version string (e.g., "3500100")

    Returns:
        True if source references the given SQLite version
    """
    if not isinstance(source, dict):
        return False
    version_tag = f"sqlite-autoconf-{version}"
    # Check various fields that might contain the version string
    for key in ("url", "path", "dest-filename"):
        value = source.get(key)
        if isinstance(value, str) and version_tag in value:
            return True
    return False


def _remove_stale_sqlite_sources(
    sources: list, dest_map: dict, old_version: str
) -> tuple[list, bool]:
    """Remove outdated SQLite sources from the sources list.

    Returns:
        Tuple of (filtered_sources, removed_any)
    """
    filtered_sources = []
    removed_stale = False

    for source in sources:
        if (
            isinstance(source, dict)
            and source.get("type") == "file"
            and source.get("dest") in dest_map.values()
            and _sqlite_matches_version(source, old_version)
        ):
            removed_stale = True
            continue
        filtered_sources.append(source)

    return filtered_sources, removed_stale


def _add_sqlite_sources_for_architectures(
    sources: list, dest_map: dict, current_version: str
) -> tuple[bool, list]:
    """Add SQLite sources for each architecture if not already present.

    Returns:
        Tuple of (changed, messages)
    """
    changed = False
    messages = []

    for arch, dest in dest_map.items():
        if _has_sqlite_source(sources, dest, current_version):
            continue

        sqlite_source = _create_sqlite_source(arch, dest, current_version)
        sources.append(sqlite_source)
        messages.append(f"Added SQLite 3.50.4 file for {arch}")
        changed = True

    return changed, messages


def _has_sqlite_source(sources: list, dest: str, version: str) -> bool:
    """Check if sources already contains a SQLite source for the given destination and version."""
    return any(
        isinstance(src, dict)
        and src.get("type") == "file"
        and src.get("dest") == dest
        and _sqlite_matches_version(src, version)
        for src in sources
    )


def _create_sqlite_source(arch: str, dest: str, version: str) -> dict:
    """Create a SQLite source dictionary for the given architecture."""
    return {
        "type": "file",
        "only-arches": [arch],
        "url": f"https://www.sqlite.org/2025/sqlite-autoconf-{version}.tar.gz",
        "sha256": "a3db587a1b92ee5ddac2f66b3edb41b26f9c867275782d46c3a088977d6a5b18",
        "dest": dest,
        "dest-filename": f"sqlite-autoconf-{version}.tar.gz",
    }


def add_sqlite3_source(document: ManifestDocument) -> OperationResult:
    """Add SQLite source for sqlite3_flutter_libs plugin.

    The sqlite3_flutter_libs plugin's CMake tries to download SQLite during configure.
    We pre-download it as a file that CMake will find and extract. This function:
    1. Removes any outdated SQLite sources
    2. Adds the current version for both x86_64 and aarch64 architectures
    3. Places files exactly where CMake FetchContent expects them

    Args:
        document: The manifest document to modify

    Returns:
        OperationResult with details of changes made
    """
    modules = document.ensure_modules()
    changed = False
    messages = []

    dest_map = {
        "x86_64": "./build/linux/x64/release/_deps/sqlite3-subbuild/sqlite3-populate-prefix/src",
        "aarch64": "./build/linux/arm64/release/_deps/sqlite3-subbuild/sqlite3-populate-prefix/src",
    }

    OLD_VERSION = "3500100"
    CURRENT_VERSION = "3500400"

    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue

        sources = module.get("sources", [])
        if not isinstance(sources, list):
            sources = []
            module["sources"] = sources

        # Remove stale SQLite sources
        sources, removed_stale = _remove_stale_sqlite_sources(
            sources, dest_map, OLD_VERSION
        )
        if removed_stale:
            messages.append(f"Removed outdated SQLite {OLD_VERSION} sources")
            changed = True

        # Add current SQLite sources
        sources_changed, add_messages = _add_sqlite_sources_for_architectures(
            sources, dest_map, CURRENT_VERSION
        )
        if sources_changed:
            changed = True
            messages.extend(add_messages)

        # Update module sources
        module["sources"] = sources
        break

    if changed:
        document.mark_changed()
        message = "Updated SQLite sources for sqlite3_flutter_libs"
        _LOGGER.debug(message)
        return OperationResult(changed, messages)

    return OperationResult.unchanged()


def add_media_kit_mimalloc_source(document: ManifestDocument) -> OperationResult:
    """Add mimalloc source for media_kit_libs_linux plugin.

    The media_kit_libs_linux plugin's CMake tries to download mimalloc during configure.
    We pre-download it as a file that CMake will find and extract.

    Args:
        document: The manifest document to modify

    Returns:
        OperationResult with details of changes made
    """
    modules = document.ensure_modules()
    changed = False
    messages = []

    # Paths where CMake FetchContent expects to find mimalloc
    dest_map = {
        "x86_64": "./build/linux/x64/release",
        "aarch64": "./build/linux/arm64/release",
    }

    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue

        sources = module.get("sources", [])
        if not isinstance(sources, list):
            sources = []
            module["sources"] = sources

        for arch, dest in dest_map.items():
            # Check if mimalloc source already exists for this architecture
            has_mimalloc = any(
                isinstance(src, dict)
                and src.get("type") == "file"
                and src.get("dest") == dest
                and "mimalloc" in src.get("url", "")
                and arch in src.get("only-arches", [])
                for src in sources
            )

            if not has_mimalloc:
                # Add mimalloc source for this architecture
                mimalloc_source = {
                    "type": "file",
                    "only-arches": [arch],
                    "url": "https://github.com/microsoft/mimalloc/archive/refs/tags/v2.1.2.tar.gz",
                    "sha256": "2b1bff6f717f9725c70bf8d79e4786da13de8a270059e4ba0bdd262ae7be46eb",
                    "dest": dest,
                    "dest-filename": "mimalloc-2.1.2.tar.gz",
                }
                sources.append(mimalloc_source)
                messages.append(f"Added mimalloc source for {arch}")
                changed = True

        module["sources"] = sources
        break

    if changed:
        document.mark_changed()
        message = "Added mimalloc sources for media_kit_libs_linux"
        _LOGGER.debug(message)
        return OperationResult(changed, messages)

    return OperationResult.unchanged()


def add_sqlite3_patch(
    document: ManifestDocument,
    patch_path: str = "sqlite3_flutter_libs/0.5.34-CMakeLists.txt.patch",
    dest: str = ".pub-cache/hosted/pub.dev/sqlite3_flutter_libs-0.5.39",
) -> OperationResult:
    """Add patch for sqlite3_flutter_libs CMakeLists.txt to fix offline build.

    Args:
        document: The manifest document to modify
        patch_path: Path to the patch file
        dest: Destination directory for the patch

    Returns:
        OperationResult indicating if changes were made
    """
    modules = document.ensure_modules()
    changed = False

    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue

        sources = module.get("sources", [])
        if not isinstance(sources, list):
            sources = []
            module["sources"] = sources

        # Check if patch already exists
        has_patch = any(
            isinstance(src, dict)
            and src.get("type") == "patch"
            and src.get("path") == patch_path
            for src in sources
        )

        if not has_patch:
            # Add patch source
            patch_source = {
                "type": "patch",
                "path": patch_path,
                "dest": dest,
            }
            sources.append(patch_source)
            module["sources"] = sources
            changed = True

        break

    if changed:
        document.mark_changed()
        message = f"Added SQLite patch {patch_path}"
        _LOGGER.debug(message)
        return OperationResult.changed_result(message)

    return OperationResult.unchanged()
