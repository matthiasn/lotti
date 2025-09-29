"""Tests for offline build patch operations."""

from __future__ import annotations

import pytest

from manifest_tool.flutter import patches as flutter_patches


def test_add_offline_build_patches_adds_sources(make_document):
    """Test that add_offline_build_patches adds required patch sources."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # Ensure sources list exists
    if "sources" not in lotti:
        lotti["sources"] = []

    result = flutter_patches.add_offline_build_patches(document)

    assert result.changed
    assert "sqlite offline patch" in str(result.messages).lower()
    assert "cargo offline config" in str(result.messages).lower()
    assert "cargokit offline patch" in str(result.messages).lower()

    sources = lotti.get("sources", [])

    # Check that patch sources were added
    assert any(
        s.get("path") == "patches/sqlite3-offline.patch"
        for s in sources
        if isinstance(s, dict)
    )
    assert any(
        s.get("path") == "patches/cargokit-offline.patch"
        for s in sources
        if isinstance(s, dict)
    )
    assert any(
        (s.get("dest") == ".cargo" and s.get("dest-filename") == "config.toml")
        for s in sources
        if isinstance(s, dict)
    )


def test_add_cmake_offline_patches(make_document):
    """Test that add_cmake_offline_patches adds SQLite patch."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    result = flutter_patches.add_cmake_offline_patches(document)

    assert result.changed
    assert "sqlite offline patch" in str(result.messages).lower()

    sources = lotti.get("sources", [])

    # Check SQLite patch was added
    sqlite_patch = next(
        (
            s
            for s in sources
            if isinstance(s, dict) and s.get("path") == "patches/sqlite3-offline.patch"
        ),
        None,
    )
    assert sqlite_patch is not None
    assert sqlite_patch["type"] == "patch"
    # Patches don't have strip property (that's for archives)


def test_add_cargokit_offline_patches(make_document):
    """Test that add_cargokit_offline_patches adds cargo config and patch."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    result = flutter_patches.add_cargokit_offline_patches(document)

    assert result.changed
    assert "cargo offline config" in str(result.messages).lower()
    assert "cargokit offline patch" in str(result.messages).lower()

    sources = lotti.get("sources", [])

    # Check cargo config was added
    cargo_config = next(
        (
            s
            for s in sources
            if isinstance(s, dict)
            and s.get("dest") == ".cargo"
            and s.get("dest-filename") == "config.toml"
        ),
        None,
    )
    assert cargo_config is not None
    assert cargo_config["type"] == "inline"
    assert "[net]" in cargo_config["contents"]
    assert "offline = true" in cargo_config["contents"]

    # Check cargokit patch was added
    cargokit_patch = next(
        (
            s
            for s in sources
            if isinstance(s, dict) and s.get("path") == "patches/cargokit-offline.patch"
        ),
        None,
    )
    assert cargokit_patch is not None
    assert cargokit_patch["type"] == "patch"


def test_add_offline_build_patches_idempotent(make_document):
    """Test that add_offline_build_patches is idempotent."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # First call
    result1 = flutter_patches.add_offline_build_patches(document)
    assert result1.changed

    sources_after_first = lotti.get("sources", []).copy()

    # Second call
    result2 = flutter_patches.add_offline_build_patches(document)
    assert not result2.changed

    sources_after_second = lotti.get("sources", [])

    # Sources should not have duplicates
    assert len(sources_after_first) == len(sources_after_second)


def test_add_offline_build_patches_no_lotti_module(make_document):
    """Test when lotti module doesn't exist."""
    document = make_document()

    # Remove lotti module
    document.data["modules"] = [
        m
        for m in document.data["modules"]
        if not (isinstance(m, dict) and m.get("name") == "lotti")
    ]

    result = flutter_patches.add_offline_build_patches(document)

    # Should not change anything
    assert not result.changed


def test_add_offline_build_patches_no_sources(make_document):
    """Test when lotti module has no sources."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # Remove sources
    if "sources" in lotti:
        del lotti["sources"]

    result = flutter_patches.add_offline_build_patches(document)

    assert result.changed

    # sources should be created
    assert "sources" in lotti
    sources = lotti["sources"]

    # All patches should be present
    assert any(
        s.get("path") == "patches/sqlite3-offline.patch"
        for s in sources
        if isinstance(s, dict)
    )
    assert any(
        s.get("path") == "patches/cargokit-offline.patch"
        for s in sources
        if isinstance(s, dict)
    )
    assert any(
        (s.get("dest") == ".cargo" and s.get("dest-filename") == "config.toml")
        for s in sources
        if isinstance(s, dict)
    )
