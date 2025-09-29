"""Tests for Flutter SDK management operations."""

from __future__ import annotations

from pathlib import Path
import pytest

from manifest_tool.flutter import sdk as flutter_sdk
from manifest_tool.core.manifest import ManifestDocument


def test_ensure_nested_sdk(make_document, tmp_path: Path):
    document = make_document()
    out_dir = tmp_path / "out"
    out_dir.mkdir()
    (out_dir / "flutter-sdk-offline.json").write_text("{}", encoding="utf-8")

    result = flutter_sdk.ensure_nested_sdk(document, output_dir=out_dir)

    assert result.changed
    lotti = next(
        module for module in document.data["modules"] if module["name"] == "lotti"
    )
    assert "flutter-sdk-offline.json" in lotti["modules"]


def test_should_remove_flutter_sdk_when_referenced(make_document, tmp_path: Path):
    document = make_document()
    out_dir = tmp_path / "out"
    out_dir.mkdir()
    nested = out_dir / "flutter-sdk-offline.json"
    nested.write_text("{}", encoding="utf-8")

    flutter_sdk.ensure_nested_sdk(document, output_dir=out_dir)
    assert flutter_sdk.should_remove_flutter_sdk(document, output_dir=out_dir)


def test_normalize_flutter_sdk_module(make_document):
    document = make_document()
    result = flutter_sdk.normalize_flutter_sdk_module(document)

    assert result.changed
    commands = next(
        module for module in document.data["modules"] if module["name"] == "flutter-sdk"
    )["build-commands"]
    assert commands == ["mv flutter /app/flutter", "export PATH=/app/flutter/bin:$PATH"]


def test_normalize_sdk_copy_replaces_command(make_document):
    document = make_document()
    result = flutter_sdk.normalize_sdk_copy(document)

    assert result.changed
    commands = next(
        module for module in document.data["modules"] if module["name"] == "lotti"
    )["build-commands"]
    assert commands[0].startswith("if [ -d /var/lib/flutter ]")


def test_convert_flutter_git_to_archive(make_document):
    document = make_document()
    result = flutter_sdk.convert_flutter_git_to_archive(
        document,
        archive_name="flutter.tar.xz",
        sha256="deadbeef",
    )

    assert result.changed
    flutter_module = next(
        module for module in document.data["modules"] if module["name"] == "flutter-sdk"
    )
    assert flutter_module["sources"][0]["type"] == "archive"
    assert (
        flutter_module["sources"][0]["url"]
        == "https://github.com/flutter/flutter/archive/flutter.tar.xz"
    )
    assert flutter_module["sources"][0]["sha256"] == "deadbeef"


def test_rewrite_flutter_git_url(make_document):
    document = make_document()
    flutter_module = next(
        module for module in document.data["modules"] if module["name"] == "flutter-sdk"
    )
    # Modify the URL to test rewriting - must contain flutter/flutter to be rewritten
    for source in flutter_module["sources"]:
        if isinstance(source, dict) and source.get("type") == "git":
            source["url"] = "https://github.com/flutter/flutter"  # Missing .git

    result = flutter_sdk.rewrite_flutter_git_url(document)
    assert result.changed

    # Check that URL was rewritten to canonical form
    for source in flutter_module["sources"]:
        if isinstance(source, dict) and source.get("type") == "git":
            assert source["url"] == "https://github.com/flutter/flutter.git"


def test_flutter_sdk_removal_when_nested_exists(tmp_path: Path):
    """Test that flutter-sdk module is removed when nested SDKs are added."""
    # Create a manifest with both top-level flutter-sdk and lotti modules
    document = ManifestDocument(
        Path("test.yml"),
        {
            "modules": [
                {"name": "flutter-sdk", "sources": []},
                {"name": "lotti", "sources": []},
                {"name": "other-module", "sources": []},
            ]
        },
    )

    # Create flutter-sdk JSON files
    (tmp_path / "flutter-sdk-stable.json").write_text("{}")
    (tmp_path / "flutter-sdk-beta.json").write_text("{}")

    # Ensure nested Flutter SDK
    result = flutter_sdk.ensure_nested_sdk(document, output_dir=tmp_path)

    # Should have added nested SDKs
    assert result.changed

    # Check that flutter-sdk module was removed
    module_names = [m.get("name") for m in document.data["modules"]]
    assert "flutter-sdk" not in module_names
    assert "lotti" in module_names
    assert "other-module" in module_names

    # Check that nested modules were added to lotti
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")
    assert "flutter-sdk-stable.json" in lotti["modules"]
    assert "flutter-sdk-beta.json" in lotti["modules"]


def test_flutter_sdk_not_removed_without_nested(tmp_path: Path):
    """Test that flutter-sdk is NOT removed when no nested SDKs exist."""
    document = ManifestDocument(
        Path("test.yml"),
        {
            "modules": [
                {"name": "flutter-sdk", "sources": []},
                {"name": "lotti", "sources": []},
            ]
        },
    )

    # Empty directory - no flutter-sdk JSON files
    result = flutter_sdk.ensure_nested_sdk(document, output_dir=tmp_path)

    # Should not have changed anything
    assert not result.changed

    # flutter-sdk should still be there
    module_names = [m.get("name") for m in document.data["modules"]]
    assert "flutter-sdk" in module_names
