"""Tests for Rust SDK configuration operations."""

from __future__ import annotations

import pytest  # noqa: F401

from manifest_tool.flutter import rust as flutter_rust


def test_ensure_rust_sdk_env(make_document):
    document = make_document()
    result = flutter_rust.ensure_rust_sdk_env(document)

    assert result.changed
    lotti = next(
        module for module in document.data["modules"] if module["name"] == "lotti"
    )
    build_opts = lotti["build-options"]

    # Check append-path
    assert "/usr/lib/sdk/rust-stable/bin" in build_opts["append-path"]
    assert "/run/build/lotti/.cargo/bin" in build_opts["append-path"]

    # Check env PATH
    env_path = build_opts["env"]["PATH"]
    assert "/usr/lib/sdk/rust-stable/bin" in env_path
    assert "/run/build/lotti/.cargo/bin" in env_path

    # Check RUSTUP_HOME
    assert build_opts["env"].get("RUSTUP_HOME") == "/usr/lib/sdk/rust-stable"

    # Should be idempotent
    result2 = flutter_rust.ensure_rust_sdk_env(document)
    assert not result2.changed


def test_remove_rustup_install(make_document):
    document = make_document()
    lotti = next(
        module for module in document.data["modules"] if module["name"] == "lotti"
    )

    # Add rustup installation commands
    lotti["build-commands"] = [
        "echo 'Starting build'",
        "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y",
        "source $HOME/.cargo/env",
        "rustup default stable",
        "flutter build linux",
    ]

    result = flutter_rust.remove_rustup_install(document)

    assert result.changed
    commands = lotti["build-commands"]

    # Rustup installation command should be removed
    assert not any("rustup.rs" in cmd for cmd in commands)
    # But other rustup commands may remain (they'll fail without rustup installed)
    # The function only removes installation, not usage

    # Other commands should remain
    assert "echo 'Starting build'" in commands
    assert "flutter build linux" in commands

    # Should be idempotent
    result2 = flutter_rust.remove_rustup_install(document)
    assert not result2.changed


def test_rust_append_path_message_not_f_string(make_document):
    """Test that Rust path addition uses plain string message."""
    document = make_document()

    result = flutter_rust.ensure_rust_sdk_env(document)

    # The fix ensures that messages don't use unnecessary f-strings
    # This would be caught by linter (Ruff F541) if incorrect
    assert result.changed
    assert "Added Rust paths to append-path" in str(result.messages)
