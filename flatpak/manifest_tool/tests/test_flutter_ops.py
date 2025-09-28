from __future__ import annotations

from pathlib import Path

import pytest

from flatpak.manifest_tool import flutter_ops
from flatpak.manifest_tool.manifest import ManifestDocument, OperationResult


def test_ensure_nested_sdk(make_document, tmp_path: Path):
    document = make_document()
    out_dir = tmp_path / "out"
    out_dir.mkdir()
    (out_dir / "flutter-sdk-offline.json").write_text("{}", encoding="utf-8")

    result = flutter_ops.ensure_nested_sdk(document, output_dir=out_dir)

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

    flutter_ops.ensure_nested_sdk(document, output_dir=out_dir)
    assert flutter_ops.should_remove_flutter_sdk(document, output_dir=out_dir)


def test_normalize_flutter_sdk_module(make_document):
    document = make_document()
    result = flutter_ops.normalize_flutter_sdk_module(document)

    assert result.changed
    commands = next(
        module for module in document.data["modules"] if module["name"] == "flutter-sdk"
    )["build-commands"]
    assert commands == ["mv flutter /app/flutter", "export PATH=/app/flutter/bin:$PATH"]


def test_normalize_lotti_env_top_layout(make_document):
    document = make_document()
    result = flutter_ops.normalize_lotti_env(
        document, flutter_bin="/app/flutter/bin", ensure_append_path=True
    )

    assert result.changed
    lotti = next(
        module for module in document.data["modules"] if module["name"] == "lotti"
    )
    env_path = lotti["build-options"]["env"]["PATH"]
    append_path = lotti["build-options"]["append-path"]
    assert env_path.startswith("/app/flutter/bin")
    assert append_path.endswith("/app/flutter/bin")


# test_ensure_lotti_network_share removed
# --share=network in build-args is NOT allowed on Flathub infrastructure


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
    result = flutter_ops.remove_network_from_build_args(document)

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
    result2 = flutter_ops.remove_network_from_build_args(document)
    assert not result2.changed


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

    result = flutter_ops.ensure_flutter_pub_get_offline(document)

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
    result2 = flutter_ops.ensure_flutter_pub_get_offline(document)
    assert not result2.changed


def test_ensure_setup_helper_source_and_command(make_document):
    document = make_document()
    source_result = flutter_ops.ensure_setup_helper_source(
        document, helper_name="setup-flutter.sh"
    )
    command_result = flutter_ops.ensure_setup_helper_command(
        document,
        helper_name="setup-flutter.sh",
        working_dir="/app",
    )

    assert source_result.changed
    assert command_result.changed

    lotti = next(
        module for module in document.data["modules"] if module["name"] == "lotti"
    )
    sources = lotti["sources"]
    assert any(
        isinstance(src, dict) and src.get("path") == "setup-flutter.sh"
        for src in sources
    )

    commands = lotti["build-commands"]
    # The helper command resolves the helper and invokes it; assert the command contains -C /app
    assert any("setup-flutter.sh" in cmd and "-C /app" in cmd for cmd in commands)


def test_ensure_rust_sdk_env(make_document):
    document = make_document()
    result = flutter_ops.ensure_rust_sdk_env(document)
    assert result.changed
    lotti = next(
        module for module in document.data["modules"] if module["name"] == "lotti"
    )
    build_opts = lotti["build-options"]
    assert "/usr/lib/sdk/rust-stable/bin" in build_opts["append-path"]
    assert "/var/lib/rustup/bin" in build_opts["append-path"]
    env_path = build_opts["env"]["PATH"]
    assert env_path.startswith("/var/lib/rustup/bin")
    assert "/usr/lib/sdk/rust-stable/bin" in env_path
    assert build_opts["env"].get("RUSTUP_HOME") == "/var/lib/rustup"


def test_normalize_sdk_copy_replaces_command(make_document):
    document = make_document()
    result = flutter_ops.normalize_sdk_copy(document)

    assert result.changed
    commands = next(
        module for module in document.data["modules"] if module["name"] == "lotti"
    )["build-commands"]
    assert commands[0].startswith("if [ -d /var/lib/flutter ]")


def test_convert_flutter_git_to_archive(make_document):
    document = make_document()
    result = flutter_ops.convert_flutter_git_to_archive(
        document,
        archive_name="flutter.tar.xz",
        sha256="deadbeef",
    )

    assert result.changed
    flutter_module = next(
        module for module in document.data["modules"] if module["name"] == "flutter-sdk"
    )
    assert flutter_module["sources"][0]["type"] == "archive"
    assert flutter_module["sources"][0]["path"] == "flutter.tar.xz"
    assert flutter_module["sources"][0]["sha256"] == "deadbeef"

    lotti = next(
        module for module in document.data["modules"] if module["name"] == "lotti"
    )
    assert not any(
        source.get("dest") == "flutter"
        for source in lotti["sources"]
        if isinstance(source, dict)
    )


def test_rewrite_flutter_git_url(make_document):
    document = make_document()
    lotti = next(
        module for module in document.data["modules"] if module["name"] == "lotti"
    )
    for source in lotti["sources"]:
        if isinstance(source, dict) and source.get("dest") == "flutter":
            source["url"] = "https://example.com/custom.git"

    result = flutter_ops.rewrite_flutter_git_url(document)
    assert result.changed
    assert all(
        source.get("url") == "https://github.com/flutter/flutter.git"
        for source in lotti["sources"]
        if isinstance(source, dict) and source.get("dest") == "flutter"
    )


def test_bundle_app_archive_updates_sources(make_document, tmp_path: Path):
    document = make_document()
    out_dir = tmp_path / "out"
    out_dir.mkdir()
    (out_dir / "flutter-sdk-offline.json").write_text("{}", encoding="utf-8")
    (out_dir / "pubspec-sources.json").write_text("{}", encoding="utf-8")
    (out_dir / "cargo-sources.json").write_text("{}", encoding="utf-8")
    (out_dir / "rustup-offline.json").write_text("{}", encoding="utf-8")
    (out_dir / "setup-flutter.sh").write_text("#!/bin/bash", encoding="utf-8")

    result = flutter_ops.bundle_app_archive(
        document,
        archive_name="lotti.tar.xz",
        sha256="cafebabe",
        output_dir=out_dir,
    )

    assert result.changed
    module_names = [module["name"] for module in document.data["modules"]]
    assert "flutter-sdk" not in module_names

    lotti = next(
        module for module in document.data["modules"] if module["name"] == "lotti"
    )
    first_source = lotti["sources"][0]
    assert first_source["path"] == "lotti.tar.xz"
    assert first_source["sha256"] == "cafebabe"
    assert "flutter-sdk-offline.json" in lotti.get("modules", [])


@pytest.mark.parametrize(
    "layout,expected_dir", [("top", "/app"), ("nested", "/var/lib")]
)
def test_ensure_setup_helper_command_layout(
    make_document, layout: str, expected_dir: str
):
    document = make_document()
    result = flutter_ops.ensure_setup_helper_command(
        document,
        helper_name="setup-flutter.sh",
        working_dir="/app" if layout == "top" else "/var/lib",
    )

    assert result.changed
    lotti = next(
        module for module in document.data["modules"] if module["name"] == "lotti"
    )
    commands = lotti["build-commands"]
    assert any(expected_dir in command for command in commands)


def test_ensure_setup_helper_command_debug_disabled_by_default(make_document):
    """Test that debug output is disabled by default."""
    document = make_document()
    result = flutter_ops.ensure_setup_helper_command(
        document,
        helper_name="setup-flutter.sh",
        working_dir="/app",
    )

    assert result.changed
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")
    commands = lotti.get("build-commands", [])
    # Debug output should NOT be included by default
    helper_cmd = next((cmd for cmd in commands if "setup-flutter.sh" in cmd), None)
    assert helper_cmd is not None
    assert "DEBUG: missing" not in helper_cmd


def test_ensure_setup_helper_command_debug_enabled_explicitly(make_document):
    """Test that debug output can be enabled explicitly."""
    document = make_document()
    result = flutter_ops.ensure_setup_helper_command(
        document,
        helper_name="setup-flutter.sh",
        working_dir="/app",
        enable_debug=True,
    )

    assert result.changed
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")
    commands = lotti.get("build-commands", [])
    # Debug output should be included when explicitly enabled
    helper_cmd = next((cmd for cmd in commands if "setup-flutter.sh" in cmd), None)
    assert helper_cmd is not None
    assert "DEBUG: missing" in helper_cmd


def test_ensure_setup_helper_command_debug_enabled_via_env(make_document, monkeypatch):
    """Test that debug output can be enabled via environment variable."""
    monkeypatch.setenv("FLATPAK_HELPER_DEBUG", "true")

    document = make_document()
    result = flutter_ops.ensure_setup_helper_command(
        document,
        helper_name="setup-flutter.sh",
        working_dir="/app",
        enable_debug=False,  # Explicitly False, but env var should override
    )

    assert result.changed
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")
    commands = lotti.get("build-commands", [])
    # Debug output should be included when env var is set
    helper_cmd = next((cmd for cmd in commands if "setup-flutter.sh" in cmd), None)
    assert helper_cmd is not None
    assert "DEBUG: missing" in helper_cmd


def test_ensure_setup_helper_command_resolver_paths(make_document):
    """Test that the resolver checks all expected paths."""
    document = make_document()
    result = flutter_ops.ensure_setup_helper_command(
        document,
        helper_name="my-helper.sh",
        working_dir="/custom",
    )

    assert result.changed
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")
    commands = lotti.get("build-commands", [])
    helper_cmd = next((cmd for cmd in commands if "my-helper.sh" in cmd), None)
    assert helper_cmd is not None

    # Should check local file first
    assert "[ -f ./my-helper.sh ]" in helper_cmd
    # Should check /var/lib/flutter/bin
    assert "/var/lib/flutter/bin/my-helper.sh" in helper_cmd
    # Should check /app/flutter/bin
    assert "/app/flutter/bin/my-helper.sh" in helper_cmd
    # Should use the resolved helper variable
    assert 'bash "$H"' in helper_cmd


def test_ensure_setup_helper_command_custom_working_dir(make_document):
    """Test with a custom working directory."""
    document = make_document()
    result = flutter_ops.ensure_setup_helper_command(
        document,
        helper_name="setup.sh",
        working_dir="/opt/custom",
    )

    assert result.changed
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")
    commands = lotti.get("build-commands", [])
    helper_cmd = next((cmd for cmd in commands if "setup.sh" in cmd), None)
    assert helper_cmd is not None

    # Should pass custom working dir
    assert "-C /opt/custom" in helper_cmd
    # Should not have the conditional logic for standard dirs
    assert "if [ -d /app/flutter ]" not in helper_cmd
    assert "if [ -d /var/lib/flutter ]" not in helper_cmd


def test_ensure_setup_helper_command_app_working_dir_fallback(make_document):
    """Test /app working directory with fallback logic."""
    document = make_document()
    result = flutter_ops.ensure_setup_helper_command(
        document,
        helper_name="setup.sh",
        working_dir="/app",
    )

    assert result.changed
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")
    commands = lotti.get("build-commands", [])
    helper_cmd = next((cmd for cmd in commands if "setup.sh" in cmd), None)
    assert helper_cmd is not None

    # Should try /app first, then /var/lib as fallback
    assert "if [ -d /app/flutter ]" in helper_cmd
    assert "-C /app" in helper_cmd
    assert "elif [ -d /var/lib/flutter ]" in helper_cmd
    assert "-C /var/lib" in helper_cmd


def test_ensure_setup_helper_command_varlib_working_dir_fallback(make_document):
    """Test /var/lib working directory with fallback logic."""
    document = make_document()
    result = flutter_ops.ensure_setup_helper_command(
        document,
        helper_name="setup.sh",
        working_dir="/var/lib",
    )

    assert result.changed
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")
    commands = lotti.get("build-commands", [])
    helper_cmd = next((cmd for cmd in commands if "setup.sh" in cmd), None)
    assert helper_cmd is not None

    # Should try /var/lib first, then /app as fallback
    assert "if [ -d /var/lib/flutter ]" in helper_cmd
    assert "-C /var/lib" in helper_cmd
    assert "elif [ -d /app/flutter ]" in helper_cmd
    assert "-C /app" in helper_cmd


def test_ensure_setup_helper_command_idempotent(make_document):
    """Test that the command is idempotent."""
    document = make_document()

    # First call
    result1 = flutter_ops.ensure_setup_helper_command(
        document,
        helper_name="setup.sh",
        working_dir="/app",
    )
    assert result1.changed

    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")
    commands_before = lotti.get("build-commands", []).copy()

    # Second call with same parameters
    result2 = flutter_ops.ensure_setup_helper_command(
        document,
        helper_name="setup.sh",
        working_dir="/app",
    )

    # Should recognize it's already there (no change)
    assert not result2.changed
    commands_after = lotti.get("build-commands", [])

    # Commands should not have duplicates
    assert len(commands_after) == len(commands_before)
    assert commands_after == commands_before


def test_bundle_app_archive_replaces_all_sources(make_document, tmp_path):
    """Test that bundle_app_archive replaces ALL sources to avoid version mismatches."""
    document = make_document()

    # Add initial sources with a git source, file source, and patch
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")
    lotti["sources"] = [
        {"type": "file", "path": "existing-file.txt"},
        {"type": "git", "url": "https://github.com/test/test.git"},
        {"type": "patch", "path": "fix.patch"},  # This should be removed
    ]

    out_dir = tmp_path / "output"
    out_dir.mkdir()
    # Create required files
    (out_dir / "pubspec-sources.json").write_text("[]", encoding="utf-8")
    (out_dir / "setup-flutter.sh").write_text("#!/bin/bash", encoding="utf-8")

    result = flutter_ops.bundle_app_archive(
        document,
        archive_name="lotti.tar.xz",
        sha256="cafebabe",
        output_dir=out_dir,
    )

    assert result.changed
    updated_sources = lotti["sources"]
    assert isinstance(updated_sources, list)

    # First source should be the archive
    assert updated_sources[0]["type"] == "archive"
    assert updated_sources[0]["path"] == "lotti.tar.xz"
    assert updated_sources[0]["sha256"] == "cafebabe"

    # Patch should NOT be preserved (to avoid version mismatches)
    assert {"type": "patch", "path": "fix.patch"} not in updated_sources
    # Old file source should NOT be preserved
    assert {"type": "file", "path": "existing-file.txt"} not in updated_sources

    # New sources should be added
    assert "pubspec-sources.json" in updated_sources
    assert {"type": "file", "path": "setup-flutter.sh"} in updated_sources


def test_bundle_app_archive_includes_all_required_sources(make_document, tmp_path):
    """Test that bundle_app_archive includes all required sources in fresh list."""
    document = make_document()

    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")
    # Start with some existing sources that should be replaced
    lotti["sources"] = [
        {"type": "git", "url": "https://github.com/test/test.git"},
        {"type": "patch", "path": "old.patch"},  # Should be removed
    ]

    out_dir = tmp_path / "output"
    out_dir.mkdir()
    # Create all required files
    (out_dir / "pubspec-sources.json").write_text("[]", encoding="utf-8")
    (out_dir / "setup-flutter.sh").write_text("#!/bin/bash", encoding="utf-8")
    (out_dir / "cargo-sources.json").write_text("[]", encoding="utf-8")
    (out_dir / "package_config.json").write_text("{}", encoding="utf-8")

    result = flutter_ops.bundle_app_archive(
        document,
        archive_name="lotti.tar.xz",
        sha256="cafebabe",
        output_dir=out_dir,
    )

    assert result.changed
    updated_sources = lotti["sources"]

    # Should have exactly the expected sources, no more, no less
    assert len(updated_sources) == 5  # archive + 4 extra sources

    # First is always the archive
    assert updated_sources[0]["type"] == "archive"
    assert updated_sources[0]["path"] == "lotti.tar.xz"

    # All required sources should be present
    assert "pubspec-sources.json" in updated_sources
    assert "cargo-sources.json" in updated_sources
    assert {"type": "file", "path": "package_config.json"} in updated_sources
    assert {"type": "file", "path": "setup-flutter.sh"} in updated_sources

    # Old patch should NOT be present
    assert {"type": "patch", "path": "old.patch"} not in updated_sources

    # cargo-sources.json should be added since it wasn't there before
    assert "cargo-sources.json" in updated_sources


def test_bundle_app_archive_with_non_list_sources(make_document, tmp_path):
    """Test bundle_app_archive when sources is not a list initially."""
    document = make_document()

    # Set sources to a non-list value (edge case)
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")
    lotti["sources"] = "invalid"  # Not a list

    out_dir = tmp_path / "output"
    out_dir.mkdir()

    result = flutter_ops.bundle_app_archive(
        document,
        archive_name="lotti.tar.xz",
        sha256="cafebabe",
        output_dir=out_dir,
    )

    assert result.changed
    # Sources should be replaced with a proper list
    updated_sources = lotti["sources"]
    assert isinstance(updated_sources, list)
    assert len(updated_sources) >= 1
    assert updated_sources[0]["type"] == "archive"


def test_bundle_app_archive_no_lotti_module(make_document, tmp_path):
    """Test bundle_app_archive when lotti module doesn't exist."""
    document = make_document()

    # Remove lotti module
    document.data["modules"] = [
        m
        for m in document.data["modules"]
        if not (isinstance(m, dict) and m.get("name") == "lotti")
    ]

    out_dir = tmp_path / "output"
    out_dir.mkdir()

    result = flutter_ops.bundle_app_archive(
        document,
        archive_name="lotti.tar.xz",
        sha256="cafebabe",
        output_dir=out_dir,
    )

    # Should not change anything
    assert not result.changed


# Tests for newly added functions


def test_ensure_flutter_pub_get_offline(make_document):
    """Test adding --offline flag to flutter pub get commands."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # Add flutter pub get commands without --offline
    lotti["build-commands"] = [
        "echo 'Starting build'",
        "/run/build/lotti/flutter_sdk/bin/flutter pub get",
        "flutter pub get",
        "some other command",
    ]

    result = flutter_ops.ensure_flutter_pub_get_offline(document)

    assert result.changed
    assert "--offline flag to flutter pub get" in str(result.messages)

    # Check that --offline was added
    commands = lotti["build-commands"]
    assert "/run/build/lotti/flutter_sdk/bin/flutter pub get --offline" in commands
    assert "flutter pub get --offline" in commands
    assert commands[0] == "echo 'Starting build'"  # Unchanged
    assert commands[3] == "some other command"  # Unchanged

    # Run again - should not change
    result2 = flutter_ops.ensure_flutter_pub_get_offline(document)
    assert not result2.changed


def test_ensure_flutter_pub_get_offline_no_changes_needed(make_document):
    """Test when flutter pub get already has --offline."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # Commands already have --offline
    lotti["build-commands"] = [
        "flutter pub get --offline",
    ]

    result = flutter_ops.ensure_flutter_pub_get_offline(document)
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

    result = flutter_ops.ensure_dart_pub_offline_in_build(document)

    assert result.changed
    assert "Added --no-pub flag" in str(result.messages)

    # Check that --no-pub was added to all flutter build linux commands
    commands = lotti["build-commands"]
    assert "flutter build linux --no-pub --release --verbose" in commands
    assert "/run/build/lotti/flutter_sdk/bin/flutter build linux --no-pub" in commands
    assert "flutter build linux --no-pub --debug" in commands
    assert commands[0] == "echo 'Preparing'"  # Unchanged

    # Run again - should not change
    result2 = flutter_ops.ensure_dart_pub_offline_in_build(document)
    assert not result2.changed


def test_ensure_dart_pub_offline_in_build_already_has_flag(make_document):
    """Test when flutter build already has --no-pub."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    lotti["build-commands"] = [
        "flutter build linux --no-pub --release",
    ]

    result = flutter_ops.ensure_dart_pub_offline_in_build(document)
    assert not result.changed


def test_disable_media_kit_mimalloc(make_document):
    """Test disabling mimalloc in media_kit plugin."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # Start with build commands
    lotti["build-commands"] = ["echo 'Starting build'", "flutter build linux --release"]

    result = flutter_ops.disable_media_kit_mimalloc(document)

    assert result.changed
    assert "mimalloc" in str(result.messages).lower()

    # Check that build-options were added with the environment variable
    assert "build-options" in lotti
    build_options = lotti["build-options"]
    assert "env" in build_options
    env = build_options["env"]
    assert "MEDIA_KIT_LIBS_LINUX_USE_MIMALLOC" in env
    assert env["MEDIA_KIT_LIBS_LINUX_USE_MIMALLOC"] == "0"

    # Run again - should not change
    result2 = flutter_ops.disable_media_kit_mimalloc(document)
    assert not result2.changed


def test_disable_media_kit_mimalloc_preserves_existing_env(make_document):
    """Test that disabling mimalloc preserves existing environment variables."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # Start with existing build-options and environment
    lotti["build-options"] = {
        "env": {"EXISTING_VAR": "value1", "ANOTHER_VAR": "value2"}
    }
    lotti["build-commands"] = ["flutter build linux --release"]

    result = flutter_ops.disable_media_kit_mimalloc(document)

    assert result.changed
    env = lotti["build-options"]["env"]
    assert len(env) == 3  # Original 2 + new one

    # Original environment variables still there
    assert env["EXISTING_VAR"] == "value1"
    assert env["ANOTHER_VAR"] == "value2"
    # New mimalloc disable variable
    assert env["MEDIA_KIT_LIBS_LINUX_USE_MIMALLOC"] == "0"


def test_remove_network_from_build_args(make_document):
    """Test removing --share=network from build-args."""
    document = make_document()

    # Add --share=network to multiple modules
    for module in document.data["modules"]:
        if isinstance(module, dict):
            module["build-options"] = {
                "build-args": ["--share=network", "--something-else"]
            }

    result = flutter_ops.remove_network_from_build_args(document)

    assert result.changed
    assert "Removed --share=network" in str(result.messages)

    # Check that --share=network was removed but other args remain
    for module in document.data["modules"]:
        if isinstance(module, dict) and "build-options" in module:
            build_args = module["build-options"].get("build-args", [])
            assert "--share=network" not in build_args
            if build_args:  # Some modules might have had only --share=network
                assert "--something-else" in build_args

    # Run again - should not change
    result2 = flutter_ops.remove_network_from_build_args(document)
    assert not result2.changed


def test_remove_network_from_build_args_cleans_empty(make_document):
    """Test that empty build-args and build-options are removed."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # Only --share=network in build-args
    lotti["build-options"] = {"build-args": ["--share=network"]}

    result = flutter_ops.remove_network_from_build_args(document)

    assert result.changed
    # build-options should be completely removed when empty
    assert "build-options" not in lotti or "build-args" not in lotti.get(
        "build-options", {}
    )


def test_ensure_rust_sdk_env(make_document):
    """Test ensuring Rust SDK environment configuration."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # Clear any existing Rust SDK configuration to test from clean state
    if "build-options" in lotti and "env" in lotti["build-options"]:
        env = lotti["build-options"]["env"]
        # Remove any existing Rust paths
        if "PATH" in env:
            env["PATH"] = env["PATH"].replace("/usr/lib/sdk/rust-stable/bin:", "")
            env["PATH"] = env["PATH"].replace(":/usr/lib/sdk/rust-stable/bin", "")
        env.pop("RUSTUP_HOME", None)

    result = flutter_ops.ensure_rust_sdk_env(document)

    assert result.changed
    assert "Rust SDK" in str(result.messages)

    # Check the environment was configured
    env = lotti["build-options"]["env"]
    assert "/usr/lib/sdk/rust-stable/bin" in env["PATH"]
    assert env["RUSTUP_HOME"] == "/var/lib/rustup"

    # Check append-path was updated
    append_path = lotti["build-options"].get("append-path", "")
    assert "/usr/lib/sdk/rust-stable/bin" in append_path

    # Run again - should not change
    result2 = flutter_ops.ensure_rust_sdk_env(document)
    assert not result2.changed
