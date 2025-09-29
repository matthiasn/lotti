"""Helper operations for Flutter build setup."""

from __future__ import annotations

from pathlib import Path
from typing import Any, Optional

try:  # pragma: no cover
    from ..core import ManifestDocument, OperationResult, get_logger
except ImportError:  # pragma: no cover
    import sys

    sys.path.insert(0, str(Path(__file__).parent.parent))
    from core import ManifestDocument, OperationResult, get_logger  # type: ignore

_LOGGER = get_logger("flutter.helpers")


def ensure_setup_helper_source(
    document: ManifestDocument,
    *,
    helper_name: str,
) -> OperationResult:
    """Ensure flutter-sdk module has the setup helper source."""

    modules = document.ensure_modules()
    changed = False

    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "flutter-sdk":
            continue

        sources = module.setdefault("sources", [])
        has_helper = any(
            isinstance(source, dict)
            and source.get("dest-filename") == "setup-flutter.sh"
            for source in sources
        )

        if not has_helper:
            sources.append(
                {
                    "type": "file",
                    "path": helper_name,
                    "dest": "flutter/bin",
                    "dest-filename": "setup-flutter.sh",
                }
            )
            changed = True
        break

    if changed:
        document.mark_changed()
        message = f"Ensured setup helper {helper_name} in flutter-sdk sources"
        _LOGGER.debug(message)
        return OperationResult.changed_result(message)
    return OperationResult.unchanged()


def _build_setup_helper_command(
    layout: str,
    enable_debug: bool,
    resolver_paths: Optional[list[str]],
    working_dir: Optional[str],
) -> str:
    """Build the setup-flutter.sh command with parameters."""
    command = "setup-flutter.sh"

    # Add resolver paths if specified
    if resolver_paths:
        for path in resolver_paths:
            command += f" -r {path}"

    # Add working directory if specified and not default
    if working_dir and working_dir != ".":
        command += f" -C {working_dir}"

    # Add debug flag if enabled
    if enable_debug:
        command += " -d"

    return command


def _update_lotti_build_commands(
    module: dict, command: str, before_position: int = 1
) -> bool:
    """Update lotti module build commands with setup helper."""
    commands = module.get("build-commands", [])
    if not isinstance(commands, list):
        commands = []

    # Check if command already exists
    for cmd in commands:
        if isinstance(cmd, str) and "setup-flutter.sh" in cmd:
            # Update if different
            if cmd != command:
                idx = commands.index(cmd)
                commands[idx] = command
                module["build-commands"] = commands
                return True
            return False

    # Insert at specified position
    position = min(before_position, len(commands))
    commands.insert(position, command)
    module["build-commands"] = commands
    return True


def _find_insertion_index(commands: list[str]) -> int:
    """Find appropriate index to insert setup command."""
    for i, cmd in enumerate(commands):
        if "echo" in str(cmd).lower() and "setting up" in str(cmd).lower():
            return i + 1
    return 1  # Default to position 1 if no echo found


def ensure_setup_helper_command(
    document: ManifestDocument,
    *,
    layout: str = "top",
    enable_debug: bool = False,
    resolver_paths: Optional[list[str]] = None,
    working_dir: Optional[str] = None,
) -> OperationResult:
    """Ensure lotti module calls setup-flutter.sh with appropriate parameters."""

    modules = document.ensure_modules()
    changed = False

    # Build the command
    command = _build_setup_helper_command(
        layout, enable_debug, resolver_paths, working_dir
    )

    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue

        # Find appropriate position
        commands = module.get("build-commands", [])
        position = _find_insertion_index(commands) if commands else 1

        # Update or add command
        if _update_lotti_build_commands(module, command, position):
            changed = True
        break

    if changed:
        document.mark_changed()
        message = f"Ensured setup helper command: {command}"
        _LOGGER.debug(message)
        return OperationResult.changed_result(message)
    return OperationResult.unchanged()


def _remove_lotti_flutter_git_sources(module: dict) -> bool:
    """Remove Flutter git sources from lotti module. Returns True if changed."""
    sources = module.get("sources", [])
    if not isinstance(sources, list):
        return False

    filtered = [
        source
        for source in sources
        if not (
            isinstance(source, dict)
            and source.get("type") == "git"
            and "flutter/flutter" in source.get("url", "")
        )
    ]

    if len(filtered) != len(sources):
        module["sources"] = filtered
        return True
    return False


def _process_lotti_module(
    module: dict, archive_path: str, sha256: str
) -> tuple[bool, list[str]]:
    """Process lotti module for app archive bundling."""
    messages = []
    changed = False

    sources = module.get("sources", [])
    if not isinstance(sources, list):
        sources = []

    # Remove any Flutter git sources from lotti
    if _remove_lotti_flutter_git_sources(module):
        messages.append("Removed Flutter git source from lotti")
        sources = module.get("sources", [])
        changed = True

    # Check for existing app archive
    has_app_archive = any(
        isinstance(src, dict)
        and src.get("type") == "file"
        and src.get("path") == archive_path
        for src in sources
    )

    if not has_app_archive:
        # Add app archive as first source
        app_source = {
            "type": "file",
            "path": archive_path,
            "sha256": sha256,
        }
        sources.insert(0, app_source)
        module["sources"] = sources
        messages.append(f"Added app archive {archive_path}")
        changed = True

    # Check for other required sources
    required_sources = [
        ("pubspec-sources.json", "pubspec dependencies"),
        ("cargo-sources.json", "Rust cargo dependencies"),
    ]

    for source_file, desc in required_sources:
        has_source = any(
            (isinstance(src, str) and src == source_file)
            or (isinstance(src, dict) and src.get("path") == source_file)
            for src in sources
        )
        if not has_source:
            _LOGGER.warning(f"Missing {source_file} for {desc}")

    return changed, messages


def bundle_app_archive(
    document: ManifestDocument,
    *,
    archive_path: str,
    sha256: str,
) -> OperationResult:
    """Bundle app source as local archive and update manifest."""

    modules = document.ensure_modules()
    changed = False
    messages = []

    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue

        module_changed, module_messages = _process_lotti_module(
            module, archive_path, sha256
        )
        if module_changed:
            changed = True
            messages.extend(module_messages)
        break

    if changed:
        document.mark_changed()
        message = "Bundled app archive and updated manifest"
        _LOGGER.debug(message)
        return OperationResult(changed, messages)

    return OperationResult.unchanged()
