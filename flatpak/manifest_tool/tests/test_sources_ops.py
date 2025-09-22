from __future__ import annotations

from pathlib import Path

import pytest

from flatpak.manifest_tool import sources_ops
from flatpak.manifest_tool.manifest import ManifestDocument


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


def test_artifact_cache_rejects_unsupported_scheme(tmp_path: Path):
    cache = sources_ops.ArtifactCache(output_dir=tmp_path / "out", download_missing=True, search_roots=[])
    local_path, messages = cache.ensure_local("file.dat", "file:///tmp/file.dat")
    assert local_path is None
    assert messages == ["UNSUPPORTED file.dat scheme file file:///tmp/file.dat"]


def test_bundle_sources_for_module_skips_non_dict(tmp_path: Path):
    cache = sources_ops.ArtifactCache(output_dir=tmp_path / "out", download_missing=False, search_roots=[])
    changed, messages = sources_ops._bundle_sources_for_module("not-a-dict", cache)
    assert not changed
    assert messages == []


def test_bundle_sources_for_module_updates_sources(tmp_path: Path):
    cache = sources_ops.ArtifactCache(output_dir=tmp_path / "out", download_missing=False, search_roots=[])

    def fake_ensure_local(filename: str, url: str):
        return tmp_path / filename, [f"MOCK {filename}"]

    cache.ensure_local = fake_ensure_local  # type: ignore[assignment]

    module = {
        "sources": [
            {"type": "archive", "url": "https://example.com/archive.tar.gz"},
            {"type": "file", "url": "https://example.com/helper.dat"},
        ]
    }

    changed, messages = sources_ops._bundle_sources_for_module(module, cache)
    assert changed
    assert module["sources"][0]["path"] == "archive.tar.gz"
    assert module["sources"][1]["path"] == "helper.dat"
    assert all("MOCK" in message for message in messages)


def test_bundle_single_source_handles_missing_url(tmp_path: Path):
    cache = sources_ops.ArtifactCache(output_dir=tmp_path / "out", download_missing=False, search_roots=[])
    changed, messages = sources_ops._bundle_single_source({"type": "archive"}, cache)
    assert not changed
    assert messages == []


def test_bundle_single_source_converts_url(tmp_path: Path):
    cache = sources_ops.ArtifactCache(output_dir=tmp_path / "out", download_missing=False, search_roots=[])

    def fake_ensure_local(filename: str, url: str):
        return tmp_path / filename, ["FETCH"]

    cache.ensure_local = fake_ensure_local  # type: ignore[assignment]

    source = {"type": "archive", "url": "https://example.com/archive.tar.gz"}
    changed, messages = sources_ops._bundle_single_source(source, cache)
    assert changed
    assert source["path"] == "archive.tar.gz"
    assert "url" not in source
    assert messages == ["FETCH"]
