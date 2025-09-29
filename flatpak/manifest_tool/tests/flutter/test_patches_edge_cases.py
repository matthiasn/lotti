"""Edge case coverage for Flutter patch helpers."""

from __future__ import annotations

from pathlib import Path

import pytest

from manifest_tool.core.manifest import ManifestDocument
from manifest_tool.flutter import patches as flutter_patches


def test_cmake_patches_ignore_existing_custom_patch(make_document):
    """add_cmake_offline_patches leaves existing custom patches untouched."""
    document = make_document()
    lotti = next(
        module for module in document.data["modules"] if module["name"] == "lotti"
    )
    lotti["sources"] = [{"type": "patch", "path": "patches/custom-sqlite.patch"}]

    result = flutter_patches.add_cmake_offline_patches(document)

    assert not result.changed
    assert lotti["sources"] == [
        {"type": "patch", "path": "patches/custom-sqlite.patch"}
    ]


def test_cargokit_patches_preserve_existing_entries(make_document):
    """Existing cargokit patches remain while missing ones are appended."""
    document = make_document()
    lotti = next(
        module for module in document.data["modules"] if module["name"] == "lotti"
    )
    existing_dest = ".pub-cache/hosted/pub.dev/super_native_extensions-0.9.1/cargokit"
    lotti["sources"] = [
        {"type": "patch", "path": "custom.patch", "dest": existing_dest}
    ]

    result = flutter_patches.add_cargokit_offline_patches(document)

    assert result.changed
    dests = [src.get("dest") for src in lotti["sources"] if isinstance(src, dict)]
    assert dests.count(existing_dest) == 1
    assert any(
        dest for dest in dests if dest != existing_dest and dest.endswith("/cargokit")
    )


def test_cargokit_patches_handle_non_list_sources(make_document):
    """Non-list sources are normalised into a list before patches are appended."""
    document = make_document()
    lotti = next(
        module for module in document.data["modules"] if module["name"] == "lotti"
    )
    lotti["sources"] = "not-a-list"

    result = flutter_patches.add_cargokit_offline_patches(document)

    assert result.changed
    assert isinstance(lotti["sources"], list)
    assert any(
        "cargokit" in src.get("dest", "")
        for src in lotti["sources"]
        if isinstance(src, dict)
    )


def test_cargokit_patches_do_nothing_without_lotti():
    """Documents without a lotti module remain unchanged."""
    document = ManifestDocument(Path("test.yml"), {"modules": [{"name": "other"}]})

    result = flutter_patches.add_cargokit_offline_patches(document)

    assert not result.changed
    assert document.data["modules"] == [{"name": "other"}]
