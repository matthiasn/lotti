"""Tests for plugin-related operations."""

from __future__ import annotations

from pathlib import Path  # noqa: F401
import pytest  # noqa: F401

from manifest_tool.flutter import plugins as flutter_plugins
from manifest_tool.core.manifest import ManifestDocument


def test_add_media_kit_mimalloc_source_basic(make_document):
    """Test adding mimalloc source for media_kit plugin."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")
    lotti["sources"] = []

    result = flutter_plugins.add_media_kit_mimalloc_source(document)

    assert result.changed
    assert "mimalloc" in str(result.messages).lower()

    sources = lotti["sources"]
    assert len(sources) == 2  # x86_64 and aarch64

    # Check both sources
    for source in sources:
        assert source["type"] == "file"
        assert "mimalloc" in source["url"]
        assert source["dest-filename"] == "mimalloc-2.1.2.tar.gz"
        assert "only-arches" in source
        assert len(source["only-arches"]) == 1


def test_add_media_kit_mimalloc_detects_bundled_sources(make_document):
    """Test that mimalloc detection works with bundled sources (path instead of url)."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # Add bundled mimalloc sources (using path instead of url)
    lotti["sources"] = [
        {
            "type": "file",
            "only-arches": ["x86_64"],
            "path": "/path/to/bundled/mimalloc-2.1.2.tar.gz",  # path instead of url
            "sha256": "2b1bff6f717f9725c70bf8d79e4786da13de8a270059e4ba0bdd262ae7be46eb",
            "dest": "./build/linux/x64/release",
            "dest-filename": "mimalloc-2.1.2.tar.gz",
        },
        {
            "type": "file",
            "only-arches": ["aarch64"],
            "path": "/path/to/bundled/mimalloc-2.1.2.tar.gz",  # path instead of url
            "sha256": "2b1bff6f717f9725c70bf8d79e4786da13de8a270059e4ba0bdd262ae7be46eb",
            "dest": "./build/linux/arm64/release",
            "dest-filename": "mimalloc-2.1.2.tar.gz",
        },
    ]

    result = flutter_plugins.add_media_kit_mimalloc_source(document)

    # Should not add duplicates
    assert not result.changed
    sources = lotti["sources"]
    assert len(sources) == 2  # Still only 2, not 4


def test_add_media_kit_mimalloc_detects_by_dest_filename(make_document):
    """Test that detection works by dest-filename even if path/url don't contain 'mimalloc'."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # Add sources with renamed paths but correct dest-filename
    lotti["sources"] = [
        {
            "type": "file",
            "only-arches": ["x86_64"],
            "path": "/renamed/archive.tar.gz",  # Doesn't contain 'mimalloc'
            "sha256": "2b1bff6f717f9725c70bf8d79e4786da13de8a270059e4ba0bdd262ae7be46eb",
            "dest": "./build/linux/x64/release",
            "dest-filename": "mimalloc-2.1.2.tar.gz",  # But dest-filename matches
        }
    ]

    result = flutter_plugins.add_media_kit_mimalloc_source(document)

    # Should only add aarch64, not x86_64
    assert result.changed
    sources = lotti["sources"]
    assert len(sources) == 2

    # Verify we have one for each architecture
    arches = [source["only-arches"][0] for source in sources]
    assert set(arches) == {"x86_64", "aarch64"}


def test_add_media_kit_mimalloc_preserves_other_sources(make_document):
    """Test that adding mimalloc preserves existing unrelated sources."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # Start with other sources
    lotti["sources"] = [
        {"type": "git", "url": "https://github.com/test/test.git"},
        {"type": "file", "path": "some-file.txt"},
    ]

    original_sources = lotti["sources"].copy()

    result = flutter_plugins.add_media_kit_mimalloc_source(document)

    assert result.changed
    sources = lotti["sources"]
    assert len(sources) == 4  # Original 2 + 2 mimalloc

    # Original sources still there
    for orig in original_sources:
        assert orig in sources


def test_add_media_kit_mimalloc_idempotent(make_document):
    """Test that the operation is idempotent."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")
    lotti["sources"] = []

    # First call
    result1 = flutter_plugins.add_media_kit_mimalloc_source(document)
    assert result1.changed

    sources_after_first = lotti["sources"].copy()

    # Second call
    result2 = flutter_plugins.add_media_kit_mimalloc_source(document)
    assert not result2.changed

    sources_after_second = lotti["sources"]
    assert sources_after_first == sources_after_second


def test_add_media_kit_mimalloc_wrong_dest_not_detected(make_document):
    """Test that sources with wrong dest are not considered matches."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # Add mimalloc source but with wrong dest
    lotti["sources"] = [
        {
            "type": "file",
            "only-arches": ["x86_64"],
            "url": "https://github.com/microsoft/mimalloc/archive/refs/tags/v2.1.2.tar.gz",
            "dest": "./wrong/path",  # Wrong dest
            "dest-filename": "mimalloc-2.1.2.tar.gz",
        }
    ]

    result = flutter_plugins.add_media_kit_mimalloc_source(document)

    # Should add both architectures with correct dest
    assert result.changed
    sources = lotti["sources"]
    assert len(sources) == 3  # Original wrong one + 2 correct ones

    # Check that correct ones were added
    correct_x64 = [
        s
        for s in sources
        if s.get("dest") == "./build/linux/x64/release"
        and "x86_64" in s.get("only-arches", [])
    ]
    assert len(correct_x64) == 1


def test_add_media_kit_mimalloc_no_lotti_module(make_document):
    """Test when lotti module doesn't exist."""
    document = make_document()

    # Remove lotti module
    document.data["modules"] = [
        m
        for m in document.data["modules"]
        if not (isinstance(m, dict) and m.get("name") == "lotti")
    ]

    result = flutter_plugins.add_media_kit_mimalloc_source(document)

    # Should not change anything
    assert not result.changed


def test_add_media_kit_mimalloc_mixed_bundled_and_url(make_document):
    """Test with mix of bundled (path) and unbundled (url) sources."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # Add x86_64 as bundled, aarch64 will be added as url
    lotti["sources"] = [
        {
            "type": "file",
            "only-arches": ["x86_64"],
            "path": "/bundled/mimalloc.tar.gz",  # bundled with path
            "dest": "./build/linux/x64/release",
            "dest-filename": "mimalloc-2.1.2.tar.gz",
        }
    ]

    result = flutter_plugins.add_media_kit_mimalloc_source(document)

    # Should only add aarch64
    assert result.changed
    sources = lotti["sources"]
    assert len(sources) == 2

    # Check the new aarch64 source has url
    aarch64_source = next(s for s in sources if "aarch64" in s.get("only-arches", []))
    assert "url" in aarch64_source
    assert "mimalloc" in aarch64_source["url"]
