"""Source-related manifest helpers."""

from __future__ import annotations

import os
import shutil
import urllib.request
from pathlib import Path
from typing import Iterable, Optional

try:  # pragma: no cover
    from . import utils
except ImportError:  # pragma: no cover
    import utils  # type: ignore


def replace_url_with_path(
    *, manifest_path: str, identifier: str, path_value: str
) -> Optional[bool]:
    """Replace url entries containing ``identifier`` with a path value.

    Mirrors the earlier inline Python behavior from the Flatpak shell scripts.
    Returns ``True`` when a replacement was made, ``False`` when nothing matched,
    and ``None`` when the manifest is absent.
    """

    path = Path(manifest_path)
    if not path.is_file():
        return None

    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except FileNotFoundError:
        return None

    changed = False
    for index, line in enumerate(lines):
        if "url:" in line and identifier in line:
            prefix = line.split("url:", 1)[0]
            lines[index] = f"{prefix}path: {path_value}"
            changed = True

    if changed:
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return changed


def add_offline_sources(
    *,
    manifest_path: str,
    pubspec: Optional[str] = None,
    cargo: Optional[str] = None,
    rustup: Iterable[str] | None = None,
    flutter_file: Optional[str] = None,
) -> bool:
    """Ensure lotti sources reference offline JSON artifacts."""

    data = utils.load_manifest(manifest_path)
    modules = data.get("modules")
    if not isinstance(modules, list):
        return False

    rustup = list(rustup or [])

    changed = False
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
            if entry and entry not in existing_strings:
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
        if changed:
            break

    if changed:
        utils.dump_manifest(manifest_path, data)
    return changed


def bundle_archive_sources(
    *,
    manifest_path: str,
    output_dir: str,
    download_missing: bool,
    search_roots: Iterable[str],
) -> bool:
    """Replace archive/file URLs with bundled paths in the manifest."""

    manifest = utils.load_manifest(manifest_path)
    modules = manifest.get("modules")
    if not isinstance(modules, list):
        return False

    out_dir = Path(output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    roots = [Path(root) for root in search_roots if root]

    def ensure_local(filename: str, source_url: str) -> Optional[Path]:
        candidate = out_dir / filename
        if candidate.exists():
            return candidate

        for root in roots:
            if not root.exists():
                continue
            for dirpath, _, filenames in os.walk(root):
                if filename in filenames:
                    src = Path(dirpath) / filename
                    candidate.parent.mkdir(parents=True, exist_ok=True)
                    if src.resolve() != candidate.resolve():
                        shutil.copy2(src, candidate)
                    return candidate

        if not download_missing:
            return None

        candidate.parent.mkdir(parents=True, exist_ok=True)
        try:
            with urllib.request.urlopen(source_url) as response, open(candidate, "wb") as handle:
                shutil.copyfileobj(response, handle)
            print(f"DOWNLOAD {filename} {source_url}")
            return candidate
        except Exception as exc:  # pylint: disable=broad-except
            print(f"ERROR {filename} {exc}")
            if candidate.exists():
                candidate.unlink(missing_ok=True)
            return None

    changed = False
    for module in modules:
        if not isinstance(module, dict):
            continue
        sources = module.get("sources")
        if not isinstance(sources, list):
            continue
        for source in sources:
            if not isinstance(source, dict):
                continue
            if source.get("type") not in {"archive", "file"}:
                continue
            url = source.get("url")
            if not url:
                continue
            filename = os.path.basename(url)
            local_path = ensure_local(filename, url)
            if local_path is None:
                print(f"MISSING {filename} {url}")
                continue
            source["path"] = local_path.name
            source.pop("url", None)
            changed = True
            print(f"BUNDLE {local_path.name}")

    if changed:
        utils.dump_manifest(manifest_path, manifest)
    return changed
