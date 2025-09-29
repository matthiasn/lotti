"""Flutter SDK management operations."""

from __future__ import annotations

from pathlib import Path
from typing import Any

try:  # pragma: no cover
    from ..core import ManifestDocument, OperationResult, get_logger
except ImportError:  # pragma: no cover
    import sys

    sys.path.insert(0, str(Path(__file__).parent.parent))
    from core import ManifestDocument, OperationResult, get_logger  # type: ignore

_LOGGER = get_logger("flutter.sdk")


def _discover_flutter_jsons(output_dir: str | Path) -> list[str]:
    """Find all Flutter SDK JSON files in the output directory.

    Args:
        output_dir: Directory to search for flutter-sdk-*.json files

    Returns:
        Sorted list of Flutter SDK JSON filenames
    """
    return sorted(
        candidate.name for candidate in Path(output_dir).glob("flutter-sdk-*.json")
    )


def ensure_nested_sdk(
    document: ManifestDocument,
    *,
    output_dir: str | Path,
) -> OperationResult:
    """Ensure nested flutter SDK JSON modules are referenced by lotti.

    Searches for flutter-sdk-*.json files and adds them as nested modules
    in the lotti module to provide offline Flutter SDK sources.

    Args:
        document: The manifest document to modify
        output_dir: Directory containing flutter-sdk-*.json files

    Returns:
        OperationResult indicating if changes were made
    """

    json_names = _discover_flutter_jsons(output_dir)
    if not json_names:
        return OperationResult.unchanged()

    modules = document.ensure_modules()
    changed = False
    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue
        nested_modules = module.get("modules") or []
        if not isinstance(nested_modules, list):
            nested_modules = []
        for json_name in json_names:
            if json_name not in nested_modules:
                nested_modules.append(json_name)
                changed = True
        module["modules"] = nested_modules
        break

    # Also remove top-level flutter-sdk module if nested SDKs are present
    if changed and json_names:
        filtered_modules, removed = _remove_flutter_sdk_if_nested(modules, json_names)
        if removed:
            document.data["modules"] = filtered_modules

    if changed:
        document.mark_changed()
        message = f"Ensured nested Flutter SDK references: {', '.join(json_names)}"
        _LOGGER.debug(message)
        return OperationResult.changed_result(message)
    return OperationResult.unchanged()


def should_remove_flutter_sdk(
    document: ManifestDocument,
    *,
    output_dir: str | Path,
) -> bool:
    """Check if flutter-sdk module should be removed.

    Returns True when offline Flutter SDK JSON files are present and
    already referenced in the lotti module, making the flutter-sdk module redundant.

    Args:
        document: The manifest document to check
        output_dir: Directory to search for flutter-sdk-*.json files

    Returns:
        True if flutter-sdk module should be removed
    """

    json_names = _discover_flutter_jsons(output_dir)
    if not json_names:
        return False

    modules = document.ensure_modules()
    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue
        referenced = [
            name for name in json_names if name in (module.get("modules") or [])
        ]
        return bool(referenced)
    return False


def _should_keep_flutter_command(command: str) -> bool:
    """Check if a Flutter SDK build command should be kept.

    Only 'mv flutter' and 'export PATH' commands are needed when using
    offline Flutter SDK. Other commands like 'flutter precache' are redundant.

    Args:
        command: Build command to check

    Returns:
        True if command should be kept, False otherwise
    """
    return command.startswith("mv flutter ") or command.startswith(
        "export PATH=/app/flutter/bin"
    )


def _normalize_single_flutter_module(module: dict) -> bool:
    """Normalize a single flutter-sdk module. Returns True if changed."""
    if not isinstance(module, dict) or module.get("name") != "flutter-sdk":
        return False

    commands = module.get("build-commands", [])
    if not isinstance(commands, list):
        commands = []

    # Filter commands keeping only mv and export PATH commands
    filtered = [str(cmd) for cmd in commands if _should_keep_flutter_command(str(cmd))]

    # Ensure at least one mv command exists
    if not any(cmd.startswith("mv flutter ") for cmd in filtered):
        filtered.insert(0, "mv flutter /app/flutter")

    if filtered != commands:
        module["build-commands"] = filtered
        return True
    return False


def normalize_flutter_sdk_module(document: ManifestDocument) -> OperationResult:
    """Strip Flutter invocations from flutter-sdk build commands.

    Removes unnecessary Flutter commands (like 'flutter precache') when using
    offline SDK, keeping only the essential 'mv' and 'export PATH' commands.

    Args:
        document: The manifest document to modify

    Returns:
        OperationResult indicating if changes were made
    """
    modules = document.ensure_modules()
    changed = any(_normalize_single_flutter_module(module) for module in modules)

    if changed:
        document.mark_changed()
        message = "Normalized flutter-sdk build commands"
        _LOGGER.debug(message)
        return OperationResult.changed_result(message)
    return OperationResult.unchanged()


def normalize_sdk_copy(document: ManifestDocument) -> OperationResult:
    """Replace flutter-sdk copy with simpler fallback."""

    modules = document.ensure_modules()
    changed = False

    _FALLBACK_COPY_SNIPPET = (
        "if [ -d /var/lib/flutter ]; then cp -r /var/lib/flutter {dst}; "
        "elif [ -d /app/flutter ]; then cp -r /app/flutter {dst}; "
        'else echo "No Flutter SDK found at /var/lib/flutter or /app/flutter"; exit 1; fi'
    )

    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue

        commands = module.get("build-commands", [])
        if not isinstance(commands, list):
            continue

        for idx, raw in enumerate(commands):
            command = str(raw)
            # Look for the complex copy pattern
            if "cp -r /app/flutter" in command and "flutter_sdk" in command:
                replacement = _FALLBACK_COPY_SNIPPET.format(
                    dst="/run/build/lotti/flutter_sdk"
                )
                commands[idx] = replacement
                changed = True

        if changed:
            module["build-commands"] = commands
        break

    if changed:
        document.mark_changed()
        message = "Replaced flutter-sdk copy with fallback snippet"
        _LOGGER.debug(message)
        return OperationResult.changed_result(message)
    return OperationResult.unchanged()


def _convert_flutter_sdk_sources(module: dict, archive_name: str, sha256: str) -> bool:
    """Convert flutter-sdk git source to archive. Returns True if changed."""
    sources = module.get("sources", [])
    changed = False

    for idx, source in enumerate(sources):
        if (
            isinstance(source, dict)
            and source.get("type") == "git"
            and "flutter/flutter" in source.get("url", "")
        ):
            sources[idx] = {
                "type": "archive",
                "url": f"https://github.com/flutter/flutter/archive/{archive_name}",
                "sha256": sha256,
                "dest": "flutter",
                "strip-components": 1,
            }
            changed = True
            break
    return changed


def convert_flutter_git_to_archive(
    document: ManifestDocument,
    *,
    archive_name: str,
    sha256: str,
) -> OperationResult:
    """Convert flutter-sdk git source to archive."""
    modules = document.ensure_modules()
    changed = False

    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "flutter-sdk":
            continue
        if _convert_flutter_sdk_sources(module, archive_name, sha256):
            changed = True
        break

    if changed:
        document.mark_changed()
        message = f"Converted Flutter SDK git source to archive {archive_name}"
        _LOGGER.debug(message)
        return OperationResult.changed_result(message)
    return OperationResult.unchanged()


_CANONICAL_FLUTTER_URL = "https://github.com/flutter/flutter.git"


def rewrite_flutter_git_url(document: ManifestDocument) -> OperationResult:
    """Rewrite Flutter git URL to canonical form."""
    modules = document.ensure_modules()
    changed = False

    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "flutter-sdk":
            continue
        sources = module.get("sources", [])
        for source in sources:
            if (
                isinstance(source, dict)
                and source.get("type") == "git"
                and "flutter/flutter" in source.get("url", "")
                and source.get("url") != _CANONICAL_FLUTTER_URL
            ):
                source["url"] = _CANONICAL_FLUTTER_URL
                changed = True
        break

    if changed:
        document.mark_changed()
        message = f"Rewrote Flutter git URL to {_CANONICAL_FLUTTER_URL}"
        _LOGGER.debug(message)
        return OperationResult.changed_result(message)
    return OperationResult.unchanged()


def _remove_flutter_sdk_if_nested(
    modules: list[Any], json_names: list[str]
) -> tuple[list[Any], bool]:
    """Remove flutter-sdk module if nested SDKs are referenced. Returns (modules, changed)."""
    filtered: list[Any] = []
    changed = False

    for module in modules:
        if not isinstance(module, dict):
            filtered.append(module)
            continue
        if module.get("name") == "flutter-sdk":
            # Check if lotti references nested SDKs
            for other in modules:
                if isinstance(other, dict) and other.get("name") == "lotti":
                    nested = other.get("modules", [])
                    referenced = [name for name in json_names if name in nested]
                    if referenced:
                        changed = True
                        continue  # Skip adding flutter-sdk
            if not changed:
                filtered.append(module)
        else:
            filtered.append(module)

    return filtered, changed
