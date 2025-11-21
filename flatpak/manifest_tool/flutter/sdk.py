"""Flutter SDK management operations."""

from __future__ import annotations

from pathlib import Path
import shlex
from typing import Any, Iterable, Optional

try:  # pragma: no cover
    from ..core import ManifestDocument, OperationResult, get_logger
except ImportError:  # pragma: no cover
    import sys

    sys.path.insert(0, str(Path(__file__).parent.parent))
    from core import ManifestDocument, OperationResult, get_logger  # type: ignore

_LOGGER = get_logger("flutter.sdk")


def _discover_flutter_jsons(output_dir: str | Path) -> list[str]:
    """Find flutter-sdk-*.json files in directory."""
    out_path = Path(output_dir)
    if not out_path.is_dir():
        return []
    json_files = list(out_path.glob("flutter-sdk-*.json"))
    # Return just filenames, not paths
    return [f.name for f in json_files]


def _get_lotti_module(modules: Iterable[Any]) -> Optional[dict]:
    """Return the lotti module dictionary if present."""

    for module in modules:
        if isinstance(module, dict) and module.get("name") == "lotti":
            return module
    return None


def _ensure_list(module: dict, key: str) -> list:
    """Ensure ``module[key]`` is a list and return it."""

    value = module.get(key)
    if isinstance(value, list):
        return value
    module[key] = []
    return module[key]


def _append_missing_entries(target: list, entries: Iterable[str]) -> bool:
    """Append items from ``entries`` that are not yet in ``target``."""

    changed = False
    for entry in entries:
        if entry not in target:
            target.append(entry)
            changed = True
    return changed


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
    lotti_module = _get_lotti_module(modules)
    if lotti_module is None:
        return OperationResult.unchanged()

    nested_modules = _ensure_list(lotti_module, "modules")
    changed = _append_missing_entries(nested_modules, json_names)

    # Also remove top-level flutter-sdk module if nested SDKs are present
    if changed:
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
    """Check if top-level flutter-sdk module should be removed.

    Returns True if lotti module references nested flutter SDK JSON files,
    making the top-level flutter-sdk module redundant.

    Args:
        document: The manifest document to check
        output_dir: Directory containing flutter-sdk-*.json files

    Returns:
        True if flutter-sdk should be removed, False otherwise
    """
    json_names = _discover_flutter_jsons(output_dir)
    if not json_names:
        return False

    modules = document.data.get("modules", [])
    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue
        nested = module.get("modules", [])
        if isinstance(nested, list):
            # Check if any SDK JSON is referenced
            for json_name in json_names:
                if json_name in nested:
                    return True
        break
    return False


def _should_keep_flutter_command(command: str) -> bool:
    """Check if a build command should be kept when normalizing flutter-sdk."""
    if not isinstance(command, str):
        return False
    # Keep Flutter commands but remove SDK manipulation
    if any(kw in command for kw in ["git ", "checkout", "reset", "apply", "config", "describe"]):
        return False
    if "flutter" in command.lower():
        return command.startswith("mv flutter") or command.startswith("export PATH")
    return True


def _normalize_single_flutter_module(module: dict) -> bool:
    """Normalize a single Flutter module. Returns True if changed."""
    if module.get("name") != "flutter-sdk":
        return False

    commands = module.get("build-commands", [])
    if not commands:
        return False

    # Check if already normalized
    if commands == ["mv flutter /app/flutter", "export PATH=/app/flutter/bin:$PATH"]:
        return False

    # Replace with normalized commands
    module["build-commands"] = [
        "mv flutter /app/flutter",
        "export PATH=/app/flutter/bin:$PATH",
    ]
    return True


def normalize_flutter_sdk_module(document: ManifestDocument) -> OperationResult:
    """Normalize flutter-sdk module's build commands.

    Reduces build commands to just the essential move and path export,
    removing git operations that don't work in offline builds.

    Args:
        document: The manifest document to modify

    Returns:
        OperationResult indicating if changes were made
    """
    modules = document.ensure_modules()
    changed = False

    for module in modules:
        if isinstance(module, dict) and _normalize_single_flutter_module(module):
            changed = True

    if changed:
        document.mark_changed()
        message = "Normalized flutter-sdk module build commands"
        _LOGGER.debug(message)
        return OperationResult.changed_result(message)
    return OperationResult.unchanged()


def normalize_sdk_copy(document: ManifestDocument) -> OperationResult:
    """Normalize Flutter SDK copy commands to be robust.

    - If commands copy from a single hardcoded location (only /var/lib/flutter or only /app/flutter),
      replace them with a conditional that tries both locations.
    - Preserve destination path.

    Args:
        document: The manifest document to modify

    Returns:
        OperationResult indicating if changes were made
    """
    modules = document.ensure_modules()
    changed = False

    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue

        commands = module.get("build-commands", [])
        if not isinstance(commands, list):
            continue

        new_commands = []
        for cmd in commands:
            if not isinstance(cmd, str):
                new_commands.append(cmd)
                continue

            stripped = cmd.strip()

            # Match common copy forms used in our manifests
            # 1) cp -r /var/lib/flutter /run/build/lotti/flutter_sdk
            # 2) cp -r /app/flutter /run/build/lotti/flutter_sdk
            # 3) cp -r /var/lib/flutter . (older form)
            # 4) cp -r /app/flutter . (rare)
            if stripped.startswith("cp -r /var/lib/flutter ") or stripped.startswith("cp -r /app/flutter "):
                parts = stripped.split()
                # Expect: cp -r <src> <dest>
                if len(parts) >= 4 and parts[0] == "cp" and parts[1] == "-r":
                    dest = parts[3]
                    # Shell-escape destination to prevent injection in constructed command
                    escaped_dest = shlex.quote(dest)
                    new_commands.append(f"cp -r /var/lib/flutter {escaped_dest}")
                    changed = True
                    continue

            new_commands.append(cmd)

        if changed:
            module["build-commands"] = new_commands
        break

    if changed:
        document.mark_changed()
        message = "Made Flutter SDK copy conditional"
        _LOGGER.debug(message)
        return OperationResult.changed_result(message)
    return OperationResult.unchanged()


def _convert_flutter_sdk_sources(module: dict, archive_name: str, sha256: str) -> bool:
    """Convert flutter-sdk module sources from git to archive. Returns True if changed."""
    if module.get("name") != "flutter-sdk":
        return False

    sources = module.get("sources", [])
    if not sources:
        return False

    # Already has archive source
    for source in sources:
        if isinstance(source, dict) and source.get("type") == "archive":
            return False

    # Replace all sources with archive
    module["sources"] = [
        {
            "type": "archive",
            "url": f"https://github.com/flutter/flutter/archive/{archive_name}",
            "sha256": sha256,
        }
    ]
    return True


def convert_flutter_git_to_archive(document: ManifestDocument, *, archive_name: str, sha256: str) -> OperationResult:
    """Convert flutter-sdk from git source to archive source.

    Args:
        document: The manifest document to modify
        archive_name: Name of the archive file
        sha256: SHA256 hash of the archive

    Returns:
        OperationResult indicating if changes were made
    """
    modules = document.ensure_modules()
    changed = False

    for module in modules:
        if isinstance(module, dict) and _convert_flutter_sdk_sources(module, archive_name, sha256):
            changed = True

    if changed:
        document.mark_changed()
        message = f"Converted Flutter SDK to archive source: {archive_name}"
        _LOGGER.debug(message)
        return OperationResult.changed_result(message)
    return OperationResult.unchanged()


def rewrite_flutter_git_url(document: ManifestDocument) -> OperationResult:
    """Rewrite Flutter git URL to canonical form.

    Ensures the flutter-sdk module uses the canonical GitHub URL
    with .git extension.

    Args:
        document: The manifest document to modify

    Returns:
        OperationResult indicating if changes were made
    """
    modules = document.ensure_modules()
    changed = False

    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "flutter-sdk":
            continue

        sources = module.get("sources", [])
        for source in sources:
            if not isinstance(source, dict) or source.get("type") != "git":
                continue

            url = source.get("url", "")
            # Only rewrite if it's a flutter/flutter URL without .git
            if "flutter/flutter" in url and not url.endswith(".git"):
                source["url"] = "https://github.com/flutter/flutter.git"
                changed = True

    if changed:
        document.mark_changed()
        message = "Rewrote Flutter git URL to canonical form"
        _LOGGER.debug(message)
        return OperationResult.changed_result(message)
    return OperationResult.unchanged()


def _collect_lotti_nested_references(modules: Iterable[Any], candidates: Iterable[str]) -> set[str]:
    """Return candidate names referenced in the lotti module."""

    lotti_module = _get_lotti_module(modules)
    if not lotti_module:
        return set()

    nested = lotti_module.get("modules")
    if not isinstance(nested, list):
        return set()

    nested_set = {name for name in nested if isinstance(name, str)}
    return {candidate for candidate in candidates if candidate in nested_set}


def _remove_flutter_sdk_if_nested(modules: list[Any], json_names: list[str]) -> tuple[list[Any], bool]:
    """Remove flutter-sdk module(s) when nested SDKs are referenced."""

    referenced = _collect_lotti_nested_references(modules, json_names)
    if not referenced:
        return modules, False

    filtered: list[Any] = []
    removed_any = False
    for module in modules:
        if isinstance(module, dict) and module.get("name") == "flutter-sdk":
            removed_any = True
            continue
        filtered.append(module)

    return filtered, removed_any
