from __future__ import annotations

from pathlib import Path

import pytest

from flatpak.python import sources_ops
from flatpak.python.manifest import ManifestDocument


def test_replace_url_with_path_text_rewrites_lines():
    original = """\
    sources:
      - type: file
        url: https://example.com/file.dat
    """
    updated, changed = sources_ops.replace_url_with_path_text(original, "file.dat", "file.dat")
    assert changed
    assert "path: file.dat" in updated


def test_replace_url_with_path(tmp_path: Path):
    manifest_path = tmp_path / "manifest.yml"
    manifest_path.write_text(
        """sources:\n  - type: file\n    url: https://example.com/file.dat\n""",
        encoding="utf-8",
    )

    result = sources_ops.replace_url_with_path(
        manifest_path=str(manifest_path),
        identifier="file.dat",
        path_value="file.dat",
    )

    assert result is True
    assert "path: file.dat" in manifest_path.read_text(encoding="utf-8")


def test_add_offline_sources(make_document):
    document = make_document()
    result = sources_ops.add_offline_sources(
        document,
        pubspec="pubspec-sources.json",
        cargo="cargo-sources.json",
        rustup=["rustup.json"],
        flutter_file="setup-flutter.sh",
    )

    assert result.changed
    lotti = next(module for module in document.data["modules"] if module["name"] == "lotti")
    sources = lotti["sources"]
    assert "pubspec-sources.json" in sources
    assert "cargo-sources.json" in sources
    assert "rustup.json" in sources
    assert any(isinstance(src, dict) and src.get("path") == "setup-flutter.sh" for src in sources)


def test_bundle_archive_sources_rewrites_urls(make_document, tmp_path: Path):
    document = make_document()
    cache_root = tmp_path / "cache"
    cache_root.mkdir()
    (cache_root / "archive.tar.gz").write_text("data", encoding="utf-8")
    (cache_root / "helper.dat").write_text("data", encoding="utf-8")

    cache = sources_ops.ArtifactCache(
        output_dir=tmp_path / "out",
        download_missing=False,
        search_roots=[cache_root],
    )

    result = sources_ops.bundle_archive_sources(document, cache)

    assert result.changed
    lotti = next(module for module in document.data["modules"] if module["name"] == "lotti")
    archive_source = next(
        source for source in lotti["sources"] if isinstance(source, dict) and source.get("type") == "archive"
    )
    helper_source = next(
        source for source in lotti["sources"] if isinstance(source, dict) and source.get("path") == "helper.dat"
    )

    assert archive_source.get("path") == "archive.tar.gz"
    assert "url" not in archive_source
    assert "BUNDLE archive.tar.gz" in result.messages
    assert helper_source.get("type") == "file"


def test_artifact_cache_reports_missing(tmp_path: Path):
    cache = sources_ops.ArtifactCache(output_dir=tmp_path / "out", download_missing=False, search_roots=[])
    local_path, messages = cache.ensure_local("missing.dat", "https://example.com/missing.dat")
    assert local_path is None
    assert messages == ["MISSING missing.dat https://example.com/missing.dat"]
