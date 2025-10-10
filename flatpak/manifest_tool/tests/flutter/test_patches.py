"""Tests for Flutter patch helpers that remain in use."""

from __future__ import annotations

import pytest

from manifest_tool.flutter import patches as flutter_patches


def test_add_cmake_offline_patches_is_noop(make_document):
    """add_cmake_offline_patches currently delegates to flatpak-flutter output."""
    document = make_document()

    result = flutter_patches.add_cmake_offline_patches(document)

    assert not result.changed
    assert result.messages == []


def test_add_cargokit_offline_patches_inserts_patches(make_document):
    """add_cargokit_offline_patches injects cargokit patch entries for known packages."""
    document = make_document()
    lotti = next(module for module in document.data["modules"] if module["name"] == "lotti")

    result = flutter_patches.add_cargokit_offline_patches(document)

    assert result.changed
    assert any("cargokit patch" in message.lower() for message in result.messages)

    sources = lotti.get("sources", [])
    cargokit_patches = [
        source
        for source in sources
        if isinstance(source, dict) and source.get("type") == "patch" and "cargokit" in source.get("dest", "")
    ]
    # fallback list adds three packages by default
    assert len(cargokit_patches) >= 3


@pytest.mark.parametrize(
    "existing_dest",
    [
        ".pub-cache/hosted/pub.dev/super_native_extensions-0.9.1/cargokit",
        ".pub-cache/hosted/pub.dev/flutter_vodozemac-0.2.2/cargokit",
    ],
)
def test_add_cargokit_offline_patches_idempotent(make_document, existing_dest):
    """Existing cargokit patches are preserved without duplication."""
    document = make_document()
    lotti = next(module for module in document.data["modules"] if module["name"] == "lotti")
    lotti.setdefault("sources", []).append({"type": "patch", "dest": existing_dest, "path": "foo.patch"})

    result = flutter_patches.add_cargokit_offline_patches(document)

    assert result.changed  # other packages still added
    assert sum(1 for s in lotti["sources"] if isinstance(s, dict) and s.get("dest") == existing_dest) == 1


def test_add_cargokit_offline_patches_respects_pubspec_order(make_document):
    """Ensure cargokit patches run after pubspec staging so files exist."""
    document = make_document()
    lotti = next(module for module in document.data["modules"] if module["name"] == "lotti")
    lotti["sources"] = [
        {"type": "file", "path": "app.tar.xz"},
        "pubspec-sources.json",
        "cargo-sources.json",
    ]

    flutter_patches.add_cargokit_offline_patches(document)

    sources = lotti["sources"]
    pubspec_index = sources.index("pubspec-sources.json")
    cargo_index = sources.index("cargo-sources.json")
    patch_indices = [
        idx
        for idx, source in enumerate(sources)
        if isinstance(source, dict) and source.get("type") == "patch" and "cargokit" in source.get("dest", "")
    ]

    assert patch_indices
    assert all(pubspec_index < idx < cargo_index for idx in patch_indices)
