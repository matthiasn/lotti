"""Source-related manifest helpers.

This module handles operations related to source management in Flatpak manifests,
including bundling offline sources, downloading missing artifacts, and managing
source references for offline builds.
"""

from __future__ import annotations

import os
import shutil
import socket
import urllib.request
import urllib.error
from urllib.parse import urlparse
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, Optional
import re

try:  # pragma: no cover
    from ..core import utils, ManifestDocument, OperationResult
except ImportError:  # pragma: no cover
    import sys

    sys.path.insert(0, str(Path(__file__).parent.parent))
    from core import utils, ManifestDocument, OperationResult  # type: ignore

_LOGGER = utils.get_logger("sources_ops")
# Only allow explicit https downloads; reject http, file, or custom schemes.
_ALLOWED_URL_SCHEMES = {"https"}


def replace_url_with_path_in_manifest(manifest_data: dict, identifier: str, path_value: str) -> bool:
    """Replace URL containing identifier with path in manifest data structure.

    Searches through all sources in the manifest (both root-level and module-level)
    and replaces URL fields containing the identifier with local path references.

    Args:
        manifest_data: The manifest dictionary structure
        identifier: String to search for in URLs
        path_value: Local path to replace the URL with

    Returns:
        True if any replacements were made
    """
    changed = False

    # Helper function to process sources list recursively
    def process_sources(sources: list, context: str = "") -> bool:
        nonlocal changed
        for source in sources:
            if not isinstance(source, dict):
                continue
            # Check if this source has a URL containing the identifier
            url = source.get("url", "")
            if identifier in url:
                # Replace URL with local path for offline builds
                source.pop("url", None)
                source["path"] = path_value
                changed = True
                _LOGGER.debug(
                    "Replaced URL containing '%s' with path '%s'%s",
                    identifier,
                    path_value,
                    f" in {context}" if context else "",
                )
        return changed

    # Check for sources at root level (simple format)
    if "sources" in manifest_data:
        sources = manifest_data.get("sources", [])
        if isinstance(sources, list):
            process_sources(sources, "root")

    # Also check for sources inside modules (Flatpak format)
    for module in manifest_data.get("modules", []):
        if not isinstance(module, dict):
            continue
        # Process sources in each module
        sources = module.get("sources", [])
        if isinstance(sources, list):
            module_name = module.get("name", "<unnamed>")
            process_sources(sources, f"module '{module_name}'")

    return changed


def replace_url_with_path(*, manifest_path: str, identifier: str, path_value: str) -> Optional[bool]:
    """File-based helper used by shell scripts to rewrite sources inline.

    This now uses proper YAML parsing instead of text manipulation.
    """

    path = Path(manifest_path)
    if not path.is_file():
        return None

    try:
        import yaml

        # Load the manifest as YAML
        content = path.read_text(encoding="utf-8")
        manifest_data = yaml.safe_load(content)

        if not isinstance(manifest_data, dict):
            _LOGGER.warning("Invalid manifest format in %s", manifest_path)
            return False

        # Replace URLs with paths in the data structure
        changed = replace_url_with_path_in_manifest(manifest_data, identifier, path_value)

        if changed:
            # Write back as YAML
            new_content = yaml.dump(
                manifest_data,
                default_flow_style=False,
                sort_keys=False,
                allow_unicode=True,
                width=120,
            )
            path.write_text(new_content, encoding="utf-8")
            _LOGGER.debug("Replaced url with path for %s", identifier)

        return changed

    except OSError as e:
        _LOGGER.warning("Failed to process manifest %s: %s", manifest_path, e)
        return None
    except yaml.YAMLError:
        _LOGGER.exception("Failed to parse YAML in %s", manifest_path)
        return None

# Keep the old text-based function for backward compatibility but mark as deprecated
def replace_url_with_path_text(text: str, identifier: str, path_value: str) -> tuple[str, bool]:
    """Replace ``url:`` lines containing ``identifier`` with ``path:`` entries.

    DEPRECATED: This function uses text manipulation which is fragile.
    Use replace_url_with_path_in_manifest() with proper YAML parsing instead.
    """

    lines = text.splitlines()
    changed = False
    for index, line in enumerate(lines):
        if "url:" in line and identifier in line:
            prefix = line.split("url:", 1)[0]
            lines[index] = f"{prefix}path: {path_value}"
            changed = True
    if not changed:
        return text, False
    return "\n".join(lines) + "\n", True


@dataclass
class ArtifactCache:
    """Resolve artifacts from local caches or download them when missing.

    This class manages the process of finding, copying, and downloading
    source artifacts for offline Flatpak builds. It searches through
    multiple cache locations and can optionally download missing files.

    Attributes:
        output_dir: Directory to place bundled artifacts
        download_missing: Whether to download missing artifacts
        search_roots: List of directories to search for cached artifacts
    """

    output_dir: Path
    download_missing: bool = False
    search_roots: Iterable[Path] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.search_roots = [Path(root) for root in self.search_roots]

    def ensure_local(self, filename: str, source_url: str) -> tuple[Optional[Path], list[str]]:
        """Ensure an artifact is available locally.

        Attempts to find the artifact in:
        1. The output directory (already bundled)
        2. Search root directories (cached)
        3. Downloads from source URL if allowed

        Args:
            filename: Name of the file to ensure
            source_url: Original URL for downloading if needed

        Returns:
            Tuple of (local_path, messages) where local_path is None if failed
        """
        messages: list[str] = []
        destination = self.output_dir / filename
        if destination.exists():
            return destination, messages

        found = self._find_in_roots(filename)
        if found:
            destination.parent.mkdir(parents=True, exist_ok=True)
            if found.resolve() != destination.resolve():
                shutil.copy2(found, destination)
            message = f"BUNDLE {filename}"
            messages.append(message)
            _LOGGER.debug(message)
            return destination, messages

        if not self.download_missing:
            message = f"MISSING {filename} {source_url}"
            messages.append(message)
            _LOGGER.debug(message)
            return None, messages

        parsed = urlparse(source_url)
        scheme = (parsed.scheme or "").lower()
        # Only allow explicit http/https downloads; reject empty or other schemes (e.g., file:)
        if scheme not in _ALLOWED_URL_SCHEMES:
            message = f"UNSUPPORTED {filename} scheme {scheme or '<none>'} {source_url}"
            messages.append(message)
            _LOGGER.warning(message)
            return None, messages

        destination.parent.mkdir(parents=True, exist_ok=True)
        try:
            # nosec B310: urlopen is guarded by strict scheme whitelist above
            with urllib.request.urlopen(source_url, timeout=30) as response, open(  # nosec B310
                destination, "wb"
            ) as handle:
                shutil.copyfileobj(response, handle)
            message = f"DOWNLOAD {filename} {source_url}"
            messages.append(message)
            _LOGGER.debug(message)
            return destination, messages
        except (
            urllib.error.URLError,
            socket.timeout,
            OSError,
        ) as exc:  # pragma: no cover - network/path errors
            _LOGGER.exception("Download failed for %s from %s", filename, source_url)
            if destination.exists():
                destination.unlink(missing_ok=True)
            message = f"ERROR {filename} {exc}"
            messages.append(message)
            return None, messages

    def _find_in_roots(self, filename: str) -> Optional[Path]:
        """Search for a file in all search root directories.

        Args:
            filename: Name of the file to find

        Returns:
            Path to the found file or None if not found
        """
        for root in self.search_roots:
            if not root.exists():
                continue
            for dirpath, _, filenames in os.walk(root):
                if filename in filenames:
                    return Path(dirpath) / filename
        return None


def _add_string_sources(
    sources: list[object],
    existing_strings: set[str],
    entries: list[Optional[str]],
) -> list[str]:
    """Add string source entries and return list of added strings.

    Args:
        sources: List of source entries to add to
        existing_strings: Set of already present string sources
        entries: List of string entries to add

    Returns:
        List of strings that were actually added
    """
    added_strings: list[str] = []
    for entry in entries:
        if _ensure_string_entry(sources, entry, existing_strings):  # type: ignore
            added_strings.append(entry)  # type: ignore[arg-type]
    return added_strings


def _build_result_messages(added_strings: list[str], flutter_file: Optional[str]) -> list[str]:
    """Build result messages for the operation."""
    messages: list[str] = []
    if added_strings:
        messages.append(f"Added offline source references: {', '.join([s for s in added_strings if s])}")
    if flutter_file:
        messages.append(f"Ensured helper file {flutter_file} available in sources")
    return messages


def _prepare_offline_entries(
    pubspec: Optional[str],
    cargo: Optional[str],
    rustup: Iterable[str] | None,
) -> list[str]:
    """Prepare the list of offline source entries."""
    rustup_list = [entry for entry in (rustup or []) if entry]
    return [pubspec, cargo, *rustup_list]


def _process_offline_sources(
    sources: list[object],
    entries: list[str],
    flutter_file: Optional[str],
) -> tuple[list[str], bool]:
    """Process offline sources and return added strings and file change status."""
    existing_strings = {source for source in sources if isinstance(source, str)}
    added_strings = _add_string_sources(sources, existing_strings, entries)
    file_changed = _ensure_file_entry(sources, flutter_file)
    return added_strings, file_changed


def add_offline_sources(
    document: ManifestDocument,
    *,
    pubspec: Optional[str] = None,
    cargo: Optional[str] = None,
    rustup: Iterable[str] | None = None,
    flutter_file: Optional[str] = None,
) -> OperationResult:
    """Ensure lotti sources reference offline JSON artifacts."""
    modules = document.ensure_modules()
    target = _find_named_module(modules, "lotti")
    if not target:
        return OperationResult.unchanged()

    sources = target.setdefault("sources", [])
    entries = _prepare_offline_entries(pubspec, cargo, rustup)
    added_strings, file_changed = _process_offline_sources(sources, entries, flutter_file)

    if not added_strings and not file_changed:
        return OperationResult.unchanged()

    document.mark_changed()
    messages = _build_result_messages(added_strings, flutter_file if file_changed else None)
    for message in messages:
        _LOGGER.debug(message)
    return OperationResult(changed=True, messages=messages)


def bundle_archive_sources(
    document: ManifestDocument,
    cache: ArtifactCache,
) -> OperationResult:
    """Replace archive/file URLs with bundled paths in the manifest."""

    modules = document.ensure_modules()
    messages: list[str] = []
    changed = False

    for module in modules:
        module_changed, module_messages = _bundle_sources_for_module(module, cache)
        if module_changed:
            changed = True
        messages.extend(module_messages)

    if changed:
        document.mark_changed()
        return OperationResult(changed=True, messages=messages)
    return OperationResult(messages=messages)


def _bundle_sources_for_module(
    module: object,
    cache: ArtifactCache,
) -> tuple[bool, list[str]]:
    if not isinstance(module, dict):
        return False, []
    sources = module.get("sources")
    if not isinstance(sources, list):
        return False, []

    module_changed = False
    messages: list[str] = []
    for source in sources:
        source_changed, source_messages = _bundle_single_source(source, cache)
        if source_changed:
            module_changed = True
        messages.extend(source_messages)
    return module_changed, messages


def _bundle_single_source(
    source: object,
    cache: ArtifactCache,
) -> tuple[bool, list[str]]:
    if not isinstance(source, dict):
        return False, []
    if source.get("type") not in {"archive", "file"}:
        return False, []
    url = source.get("url")
    if not url:
        return False, []

    # Parse URL to get clean filename without query/fragment
    parsed = urlparse(url)
    filename = os.path.basename(parsed.path)
    # Fall back to using the whole URL if basename is empty
    if not filename:
        filename = os.path.basename(url) or "download"
    local_path, fetch_messages = cache.ensure_local(filename, url)
    if local_path is None:
        return False, fetch_messages

    source["path"] = local_path.name
    source.pop("url", None)
    return True, fetch_messages


_RUSTUP_JSON_RE = re.compile(r"^rustup-.*\.json$")


def _is_rustup_source(src: object) -> bool:
    """Check if a source is a rustup JSON reference."""
    if isinstance(src, str):
        return _RUSTUP_JSON_RE.match(src) is not None
    if isinstance(src, dict) and src.get("type") == "file":
        path = str(src.get("path", ""))
        return _RUSTUP_JSON_RE.match(path) is not None
    return False


def _filter_rustup_from_module(module: dict) -> tuple[int, bool]:
    """Filter rustup sources from a module.

    Returns:
        Tuple of (number removed, whether module was changed)
    """
    sources = module.get("sources")
    if not isinstance(sources, list):
        return 0, False

    filtered = [src for src in sources if not _is_rustup_source(src)]
    removed = len(sources) - len(filtered)

    if removed > 0:
        module["sources"] = filtered
        return removed, True
    return 0, False


def remove_rustup_sources(document: ManifestDocument) -> OperationResult:
    """Remove any rustup-*.json entries from module sources.

    Accepts both bare string references and file-type dict entries.
    """
    modules = document.ensure_modules()
    changed = False
    messages: list[str] = []

    for module in modules:
        if not isinstance(module, dict):
            continue

        removed, module_changed = _filter_rustup_from_module(module)
        if module_changed:
            changed = True
            module_name = module.get("name", "<unnamed>")
            messages.append(f"Removed {removed} rustup JSON reference(s) from module {module_name}")

    if changed:
        document.mark_changed()
        for msg in messages:
            _LOGGER.debug(msg)
        return OperationResult(changed=True, messages=messages)
    return OperationResult.unchanged()


# ---- helpers to reduce complexity in add_offline_sources ----
def _find_named_module(modules: Iterable[object], name: str) -> Optional[dict]:
    for module in modules:
        if isinstance(module, dict) and module.get("name") == name:
            return module
    return None


def _ensure_string_entry(sources: list[object], entry: str, existing: set[str]) -> bool:
    if not entry or entry in existing:
        return False
    sources.append(entry)
    existing.add(entry)
    return True


def _ensure_file_entry(sources: list[object], path: Optional[str]) -> bool:
    if not path:
        return False
    present = any(
        isinstance(source, dict) and source.get("type") == "file" and source.get("path") == path for source in sources
    )
    if present:
        return False
    sources.append({"type": "file", "path": path})
    return True
