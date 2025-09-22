"""Utility helpers shared across Flatpak automation modules."""

from __future__ import annotations

import shlex
import logging
from pathlib import Path
from typing import Any, Mapping

import yaml


_BOOLEAN_VALUES = {"true", "false"}
_LOGGER_BASENAME = "flatpak_helpers"
_logger_configured = False


def get_logger(name: str | None = None) -> logging.Logger:
    """Return a module-level logger with default configuration."""

    global _logger_configured  # noqa: PLW0603 - intentional module-level guard
    base_logger = logging.getLogger(_LOGGER_BASENAME)
    if not _logger_configured:
        handler = logging.StreamHandler()
        handler.setFormatter(logging.Formatter("%(levelname)s: %(message)s"))
        base_logger.addHandler(handler)
        base_logger.setLevel(logging.INFO)
        _logger_configured = True

    if name:
        return base_logger.getChild(name)
    return base_logger


def format_shell_assignments(values: Mapping[str, str]) -> str:
    """Render a mapping as newline-separated shell assignments."""

    assignments: list[str] = []
    for key, raw_value in values.items():
        value = raw_value
        if value.lower() in _BOOLEAN_VALUES:
            assignments.append(f"{key}={value.lower()}")
        else:
            assignments.append(f"{key}={shlex.quote(value)}")
    return "\n".join(assignments)


def load_manifest(path: str | Path) -> dict[str, Any]:
    """Load a YAML manifest, returning an empty dict when absent."""

    manifest_path = Path(path)
    if not manifest_path.is_file():
        return {}
    contents = manifest_path.read_text(encoding="utf-8")
    data = yaml.safe_load(contents)
    return data or {}


def dump_manifest(path: str | Path, data: Mapping[str, Any]) -> None:
    """Persist manifest data with stable ordering."""

    manifest_path = Path(path)
    manifest_path.write_text(
        yaml.safe_dump(data, sort_keys=False),
        encoding="utf-8",
    )
