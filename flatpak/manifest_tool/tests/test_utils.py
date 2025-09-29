from __future__ import annotations

from pathlib import Path

from manifest_tool.core import utils


def test_load_and_dump_manifest(tmp_path: Path) -> None:
    p = tmp_path / "m.yml"
    # load missing returns empty dict
    assert utils.load_manifest(p) == {}
    data = {"modules": [{"name": "lotti", "sources": []}]}
    utils.dump_manifest(p, data)
    loaded = utils.load_manifest(p)
    assert loaded == data
