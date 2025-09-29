"""Manifest Tool - Utilities for manipulating Flatpak manifests.

This package provides comprehensive tools for preparing Flutter applications
for Flatpak/Flathub submission, handling offline builds, and ensuring compliance.
"""

# Core components - maintain backward compatibility
from .core import (
    ManifestDocument,
    OperationResult,
    merge_results,
    ValidationResult,
    check_flathub_compliance,
    get_logger,
    load_manifest,
    dump_manifest,
    format_shell_assignments,
)

# Re-export submodules for backward compatibility
from .core import utils
from .core import validation
from .core import manifest
from .operations import manifest as manifest_ops
from .operations import sources as sources_ops
from .operations import ci as ci_ops
from .build import utils as build_utils

# Create flutter_ops module with all functions for backward compatibility
from . import flutter
import sys
from types import ModuleType

# Create a dynamic module that contains all flutter functions
flutter_ops = ModuleType("flutter_ops")
for name in dir(flutter):
    if not name.startswith("_"):
        setattr(flutter_ops, name, getattr(flutter, name))
sys.modules["manifest_tool.flutter_ops"] = flutter_ops

__version__ = "1.0.0"

__all__ = [
    # Backward compatibility modules
    "utils",
    "validation",
    "manifest",
    "manifest_ops",
    "sources_ops",
    "ci_ops",
    "flutter_ops",
    "build_utils",
    "cli",
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
