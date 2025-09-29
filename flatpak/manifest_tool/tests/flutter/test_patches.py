"""Tests for offline build patch operations."""

from __future__ import annotations

import pytest

from manifest_tool.flutter import patches as flutter_patches


def test_add_offline_build_patches_adds_all_commands(make_document):
    """Test that add_offline_build_patches adds all required commands."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # Start with basic build commands
    lotti["build-commands"] = ["echo 'Starting build'", "flutter build linux --release"]

    result = flutter_patches.add_offline_build_patches(document)

    assert result.changed
    assert "offline build patches" in str(result.messages).lower()

    commands = lotti["build-commands"]

    # Check that all patch commands were added
    assert any(
        "sqlite3_flutter_libs" in cmd for cmd in commands if isinstance(cmd, str)
    )
    assert any("cargokit" in cmd for cmd in commands if isinstance(cmd, str))
    assert any(".cargo/config.toml" in cmd for cmd in commands if isinstance(cmd, str))


def test_add_offline_build_patches_inserts_before_flutter_build(make_document):
    """Test that patches are inserted before the flutter build command."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    lotti["build-commands"] = [
        "echo 'Pre-build step'",
        "flutter build linux --release --verbose",
        "echo 'Post-build step'",
    ]

    result = flutter_patches.add_offline_build_patches(document)

    assert result.changed

    commands = lotti["build-commands"]

    # Find the index of flutter build
    flutter_build_idx = next(
        idx
        for idx, cmd in enumerate(commands)
        if isinstance(cmd, str) and "flutter build linux" in cmd
    )

    # Find patch command indices
    patch_indices = [
        idx
        for idx, cmd in enumerate(commands)
        if isinstance(cmd, str)
        and any(
            pattern in cmd
            for pattern in ["sqlite3_flutter_libs", "cargokit", ".cargo/config.toml"]
        )
    ]

    # All patches should be before flutter build
    assert all(idx < flutter_build_idx for idx in patch_indices)

    # Pre-build step should still be first
    assert commands[0] == "echo 'Pre-build step'"
    # Post-build step should still be after flutter build
    assert commands[-1] == "echo 'Post-build step'"


def test_add_offline_build_patches_idempotent(make_document):
    """Test that add_offline_build_patches is idempotent."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    lotti["build-commands"] = ["flutter build linux --release"]

    # First call
    result1 = flutter_patches.add_offline_build_patches(document)
    assert result1.changed

    commands_after_first = lotti["build-commands"].copy()

    # Second call
    result2 = flutter_patches.add_offline_build_patches(document)
    assert not result2.changed

    commands_after_second = lotti["build-commands"]

    # Commands should not have duplicates
    assert commands_after_first == commands_after_second


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


def test_add_offline_build_patches_no_build_commands(make_document):
    """Test when lotti module has no build-commands."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # Remove build-commands
    if "build-commands" in lotti:
        del lotti["build-commands"]

    result = flutter_patches.add_offline_build_patches(document)

    assert result.changed

    # build-commands should be created
    assert "build-commands" in lotti
    commands = lotti["build-commands"]

    # All patches should be present
    assert any(
        "sqlite3_flutter_libs" in cmd for cmd in commands if isinstance(cmd, str)
    )
    assert any("cargokit" in cmd for cmd in commands if isinstance(cmd, str))
    assert any(".cargo/config.toml" in cmd for cmd in commands if isinstance(cmd, str))


def test_add_offline_build_patches_preserves_command_order(make_document):
    """Test that non-patch commands maintain their relative order."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    lotti["build-commands"] = [
        "echo 'Step 1'",
        "echo 'Step 2'",
        "flutter build linux --release",
        "echo 'Step 3'",
        "echo 'Step 4'",
    ]

    result = flutter_patches.add_offline_build_patches(document)

    assert result.changed

    commands = lotti["build-commands"]

    # Find indices of original commands
    step1_idx = commands.index("echo 'Step 1'")
    step2_idx = commands.index("echo 'Step 2'")
    flutter_idx = next(
        idx for idx, cmd in enumerate(commands) if "flutter build linux" in cmd
    )
    step3_idx = commands.index("echo 'Step 3'")
    step4_idx = commands.index("echo 'Step 4'")

    # Original commands should maintain relative order
    assert step1_idx < step2_idx < flutter_idx < step3_idx < step4_idx
