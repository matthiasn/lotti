"""Validation module - backward compatibility wrapper.

This module imports all functions from the new modular core package
to maintain backward compatibility with existing code.
"""

from .core.validation import *

__all__ = [
    "validate_manifest",
]
