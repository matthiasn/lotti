"""Offline build fixes for Flutter applications."""

from __future__ import annotations

from pathlib import Path
from typing import Any, Callable, Iterable, Optional, Tuple

try:  # pragma: no cover
    from ..core import ManifestDocument, OperationResult, get_logger
except ImportError:  # pragma: no cover
    import sys

    sys.path.insert(0, str(Path(__file__).parent.parent))
    from core import ManifestDocument, OperationResult, get_logger  # type: ignore

_LOGGER = get_logger("flutter.offline_fixes")


def remove_setup_flutter_command(document: ManifestDocument) -> OperationResult:
    """Remove setup-flutter.sh command from lotti build commands.

    The setup-flutter.sh script causes offline build failures by trying to
    download the Dart SDK. The flutter-sdk module already handles all setup.

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
            continue

        # Remove any setup-flutter.sh commands
        filtered_commands = []
        for cmd in commands:
            if isinstance(cmd, str) and "setup-flutter.sh" in cmd:
                messages.append(f"Removed command: {cmd}")
                changed = True
            else:
                filtered_commands.append(cmd)

        if changed:
            module["build-commands"] = filtered_commands
        break

    if changed:
        document.mark_changed()
        return OperationResult.changed_result("; ".join(messages))
    return OperationResult.unchanged()


def _has_rustup_module(modules: Iterable[Any]) -> bool:
    """Return True if the manifest references a rustup module."""

    for module in modules:
        if isinstance(module, str) and "rustup" in module:
            return True
        if isinstance(module, dict) and module.get("name") == "rustup":
            return True
    return False


def _get_lotti_module(modules: Iterable[Any]) -> Optional[dict]:
    """Return the lotti module dictionary if present."""

    for module in modules:
        if isinstance(module, dict) and module.get("name") == "lotti":
            return module
    return None


def _ensure_rustup_env(env: dict) -> Tuple[bool, list[str]]:
    """Ensure PATH and RUSTUP_HOME environment variables are configured."""

    messages: list[str] = []
    changed = False

    path_value = env.get("PATH")
    if isinstance(path_value, str) and "/var/lib/rustup/bin" not in path_value:
        env["PATH"] = f"/var/lib/rustup/bin:{path_value}"
        messages.append("Added /var/lib/rustup/bin to PATH")
        changed = True

    rustup_home = env.get("RUSTUP_HOME")
    if rustup_home != "/var/lib/rustup":
        env["RUSTUP_HOME"] = "/var/lib/rustup"
        if rustup_home is None:
            messages.append("Set RUSTUP_HOME to /var/lib/rustup")
        else:
            messages.append("Fixed RUSTUP_HOME to /var/lib/rustup")
        changed = True

    return changed, messages


def _ensure_rustup_append_path(build_options: dict) -> Tuple[bool, list[str]]:
    """Ensure append-path includes rustup bin when the field exists."""

    append_value = build_options.get("append-path")
    if not isinstance(append_value, str) or "/var/lib/rustup/bin" in append_value:
        return False, []

    build_options["append-path"] = f"/var/lib/rustup/bin:{append_value}"
    return True, ["Added /var/lib/rustup/bin to append-path"]


def ensure_rustup_in_path(document: ManifestDocument) -> OperationResult:
    """Ensure rustup is in PATH and RUSTUP_HOME is set correctly.

    If rustup module is present:
    - Add /var/lib/rustup/bin to PATH
    - Set RUSTUP_HOME to /var/lib/rustup (not /usr/lib/sdk/rust-stable)

    Args:
        document: The manifest document to modify

    Returns:
        OperationResult with details of changes made
    """
    modules = document.ensure_modules()
    if not _has_rustup_module(modules):
        return OperationResult.unchanged()

    module = _get_lotti_module(modules)
    if not module or not isinstance(module, dict):
        return OperationResult.unchanged()

    messages: list[str] = []
    changed = False

    build_options = module.get("build-options", {})
    if isinstance(build_options, dict):
        env = build_options.get("env", {})
        if isinstance(env, dict):
            env_changed, env_messages = _ensure_rustup_env(env)
            if env_changed:
                changed = True
                messages.extend(env_messages)

        append_changed, append_messages = _ensure_rustup_append_path(build_options)
        if append_changed:
            changed = True
            messages.extend(append_messages)

    if changed:
        document.mark_changed()
        return OperationResult.changed_result("; ".join(messages))
    return OperationResult.unchanged()


def _fix_flutter_commands(commands: list[Any]) -> Tuple[bool, list[str]]:
    """Replace /app/flutter references inside command list."""

    changed = False
    messages: list[str] = []

    for index, command in enumerate(commands):
        if not isinstance(command, str):
            continue
        if "/app/flutter" in command and "/var/lib/flutter" not in command:
            commands[index] = command.replace("/app/flutter", "/var/lib/flutter")
            messages.append(f"Fixed path in command: {command[:50]}...")
            changed = True

    return changed, messages


def _dedupe_path_entries(value: str) -> str:
    """Remove duplicate path entries while preserving order."""

    parts = value.split(":")
    seen = set()
    deduped: list[str] = []
    for part in parts:
        if part and part not in seen:
            seen.add(part)
            deduped.append(part)
    return ":".join(deduped)


def _fix_flutter_env(env: dict) -> Tuple[bool, list[str]]:
    """Adjust PATH variables inside env to point at /var/lib/flutter."""

    changed = False
    messages: list[str] = []

    path_value = env.get("PATH")
    if isinstance(path_value, str) and "/app/flutter/bin" in path_value:
        new_path = path_value.replace("/app/flutter/bin", "/var/lib/flutter/bin")
        env["PATH"] = _dedupe_path_entries(new_path)
        messages.append("Fixed PATH environment variable")
        changed = True

    return changed, messages


def _fix_append_path(build_options: dict) -> Tuple[bool, list[str]]:
    """Fix append-path entry if it refers to /app/flutter/bin."""

    append_value = build_options.get("append-path")
    if not isinstance(append_value, str) or "/app/flutter/bin" not in append_value:
        return False, []

    build_options["append-path"] = append_value.replace("/app/flutter/bin", "/var/lib/flutter/bin")
    return True, ["Fixed append-path"]


def _merge_env_path_into_append(build_options: dict) -> Tuple[bool, list[str]]:
    """Move PATH entries into append-path to avoid duplicating path handling."""

    messages: list[str] = []
    changed = False

    env = build_options.get("env", {})
    if not isinstance(env, dict):
        return False, []

    env_path = env.pop("PATH", None)
    append_value = build_options.get("append-path", "")

    if env_path:
        # Combine env PATH + existing append-path, preserving order and deduping
        combined = _dedupe_path_entries(f"{env_path}:{append_value}" if append_value else env_path)
        build_options["append-path"] = combined
        messages.append("Moved PATH entries into append-path")
        changed = True

    return changed, messages


def _ensure_build_commands(module: dict) -> list:
    """Ensure the module exposes a mutable build command list."""

    commands = module.get("build-commands")
    if isinstance(commands, list):
        return commands
    module["build-commands"] = []
    return module["build-commands"]


def _command_exists(commands: Iterable[Any], predicate: Callable[[str], bool]) -> bool:
    """Return True if any command matches ``predicate``."""

    for cmd in commands:
        if isinstance(cmd, str) and predicate(cmd):
            return True
    return False


def _determine_insert_position(commands: list[Any]) -> int:
    """Choose insertion index for cargo helper commands."""

    for index, cmd in enumerate(commands):
        if isinstance(cmd, str) and "Building Lotti from source" in cmd:
            return index + 1
    return min(len(commands), 3)


def _ensure_cargo_home(env: dict) -> Tuple[bool, list[str]]:
    """Set CARGO_HOME to the expected build directory."""

    if env.get("CARGO_HOME") == "/run/build/lotti/.cargo":
        return False, []

    env["CARGO_HOME"] = "/run/build/lotti/.cargo"
    return True, ["Set CARGO_HOME to /run/build/lotti/.cargo"]


def _ensure_cargo_commands(commands: list[Any]) -> Tuple[bool, list[str]]:
    """Insert helper commands to make cargo config available."""

    changed = False
    messages: list[str] = []
    insert_pos = _determine_insert_position(commands)

    command_plan = [
        (
            lambda cmd: "mkdir -p .cargo" in cmd,
            "mkdir -p .cargo",
            "Ensured .cargo directory exists",
        ),
        (
            # Link the vendored cargo directory into CARGO_HOME
            lambda cmd: "ln -sfn" in cmd and ".cargo/cargo" in cmd,
            "ln -sfn ../cargo .cargo/cargo",
            "Linked cargo vendor directory into CARGO_HOME",
        ),
        (
            lambda cmd: "cp cargo/config .cargo/config" in cmd,
            "cp cargo/config .cargo/config.toml 2>/dev/null || true",
            "Added cargo config copy command",
        ),
    ]

    for predicate, command, message in command_plan:
        if _command_exists(commands, predicate):
            continue
        commands.insert(insert_pos, command)
        insert_pos += 1
        messages.append(message)
        changed = True

    return changed, messages


def fix_flutter_sdk_paths(document: ManifestDocument) -> OperationResult:
    """Fix Flutter SDK paths to use /var/lib/flutter instead of /app/flutter.

    The flutter-sdk module installs to /var/lib/flutter, not /app/flutter.
    This fixes the paths in build commands and environment variables.

    Args:
        document: The manifest document to modify

    Returns:
        OperationResult with details of changes made
    """
    modules = document.ensure_modules()
    module = _get_lotti_module(modules)
    if not module:
        return OperationResult.unchanged()

    changed = False
    messages: list[str] = []

    commands = module.get("build-commands", [])
    if isinstance(commands, list):
        cmd_changed, cmd_messages = _fix_flutter_commands(commands)
        if cmd_changed:
            changed = True
            messages.extend(cmd_messages)

    build_options = module.get("build-options", {})
    if isinstance(build_options, dict):
        env = build_options.get("env", {})
        if isinstance(env, dict):
            env_changed, env_messages = _fix_flutter_env(env)
            if env_changed:
                changed = True
                messages.extend(env_messages)

        append_changed, append_messages = _fix_append_path(build_options)
        if append_changed:
            changed = True
            messages.extend(append_messages)

    if changed:
        document.mark_changed()
        return OperationResult.changed_result("; ".join(messages))
    return OperationResult.unchanged()


def remove_flutter_sdk_source(document: ManifestDocument) -> OperationResult:
    """Remove setup-flutter.sh source from flutter-sdk module.

    The setup-flutter.sh file reference is not needed and causes issues.

    Args:
        document: The manifest document to modify

    Returns:
        OperationResult with details of changes made
    """
    modules = document.ensure_modules()
    changed = False
    messages = []

    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "flutter-sdk":
            continue

        sources = module.get("sources", [])
        if not isinstance(sources, list):
            continue

        # Remove setup-flutter.sh source
        filtered_sources = []
        for source in sources:
            if isinstance(source, dict) and source.get("dest-filename") == "setup-flutter.sh":
                messages.append("Removed setup-flutter.sh source from flutter-sdk")
                changed = True
            else:
                filtered_sources.append(source)

        if changed:
            module["sources"] = filtered_sources
        break

    if changed:
        document.mark_changed()
        return OperationResult.changed_result("; ".join(messages))
    return OperationResult.unchanged()


def ensure_cargo_config_in_place(document: ManifestDocument) -> OperationResult:
    """Ensure cargo vendor config is accessible to cargo.

    The cargo-sources.json places config at cargo/config, but cargo needs it
    at .cargo/config.toml. Since cargo runs from plugin subdirectories, we need
    to ensure CARGO_HOME points to the main build directory where the config is.

    Args:
        document: The manifest document to modify

    Returns:
        OperationResult with details of changes made
    """
    modules = document.ensure_modules()
    module = _get_lotti_module(modules)
    if not module:
        return OperationResult.unchanged()

    messages: list[str] = []
    changed = False

    build_options = module.setdefault("build-options", {})
    env = build_options.setdefault("env", {})
    home_changed, home_messages = _ensure_cargo_home(env)
    if home_changed:
        changed = True
        messages.extend(home_messages)

    commands = _ensure_build_commands(module)
    command_changed, command_messages = _ensure_cargo_commands(commands)
    if command_changed:
        changed = True
        messages.extend(command_messages)

    if changed:
        document.mark_changed()
        return OperationResult.changed_result("; ".join(messages))
    return OperationResult.unchanged()


def apply_all_offline_fixes(document: ManifestDocument) -> OperationResult:
    """Apply all offline build fixes to the manifest.

    This includes:
    1. Removing setup-flutter.sh commands and sources
    2. Fixing Flutter SDK paths
    3. Adding cargokit patches and cargo config

    Args:
        document: The manifest document to modify

    Returns:
        OperationResult with combined results
    """
    # Import patches module for cargokit fixes
    from . import patches

    results = []

    # Remove setup-flutter.sh command from lotti
    result = remove_setup_flutter_command(document)
    if result.changed:
        results.append(result)

    # Fix Flutter SDK paths
    result = fix_flutter_sdk_paths(document)
    if result.changed:
        results.append(result)

    # Remove setup-flutter.sh source from flutter-sdk
    result = remove_flutter_sdk_source(document)
    if result.changed:
        results.append(result)

    # Add cargokit patches and cargo config
    result = patches.add_cargokit_offline_patches(document)
    if result.changed:
        results.append(result)

    # Ensure rustup is in PATH if rustup module is present
    result = ensure_rustup_in_path(document)
    if result.changed:
        results.append(result)

    # Ensure cargo config is in the right place
    result = ensure_cargo_config_in_place(document)
    if result.changed:
        results.append(result)

    # Move PATH into append-path for deterministic path handling
    modules = document.ensure_modules()
    lotti = _get_lotti_module(modules)
    if lotti and isinstance(lotti, dict):
        build_options = lotti.setdefault("build-options", {})
        merged, merge_messages = _merge_env_path_into_append(build_options)
        if merged:
            results.append(OperationResult.changed_result("; ".join(merge_messages)))
            document.mark_changed()

    if results:
        all_messages = []
        for r in results:
            all_messages.extend(r.messages)
        return OperationResult(changed=True, messages=all_messages)

    return OperationResult.unchanged()
