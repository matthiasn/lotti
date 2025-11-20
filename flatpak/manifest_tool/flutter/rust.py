"""Rust SDK and environment configuration for Flutter."""

from __future__ import annotations

from pathlib import Path

try:  # pragma: no cover
    from ..core import ManifestDocument, OperationResult, get_logger
except ImportError:  # pragma: no cover
    import sys

    sys.path.insert(0, str(Path(__file__).parent.parent))
    from core import ManifestDocument, OperationResult, get_logger  # type: ignore

_LOGGER = get_logger("flutter.rust")


def _normalize_paths(values: list[str], rust_bin: str) -> list[str]:
    """Ensure rust bin is present and remove rustup shims."""
    cleaned: list[str] = []
    for value in values:
        if not value or value == "/run/build/lotti/.cargo/bin":
            continue
        if value not in cleaned:
            cleaned.append(value)
    if rust_bin not in cleaned:
        cleaned.insert(0, rust_bin)
    return cleaned


def _update_append_path(build_options: dict, rust_bin: str) -> bool:
    """Update append-path to include Rust SDK path and drop rustup shims."""
    append_path = build_options.get("append-path", "")
    paths = _normalize_paths(append_path.split(":"), rust_bin)
    new_value = ":".join(paths)
    if new_value != append_path:
        build_options["append-path"] = new_value
        return True
    return False


def _update_env_path(env: dict, rust_bin: str) -> bool:
    """Update PATH environment variable to include Rust SDK path and drop rustup shims."""
    current_path = env.get("PATH", "")
    paths = _normalize_paths(current_path.split(":"), rust_bin)
    new_value = ":".join(paths)
    if new_value != current_path:
        env["PATH"] = new_value
        return True
    return False


def ensure_rust_sdk_env(document: ManifestDocument) -> OperationResult:
    """Ensure Rust SDK environment is properly configured.

    Sets up PATH for Rust SDK extension usage (without bundling rustup).

    Args:
        document: The manifest document to modify

    Returns:
        OperationResult indicating if changes were made
    """
    modules = document.ensure_modules()
    changed = False
    messages = []

    rust_bin = "/usr/lib/sdk/rust-stable/bin"

    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue

        build_options = module.setdefault("build-options", {})

        # Update append-path
        if _update_append_path(build_options, rust_bin):
            messages.append("Added Rust SDK path to append-path")
            changed = True

        # Update env
        env = build_options.setdefault("env", {})

        # Update PATH
        if _update_env_path(env, rust_bin):
            messages.append("Updated PATH with Rust SDK path")
            changed = True

        break

    if changed:
        document.mark_changed()
        message = "Configured Rust SDK environment"
        _LOGGER.debug(message)
        return OperationResult(changed, messages)

    return OperationResult.unchanged()


def _is_rustup_command(cmd: str) -> bool:
    """Check if a command is a rustup installation command."""
    return (
        "rustup.rs" in cmd
        or "rustup.sh" in cmd
        or "rustup-init" in cmd
        or ".cargo/bin" in cmd  # Also remove PATH exports for local cargo
    )


def _remove_rustup_from_module(module: dict) -> bool:
    """Remove rustup installation commands from a module."""
    commands = module.get("build-commands")
    if not isinstance(commands, list):
        return False

    filtered = [cmd for cmd in commands if not _is_rustup_command(str(cmd))]

    if len(filtered) != len(commands):
        module["build-commands"] = filtered
        return True
    return False


def remove_rustup_install(document: ManifestDocument) -> OperationResult:
    """Remove rustup installation from lotti build commands.

    Rustup is provided by the SDK extension, so we don't need to install it.

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

        if _remove_rustup_from_module(module):
            changed = True
        break

    if changed:
        document.mark_changed()
        message = "Removed rustup installation (using SDK extension instead)"
        _LOGGER.debug(message)
        return OperationResult.changed_result(message)

    return OperationResult.unchanged()
