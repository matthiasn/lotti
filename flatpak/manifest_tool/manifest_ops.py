"""Pure manifest mutation helpers."""

from __future__ import annotations

from typing import Any, Iterable, Sequence, Optional

try:  # pragma: no cover
    from . import utils
    from .manifest import ManifestDocument, OperationResult
except ImportError:  # pragma: no cover
    import utils  # type: ignore
    from manifest import ManifestDocument, OperationResult  # type: ignore

_DEFAULT_REPO_URLS: tuple[str, ...] = (
    "https://github.com/matthiasn/lotti",
    "git@github.com:matthiasn/lotti",
)

_LOGGER = utils.get_logger("manifest_ops")


def _ensure_flutter_sdk_helper(module: dict, helper_name: str) -> bool:
    """Ensure flutter-sdk module has the setup helper.

    Args:
        module: The flutter-sdk module dictionary to check and modify
        helper_name: Name/path of the helper script to add

    Returns:
        True if the helper was added, False if already present
    """
    sources = module.setdefault("sources", [])
    # Check if setup-flutter.sh is already in the sources
    has_helper = any(
        isinstance(source, dict) and source.get("dest-filename") == "setup-flutter.sh"
        for source in sources
    )

    if not has_helper:
        sources.append(
            {
                "type": "file",
                "path": helper_name,
                "dest": "flutter/bin",
                "dest-filename": "setup-flutter.sh",
            }
        )
        return True
    return False


def _ensure_lotti_flutter_path(module: dict) -> bool:
    """Ensure lotti module PATH includes /app/flutter/bin.

    Args:
        module: The lotti module dictionary to check and modify

    Returns:
        True if PATH was modified, False if already correct
    """
    build_options = module.setdefault("build-options", {})
    env = build_options.setdefault("env", {})
    current_path = env.get("PATH", "")
    # Split PATH and filter out empty entries
    entries = [entry for entry in current_path.split(":") if entry]

    if "/app/flutter/bin" not in entries:
        env["PATH"] = (
            f"/app/flutter/bin:{current_path}" if current_path else "/app/flutter/bin"
        )
        return True
    return False


def ensure_flutter_setup_helper(
    document: ManifestDocument,
    *,
    helper_name: str,
) -> OperationResult:
    """Ensure flutter-sdk ships the setup helper and lotti PATH is configured.

    This function performs two critical tasks:
    1. Adds the setup-flutter.sh helper script to flutter-sdk module
    2. Ensures /app/flutter/bin is in the lotti module's PATH

    Args:
        document: The manifest document to modify
        helper_name: Path to the setup-flutter.sh helper script

    Returns:
        OperationResult indicating if changes were made
    """

    modules = document.ensure_modules()
    changed = False

    for module in modules:
        if not isinstance(module, dict):
            continue

        name = module.get("name")
        if name == "flutter-sdk":
            if _ensure_flutter_sdk_helper(module, helper_name):
                changed = True
        elif name == "lotti":
            if _ensure_lotti_flutter_path(module):
                changed = True

    if changed:
        document.mark_changed()
        _LOGGER.debug("Ensured setup helper %s is present", helper_name)
        return OperationResult.changed_result(f"Ensured setup helper {helper_name}")
    return OperationResult.unchanged()


def _get_normalized_targets(repo_urls: Sequence[str] | None) -> set[str]:
    """Get normalized target URLs for comparison."""
    if repo_urls is None:
        return {url.removesuffix(".git") for url in _DEFAULT_REPO_URLS}
    return {url.removesuffix(".git") for url in repo_urls}


def _should_pin_source(source: dict, normalized_targets: set[str], commit: str) -> bool:
    """Check if a source should be pinned to a commit.

    Args:
        source: Source dictionary to check
        normalized_targets: Set of target repository URLs (without .git)
        commit: The commit SHA to check against

    Returns:
        True if the source needs pinning, False otherwise
    """
    # Skip non-dict sources (e.g., string references)
    if not isinstance(source, dict):
        return False
    # Only process git sources
    if source.get("type") != "git":
        return False

    # Normalize source URL by removing trailing .git for comparison
    url = (source.get("url") or "").removesuffix(".git")
    if url not in normalized_targets:
        return False

    # Check if already pinned correctly (has correct commit and no branch)
    if source.get("commit") == commit and "branch" not in source:
        return False

    return True


def _pin_lotti_sources(module: dict, commit: str, normalized_targets: set[str]) -> bool:
    """Pin git sources in lotti module to specified commit."""
    changed = False
    for source in module.get("sources", []):
        if _should_pin_source(source, normalized_targets, commit):
            source["commit"] = commit
            source.pop("branch", None)
            changed = True
    return changed


def pin_commit(
    document: ManifestDocument,
    *,
    commit: str,
    repo_urls: Sequence[str] | None = None,
) -> OperationResult:
    """Pin lotti module's git sources to a specific commit.

    Replaces branch references with commit SHA to ensure reproducible builds.
    By default targets the official lotti repository URLs.

    Args:
        document: The manifest document to modify
        commit: The commit SHA to pin to
        repo_urls: Optional list of repository URLs to target
                  (defaults to official lotti repos)

    Returns:
        OperationResult indicating if changes were made
    """

    normalized_targets = _get_normalized_targets(repo_urls)
    modules = document.ensure_modules()
    changed = False

    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue
        if _pin_lotti_sources(module, commit, normalized_targets):
            changed = True
        break  # Only process lotti module

    if changed:
        document.mark_changed()
        _LOGGER.debug("Pinned lotti module to commit %s", commit)
        return OperationResult.changed_result(f"Pinned lotti module to {commit}")
    return OperationResult.unchanged()


def _is_lotti_module(module: Any) -> bool:
    """Check if a module is the lotti module."""
    return isinstance(module, dict) and module.get("name") == "lotti"


def _is_git_source(source: Any) -> bool:
    """Check if a source is a git source."""
    return isinstance(source, dict) and source.get("type") == "git"


def _normalize_repo_url(url: str) -> str:
    """Normalize a repository URL for comparison.

    Strips common prefixes and suffixes to allow comparison of different
    URL formats pointing to the same repository.

    Args:
        url: The repository URL to normalize

    Returns:
        Normalized URL string (e.g., "matthiasn/lotti")
    """
    # Remove trailing .git suffix if present
    if url.endswith(".git"):
        url = url[:-4]
    # Remove GitHub prefixes (both HTTPS and SSH formats)
    url = url.replace("https://github.com/", "")
    url = url.replace("git@github.com:", "")
    return url


def _is_lotti_repo_url(url: str) -> bool:
    """Check if a URL points to the official lotti repository."""
    normalized_url = _normalize_repo_url(url)
    # Only accept the official matthiasn/lotti repository
    return normalized_url == "matthiasn/lotti"


def _update_source_for_pr(source: dict, pr_url: str, pr_commit: str) -> list[str]:
    """Update a git source for a PR build.

    Args:
        source: The git source dictionary to update
        pr_url: The PR fork repository URL
        pr_commit: The PR head commit SHA

    Returns:
        List of change messages
    """
    changes = []

    if source.get("url") != pr_url:
        source["url"] = pr_url
        changes.append(f"Updated URL to {pr_url}")

    if source.get("commit") != pr_commit:
        source["commit"] = pr_commit
        source.pop("branch", None)
        changes.append(f"Pinned to PR commit {pr_commit}")

    return changes


def _update_source_for_commit(source: dict, commit: str) -> list[str]:
    """Update a git source with a specific commit.

    Args:
        source: The git source dictionary to update
        commit: The commit SHA to set

    Returns:
        List of change messages
    """
    changes = []
    current_commit = source.get("commit", "")

    if current_commit == "COMMIT_PLACEHOLDER" or current_commit != commit:
        source["commit"] = commit
        source.pop("branch", None)
        changes.append(f"Updated commit to {commit}")
    elif current_commit == commit and "branch" in source:
        source.pop("branch", None)
        changes.append("Removed branch reference")

    return changes


def update_manifest_for_build(
    document: ManifestDocument,
    *,
    commit: str | None = None,
    pr_url: str | None = None,
    pr_commit: str | None = None,
) -> OperationResult:
    """Update manifest for building, handling both PR and non-PR scenarios.

    For PR builds:
    - Updates the lotti git URL to the PR's fork repository
    - Pins the commit to the PR's head commit

    For non-PR builds:
    - Replaces COMMIT_PLACEHOLDER with the specified commit

    Args:
        document: The manifest document to update
        commit: The commit SHA for non-PR builds
        pr_url: The PR fork repository URL (for PR builds)
        pr_commit: The PR head commit SHA (for PR builds)

    Returns:
        OperationResult indicating what changed
    """
    modules = document.ensure_modules()
    changes = []

    for module in modules:
        if not _is_lotti_module(module):
            continue

        for source in module.get("sources", []):
            if not _is_git_source(source):
                continue

            url = source.get("url", "")
            if not _is_lotti_repo_url(url):
                continue

            # Update source based on build type
            if pr_url and pr_commit:
                changes.extend(_update_source_for_pr(source, pr_url, pr_commit))
            elif commit:
                changes.extend(_update_source_for_commit(source, commit))

    if changes:
        document.mark_changed()
        _LOGGER.debug("Updated manifest: %s", "; ".join(changes))
        return OperationResult(changed=True, messages=changes)
    return OperationResult.unchanged()


def ensure_module_include(
    document: ManifestDocument,
    *,
    module_name: str,
    before_name: Optional[str] = None,
) -> OperationResult:
    """Ensure a string module include (e.g., rustup-1.83.0.json) is present.

    This is used to include external JSON module definitions in the manifest.
    Build order can be controlled by inserting the include before a specific module.

    Args:
        document: The manifest document to modify
        module_name: The module include string to add (e.g., "rustup-1.83.0.json")
        before_name: Optional name of module to insert before (for build ordering)

    Returns:
        OperationResult indicating if the include was added
    """

    modules = document.ensure_modules()
    # Already present?
    for module in modules:
        if isinstance(module, str) and module == module_name:
            return OperationResult.unchanged()

    insert_index = None
    if before_name is not None:
        for idx, module in enumerate(modules):
            if isinstance(module, dict) and module.get("name") == before_name:
                insert_index = idx
                break
    if insert_index is None:
        modules.append(module_name)
    else:
        modules.insert(insert_index, module_name)

    document.mark_changed()
    _LOGGER.debug("Ensured module include %s", module_name)
    return OperationResult.changed_result(f"Ensured module include {module_name}")
