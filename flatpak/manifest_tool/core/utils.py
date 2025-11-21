"""Utility helpers shared across Flatpak automation modules."""

from __future__ import annotations

import logging
from pathlib import Path
from typing import Any, Mapping

import yaml


class _LiteralSafeDumper(yaml.SafeDumper):
    """Custom dumper that emits literal blocks for multiline strings."""


def _repr_str(dumper: yaml.Dumper, data: str) -> yaml.nodes.ScalarNode:
    style = "|" if "\n" in data else None
    return dumper.represent_scalar("tag:yaml.org,2002:str", data, style=style)


_LiteralSafeDumper.add_representer(str, _repr_str)


_LOGGER_BASENAME = "flatpak_helpers"
_logger_configured = False


def get_logger(name: str | None = None) -> logging.Logger:
    """Return a module-level logger with default configuration."""

    global _logger_configured  # intentional module-level guard
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
        yaml.dump(data, sort_keys=False, Dumper=_LiteralSafeDumper),
        encoding="utf-8",
    )
