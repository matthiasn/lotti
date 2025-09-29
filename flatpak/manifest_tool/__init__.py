"""Manifest Tool - Utilities for manipulating Flatpak manifests.

This package provides comprehensive tools for preparing Flutter applications
for Flatpak/Flathub submission, handling offline builds, and ensuring compliance.
"""

# Core components
from .core.manifest import ManifestDocument, OperationResult, merge_results
from .core.utils import (
    load_manifest,
    dump_manifest,
    format_shell_assignments,
    get_logger,
)
from .core.validation import ValidationResult, check_flathub_compliance

# Re-export for convenience
from . import flutter
from . import build
from . import operations
from . import core

__version__ = "1.0.0"

__all__ = [
    # Modules
    "flutter",
    "build",
    "operations",
    "core",
    # Core exports
    "ManifestDocument",
    "OperationResult",
    "ValidationResult",
    "merge_results",
    "check_flathub_compliance",
    "get_logger",
    "load_manifest",
    "dump_manifest",
    "format_shell_assignments",
]
