"""Flutter-specific operations for Flatpak manifests."""

# SDK operations
from .sdk import (
    ensure_nested_sdk,
    should_remove_flutter_sdk,
    normalize_flutter_sdk_module,
    normalize_sdk_copy,
    convert_flutter_git_to_archive,
    rewrite_flutter_git_url,
)

# Build operations
from .build import (
    ensure_flutter_pub_get_offline,
    ensure_dart_pub_offline_in_build,
    remove_flutter_config_command,
    remove_network_from_build_args,
    normalize_lotti_env,
)

# Plugin operations
from .plugins import (
    add_sqlite3_source,
    add_media_kit_mimalloc_source,
    add_sqlite3_patch,
)

# Rust operations
from .rust import (
    ensure_rust_sdk_env,
    remove_rustup_install,
)

# Patch operations
from .patches import (
    add_offline_build_patches,
)

# Offline fixes
from .offline_fixes import (
    apply_all_offline_fixes,
)

# Helper operations
from .helpers import (
    ensure_setup_helper_source,
    ensure_setup_helper_command,
    bundle_app_archive,
)

__all__ = [
    # SDK
    "ensure_nested_sdk",
    "should_remove_flutter_sdk",
    "normalize_flutter_sdk_module",
    "normalize_sdk_copy",
    "convert_flutter_git_to_archive",
    "rewrite_flutter_git_url",
    # Build
    "ensure_flutter_pub_get_offline",
    "ensure_dart_pub_offline_in_build",
    "remove_flutter_config_command",
    "remove_network_from_build_args",
    "normalize_lotti_env",
    # Plugins
    "add_sqlite3_source",
    "add_media_kit_mimalloc_source",
    "add_sqlite3_patch",
    # Rust
    "ensure_rust_sdk_env",
    "remove_rustup_install",
    # Patches
    "add_offline_build_patches",
    # Offline fixes
    "apply_all_offline_fixes",
    # Helpers
    "ensure_setup_helper_source",
    "ensure_setup_helper_command",
    "bundle_app_archive",
]
