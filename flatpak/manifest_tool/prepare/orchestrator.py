"""Orchestrates creation of the Flathub offline payload."""

from __future__ import annotations

import datetime
import hashlib
import json
import lzma
import os
import re
import shutil
import socket
import stat
import subprocess
import sys
import tarfile
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterable, Mapping, MutableMapping, Optional
from urllib.parse import urlparse

import yaml
from .. import flutter
from ..build_utils import utils as build_utils
from ..core import utils, validation as core_validation
from ..core.manifest import ManifestDocument
from ..operations import ci as ci_ops
from ..operations import manifest as manifest_ops
from ..operations import sources as sources_ops
from ..tools.get_fvm_flutter_version import read_version

try:  # pragma: no cover - optional dependency
    from colorama import Fore, Style, init as colorama_init

    colorama_init()
    _COLOR_ENABLED = True
except ImportError:  # pragma: no cover - colorama optional
    Fore = Style = None  # type: ignore
    _COLOR_ENABLED = False

_ALLOWED_URL_SCHEMES = {"https"}


def _read_fvm_flutter_tag(repo_root: Path) -> Optional[str]:
    """Read Flutter version from FVM config file."""
    config_path = repo_root / ".fvm" / "fvm_config.json"
    return read_version(config_path)


def get_default_flutter_tag() -> str:
    """Read the default Flutter tag from FVM config or fall back to 'stable'."""
    # Try to read from repository root's FVM config
    repo_root = next(
        (p for p in Path(__file__).resolve().parents if (p / ".fvm").exists() or (p / ".git").exists()),
        Path(__file__).resolve().parents[3],
    )
    fvm_tag = _read_fvm_flutter_tag(repo_root)
    return fvm_tag if fvm_tag else "stable"


# Computed once at module load for consistency in tests and logging
DEFAULT_FLUTTER_TAG = get_default_flutter_tag()

_SQLITE_AUTOCONF_VERSION = os.getenv("SQLITE_AUTOCONF_VERSION", "sqlite-autoconf-3500400")
_SQLITE_AUTOCONF_SHA256 = os.getenv(
    "SQLITE_AUTOCONF_SHA256",
    "a3db587a1b92ee5ddac2f66b3edb41b26f9c867275782d46c3a088977d6a5b18",
)

CARGO_LOCK_SOURCES: tuple[tuple[str, str], ...] = (
    (
        "flutter_vodozemac",
        (
            # Match the plugin version used in pubspec-sources (0.3.0)
            "https://raw.githubusercontent.com/famedly/dart-vodozemac/"
            "5319314eb397bc3c8de06baddbe64fa721596ce0/rust/Cargo.lock"
        ),
    ),
    (
        "super_native_extensions",
        (
            "https://raw.githubusercontent.com/superlistapp/"
            "super_native_extensions/super_native_extensions-v0.9.1/"
            "super_native_extensions/rust/Cargo.lock"
        ),
    ),
    (
        "irondash_engine_context",
        ("https://raw.githubusercontent.com/irondash/irondash/" "65343873472d6796c0388362a8e04b6e9a499044/Cargo.lock"),
    ),
)

_LOGGER = utils.get_logger("prepare_flathub")


def _copytree(src: Path, dst: Path) -> None:
    if dst.exists():
        if dst.is_dir() and not dst.is_symlink():
            shutil.rmtree(dst)
        else:
            dst.unlink()
    shutil.copytree(src, dst)


def _copyfile(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def _file_sha256(path: Path) -> str:
    sha = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(8192), b""):
            sha.update(chunk)
    return sha.hexdigest()


def _run_command(command: list[str], **kwargs) -> subprocess.CompletedProcess[str]:
    if command and isinstance(command[0], str) and not os.path.isabs(command[0]):
        resolved = shutil.which(command[0])
        if not resolved:
            raise PrepareFlathubError(f"Executable not found: {command[0]}")
        command = [resolved, *command[1:]]
    return subprocess.run(command, **kwargs)


@dataclass(slots=True)
class PrepareFlathubOptions:
    """Runtime options derived from CLI arguments or environment variables."""

    repository_root: Path
    flatpak_dir: Path
    work_dir: Path
    output_dir: Path
    clean_after_gen: bool = True
    pin_commit: bool = True
    use_nested_flutter: bool = False
    download_missing_sources: bool = True
    no_flatpak_flutter: bool = False
    flatpak_flutter_timeout: Optional[int] = None
    extra_env: Mapping[str, str] | None = None
    test_build: bool = False
    flathub_dir: Optional[Path] = None


class PrepareFlathubError(RuntimeError):
    """Raised when preparation fails."""


@dataclass(slots=True)
class PrepareFlathubContext:
    """Aggregated data used throughout the preparation workflow."""

    options: PrepareFlathubOptions
    repo_root: Path
    flatpak_dir: Path
    script_dir: Path
    python_cli: Path
    work_dir: Path
    output_dir: Path
    manifest_template: Path
    manifest_work: Path
    manifest_output: Path
    env: MutableMapping[str, str]
    lotti_version: str
    release_date: str
    current_branch: str
    app_commit: str
    flutter_tag: Optional[str]
    cached_flutter_dir: Optional[Path]
    flatpak_flutter_repo: Path
    flatpak_flutter_log: Path
    setup_helper_basename: str
    setup_helper_source: Path
    screenshot_source: Path
    flatpak_flutter_status: int | None = None
    flutter_git_url: str = "https://github.com/flutter/flutter.git"
    flathub_dir: Optional[Path] = None
    pr_head_commit: Optional[str] = None
    pr_head_url: Optional[str] = None


class _StatusPrinter:
    """Utility to provide human-friendly status updates."""

    def __init__(self) -> None:
        if _COLOR_ENABLED:
            self._green = Fore.GREEN
            self._yellow = Fore.YELLOW
            self._red = Fore.RED
            self._blue = Fore.BLUE
            self._nc = Style.RESET_ALL
        else:
            self._green = self._yellow = self._red = self._blue = self._nc = ""

    def status(self, message: str) -> None:
        print(f"{self._green}[✓]{self._nc} {message}")

    def info(self, message: str) -> None:
        print(f"{self._blue}[i]{self._nc} {message}")

    def warn(self, message: str) -> None:
        print(f"{self._yellow}[!]{self._nc} {message}")

    def error(self, message: str) -> None:
        print(f"{self._red}[✗]{self._nc} {message}")


def prepare_flathub(options: PrepareFlathubOptions) -> None:
    printer = _StatusPrinter()
    _LOGGER.debug("prepare_flathub invoked with options: %s", options)
    context = _build_context(options, printer)
    _print_intro(context, printer)
    _execute_pipeline(context, printer)


def _build_context(options: PrepareFlathubOptions, printer: _StatusPrinter) -> PrepareFlathubContext:
    repo_root = options.repository_root
    flatpak_dir = options.flatpak_dir
    script_dir = flatpak_dir
    python_cli = flatpak_dir / "manifest_tool" / "cli.py"
    work_dir = options.work_dir
    output_dir = options.output_dir
    manifest_template = flatpak_dir / "com.matthiasn.lotti.source.yml"
    manifest_work = work_dir / "com.matthiasn.lotti.yml"
    manifest_output = output_dir / "com.matthiasn.lotti.yml"
    flatpak_flutter_repo = flatpak_dir / "flatpak-flutter"
    flatpak_flutter_log = work_dir / "flatpak-flutter.log"
    setup_helper_source = flatpak_dir / "helpers" / "setup-flutter.sh"
    screenshot_source = flatpak_dir / "screenshot.png"

    env: MutableMapping[str, str] = dict(options.extra_env or {})
    pr_env = dict(
        ci_ops.pr_aware_environment(
            event_name=os.getenv("GITHUB_EVENT_NAME"),
            event_path=os.getenv("GITHUB_EVENT_PATH"),
        )
    )
    env.update(pr_env)

    lotti_version = env.get("LOTTI_VERSION") or _derive_lotti_version(repo_root, printer)
    release_date = env.get("LOTTI_RELEASE_DATE") or datetime.date.today().isoformat()
    current_branch = _determine_branch(repo_root, env, printer)
    app_commit = _run_git(["rev-parse", "HEAD"], cwd=repo_root)

    # Defer Flutter tag resolution to prefer FVM configuration first.
    # The tag will be determined later via _ensure_flutter_tag_from_modules.
    flutter_tag = None
    cached_flutter_dir = build_utils.find_flutter_sdk(search_roots=[repo_root], max_depth=6)

    context = PrepareFlathubContext(
        options=options,
        repo_root=repo_root,
        flatpak_dir=flatpak_dir,
        script_dir=script_dir,
        python_cli=python_cli,
        work_dir=work_dir,
        output_dir=output_dir,
        manifest_template=manifest_template,
        manifest_work=manifest_work,
        manifest_output=manifest_output,
        env=env,
        lotti_version=lotti_version,
        release_date=release_date,
        current_branch=current_branch,
        app_commit=app_commit,
        flutter_tag=flutter_tag,
        cached_flutter_dir=cached_flutter_dir,
        flatpak_flutter_repo=flatpak_flutter_repo,
        flatpak_flutter_log=flatpak_flutter_log,
        setup_helper_basename=setup_helper_source.name,
        setup_helper_source=setup_helper_source,
        screenshot_source=screenshot_source,
        flathub_dir=options.flathub_dir,
        pr_head_commit=pr_env.get("PR_HEAD_SHA"),
        pr_head_url=pr_env.get("PR_HEAD_URL"),
    )

    printer.info(f"Using version: {lotti_version}")
    printer.info(f"Release date: {release_date}")
    printer.info(f"Branch: {current_branch}")
    printer.info(f"Commit: {app_commit}")
    if cached_flutter_dir:
        printer.info(f"Found cached Flutter SDK at {cached_flutter_dir}")
    else:
        printer.warn("No cached Flutter SDK found in local search roots")

    return context


def _print_intro(context: PrepareFlathubContext, printer: _StatusPrinter) -> None:
    print("==========================================")
    print("   Flathub Submission Preparation")
    print("==========================================")
    print(f"Version: {context.lotti_version}")
    print(f"Release Date: {context.release_date}")
    print(f"Branch: {context.current_branch}")
    print()
    printer.info("Effective options:")
    options = context.options
    print("  PIN_COMMIT=" + ("true" if options.pin_commit else "false"))
    print("  USE_NESTED_FLUTTER=" + ("true" if options.use_nested_flutter else "false"))
    print("  DOWNLOAD_MISSING_SOURCES=" + ("true" if options.download_missing_sources else "false"))
    print("  CLEAN_AFTER_GEN=" + ("true" if options.clean_after_gen else "false"))
    print("  NO_FLATPAK_FLUTTER=" + ("true" if options.no_flatpak_flutter else "false"))
    timeout = options.flatpak_flutter_timeout
    print("  FLATPAK_FLUTTER_TIMEOUT=" + ("<unset>" if timeout is None else str(timeout)))
    print("  TEST_BUILD=" + ("true" if options.test_build else "false"))
    print()


def _run_git(args: Iterable[str], *, cwd: Path) -> str:
    result = _run_command(
        ["git", *args],
        cwd=cwd,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if result.returncode != 0:
        raise PrepareFlathubError(f"git {' '.join(args)} failed with code {result.returncode}: {result.stderr.strip()}")
    return result.stdout.strip()


def _derive_lotti_version(repo_root: Path, printer: _StatusPrinter) -> str:
    pubspec_path = repo_root / "pubspec.yaml"
    if pubspec_path.is_file():
        for line in pubspec_path.read_text(encoding="utf-8").splitlines():
            if line.startswith("version:"):
                version = line.split("version:", 1)[1].strip()
                if "+" in version:
                    version = version.split("+", 1)[0]
                return version
    raise PrepareFlathubError(
        "Unable to determine Lotti version. Define it in pubspec.yaml before running the orchestrator."
    )


def _determine_branch(repo_root: Path, env: Mapping[str, str], printer: _StatusPrinter) -> str:
    branch = _run_git(["rev-parse", "--abbrev-ref", "HEAD"], cwd=repo_root)
    if branch == "HEAD":
        for candidate in ("GITHUB_HEAD_REF", "GITHUB_REF_NAME"):
            value = env.get(candidate)
            if value:
                printer.warn(f"Detached HEAD detected; using {candidate.lower()} value '{value}'")
                branch = value
                break
        else:
            printer.warn("Detached HEAD with no ref info; defaulting to 'main'")
            branch = "main"

    remote_check = _run_command(
        ["git", "ls-remote", "origin", f"refs/heads/{branch}"],
        cwd=repo_root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if remote_check.returncode != 0:
        printer.warn(f"Unable to verify remote branch {branch} (git ls-remote exited with {remote_check.returncode}).")
    elif not remote_check.stdout.strip():
        printer.warn(f"Branch {branch} not found on remote; ensure it is pushed before publishing")

    return branch


def _extract_flutter_tag(manifest_template: Path, printer: _StatusPrinter) -> Optional[str]:
    if not manifest_template.is_file():
        printer.warn(f"Manifest template not found at {manifest_template}")
        return None
    data = yaml.safe_load(manifest_template.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        return None
    modules = data.get("modules")
    if not isinstance(modules, list):
        return None
    for module in modules:
        if isinstance(module, dict) and module.get("name") == "flutter-sdk":
            sources = module.get("sources")
            if not isinstance(sources, list):
                continue
            for source in sources:
                if isinstance(source, dict) and "tag" in source:
                    return str(source["tag"]).strip()
    printer.warn(f"Could not detect Flutter tag from manifest; defaulting to {DEFAULT_FLUTTER_TAG}")
    return DEFAULT_FLUTTER_TAG


def _copy_manifest_template(context: PrepareFlathubContext) -> None:
    template = context.manifest_template
    if not template.is_file():
        raise PrepareFlathubError(f"Manifest template not found at {template}")
    shutil.copyfile(template, context.manifest_work)


def _ensure_flutter_tag_from_modules(
    context: PrepareFlathubContext,
    modules: Iterable[object],
    printer: _StatusPrinter,
) -> None:
    if context.flutter_tag:
        return

    fvm_tag = _read_fvm_flutter_tag(context.repo_root)
    has_fvm_tag = False
    if fvm_tag:
        context.flutter_tag = fvm_tag
        has_fvm_tag = True

    detected = None
    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "flutter-sdk":
            continue
        for source in module.get("sources", []):
            if isinstance(source, dict) and source.get("tag"):
                detected = str(source["tag"])
                break
        if detected:
            break

    if detected and context.flutter_tag:
        if detected != context.flutter_tag:
            printer.warn(
                "Manifest flutter-sdk tag %s differs from FVM (%s); using FVM" % (detected, context.flutter_tag)
            )
        return

    if detected:
        context.flutter_tag = detected
        return

    if has_fvm_tag and context.flutter_tag:
        printer.info(f"Using Flutter tag from FVM configuration: {context.flutter_tag}")
        return

    printer.warn(f"Could not detect Flutter tag; defaulting to {DEFAULT_FLUTTER_TAG}")
    context.flutter_tag = DEFAULT_FLUTTER_TAG


def _ensure_branch_for_lotti_sources(sources: list[object], branch: str) -> bool:
    changed = False
    for source in sources:
        if not isinstance(source, dict) or source.get("type") != "git":
            continue
        if source.get("commit") == "COMMIT_PLACEHOLDER" or "branch" in source:
            source.pop("commit", None)
            source["branch"] = branch
            changed = True
    return changed


def _ensure_flutter_source_in_lotti(sources: list[object], context: PrepareFlathubContext) -> bool:
    if any(
        isinstance(source, dict) and source.get("type") == "git" and source.get("dest") == "flutter"
        for source in sources
    ):
        return False

    sources.insert(
        0,
        {
            "type": "git",
            "url": context.flutter_git_url,
            "tag": context.flutter_tag,
            "dest": "flutter",
        },
    )
    return True


def _ensure_lotti_repo_url(sources: list[object], target_url: str) -> bool:
    changed = False
    for source in sources:
        if not isinstance(source, dict) or source.get("type") != "git":
            continue
        if source.get("dest") == "flutter":
            continue
        if source.get("url") != target_url:
            source["url"] = target_url
            changed = True
    return changed


def _prepare_lotti_module_for_flatpak_flutter(
    modules: Iterable[object],
    context: PrepareFlathubContext,
) -> tuple[bool, bool, bool]:
    branch_applied = False
    flutter_added = False
    repo_overridden = False
    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue
        sources = module.setdefault("sources", [])
        branch_applied = _ensure_branch_for_lotti_sources(sources, context.current_branch) or branch_applied
        flutter_added = _ensure_flutter_source_in_lotti(sources, context) or flutter_added
        if context.pr_head_url:
            repo_overridden = _ensure_lotti_repo_url(sources, context.pr_head_url) or repo_overridden
    return branch_applied, flutter_added, repo_overridden


def _execute_pipeline(context: PrepareFlathubContext, printer: _StatusPrinter) -> None:
    _prepare_directories(context, printer)
    _prepare_manifest_for_flatpak_flutter(context, printer)
    _ensure_setup_helper_reference(context, printer)
    _ensure_flatpak_flutter_repo(context, printer)
    _prepare_workspace_files(context, printer)
    _prestage_local_tool_for_pub_get(context, printer)
    _prime_flutter_sdk(context, printer)
    _run_flatpak_flutter(context, printer)
    # Fail fast if flatpak-flutter failed, unless explicit fallback was requested
    allow_fallback_env = os.getenv("ALLOW_FALLBACK", "false").strip().lower()
    allow_fallback = allow_fallback_env in {"1", "true", "yes", "on"}
    if context.flatpak_flutter_status not in (0, None) and not allow_fallback:
        raise PrepareFlathubError("flatpak-flutter failed; set ALLOW_FALLBACK=true to proceed with fallback generation")
    _normalize_sqlite_patch(context, printer)
    _pin_working_manifest(context, printer)
    _copy_generated_artifacts(context, printer)
    _regenerate_pubspec_sources_if_needed(context, printer)
    _stage_package_config(context, printer)
    _ensure_flutter_json(context, printer)
    _apply_manifest_compliance(context, printer)
    _copy_assets_and_metadata(context, printer)
    _download_and_generate_cargo_sources(context, printer)
    _post_process_output_manifest(context, printer)
    _bundle_sources_and_archives(context, printer)
    _final_manifest_checks(context, printer)
    _cleanup(context, printer)
    _maybe_test_build(context, printer)
    _print_summary(context, printer)


def _prestage_local_tool_for_pub_get(context: PrepareFlathubContext, printer: _StatusPrinter) -> None:
    """Pre-stage local tool path deps into flatpak-flutter build dir before pub get.

    flatpak-flutter clones the app into `.flatpak-builder/build/lotti` and runs
    `flutter pub get` there. If the app depends on a local path like
    `tool/lotti_custom_lint`, ensure that directory exists in the clone before
    pub get runs by copying it from the repository root.
    """
    source_dir = context.repo_root / "tool" / "lotti_custom_lint"
    if not source_dir.is_dir():
        return
    target_root = context.work_dir / ".flatpak-builder" / "build" / "lotti"
    target_dir = target_root / "tool" / "lotti_custom_lint"
    try:
        target_dir.parent.mkdir(parents=True, exist_ok=True)
        # Copy only if missing or stale
        if not target_dir.exists():
            _copytree(source_dir, target_dir)
            printer.info("Pre-staged tool/lotti_custom_lint for flatpak-flutter pub get")
    except (OSError, shutil.Error):
        _LOGGER.debug("Failed to pre-stage local tool path", exc_info=True)


def _prepare_directories(context: PrepareFlathubContext, printer: _StatusPrinter) -> None:
    printer.status("Creating clean work directory...")
    work_dir = context.work_dir
    output_dir = context.output_dir

    work_dir.mkdir(parents=True, exist_ok=True)
    for child in list(work_dir.iterdir()):
        try:
            if child.is_dir() and not child.is_symlink():
                shutil.rmtree(child)
            else:
                child.unlink()
        except FileNotFoundError:
            continue
    output_dir.mkdir(parents=True, exist_ok=True)
    context.flatpak_flutter_log.parent.mkdir(parents=True, exist_ok=True)


def _prepare_manifest_for_flatpak_flutter(context: PrepareFlathubContext, printer: _StatusPrinter) -> None:
    printer.status("Preparing source manifest...")
    manifest_path = context.manifest_work
    _copy_manifest_template(context)

    document = ManifestDocument.load(manifest_path)
    modules = document.ensure_modules()

    _ensure_flutter_tag_from_modules(context, modules, printer)

    branch_applied, flutter_added, repo_overridden = _prepare_lotti_module_for_flatpak_flutter(modules, context)

    # Ensure local tool path dependencies are available to flatpak-flutter before pub get
    _ensure_local_tool_paths(context, document, printer)

    if branch_applied or flutter_added or repo_overridden:
        document.mark_changed()
    document.save()

    if context.flutter_tag:
        printer.info(f"Using Flutter tag: {context.flutter_tag}")
    if branch_applied:
        printer.info(f"Replaced app source with branch {context.current_branch}")
    if flutter_added:
        printer.info("Injected Flutter SDK git source into lotti module")
    if repo_overridden:
        printer.info(f"Using PR fork URL: {context.pr_head_url}")


def _ensure_local_tool_paths(
    context: PrepareFlathubContext, document: ManifestDocument, printer: _StatusPrinter
) -> None:
    """Inject local tool/ path deps into lotti sources for flatpak-flutter.

    flatpak-flutter runs `flutter pub get` before processing foreign.json. If the
    app depends on a local path (e.g., tool/lotti_custom_lint), ensure it's included
    as a 'dir' source so it exists under .flatpak-builder/build/<app>/tool/... when
    pub get runs.
    """
    tool_rel = Path("tool/lotti_custom_lint")
    tool_abs = context.work_dir / tool_rel
    if not tool_abs.exists():
        # Try copying from repo_root if not already staged
        repo_tool = context.repo_root / tool_rel
        if repo_tool.exists():
            try:
                _copytree(repo_tool, tool_abs)
                printer.info("Staged local tool path: tool/lotti_custom_lint")
            except Exception as exc:  # noqa: BLE001 - best effort staging, log and continue
                printer.warn(f"Failed to stage local tool path: {exc}")
    if not tool_abs.exists():
        return

    modules = document.ensure_modules()
    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue
        sources = module.setdefault("sources", [])
        already = any(
            isinstance(s, dict) and s.get("type") == "dir" and s.get("path") == str(tool_rel) for s in sources
        )
        if not already:
            sources.insert(
                0,
                {
                    "type": "dir",
                    "path": str(tool_rel),
                    "dest": str(tool_rel),
                },
            )
            document.mark_changed()
            printer.info("Injected local tool dir source: tool/lotti_custom_lint")
        break


def _ensure_setup_helper_reference(context: PrepareFlathubContext, printer: _StatusPrinter) -> None:
    document = ManifestDocument.load(context.manifest_work)
    result = manifest_ops.ensure_flutter_setup_helper(document, helper_name=context.setup_helper_basename)
    if result.changed:
        document.save()
    for message in result.messages:
        printer.info(message)


def _ensure_flatpak_flutter_repo(context: PrepareFlathubContext, printer: _StatusPrinter) -> None:
    repo_dir = context.flatpak_flutter_repo
    if repo_dir.is_dir():
        return
    printer.status("Cloning flatpak-flutter...")
    repo_dir.parent.mkdir(parents=True, exist_ok=True)
    result = _run_command(
        [
            "git",
            "clone",
            "https://github.com/TheAppgineer/flatpak-flutter.git",
            str(repo_dir),
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise PrepareFlathubError("Failed to clone flatpak-flutter: " + result.stderr.strip())


def _prepare_workspace_files(context: PrepareFlathubContext, printer: _StatusPrinter) -> None:
    printer.status("Preparing workspace inputs...")
    repo_root = context.repo_root
    work_dir = context.work_dir

    lib_src = repo_root / "lib"
    linux_src = repo_root / "linux"
    tool_src = repo_root / "tool"
    pubspec_yaml = repo_root / "pubspec.yaml"
    pubspec_lock = repo_root / "pubspec.lock"

    if not lib_src.is_dir():
        raise PrepareFlathubError(f"Expected lib directory at {lib_src}")
    if not linux_src.is_dir():
        raise PrepareFlathubError(f"Expected linux directory at {linux_src}")
    if not pubspec_yaml.is_file():
        raise PrepareFlathubError(f"Missing pubspec.yaml at {pubspec_yaml}")
    if not pubspec_lock.is_file():
        raise PrepareFlathubError(f"Missing pubspec.lock at {pubspec_lock}")

    _copytree(lib_src, work_dir / "lib")
    _copytree(linux_src, work_dir / "linux")
    # Copy local tool/ path dependencies (e.g., tool/lotti_custom_lint) so flatpak-flutter pub get resolves
    if tool_src.is_dir():
        _copytree(tool_src, work_dir / "tool")
        # Write foreign.json to have flatpak-flutter embed local tool paths into the app sources
        try:
            foreign_json = {
                "app_local_paths": {
                    "manifest": {
                        "sources": [
                            {
                                "type": "dir",
                                "path": "tool/lotti_custom_lint",
                                "dest": "$APP/tool/lotti_custom_lint",
                            }
                        ]
                    }
                }
            }
            (work_dir / "foreign.json").write_text(json.dumps(foreign_json, indent=2) + "\n", encoding="utf-8")
        except Exception as exc:  # noqa: BLE001 - best effort hint file
            printer.warn(f"Failed to write foreign.json: {exc}")
    _copyfile(pubspec_yaml, work_dir / "pubspec.yaml")
    _copyfile(pubspec_lock, work_dir / "pubspec.lock")

    helper_source = context.setup_helper_source
    if not helper_source.is_file():
        raise PrepareFlathubError(f"Setup helper script not found at {helper_source}")
    helper_target = work_dir / context.setup_helper_basename
    _copyfile(helper_source, helper_target)
    helper_target.chmod(helper_target.stat().st_mode | stat.S_IEXEC)

    build_root = work_dir / ".flatpak-builder" / "build"
    build_root.mkdir(parents=True, exist_ok=True)
    for name in ("lotti", "lotti-1"):
        build_dir = build_root / name
        build_dir.mkdir(parents=True, exist_ok=True)
        _copyfile(work_dir / "pubspec.yaml", build_dir / "pubspec.yaml")
        _copyfile(work_dir / "pubspec.lock", build_dir / "pubspec.lock")
        foreign = build_dir / "foreign_deps.json"
        if not foreign.exists():
            foreign.write_text("{}\n", encoding="utf-8")


def _prime_flutter_sdk(context: PrepareFlathubContext, printer: _StatusPrinter) -> None:
    target_dir = context.work_dir / ".flatpak-builder" / "build" / "lotti" / "flutter"
    flutter_bin = target_dir / "bin" / "flutter"

    if flutter_bin.is_file() and os.access(flutter_bin, os.X_OK):
        return

    printer.status(f"Priming Flutter SDK at {target_dir} (tag {context.flutter_tag})...")
    target_dir.mkdir(parents=True, exist_ok=True)

    local_candidate = _resolve_cached_flutter_sdk(context, target_dir)
    if local_candidate:
        _copy_cached_flutter_sdk(local_candidate, target_dir, printer)

    if not flutter_bin.is_file() and not _clone_flutter_sdk_from_remote(context, printer, target_dir):
        printer.warn("Failed to provision Flutter SDK; flatpak-flutter will attempt its own clone.")
        return

    _verify_flutter_sdk_version(flutter_bin, target_dir)


def _run_flatpak_flutter(context: PrepareFlathubContext, printer: _StatusPrinter) -> None:
    printer.status("Running flatpak-flutter to generate offline sources...")
    if context.options.no_flatpak_flutter:
        printer.info("Skipping flatpak-flutter run (NO_FLATPAK_FLUTTER=true); using fallback generation paths")
        context.flatpak_flutter_status = 124
        return

    script_path = context.flatpak_flutter_repo / "flatpak-flutter.py"
    if not script_path.is_file():
        raise PrepareFlathubError(f"flatpak-flutter.py not found at {script_path}")

    cmd = [
        sys.executable,
        str(script_path),
        "--app-module",
        "lotti",
        "--keep-build-dirs",
        context.manifest_work.name,
    ]

    env = dict(os.environ)
    env["GIT_TERMINAL_PROMPT"] = "0"

    timeout = context.options.flatpak_flutter_timeout
    log_output = ""
    try:
        result = _run_command(
            cmd,
            cwd=context.work_dir,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=timeout,
            check=False,
        )
        context.flatpak_flutter_status = result.returncode
        log_output = result.stdout or ""
    except subprocess.TimeoutExpired as exc:
        context.flatpak_flutter_status = 124
        log_output = (exc.output or "") + (exc.stderr or "")
        printer.warn(f"flatpak-flutter timed out after {timeout}s; proceeding with fallback generation")

    context.flatpak_flutter_log.write_text(log_output, encoding="utf-8")
    if context.flatpak_flutter_status == 0:
        printer.status("Generated offline manifest and dependencies")
    else:
        printer.warn(
            f"flatpak-flutter exited with {context.flatpak_flutter_status}; proceeding with fallback generation"
        )
        printer.info(f"Check {context.flatpak_flutter_log} for details")


def _normalize_sqlite_patch(context: PrepareFlathubContext, printer: _StatusPrinter) -> None:
    patch_path = context.work_dir / "sqlite3_flutter_libs" / "0.5.34-CMakeLists.txt.patch"
    if not patch_path.is_file():
        return
    content = patch_path.read_text(encoding="utf-8")
    new_content = re.sub(r"sqlite-autoconf-350[0-9]{4}", _SQLITE_AUTOCONF_VERSION, content)
    new_content = re.sub(
        r"SHA256=[0-9a-f]{64}",
        f"SHA256={_SQLITE_AUTOCONF_SHA256}",
        new_content,
    )
    if new_content != content:
        patch_path.write_text(new_content, encoding="utf-8")
        printer.info("Normalized sqlite3 patch to target version " f"{_SQLITE_AUTOCONF_VERSION}")


def _assert_commit_pinned(manifest_path: Path, label: str) -> None:
    text = manifest_path.read_text(encoding="utf-8")
    if "COMMIT_PLACEHOLDER" in text:
        raise PrepareFlathubError(f"{label} manifest contains COMMIT_PLACEHOLDER; final manifest must be commit-pinned")
    if re.search(r"^\s*branch:\s", text, re.MULTILINE):
        raise PrepareFlathubError(f"{label} manifest contains branch entries; final manifest must be commit-pinned")


def _pin_working_manifest(context: PrepareFlathubContext, printer: _StatusPrinter) -> None:
    target_commit = context.pr_head_commit or context.app_commit
    printer.status(f"Pinning working manifest to commit: {target_commit}")
    document = ManifestDocument.load(context.manifest_work)
    result = manifest_ops.pin_commit(document, commit=target_commit)
    if result.changed:
        document.save()
    _assert_commit_pinned(context.manifest_work, "Working")


def _copy_generated_artifacts(context: PrepareFlathubContext, printer: _StatusPrinter) -> None:
    printer.status("Creating flathub manifest...")
    output_dir = context.output_dir
    work_dir = context.work_dir

    _assert_commit_pinned(context.manifest_work, "Generated")
    _copyfile(context.manifest_work, output_dir / context.manifest_work.name)

    def _copy_pattern(pattern: str, warn: str) -> None:
        matches = list(work_dir.glob(pattern))
        if not matches:
            printer.warn(warn)
            return
        for match in matches:
            if match.is_file():
                _copyfile(match, output_dir / match.name)

    _copy_pattern("flutter-sdk-*.json", "No flutter-sdk JSON found")
    _copy_pattern("pubspec-sources.json", "No pubspec-sources.json found")
    _copy_pattern("cargo-sources.json", "No cargo-sources.json found")
    _copy_pattern(
        "rustup-*.json",
        "No rustup JSON found (will rely on SDK extension if not present)",
    )
    _copy_pattern("package_config.json", "No package_config.json found")

    helper_target = work_dir / context.setup_helper_basename
    if helper_target.is_file():
        _copyfile(helper_target, output_dir / context.setup_helper_basename)

    patterns = [
        "**/.flatpak-builder/**/pubspec-sources.json",
        "**/.flatpak-builder/**/cargo-sources.json",
        "**/.flatpak-builder/**/flutter-sdk-*.json",
    ]

    search_roots = {work_dir, work_dir.parent.resolve()}
    for root in search_roots:
        if not root.exists():
            continue
        for pattern in patterns:
            for path in root.glob(pattern):
                if not path.is_file():
                    continue
                dest = output_dir / path.name
                try:
                    _copyfile(path, dest)
                    printer.info(f"Bundled {path.name}")
                except FileNotFoundError:
                    continue


def _stage_pubdev_archive(
    context: PrepareFlathubContext,
    printer: _StatusPrinter,
    package: str,
    version: str,
) -> None:
    dest = context.flatpak_dir / "cache" / "pub.dev" / f"{package}-{version}.tar.gz"
    if dest.exists():
        return

    candidates = [
        context.repo_root / ".pub-cache" / "hosted" / "pub.dev" / f"{package}-{version}",
        Path.home() / ".pub-cache" / "hosted" / "pub.dev" / f"{package}-{version}",
    ]

    pub_cache_env = context.env.get("PUB_CACHE")
    if pub_cache_env:
        candidates.append(Path(pub_cache_env) / "hosted" / "pub.dev" / f"{package}-{version}")

    # Also search any local pub caches created by flatpak-flutter under the work directory
    # e.g., .flatpak-builder/build/lotti/.pub-cache/hosted/pub.dev/<package>-<version>
    build_root = context.work_dir / ".flatpak-builder" / "build"
    if build_root.is_dir():
        try:
            for path in build_root.glob(f"**/.pub-cache/hosted/pub.dev/{package}-{version}"):
                if path.is_dir():
                    candidates.append(path)
        except OSError:
            pass

    for candidate in candidates:
        if candidate.is_dir():
            dest.parent.mkdir(parents=True, exist_ok=True)
            with tarfile.open(dest, "w:gz") as tar:
                tar.add(candidate, arcname=candidate.name)
            printer.info(f"Staged pub.dev archive {package}-{version} from {candidate}")
            return

    printer.warn(f"Missing staged pub.dev archive for {package}-{version}; offline bundling may fail")


def _find_flutter_tools_lock(context: PrepareFlathubContext) -> Path | None:
    search_dirs = [context.work_dir / ".flatpak-builder" / "build"]
    for base in search_dirs:
        if not base.is_dir():
            continue
        for path in base.glob("**/flutter/packages/flutter_tools/pubspec.lock"):
            return path
    cache_lock = context.flatpak_dir / "cache" / "flutter_tools" / "pubspec.lock"
    if cache_lock.is_file():
        return cache_lock
    return None


def _find_cargokit_locks(context: PrepareFlathubContext) -> list[Path]:
    locks: list[Path] = []
    for base in (
        context.work_dir / ".flatpak-builder" / "build",
        context.output_dir / ".flatpak-builder" / "build",
    ):
        if not base.is_dir():
            continue
        locks.extend(base.glob("**/cargokit/build_tool/pubspec.lock"))
    return sorted({lock.resolve() for lock in locks})


def _find_preset_cargokit_locks(context: PrepareFlathubContext) -> list[Path]:
    cache_dir = context.flatpak_dir / "cache" / "cargokit"
    if not cache_dir.is_dir():
        return []
    return sorted(cache_dir.glob("*.pubspec.lock"))


def _collect_pubspec_lock_inputs(context: PrepareFlathubContext) -> list[Path]:
    app_lock = context.work_dir / "pubspec.lock"
    if not app_lock.is_file():
        raise PrepareFlathubError(f"FATAL: Application pubspec.lock not found at: {app_lock}")

    lock_inputs: list[Path] = [app_lock]

    tools_lock = _find_flutter_tools_lock(context)
    if tools_lock:
        lock_inputs.append(tools_lock)

    lock_inputs.extend(_find_cargokit_locks(context))
    lock_inputs.extend(_find_preset_cargokit_locks(context))

    if not lock_inputs:
        raise PrepareFlathubError("FATAL: No lockfiles found for pubspec-sources.json generation")

    return lock_inputs


def _run_pubspec_sources_generator(context: PrepareFlathubContext, lock_inputs: list[Path]) -> Path:
    generator = context.flatpak_flutter_repo / "pubspec_generator" / "pubspec_generator.py"
    if not generator.is_file():
        raise PrepareFlathubError(f"pubspec_generator not found at {generator}")

    output_tmp = context.work_dir / "pubspec-sources.generated.json"
    command = [
        sys.executable,
        str(generator),
        ",".join(str(path) for path in lock_inputs),
        "-o",
        str(output_tmp),
    ]
    result = _run_command(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        check=False,
    )
    if result.returncode != 0 or not output_tmp.is_file():
        raise PrepareFlathubError("Failed to generate pubspec-sources.json:\n" + (result.stdout or ""))

    final_path = context.output_dir / "pubspec-sources.json"
    _copyfile(output_tmp, final_path)
    output_tmp.unlink(missing_ok=True)
    return final_path


def _stage_packages_from_pubspec_json(
    context: PrepareFlathubContext,
    printer: _StatusPrinter,
    json_path: Path,
) -> None:
    if not json_path.is_file():
        raise PrepareFlathubError("pubspec-sources.json missing after preparation; offline bundle is incomplete")

    data = json.loads(json_path.read_text(encoding="utf-8"))
    seen: set[tuple[str, str]] = set()
    for entry in data:
        if not isinstance(entry, dict):
            continue
        dest = entry.get("dest", "")
        if not dest.startswith(".pub-cache/hosted/pub.dev/"):
            continue
        package, version = _split_package_version(dest)
        if not package:
            continue
        key = (package, version)
        if key in seen:
            continue
        seen.add(key)
        _stage_pubdev_archive(context, printer, package, version)


def _split_package_version(dest: str) -> tuple[str, str]:
    name_version = dest.split("/")[-1]
    if "-" not in name_version:
        return "", ""
    package, version = name_version.split("-", 1)
    for suffix in (".tar.gz", ".tgz", ".tar", ".zip"):
        if version.endswith(suffix):
            version = version[: -len(suffix)]
            break
    return package, version


def _regenerate_pubspec_sources_if_needed(context: PrepareFlathubContext, printer: _StatusPrinter) -> None:
    # If flatpak-flutter succeeded and already produced pubspec-sources.json, keep it.
    existing = context.output_dir / "pubspec-sources.json"
    if context.flatpak_flutter_status == 0 and existing.is_file():
        printer.info("Using pubspec-sources.json from flatpak-flutter")
        _stage_packages_from_pubspec_json(context, printer, existing)
        return

    # Otherwise, generate from available lockfiles (best-effort fallback)
    lock_inputs = _collect_pubspec_lock_inputs(context)
    printer.info("Generating pubspec-sources.json from lockfiles")
    final_path = _run_pubspec_sources_generator(context, lock_inputs)
    printer.status("Regenerated pubspec-sources.json with build tool dependencies")
    _stage_packages_from_pubspec_json(context, printer, final_path)


def _apply_core_manifest_fixes(document: ManifestDocument, printer: _StatusPrinter) -> None:
    _apply_operation(document, printer, flutter.remove_network_from_build_args)
    _apply_operation(document, printer, flutter.remove_flutter_config_command)
    _apply_operation(document, printer, flutter.ensure_flutter_pub_get_offline)
    _apply_operation(document, printer, flutter.ensure_dart_pub_offline_in_build)
    _apply_operation(document, printer, flutter.remove_rustup_install)
    # Ensure Rust toolchain from SDK extension is available on PATH
    _apply_operation(document, printer, flutter.ensure_rust_sdk_env)
    _apply_operation(document, printer, flutter.apply_all_offline_fixes)
    _apply_operation(
        document,
        printer,
        manifest_ops.ensure_screenshot_asset,
        screenshot_source="screenshot.png",
        install_path="/app/share/app-info/screenshots/com.matthiasn.lotti/main.png",
    )


def _collect_rustup_json_names(context: PrepareFlathubContext) -> list[str]:
    return [p.name for p in context.output_dir.glob("rustup-*.json")]


def _include_rustup_modules(
    document: ManifestDocument,
    printer: _StatusPrinter,
    rustup_modules: Iterable[str],
) -> None:
    for rustup_json in rustup_modules:
        _apply_operation(
            document,
            printer,
            manifest_ops.ensure_module_include,
            module_name=rustup_json,
            before_name="lotti",
        )


def _pin_manifest_if_requested(
    document: ManifestDocument,
    context: PrepareFlathubContext,
    printer: _StatusPrinter,
) -> None:
    if context.options.pin_commit:
        _apply_operation(
            document,
            printer,
            manifest_ops.pin_commit,
            commit=context.app_commit,
        )


def _maybe_apply_nested_flutter(
    document: ManifestDocument,
    context: PrepareFlathubContext,
    printer: _StatusPrinter,
) -> None:
    if context.options.use_nested_flutter:
        _apply_operation(
            document,
            printer,
            flutter.ensure_nested_sdk,
            output_dir=str(context.output_dir),
        )


def _first_matching_file(directory: Path, pattern: str) -> Optional[str]:
    for path in sorted(directory.glob(pattern)):
        if path.is_file():
            return path.name
    return None


def _add_offline_sources_to_manifest(
    document: ManifestDocument,
    printer: _StatusPrinter,
    rustup_modules: list[str],
    flutter_json_name: Optional[str],
    context: PrepareFlathubContext,
) -> None:
    pubspec_json = "pubspec-sources.json" if (context.output_dir / "pubspec-sources.json").is_file() else None
    cargo_json = "cargo-sources.json" if (context.output_dir / "cargo-sources.json").is_file() else None

    _apply_operation(
        document,
        printer,
        sources_ops.add_offline_sources,
        pubspec=pubspec_json,
        cargo=cargo_json,
        rustup=rustup_modules,
        flutter_file=flutter_json_name if context.options.use_nested_flutter else None,
    )


def _apply_layout_adjustments(
    document: ManifestDocument,
    context: PrepareFlathubContext,
    printer: _StatusPrinter,
    layout: str,
) -> None:
    flutter_bin = "/var/lib/flutter/bin" if layout == "nested" else "/app/flutter/bin"
    working_dir = "/var/lib" if layout == "nested" else "/app"

    _apply_operation(
        document,
        printer,
        flutter.normalize_lotti_env,
        flutter_bin=flutter_bin,
        ensure_append_path=True,
    )

    source_result = flutter.ensure_setup_helper_source(document, helper_name=context.setup_helper_basename)
    command_result = flutter.ensure_setup_helper_command(
        document,
        working_dir=working_dir,
    )
    if source_result.changed or command_result.changed:
        document.save()
    for message in (*source_result.messages, *command_result.messages):
        printer.info(message)


def _finalize_manifest_adjustments(
    document: ManifestDocument,
    printer: _StatusPrinter,
) -> None:
    _apply_operation(document, printer, flutter.normalize_sdk_copy)
    _apply_operation(document, printer, sources_ops.remove_rustup_sources)


def _stage_package_config(context: PrepareFlathubContext, printer: _StatusPrinter) -> None:
    tools_lock = _find_flutter_tools_lock(context)
    output_path = context.output_dir / "package_config.json"

    if tools_lock and tools_lock.is_file():
        tools_dir = tools_lock.parent
        pkg_config = tools_dir / ".dart_tool" / "package_config.json"
        if pkg_config.is_file():
            _copyfile(pkg_config, output_path)
            return

    fallback = None
    search_root = context.work_dir / ".flatpak-builder" / "build"
    if search_root.is_dir():
        for path in search_root.glob("**/flutter/packages/flutter_tools/.dart_tool/package_config.json"):
            fallback = path
            break
    if fallback and fallback.is_file():
        _copyfile(fallback, output_path)
    else:
        printer.warn("Could not locate flutter_tools package_config.json for offline cache")


def _ensure_flutter_json(context: PrepareFlathubContext, printer: _StatusPrinter) -> None:
    output_dir = context.output_dir
    if list(output_dir.glob("flutter-sdk-*.json")):
        return

    printer.warn("No flutter-sdk JSON produced by flatpak-flutter; generating locally...")
    generator = context.flatpak_flutter_repo / "flutter_sdk_generator" / "flutter_sdk_generator.py"
    if not generator.is_file():
        printer.warn("flutter_sdk_generator not found; skipping generation")
        return

    input_dir = context.work_dir / ".flatpak-builder" / "build" / "lotti" / "flutter"
    flutter_bin = input_dir / "bin" / "flutter"
    if not flutter_bin.is_file():
        printer.warn(f"Primed Flutter SDK not found at {input_dir}; cannot generate flutter-sdk JSON")
        return

    output_path = output_dir / f"flutter-sdk-{context.flutter_tag}.json"
    result = _run_command(
        [sys.executable, str(generator), str(input_dir), "-o", str(output_path)],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        printer.warn("Failed to generate flutter-sdk JSON: " + (result.stdout or ""))
        if output_path.exists():
            output_path.unlink()
        return
    printer.status(f"Generated {output_path}")


def _run_cargo_generator(context: PrepareFlathubContext, inputs: list[Path], output_path: Path) -> bool:
    generator = context.flatpak_flutter_repo / "cargo_generator" / "cargo_generator.py"
    if not generator.is_file():
        return False
    command = [
        sys.executable,
        str(generator),
        ",".join(str(path) for path in inputs),
        "-o",
        str(output_path),
    ]
    result = _run_command(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        return False
    return output_path.is_file()


def _apply_operation(
    document: ManifestDocument,
    printer: _StatusPrinter,
    func,
    **kwargs,
) -> None:
    result = func(document, **kwargs)
    if result.changed:
        document.save()
    for message in result.messages:
        printer.info(message)


def _apply_manifest_compliance(context: PrepareFlathubContext, printer: _StatusPrinter) -> None:
    printer.status("Applying Flathub compliance fixes...")
    manifest_path = context.output_dir / context.manifest_work.name
    if not manifest_path.is_file():
        raise PrepareFlathubError(f"Output manifest not found at {manifest_path}")

    document = ManifestDocument.load(manifest_path)
    _apply_core_manifest_fixes(document, printer)


def _copy_assets_and_metadata(context: PrepareFlathubContext, printer: _StatusPrinter) -> None:
    printer.status("Copying additional files...")
    _write_metainfo_files(context)
    _copy_desktop_file(context, printer)
    _copy_icons(context)
    _copy_screenshots(context)
    _copy_fontconfig(context, printer)
    _copy_flutter_patches(context, printer)
    _copy_prebuilt_patches(context)
    _copy_helper_directories(context)


def _write_metainfo_files(context: PrepareFlathubContext) -> None:
    flatpak_dir = context.flatpak_dir
    output_dir = context.output_dir
    work_dir = context.work_dir
    metainfo_src = flatpak_dir / "com.matthiasn.lotti.metainfo.xml"
    if not metainfo_src.is_file():
        return
    text = metainfo_src.read_text(encoding="utf-8")
    text = text.replace("{{LOTTI_VERSION}}", context.lotti_version)
    text = text.replace("{{LOTTI_RELEASE_DATE}}", context.release_date)
    output_dir.joinpath("com.matthiasn.lotti.metainfo.xml").write_text(text, encoding="utf-8")
    work_dir.joinpath("com.matthiasn.lotti.metainfo.xml").write_text(text, encoding="utf-8")


def _copy_desktop_file(context: PrepareFlathubContext, printer: _StatusPrinter) -> None:
    desktop_src = context.flatpak_dir / "com.matthiasn.lotti.desktop"
    if desktop_src.is_file():
        _copyfile(desktop_src, context.output_dir / desktop_src.name)
        _copyfile(desktop_src, context.work_dir / desktop_src.name)
    else:
        printer.warn("No desktop file found")


def _copy_icons(context: PrepareFlathubContext) -> None:
    for icon in context.flatpak_dir.glob("app_icon_*.png"):
        if icon.is_file():
            _copyfile(icon, context.output_dir / icon.name)
            _copyfile(icon, context.work_dir / icon.name)


def _copy_screenshots(context: PrepareFlathubContext) -> None:
    screenshot = context.screenshot_source
    if not screenshot.is_file():
        raise PrepareFlathubError(
            "Screenshot asset is missing: "
            f"expected {screenshot} relative to {context.flatpak_dir}. "
            "Provide flatpak/screenshot.png before running the Flathub prep."
        )

    _copyfile(screenshot, context.output_dir / screenshot.name)
    _copyfile(screenshot, context.work_dir / screenshot.name)


def _copy_fontconfig(context: PrepareFlathubContext, printer: _StatusPrinter) -> None:
    fontconfig = context.flatpak_dir / "75-noto-color-emoji.conf"
    if fontconfig.is_file():
        _copyfile(fontconfig, context.output_dir / fontconfig.name)
        _copyfile(fontconfig, context.work_dir / fontconfig.name)
        printer.info("Copied emoji fontconfig file")
    else:
        printer.warn("Emoji fontconfig file not found at flatpak/75-noto-color-emoji.conf")


def _copy_flutter_patches(context: PrepareFlathubContext, printer: _StatusPrinter) -> None:
    out_manifest = context.output_dir / context.manifest_work.name
    for patch_name in (
        "flutter-shared.sh.patch",
        "flutter-pre-3_35-shared.sh.patch",
    ):
        patch_source = _find_flutter_patch(context, patch_name)
        if patch_source:
            _copyfile(patch_source, context.output_dir / patch_name)
            _copyfile(patch_source, context.work_dir / patch_name)
            replaced = sources_ops.replace_url_with_path(
                manifest_path=str(out_manifest),
                identifier=patch_name,
                path_value=patch_name,
            )
            if replaced:
                printer.info(f"Bundled Flutter patch {patch_name}")
        elif out_manifest.is_file() and patch_name in out_manifest.read_text(encoding="utf-8"):
            printer.warn(f"Referenced Flutter patch {patch_name} not found in flatpak-flutter sources")


def _find_flutter_patch(context: PrepareFlathubContext, patch_name: str) -> Optional[Path]:
    releases_candidate = context.flatpak_flutter_repo / "releases" / "flutter" / patch_name
    if releases_candidate.is_file():
        return releases_candidate
    direct_candidate = context.flatpak_flutter_repo / patch_name
    if direct_candidate.is_file():
        return direct_candidate
    return None


def _copy_prebuilt_patches(context: PrepareFlathubContext) -> None:
    patches_dir = context.flatpak_dir / "patches"
    if patches_dir.is_dir():
        _copytree(patches_dir, context.output_dir / "patches")


def _copy_helper_directories(context: PrepareFlathubContext) -> None:
    foreign_deps_root = context.flatpak_flutter_repo / "foreign_deps"
    for helper_dir in ("sqlite3_flutter_libs", "cargokit"):
        helper_source = context.work_dir / helper_dir
        if not helper_source.is_dir():
            fallback_source = foreign_deps_root / helper_dir
            helper_source = fallback_source if fallback_source.is_dir() else None
        if helper_source and helper_source.is_dir():
            _copytree(helper_source, context.output_dir / helper_dir)


def _remove_flutter_sdk_module(document: ManifestDocument) -> bool:
    modules = document.ensure_modules()
    new_modules = [
        module for module in modules if not (isinstance(module, dict) and module.get("name") == "flutter-sdk")
    ]
    if len(new_modules) != len(modules):
        document.data["modules"] = new_modules
        document.mark_changed()
        return True
    return False


def _ensure_flutter_archive(
    context: PrepareFlathubContext,
    printer: _StatusPrinter,
    document: ManifestDocument,
) -> None:
    if list(context.output_dir.glob("flutter-sdk-*.json")):
        return

    tag = context.flutter_tag or "stable"
    archive_basename = f"flutter_linux_{tag}-stable.tar.xz"
    archive_target = context.output_dir / archive_basename
    archive_source = _find_existing_flutter_archive(context, tag)

    if not archive_source and context.options.download_missing_sources:
        archive_source = _download_flutter_archive(context, printer, tag, archive_target)

    if not archive_source:
        printer.warn("No cached Flutter archive found; flutter-sdk module will continue to reference upstream git")
        return

    if archive_source != archive_target:
        _copyfile(archive_source, archive_target)

    sha = _file_sha256(archive_target)
    _apply_operation(
        document,
        printer,
        flutter.convert_flutter_git_to_archive,
        archive_name=archive_target.name,
        sha256=sha,
    )
    printer.info(f"Bundled Flutter archive {archive_target.name} for offline builds")


def _find_existing_flutter_archive(context: PrepareFlathubContext, tag: str) -> Optional[Path]:
    archive_target = context.output_dir / f"flutter_linux_{tag}-stable.tar.xz"
    if archive_target.is_file():
        return archive_target

    search_roots = [
        context.output_dir,
        context.flatpak_dir / ".flatpak-builder",
        context.repo_root / ".flatpak-builder",
        context.repo_root.parent / ".flatpak-builder",
    ]
    pattern = f"**/flutter_*{tag}*.tar*"
    for root in search_roots:
        if not root.exists():
            continue
        for candidate in root.glob(pattern):
            if candidate.is_file():
                return candidate
    return None


def _download_flutter_archive(
    context: PrepareFlathubContext,
    printer: _StatusPrinter,
    tag: str,
    archive_target: Path,
) -> Optional[Path]:
    url = (
        "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/"
        f"flutter_linux_{tag}-stable.tar.xz"
    )
    printer.info(f"Downloading Flutter archive {archive_target.name}")
    try:
        _download_https_resource(url, archive_target)
        return archive_target
    except (
        urllib.error.URLError,
        socket.timeout,
    ) as exc:  # pragma: no cover - network failure
        printer.warn(f"Failed to download Flutter archive from {url}: {exc}")
        return None


def _download_https_resource(url: str, destination: Path) -> None:
    parsed = urlparse(url)
    if parsed.scheme.lower() not in _ALLOWED_URL_SCHEMES:
        raise PrepareFlathubError(f"Unsupported scheme for HTTPS download: {url}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(url)
    with urllib.request.urlopen(request, timeout=60) as response:  # nosec B310
        with destination.open("wb") as handle:
            shutil.copyfileobj(response, handle)


def _resolve_cached_flutter_sdk(context: PrepareFlathubContext, target_dir: Path) -> Optional[Path]:
    local_candidate = context.cached_flutter_dir
    try:
        if local_candidate and local_candidate.resolve() == target_dir.resolve():
            local_candidate = None
    except FileNotFoundError:
        local_candidate = None

    if local_candidate:
        return local_candidate

    return build_utils.find_flutter_sdk(
        search_roots=[context.repo_root],
        exclude_paths=[context.work_dir, target_dir],
        max_depth=6,
    )


def _copy_cached_flutter_sdk(source: Path, target_dir: Path, printer: _StatusPrinter) -> None:
    printer.info(f"Using cached Flutter SDK from {source}")
    for child in list(target_dir.iterdir()):
        if child.is_dir() and not child.is_symlink():
            shutil.rmtree(child)
        else:
            child.unlink()
    shutil.copytree(source, target_dir, dirs_exist_ok=True)


def _clone_flutter_sdk_from_remote(
    context: PrepareFlathubContext,
    printer: _StatusPrinter,
    target_dir: Path,
) -> bool:
    printer.warn("Cached Flutter SDK not available; attempting shallow clone from remote.")
    tag = context.flutter_tag or "stable"
    result = _run_command(
        [
            "git",
            "clone",
            "--depth",
            "1",
            "--branch",
            tag,
            context.flutter_git_url,
            str(target_dir),
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    return result.returncode == 0


def _verify_flutter_sdk_version(flutter_bin: Path, target_dir: Path) -> None:
    _run_command(
        [str(flutter_bin), "--version"],
        cwd=target_dir,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def _fallback_cargo_sources_from_presets(context: PrepareFlathubContext, printer: _StatusPrinter) -> bool:
    output_path = context.output_dir / "cargo-sources.json"
    preset_dir = context.flatpak_dir / "cargo-lock-files"
    if not preset_dir.is_dir():
        return False
    inputs = [path for path in preset_dir.glob("*.lock") if path.is_file()]
    if not inputs:
        return False
    if _run_cargo_generator(context, inputs, context.work_dir / "cargo-sources-cargokit.json"):
        _copyfile(
            context.work_dir / "cargo-sources-cargokit.json",
            output_path,
        )
        printer.status("Generated cargo-sources.json from pre-saved Cargo.lock files")
        return True
    printer.warn("Failed to generate cargo-sources.json from pre-saved Cargo.lock files")
    return False


def _fallback_cargo_sources_from_builder(context: PrepareFlathubContext, printer: _StatusPrinter) -> bool:
    build_dir = context.work_dir / ".flatpak-builder" / "build"
    if not build_dir.is_dir():
        return False
    patterns = [
        "**/.pub-cache/hosted/pub.dev/*/rust/Cargo.lock",
        "**/.pub-cache/hosted/pub.dev/*/android/rust/Cargo.lock",
        "**/.pub-cache/hosted/pub.dev/*/ios/rust/Cargo.lock",
        "**/.pub-cache/hosted/pub.dev/*/linux/rust/Cargo.lock",
        "**/.pub-cache/hosted/pub.dev/*/macos/rust/Cargo.lock",
        "**/.pub-cache/hosted/pub.dev/*/windows/rust/Cargo.lock",
    ]
    locks: set[Path] = set()
    for pattern in patterns:
        for path in build_dir.glob(pattern):
            if path.is_file():
                try:
                    locks.add(path.resolve())
                except FileNotFoundError:
                    continue
    if not locks:
        printer.warn("No Cargo.lock files found under .flatpak-builder; skipping cargo-sources generation")
        return False
    unique_locks = sorted(locks)
    printer.info(f"Found {len(unique_locks)} cargokit Cargo.lock file(s)")
    temp_output = context.work_dir / "cargo-sources-cargokit.json"
    if _run_cargo_generator(context, unique_locks, temp_output):
        _copyfile(temp_output, context.output_dir / "cargo-sources.json")
        printer.status("Generated cargo-sources.json from cargokit Cargo.lock files")
        return True
    printer.warn("Failed to generate cargo-sources.json from cargokit Cargo.lock files")
    return False


def _download_cargo_lock_files(
    context: PrepareFlathubContext,
    printer: _StatusPrinter,
    fetcher: Optional[Callable[[str, Path], None]] = None,
) -> list[Path]:
    fetch = fetcher or _download_https_resource
    output_dir = context.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    downloaded: list[Path] = []
    for name, url in CARGO_LOCK_SOURCES:
        destination = output_dir / f"{name}-Cargo.lock"
        printer.info(f"Downloading {name} Cargo.lock...")
        try:
            fetch(url, destination)
        except (PrepareFlathubError, urllib.error.URLError, socket.timeout) as exc:
            printer.warn(f"Failed to download {name} Cargo.lock from {url}: {exc}")
            destination.unlink(missing_ok=True)
            continue

        try:
            content = destination.read_text("utf-8", errors="ignore")
        except OSError as exc:
            printer.warn(f"Failed to read downloaded Cargo.lock for {name}: {exc}")
            destination.unlink(missing_ok=True)
            continue

        if "[package]" not in content:
            printer.warn(f"Downloaded file for {name} did not look like a Cargo.lock; removing")
            destination.unlink(missing_ok=True)
            continue

        printer.status(f"Downloaded {destination.name}")
        downloaded.append(destination)

    return downloaded


def _download_and_generate_cargo_sources(context: PrepareFlathubContext, printer: _StatusPrinter) -> None:
    printer.info("Downloading Cargo.lock files from GitHub to generate correct cargo-sources.json...")
    downloaded_locks = _download_cargo_lock_files(context, printer)

    if downloaded_locks:
        cargo_json = context.output_dir / "cargo-sources.json"
        if _run_cargo_generator(context, downloaded_locks, cargo_json):
            printer.status("Generated cargo-sources.json from downloaded Cargo.lock files")
            with cargo_json.open(encoding="utf-8") as fh:
                line_count = sum(1 for _ in fh)
            printer.info(f"Line count: {line_count}")
            return
        printer.warn("Failed to generate cargo-sources.json from downloaded files")

    cargo_json = context.output_dir / "cargo-sources.json"
    if cargo_json.is_file():
        return
    if _fallback_cargo_sources_from_presets(context, printer):
        return
    _fallback_cargo_sources_from_builder(context, printer)


def _post_process_output_manifest(context: PrepareFlathubContext, printer: _StatusPrinter) -> None:
    printer.status("Post-processing output manifest...")
    manifest_path = context.output_dir / context.manifest_work.name
    if not manifest_path.is_file():
        raise PrepareFlathubError(f"Output manifest not found at {manifest_path}")

    document = ManifestDocument.load(manifest_path)
    _apply_core_manifest_fixes(document, printer)

    rustup_modules = _collect_rustup_json_names(context)
    _include_rustup_modules(document, printer, rustup_modules)
    _pin_manifest_if_requested(document, context, printer)
    _maybe_apply_nested_flutter(document, context, printer)

    flutter_json_name = _first_matching_file(context.output_dir, "flutter-sdk-*.json")
    remove_flutter = flutter.should_remove_flutter_sdk(document, output_dir=context.output_dir)
    if remove_flutter:
        if _remove_flutter_sdk_module(document):
            document.save()
        printer.info("Offline Flutter JSON found and referenced; removing top-level flutter-sdk module.")
    else:
        printer.info("Keeping top-level flutter-sdk module (offline JSON missing or not referenced).")

    _apply_operation(document, printer, flutter.normalize_flutter_sdk_module)
    _add_offline_sources_to_manifest(document, printer, rustup_modules, flutter_json_name, context)

    # Ensure plugin toolchain sources that normally fetch at configure time are provided offline.
    # 1) sqlite3_flutter_libs downloads SQLite – add as file sources for each arch.
    # 2) media_kit_libs_linux downloads mimalloc – add as file sources.
    _apply_operation(document, printer, flutter.add_sqlite3_source)
    _apply_operation(document, printer, flutter.add_media_kit_mimalloc_source)

    # Ensure cargokit patches are applied after dependency sources have been included
    # to avoid 'patch: File to patch' interactive prompts when files are not yet present.
    _ensure_cargokit_patches_after_dependency_sources(document, printer)

    layout = "nested" if remove_flutter else "top"
    _apply_layout_adjustments(document, context, printer, layout)
    _finalize_manifest_adjustments(document, printer)

    # Remove any local dir sources (e.g., tool/lotti_custom_lint) from final submission manifest
    _remove_local_dir_sources(document, printer)

    # Ensure pubspec-sources.json includes exact pinned pub packages needed by cargokit build tools.
    # Some plugin versions pin yaml=3.1.2, which may not be included by default generators when only 3.1.3 exists.
    _ensure_pub_package_in_pubspec_sources(context, printer, name="yaml", version="3.1.2")

    document.save()


def _ensure_pub_package_in_pubspec_sources(
    context: PrepareFlathubContext, printer: _StatusPrinter, *, name: str, version: str
) -> None:
    json_path = context.output_dir / "pubspec-sources.json"
    if not json_path.is_file():
        return

    try:
        data = json.loads(json_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return

    target_dest = f".pub-cache/hosted/pub.dev/{name}-{version}"
    present = False
    for entry in data:
        if not isinstance(entry, dict):
            continue
        if entry.get("dest") == target_dest:
            present = True
            break
    if present:
        return

    # Fetch archive to compute SHA256 (preparation stage allows network)
    url = f"https://pub.dev/api/archives/{name}-{version}.tar.gz"
    tmp_path = context.work_dir / f"{name}-{version}.tar.gz"
    try:
        _download_https_resource(
            url=url,
            destination=tmp_path,
        )
    except Exception:
        printer.warn(f"Failed to fetch {name}-{version} archive for sha256; skipping injection")
        return
    sha = _file_sha256(tmp_path)
    tmp_path.unlink(missing_ok=True)

    entry = {
        "type": "archive",
        "archive-type": "tar-gzip",
        "url": url,
        "sha256": sha,
        "strip-components": 0,
        "dest": target_dest,
    }
    data.append(entry)
    json_path.write_text(json.dumps(data, indent=4) + "\n", encoding="utf-8")
    printer.info(f"Injected pub package {name}-{version} into pubspec-sources.json")


def _remove_local_dir_sources(document: ManifestDocument, printer: _StatusPrinter) -> None:
    modules = document.ensure_modules()
    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue
        sources = module.get("sources", [])
        if not isinstance(sources, list):
            return
        filtered: list[object] = []
        removed = 0
        for src in sources:
            if isinstance(src, dict) and src.get("type") == "dir":
                removed += 1
                continue
            filtered.append(src)
        if removed:
            module["sources"] = filtered
            document.mark_changed()
            printer.info(f"Removed {removed} local dir source(s) from final manifest")
        break


# Helper predicates split out to reduce complexity of the main reorder function
def _is_dep_include_entry(entry: object) -> bool:
    if isinstance(entry, str):
        return "pubspec-sources.json" in entry or "cargo-sources.json" in entry
    if isinstance(entry, dict):
        path = str(entry.get("path", ""))
        return path.endswith("pubspec-sources.json") or path.endswith("cargo-sources.json")
    return False


def _is_cargokit_patch_entry(entry: object) -> bool:
    if not isinstance(entry, dict) or entry.get("type") != "patch":
        return False
    dest = str(entry.get("dest", ""))
    path = str(entry.get("path", ""))
    return (
        dest.startswith(".pub-cache/hosted/pub.dev/")
        and "/cargokit" in dest
        and path.endswith("run_build_tool.sh.patch")
    )


def _is_sqlite_patch_entry(entry: object) -> bool:
    if not isinstance(entry, dict) or entry.get("type") != "patch":
        return False
    path = str(entry.get("path", ""))
    if not path.startswith("sqlite3_flutter_libs/"):
        return False
    return path.endswith("-CMakeLists.txt.patch")


def _ensure_cargokit_patches_after_dependency_sources(document: ManifestDocument, printer: _StatusPrinter) -> None:
    """Reorder cargokit patch sources to appear after dependency source includes.

    flatpak-builder processes sources sequentially. Cargokit patches must run
    after pubspec/cargo sources have populated the .pub-cache directories.
    If patches appear earlier, patch(1) prompts for the file to patch and hangs.
    """
    modules = document.ensure_modules()
    target = None
    for module in modules:
        if isinstance(module, dict) and module.get("name") == "lotti":
            target = module
            break
    if not target:
        return

    sources = target.get("sources")
    if not isinstance(sources, list):
        return

    last_dep_idx = max((idx for idx, e in enumerate(sources) if _is_dep_include_entry(e)), default=-1)
    if last_dep_idx < 0:
        return

    # Collect patches that are placed before dependency includes
    early_patch_indices = [
        idx
        for idx, e in enumerate(sources)
        if (_is_cargokit_patch_entry(e) or _is_sqlite_patch_entry(e)) and idx <= last_dep_idx
    ]
    if not early_patch_indices:
        return

    # Stable-reorder: extract early patches and insert them after last_dep_idx
    patches_to_move = [sources[i] for i in early_patch_indices]
    for i in reversed(early_patch_indices):
        del sources[i]

    insert_pos = min(last_dep_idx + 1, len(sources))
    for patch_entry in patches_to_move:
        sources.insert(insert_pos, patch_entry)
        insert_pos += 1

    target["sources"] = sources
    document.mark_changed()
    printer.info("Reordered cargokit patches after dependency sources")


def _bundle_sources_and_archives(context: PrepareFlathubContext, printer: _StatusPrinter) -> None:
    printer.status("Bundling cached archive and file sources referenced by manifest...")
    manifest_path = context.output_dir / context.manifest_work.name
    document = ManifestDocument.load(manifest_path)

    _ensure_flutter_archive(context, printer, document)

    search_roots = [
        context.flatpak_dir / "cache" / "pub.dev",
        context.flatpak_dir / ".flatpak-builder" / "downloads",
        context.repo_root / ".flatpak-builder" / "downloads",
        context.repo_root.parent / ".flatpak-builder" / "downloads",
    ]

    cache = sources_ops.ArtifactCache(
        output_dir=context.output_dir,
        download_missing=context.options.download_missing_sources,
        search_roots=[root for root in search_roots if root.exists()],
    )
    result = sources_ops.bundle_archive_sources(document, cache)
    if result.changed:
        document.save()
    for message in result.messages:
        printer.info(message)

    _apply_operation(document, printer, flutter.rewrite_flutter_git_url)

    app_archive_name = f"lotti-{context.app_commit}.tar.xz"
    app_archive_path = context.output_dir / app_archive_name
    if not app_archive_path.is_file():
        printer.info(f"Creating archived app source {app_archive_name}")
        result = _run_command(
            [
                "git",
                "archive",
                "--format=tar",
                "--prefix=lotti/",
                context.app_commit,
            ],
            cwd=context.repo_root,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=False,
            check=False,
        )
        if result.returncode != 0:
            error_output = (result.stderr or b"").decode("utf-8", "replace")
            raise PrepareFlathubError("Failed to create app archive: " + error_output)
        with lzma.open(app_archive_path, "wb") as archive_file:
            archive_file.write(result.stdout)

    app_sha = _file_sha256(app_archive_path)
    _apply_operation(
        document,
        printer,
        flutter.bundle_app_archive,
        archive_path=app_archive_name,
        sha256=app_sha,
    )

    _apply_operation(document, printer, flutter.apply_all_offline_fixes)
    document.save()


def _final_manifest_checks(context: PrepareFlathubContext, printer: _StatusPrinter) -> None:
    printer.status("Checking manifest for Flathub compliance...")
    manifest_path = context.output_dir / context.manifest_work.name
    document = ManifestDocument.load(manifest_path)
    result = core_validation.check_flathub_compliance(document)
    print(result.message)
    for detail in result.details or []:
        print(f"  - {detail}")
    if not result.success:
        raise PrepareFlathubError("FATAL: Flathub compliance violations found in final manifest")
    printer.status("Flathub compliance checks passed")
    _assert_commit_pinned(manifest_path, "Output")


def _cleanup(context: PrepareFlathubContext, printer: _StatusPrinter) -> None:
    if not context.options.clean_after_gen:
        return
    printer.status("Cleaning work build directory (.flatpak-builder)...")
    build_dir = context.work_dir / ".flatpak-builder"
    if build_dir.exists():
        shutil.rmtree(build_dir, ignore_errors=True)


def _maybe_test_build(context: PrepareFlathubContext, printer: _StatusPrinter) -> None:
    if not context.options.test_build:
        return
    printer.status("Testing build...")
    result = _run_command(
        [
            "flatpak-builder",
            "--force-clean",
            "--repo=repo",
            "build-dir",
            context.manifest_work.name,
        ],
        cwd=context.output_dir,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        check=False,
    )
    if result.returncode == 0:
        printer.status("Test build successful!")
    else:
        printer.error("Test build failed")
        print(result.stdout)


def _print_summary(context: PrepareFlathubContext, printer: _StatusPrinter) -> None:
    printer.status("Preparation complete!")
    print()
    printer.info(f"Generated files are in: {context.output_dir}")
    print()
    printer.info("Files generated:")
    for entry in sorted(context.output_dir.iterdir()):
        print(f"  {entry.name}")
    print()

    flathub_root = (
        context.flathub_dir.resolve()
        if context.flathub_dir is not None
        else (context.repo_root.parent / "flathub").resolve()
    )
    if flathub_root.is_dir():
        printer.info("To copy to flathub repo:")
        print(f"  cp -r {context.output_dir}/* {flathub_root}/com.matthiasn.lotti/")
        print()
        printer.info("Then:")
        for step in (
            f"cd {flathub_root}",
            "git checkout -b new-app-com.matthiasn.lotti",
            "git add com.matthiasn.lotti",
            'git commit -m "Add com.matthiasn.lotti"',
            "git push origin new-app-com.matthiasn.lotti",
            "Create PR at https://github.com/flathub/flathub",
        ):
            print(f"  {step}")
    else:
        printer.info("To prepare for Flathub submission:")
        print("  1. Fork https://github.com/flathub/flathub")
        print(f"  2. Clone your fork to {flathub_root}")
        print(f"  3. Copy {context.output_dir} to {flathub_root}/com.matthiasn.lotti")
        print("  4. Create a pull request")


__all__ = [
    "PrepareFlathubOptions",
    "PrepareFlathubError",
    "prepare_flathub",
]
