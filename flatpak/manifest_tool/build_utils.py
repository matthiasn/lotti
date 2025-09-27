"""Build preparation utilities for Flatpak builds."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Optional, Iterable

try:  # pragma: no cover
    from . import utils
except ImportError:  # pragma: no cover
    import utils  # type: ignore

_LOGGER = utils.get_logger("build_utils")


def _should_skip_directory(current_path: Path, exclude_set: set[Path]) -> bool:
    """Check if a directory should be skipped based on exclusions."""
    current_resolved = current_path.resolve()
    for excluded in exclude_set:
        try:
            # Check if current path is inside an excluded directory
            current_resolved.relative_to(excluded)
            return True
        except ValueError:
            # Not a subdirectory
            continue
    return False


def _is_valid_flutter_sdk(current_path: Path) -> bool:
    """Check if a directory contains a valid Flutter SDK."""
    flutter_bin = current_path / "bin" / "flutter"
    if not (flutter_bin.is_file() and os.access(flutter_bin, os.X_OK)):
        return False

    # Verify it's a valid Flutter SDK by checking for other expected files
    dart_bin = current_path / "bin" / "dart"
    packages_dir = current_path / "packages"
    return dart_bin.exists() and packages_dir.is_dir()


def _search_flutter_in_root(
    root: Path, exclude_set: set[Path], max_depth: int
) -> Optional[Path]:
    """Search for Flutter SDK in a single root directory."""
    if not root.exists():
        return None

    for dirpath, dirnames, filenames in os.walk(root):
        current_path = Path(dirpath)

        # Calculate depth
        try:
            depth = len(current_path.relative_to(root).parts)
        except ValueError:
            continue

        if depth > max_depth:
            dirnames[:] = []  # Don't recurse deeper
            continue

        # Skip excluded directories
        if _should_skip_directory(current_path, exclude_set):
            dirnames[:] = []  # Don't recurse into excluded dirs
            continue

        # Check if this is a Flutter SDK directory
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
    """Find a cached Flutter SDK installation.

    Args:
        search_roots: Root directories to search in
        exclude_paths: Paths to exclude from search (e.g., work directories)
        max_depth: Maximum directory depth to search

    Returns:
        Path to Flutter SDK directory, or None if not found
    """
    exclude_set = set()
    if exclude_paths:
        for path in exclude_paths:
            exclude_set.add(path.resolve())

    for root in search_roots:
        found = _search_flutter_in_root(root, exclude_set, max_depth)
        if found:
            return found

    return None


def prepare_build_directory(
    *,
    build_dir: Path,
    pubspec_yaml: Optional[Path] = None,
    pubspec_lock: Optional[Path] = None,
    create_foreign_deps: bool = True,
) -> bool:
    """Prepare a build directory for flatpak-flutter.

    Args:
        build_dir: The build directory to prepare
        pubspec_yaml: Path to pubspec.yaml to copy
        pubspec_lock: Path to pubspec.lock to copy
        create_foreign_deps: Whether to create empty foreign_deps.json

    Returns:
        True if successful, False otherwise
    """
    try:
        build_dir.mkdir(parents=True, exist_ok=True)

        # Copy pubspec files if provided
        if pubspec_yaml and pubspec_yaml.exists():
            dest = build_dir / "pubspec.yaml"
            dest.write_bytes(pubspec_yaml.read_bytes())
            _LOGGER.debug("Copied pubspec.yaml to %s", dest)

        if pubspec_lock and pubspec_lock.exists():
            dest = build_dir / "pubspec.lock"
            dest.write_bytes(pubspec_lock.read_bytes())
            _LOGGER.debug("Copied pubspec.lock to %s", dest)

        # Create empty foreign_deps.json if requested
        if create_foreign_deps:
            foreign_deps = build_dir / "foreign_deps.json"
            if not foreign_deps.exists():
                foreign_deps.write_text("{}", encoding="utf-8")
                _LOGGER.debug("Created empty foreign_deps.json in %s", build_dir)

        return True

    except (OSError, IOError) as e:
        _LOGGER.error("Failed to prepare build directory %s: %s", build_dir, e)
        return False


def copy_flutter_sdk(
    *, source_sdk: Path, target_dir: Path, clean_target: bool = True
) -> bool:
    """Copy a Flutter SDK to a target directory.

    Args:
        source_sdk: Source Flutter SDK directory
        target_dir: Target directory for the SDK
        clean_target: Whether to clean existing content in target

    Returns:
        True if successful, False otherwise
    """
    import shutil

    try:
        # Verify source is a valid Flutter SDK
        flutter_bin = source_sdk / "bin" / "flutter"
        if not flutter_bin.is_file():
            _LOGGER.error("Invalid Flutter SDK at %s: missing bin/flutter", source_sdk)
            return False

        # Prepare target directory
        target_dir.mkdir(parents=True, exist_ok=True)

        if clean_target and target_dir.exists():
            # Remove existing contents but keep the directory
            for item in target_dir.iterdir():
                if item.is_dir():
                    shutil.rmtree(item)
                else:
                    item.unlink()
            _LOGGER.debug("Cleaned existing content in %s", target_dir)

        # Copy SDK
        _LOGGER.info("Copying Flutter SDK from %s to %s", source_sdk, target_dir)

        # Use shutil.copytree with dirs_exist_ok for Python 3.8+
        if hasattr(shutil, "copytree"):
            # Copy all contents of source_sdk to target_dir
            for item in source_sdk.iterdir():
                dest = target_dir / item.name
                if item.is_dir():
                    shutil.copytree(item, dest, dirs_exist_ok=True)
                else:
                    shutil.copy2(item, dest)
        else:
            # Fallback for older Python
            from distutils.dir_util import copy_tree

            copy_tree(str(source_sdk), str(target_dir))

        # Verify the copy
        target_flutter = target_dir / "bin" / "flutter"
        if not target_flutter.is_file():
            _LOGGER.error("Flutter SDK copy verification failed")
            return False

        _LOGGER.info("Successfully copied Flutter SDK to %s", target_dir)
        return True

    except (OSError, IOError, shutil.Error) as e:
        _LOGGER.error("Failed to copy Flutter SDK: %s", e)
        return False
