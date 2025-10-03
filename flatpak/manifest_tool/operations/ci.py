"""CI-oriented helpers for Flatpak automation."""

from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Dict, Mapping

_LOGGER = logging.getLogger(__name__)


def pr_aware_environment(*, event_name: str | None, event_path: str | None) -> Mapping[str, str]:
    """Extract head repo metadata for pull request events.

    Returns a mapping of shell assignments suitable for ``eval`` in bash.
    Empty mapping when data is unavailable, ensuring callers can keep defaults.
    """

    if event_name != "pull_request":
        return {}

    if not event_path:
        return {}

    payload_path = Path(event_path)
    if not payload_path.is_file():
        return {}

    try:
        payload = json.loads(payload_path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as e:
        _LOGGER.warning("Failed to load event payload from %s: %s", payload_path, e)
        return {}

    head = payload.get("pull_request", {}).get("head", {})
    sha = head.get("sha") or ""
    ref = head.get("ref") or ""
    repo = head.get("repo", {})
    url = repo.get("clone_url") or ""

    if not sha or not url:
        return {}

    assignments: Dict[str, str] = {
        "PR_MODE": "true",
        "PR_HEAD_SHA": sha,
        "PR_HEAD_REF": ref,
        "PR_HEAD_URL": url,
    }
    return assignments
