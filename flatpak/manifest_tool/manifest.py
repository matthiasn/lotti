"""Manifest module - backward compatibility wrapper.

This module imports all classes from the new modular core package
to maintain backward compatibility with existing code.
"""

from .core.manifest import *

__all__ = [
    "OperationResult",
    "ManifestDocument",
    "get_logger",
]
