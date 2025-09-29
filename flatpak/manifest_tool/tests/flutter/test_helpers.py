"""Tests for Flutter helper operations."""

from __future__ import annotations

from pathlib import Path
import pytest

from manifest_tool.flutter import helpers as flutter_helpers


def test_ensure_setup_helper_source(make_document):
    """Test adding setup helper source to flutter-sdk module."""
    document = make_document()

    result = flutter_helpers.ensure_setup_helper_source(
        document, helper_name="setup-flutter.sh"
    )

    assert result.changed

    flutter_sdk = next(
        module for module in document.data["modules"] if module["name"] == "flutter-sdk"
    )
    sources = flutter_sdk["sources"]

    # Check that helper source was added
    assert any(
        isinstance(src, dict)
        and src.get("dest-filename") == "setup-flutter.sh"
        and src.get("path") == "setup-flutter.sh"
        for src in sources
    )

    # Should be idempotent
    result2 = flutter_helpers.ensure_setup_helper_source(
        document, helper_name="setup-flutter.sh"
    )
    assert not result2.changed


def test_ensure_setup_helper_command(make_document):
    """Test adding setup helper command to lotti module."""
    document = make_document()

    result = flutter_helpers.ensure_setup_helper_command(
        document,
        working_dir="/app",
    )

    assert result.changed

    lotti = next(
        module for module in document.data["modules"] if module["name"] == "lotti"
    )
    commands = lotti["build-commands"]

    # Check that helper command was added
    assert any("setup-flutter.sh" in cmd for cmd in commands)
    assert any("-C /app" in cmd for cmd in commands if "setup-flutter.sh" in cmd)

    # Should be idempotent
    result2 = flutter_helpers.ensure_setup_helper_command(
        document,
        working_dir="/app",
    )
    assert not result2.changed


def test_ensure_setup_helper_command_with_debug(make_document):
    """Test setup helper command with debug enabled."""
    document = make_document()

    result = flutter_helpers.ensure_setup_helper_command(
        document,
        working_dir="/app",
        enable_debug=True,
    )

    assert result.changed

    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")
    commands = lotti.get("build-commands", [])

    # Debug flag should be included
    helper_cmd = next((cmd for cmd in commands if "setup-flutter.sh" in cmd), None)
    assert helper_cmd is not None
    assert " -d" in helper_cmd


def test_ensure_setup_helper_command_with_resolver_paths(make_document):
    """Test setup helper command with custom resolver paths."""
    document = make_document()

    result = flutter_helpers.ensure_setup_helper_command(
        document,
        working_dir="/app",
        resolver_paths=["/custom/path1", "/custom/path2"],
    )

    assert result.changed

    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")
    commands = lotti.get("build-commands", [])

    helper_cmd = next((cmd for cmd in commands if "setup-flutter.sh" in cmd), None)
    assert helper_cmd is not None
    assert "-r /custom/path1" in helper_cmd
    assert "-r /custom/path2" in helper_cmd


def test_bundle_app_archive_updates_sources(make_document):
    """Test bundling app archive and updating sources."""
    document = make_document()

    result = flutter_helpers.bundle_app_archive(
        document,
        archive_path="lotti.tar.xz",
        sha256="cafebabe",
    )

    assert result.changed

    lotti = next(
        module for module in document.data["modules"] if module["name"] == "lotti"
    )
    first_source = lotti["sources"][0]

    assert first_source["type"] == "file"
    assert first_source["path"] == "lotti.tar.xz"
    assert first_source["sha256"] == "cafebabe"


def test_bundle_app_archive_no_lotti_module(make_document):
    """Test bundle_app_archive when lotti module doesn't exist."""
    document = make_document()

    # Remove lotti module
    document.data["modules"] = [
        m
        for m in document.data["modules"]
        if not (isinstance(m, dict) and m.get("name") == "lotti")
    ]

    result = flutter_helpers.bundle_app_archive(
        document,
        archive_path="lotti.tar.xz",
        sha256="cafebabe",
    )

    # Should not change anything
    assert not result.changed


def test_bundle_app_archive_removes_git_sources(make_document):
    """Test that bundle_app_archive removes git sources."""
    document = make_document()

    # Add git source to lotti
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")
    lotti["sources"] = [
        {"type": "git", "url": "https://github.com/test/test.git"},
        {"type": "file", "path": "keep-this.txt"},
    ]

    result = flutter_helpers.bundle_app_archive(
        document,
        archive_path="lotti.tar.xz",
        sha256="cafebabe",
    )

    assert result.changed
    updated_sources = lotti["sources"]

    # First source should be the archive
    assert updated_sources[0]["type"] == "file"
    assert updated_sources[0]["path"] == "lotti.tar.xz"

    # Only Flutter git sources are removed, not all git sources
    # Non-Flutter git source should still be there
    git_sources = [
        s for s in updated_sources if isinstance(s, dict) and s.get("type") == "git"
    ]
    assert len(git_sources) == 1  # The non-Flutter git source remains

    # File source should be preserved
    assert {"type": "file", "path": "keep-this.txt"} in updated_sources
