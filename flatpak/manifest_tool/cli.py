#!/usr/bin/env python3
"""Command-line interface for Flatpak helper operations."""

from __future__ import annotations

import argparse
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

try:  # pragma: no cover - import fallback for direct execution
    from . import build_utils, ci_ops, flutter_ops, manifest_ops, sources_ops, utils
    from .manifest import ManifestDocument, OperationResult, merge_results
except ImportError:  # pragma: no cover
    PACKAGE_ROOT = Path(__file__).resolve().parent
    if str(PACKAGE_ROOT) not in sys.path:
        sys.path.insert(0, str(PACKAGE_ROOT))
    import build_utils  # type: ignore
    import ci_ops  # type: ignore
    import flutter_ops  # type: ignore
    import manifest_ops  # type: ignore
    import sources_ops  # type: ignore
    import utils  # type: ignore
    from manifest import ManifestDocument, OperationResult, merge_results  # type: ignore

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


def _run_pr_aware_pin(namespace: argparse.Namespace) -> int:
    assignments = ci_ops.pr_aware_environment(
        event_name=namespace.event_name,
        event_path=namespace.event_path,
    )
    if not assignments:
        return 0
    sys.stdout.write(utils.format_shell_assignments(assignments))
    sys.stdout.write("\n")
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
            import shutil

            git_path = shutil.which("git")
            if not git_path:
                raise FileNotFoundError("git executable not found in PATH")

            commit = subprocess.check_output(
                [git_path, "rev-parse", "HEAD"], text=True, stderr=subprocess.STDOUT
            ).strip()
            print(f"No commit specified, using current HEAD: {commit}")
        except (subprocess.CalledProcessError, FileNotFoundError, OSError) as exc:
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
        executor=lambda document: flutter_ops.ensure_nested_sdk(
            document,
            output_dir=namespace.output_dir,
        ),
    )
    return _run_manifest_operation(operation)


def _run_normalize_lotti_env(namespace: argparse.Namespace) -> int:
    flutter_bin = (
        "/var/lib/flutter/bin" if namespace.layout == "nested" else "/app/flutter/bin"
    )
    operation = ManifestOperation(
        manifest=Path(namespace.manifest),
        executor=lambda document: flutter_ops.normalize_lotti_env(
            document,
            flutter_bin=flutter_bin,
            ensure_append_path=namespace.append_path,
        ),
    )
    return _run_manifest_operation(operation)


def _run_ensure_lotti_setup_helper(namespace: argparse.Namespace) -> int:
    working_dir = "/var/lib" if namespace.layout == "nested" else "/app"

    def executor(document: ManifestDocument) -> OperationResult:
        source_result = flutter_ops.ensure_setup_helper_source(
            document,
            helper_name=namespace.helper,
        )
        command_result = flutter_ops.ensure_setup_helper_command(
            document,
            helper_name=namespace.helper,
            working_dir=working_dir,
        )
        return merge_results([source_result, command_result])

    operation = ManifestOperation(manifest=Path(namespace.manifest), executor=executor)
    return _run_manifest_operation(operation)


def _run_should_remove_flutter_sdk(namespace: argparse.Namespace) -> int:
    document = ManifestDocument.load(namespace.manifest)
    try:
        result = flutter_ops.should_remove_flutter_sdk(
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
        executor=lambda document: flutter_ops.normalize_flutter_sdk_module(document),
    )
    return _run_manifest_operation(operation)


def _run_normalize_sdk_copy(namespace: argparse.Namespace) -> int:
    operation = ManifestOperation(
        manifest=Path(namespace.manifest),
        executor=lambda document: flutter_ops.normalize_sdk_copy(document),
    )
    return _run_manifest_operation(operation)


def _run_convert_flutter_git_to_archive(namespace: argparse.Namespace) -> int:
    operation = ManifestOperation(
        manifest=Path(namespace.manifest),
        executor=lambda document: flutter_ops.convert_flutter_git_to_archive(
            document,
            archive_name=namespace.archive,
            sha256=namespace.sha256,
        ),
    )
    return _run_manifest_operation(operation)


def _run_rewrite_flutter_git_url(namespace: argparse.Namespace) -> int:
    operation = ManifestOperation(
        manifest=Path(namespace.manifest),
        executor=lambda document: flutter_ops.rewrite_flutter_git_url(document),
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
        executor=lambda document: flutter_ops.bundle_app_archive(
            document,
            archive_name=namespace.archive,
            sha256=namespace.sha256,
            output_dir=namespace.output_dir,
        ),
    )
    return _run_manifest_operation(operation)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Flatpak helper CLI")
    subparsers = parser.add_subparsers(dest="command", required=True)

    parser_pr = subparsers.add_parser(
        "pr-aware-pin", help="Emit shell assignments for PR-aware manifest pinning."
    )
    parser_pr.add_argument(
        "--event-name", default=None, help="GitHub event name (e.g. pull_request)."
    )
    parser_pr.add_argument(
        "--event-path", default=None, help="Path to the GitHub event payload JSON."
    )
    parser_pr.set_defaults(func=_run_pr_aware_pin)

    parser_replace = subparsers.add_parser(
        "replace-url-with-path",
        help="Replace a manifest source url with a local path entry.",
    )
    parser_replace.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_replace.add_argument(
        "--identifier", required=True, help="Identifier to match within the url line."
    )
    parser_replace.add_argument(
        "--path", required=True, dest="path_value", help="Replacement path value."
    )
    parser_replace.set_defaults(func=_run_replace_url_with_path)

    parser_setup = subparsers.add_parser(
        "ensure-setup-helper",
        help="Ensure flutter-sdk module ships the setup helper script.",
    )
    parser_setup.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_setup.add_argument(
        "--helper", default="setup-flutter.sh", help="Helper script basename to embed."
    )
    parser_setup.set_defaults(func=_run_ensure_setup_helper)

    parser_pin = subparsers.add_parser(
        "pin-commit", help="Pin the lotti source to a specific commit."
    )
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
    parser_mod_include.add_argument(
        "--manifest", required=True, help="Manifest file path."
    )
    parser_mod_include.add_argument(
        "--name", required=True, help="Module include name (e.g., rustup-1.83.0.json)"
    )
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

    parser_nested = subparsers.add_parser(
        "ensure-nested-sdk", help="Attach flutter-sdk JSON modules under lotti."
    )
    parser_nested.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_nested.add_argument(
        "--output-dir", required=True, help="Directory containing flutter jsons."
    )
    parser_nested.set_defaults(func=_run_ensure_nested_sdk)

    parser_env = subparsers.add_parser(
        "normalize-lotti-env", help="Normalize PATH settings for the lotti module."
    )
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
    parser_helper.add_argument(
        "--helper", default="setup-flutter.sh", help="Helper script basename."
    )
    parser_helper.set_defaults(func=_run_ensure_lotti_setup_helper)

    parser_net = subparsers.add_parser(
        "ensure-lotti-network-share",
        help="Ensure lotti build-args include --share=network.",
    )
    parser_net.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_net.set_defaults(
        func=lambda ns: _run_manifest_operation(
            ManifestOperation(
                manifest=Path(ns.manifest),
                executor=lambda document: flutter_ops.ensure_lotti_network_share(
                    document
                ),
            )
        )
    )

    parser_rust_env = subparsers.add_parser(
        "ensure-rust-sdk-env",
        help="Ensure Rust SDK extension bin is on PATH for lotti.",
    )
    parser_rust_env.add_argument(
        "--manifest", required=True, help="Manifest file path."
    )
    parser_rust_env.set_defaults(
        func=lambda ns: _run_manifest_operation(
            ManifestOperation(
                manifest=Path(ns.manifest),
                executor=lambda document: flutter_ops.ensure_rust_sdk_env(document),
            )
        )
    )

    parser_rm_rustup = subparsers.add_parser(
        "remove-rustup-install", help="Remove rustup install commands from lotti."
    )
    parser_rm_rustup.add_argument(
        "--manifest", required=True, help="Manifest file path."
    )
    parser_rm_rustup.set_defaults(
        func=lambda ns: _run_manifest_operation(
            ManifestOperation(
                manifest=Path(ns.manifest),
                executor=lambda document: flutter_ops.remove_rustup_install(document),
            )
        )
    )

    parser_remove = subparsers.add_parser(
        "should-remove-flutter-sdk",
        help="Check if the top-level flutter-sdk module can be removed.",
    )
    parser_remove.add_argument("--manifest", required=True, help="Manifest file path.")
    parser_remove.add_argument(
        "--output-dir", required=True, help="Directory containing flutter jsons."
    )
    parser_remove.set_defaults(func=_run_should_remove_flutter_sdk)

    parser_sdk_module = subparsers.add_parser(
        "normalize-flutter-sdk-module",
        help="Prune flutter-sdk build commands to safe operations.",
    )
    parser_sdk_module.add_argument(
        "--manifest", required=True, help="Manifest file path."
    )
    parser_sdk_module.set_defaults(func=_run_normalize_flutter_sdk_module)

    parser_sdk_copy = subparsers.add_parser(
        "normalize-sdk-copy",
        help="Normalize the Flutter SDK copy command with fallbacks.",
    )
    parser_sdk_copy.add_argument(
        "--manifest", required=True, help="Manifest file path."
    )
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
    parser_offline_sources.add_argument(
        "--manifest", required=True, help="Manifest file path."
    )
    parser_offline_sources.add_argument(
        "--pubspec", help="pubspec JSON filename to include."
    )
    parser_offline_sources.add_argument(
        "--cargo", help="cargo JSON filename to include."
    )
    parser_offline_sources.add_argument(
        "--flutter-json", dest="flutter_json", help="Flutter SDK JSON filename."
    )
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
    parser_bundle.add_argument(
        "--output-dir", required=True, help="Directory for cached artifacts."
    )
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
    parser_bundle_app.add_argument(
        "--manifest", required=True, help="Manifest file path."
    )
    parser_bundle_app.add_argument(
        "--archive", required=True, help="Archive filename (relative to output dir)."
    )
    parser_bundle_app.add_argument(
        "--sha256", required=True, help="Archive SHA256 hash."
    )
    parser_bundle_app.add_argument(
        "--output-dir", required=True, help="Directory containing offline artifacts."
    )
    parser_bundle_app.set_defaults(func=_run_bundle_app_archive)

    parser_rm_rustup = subparsers.add_parser(
        "remove-rustup-sources", help="Remove rustup-*.json references from sources."
    )
    parser_rm_rustup.add_argument(
        "--manifest", required=True, help="Manifest file path."
    )
    parser_rm_rustup.set_defaults(
        func=lambda ns: _run_manifest_operation(
            ManifestOperation(
                manifest=Path(ns.manifest),
                executor=lambda document: sources_ops.remove_rustup_sources(document),
            )
        )
    )

    # Build utility commands
    parser_find_flutter = subparsers.add_parser(
        "find-flutter-sdk", help="Find a cached Flutter SDK installation."
    )
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
    parser_find_flutter.add_argument(
        "--max-depth", type=int, default=6, help="Maximum search depth (default: 6)."
    )
    parser_find_flutter.set_defaults(func=lambda ns: _run_find_flutter_sdk(ns))

    parser_prepare_build = subparsers.add_parser(
        "prepare-build-dir", help="Prepare build directory for flatpak-flutter."
    )
    parser_prepare_build.add_argument(
        "--build-dir", required=True, help="Build directory to prepare."
    )
    parser_prepare_build.add_argument(
        "--pubspec-yaml", help="Path to pubspec.yaml to copy."
    )
    parser_prepare_build.add_argument(
        "--pubspec-lock", help="Path to pubspec.lock to copy."
    )
    parser_prepare_build.add_argument(
        "--no-foreign-deps",
        action="store_true",
        help="Don't create empty foreign_deps.json.",
    )
    parser_prepare_build.set_defaults(func=lambda ns: _run_prepare_build_dir(ns))

    # Generate the setup-flutter.sh helper script
    parser_generate_helper = subparsers.add_parser(
        "generate-setup-helper", help="Generate the setup-flutter.sh helper script."
    )
    parser_generate_helper.add_argument(
        "--output",
        default="setup-flutter.sh",
        help="Output file path (default: setup-flutter.sh).",
    )
    parser_generate_helper.set_defaults(func=lambda ns: _run_generate_setup_helper(ns))

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


def _run_prepare_build_dir(namespace: argparse.Namespace) -> int:
    """Run the prepare-build-dir command."""
    build_dir = Path(namespace.build_dir)
    pubspec_yaml = Path(namespace.pubspec_yaml) if namespace.pubspec_yaml else None
    pubspec_lock = Path(namespace.pubspec_lock) if namespace.pubspec_lock else None

    success = build_utils.prepare_build_directory(
        build_dir=build_dir,
        pubspec_yaml=pubspec_yaml,
        pubspec_lock=pubspec_lock,
        create_foreign_deps=not namespace.no_foreign_deps,
    )

    return 0 if success else 1


def _run_generate_setup_helper(namespace: argparse.Namespace) -> int:
    """Generate the setup-flutter.sh helper script."""
    output_path = Path(namespace.output)

    # Read the helper script from the helpers directory
    helpers_dir = Path(__file__).parent.parent / "helpers"
    helper_script = helpers_dir / "setup-flutter.sh"

    if not helper_script.exists():
        logger.error("Helper script not found at %s", helper_script)
        return 1

    try:
        content = helper_script.read_text(encoding="utf-8")
        output_path.write_text(content, encoding="utf-8")
        # Make it executable
        output_path.chmod(0o755)
        logger.info("Generated helper script at %s", output_path)
        return 0
    except (OSError, IOError) as e:
        logger.error("Failed to generate helper script: %s", e)
        return 1


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
