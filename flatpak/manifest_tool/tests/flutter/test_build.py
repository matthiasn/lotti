"""Tests for Flutter build command operations."""

from __future__ import annotations

import pytest

from manifest_tool.flutter import build as flutter_build


def test_normalize_lotti_env_top_layout(make_document):
    document = make_document()
    result = flutter_build.normalize_lotti_env(
        document, flutter_bin="/app/flutter/bin", ensure_append_path=True
    )

    assert result.changed
    lotti = next(
        module for module in document.data["modules"] if module["name"] == "lotti"
    )
    # When ensure_append_path=True, only append-path is updated
    append_path = lotti["build-options"]["append-path"]
    assert "/app/flutter/bin" in append_path


def test_remove_network_from_build_args(make_document):
    # Create document with network access in build-args
    document = make_document()

    # Add --share=network to both flutter-sdk and lotti modules
    flutter_sdk = next(
        module for module in document.data["modules"] if module["name"] == "flutter-sdk"
    )
    flutter_sdk.setdefault("build-options", {})["build-args"] = [
        "--share=network",
        "--allow=devel",
    ]

    lotti = next(
        module for module in document.data["modules"] if module["name"] == "lotti"
    )
    lotti["build-options"]["build-args"] = ["--share=network"]

    # Remove network access
    result = flutter_build.remove_network_from_build_args(document)

    assert result.changed
    assert len(result.messages) == 2
    assert "Removed --share=network from flutter-sdk" in result.messages
    assert "Removed --share=network from lotti" in result.messages

    # Verify --share=network is removed but other args remain
    assert "--share=network" not in flutter_sdk["build-options"]["build-args"]
    assert "--allow=devel" in flutter_sdk["build-options"]["build-args"]

    # Verify empty build-args is removed
    assert "build-args" not in lotti["build-options"]

    # Should be idempotent
    result2 = flutter_build.remove_network_from_build_args(document)
    assert not result2.changed


def test_remove_network_from_build_args_cleans_empty(make_document):
    """Test that empty build-args and build-options are removed."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # Only --share=network in build-args
    lotti["build-options"] = {"build-args": ["--share=network"]}

    result = flutter_build.remove_network_from_build_args(document)

    assert result.changed
    # build-options should be completely removed when empty
    assert "build-options" not in lotti or "build-args" not in lotti.get(
        "build-options", {}
    )


def test_ensure_flutter_pub_get_offline(make_document):
    """Test that flutter pub get commands get --offline flag added."""
    document = make_document()

    # Add flutter pub get commands to lotti module
    lotti = next(
        module for module in document.data["modules"] if module["name"] == "lotti"
    )
    lotti["build-commands"] = [
        "echo Starting build",
        "/run/build/lotti/flutter_sdk/bin/flutter pub get",
        "flutter pub get --verbose",
        "/app/flutter/bin/flutter pub get --offline",  # Already has offline
        "flutter build linux",
    ]

    result = flutter_build.ensure_flutter_pub_get_offline(document)

    assert result.changed
    assert len(result.messages) == 2  # Two commands without --offline

    # Check commands were updated
    commands = lotti["build-commands"]
    assert commands[0] == "echo Starting build"  # Unchanged
    assert commands[1] == "/run/build/lotti/flutter_sdk/bin/flutter pub get --offline"
    assert commands[2] == "flutter pub get --offline --verbose"
    assert commands[3] == "/app/flutter/bin/flutter pub get --offline"  # Already had it
    assert commands[4] == "flutter build linux"  # Unchanged

    # Should be idempotent
    result2 = flutter_build.ensure_flutter_pub_get_offline(document)
    assert not result2.changed


def test_ensure_flutter_pub_get_offline_no_changes_needed(make_document):
    """Test when flutter pub get already has --offline."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # Commands already have --offline
    lotti["build-commands"] = [
        "flutter pub get --offline",
    ]

    result = flutter_build.ensure_flutter_pub_get_offline(document)
    assert not result.changed


def test_ensure_dart_pub_offline_in_build(make_document):
    """Test adding --no-pub flag to flutter build commands."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # Add flutter build commands without --no-pub
    lotti["build-commands"] = [
        "echo 'Preparing'",
        "flutter build linux --release --verbose",
        "/run/build/lotti/flutter_sdk/bin/flutter build linux",
        "flutter build linux --debug",
    ]

    result = flutter_build.ensure_dart_pub_offline_in_build(document)

    assert result.changed
    assert "Added --no-pub flag" in str(result.messages)

    # Check that --no-pub was added to all flutter build linux commands
    commands = lotti["build-commands"]
    assert "flutter build linux --no-pub --release --verbose" in commands
    assert "/run/build/lotti/flutter_sdk/bin/flutter build linux --no-pub" in commands
    assert "flutter build linux --no-pub --debug" in commands
    assert commands[0] == "echo 'Preparing'"  # Unchanged

    # Run again - should not change
    result2 = flutter_build.ensure_dart_pub_offline_in_build(document)
    assert not result2.changed


def test_ensure_dart_pub_offline_in_build_already_has_flag(make_document):
    """Test when flutter build already has --no-pub."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    lotti["build-commands"] = [
        "flutter build linux --no-pub --release",
    ]

    result = flutter_build.ensure_dart_pub_offline_in_build(document)
    assert not result.changed


def test_remove_flutter_config_command(make_document):
    """Test removing flutter config commands."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # Add some commands including flutter config
    lotti["build-commands"] = [
        "echo 'Starting'",
        "flutter config --no-analytics",
        "flutter pub get",
        "flutter config --enable-linux-desktop",
        "flutter build linux",
    ]

    result = flutter_build.remove_flutter_config_command(document)

    assert result.changed
    commands = lotti["build-commands"]

    # flutter config commands should be removed
    assert "flutter config --no-analytics" not in commands
    assert "flutter config --enable-linux-desktop" not in commands

    # Other commands should remain
    assert "echo 'Starting'" in commands
    assert "flutter pub get" in commands
    assert "flutter build linux" in commands

    # Should be idempotent
    result2 = flutter_build.remove_flutter_config_command(document)
    assert not result2.changed
