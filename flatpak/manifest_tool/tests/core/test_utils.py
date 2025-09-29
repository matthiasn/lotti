from __future__ import annotations

from pathlib import Path

from manifest_tool.core import utils


def test_format_shell_assignments_quotes_and_bools() -> None:
    out = utils.format_shell_assignments(
        {
            "BOOL": "true",
            "NAME": "hello world",
            "SHA": "deadbeef",
        }
    )
    # Booleans are unquoted lowercase
    assert "BOOL=true" in out
    # Strings containing spaces are shell-quoted
    assert "NAME='hello world'" in out
    # Other strings may be quoted or not depending on shell rules; parse assignments
    pairs = [line.split("=", 1) for line in out.strip().splitlines() if "=" in line]
    assigns = {k: v for k, v in pairs}
    assert assigns.get("SHA", "").strip("'\"") == "deadbeef"


def test_load_and_dump_manifest(tmp_path: Path) -> None:
    p = tmp_path / "m.yml"
    # load missing returns empty dict
    assert utils.load_manifest(p) == {}
    data = {"modules": [{"name": "lotti", "sources": []}]}
    utils.dump_manifest(p, data)
    loaded = utils.load_manifest(p)
    assert loaded == data
