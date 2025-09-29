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
    """Find flutter-sdk-*.json files in directory."""
    out_path = Path(output_dir)
    if not out_path.is_dir():
        return []
    json_files = list(out_path.glob("flutter-sdk-*.json"))
    # Return just filenames, not paths
    return [f.name for f in json_files]


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
    if any(
        kw in command
        for kw in ["git ", "checkout", "reset", "apply", "config", "describe"]
    ):
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
    """Replace hardcoded SDK copy with conditional version.

    Changes cp -r /var/lib/flutter to a conditional that checks
    if the directory exists first.

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
            if isinstance(cmd, str) and cmd.strip() == "cp -r /var/lib/flutter .":
                # Replace with conditional version
                new_cmd = (
                    "if [ -d /var/lib/flutter ]; then cp -r /var/lib/flutter .; fi"
                )
                new_commands.append(new_cmd)
                changed = True
            else:
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


def convert_flutter_git_to_archive(
    document: ManifestDocument, *, archive_name: str, sha256: str
) -> OperationResult:
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
        if isinstance(module, dict) and _convert_flutter_sdk_sources(
            module, archive_name, sha256
        ):
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


def _remove_flutter_sdk_if_nested(
    modules: list[Any], json_names: list[str]
) -> tuple[list[Any], bool]:
    """Remove flutter-sdk module(s) if lotti references nested SDK JSONs.

    Returns (filtered_modules, removed_any).
    """
    # Find lotti's nested references (ensure list)
    lotti_nested: list[Any] = []
    for m in modules:
        if isinstance(m, dict) and m.get("name") == "lotti":
            nested = m.get("modules") or []
            lotti_nested = nested if isinstance(nested, list) else []
            break

    # Check if any json_names are referenced in lotti's modules
    referenced = {name for name in json_names if name in lotti_nested}

    # Filter modules
    filtered: list[Any] = []
    removed_any = False
    for module in modules:
        if isinstance(module, dict) and module.get("name") == "flutter-sdk":
            if referenced:
                removed_any = True
                continue  # Skip adding flutter-sdk
        filtered.append(module)

    return filtered, removed_any
