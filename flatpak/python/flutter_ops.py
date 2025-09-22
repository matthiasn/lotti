"""Flutter-specific manifest operations."""

from __future__ import annotations

from pathlib import Path
from typing import Iterable

try:  # pragma: no cover
    from . import utils
except ImportError:  # pragma: no cover
    import utils  # type: ignore

_FALLBACK_COPY_SNIPPET = (
    "if [ -d /var/lib/flutter ]; then cp -r /var/lib/flutter {dst}; "
    "elif [ -d /app/flutter ]; then cp -r /app/flutter {dst}; "
    "else echo \"No Flutter SDK found at /var/lib/flutter or /app/flutter\"; exit 1; fi"
)

_CANONICAL_FLUTTER_URL = "https://github.com/flutter/flutter.git"


def ensure_nested_sdk(manifest_path: str | Path, output_dir: str | Path) -> bool:
    """Ensure nested flutter SDK JSON modules are referenced by lotti."""

    json_names = sorted(
        candidate.name for candidate in Path(output_dir).glob("flutter-sdk-*.json")
    )
    if not json_names:
        return False

    data = utils.load_manifest(manifest_path)
    modules = data.get("modules")
    if not isinstance(modules, list):
        return False

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
        utils.dump_manifest(manifest_path, data)
    return changed


def should_remove_flutter_sdk(manifest_path: str | Path, output_dir: str | Path) -> bool:
    """Return ``True`` when offline flutter JSONs are present and referenced."""

    json_names = [candidate.name for candidate in Path(output_dir).glob("flutter-sdk-*.json")]
    if not json_names:
        return False

    data = utils.load_manifest(manifest_path)
    modules = data.get("modules")
    if not isinstance(modules, list):
        return False

    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue
        referenced = [name for name in json_names if name in (module.get("modules") or [])]
        return bool(referenced)
    return False


def normalize_flutter_sdk_module(manifest_path: str | Path) -> bool:
    """Strip Flutter invocations from flutter-sdk build commands."""

    data = utils.load_manifest(manifest_path)
    modules = data.get("modules")
    if not isinstance(modules, list):
        return False

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
            if command.startswith("mv flutter ") or command.startswith("export PATH=/app/flutter/bin"):
                filtered.append(command)
        if not any(cmd.startswith("mv flutter ") for cmd in filtered):
            filtered.insert(0, "mv flutter /app/flutter")
        if filtered != commands:
            module["build-commands"] = filtered
            changed = True
    if changed:
        utils.dump_manifest(manifest_path, data)
    return changed


def _split_path(value: str | None) -> list[str]:
    if not value:
        return []
    return [entry for entry in value.split(":") if entry]


def normalize_lotti_env(
    manifest_path: str | Path,
    *,
    flutter_bin: str,
    ensure_append_path: bool,
) -> bool:
    """Ensure lotti build-options PATH settings include ``flutter_bin``."""

    data = utils.load_manifest(manifest_path)
    modules = data.get("modules")
    if not isinstance(modules, list):
        return False

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
                build_options["append-path"] = ":".join(append_entries) if append_entries else flutter_bin
                changed = True
        env = build_options.setdefault("env", {})
        path_current = env.get("PATH", "")
        path_entries = _split_path(path_current)
        if flutter_bin not in path_entries:
            path_entries.insert(0, flutter_bin)
            env["PATH"] = ":".join(path_entries)
            changed = True
    if changed:
        utils.dump_manifest(manifest_path, data)
    return changed


def ensure_setup_helper_source(
    manifest_path: str | Path,
    *,
    helper_name: str,
) -> bool:
    """Ensure the lotti module sources include the setup helper file."""

    data = utils.load_manifest(manifest_path)
    modules = data.get("modules")
    if not isinstance(modules, list):
        return False

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
        utils.dump_manifest(manifest_path, data)
    return changed


def ensure_setup_helper_command(
    manifest_path: str | Path,
    *,
    helper_name: str,
    working_dir: str,
) -> bool:
    """Ensure lotti build-commands invoke the setup helper with the desired working dir."""

    def _desired_command() -> str:
        if working_dir == "/app":
            return (
                f"if [ -d /app/flutter ]; then bash {helper_name} -C /app; "
                f"elif [ -d /var/lib/flutter ]; then bash {helper_name} -C /var/lib; "
                f"else bash {helper_name}; fi"
            )
        if working_dir == "/var/lib":
            return (
                f"if [ -d /var/lib/flutter ]; then bash {helper_name} -C /var/lib; "
                f"elif [ -d /app/flutter ]; then bash {helper_name} -C /app; "
                f"else bash {helper_name}; fi"
            )
        return f"bash {helper_name} -C {working_dir}"

    desired_command = _desired_command()

    data = utils.load_manifest(manifest_path)
    modules = data.get("modules")
    if not isinstance(modules, list):
        return False

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
        utils.dump_manifest(manifest_path, data)
    return changed


def normalize_sdk_copy(manifest_path: str | Path) -> bool:
    """Normalize the cp command copying the Flutter SDK."""

    data = utils.load_manifest(manifest_path)
    modules = data.get("modules")
    if not isinstance(modules, list):
        return False

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
                fallback = _FALLBACK_COPY_SNIPPET.format(dst="/run/build/lotti/flutter_sdk")
                new_commands.append(fallback)
                updated = True
            else:
                new_commands.append(command)
        if updated:
            module["build-commands"] = new_commands
            changed = True
    if changed:
        utils.dump_manifest(manifest_path, data)
    return changed


def convert_flutter_git_to_archive(
    manifest_path: str | Path,
    *,
    archive_name: str,
    sha256: str,
) -> bool:
    """Convert flutter git sources to archive references."""

    data = utils.load_manifest(manifest_path)
    modules = data.get("modules")
    if not isinstance(modules, list):
        return False

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
        utils.dump_manifest(manifest_path, data)
    return changed


def rewrite_flutter_git_url(manifest_path: str | Path) -> bool:
    """Restore flutter git URLs to the canonical upstream."""

    data = utils.load_manifest(manifest_path)
    modules = data.get("modules")
    if not isinstance(modules, list):
        return False

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
        utils.dump_manifest(manifest_path, data)
    return changed


def bundle_app_archive(
    manifest_path: str | Path,
    *,
    archive_name: str,
    sha256: str,
    output_dir: str | Path,
) -> bool:
    """Bundle the app source as an archive and attach offline metadata."""

    output_path = Path(output_dir)
    extra_modules = [candidate.name for candidate in sorted(output_path.glob("flutter-sdk-*.json"))]

    data = utils.load_manifest(manifest_path)
    modules = data.get("modules")
    if not isinstance(modules, list):
        return False

    changed = False
    if extra_modules:
        filtered_modules = [
            module
            for module in modules
            if not (isinstance(module, dict) and module.get("name") == "flutter-sdk")
        ]
        if filtered_modules != modules:
            data["modules"] = filtered_modules
            modules = filtered_modules
            changed = True

    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue
        extra_sources: list = []
        for candidate in (
            output_path / "pubspec-sources.json",
            output_path / "cargo-sources.json",
        ):
            if candidate.exists():
                extra_sources.append(candidate.name)
        for candidate in sorted(output_path.glob("rustup-*.json")):
            extra_sources.append(candidate.name)
        helper = output_path / "setup-flutter.sh"
        if helper.exists():
            extra_sources.append({"type": "file", "path": helper.name})
        module["sources"] = [
            {
                "type": "archive",
                "path": archive_name,
                "sha256": sha256,
                "strip-components": 1,
            }
        ] + extra_sources
        if extra_modules:
            module["modules"] = extra_modules
        changed = True
        break

    if changed:
        utils.dump_manifest(manifest_path, data)
    return changed
