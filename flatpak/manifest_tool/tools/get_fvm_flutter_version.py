#!/usr/bin/env python3
"""Print the Flutter SDK version pinned by FVM, if available."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Mapping

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_FVM_CONFIG = ROOT / ".fvm" / "fvm_config.json"


def read_version(config_path: Path) -> str | None:
    if not config_path.is_file():
        return None
    try:
        data = json.loads(config_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    version = data.get("flutterSdkVersion") or data.get("flutterSdk")
    if isinstance(version, str) and version.strip():
        return version.strip()
    return None


def main_with_env(env: Mapping[str, str] | None = None) -> int:
    env = env or os.environ
    override = env.get("FVM_CONFIG_PATH")
    config_path = Path(override) if override else DEFAULT_FVM_CONFIG
    version = read_version(config_path)
    if not version:
        return 1
    print(version)
    return 0


def main() -> int:  # pragma: no cover - thin wrapper
    return main_with_env()


if __name__ == "__main__":
    raise SystemExit(main())
