from __future__ import annotations

import json
from pathlib import Path

from flatpak.manifest_tool import ci_ops


def test_pr_aware_environment_non_pr_event(tmp_path: Path) -> None:
    assert ci_ops.pr_aware_environment(event_name="push", event_path=str(tmp_path / "e.json")) == {}


def test_pr_aware_environment_missing_event_path() -> None:
    assert ci_ops.pr_aware_environment(event_name="pull_request", event_path=None) == {}


def test_pr_aware_environment_invalid_json(tmp_path: Path) -> None:
    p = tmp_path / "event.json"
    p.write_text("not json", encoding="utf-8")
    assert ci_ops.pr_aware_environment(event_name="pull_request", event_path=str(p)) == {}


def test_pr_aware_environment_happy_path(tmp_path: Path) -> None:
    payload = {
        "pull_request": {
            "head": {
                "sha": "deadbeef",
                "ref": "feature/x",
                "repo": {"clone_url": "https://github.com/user/repo.git"},
            }
        }
    }
    p = tmp_path / "event.json"
    p.write_text(json.dumps(payload), encoding="utf-8")
    env = ci_ops.pr_aware_environment(event_name="pull_request", event_path=str(p))
    assert env.get("PR_MODE") == "true"
    assert env.get("PR_HEAD_SHA") == "deadbeef"
    assert env.get("PR_HEAD_REF") == "feature/x"
    assert env.get("PR_HEAD_URL") == "https://github.com/user/repo.git"

