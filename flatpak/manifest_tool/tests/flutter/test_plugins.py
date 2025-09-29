"""Tests for Flutter plugin dependency operations."""

from __future__ import annotations

import pytest

from manifest_tool.flutter import plugins as flutter_plugins


def test_add_sqlite3_source(make_document):
    """Test adding SQLite source for sqlite3_flutter_libs plugin."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # Start with no sources
    lotti["sources"] = []

    result = flutter_plugins.add_sqlite3_source(document)

    assert result.changed
    assert "sqlite" in str(result.messages).lower()

    # Check that SQLite sources were added (one for each architecture)
    sources = lotti["sources"]
    assert len(sources) == 2

    # Check x86_64 source
    x64_source = next(s for s in sources if "x86_64" in s.get("only-arches", []))
    assert x64_source["type"] == "file"
    assert "sqlite-autoconf-3500400.tar.gz" in x64_source["url"]
    assert (
        x64_source["sha256"]
        == "a3db587a1b92ee5ddac2f66b3edb41b26f9c867275782d46c3a088977d6a5b18"
    )
    assert (
        x64_source["dest"]
        == "./build/linux/x64/release/_deps/sqlite3-subbuild/sqlite3-populate-prefix/src"
    )
    assert x64_source["dest-filename"] == "sqlite-autoconf-3500400.tar.gz"

    # Check aarch64 source
    arm64_source = next(s for s in sources if "aarch64" in s.get("only-arches", []))
    assert arm64_source["type"] == "file"
    assert "sqlite-autoconf-3500400.tar.gz" in arm64_source["url"]
    assert (
        arm64_source["sha256"]
        == "a3db587a1b92ee5ddac2f66b3edb41b26f9c867275782d46c3a088977d6a5b18"
    )
    assert (
        arm64_source["dest"]
        == "./build/linux/arm64/release/_deps/sqlite3-subbuild/sqlite3-populate-prefix/src"
    )
    assert arm64_source["dest-filename"] == "sqlite-autoconf-3500400.tar.gz"

    # Run again - should not change
    result2 = flutter_plugins.add_sqlite3_source(document)
    assert not result2.changed


def test_add_media_kit_mimalloc_source(make_document):
    """Test adding mimalloc source for media_kit plugin."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # Start with no sources
    lotti["sources"] = []

    result = flutter_plugins.add_media_kit_mimalloc_source(document)

    assert result.changed
    assert "mimalloc" in str(result.messages).lower()

    # Check that mimalloc sources were added (one for each architecture)
    sources = lotti["sources"]
    assert len(sources) == 2

    # Check x86_64 source
    x64_source = next(s for s in sources if "x86_64" in s.get("only-arches", []))
    assert x64_source["type"] == "file"
    assert "mimalloc/archive/refs/tags/v2.1.2.tar.gz" in x64_source["url"]
    assert (
        x64_source["sha256"]
        == "2b1bff6f717f9725c70bf8d79e4786da13de8a270059e4ba0bdd262ae7be46eb"
    )
    assert x64_source["dest"] == "./build/linux/x64/release"
    assert x64_source["dest-filename"] == "mimalloc-2.1.2.tar.gz"

    # Check aarch64 source
    arm64_source = next(s for s in sources if "aarch64" in s.get("only-arches", []))
    assert arm64_source["type"] == "file"
    assert "mimalloc/archive/refs/tags/v2.1.2.tar.gz" in arm64_source["url"]
    assert (
        arm64_source["sha256"]
        == "2b1bff6f717f9725c70bf8d79e4786da13de8a270059e4ba0bdd262ae7be46eb"
    )
    assert arm64_source["dest"] == "./build/linux/arm64/release"
    assert arm64_source["dest-filename"] == "mimalloc-2.1.2.tar.gz"

    # Run again - should not change
    result2 = flutter_plugins.add_media_kit_mimalloc_source(document)
    assert not result2.changed


def test_add_media_kit_mimalloc_source_preserves_existing(make_document):
    """Test that adding mimalloc preserves existing sources."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # Start with existing sources
    lotti["sources"] = [
        {"type": "git", "url": "https://github.com/test/test.git"},
        {"type": "file", "path": "some-file.txt"},
    ]

    result = flutter_plugins.add_media_kit_mimalloc_source(document)

    assert result.changed
    sources = lotti["sources"]
    assert len(sources) == 4  # Original 2 + 2 mimalloc sources

    # Original sources still there
    assert sources[0]["type"] == "git"
    assert sources[1]["type"] == "file"
    # New mimalloc sources
    assert any(s.get("dest-filename") == "mimalloc-2.1.2.tar.gz" for s in sources)


def test_add_sqlite3_patch(make_document):
    """Test adding SQLite patch for offline builds."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # Start with no sources
    lotti["sources"] = []

    result = flutter_plugins.add_sqlite3_patch(document)

    assert result.changed
    sources = lotti["sources"]

    # Check that patch was added
    assert len(sources) == 1
    patch = sources[0]
    assert patch["type"] == "patch"
    assert patch["path"] == "sqlite3_flutter_libs/0.5.34-CMakeLists.txt.patch"
    assert patch["dest"] == ".pub-cache/hosted/pub.dev/sqlite3_flutter_libs-0.5.39"

    # Run again - should not change
    result2 = flutter_plugins.add_sqlite3_patch(document)
    assert not result2.changed
