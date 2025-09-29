"""Build utilities module - backward compatibility wrapper.

This module imports all functions from the new modular build package
to maintain backward compatibility with existing code.
"""

from .build.utils import *

__all__ = [
    "find_flutter_sdk",
    "prepare_build_directory",
    "copy_flutter_sdk",
]
