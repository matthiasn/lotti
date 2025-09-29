"""Offline build fixes for Flutter applications."""

from __future__ import annotations

from pathlib import Path
from typing import Any

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
    changed = False
    messages = []

    # Check if rustup module exists
    has_rustup = any(
        isinstance(m, str)
        and "rustup" in m
        or isinstance(m, dict)
        and m.get("name") == "rustup"
        for m in modules
    )

    if not has_rustup:
        return OperationResult.unchanged()

    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue

        build_options = module.get("build-options", {})
        if isinstance(build_options, dict):
            env = build_options.get("env", {})
            if isinstance(env, dict):
                # Fix PATH
                if "PATH" in env:
                    path = env["PATH"]
                    if "/var/lib/rustup/bin" not in path:
                        # Add rustup bin to the beginning of PATH
                        env["PATH"] = f"/var/lib/rustup/bin:{path}"
                        messages.append("Added /var/lib/rustup/bin to PATH")
                        changed = True

                # Fix RUSTUP_HOME - must match where rustup was installed
                if "RUSTUP_HOME" in env and env["RUSTUP_HOME"] != "/var/lib/rustup":
                    env["RUSTUP_HOME"] = "/var/lib/rustup"
                    messages.append("Fixed RUSTUP_HOME to /var/lib/rustup")
                    changed = True
                elif "RUSTUP_HOME" not in env:
                    env["RUSTUP_HOME"] = "/var/lib/rustup"
                    messages.append("Set RUSTUP_HOME to /var/lib/rustup")
                    changed = True

            # Also update append-path
            if "append-path" in build_options:
                append_path = build_options["append-path"]
                if "/var/lib/rustup/bin" not in append_path:
                    # Add to the beginning of append-path
                    build_options["append-path"] = f"/var/lib/rustup/bin:{append_path}"
                    messages.append("Added /var/lib/rustup/bin to append-path")
                    changed = True
        break

    if changed:
        document.mark_changed()
        return OperationResult.changed_result("; ".join(messages))
    return OperationResult.unchanged()


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
    changed = False
    messages = []

    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue

        # Fix build commands
        commands = module.get("build-commands", [])
        if isinstance(commands, list):
            for i, cmd in enumerate(commands):
                if isinstance(cmd, str):
                    if "/app/flutter" in cmd and "/var/lib/flutter" not in cmd:
                        new_cmd = cmd.replace("/app/flutter", "/var/lib/flutter")
                        commands[i] = new_cmd
                        messages.append(f"Fixed path in command: {cmd[:50]}...")
                        changed = True

        # Fix build-options environment variables
        build_options = module.get("build-options", {})
        if isinstance(build_options, dict):
            env = build_options.get("env", {})
            if isinstance(env, dict):
                # Fix PATH
                if "PATH" in env:
                    old_path = env["PATH"]
                    if "/app/flutter/bin" in old_path:
                        # Replace /app/flutter/bin with /var/lib/flutter/bin
                        new_path = old_path.replace(
                            "/app/flutter/bin", "/var/lib/flutter/bin"
                        )
                        # Deduplicate if /var/lib/flutter/bin appears twice
                        path_parts = new_path.split(":")
                        seen = set()
                        deduped_parts = []
                        for part in path_parts:
                            if part not in seen:
                                seen.add(part)
                                deduped_parts.append(part)
                        env["PATH"] = ":".join(deduped_parts)
                        messages.append("Fixed PATH environment variable")
                        changed = True

            # Fix append-path
            if "append-path" in build_options:
                old_append = build_options["append-path"]
                if "/app/flutter/bin" in old_append:
                    build_options["append-path"] = old_append.replace(
                        "/app/flutter/bin", "/var/lib/flutter/bin"
                    )
                    messages.append("Fixed append-path")
                    changed = True
        break

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
            if (
                isinstance(source, dict)
                and source.get("dest-filename") == "setup-flutter.sh"
            ):
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

    if results:
        all_messages = []
        for r in results:
            all_messages.extend(r.messages)
        return OperationResult(changed=True, messages=all_messages)

    return OperationResult.unchanged()
