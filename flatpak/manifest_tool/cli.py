#!/usr/bin/env python3
"""Command-line interface for Flatpak helper operations."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

try:  # pragma: no cover - import fallback for direct execution
    from . import flutter
    from .build_utils import utils as build_utils
    from .core import utils
    from .core.manifest import ManifestDocument, OperationResult, merge_results
    from .operations import ci as ci_ops
    from .operations import manifest as manifest_ops
    from .operations import sources as sources_ops
    from .prepare import (
        PrepareFlathubError,
        PrepareFlathubOptions,
        prepare_flathub,
    )
except ImportError:  # pragma: no cover
    PACKAGE_ROOT = Path(__file__).resolve().parent
    PACKAGE_PARENT = PACKAGE_ROOT.parent
    if str(PACKAGE_PARENT) not in sys.path:
        sys.path.insert(0, str(PACKAGE_PARENT))

    # Import using fully-qualified package paths to avoid clashing with similarly
    # named third-party modules when falling back to direct execution.
    import manifest_tool.flutter as flutter  # type: ignore
    from manifest_tool.build_utils import utils as build_utils  # type: ignore
    from manifest_tool.core import utils  # type: ignore
    from manifest_tool.core.manifest import (  # type: ignore
        ManifestDocument,
        OperationResult,
        merge_results,
    )
    from manifest_tool.operations import ci as ci_ops  # type: ignore
    from manifest_tool.operations import manifest as manifest_ops  # type: ignore
    from manifest_tool.operations import sources as sources_ops  # type: ignore
    from manifest_tool.prepare import (  # type: ignore
        PrepareFlathubError,
        PrepareFlathubOptions,
        prepare_flathub,
    )

logger = utils.get_logger("cli")


@dataclass
class ManifestOperation:
    manifest: Path
    executor: Callable[[ManifestDocument], OperationResult]


def _emit_messages(result: OperationResult) -> None:
    for message in result.messages:
        print(message)


def _run_manifest_operation(operation: ManifestOperation) -> int:
    document = ManifestDocument.load(operation.manifest)
    try:
        result = operation.executor(document)
    except Exception as exc:  # pragma: no cover
        logger.error("Operation failed: %s", exc)
        return 1
    if result.changed:
        document.save()
    _emit_messages(result)
    return 0


def _run_replace_url_with_path(namespace: argparse.Namespace) -> int:
    result = sources_ops.replace_url_with_path(
        manifest_path=namespace.manifest,
        identifier=namespace.identifier,
        path_value=namespace.path_value,
    )
    if result:
        print(f"Replaced url with path for {namespace.identifier}")
        return 0
    return 1 if result is None else 0


def _run_ensure_setup_helper(namespace: argparse.Namespace) -> int:
    operation = ManifestOperation(
        manifest=Path(namespace.manifest),
        executor=lambda document: manifest_ops.ensure_flutter_setup_helper(
            document,
            helper_name=namespace.helper,
        ),
    )
    return _run_manifest_operation(operation)


def _run_pin_commit(namespace: argparse.Namespace) -> int:
    operation = ManifestOperation(
        manifest=Path(namespace.manifest),
        executor=lambda document: manifest_ops.pin_commit(
            document,
            commit=namespace.commit,
            repo_urls=namespace.repo_url,
        ),
    )
    return _run_manifest_operation(operation)


def _run_update_manifest(namespace: argparse.Namespace) -> int:
    """Update manifest for build, handling both PR and non-PR scenarios."""
    # Check if we're in PR mode
    pr_url = None
    pr_commit = None
    commit = namespace.commit

    if namespace.event_name and namespace.event_path:
        if namespace.event_name == "pull_request":
            # Get PR information
            pr_env = ci_ops.pr_aware_environment(
                event_name=namespace.event_name,
                event_path=namespace.event_path,
            )
            if pr_env.get("PR_MODE") == "true":
                pr_url = pr_env.get("PR_HEAD_URL")
                pr_commit = pr_env.get("PR_HEAD_SHA")
                commit = None  # Don't use the regular commit in PR mode
                print(f"PR mode: updating manifest for {pr_url} @ {pr_commit}")

    # If no commit specified and not in PR mode, use current HEAD
    if not commit and not pr_commit:
        try:
            # Use absolute path to git for security (B607)
            git_path = shutil.which("git")
            if not git_path:
                raise FileNotFoundError("git executable not found in PATH")

            commit = subprocess.check_output(
                [git_path, "rev-parse", "HEAD"], text=True, stderr=subprocess.STDOUT
            ).strip()
            print(f"No commit specified, using current HEAD: {commit}")
        except (subprocess.CalledProcessError, OSError) as exc:
            print(
                f"Error: Unable to determine current HEAD commit: {exc}",
                file=sys.stderr,
            )
            return 1

    operation = ManifestOperation(
        manifest=Path(namespace.manifest),
        executor=lambda document: manifest_ops.update_manifest_for_build(
            document,
            commit=commit,
            pr_url=pr_url,
            pr_commit=pr_commit,
        ),
    )
    return _run_manifest_operation(operation)


def _run_ensure_nested_sdk(namespace: argparse.Namespace) -> int:
    operation = ManifestOperation(
        manifest=Path(namespace.manifest),
        executor=lambda document: flutter.ensure_nested_sdk(
            document,
            output_dir=namespace.output_dir,
        ),
    )
    return _run_manifest_operation(operation)


def _run_normalize_lotti_env(namespace: argparse.Namespace) -> int:
    flutter_bin = "/var/lib/flutter/bin" if namespace.layout == "nested" else "/app/flutter/bin"
    operation = ManifestOperation(
        manifest=Path(namespace.manifest),
        executor=lambda document: flutter.normalize_lotti_env(
            document,
            flutter_bin=flutter_bin,
            ensure_append_path=namespace.append_path,
        ),
    )
    return _run_manifest_operation(operation)


def _run_ensure_lotti_setup_helper(namespace: argparse.Namespace) -> int:
    working_dir = "/var/lib" if namespace.layout == "nested" else "/app"

    def executor(document: ManifestDocument) -> OperationResult:
        source_result = flutter.ensure_setup_helper_source(
            document,
            helper_name=namespace.helper,
        )
        command_result = flutter.ensure_setup_helper_command(
            document,
            working_dir=working_dir,
        )
        return merge_results([source_result, command_result])

    operation = ManifestOperation(manifest=Path(namespace.manifest), executor=executor)
    return _run_manifest_operation(operation)


def _run_should_remove_flutter_sdk(namespace: argparse.Namespace) -> int:
    document = ManifestDocument.load(namespace.manifest)
    try:
        result = flutter.should_remove_flutter_sdk(
            document,
            output_dir=namespace.output_dir,
        )
    except Exception as exc:  # pragma: no cover
        logger.error("Operation failed: %s", exc)
        return 1
    sys.stdout.write("1\n" if result else "0\n")
    return 0


def _run_normalize_flutter_sdk_module(namespace: argparse.Namespace) -> int:
    operation = ManifestOperation(
        manifest=Path(namespace.manifest),
        executor=lambda document: flutter.normalize_flutter_sdk_module(document),
    )
    return _run_manifest_operation(operation)


def _run_normalize_sdk_copy(namespace: argparse.Namespace) -> int:
    operation = ManifestOperation(
        manifest=Path(namespace.manifest),
        executor=lambda document: flutter.normalize_sdk_copy(document),
    )
    return _run_manifest_operation(operation)


def _run_convert_flutter_git_to_archive(namespace: argparse.Namespace) -> int:
    operation = ManifestOperation(
        manifest=Path(namespace.manifest),
        executor=lambda document: flutter.convert_flutter_git_to_archive(
            document,
            archive_name=namespace.archive,
            sha256=namespace.sha256,
        ),
    )
    return _run_manifest_operation(operation)


def _run_rewrite_flutter_git_url(namespace: argparse.Namespace) -> int:
    operation = ManifestOperation(
        manifest=Path(namespace.manifest),
        executor=lambda document: flutter.rewrite_flutter_git_url(document),
    )
    return _run_manifest_operation(operation)


def _run_add_offline_sources(namespace: argparse.Namespace) -> int:
    operation = ManifestOperation(
        manifest=Path(namespace.manifest),
        executor=lambda document: sources_ops.add_offline_sources(
            document,
            pubspec=namespace.pubspec,
            cargo=namespace.cargo,
            rustup=namespace.rustup or [],
            flutter_file=namespace.flutter_json,
        ),
    )
    return _run_manifest_operation(operation)


def _run_bundle_archive_sources(namespace: argparse.Namespace) -> int:
    cache = sources_ops.ArtifactCache(
        output_dir=Path(namespace.output_dir),
        download_missing=namespace.download_missing,
        search_roots=[Path(root) for root in namespace.search_root or []],
    )

    operation = ManifestOperation(
        manifest=Path(namespace.manifest),
        executor=lambda document: sources_ops.bundle_archive_sources(document, cache),
    )
    return _run_manifest_operation(operation)


def _run_bundle_app_archive(namespace: argparse.Namespace) -> int:
    operation = ManifestOperation(
        manifest=Path(namespace.manifest),
        executor=lambda document: flutter.bundle_app_archive(
            document,
            archive_path=str(Path(namespace.output_dir) / namespace.archive),
            sha256=namespace.sha256,
        ),
    )
    return _run_manifest_operation(operation)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Flatpak helper CLI")
    subparsers = parser.add_subparsers(dest="command", required=True)

    parser_replace = subparsers.add_parser(
        "replace-url-with-path",
        help="Replace a manifest source url with a local path entry.",
    )
    parser_replace.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_replace.add_argument("--identifier", required=True, help="Identifier to match within the url line.")
    parser_replace.add_argument("--path", required=True, dest="path_value", help="Replacement path value.")
    parser_replace.set_defaults(func=_run_replace_url_with_path)

    parser_setup = subparsers.add_parser(
        "ensure-setup-helper",
        help="Ensure flutter-sdk module ships the setup helper script.",
    )
    parser_setup.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_setup.add_argument("--helper", default="setup-flutter.sh", help="Helper script basename to embed.")
    parser_setup.set_defaults(func=_run_ensure_setup_helper)

    parser_pin = subparsers.add_parser("pin-commit", help="Pin the lotti source to a specific commit.")
    parser_pin.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_pin.add_argument("--commit", required=True, help="Commit SHA to pin.")
    parser_pin.add_argument(
        "--repo-url",
        action="append",
        default=None,
        help="Optional repository URL to match (can be repeated).",
    )
    parser_pin.set_defaults(func=_run_pin_commit)

    # New comprehensive update-manifest command
    parser_update = subparsers.add_parser(
        "update-manifest",
        help="Update manifest for build (handles both PR and non-PR scenarios).",
    )
    parser_update.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_update.add_argument(
        "--commit",
        default=None,
        help="Commit SHA to pin (for non-PR builds). If not provided, uses current HEAD.",
    )
    parser_update.add_argument(
        "--event-name",
        default=None,
        help="GitHub event name (e.g., pull_request).",
    )
    parser_update.add_argument(
        "--event-path",
        default=None,
        help="Path to GitHub event JSON file.",
    )
    parser_update.set_defaults(func=_run_update_manifest)

    parser_mod_include = subparsers.add_parser(
        "ensure-module-include",
        help="Ensure a string module include is present (e.g., rustup JSON module).",
    )
    parser_mod_include.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_mod_include.add_argument("--name", required=True, help="Module include name (e.g., rustup-1.83.0.json)")
    parser_mod_include.add_argument(
        "--before",
        dest="before_name",
        default=None,
        help="Insert before module with this name (e.g., lotti).",
    )
    parser_mod_include.set_defaults(
        func=lambda ns: _run_manifest_operation(
            ManifestOperation(
                manifest=Path(ns.manifest),
                executor=lambda document: manifest_ops.ensure_module_include(
                    document, module_name=ns.name, before_name=ns.before_name
                ),
            )
        )
    )

    parser_nested = subparsers.add_parser("ensure-nested-sdk", help="Attach flutter-sdk JSON modules under lotti.")
    parser_nested.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_nested.add_argument("--output-dir", required=True, help="Directory containing flutter jsons.")
    parser_nested.set_defaults(func=_run_ensure_nested_sdk)

    parser_env = subparsers.add_parser("normalize-lotti-env", help="Normalize PATH settings for the lotti module.")
    parser_env.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_env.add_argument(
        "--layout",
        choices=("top", "nested"),
        default="top",
        help="SDK layout to normalize.",
    )
    parser_env.add_argument(
        "--append-path",
        action="store_true",
        help="Also ensure append-path includes the Flutter bin directory.",
    )
    parser_env.set_defaults(func=_run_normalize_lotti_env)

    parser_helper = subparsers.add_parser(
        "ensure-lotti-setup-helper",
        help="Ensure the lotti module bundles and invokes setup-flutter.sh.",
    )
    parser_helper.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_helper.add_argument(
        "--layout",
        choices=("top", "nested"),
        default="top",
        help="SDK layout to target.",
    )
    parser_helper.add_argument("--helper", default="setup-flutter.sh", help="Helper script basename.")
    parser_helper.set_defaults(func=_run_ensure_lotti_setup_helper)

    # Note: ensure-lotti-network-share command removed
    # --share=network in build-args is NOT allowed on Flathub infrastructure
    # Network access during builds violates Flathub policy

    parser_remove_network = subparsers.add_parser(
        "remove-network-from-build-args",
        help="Remove --share=network from build-args for Flathub compliance.",
    )
    parser_remove_network.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_remove_network.set_defaults(
        func=lambda ns: _run_manifest_operation(
            ManifestOperation(
                manifest=Path(ns.manifest),
                executor=lambda document: flutter.remove_network_from_build_args(document),
            )
        )
    )

    parser_pub_offline = subparsers.add_parser(
        "ensure-flutter-pub-get-offline",
        help="Ensure flutter pub get commands use --offline flag.",
    )
    parser_pub_offline.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_pub_offline.set_defaults(
        func=lambda ns: _run_manifest_operation(
            ManifestOperation(
                manifest=Path(ns.manifest),
                executor=lambda document: flutter.ensure_flutter_pub_get_offline(document),
            )
        )
    )

    parser_remove_config = subparsers.add_parser(
        "remove-flutter-config",
        help="Remove flutter config commands from lotti build steps.",
    )
    parser_remove_config.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_remove_config.set_defaults(
        func=lambda ns: _run_manifest_operation(
            ManifestOperation(
                manifest=Path(ns.manifest),
                executor=lambda document: flutter.remove_flutter_config_command(document),
            )
        )
    )

    parser_dart_offline = subparsers.add_parser(
        "ensure-dart-pub-offline-in-build",
        help="Wrap flutter build to disable pub network access.",
    )
    parser_dart_offline.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_dart_offline.set_defaults(
        func=lambda ns: _run_manifest_operation(
            ManifestOperation(
                manifest=Path(ns.manifest),
                executor=lambda document: flutter.ensure_dart_pub_offline_in_build(document),
            )
        )
    )

    parser_sqlite = subparsers.add_parser(
        "add-sqlite3-source",
        help="Add SQLite source for sqlite3_flutter_libs plugin.",
    )
    parser_sqlite.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_sqlite.set_defaults(
        func=lambda ns: _run_manifest_operation(
            ManifestOperation(
                manifest=Path(ns.manifest),
                executor=lambda document: flutter.add_sqlite3_source(document),
            )
        )
    )

    parser_mimalloc = subparsers.add_parser(
        "add-media-kit-mimalloc-source",
        help="Add mimalloc source for media_kit_libs_linux plugin.",
    )
    parser_mimalloc.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_mimalloc.set_defaults(
        func=lambda ns: _run_manifest_operation(
            ManifestOperation(
                manifest=Path(ns.manifest),
                executor=lambda document: flutter.add_media_kit_mimalloc_source(document),
            )
        )
    )

    parser_rust_env = subparsers.add_parser(
        "ensure-rust-sdk-env",
        help="Ensure Rust SDK extension bin is on PATH for lotti.",
    )
    parser_rust_env.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_rust_env.set_defaults(
        func=lambda ns: _run_manifest_operation(
            ManifestOperation(
                manifest=Path(ns.manifest),
                executor=lambda document: flutter.ensure_rust_sdk_env(document),
            )
        )
    )

    parser_rm_rustup = subparsers.add_parser("remove-rustup-install", help="Remove rustup install commands from lotti.")
    parser_rm_rustup.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_rm_rustup.set_defaults(
        func=lambda ns: _run_manifest_operation(
            ManifestOperation(
                manifest=Path(ns.manifest),
                executor=lambda document: flutter.remove_rustup_install(document),
            )
        )
    )

    parser_remove = subparsers.add_parser(
        "should-remove-flutter-sdk",
        help="Check if the top-level flutter-sdk module can be removed.",
    )
    parser_remove.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_remove.add_argument("--output-dir", required=True, help="Directory containing flutter jsons.")
    parser_remove.set_defaults(func=_run_should_remove_flutter_sdk)

    parser_sdk_module = subparsers.add_parser(
        "normalize-flutter-sdk-module",
        help="Prune flutter-sdk build commands to safe operations.",
    )
    parser_sdk_module.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_sdk_module.set_defaults(func=_run_normalize_flutter_sdk_module)

    parser_sdk_copy = subparsers.add_parser(
        "normalize-sdk-copy",
        help="Normalize the Flutter SDK copy command with fallbacks.",
    )
    parser_sdk_copy.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_sdk_copy.set_defaults(func=_run_normalize_sdk_copy)

    parser_convert = subparsers.add_parser(
        "convert-flutter-git-to-archive",
        help="Convert flutter git sources into archive references.",
    )
    parser_convert.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_convert.add_argument("--archive", required=True, help="Archive filename.")
    parser_convert.add_argument("--sha256", required=True, help="Archive SHA256 hash.")
    parser_convert.set_defaults(func=_run_convert_flutter_git_to_archive)

    parser_rewrite = subparsers.add_parser(
        "rewrite-flutter-git-url",
        help="Restore flutter git URL to the canonical upstream.",
    )
    parser_rewrite.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_rewrite.set_defaults(func=_run_rewrite_flutter_git_url)

    parser_offline_sources = subparsers.add_parser(
        "add-offline-sources", help="Attach offline JSON sources to the lotti module."
    )
    parser_offline_sources.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_offline_sources.add_argument("--pubspec", help="pubspec JSON filename to include.")
    parser_offline_sources.add_argument("--cargo", help="cargo JSON filename to include.")
    parser_offline_sources.add_argument("--flutter-json", dest="flutter_json", help="Flutter SDK JSON filename.")
    parser_offline_sources.add_argument(
        "--rustup",
        action="append",
        default=None,
        help="Additional rustup JSON filenames (repeatable).",
    )
    parser_offline_sources.set_defaults(func=_run_add_offline_sources)

    parser_bundle = subparsers.add_parser(
        "bundle-archive-sources",
        help="Bundle archive/file sources referenced in the manifest.",
    )
    parser_bundle.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_bundle.add_argument("--output-dir", required=True, help="Directory for cached artifacts.")
    parser_bundle.add_argument(
        "--download-missing",
        action="store_true",
        help="Download missing sources when cache lookup fails.",
    )
    parser_bundle.add_argument(
        "--search-root",
        action="append",
        default=None,
        help="Additional directories to search for cached artifacts.",
    )
    parser_bundle.set_defaults(func=_run_bundle_archive_sources)

    parser_bundle_app = subparsers.add_parser(
        "bundle-app-archive",
        help="Bundle the application source archive and attach metadata.",
    )
    parser_bundle_app.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_bundle_app.add_argument("--archive", required=True, help="Archive filename (relative to output dir).")
    parser_bundle_app.add_argument("--sha256", required=True, help="Archive SHA256 hash.")
    parser_bundle_app.add_argument("--output-dir", required=True, help="Directory containing offline artifacts.")
    parser_bundle_app.set_defaults(func=_run_bundle_app_archive)

    parser_rm_rustup = subparsers.add_parser(
        "remove-rustup-sources", help="Remove rustup-*.json references from sources."
    )
    parser_rm_rustup.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_rm_rustup.set_defaults(
        func=lambda ns: _run_manifest_operation(
            ManifestOperation(
                manifest=Path(ns.manifest),
                executor=lambda document: sources_ops.remove_rustup_sources(document),
            )
        )
    )

    # Apply all offline fixes (setup-flutter removal, path fixes, patches)
    parser_apply_offline_fixes = subparsers.add_parser(
        "apply-offline-fixes",
        help="Apply all offline fixes: remove setup-flutter.sh, fix paths, add patches.",
    )
    parser_apply_offline_fixes.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_apply_offline_fixes.set_defaults(
        func=lambda ns: _run_manifest_operation(
            ManifestOperation(
                manifest=Path(ns.manifest),
                executor=lambda document: flutter.apply_all_offline_fixes(document),
            )
        )
    )

    # Validation command
    parser_check_compliance = subparsers.add_parser(
        "check-flathub-compliance",
        help="Check manifest for Flathub compliance violations.",
    )
    parser_check_compliance.add_argument("--manifest", required=True, help="Manifest file path.")

    # Import validation module
    try:
        from .core import validation
    except ImportError:
        from core import validation  # type: ignore

    def _run_validation_check(namespace: argparse.Namespace) -> int:
        """Run validation and convert result to appropriate format."""
        document = ManifestDocument.load(namespace.manifest)
        try:
            result = validation.check_flathub_compliance(document)
        except Exception as exc:  # pragma: no cover
            logger.error("Validation failed: %s", exc)
            return 1

        # Print validation result
        print(result.message)
        if result.details:
            for detail in result.details:
                print(f"  - {detail}")

        # Return appropriate exit code
        return 0 if result.success else 1

    parser_check_compliance.set_defaults(func=_run_validation_check)

    # Build utility commands
    parser_find_flutter = subparsers.add_parser("find-flutter-sdk", help="Find a cached Flutter SDK installation.")
    parser_find_flutter.add_argument(
        "--search-root",
        action="append",
        required=True,
        help="Root directory to search (can be repeated).",
    )
    parser_find_flutter.add_argument(
        "--exclude",
        action="append",
        help="Path to exclude from search (can be repeated).",
    )
    parser_find_flutter.add_argument("--max-depth", type=int, default=6, help="Maximum search depth (default: 6).")
    parser_find_flutter.set_defaults(func=lambda ns: _run_find_flutter_sdk(ns))

    parser_prepare = subparsers.add_parser(
        "prepare-flathub",
        help=("Prepare the offline Flathub payload using the Python orchestrator."),
    )
    parser_prepare.add_argument(
        "--repo-root",
        type=Path,
        default=Path.cwd(),
        help="Repository root containing the flatpak directory (default: CWD)",
    )
    parser_prepare.add_argument(
        "--flatpak-dir",
        type=Path,
        help="Override path to the flatpak directory (defaults to repo-root/flatpak)",
    )
    parser_prepare.add_argument(
        "--work-dir",
        type=Path,
        help="Override work directory (defaults to flatpak-dir/flathub-build)",
    )
    parser_prepare.add_argument(
        "--output-dir",
        type=Path,
        help="Override output directory (defaults to work-dir/output)",
    )
    parser_prepare.add_argument(
        "--flathub-dir",
        type=Path,
        help="Path to local flathub checkout (defaults to repo-root/../flathub)",
    )
    parser_prepare.set_defaults(func=_run_prepare_flathub)

    return parser


def _run_find_flutter_sdk(namespace: argparse.Namespace) -> int:
    """Run the find-flutter-sdk command."""
    search_roots = [Path(root) for root in namespace.search_root]
    exclude_paths = [Path(p) for p in namespace.exclude] if namespace.exclude else None

    sdk_path = build_utils.find_flutter_sdk(
        search_roots=search_roots,
        exclude_paths=exclude_paths,
        max_depth=namespace.max_depth,
    )

    if sdk_path:
        print(sdk_path)
        return 0
    return 1


def _env_bool(name: str, default: bool) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    value = value.strip().lower()
    return value in {"1", "true", "yes", "on"}


def _env_optional_int(name: str) -> int | None:
    value = os.getenv(name)
    if value is None or not value.strip():
        return None
    try:
        return int(value)
    except ValueError:
        logger.warning("Ignoring invalid integer in %s=%s", name, value)
        return None


def _run_prepare_flathub(namespace: argparse.Namespace) -> int:
    repo_root = namespace.repo_root.resolve()
    flatpak_dir = (namespace.flatpak_dir or repo_root / "flatpak").resolve()
    work_dir = (namespace.work_dir or flatpak_dir / "flathub-build").resolve()
    output_dir = (namespace.output_dir or work_dir / "output").resolve()

    extra_env = {k: os.environ[k] for k in ("PUB_CACHE", "PYTHON") if k in os.environ}

    options = PrepareFlathubOptions(
        repository_root=repo_root,
        flatpak_dir=flatpak_dir,
        work_dir=work_dir,
        output_dir=output_dir,
        clean_after_gen=_env_bool("CLEAN_AFTER_GEN", True),
        pin_commit=_env_bool("PIN_COMMIT", True),
        use_nested_flutter=_env_bool("USE_NESTED_FLUTTER", False),
        download_missing_sources=_env_bool("DOWNLOAD_MISSING_SOURCES", True),
        no_flatpak_flutter=_env_bool("NO_FLATPAK_FLUTTER", False),
        flatpak_flutter_timeout=_env_optional_int("FLATPAK_FLUTTER_TIMEOUT"),
        extra_env=extra_env,
        test_build=_env_bool("TEST_BUILD", False),
        flathub_dir=(namespace.flathub_dir.resolve() if namespace.flathub_dir else None),
    )

    try:
        prepare_flathub(options)
    except PrepareFlathubError as exc:
        logger.exception("prepare-flathub failed: %s", exc)
        return 1
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    namespace = parser.parse_args(argv)
    func: Callable[[argparse.Namespace], int] = getattr(namespace, "func", None)
    if func is None:
        parser.print_help()
        return 1
    return func(namespace)


if __name__ == "__main__":
    raise SystemExit(main())
