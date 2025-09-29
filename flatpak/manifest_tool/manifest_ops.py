"""Manifest operations module - backward compatibility wrapper.

This module imports all functions from the new modular operations package
to maintain backward compatibility with existing code.
"""

from .operations.manifest import *

__all__ = [
    "add_sdk",
    "ensure_module_include",
    "ensure_modules",
    "remove_git_sources",
    "remove_module_by_name",
    "set_build_option",
]
