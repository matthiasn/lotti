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


def normalize_flutter_sdk_module(document: ManifestDocument) -> OperationResult:
    """Strip Flutter invocations from flutter-sdk build commands."""

    modules = document.ensure_modules()
    changed = False
    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "flutter-sdk":
            continue
        commands = module.get("build-commands", [])
        if not isinstance(commands, list):
            commands = []
        filtered: list[str] = []
        for raw in commands:
            command = str(raw)
            if command.startswith("mv flutter ") or command.startswith(
                "export PATH=/app/flutter/bin"
            ):
                filtered.append(command)
        if not any(cmd.startswith("mv flutter ") for cmd in filtered):
            filtered.insert(0, "mv flutter /app/flutter")
        if filtered != commands:
            module["build-commands"] = filtered
            changed = True
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


def ensure_lotti_network_share(document: ManifestDocument) -> OperationResult:
    """Ensure the lotti module has build-args with --share=network.

    Some build environments rely on network access during setup (e.g., when
    falling back from offline cache). This helper makes sure the final manifest
    preserves that capability for the lotti build stage.
    """

    modules = document.ensure_modules()
    changed = False
    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue
        build_opts = module.setdefault("build-options", {})
        build_args = build_opts.get("build-args")
        if isinstance(build_args, list):
            if "--share=network" not in build_args:
                build_args.insert(0, "--share=network")
                changed = True
        elif build_args is None:
            build_opts["build-args"] = ["--share=network"]
            changed = True
        else:
            # Unexpected type; normalize to list including --share=network
            build_opts["build-args"] = ["--share=network"]
            changed = True
        break

    if changed:
        document.mark_changed()
        message = "Ensured lotti build-args include --share=network"
        _LOGGER.debug(message)
        return OperationResult.changed_result(message)
    return OperationResult.unchanged()


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

        # append-path
        append_current = str(build_options.get("append-path", ""))
        append_entries = [e for e in append_current.split(":") if e]
        # Ensure Rust SDK and rustup bins are in append-path
        changed_local = False
        for entry in (rust_bin, rustup_bin):
            if entry not in append_entries:
                append_entries.append(entry)
                changed_local = True
        if changed_local:
            if append_entries:
                build_options["append-path"] = ":".join(append_entries)
            else:
                build_options["append-path"] = rust_bin
            changed = True

        # env.PATH
        env = build_options.setdefault("env", {})
        path_current = str(env.get("PATH", ""))
        path_entries = [e for e in path_current.split(":") if e]
        # Ensure PATH begins with rustup, then rust SDK bin (stable order)
        # Remove any existing occurrences first, then prepend in desired order.
        original_len = len(path_entries)
        path_entries = [e for e in path_entries if e not in (rustup_bin, rust_bin)]
        path_entries = [rustup_bin, rust_bin] + path_entries
        if len(path_entries) != original_len or not env.get("PATH", "").startswith(
            rustup_bin
        ):
            env["PATH"] = ":".join(path_entries)
            changed = True
        # Ensure RUSTUP_HOME is set for tool expectations
        if env.get("RUSTUP_HOME") != "/var/lib/rustup":
            env["RUSTUP_HOME"] = "/var/lib/rustup"
            changed = True
        break

    if changed:
        document.mark_changed()
        message = "Ensured Rust SDK path on PATH for lotti"
        _LOGGER.debug(message)
        return OperationResult.changed_result(message)
    return OperationResult.unchanged()


def remove_rustup_install(document: ManifestDocument) -> OperationResult:
    """Remove rustup installation commands from lotti build-commands.

    This avoids network and relies on the Rust SDK extension instead.
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
        removed_any = False
        for raw in commands:
            cmd = str(raw)
            if (
                ("sh.rustup.rs" in cmd)
                or ("Installing Rust" in cmd)
                or ("$HOME/.cargo/bin" in cmd)
            ):
                removed_any = True
                continue
            filtered.append(cmd)
        if removed_any:
            module["build-commands"] = filtered
            changed = True
        break

    if changed:
        document.mark_changed()
        message = "Removed rustup install steps from lotti"
        _LOGGER.debug(message)
        return OperationResult.changed_result(message)
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

    desired_command = debug + resolver + exec_cmd

    modules = document.ensure_modules()
    changed = False
    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue
        commands = module.get("build-commands")
        if not isinstance(commands, list):
            commands = []
        normalized: list[str] = []
        present = False
        for raw in commands:
            command = str(raw)
            if helper_name in command:
                command = desired_command
            if command.strip() == desired_command:
                present = True
            normalized.append(command)
        if not present:
            insertion_index = 0
            for idx, command in enumerate(normalized):
                if "flutter " in command:
                    insertion_index = idx
                    break
                insertion_index = idx + 1
            normalized.insert(insertion_index, desired_command)
        if normalized != commands:
            module["build-commands"] = normalized
            changed = True
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
            for source in module.setdefault("sources", []):
                if isinstance(source, dict) and source.get("type") == "git":
                    source["type"] = "archive"
                    source["path"] = archive_name
                    source["sha256"] = sha256
                    source.pop("url", None)
                    source.pop("branch", None)
                    source.pop("tag", None)
                    changed = True
        elif name == "lotti":
            sources = module.get("sources", [])
            if not isinstance(sources, list):
                continue
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


def _source_exists(sources_list: list, new_source: str | dict) -> bool:
    """Check if a source already exists in the sources list."""
    for existing in sources_list:
        if isinstance(existing, str) and isinstance(new_source, str):
            if existing == new_source:
                return True
        elif isinstance(existing, dict) and isinstance(new_source, dict):
            if existing.get("type") == new_source.get("type"):
                if existing.get("type") == "file":
                    if existing.get("path") == new_source.get("path"):
                        return True
                elif existing.get("type") == "archive":
                    if existing.get("sha256") == new_source.get("sha256"):
                        return True
    return False


def _replace_or_add_archive_source(
    sources: list, archive_name: str, sha256: str
) -> None:
    """Replace git source with archive or add archive as first source."""
    archive_source = {
        "type": "archive",
        "path": archive_name,
        "sha256": sha256,
        "strip-components": 1,
    }

    # Try to replace existing git source
    for i, source in enumerate(sources):
        if isinstance(source, dict) and source.get("type") == "git":
            sources[i] = archive_source
            return

    # No git source found, add archive as first source
    sources.insert(0, archive_source)


def _add_build_sources(sources: list, output_path: Path) -> None:
    """Add build-related sources if they exist and aren't duplicates."""
    # Include source lists generated by flatpak-flutter
    for candidate in (
        output_path / "pubspec-sources.json",
        output_path / "cargo-sources.json",
    ):
        if candidate.exists() and not _source_exists(sources, candidate.name):
            sources.append(candidate.name)

    # Include package_config.json as a file
    pkg_cfg = output_path / "package_config.json"
    if pkg_cfg.exists():
        file_source = {"type": "file", "path": pkg_cfg.name}
        if not _source_exists(sources, file_source):
            sources.append(file_source)

    # Include setup helper script
    helper = output_path / "setup-flutter.sh"
    if helper.exists():
        helper_source = {"type": "file", "path": helper.name}
        if not _source_exists(sources, helper_source):
            sources.append(helper_source)


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
    if extra_modules:
        filtered_modules = [
            module
            for module in modules
            if not (isinstance(module, dict) and module.get("name") == "flutter-sdk")
        ]
        if filtered_modules != modules:
            document.data["modules"] = filtered_modules
            modules = filtered_modules
            changed = True
            messages.append("Removed top-level flutter-sdk in favor of nested modules")

    # Process lotti module
    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue

        # Get or create sources list
        sources = module.setdefault("sources", [])
        if not isinstance(sources, list):
            sources = []
            module["sources"] = sources

        # Replace git source with archive or add archive
        _replace_or_add_archive_source(sources, archive_name, sha256)

        # Add build-related sources
        _add_build_sources(sources, output_path)

        # Add nested modules if they exist
        if extra_modules:
            module["modules"] = extra_modules

        changed = True
        messages.append(f"Bundled app archive {archive_name}")
        break

    if changed:
        document.mark_changed()
        for message in messages:
            _LOGGER.debug(message)
        return OperationResult(changed=True, messages=messages)
    return OperationResult.unchanged()
