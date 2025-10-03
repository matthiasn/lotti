"""Build utilities for locating Flutter SDK installations."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Iterable, Optional

try:  # pragma: no cover
    from ..core import utils
except ImportError:  # pragma: no cover
    import sys

    sys.path.insert(0, str(Path(__file__).parent.parent))
    from core import utils  # type: ignore

_LOGGER = utils.get_logger("build_utils")


def _should_skip_directory(current_path: Path, exclude_set: set[Path]) -> bool:
    """Return True when ``current_path`` should be ignored during traversal."""

    current_resolved = current_path.resolve()
    for excluded in exclude_set:
        try:
            current_resolved.relative_to(excluded)
            return True
        except ValueError:
            continue
    return False


def _is_valid_flutter_sdk(current_path: Path) -> bool:
    """Return True when ``current_path`` resembles a Flutter SDK checkout."""

    flutter_bin = current_path / "bin" / "flutter"
    if not (flutter_bin.is_file() and os.access(flutter_bin, os.X_OK)):
        return False

    dart_bin = current_path / "bin" / "dart"
    packages_dir = current_path / "packages"
    return dart_bin.exists() and packages_dir.is_dir()


def _search_flutter_in_root(root: Path, exclude_set: set[Path], max_depth: int) -> Optional[Path]:
    """Search ``root`` recursively for a valid Flutter SDK."""

    if not root.exists():
        return None

    for dirpath, dirnames, _ in os.walk(root):
        current_path = Path(dirpath)
        try:
            depth = len(current_path.relative_to(root).parts)
        except ValueError:
            continue

        if depth > max_depth:
            dirnames[:] = []
            continue

        if _should_skip_directory(current_path, exclude_set):
            dirnames[:] = []
            continue

        if _is_valid_flutter_sdk(current_path):
            _LOGGER.debug("Found Flutter SDK at %s", current_path)
            return current_path

    return None


def find_flutter_sdk(
    *,
    search_roots: Iterable[Path],
    exclude_paths: Optional[Iterable[Path]] = None,
    max_depth: int = 6,
) -> Optional[Path]:
    """Locate a Flutter SDK within ``search_roots``.

    Args:
        search_roots: root directories to scan.
        exclude_paths: optional paths to skip during traversal.
        max_depth: maximum directory depth below each root to explore.

    Returns:
        Path to the first matching Flutter SDK, or ``None`` if not found.
    """

    exclude_set: set[Path] = set()
    if exclude_paths:
        for path in exclude_paths:
            exclude_set.add(path.resolve())

    for root in search_roots:
        found = _search_flutter_in_root(root, exclude_set, max_depth)
        if found:
            return found

    return None
