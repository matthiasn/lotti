"""Offline build patches for Flutter applications."""

from __future__ import annotations

from pathlib import Path

try:  # pragma: no cover
    from ..core import ManifestDocument, OperationResult, get_logger
except ImportError:  # pragma: no cover
    import sys

    sys.path.insert(0, str(Path(__file__).parent.parent))
    from core import ManifestDocument, OperationResult, get_logger  # type: ignore

_LOGGER = get_logger("flutter.patches")


def _create_sqlite_patch_command() -> str:
    """Create command to patch sqlite3_flutter_libs CMakeLists.txt.

    Note: This needs to be a shell command because the exact path to the
    sqlite3_flutter_libs package is not known until runtime - it depends on
    the package version downloaded by pub.
    """
    return (
        "find .pub-cache/hosted/pub.dev -name 'sqlite3_flutter_libs-*' -type d | "
        "while read dir; do "
        'if [ -f "$dir/linux/CMakeLists.txt" ]; then '
        "sed -i 's|FetchContent_Declare(|"
        'if(NOT EXISTS "${CMAKE_CURRENT_BINARY_DIR}/_deps/sqlite3-subbuild/sqlite3-populate-prefix/src/sqlite-autoconf-3500400.tar.gz")'
        '\\n    message(FATAL_ERROR "SQLite source not found. Expected at: '
        '${CMAKE_CURRENT_BINARY_DIR}/_deps/sqlite3-subbuild/sqlite3-populate-prefix/src/sqlite-autoconf-3500400.tar.gz")'
        "\\nendif()\\n"
        'FetchContent_Declare(|\' "$dir/linux/CMakeLists.txt"; '
        "sed -i 's|https://www.sqlite.org/[0-9]\\+/sqlite-autoconf-[0-9]\\+\\.tar\\.gz|"
        "file://${CMAKE_CURRENT_BINARY_DIR}/_deps/sqlite3-subbuild/sqlite3-populate-prefix/src/sqlite-autoconf-3500400.tar.gz|' "
        '"$dir/linux/CMakeLists.txt"; '
        "fi; done"
    )


def _create_cargokit_patch_command() -> str:
    """Create command to patch cargokit for offline builds."""
    return (
        "find .pub-cache/hosted/pub.dev -path '*/cargokit/run_build_tool.sh' | "
        "while read script; do "
        "sed -i 's/cargo build/cargo build --offline/' \"$script\"; "
        "done"
    )


def _create_cargo_config_command() -> str:
    """Create command to setup cargo config for offline mode."""
    return (
        "mkdir -p .cargo && "
        'echo "[net]" > .cargo/config.toml && '
        'echo "offline = true" >> .cargo/config.toml && '
        'echo "[http]" >> .cargo/config.toml && '
        'echo "max-retries = 0" >> .cargo/config.toml'
    )


def _get_offline_patch_commands() -> list[tuple[str, str]]:
    """Get all offline patch commands with descriptions."""
    return [
        ('echo "Patching SQLite for offline build..."', "status"),
        (_create_sqlite_patch_command(), "sqlite_patch"),
        ('echo "Patching cargokit for offline build..."', "status"),
        (_create_cargokit_patch_command(), "cargokit_patch"),
        ('echo "Setting up cargo for offline mode..."', "status"),
        (_create_cargo_config_command(), "cargo_config"),
    ]


def _remove_duplicate_patch_commands(
    commands: list, patch_commands: list[tuple[str, str]]
) -> list:
    """Remove existing patch commands that would be duplicated."""
    # Extract just the command strings from patch_commands
    patch_cmd_strings = [cmd for cmd, _ in patch_commands]

    # Filter out any existing commands that match our patch commands
    filtered = []
    for cmd in commands:
        cmd_str = str(cmd)
        # Check if this command is similar to any of our patch commands
        is_duplicate = any(
            [
                "sqlite3_flutter_libs" in cmd_str and "CMakeLists.txt" in cmd_str,
                "cargokit" in cmd_str and "run_build_tool.sh" in cmd_str,
                ".cargo/config.toml" in cmd_str and "offline = true" in cmd_str,
                "Patching SQLite for offline build" in cmd_str,
                "Patching cargokit for offline build" in cmd_str,
                "Setting up cargo for offline mode" in cmd_str,
            ]
        )
        # Also check for exact matches with any of our patch commands
        if not is_duplicate and cmd_str not in patch_cmd_strings:
            filtered.append(cmd)

    return filtered


def _find_flutter_build_index(commands: list) -> int:
    """Find the index of the flutter build command."""
    for i, cmd in enumerate(commands):
        if isinstance(cmd, str) and "flutter build linux" in cmd:
            return i
    return len(commands)  # Append at end if not found


def _insert_patch_commands(
    commands: list, patch_commands: list[tuple[str, str]], insert_index: int
) -> list:
    """Insert patch commands at the specified index."""
    result = commands[:insert_index]
    result.extend([cmd for cmd, _ in patch_commands])
    result.extend(commands[insert_index:])
    return result


def add_offline_build_patches(document: ManifestDocument) -> OperationResult:
    """Add comprehensive offline build patches to the lotti module.

    This adds several patches to ensure the build works offline:
    1. Patches sqlite3_flutter_libs CMakeLists.txt to use local SQLite source
    2. Patches cargokit to use cargo build --offline
    3. Sets up cargo config for offline mode

    Args:
        document: The manifest document to modify

    Returns:
        OperationResult with details of changes made
    """
    modules = document.ensure_modules()
    changed = False
    messages = []

    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue

        commands = module.get("build-commands", [])
        if not isinstance(commands, list):
            commands = []
            module["build-commands"] = commands

        # Get patch commands
        patch_commands = _get_offline_patch_commands()

        # Remove any existing similar commands
        commands = _remove_duplicate_patch_commands(commands, patch_commands)

        # Find where to insert (before flutter build)
        insert_index = _find_flutter_build_index(commands)

        # Insert patch commands
        new_commands = _insert_patch_commands(commands, patch_commands, insert_index)

        if new_commands != module.get("build-commands", []):
            module["build-commands"] = new_commands
            messages.append("Added offline build patches")
            changed = True

        break

    if changed:
        document.mark_changed()
        message = "Added comprehensive offline build patches"
        _LOGGER.debug(message)
        return OperationResult(changed, messages)

    return OperationResult.unchanged()
