"""Flutter-specific manifest operations."""

from __future__ import annotations

from pathlib import Path

try:  # pragma: no cover
    from . import utils
    from .manifest import ManifestDocument, OperationResult
except ImportError:  # pragma: no cover
    import utils  # type: ignore
    from manifest import ManifestDocument, OperationResult  # type: ignore

_LOGGER = utils.get_logger("flutter_ops")

_FALLBACK_COPY_SNIPPET = (
    "if [ -d /var/lib/flutter ]; then cp -r /var/lib/flutter {dst}; "
    "elif [ -d /app/flutter ]; then cp -r /app/flutter {dst}; "
    'else echo "No Flutter SDK found at /var/lib/flutter or /app/flutter"; exit 1; fi'
)

_CANONICAL_FLUTTER_URL = "https://github.com/flutter/flutter.git"


def _split_path(value: str | None) -> list[str]:
    if not value:
        return []
    return [entry for entry in value.split(":") if entry]


def _discover_flutter_jsons(output_dir: str | Path) -> list[str]:
    return sorted(
        candidate.name for candidate in Path(output_dir).glob("flutter-sdk-*.json")
    )


def ensure_nested_sdk(
    document: ManifestDocument,
    *,
    output_dir: str | Path,
) -> OperationResult:
    """Ensure nested flutter SDK JSON modules are referenced by lotti."""

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
    """Return ``True`` when offline flutter JSONs are present and referenced."""

    json_names = _discover_flutter_jsons(output_dir)
    if not json_names:
        return False

    modules = document.ensure_modules()
    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue
        referenced = [
            name for name in json_names if name in (module.get("modules") or [])
        ]
        return bool(referenced)
    return False


def _should_keep_flutter_command(command: str) -> bool:
    """Check if a Flutter SDK build command should be kept."""
    return command.startswith("mv flutter ") or command.startswith(
        "export PATH=/app/flutter/bin"
    )


def _normalize_single_flutter_module(module: dict) -> bool:
    """Normalize a single flutter-sdk module. Returns True if changed."""
    if not isinstance(module, dict) or module.get("name") != "flutter-sdk":
        return False

    commands = module.get("build-commands", [])
    if not isinstance(commands, list):
        commands = []

    # Filter commands keeping only mv and export PATH commands
    filtered = [str(cmd) for cmd in commands if _should_keep_flutter_command(str(cmd))]

    # Ensure at least one mv command exists
    if not any(cmd.startswith("mv flutter ") for cmd in filtered):
        filtered.insert(0, "mv flutter /app/flutter")

    if filtered != commands:
        module["build-commands"] = filtered
        return True
    return False


def normalize_flutter_sdk_module(document: ManifestDocument) -> OperationResult:
    """Strip Flutter invocations from flutter-sdk build commands."""
    modules = document.ensure_modules()
    changed = any(_normalize_single_flutter_module(module) for module in modules)

    if changed:
        document.mark_changed()
        message = "Normalized flutter-sdk build commands"
        _LOGGER.debug(message)
        return OperationResult.changed_result(message)
    return OperationResult.unchanged()


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
                append_entries.append(flutter_bin)
                build_options["append-path"] = (
                    ":".join(append_entries) if append_entries else flutter_bin
                )
                changed = True
        env = build_options.setdefault("env", {})
        path_current = env.get("PATH", "")
        path_entries = _split_path(path_current)
        if flutter_bin not in path_entries:
            path_entries.insert(0, flutter_bin)
            env["PATH"] = ":".join(path_entries)
            changed = True
    if changed:
        document.mark_changed()
        message = f"Normalized lotti PATH for {flutter_bin}"
        _LOGGER.debug(message)
        return OperationResult.changed_result(message)
    return OperationResult.unchanged()


# Note: ensure_lotti_network_share function removed
# --share=network in build-args is NOT allowed on Flathub infrastructure
# Network access during builds violates Flathub policy for security and reproducibility
# Builds must be completely offline with all dependencies pre-fetched


def ensure_flutter_pub_get_offline(document: ManifestDocument) -> OperationResult:
    """Ensure flutter pub get commands use --offline flag for Flathub compliance.

    Flathub builds have no network access, so pub get must run in offline mode.
    This function adds the --offline flag to flutter pub get commands.

    Note: flutter build does not support --offline flag. The internal dart pub get
    calls made by flutter build will need to be handled differently.
    """
    modules = document.ensure_modules()
    changed = False
    messages = []

    for module in modules:
        if not isinstance(module, dict):
            continue

        build_commands = module.get("build-commands", [])
        module_name = module.get("name", "unnamed")

        for i, cmd in enumerate(build_commands):
            if not isinstance(cmd, str):
                continue

            # Handle flutter pub get commands (only pub get supports --offline)
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


def add_sqlite3_source(document: ManifestDocument) -> OperationResult:
    """Add SQLite source for sqlite3_flutter_libs plugin.

    The sqlite3_flutter_libs plugin's CMake tries to download SQLite during configure.
    We pre-download it as a file that CMake will find and extract.
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

        # Ensure sources list exists
        if "sources" not in module:
            module["sources"] = []
        sources = module["sources"]

        # Check if SQLite file sources already exist for each architecture
        has_x64_sqlite = any(
            isinstance(src, dict)
            and src.get("type") == "file"
            and "x86_64" in src.get("only-arches", [])
            and src.get("dest")
            == "./build/linux/x64/release/_deps/sqlite3-subbuild/sqlite3-populate-prefix/src"
            and "3500400" in str(src.get("url", ""))
            for src in sources
        )
        has_arm64_sqlite = any(
            isinstance(src, dict)
            and src.get("type") == "file"
            and "aarch64" in src.get("only-arches", [])
            and src.get("dest")
            == "./build/linux/arm64/release/_deps/sqlite3-subbuild/sqlite3-populate-prefix/src"
            and "3500400" in str(src.get("url", ""))
            for src in sources
        )

        # Add SQLite file sources that CMake FetchContent will find
        if not has_x64_sqlite:
            sqlite_x64 = {
                "type": "file",
                "only-arches": ["x86_64"],
                "url": "https://www.sqlite.org/2025/sqlite-autoconf-3500400.tar.gz",
                "sha256": "a3db587a1b92ee5ddac2f66b3edb41b26f9c867275782d46c3a088977d6a5b18",
                "dest": "./build/linux/x64/release/_deps/sqlite3-subbuild/sqlite3-populate-prefix/src",
                "dest-filename": "sqlite-autoconf-3500400.tar.gz",
            }
            sources.append(sqlite_x64)
            messages.append("Added SQLite 3.50.4 file for x86_64")
            changed = True

        if not has_arm64_sqlite:
            sqlite_arm64 = {
                "type": "file",
                "only-arches": ["aarch64"],
                "url": "https://www.sqlite.org/2025/sqlite-autoconf-3500400.tar.gz",
                "sha256": "a3db587a1b92ee5ddac2f66b3edb41b26f9c867275782d46c3a088977d6a5b18",
                "dest": "./build/linux/arm64/release/_deps/sqlite3-subbuild/sqlite3-populate-prefix/src",
                "dest-filename": "sqlite-autoconf-3500400.tar.gz",
            }
            sources.append(sqlite_arm64)
            messages.append("Added SQLite 3.50.4 file for aarch64")
            changed = True

    if changed:
        document.mark_changed()
        message = "Updated SQLite sources for sqlite3_flutter_libs plugin"
        _LOGGER.debug(message)
        return OperationResult(changed, messages)

    return OperationResult.unchanged()


def add_media_kit_mimalloc_source(document: ManifestDocument) -> OperationResult:
    """Add mimalloc source for media_kit_libs_linux plugin.

    The media_kit plugin's CMake tries to download mimalloc during configure.
    We pre-download it and place it where CMake expects to find it.
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

        # Ensure sources list exists
        if "sources" not in module:
            module["sources"] = []
        sources = module["sources"]

        # Check if mimalloc source already exists
        has_mimalloc = any(
            isinstance(src, dict)
            and src.get("dest-filename") == "mimalloc-2.1.2.tar.gz"
            for src in sources
        )

        if not has_mimalloc:
            # Add mimalloc source
            mimalloc_source = {
                "type": "file",
                "url": "https://github.com/microsoft/mimalloc/archive/refs/tags/v2.1.2.tar.gz",
                "sha256": "2b1bff6f717f9725c70bf8d79e4786da13de8a270059e4ba0bdd262ae7be46eb",
                "dest-filename": "mimalloc-2.1.2.tar.gz",
            }
            sources.append(mimalloc_source)
            messages.append("Added mimalloc source for media_kit_libs_linux")
            changed = True

        # No need to add build commands to place the file
        # The bundle-archive-sources operation will modify the source entry
        # to use the 'dest' field which makes Flatpak place it directly
        # in the build directories before the build starts

    if changed:
        document.mark_changed()
        message = "Added mimalloc source for media_kit_libs_linux plugin"
        _LOGGER.debug(message)
        return OperationResult(changed, messages)

    return OperationResult.unchanged()


def remove_network_from_build_args(document: ManifestDocument) -> OperationResult:
    """Remove --share=network from build-args in all modules for Flathub compliance.

    Flathub strictly prohibits network access during builds. While the source
    manifest may include --share=network for local development convenience,
    it must be removed for Flathub submission.
    """
    modules = document.ensure_modules()
    changed = False
    messages = []

    for module in modules:
        if not isinstance(module, dict):
            continue

        build_options = module.get("build-options", {})
        build_args = build_options.get("build-args")

        if isinstance(build_args, list) and "--share=network" in build_args:
            # Remove all instances of --share=network
            while "--share=network" in build_args:
                build_args.remove("--share=network")

            # If build-args is now empty, remove it
            if not build_args:
                del build_options["build-args"]
                # If build-options is now empty, remove it
                if not build_options:
                    del module["build-options"]

            module_name = module.get("name", "unnamed")
            messages.append(f"Removed --share=network from {module_name}")
            changed = True

    if changed:
        document.mark_changed()
        message = "Removed network access from build-args for Flathub compliance"
        _LOGGER.debug(message)
        return OperationResult(changed, messages)

    return OperationResult.unchanged()


def _update_append_path(build_options: dict, rust_bin: str, rustup_bin: str) -> bool:
    """Update append-path with Rust SDK directories."""
    append_current = str(build_options.get("append-path", ""))
    append_entries = [e for e in append_current.split(":") if e]

    changed = False
    for entry in (rust_bin, rustup_bin):
        if entry not in append_entries:
            append_entries.append(entry)
            changed = True

    if changed:
        build_options["append-path"] = (
            ":".join(append_entries) if append_entries else rust_bin
        )

    return changed


def _update_env_path(env: dict, rust_bin: str, rustup_bin: str) -> bool:
    """Update env.PATH with Rust SDK directories in proper order."""
    path_current = str(env.get("PATH", ""))
    path_entries = [e for e in path_current.split(":") if e]

    # Remove existing entries and prepend in desired order
    original_len = len(path_entries)
    path_entries = [e for e in path_entries if e not in (rustup_bin, rust_bin)]
    path_entries = [rustup_bin, rust_bin] + path_entries

    if len(path_entries) != original_len or not env.get("PATH", "").startswith(
        rustup_bin
    ):
        env["PATH"] = ":".join(path_entries)
        return True
    return False


def _update_rustup_home(env: dict) -> bool:
    """Ensure RUSTUP_HOME is set for tool expectations."""
    if env.get("RUSTUP_HOME") != "/var/lib/rustup":
        env["RUSTUP_HOME"] = "/var/lib/rustup"
        return True
    return False


def ensure_rust_sdk_env(document: ManifestDocument) -> OperationResult:
    """Ensure /usr/lib/sdk/rust-stable/bin is available on PATH for lotti.

    This prefers the Rust SDK extension over rustup to avoid network access.
    """
    rust_bin = "/usr/lib/sdk/rust-stable/bin"
    rustup_bin = "/var/lib/rustup/bin"

    modules = document.ensure_modules()
    changed = False

    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue

        build_options = module.setdefault("build-options", {})

        # Update append-path
        if _update_append_path(build_options, rust_bin, rustup_bin):
            changed = True

        # Update env.PATH and RUSTUP_HOME
        env = build_options.setdefault("env", {})
        if _update_env_path(env, rust_bin, rustup_bin):
            changed = True
        if _update_rustup_home(env):
            changed = True

        break

    if changed:
        document.mark_changed()
        message = "Ensured Rust SDK path on PATH for lotti"
        _LOGGER.debug(message)
        return OperationResult.changed_result(message)
    return OperationResult.unchanged()


def _is_rustup_command(cmd: str) -> bool:
    """Check if a command is related to rustup installation."""
    return (
        "sh.rustup.rs" in cmd or "Installing Rust" in cmd or "$HOME/.cargo/bin" in cmd
    )


def _remove_rustup_from_module(module: dict) -> bool:
    """Remove rustup commands from a module. Returns True if changed."""
    if not isinstance(module, dict) or module.get("name") != "lotti":
        return False

    commands = module.get("build-commands")
    if not isinstance(commands, list):
        return False

    # Filter out rustup-related commands
    filtered = [str(cmd) for cmd in commands if not _is_rustup_command(str(cmd))]

    if len(filtered) < len(commands):
        module["build-commands"] = filtered
        return True
    return False


def remove_rustup_install(document: ManifestDocument) -> OperationResult:
    """Remove rustup installation commands from lotti build-commands.

    This avoids network and relies on the Rust SDK extension instead.
    """
    modules = document.ensure_modules()

    # Process only the first matching lotti module
    for module in modules:
        if _remove_rustup_from_module(module):
            document.mark_changed()
            message = "Removed rustup install steps from lotti"
            _LOGGER.debug(message)
            return OperationResult.changed_result(message)
        if isinstance(module, dict) and module.get("name") == "lotti":
            break

    return OperationResult.unchanged()


def ensure_setup_helper_source(
    document: ManifestDocument,
    *,
    helper_name: str,
) -> OperationResult:
    """Ensure the lotti module sources include the setup helper file."""

    modules = document.ensure_modules()
    changed = False
    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue
        sources = module.setdefault("sources", [])
        if not any(
            isinstance(source, dict)
            and source.get("type") == "file"
            and source.get("path") == helper_name
            for source in sources
        ):
            sources.append({"type": "file", "path": helper_name})
            changed = True
        break
    if changed:
        document.mark_changed()
        message = f"Ensured {helper_name} included in lotti sources"
        _LOGGER.debug(message)
        return OperationResult.changed_result(message)
    return OperationResult.unchanged()


def _build_setup_helper_command(
    helper_name: str, working_dir: str, enable_debug: bool = False
) -> str:
    """Build the setup helper command with resolver and execution logic.

    This is extracted to reduce complexity of ensure_setup_helper_command.
    """

    def _get_resolver_command(helper_name: str) -> str:
        """Get the helper resolver command."""
        return (
            f"if [ -f ./{helper_name} ]; then H=./{helper_name}; "
            f"elif [ -x /var/lib/flutter/bin/{helper_name} ]; then H=/var/lib/flutter/bin/{helper_name}; "
            f"elif [ -x /app/flutter/bin/{helper_name} ]; then H=/app/flutter/bin/{helper_name}; "
            f"else H=./{helper_name}; fi; "
        )

    def _get_debug_command(helper_name: str) -> str:
        """Get the debug command if needed."""
        return (
            f"if [ ! -f ./{helper_name} ]; then "
            f"echo 'DEBUG: missing ./{helper_name}; PWD='\"$PWD\"; ls -la; fi; "
        )

    def _get_exec_command(working_dir: str) -> str:
        """Get the execution command based on working directory."""
        if working_dir == "/app":
            return (
                'if [ -d /app/flutter ]; then bash "$H" -C /app; '
                'elif [ -d /var/lib/flutter ]; then bash "$H" -C /var/lib; '
                'else bash "$H"; fi'
            )
        elif working_dir == "/var/lib":
            return (
                'if [ -d /var/lib/flutter ]; then bash "$H" -C /var/lib; '
                'elif [ -d /app/flutter ]; then bash "$H" -C /app; '
                'else bash "$H"; fi'
            )
        else:
            return f'bash "$H" -C {working_dir}'

    # Build the final command
    debug = _get_debug_command(helper_name) if enable_debug else ""
    resolver = _get_resolver_command(helper_name)
    exec_cmd = _get_exec_command(working_dir)

    return debug + resolver + exec_cmd


def _update_lotti_build_commands(
    module: dict, helper_name: str, desired_command: str
) -> bool:
    """Update the build commands for the lotti module.

    Returns True if changes were made.
    """
    commands = module.get("build-commands")
    if not isinstance(commands, list):
        commands = []

    normalized: list[str] = []
    present = False

    # Normalize existing commands
    for raw in commands:
        command = str(raw)
        if helper_name in command:
            command = desired_command
        if command.strip() == desired_command:
            present = True
        normalized.append(command)

    # Add command if not present
    if not present:
        insertion_index = _find_insertion_index(normalized)
        normalized.insert(insertion_index, desired_command)

    # Update module if changed
    if normalized != commands:
        module["build-commands"] = normalized
        return True
    return False


def _find_insertion_index(commands: list[str]) -> int:
    """Find the best index to insert the setup helper command."""
    for idx, command in enumerate(commands):
        if "flutter " in command:
            return idx
    return len(commands)


def ensure_setup_helper_command(
    document: ManifestDocument,
    *,
    helper_name: str,
    working_dir: str,
    enable_debug: bool = False,  # Disabled by default, can be enabled via env var
) -> OperationResult:
    """Ensure lotti build-commands invoke the setup helper with the desired working dir.

    Args:
        document: The manifest document to modify
        helper_name: Name of the helper script (e.g., "setup-flutter.sh")
        working_dir: Working directory to pass to the helper
        enable_debug: Whether to include debug output (default: False)
    """
    # Allow environment variable to enable debug mode
    import os

    if os.environ.get("FLATPAK_HELPER_DEBUG", "").lower() in ("1", "true", "yes"):
        enable_debug = True

    # Build the desired command
    desired_command = _build_setup_helper_command(
        helper_name, working_dir, enable_debug
    )

    # Find and update the lotti module
    modules = document.ensure_modules()
    changed = False

    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue

        changed = _update_lotti_build_commands(module, helper_name, desired_command)
        break

    if changed:
        document.mark_changed()
        message = f"Ensured setup helper command ({working_dir})"
        _LOGGER.debug(message)
        return OperationResult.changed_result(message)
    return OperationResult.unchanged()


def normalize_sdk_copy(document: ManifestDocument) -> OperationResult:
    """Normalize the cp command copying the Flutter SDK."""

    modules = document.ensure_modules()
    changed = False
    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue
        commands = module.get("build-commands")
        if not isinstance(commands, list):
            continue
        new_commands: list[str] = []
        updated = False
        for raw in commands:
            command = str(raw)
            if "cp -r" in command and "/run/build/lotti/flutter_sdk" in command:
                fallback = _FALLBACK_COPY_SNIPPET.format(
                    dst="/run/build/lotti/flutter_sdk"
                )
                new_commands.append(fallback)
                updated = True
            else:
                new_commands.append(command)
        if updated:
            module["build-commands"] = new_commands
            changed = True
    if changed:
        document.mark_changed()
        message = "Normalized Flutter SDK copy command"
        _LOGGER.debug(message)
        return OperationResult.changed_result(message)
    return OperationResult.unchanged()


def _convert_flutter_sdk_sources(module: dict, archive_name: str, sha256: str) -> bool:
    """Convert flutter-sdk module git sources to archive."""
    changed = False
    for source in module.setdefault("sources", []):
        if isinstance(source, dict) and source.get("type") == "git":
            source["type"] = "archive"
            source["path"] = archive_name
            source["sha256"] = sha256
            source.pop("url", None)
            source.pop("branch", None)
            source.pop("tag", None)
            changed = True
    return changed


def _remove_lotti_flutter_git_sources(module: dict) -> bool:
    """Remove flutter git sources from lotti module."""
    sources = module.get("sources", [])
    if not isinstance(sources, list):
        return False

    filtered = []
    removed = False
    for source in sources:
        if (
            isinstance(source, dict)
            and source.get("type") == "git"
            and source.get("dest") == "flutter"
        ):
            removed = True
            continue
        filtered.append(source)

    if removed:
        module["sources"] = filtered
        return True
    return False


def convert_flutter_git_to_archive(
    document: ManifestDocument,
    *,
    archive_name: str,
    sha256: str,
) -> OperationResult:
    """Convert flutter git sources to archive references."""

    modules = document.ensure_modules()
    changed = False

    for module in modules:
        if not isinstance(module, dict):
            continue

        name = module.get("name")
        if name == "flutter-sdk":
            if _convert_flutter_sdk_sources(module, archive_name, sha256):
                changed = True
        elif name == "lotti":
            if _remove_lotti_flutter_git_sources(module):
                changed = True

    if changed:
        document.mark_changed()
        message = f"Converted flutter git source to archive {archive_name}"
        _LOGGER.debug(message)
        return OperationResult.changed_result(message)
    return OperationResult.unchanged()


def rewrite_flutter_git_url(document: ManifestDocument) -> OperationResult:
    """Restore flutter git URLs to the canonical upstream."""

    modules = document.ensure_modules()
    changed = False
    for module in modules:
        if not isinstance(module, dict):
            continue
        for source in module.get("sources", []):
            if (
                isinstance(source, dict)
                and source.get("type") == "git"
                and source.get("dest") == "flutter"
            ):
                if source.get("url") != _CANONICAL_FLUTTER_URL:
                    source["url"] = _CANONICAL_FLUTTER_URL
                    changed = True
    if changed:
        document.mark_changed()
        message = "Rewrote flutter git URLs to canonical origin"
        _LOGGER.debug(message)
        return OperationResult.changed_result(message)
    return OperationResult.unchanged()


def _remove_flutter_sdk_if_nested(
    document: ManifestDocument, modules: list, extra_modules: list
) -> tuple[list, bool, str | None]:
    """Remove top-level flutter-sdk module if nested modules exist."""
    if not extra_modules:
        return modules, False, None

    filtered_modules = [
        module
        for module in modules
        if not (isinstance(module, dict) and module.get("name") == "flutter-sdk")
    ]

    if filtered_modules != modules:
        document.data["modules"] = filtered_modules
        return (
            filtered_modules,
            True,
            "Removed top-level flutter-sdk in favor of nested modules",
        )

    return modules, False, None


def _process_lotti_module(
    module: dict, archive_name: str, sha256: str, output_path: Path, extra_modules: list
) -> bool:
    """Process the lotti module to add archive and build sources.

    IMPORTANT: This completely replaces the sources list to ensure patches
    and other sources from previous versions don't get applied to the
    bundled archive, which would cause version mismatches.
    """
    extra_sources: list = []

    # Include source lists generated by flatpak-flutter (string references are supported)
    for candidate in (
        output_path / "pubspec-sources.json",
        output_path / "cargo-sources.json",
    ):
        if candidate.exists():
            extra_sources.append(candidate.name)

    # Include package_config.json as a file so it is staged into the build dir
    pkg_cfg = output_path / "package_config.json"
    if pkg_cfg.exists():
        extra_sources.append({"type": "file", "path": pkg_cfg.name})

    # Include setup helper script
    helper = output_path / "setup-flutter.sh"
    if helper.exists():
        extra_sources.append({"type": "file", "path": helper.name})

    # Preserve existing sources required by plugins/tools
    # - Keep ALL file sources (plugin blobs like mimalloc/sqlite archives)
    # - Do NOT keep patch or git sources here to avoid version mismatches
    #   (patches can be re-injected explicitly by the preparation script if needed)
    existing_file_sources: list = []
    if "sources" in module:
        for src in module["sources"]:
            if isinstance(src, dict) and src.get("type") == "file":
                existing_file_sources.append(src)

    # Replace sources but preserve ALL file sources for plugin dependencies
    module["sources"] = [
        {
            "type": "archive",
            "path": archive_name,
            "sha256": sha256,
            "strip-components": 1,
        }
    ]
    # Attach generator outputs
    module["sources"].extend(extra_sources)
    # Preserve important existing sources for plugins/tools
    module["sources"].extend(existing_file_sources)
    # Intentionally drop patch/git/dir sources here; they can be added later by tooling

    # Add nested modules if they exist
    if extra_modules:
        module["modules"] = extra_modules

    return True


def add_sqlite3_patch(
    document: ManifestDocument, *, version: str, patch_path: str
) -> OperationResult:
    """Ensure sqlite3 plugin CMake patch is present for offline builds.

    Args:
        version: sqlite3_flutter_libs version string (e.g., "0.5.39")
        patch_path: relative path to patch file staged in sources
                    (e.g., "sqlite3_flutter_libs/0.5.34-CMakeLists.txt.patch")

    Adds:
      - type: patch
        path: <patch_path>
        dest: .pub-cache/hosted/pub.dev/sqlite3_flutter_libs-<version>
    """
    modules = document.ensure_modules()
    target = None
    for module in modules:
        if isinstance(module, dict) and module.get("name") == "lotti":
            target = module
            break
    if not target:
        return OperationResult.unchanged()

    sources = target.setdefault("sources", [])
    dest_dir = f".pub-cache/hosted/pub.dev/sqlite3_flutter_libs-{version}"

    # Already present?
    for src in sources:
        if (
            isinstance(src, dict)
            and src.get("type") == "patch"
            and src.get("path") == patch_path
            and src.get("dest") == dest_dir
        ):
            return OperationResult.unchanged()

    sources.append({"type": "patch", "path": patch_path, "dest": dest_dir})
    document.mark_changed()
    _LOGGER.debug("Ensured sqlite3 patch %s targeting %s present", patch_path, dest_dir)
    return OperationResult.changed_result(
        f"Added sqlite3 patch {patch_path} for {dest_dir}"
    )


def bundle_app_archive(
    document: ManifestDocument,
    *,
    archive_name: str,
    sha256: str,
    output_dir: str | Path,
) -> OperationResult:
    """Bundle the app source as an archive and attach offline metadata."""
    output_path = Path(output_dir)
    extra_modules = _discover_flutter_jsons(output_path)
    modules = document.ensure_modules()
    messages: list[str] = []
    changed = False

    # Remove top-level flutter-sdk if nested modules exist
    modules, sdk_removed, sdk_message = _remove_flutter_sdk_if_nested(
        document, modules, extra_modules
    )
    if sdk_removed:
        changed = True
        if sdk_message:
            messages.append(sdk_message)

    # Process lotti module
    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue

        if _process_lotti_module(
            module, archive_name, sha256, output_path, extra_modules
        ):
            changed = True
            messages.append(f"Bundled app archive {archive_name}")
        break

    if changed:
        document.mark_changed()
        for message in messages:
            _LOGGER.debug(message)
        return OperationResult(changed=True, messages=messages)
    return OperationResult.unchanged()
