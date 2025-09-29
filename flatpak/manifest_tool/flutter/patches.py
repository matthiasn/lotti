"""Offline build patches for Flutter applications."""

from __future__ import annotations

from pathlib import Path
from textwrap import dedent

try:  # pragma: no cover
    from ..core import ManifestDocument, OperationResult, get_logger
except ImportError:  # pragma: no cover
    import sys

    sys.path.insert(0, str(Path(__file__).parent.parent))
    from core import ManifestDocument, OperationResult, get_logger  # type: ignore

_LOGGER = get_logger("flutter.patches")


def _create_sqlite_patch_command() -> str:
    """Create the SQLite CMakeLists.txt patch command."""
    return (
        dedent(
            """python3 - <<'PY'
import pathlib

base = pathlib.Path('.pub-cache/hosted/pub.dev')
target = next(base.glob('sqlite3_flutter_libs-*/linux/CMakeLists.txt'), None)
if target is None:
    raise SystemExit('sqlite3_flutter_libs linux/CMakeLists.txt not found')
content = target.read_text()
needle = 'URL_HASH SHA256=a3db587a1b92ee5ddac2f66b3edb41b26f9c867275782d46c3a088977d6a5b18'
if needle not in content:
    new_content = content.replace(
        'DOWNLOAD_EXTRACT_TIMESTAMP NEW',
        'URL_HASH SHA256=a3db587a1b92ee5ddac2f66b3edb41b26f9c867275782d46c3a088977d6a5b18\\n    DOWNLOAD_EXTRACT_TIMESTAMP NEW'
    )
    # Also handle the older CMake version without DOWNLOAD_EXTRACT_TIMESTAMP
    if 'DOWNLOAD_EXTRACT_TIMESTAMP' not in content:
        new_content = content.replace(
            'URL https://sqlite.org/2025/sqlite-autoconf-3500400.tar.gz',
            'URL https://sqlite.org/2025/sqlite-autoconf-3500400.tar.gz\\n    URL_HASH SHA256=a3db587a1b92ee5ddac2f66b3edb41b26f9c867275782d46c3a088977d6a5b18'
        )
    target.write_text(new_content)
    print(f'Patched {target} for offline SQLite build')
PY"""
        ).strip()
        + "\n"
    )


def add_cmake_offline_patches(document: ManifestDocument) -> OperationResult:
    """Add patches for CMake-based plugins to work offline.

    This adds inline patch commands to modify CMakeLists.txt files
    for plugins like sqlite3_flutter_libs that use CMake FetchContent.

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

        commands = module.setdefault("build-commands", [])
        patch_cmd = _create_sqlite_patch_command()

        # Check if patch command already exists
        if patch_cmd not in commands:
            # Find insertion point - before flutter build commands
            insert_index = 0
            for i, cmd in enumerate(commands):
                if "flutter build" in cmd or "flutter pub get" in cmd:
                    insert_index = i
                    break
            else:
                insert_index = len(commands)

            commands.insert(insert_index, patch_cmd)
            module["build-commands"] = commands
            messages.append("Added SQLite offline patch command")
            changed = True

        break

    if changed:
        document.mark_changed()
        return OperationResult.changed_result("; ".join(messages))
    return OperationResult.unchanged()


def _create_cargokit_patch_command() -> str:
    """Create the cargokit offline patch command."""
    return (
        dedent(
            """python3 - <<'PY'
import pathlib

base = pathlib.Path('.pub-cache/hosted/pub.dev')
patched = False
# Try both one and two levels deep as package structures may vary
for pattern in ['*/cargokit/run_build_tool.sh', '*/*/cargokit/run_build_tool.sh']:
    for script in base.glob(pattern):
        text = script.read_text()
        if 'pub get --offline --no-precompile' in text:
            print(f'{script} already patched')
            continue
        new_text = text.replace(
            'pub get --no-precompile',
            'pub get --offline --no-precompile'
        )
        if new_text != text:
            script.write_text(new_text)
            print(f'Patched {script} for offline pub get')
            patched = True
if not patched:
    print('No cargokit scripts needed patching')
PY"""
        ).strip()
        + "\n"
    )


def _create_cargo_config_command() -> str:
    """Create the cargo vendor config command."""
    return (
        dedent(
            """mkdir -p "$CARGO_HOME" && cat > "$CARGO_HOME/config" <<'CARGO_CFG'
[source.vendored-sources]
directory = "/run/build/lotti/cargo/vendor"

[source.crates-io]
replace-with = "vendored-sources"

[source."https://github.com/knopp/mime_guess"]
git = "https://github.com/knopp/mime_guess"
replace-with = "vendored-sources"

[net]
offline = true
CARGO_CFG"""
        ).strip()
        + "\n"
    )


def add_cargokit_offline_patches(document: ManifestDocument) -> OperationResult:
    """Add patches for Rust-based plugins to build offline.

    This adds inline patch commands for cargokit and cargo configuration
    to work in offline mode for plugins that use the cargokit build system.

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

        commands = module.setdefault("build-commands", [])

        # Add cargokit patch command
        cargokit_cmd = _create_cargokit_patch_command()
        if cargokit_cmd not in commands:
            # Find insertion point
            insert_index = 0
            for i, cmd in enumerate(commands):
                if "flutter build" in cmd or "flutter pub get" in cmd:
                    insert_index = i
                    break
            else:
                insert_index = len(commands)

            commands.insert(insert_index, cargokit_cmd)
            messages.append("Added cargokit offline patch command")
            changed = True

        # Add cargo config command
        cargo_config_cmd = _create_cargo_config_command()
        if cargo_config_cmd not in commands:
            # Find insertion point
            insert_index = 0
            for i, cmd in enumerate(commands):
                if "flutter build" in cmd or "flutter pub get" in cmd:
                    insert_index = i
                    break
            else:
                insert_index = len(commands)

            commands.insert(insert_index, cargo_config_cmd)
            messages.append("Added cargo config command")
            changed = True

        if changed:
            module["build-commands"] = commands

        break

    if changed:
        document.mark_changed()
        return OperationResult.changed_result("; ".join(messages))
    return OperationResult.unchanged()


def add_offline_build_patches(document: ManifestDocument) -> OperationResult:
    """Add comprehensive offline build patches to the lotti module.

    This adds patches and configurations to ensure the build works offline:
    1. Configures CMake-based plugins to use local sources
    2. Configures Rust/cargo to build in offline mode
    3. Adds necessary patch files to redirect network fetches

    Args:
        document: The manifest document to modify

    Returns:
        OperationResult with combined results from all patch operations
    """
    results = []

    # Add CMake offline patches (for sqlite3_flutter_libs, etc)
    cmake_result = add_cmake_offline_patches(document)
    if cmake_result.changed:
        results.append(cmake_result)

    # Add cargo/Rust offline patches (for cargokit-based plugins)
    cargo_result = add_cargokit_offline_patches(document)
    if cargo_result.changed:
        results.append(cargo_result)

    if results:
        all_messages = []
        for r in results:
            all_messages.extend(r.messages)
        return OperationResult(changed=True, messages=all_messages)

    return OperationResult.unchanged()
