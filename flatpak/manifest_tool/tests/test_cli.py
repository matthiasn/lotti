from __future__ import annotations

import yaml

from flatpak.manifest_tool import cli
from flatpak.manifest_tool.tests.conftest import SAMPLE_MANIFEST


def test_cli_normalize_lotti_env(manifest_file, capsys):
    exit_code = cli.main([
        "normalize-lotti-env",
        "--manifest",
        str(manifest_file),
        "--layout",
        "top",
        "--append-path",
    ])

    assert exit_code == 0
    captured = capsys.readouterr()
    assert "Normalized lotti PATH" in captured.out

    data = yaml.safe_load(manifest_file.read_text(encoding="utf-8"))
    lotti = next(module for module in data["modules"] if module["name"] == "lotti")
    assert lotti["build-options"]["env"]["PATH"].startswith("/app/flutter/bin")


def test_cli_bundle_archive_sources(tmp_path, capsys):
    manifest_path = tmp_path / "manifest.yml"
    manifest_path.write_text(SAMPLE_MANIFEST, encoding="utf-8")

    cache_root = tmp_path / "cache"
    cache_root.mkdir()
    (cache_root / "archive.tar.gz").write_text("data", encoding="utf-8")
    (cache_root / "helper.dat").write_text("data", encoding="utf-8")

    exit_code = cli.main(
        [
            "bundle-archive-sources",
            "--manifest",
            str(manifest_path),
            "--output-dir",
            str(tmp_path / "out"),
            "--search-root",
            str(cache_root),
        ]
    )

    assert exit_code == 0
    captured = capsys.readouterr()
    assert "BUNDLE archive.tar.gz" in captured.out

    data = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
    lotti = next(module for module in data["modules"] if module["name"] == "lotti")
    archive_source = next(source for source in lotti["sources"] if isinstance(source, dict) and source.get("type") == "archive")
    assert archive_source.get("path") == "archive.tar.gz"
    assert "url" not in archive_source


def test_cli_pin_commit(tmp_path, capsys):
    manifest_path = tmp_path / "manifest.yml"
    manifest_path.write_text(SAMPLE_MANIFEST, encoding="utf-8")

    exit_code = cli.main([
        "pin-commit",
        "--manifest",
        str(manifest_path),
        "--commit",
        "abc123",
    ])

    assert exit_code == 0
    captured = capsys.readouterr()
    assert "Pinned lotti module" in captured.out

    data = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
    lotti = next(module for module in data["modules"] if module["name"] == "lotti")
    commits = [source.get("commit") for source in lotti["sources"] if isinstance(source, dict)]
    assert "abc123" in commits
