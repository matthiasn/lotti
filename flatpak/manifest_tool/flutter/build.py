"""Flutter build command operations."""

from __future__ import annotations

from pathlib import Path

try:  # pragma: no cover
    from ..core import ManifestDocument, OperationResult, get_logger
except ImportError:  # pragma: no cover
    import sys

    sys.path.insert(0, str(Path(__file__).parent.parent))
    from core import ManifestDocument, OperationResult, get_logger  # type: ignore

_LOGGER = get_logger("flutter.build")


def ensure_flutter_pub_get_offline(document: ManifestDocument) -> OperationResult:
    """Ensure flutter pub get commands use --offline flag for Flathub compliance.

    Flathub builds have no network access, so pub get must run in offline mode.
    The --offline flag ensures Flutter uses only locally cached packages.

    Args:
        document: The manifest document to modify

    Returns:
        OperationResult with details of changes made
    """
    modules = document.ensure_modules()
    changed = False
    messages = []

    for module in modules:
        if not isinstance(module, dict):
            continue

        module_name = module.get("name", "")
        build_commands = module.get("build-commands", [])

        for i, cmd in enumerate(build_commands):
            if not isinstance(cmd, str):
                continue

            # Handle flutter pub get commands - only pub get supports --offline flag
            # (flutter build has --no-pub instead)
            if "flutter pub get" in cmd and "--offline" not in cmd:
                build_commands[i] = cmd.replace(
                    "flutter pub get", "flutter pub get --offline"
                )
                messages.append(
                    f"Added --offline flag to flutter pub get in {module_name}"
                )
                changed = True

    if changed:
        document.mark_changed()
        message = "Ensured flutter pub get uses --offline mode"
        _LOGGER.debug(message)
        return OperationResult(changed, messages)

    return OperationResult.unchanged()


def ensure_dart_pub_offline_in_build(document: ManifestDocument) -> OperationResult:
    """Add --no-pub flag to flutter build to skip internal dart pub get.

    Flutter build internally calls 'dart pub get --example' which tries to
    access the network. The --no-pub flag skips this automatic pub get,
    since dependencies were already resolved by our explicit flutter pub get --offline.

    Args:
        document: The manifest document to modify

    Returns:
        OperationResult with details of changes made
    """
    modules = document.ensure_modules()
    changed = False
    messages = []

    for module in modules:
        if not isinstance(module, dict):
            continue

        # Only modify the lotti module
        if module.get("name") != "lotti":
            continue

        build_commands = module.get("build-commands", [])

        for i, cmd in enumerate(build_commands):
            if not isinstance(cmd, str):
                continue

            # Find flutter build linux commands without --no-pub flag
            if "flutter build linux" in cmd and "--no-pub" not in cmd:
                # Add --no-pub flag to skip automatic pub get
                build_commands[i] = cmd.replace(
                    "flutter build linux", "flutter build linux --no-pub"
                )
                messages.append(
                    "Added --no-pub flag to skip automatic pub get during build"
                )
                changed = True

    if changed:
        document.mark_changed()
        message = "Configured flutter build to skip automatic pub get"
        _LOGGER.debug(message)
        return OperationResult(changed, messages)

    return OperationResult.unchanged()


def remove_flutter_config_command(document: ManifestDocument) -> OperationResult:
    """Remove flutter config commands from lotti build-commands.

    Flutter config commands modify global state and should not be used
    during Flathub builds.

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

        commands = module.get("build-commands")
        if not isinstance(commands, list):
            continue

        filtered: list[str] = []
        for raw in commands:
            command = str(raw)
            if "flutter config" in command:
                changed = True
                continue
            filtered.append(command)

        if changed:
            module["build-commands"] = filtered
        break

    if changed:
        document.mark_changed()
        message = "Removed flutter config command from lotti build steps"
        _LOGGER.debug(message)
        return OperationResult.changed_result(message)
    return OperationResult.unchanged()


def remove_network_from_build_args(document: ManifestDocument) -> OperationResult:
    """Remove --share=network from build-args sections."""

    modules = document.ensure_modules()
    changed = False
    messages = []

    for module in modules:
        if not isinstance(module, dict):
            continue

        build_options = module.get("build-options")
        if not isinstance(build_options, dict):
            continue

        build_args = build_options.get("build-args")
        if not isinstance(build_args, list):
            continue

        # Filter out --share=network
        filtered = [arg for arg in build_args if arg != "--share=network"]
        if len(filtered) != len(build_args):
            module_name = module.get("name", "unnamed")
            messages.append(f"Removed --share=network from {module_name}")
            changed = True

            # Update or remove build-args based on filtered content
            if filtered:
                build_options["build-args"] = filtered
            else:
                # Remove empty build-args
                build_options.pop("build-args", None)

                # Remove build-options if it becomes empty
                if not build_options:
                    module.pop("build-options", None)

    if changed:
        document.mark_changed()
        message = "Removed network access from build arguments"
        _LOGGER.debug(message)
        return OperationResult(changed, messages)

    return OperationResult.unchanged()


def _split_path(value: str | None) -> list[str]:
    """Split a PATH-style string into a list of entries.

    Args:
        value: A colon-separated PATH string or None

    Returns:
        List of non-empty path entries
    """
    if not value:
        return []
    return [entry for entry in value.split(":") if entry]


def normalize_lotti_env(
    document: ManifestDocument,
    *,
    flutter_bin: str,
    ensure_append_path: bool,
) -> OperationResult:
    """Ensure lotti build-options PATH settings include ``flutter_bin``."""

    modules = document.ensure_modules()
    changed = False
    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue
        build_options = module.setdefault("build-options", {})
        if ensure_append_path:
            append_current = build_options.get("append-path", "")
            append_entries = _split_path(append_current)
            if flutter_bin not in append_entries:
                append_entries.insert(0, flutter_bin)
                build_options["append-path"] = ":".join(append_entries)
                changed = True
        else:
            env = build_options.setdefault("env", {})
            path_current = env.get("PATH", "")
            path_entries = _split_path(path_current)
            if flutter_bin not in path_entries:
                path_entries.insert(0, flutter_bin)
                env["PATH"] = ":".join(path_entries)
                changed = True
        break

    if changed:
        document.mark_changed()
        message = f"Ensured lotti PATH includes {flutter_bin}"
        _LOGGER.debug(message)
        return OperationResult.changed_result(message)
    return OperationResult.unchanged()
