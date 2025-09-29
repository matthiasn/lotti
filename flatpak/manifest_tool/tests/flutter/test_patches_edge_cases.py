"""Edge case tests for offline build patch operations."""

from __future__ import annotations

import pytest

from manifest_tool.flutter import patches as flutter_patches
from manifest_tool.core.manifest import ManifestDocument
from pathlib import Path


def test_add_cmake_patches_with_existing_conflicting_patch(make_document):
    """Test adding CMake patches when a conflicting patch already exists."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # Add a different SQLite patch first
    lotti["sources"] = [
        {
            "type": "patch",
            "path": "patches/sqlite3-offline.patch",
        }
    ]

    result = flutter_patches.add_cmake_offline_patches(document)

    # Should not add a duplicate
    assert not result.changed
    sources = lotti["sources"]
    sqlite_patches = [
        s
        for s in sources
        if isinstance(s, dict) and s.get("path") == "patches/sqlite3-offline.patch"
    ]
    assert len(sqlite_patches) == 1


def test_add_cargokit_patches_with_existing_different_cargo_config(make_document):
    """Test adding cargo config when a different config already exists."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # Add a different cargo config
    lotti["sources"] = [
        {
            "type": "inline",
            "dest": ".cargo",
            "dest-filename": "config.toml",
            "contents": "[net]\noffline = false\n",  # Different content
        }
    ]

    result = flutter_patches.add_cargokit_offline_patches(document)

    # Should not overwrite existing config
    assert result.changed  # Only the patch is added
    sources = lotti["sources"]
    cargo_configs = [
        s
        for s in sources
        if isinstance(s, dict)
        and s.get("dest") == ".cargo"
        and s.get("dest-filename") == "config.toml"
    ]
    assert len(cargo_configs) == 1
    # Original config should be preserved
    assert "offline = false" in cargo_configs[0]["contents"]


def test_patches_with_malformed_sources_list(make_document):
    """Test handling of malformed sources list."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # Set sources to a string instead of list
    lotti["sources"] = "not-a-list"

    result = flutter_patches.add_offline_build_patches(document)

    assert result.changed
    # Should replace the malformed sources with a proper list
    assert isinstance(lotti["sources"], list)
    assert len(lotti["sources"]) == 3  # SQLite patch, cargo config, cargokit patch


def test_patches_preserve_other_sources(make_document):
    """Test that patches preserve unrelated sources."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # Add various unrelated sources
    lotti["sources"] = [
        {"type": "git", "url": "https://github.com/test/test.git"},
        {"type": "file", "path": "some-file.txt"},
        {
            "type": "archive",
            "url": "https://example.com/archive.tar.gz",
            "sha256": "abc123",
        },
        {"type": "script", "dest-filename": "build.sh", "commands": ["echo hello"]},
    ]

    original_sources = lotti["sources"].copy()

    result = flutter_patches.add_offline_build_patches(document)

    assert result.changed
    sources = lotti["sources"]

    # All original sources should still be there
    for orig in original_sources:
        assert orig in sources

    # Plus the new patches
    assert len(sources) == len(original_sources) + 3


def test_patches_with_module_missing_dict_type(make_document):
    """Test when module is not a dict (edge case)."""
    document = make_document()

    # Replace lotti module with a string
    for i, module in enumerate(document.data["modules"]):
        if isinstance(module, dict) and module.get("name") == "lotti":
            document.data["modules"][i] = "lotti"  # String instead of dict
            break

    result = flutter_patches.add_offline_build_patches(document)

    # Should not crash, should not change anything
    assert not result.changed


def test_cargo_config_contents_format():
    """Test that cargo config has correct format."""
    document = ManifestDocument(
        Path("test.yml"), {"modules": [{"name": "lotti", "sources": []}]}
    )

    result = flutter_patches.add_cargokit_offline_patches(document)

    assert result.changed
    lotti = document.data["modules"][0]
    cargo_config = next(
        s
        for s in lotti["sources"]
        if isinstance(s, dict)
        and s.get("dest") == ".cargo"
        and s.get("dest-filename") == "config.toml"
    )

    # Verify the config has the right structure
    contents = cargo_config["contents"]
    assert "[net]" in contents
    assert "offline = true" in contents
    assert "[http]" in contents
    assert "max-retries = 0" in contents

    # Should be valid TOML
    lines = contents.strip().split("\n")
    assert lines[0] == "[net]"
    assert lines[1] == "offline = true"
    assert lines[2] == ""
    assert lines[3] == "[http]"
    assert lines[4] == "max-retries = 0"


def test_patch_sources_have_required_fields():
    """Test that patch sources have all required fields."""
    document = ManifestDocument(
        Path("test.yml"), {"modules": [{"name": "lotti", "sources": []}]}
    )

    result = flutter_patches.add_offline_build_patches(document)

    assert result.changed
    lotti = document.data["modules"][0]

    # Check SQLite patch
    sqlite_patch = next(
        s
        for s in lotti["sources"]
        if isinstance(s, dict) and s.get("path") == "patches/sqlite3-offline.patch"
    )
    assert sqlite_patch["type"] == "patch"
    assert len(sqlite_patch) == 2  # Only type, path

    # Check cargokit patch
    cargokit_patch = next(
        s
        for s in lotti["sources"]
        if isinstance(s, dict) and s.get("path") == "patches/cargokit-offline.patch"
    )
    assert cargokit_patch["type"] == "patch"
    assert len(cargokit_patch) == 2  # Only type, path

    # Check cargo config
    cargo_config = next(
        s
        for s in lotti["sources"]
        if isinstance(s, dict)
        and s.get("dest") == ".cargo"
        and s.get("dest-filename") == "config.toml"
    )
    assert cargo_config["type"] == "inline"
    assert "contents" in cargo_config
    assert "dest" in cargo_config
    assert "dest-filename" in cargo_config
    assert len(cargo_config) == 4  # type, dest, dest-filename, contents


def test_multiple_lotti_modules(make_document):
    """Test behavior when there are multiple modules named lotti (shouldn't happen but...)."""
    document = make_document()

    # Duplicate the lotti module
    lotti = next(m for m in document.data["modules"] if m.get("name") == "lotti")
    lotti2 = lotti.copy()
    lotti2["sources"] = []
    document.data["modules"].append(lotti2)

    result = flutter_patches.add_offline_build_patches(document)

    assert result.changed
    # Only the first lotti module should be modified
    lotti_modules = [
        m
        for m in document.data["modules"]
        if isinstance(m, dict) and m.get("name") == "lotti"
    ]
    assert len(lotti_modules) == 2

    # First should have patches
    assert len(lotti_modules[0].get("sources", [])) >= 3
    # Second should be unchanged
    assert len(lotti_modules[1].get("sources", [])) == 0


def test_patches_do_not_duplicate_on_repeated_calls(make_document):
    """Test that calling patch functions multiple times doesn't duplicate."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")
    lotti["sources"] = []

    # Call each function twice
    flutter_patches.add_cmake_offline_patches(document)
    flutter_patches.add_cmake_offline_patches(document)

    flutter_patches.add_cargokit_offline_patches(document)
    flutter_patches.add_cargokit_offline_patches(document)

    sources = lotti["sources"]

    # Should only have one of each
    sqlite_patches = [
        s
        for s in sources
        if isinstance(s, dict) and s.get("path") == "patches/sqlite3-offline.patch"
    ]
    assert len(sqlite_patches) == 1

    cargo_configs = [
        s
        for s in sources
        if isinstance(s, dict)
        and s.get("dest") == ".cargo"
        and s.get("dest-filename") == "config.toml"
    ]
    assert len(cargo_configs) == 1

    cargokit_patches = [
        s
        for s in sources
        if isinstance(s, dict) and s.get("path") == "patches/cargokit-offline.patch"
    ]
    assert len(cargokit_patches) == 1


def test_empty_modules_list():
    """Test with empty modules list."""
    document = ManifestDocument(Path("test.yml"), {"modules": []})

    result = flutter_patches.add_offline_build_patches(document)

    assert not result.changed
    assert document.data["modules"] == []


def test_sources_not_modified_if_no_lotti():
    """Test that other modules' sources are not touched."""
    document = ManifestDocument(
        Path("test.yml"),
        {
            "modules": [
                {"name": "other", "sources": [{"type": "git", "url": "test"}]},
                {"name": "another", "sources": []},
            ]
        },
    )

    original = document.data.copy()

    result = flutter_patches.add_offline_build_patches(document)

    assert not result.changed
    assert document.data == original
