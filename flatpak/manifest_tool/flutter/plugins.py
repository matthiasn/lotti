"""Flutter plugin dependency management."""

from __future__ import annotations

from pathlib import Path
from typing import Optional

try:  # pragma: no cover
    from ..core import ManifestDocument, OperationResult, get_logger
    from .patches import _load_pubspec_sources  # internal helper
except ImportError:  # pragma: no cover
    import sys

    sys.path.insert(0, str(Path(__file__).parent.parent))
    from core import ManifestDocument, OperationResult, get_logger  # type: ignore
    from flutter.patches import _load_pubspec_sources  # type: ignore

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


def _remove_stale_sqlite_sources(sources: list, dest_map: dict, old_version: str) -> tuple[list, bool]:
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


def _add_sqlite_sources_for_architectures(sources: list, dest_map: dict, current_version: str) -> tuple[bool, list]:
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
        messages.append(f"Added SQLite file for {arch}")
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


_SQLITE_VERSIONS = {
    "3500400": "a3db587a1b92ee5ddac2f66b3edb41b26f9c867275782d46c3a088977d6a5b18",
    "3510100": "4f2445cd70479724d32ad015ec7fd37fbb6f6130013bd4bfbc80c32beb42b7e0",
}


def _create_sqlite_source(arch: str, dest: str, version: str) -> dict:
    """Create a SQLite source dictionary for the given architecture."""
    sha256 = _SQLITE_VERSIONS[version]
    return {
        "type": "file",
        "only-arches": [arch],
        "url": f"https://www.sqlite.org/2025/sqlite-autoconf-{version}.tar.gz",
        "sha256": sha256,
        "dest": dest,
        "dest-filename": f"sqlite-autoconf-{version}.tar.gz",
    }


def _ensure_sources_list(module: dict) -> list:
    """Return a mutable list of sources for the given module."""

    sources = module.get("sources")
    if isinstance(sources, list):
        return sources
    module["sources"] = []
    return module["sources"]


def _is_mimalloc_source(entry: dict, arch: str, dest: str) -> bool:
    """Return True when entry already represents the desired mimalloc source."""

    if not isinstance(entry, dict) or entry.get("type") != "file":
        return False
    if entry.get("dest") != dest:
        return False

    arches = entry.get("only-arches", [])
    if isinstance(arches, list) and arch not in arches:
        return False

    url = entry.get("url", "")
    path = entry.get("path", "")
    filename = entry.get("dest-filename")
    return "mimalloc" in url or "mimalloc" in path or filename == "mimalloc-2.1.2.tar.gz"


def _has_mimalloc_source(sources: list, arch: str, dest: str) -> bool:
    """Check whether mimalloc source already exists for ``arch``."""

    for entry in sources:
        if _is_mimalloc_source(entry, arch, dest):
            return True
    return False


def _create_mimalloc_source(arch: str, dest: str) -> dict:
    """Create mimalloc source definition for ``arch``."""

    return {
        "type": "file",
        "only-arches": [arch],
        "url": "https://github.com/microsoft/mimalloc/archive/refs/tags/v2.1.2.tar.gz",
        "sha256": "2b1bff6f717f9725c70bf8d79e4786da13de8a270059e4ba0bdd262ae7be46eb",
        "dest": dest,
        "dest-filename": "mimalloc-2.1.2.tar.gz",
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

    OLD_VERSION = "3500400"
    CURRENT_VERSION = "3510100"

    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue

        sources = module.get("sources", [])
        if not isinstance(sources, list):
            sources = []
            module["sources"] = sources

        # Remove stale SQLite sources
        sources, removed_stale = _remove_stale_sqlite_sources(sources, dest_map, OLD_VERSION)
        if removed_stale:
            messages.append(f"Removed outdated SQLite {OLD_VERSION} sources")
            changed = True

        # Add current SQLite sources
        sources_changed, add_messages = _add_sqlite_sources_for_architectures(sources, dest_map, CURRENT_VERSION)
        if sources_changed:
            changed = True
            messages.extend(add_messages)

        # Also add a patch that injects URL_HASH into the plugin CMake to avoid redownloads
        # Compute plugin version and matching patch path (if available)
        manifest_path = getattr(document, "path", None)
        manifest_dir = Path(manifest_path).parent if manifest_path else Path.cwd()
        entries = _load_pubspec_sources(document)

        plugin_version = _extract_sqlite_plugin_version(entries)
        patch_rel = _compute_sqlite_patch_rel(manifest_dir, plugin_version)

        if plugin_version and patch_rel:
            plugin_root = f".pub-cache/hosted/pub.dev/sqlite3_flutter_libs-{plugin_version}"
            # Remove any existing sqlite3_flutter_libs CMake patches (avoid duplicate patching)
            old_sources = sources[:]
            sources[:] = [
                src
                for src in sources
                if not (
                    isinstance(src, dict)
                    and src.get("type") == "patch"
                    and str(src.get("path", "")).startswith("sqlite3_flutter_libs/")
                    and str(src.get("path", "")).endswith("-CMakeLists.txt.patch")
                )
            ]
            if len(sources) < len(old_sources):
                changed = True
                messages.append("Removed outdated sqlite3_flutter_libs CMake patch(es)")
            # Add the correct version patch
            already = any(
                isinstance(src, dict) and src.get("type") == "patch" and src.get("path") == patch_rel for src in sources
            )
            if not already:
                sources.append({"type": "patch", "path": patch_rel, "dest": plugin_root})
                changed = True
                messages.append(f"Added sqlite3_flutter_libs CMake patch {patch_rel}")

        # Update module sources
        module["sources"] = sources
        break

    if changed:
        document.mark_changed()
        message = "Updated SQLite sources for sqlite3_flutter_libs"
        _LOGGER.debug(message)
        return OperationResult(changed, messages)

    return OperationResult.unchanged()


def _extract_sqlite_plugin_version(entries) -> Optional[str]:
    """Extract sqlite3_flutter_libs version from pubspec-sources entries."""
    if not entries:
        return None
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        dest = str(entry.get("dest", ""))
        if "/pub.dev/sqlite3_flutter_libs-" in dest:
            try:
                return dest.split("/sqlite3_flutter_libs-", 1)[1]
            except Exception:  # pragma: no cover - defensive
                return None
    return None


def _compute_sqlite_patch_rel(manifest_dir: Path, plugin_version: Optional[str]) -> Optional[str]:
    """Return relative path to the best sqlite patch file if present."""
    patch_dir = manifest_dir / "sqlite3_flutter_libs"
    if not patch_dir.is_dir():
        return None
    # Prefer exact version match
    if plugin_version:
        exact = patch_dir / f"{plugin_version}-CMakeLists.txt.patch"
        if exact.is_file():
            return f"sqlite3_flutter_libs/{exact.name}"
    # Fallback to any available patch file
    candidates = sorted(patch_dir.glob("*-CMakeLists.txt.patch"))
    if candidates:
        return f"sqlite3_flutter_libs/{candidates[-1].name}"
    return None


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

        sources = _ensure_sources_list(module)

        for arch, dest in dest_map.items():
            if _has_mimalloc_source(sources, arch, dest):
                continue

            sources.append(_create_mimalloc_source(arch, dest))
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


def ensure_pub_package_archive(
    document: ManifestDocument,
    *,
    name: str,
    version: str,
    sha256: Optional[str] = None,
) -> OperationResult:
    """Ensure a Dart pub package archive is extracted into the offline cache.

    Adds a manifest source of type 'archive' that extracts the given package
    into `.pub-cache/hosted/pub.dev/<name>-<version>` so that offline pub gets
    inside plugin build tools can resolve exact pinned versions.
    """
    modules = document.ensure_modules()
    changed = False
    messages: list[str] = []

    target_dest = f".pub-cache/hosted/pub.dev/{name}-{version}"

    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue
        sources = module.setdefault("sources", [])

        # Check if already present
        present = False
        for entry in sources:
            if not isinstance(entry, dict):
                continue
            if entry.get("type") == "archive" and entry.get("dest") == target_dest:
                present = True
                break
            if entry.get("type") == "file" and entry.get("path") == target_dest:
                present = True
                break

        if not present:
            archive_entry: dict[str, object] = {
                "type": "archive",
                "archive-type": "tar-gzip",
                "url": f"https://pub.dev/api/archives/{name}-{version}.tar.gz",
                "dest": target_dest,
            }
            if sha256:
                archive_entry["sha256"] = sha256
            sources.append(archive_entry)
            changed = True
            messages.append(f"Added pub package {name}-{version} to offline cache")

        module["sources"] = sources
        break

    if changed:
        document.mark_changed()
        return OperationResult.changed_result("; ".join(messages))
    return OperationResult.unchanged()
