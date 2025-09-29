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


def _update_append_path(build_options: dict, rust_bin: str, rustup_bin: str) -> bool:
    """Update append-path to include Rust paths."""
    append_path = build_options.get("append-path", "")
    paths = [p for p in append_path.split(":") if p]

    changed = False
    if rust_bin not in paths:
        paths.insert(0, rust_bin)
        changed = True
    if rustup_bin not in paths:
        paths.insert(1, rustup_bin)
        changed = True

    if changed:
        build_options["append-path"] = ":".join(paths)
    return changed


def _update_env_path(env: dict, rust_bin: str, rustup_bin: str) -> bool:
    """Update PATH environment variable to include Rust paths."""
    current_path = env.get("PATH", "")
    paths = [p for p in current_path.split(":") if p]

    changed = False
    if rust_bin not in paths:
        paths.insert(0, rust_bin)
        changed = True
    if rustup_bin not in paths:
        paths.insert(1, rustup_bin)
        changed = True

    if changed:
        env["PATH"] = ":".join(paths)
    return changed


def _update_rustup_home(env: dict) -> bool:
    """Ensure RUSTUP_HOME is set."""
    if env.get("RUSTUP_HOME") != "/usr/lib/sdk/rust-stable":
        env["RUSTUP_HOME"] = "/usr/lib/sdk/rust-stable"
        return True
    return False


def ensure_rust_sdk_env(document: ManifestDocument) -> OperationResult:
    """Ensure Rust SDK environment is properly configured.

    Sets up PATH and RUSTUP_HOME for Rust SDK extension usage.

    Args:
        document: The manifest document to modify

    Returns:
        OperationResult indicating if changes were made
    """
    modules = document.ensure_modules()
    changed = False
    messages = []

    rust_bin = "/usr/lib/sdk/rust-stable/bin"
    rustup_bin = "/run/build/lotti/.cargo/bin"

    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue

        build_options = module.setdefault("build-options", {})

        # Update append-path
        if _update_append_path(build_options, rust_bin, rustup_bin):
            messages.append(f"Added Rust paths to append-path")
            changed = True

        # Update env
        env = build_options.setdefault("env", {})

        # Update PATH
        if _update_env_path(env, rust_bin, rustup_bin):
            messages.append("Updated PATH with Rust SDK paths")
            changed = True

        # Set RUSTUP_HOME
        if _update_rustup_home(env):
            messages.append("Set RUSTUP_HOME to /usr/lib/sdk/rust-stable")
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
