#!/usr/bin/env python3
"""Command-line interface for Flatpak helper operations."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Callable

try:  # pragma: no cover - import fallback for direct execution
    from . import ci_ops, flutter_ops, manifest_ops, sources_ops, utils
except ImportError:  # pragma: no cover
    PACKAGE_ROOT = Path(__file__).resolve().parent
    if str(PACKAGE_ROOT) not in sys.path:
        sys.path.insert(0, str(PACKAGE_ROOT))
    import ci_ops  # type: ignore
    import flutter_ops  # type: ignore
    import manifest_ops  # type: ignore
    import sources_ops  # type: ignore
    import utils  # type: ignore


def _add_pr_aware_pin(subparsers: argparse._SubParsersAction[argparse.ArgumentParser]) -> None:
    parser = subparsers.add_parser(
        "pr-aware-pin",
        help="Emit shell assignments for PR-aware manifest pinning.",
    )
    parser.add_argument(
        "--event-name",
        default=None,
        help="GitHub event name (e.g. pull_request).",
    )
    parser.add_argument(
        "--event-path",
        default=None,
        help="Path to the GitHub event payload JSON.",
    )
    parser.set_defaults(func=_run_pr_aware_pin)


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


def _add_replace_url_with_path(
    subparsers: argparse._SubParsersAction[argparse.ArgumentParser],
) -> None:
    parser = subparsers.add_parser(
        "replace-url-with-path",
        help="Replace a manifest source url with a local path entry.",
    )
    parser.add_argument("--manifest", required=True, help="Manifest file path.")
    parser.add_argument(
        "--identifier",
        required=True,
        help="Identifier to match within the url line.",
    )
    parser.add_argument("--path", required=True, dest="path_value", help="Replacement path value.")
    parser.set_defaults(func=_run_replace_url_with_path)


def _run_replace_url_with_path(namespace: argparse.Namespace) -> int:
    changed = sources_ops.replace_url_with_path(
        manifest_path=namespace.manifest,
        identifier=namespace.identifier,
        path_value=namespace.path_value,
    )
    return 0 if changed is not None else 1


def _add_ensure_setup_helper(
    subparsers: argparse._SubParsersAction[argparse.ArgumentParser],
) -> None:
    parser = subparsers.add_parser(
        "ensure-setup-helper",
        help="Ensure flutter-sdk module ships the setup helper script.",
    )
    parser.add_argument("--manifest", required=True, help="Manifest file path.")
    parser.add_argument(
        "--helper",
        default="setup-flutter.sh",
        help="Helper script basename to embed.",
    )
    parser.set_defaults(func=_run_ensure_setup_helper)


def _run_ensure_setup_helper(namespace: argparse.Namespace) -> int:
    manifest_ops.ensure_flutter_setup_helper(
        manifest_path=namespace.manifest,
        helper_name=namespace.helper,
    )
    return 0


def _add_pin_commit(
    subparsers: argparse._SubParsersAction[argparse.ArgumentParser],
) -> None:
    parser = subparsers.add_parser(
        "pin-commit",
        help="Pin the lotti source to a specific commit.",
    )
    parser.add_argument("--manifest", required=True, help="Manifest file path.")
    parser.add_argument("--commit", required=True, help="Commit SHA to pin.")
    parser.add_argument(
        "--repo-url",
        action="append",
        default=None,
        help="Optional repository URL to match (can be repeated).",
    )
    parser.set_defaults(func=_run_pin_commit)


def _run_pin_commit(namespace: argparse.Namespace) -> int:
    manifest_ops.pin_commit(
        manifest_path=namespace.manifest,
        commit=namespace.commit,
        repo_urls=namespace.repo_url,
    )
    return 0


def _add_ensure_nested_sdk(
    subparsers: argparse._SubParsersAction[argparse.ArgumentParser],
) -> None:
    parser = subparsers.add_parser(
        "ensure-nested-sdk",
        help="Attach flutter-sdk JSON modules under lotti.",
    )
    parser.add_argument("--manifest", required=True, help="Manifest file path.")
    parser.add_argument("--output-dir", required=True, help="Directory containing flutter jsons.")
    parser.set_defaults(func=_run_ensure_nested_sdk)


def _run_ensure_nested_sdk(namespace: argparse.Namespace) -> int:
    flutter_ops.ensure_nested_sdk(
        manifest_path=namespace.manifest,
        output_dir=namespace.output_dir,
    )
    return 0


def _add_normalize_lotti_env(
    subparsers: argparse._SubParsersAction[argparse.ArgumentParser],
) -> None:
    parser = subparsers.add_parser(
        "normalize-lotti-env",
        help="Normalize PATH settings for the lotti module.",
    )
    parser.add_argument("--manifest", required=True, help="Manifest file path.")
    parser.add_argument(
        "--layout",
        choices=("top", "nested"),
        default="top",
        help="SDK layout to normalize (top installs under /app, nested under /var/lib).",
    )
    parser.add_argument(
        "--append-path",
        action="store_true",
        help="Also ensure append-path includes the Flutter bin directory.",
    )
    parser.set_defaults(func=_run_normalize_lotti_env)


def _run_normalize_lotti_env(namespace: argparse.Namespace) -> int:
    flutter_bin = "/var/lib/flutter/bin" if namespace.layout == "nested" else "/app/flutter/bin"
    flutter_ops.normalize_lotti_env(
        manifest_path=namespace.manifest,
        flutter_bin=flutter_bin,
        ensure_append_path=namespace.append_path,
    )
    return 0


def _add_ensure_lotti_setup_helper(
    subparsers: argparse._SubParsersAction[argparse.ArgumentParser],
) -> None:
    parser = subparsers.add_parser(
        "ensure-lotti-setup-helper",
        help="Ensure the lotti module bundles and invokes setup-flutter.sh.",
    )
    parser.add_argument("--manifest", required=True, help="Manifest file path.")
    parser.add_argument(
        "--layout",
        choices=("top", "nested"),
        default="top",
        help="SDK layout to target for helper invocation.",
    )
    parser.add_argument(
        "--helper",
        default="setup-flutter.sh",
        help="Helper script basename.",
    )
    parser.set_defaults(func=_run_ensure_lotti_setup_helper)


def _run_ensure_lotti_setup_helper(namespace: argparse.Namespace) -> int:
    working_dir = "/var/lib" if namespace.layout == "nested" else "/app"
    flutter_ops.ensure_setup_helper_source(
        manifest_path=namespace.manifest,
        helper_name=namespace.helper,
    )
    flutter_ops.ensure_setup_helper_command(
        manifest_path=namespace.manifest,
        helper_name=namespace.helper,
        working_dir=working_dir,
    )
    return 0


def _add_should_remove_flutter_sdk(
    subparsers: argparse._SubParsersAction[argparse.ArgumentParser],
) -> None:
    parser = subparsers.add_parser(
        "should-remove-flutter-sdk",
        help="Check if the top-level flutter-sdk module can be removed.",
    )
    parser.add_argument("--manifest", required=True, help="Manifest file path.")
    parser.add_argument("--output-dir", required=True, help="Directory containing flutter jsons.")
    parser.set_defaults(func=_run_should_remove_flutter_sdk)


def _run_should_remove_flutter_sdk(namespace: argparse.Namespace) -> int:
    result = flutter_ops.should_remove_flutter_sdk(
        manifest_path=namespace.manifest,
        output_dir=namespace.output_dir,
    )
    sys.stdout.write("1\n" if result else "0\n")
    return 0


def _add_normalize_flutter_sdk_module(
    subparsers: argparse._SubParsersAction[argparse.ArgumentParser],
) -> None:
    parser = subparsers.add_parser(
        "normalize-flutter-sdk-module",
        help="Prune flutter-sdk build commands to safe operations.",
    )
    parser.add_argument("--manifest", required=True, help="Manifest file path.")
    parser.set_defaults(func=_run_normalize_flutter_sdk_module)


def _run_normalize_flutter_sdk_module(namespace: argparse.Namespace) -> int:
    flutter_ops.normalize_flutter_sdk_module(manifest_path=namespace.manifest)
    return 0


def _add_normalize_sdk_copy(
    subparsers: argparse._SubParsersAction[argparse.ArgumentParser],
) -> None:
    parser = subparsers.add_parser(
        "normalize-sdk-copy",
        help="Normalize the Flutter SDK copy command with fallbacks.",
    )
    parser.add_argument("--manifest", required=True, help="Manifest file path.")
    parser.set_defaults(func=_run_normalize_sdk_copy)


def _run_normalize_sdk_copy(namespace: argparse.Namespace) -> int:
    flutter_ops.normalize_sdk_copy(manifest_path=namespace.manifest)
    return 0


def _add_convert_flutter_git_to_archive(
    subparsers: argparse._SubParsersAction[argparse.ArgumentParser],
) -> None:
    parser = subparsers.add_parser(
        "convert-flutter-git-to-archive",
        help="Convert flutter git sources into archive references.",
    )
    parser.add_argument("--manifest", required=True, help="Manifest file path.")
    parser.add_argument("--archive", required=True, help="Archive filename.")
    parser.add_argument("--sha256", required=True, help="Archive SHA256 hash.")
    parser.set_defaults(func=_run_convert_flutter_git_to_archive)


def _run_convert_flutter_git_to_archive(namespace: argparse.Namespace) -> int:
    flutter_ops.convert_flutter_git_to_archive(
        manifest_path=namespace.manifest,
        archive_name=namespace.archive,
        sha256=namespace.sha256,
    )
    return 0


def _add_rewrite_flutter_git_url(
    subparsers: argparse._SubParsersAction[argparse.ArgumentParser],
) -> None:
    parser = subparsers.add_parser(
        "rewrite-flutter-git-url",
        help="Restore flutter git URL to the canonical upstream.",
    )
    parser.add_argument("--manifest", required=True, help="Manifest file path.")
    parser.set_defaults(func=_run_rewrite_flutter_git_url)


def _run_rewrite_flutter_git_url(namespace: argparse.Namespace) -> int:
    flutter_ops.rewrite_flutter_git_url(manifest_path=namespace.manifest)
    return 0


def _add_add_offline_sources(
    subparsers: argparse._SubParsersAction[argparse.ArgumentParser],
) -> None:
    parser = subparsers.add_parser(
        "add-offline-sources",
        help="Attach offline JSON sources to the lotti module.",
    )
    parser.add_argument("--manifest", required=True, help="Manifest file path.")
    parser.add_argument("--pubspec", help="pubspec JSON filename to include.")
    parser.add_argument("--cargo", help="cargo JSON filename to include.")
    parser.add_argument("--flutter-json", dest="flutter_json", help="Flutter SDK JSON filename.")
    parser.add_argument(
        "--rustup",
        action="append",
        default=None,
        help="Additional rustup JSON filenames (repeatable).",
    )
    parser.set_defaults(func=_run_add_offline_sources)


def _run_add_offline_sources(namespace: argparse.Namespace) -> int:
    sources_ops.add_offline_sources(
        manifest_path=namespace.manifest,
        pubspec=namespace.pubspec,
        cargo=namespace.cargo,
        rustup=namespace.rustup or [],
        flutter_file=namespace.flutter_json,
    )
    return 0


def _add_bundle_archive_sources(
    subparsers: argparse._SubParsersAction[argparse.ArgumentParser],
) -> None:
    parser = subparsers.add_parser(
        "bundle-archive-sources",
        help="Bundle archive/file sources referenced in the manifest.",
    )
    parser.add_argument("--manifest", required=True, help="Manifest file path.")
    parser.add_argument("--output-dir", required=True, help="Directory for cached artifacts.")
    parser.add_argument(
        "--download-missing",
        action="store_true",
        help="Download missing sources when cache lookup fails.",
    )
    parser.add_argument(
        "--search-root",
        action="append",
        default=None,
        help="Additional directories to search for cached artifacts.",
    )
    parser.set_defaults(func=_run_bundle_archive_sources)


def _run_bundle_archive_sources(namespace: argparse.Namespace) -> int:
    sources_ops.bundle_archive_sources(
        manifest_path=namespace.manifest,
        output_dir=namespace.output_dir,
        download_missing=namespace.download_missing,
        search_roots=namespace.search_root or [],
    )
    return 0


def _add_bundle_app_archive(
    subparsers: argparse._SubParsersAction[argparse.ArgumentParser],
) -> None:
    parser = subparsers.add_parser(
        "bundle-app-archive",
        help="Bundle the application source archive and attach metadata.",
    )
    parser.add_argument("--manifest", required=True, help="Manifest file path.")
    parser.add_argument("--archive", required=True, help="Archive filename (relative to output dir).")
    parser.add_argument("--sha256", required=True, help="Archive SHA256 hash.")
    parser.add_argument("--output-dir", required=True, help="Directory containing offline artifacts.")
    parser.set_defaults(func=_run_bundle_app_archive)


def _run_bundle_app_archive(namespace: argparse.Namespace) -> int:
    flutter_ops.bundle_app_archive(
        manifest_path=namespace.manifest,
        archive_name=namespace.archive,
        sha256=namespace.sha256,
        output_dir=namespace.output_dir,
    )
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Flatpak helper CLI")
    subparsers = parser.add_subparsers(dest="command", required=True)
    _add_pr_aware_pin(subparsers)
    _add_replace_url_with_path(subparsers)
    _add_ensure_setup_helper(subparsers)
    _add_pin_commit(subparsers)
    _add_ensure_nested_sdk(subparsers)
    _add_normalize_lotti_env(subparsers)
    _add_ensure_lotti_setup_helper(subparsers)
    _add_should_remove_flutter_sdk(subparsers)
    _add_normalize_flutter_sdk_module(subparsers)
    _add_normalize_sdk_copy(subparsers)
    _add_convert_flutter_git_to_archive(subparsers)
    _add_rewrite_flutter_git_url(subparsers)
    _add_add_offline_sources(subparsers)
    _add_bundle_archive_sources(subparsers)
    _add_bundle_app_archive(subparsers)
    return parser


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
