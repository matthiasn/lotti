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
    # SQLite patches are handled by flatpak-flutter generated patches, not added here
    assert "cargokit patch" in str(result.messages).lower()

    sources = lotti.get("sources", [])

    # Check that cargokit patches were added for detected packages
    cargokit_patches = [
        s
        for s in sources
        if isinstance(s, dict)
        and s.get("type") == "patch"
        and "cargokit" in s.get("dest", "")
    ]
    # Should have patches for the fallback packages at minimum
    assert (
        len(cargokit_patches) >= 3
    )  # super_native_extensions, flutter_vodozemac, irondash_engine_context

    # Note: We don't add cargo config anymore - cargo-sources.json provides it


def test_add_cmake_offline_patches(make_document):
    """Test that add_cmake_offline_patches does nothing (handled by flatpak-flutter)."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    result = flutter_patches.add_cmake_offline_patches(document)

    # SQLite patches are handled by flatpak-flutter generated patches
    # This function now returns unchanged
    assert not result.changed
    assert result.messages == []


def test_add_cargokit_offline_patches(make_document):
    """Test that add_cargokit_offline_patches adds cargokit patches."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    result = flutter_patches.add_cargokit_offline_patches(document)

    assert result.changed
    assert "cargokit patch" in str(result.messages).lower()

    sources = lotti.get("sources", [])

    # Note: We don't add cargo config anymore - cargo-sources.json provides the
    # correct vendor configuration with source replacements

    # Check cargokit patches were added for detected packages
    cargokit_patches = [
        s
        for s in sources
        if isinstance(s, dict)
        and s.get("type") == "patch"
        and "cargokit" in s.get("dest", "")
    ]
    # Should have patches for the fallback packages at minimum
    assert (
        len(cargokit_patches) >= 3
    )  # super_native_extensions, flutter_vodozemac, irondash_engine_context


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

    # Check cargokit patches were added
    cargokit_patches = [
        s
        for s in sources
        if isinstance(s, dict)
        and s.get("type") == "patch"
        and "cargokit" in s.get("dest", "")
    ]
    assert len(cargokit_patches) >= 3  # fallback packages

    # Note: We don't add cargo config anymore - cargo-sources.json provides it
