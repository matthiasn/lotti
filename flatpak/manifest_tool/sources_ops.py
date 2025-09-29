"""Sources operations module - backward compatibility wrapper.

This module imports all functions from the new modular operations package
to maintain backward compatibility with existing code.
"""

from .operations.sources import *

__all__ = [
    "add_sources",
    "archive_source",
    "directory_source",
    "extra_data_source",
    "file_source",
    "git_source",
    "inline_source",
    "json_source",
    "patch_source",
    "shell_source",
    "sources_from_json",
    "sources_from_json_file",
]
