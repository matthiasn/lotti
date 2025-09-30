"""Operations for manipulating Flatpak manifests."""

from .manifest import (
    pin_commit,
    ensure_flutter_setup_helper,
    ensure_module_include,
    update_manifest_for_build,
    ensure_screenshot_asset,
)

from .sources import (
    replace_url_with_path,
    replace_url_with_path_in_manifest,
    ArtifactCache,
    add_offline_sources,
    bundle_archive_sources,
    remove_rustup_sources,
)

from .ci import (
    pr_aware_environment,
)

__all__ = [
    # Manifest operations
    "pin_commit",
    "ensure_flutter_setup_helper",
    "ensure_module_include",
    "update_manifest_for_build",
    "ensure_screenshot_asset",
    # Source operations
    "replace_url_with_path",
    "replace_url_with_path_in_manifest",
    "ArtifactCache",
    "add_offline_sources",
    "bundle_archive_sources",
    "remove_rustup_sources",
    # CI operations
    "pr_aware_environment",
]
