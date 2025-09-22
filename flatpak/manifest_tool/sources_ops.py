"""Source-related manifest helpers."""

from __future__ import annotations

import os
import shutil
import urllib.request
from urllib.parse import urlparse
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, Optional

try:  # pragma: no cover
    from . import utils
    from .manifest import ManifestDocument, OperationResult
except ImportError:  # pragma: no cover
    import utils  # type: ignore
    from manifest import ManifestDocument, OperationResult  # type: ignore

_LOGGER = utils.get_logger("sources_ops")
_ALLOWED_URL_SCHEMES = {"http", "https"}


def replace_url_with_path_text(text: str, identifier: str, path_value: str) -> tuple[str, bool]:
    """Replace ``url:`` lines containing ``identifier`` with ``path:`` entries."""

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


def replace_url_with_path(
    *, manifest_path: str, identifier: str, path_value: str
) -> Optional[bool]:
    """File-based helper used by shell scripts to rewrite sources inline."""

    path = Path(manifest_path)
    if not path.is_file():
        return None

    try:
        content = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return None

    new_content, changed = replace_url_with_path_text(content, identifier, path_value)
    if changed:
        path.write_text(new_content, encoding="utf-8")
        _LOGGER.debug("Replaced url with path for %s", identifier)
    return changed


@dataclass
class ArtifactCache:
    """Resolve artifacts from local caches or download them when missing."""

    output_dir: Path
    download_missing: bool = False
    search_roots: Iterable[Path] = field(default_factory=tuple)

    def __post_init__(self) -> None:
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.search_roots = [Path(root) for root in self.search_roots]

    def ensure_local(self, filename: str, source_url: str) -> tuple[Optional[Path], list[str]]:
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
        scheme = parsed.scheme or ""
        if scheme and scheme not in _ALLOWED_URL_SCHEMES:
            message = f"UNSUPPORTED {filename} scheme {scheme} {source_url}"
            messages.append(message)
            _LOGGER.warning(message)
            return None, messages

        destination.parent.mkdir(parents=True, exist_ok=True)
        try:
            with urllib.request.urlopen(source_url) as response, open(destination, "wb") as handle:
                shutil.copyfileobj(response, handle)
            message = f"DOWNLOAD {filename} {source_url}"
            messages.append(message)
            _LOGGER.debug(message)
            return destination, messages
        except Exception as exc:  # pragma: no cover - network/path errors
            if destination.exists():
                destination.unlink(missing_ok=True)
            message = f"ERROR {filename} {exc}"
            messages.append(message)
            _LOGGER.error(message)
            return None, messages

    def _find_in_roots(self, filename: str) -> Optional[Path]:
        for root in self.search_roots:
            if not root.exists():
                continue
            for dirpath, _, filenames in os.walk(root):
                if filename in filenames:
                    return Path(dirpath) / filename
        return None


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
    rustup = [entry for entry in (rustup or []) if entry]
    changed = False
    messages: list[str] = []

    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue
        sources = module.setdefault("sources", [])
        existing_strings = {source for source in sources if isinstance(source, str)}
        if pubspec and pubspec not in existing_strings:
            sources.append(pubspec)
            existing_strings.add(pubspec)
            changed = True
        if cargo and cargo not in existing_strings:
            sources.append(cargo)
            existing_strings.add(cargo)
            changed = True
        for entry in rustup:
            if entry not in existing_strings:
                sources.append(entry)
                existing_strings.add(entry)
                changed = True
        if flutter_file:
            if not any(
                isinstance(source, dict)
                and source.get("type") == "file"
                and source.get("path") == flutter_file
                for source in sources
            ):
                sources.append({"type": "file", "path": flutter_file})
                changed = True
        break

    if changed:
        document.mark_changed()
        if pubspec or cargo or rustup:
            wanted = [name for name in [pubspec, cargo, *rustup] if name]
            messages.append(f"Added offline source references: {', '.join(wanted)}")
        if flutter_file:
            messages.append(f"Ensured helper file {flutter_file} available in sources")
        for message in messages:
            _LOGGER.debug(message)
        return OperationResult(changed=True, messages=messages)
    return OperationResult.unchanged()


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

    filename = os.path.basename(url)
    local_path, fetch_messages = cache.ensure_local(filename, url)
    if local_path is None:
        return False, fetch_messages

    source["path"] = local_path.name
    source.pop("url", None)
    return True, fetch_messages
