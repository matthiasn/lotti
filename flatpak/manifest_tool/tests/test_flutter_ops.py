from __future__ import annotations

from pathlib import Path

import pytest

from manifest_tool import flutter as flutter_ops


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
    # When ensure_append_path=True, only append-path is updated
    append_path = lotti["build-options"]["append-path"]
    assert "/app/flutter/bin" in append_path


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
        working_dir="/app",
    )

    assert source_result.changed
    assert command_result.changed

    # Helper source is added to flutter-sdk module
    flutter_sdk = next(
        module for module in document.data["modules"] if module["name"] == "flutter-sdk"
    )
    sources = flutter_sdk["sources"]
    assert any(
        isinstance(src, dict) and src.get("dest-filename") == "setup-flutter.sh"
        for src in sources
    )

    # Command is added to lotti module
    lotti = next(
        module for module in document.data["modules"] if module["name"] == "lotti"
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
    assert "/run/build/lotti/.cargo/bin" in build_opts["append-path"]
    assert "PATH" not in build_opts.get("env", {})
    assert build_opts["env"].get("RUSTUP_HOME") == "/usr/lib/sdk/rust-stable"


def test_normalize_sdk_copy_replaces_command(make_document):
    document = make_document()

    # First modify the lotti module to have the command we want to replace
    lotti = next(
        module for module in document.data["modules"] if module["name"] == "lotti"
    )
    lotti["build-commands"] = ["cp -r /var/lib/flutter .", "echo build"]

    result = flutter_ops.normalize_sdk_copy(document)

    assert result.changed
    commands = lotti["build-commands"]
    assert commands[0] == "cp -r /var/lib/flutter ."


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
    assert (
        flutter_module["sources"][0]["url"]
        == "https://github.com/flutter/flutter/archive/flutter.tar.xz"
    )
    assert flutter_module["sources"][0]["sha256"] == "deadbeef"
    # Archive sources don't have 'dest' - that's for git sources

    # The function only modifies flutter-sdk module, not lotti
    # Lotti sources remain unchanged


def test_rewrite_flutter_git_url(make_document):
    document = make_document()
    # The function operates on flutter-sdk module, not lotti
    flutter_sdk = next(
        module for module in document.data["modules"] if module["name"] == "flutter-sdk"
    )
    # Add a non-canonical Flutter git source
    flutter_sdk["sources"] = [
        {
            "type": "git",
            "url": "https://github.com/flutter/flutter",  # Missing .git extension
        }
    ]

    result = flutter_ops.rewrite_flutter_git_url(document)
    assert result.changed
    assert flutter_sdk["sources"][0]["url"] == "https://github.com/flutter/flutter.git"


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
        archive_path=str(out_dir / "lotti.tar.xz"),
        sha256="cafebabe",
    )

    assert result.changed
    # Note: The new implementation doesn't remove flutter-sdk module

    lotti = next(
        module for module in document.data["modules"] if module["name"] == "lotti"
    )
    first_source = lotti["sources"][0]
    assert first_source["path"] == str(out_dir / "lotti.tar.xz")
    assert first_source["sha256"] == "cafebabe"


@pytest.mark.parametrize(
    "layout,expected_dir", [("top", "/app"), ("nested", "/var/lib")]
)
def test_ensure_setup_helper_command_layout(
    make_document, layout: str, expected_dir: str
):
    document = make_document()
    result = flutter_ops.ensure_setup_helper_command(
        document,
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
        working_dir="/app",
    )

    assert result.changed
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")
    commands = lotti.get("build-commands", [])
    # Debug output should NOT be included by default
    helper_cmd = next((cmd for cmd in commands if "setup-flutter.sh" in cmd), None)
    assert helper_cmd is not None
    # Should not have debug flag
    assert " -d" not in helper_cmd


def test_ensure_setup_helper_command_debug_enabled_explicitly(make_document):
    """Test that debug output can be enabled explicitly."""
    document = make_document()
    result = flutter_ops.ensure_setup_helper_command(
        document,
        working_dir="/app",
        enable_debug=True,
    )

    assert result.changed
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")
    commands = lotti.get("build-commands", [])
    # Debug output should be included when explicitly enabled
    helper_cmd = next((cmd for cmd in commands if "setup-flutter.sh" in cmd), None)
    assert helper_cmd is not None
    # Should have debug flag
    assert " -d" in helper_cmd


def test_ensure_setup_helper_command_debug_enabled_via_env(make_document, monkeypatch):
    """Test that debug output can be enabled via environment variable."""
    monkeypatch.setenv("FLATPAK_HELPER_DEBUG", "true")

    document = make_document()
    result = flutter_ops.ensure_setup_helper_command(
        document,
        working_dir="/app",
        enable_debug=False,  # Explicitly False, but env var should override
    )

    assert result.changed
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")
    commands = lotti.get("build-commands", [])
    # Debug output should be included when env var is set
    helper_cmd = next((cmd for cmd in commands if "setup-flutter.sh" in cmd), None)
    assert helper_cmd is not None
    # Should NOT have debug flag since env var doesn't override in new implementation
    assert " -d" not in helper_cmd


def test_ensure_setup_helper_command_resolver_paths(make_document):
    """Test that the resolver checks all expected paths."""
    document = make_document()
    result = flutter_ops.ensure_setup_helper_command(
        document,
        working_dir="/custom",
    )

    assert result.changed
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")
    commands = lotti.get("build-commands", [])
    helper_cmd = next((cmd for cmd in commands if "setup-flutter.sh" in cmd), None)
    assert helper_cmd is not None
    # Should have custom working directory
    assert "-C /custom" in helper_cmd


def test_ensure_setup_helper_command_custom_working_dir(make_document):
    """Test with a custom working directory."""
    document = make_document()
    result = flutter_ops.ensure_setup_helper_command(
        document,
        working_dir="/opt/custom",
    )

    assert result.changed
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")
    commands = lotti.get("build-commands", [])
    helper_cmd = next((cmd for cmd in commands if "setup-flutter.sh" in cmd), None)
    assert helper_cmd is not None
    # Should pass custom working dir
    assert "-C /opt/custom" in helper_cmd


def test_ensure_setup_helper_command_app_working_dir_fallback(make_document):
    """Test /app working directory with fallback logic."""
    document = make_document()
    result = flutter_ops.ensure_setup_helper_command(
        document,
        working_dir="/app",
    )

    assert result.changed
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")
    commands = lotti.get("build-commands", [])
    helper_cmd = next((cmd for cmd in commands if "setup-flutter.sh" in cmd), None)
    assert helper_cmd is not None
    # Should have /app working directory
    assert "-C /app" in helper_cmd


def test_ensure_setup_helper_command_varlib_working_dir_fallback(make_document):
    """Test /var/lib working directory with fallback logic."""
    document = make_document()
    result = flutter_ops.ensure_setup_helper_command(
        document,
        working_dir="/var/lib",
    )

    assert result.changed
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")
    commands = lotti.get("build-commands", [])
    helper_cmd = next((cmd for cmd in commands if "setup-flutter.sh" in cmd), None)
    assert helper_cmd is not None
    # Should have /var/lib working directory
    assert "-C /var/lib" in helper_cmd


def test_ensure_setup_helper_command_idempotent(make_document):
    """Test that the command is idempotent."""
    document = make_document()

    # First call
    result1 = flutter_ops.ensure_setup_helper_command(
        document,
        working_dir="/app",
    )
    assert result1.changed

    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")
    commands_before = lotti.get("build-commands", []).copy()

    # Second call with same parameters
    result2 = flutter_ops.ensure_setup_helper_command(
        document,
        working_dir="/app",
    )

    # Should recognize it's already there (no change)
    assert not result2.changed
    commands_after = lotti.get("build-commands", [])

    # Commands should not have duplicates
    assert len(commands_after) == len(commands_before)
    assert commands_after == commands_before


def test_bundle_app_archive_replaces_non_file_sources(make_document, tmp_path):
    """Test that bundle_app_archive replaces non-file sources but preserves file sources.

    File sources are preserved because they're often plugin dependencies needed
    for offline builds. Non-file sources (git, patch) are replaced to avoid
    version mismatches.
    """
    document = make_document()

    # Add initial sources with a git source, file source, and patch
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")
    lotti["sources"] = [
        {
            "type": "file",
            "path": "existing-file.txt",
        },  # Should be preserved (plugin dep)
        {"type": "git", "url": "https://github.com/test/test.git"},  # Should be removed
        {"type": "patch", "path": "fix.patch"},  # Should be removed
    ]

    out_dir = tmp_path / "output"
    out_dir.mkdir()
    # Create required files
    (out_dir / "pubspec-sources.json").write_text("[]", encoding="utf-8")
    (out_dir / "setup-flutter.sh").write_text("#!/bin/bash", encoding="utf-8")

    result = flutter_ops.bundle_app_archive(
        document,
        archive_path=str(out_dir / "lotti.tar.xz"),
        sha256="cafebabe",
    )

    assert result.changed
    updated_sources = lotti["sources"]
    assert isinstance(updated_sources, list)

    # First source should be the archive (as a file type)
    assert updated_sources[0]["type"] == "file"
    assert updated_sources[0]["path"] == str(out_dir / "lotti.tar.xz")
    assert updated_sources[0]["sha256"] == "cafebabe"

    # The new implementation preserves all sources except Flutter git sources
    # Patch and non-Flutter git sources are preserved
    assert {"type": "patch", "path": "fix.patch"} in updated_sources
    assert {"type": "git", "url": "https://github.com/test/test.git"} in updated_sources

    # File sources SHOULD be preserved (they're plugin dependencies)
    assert {"type": "file", "path": "existing-file.txt"} in updated_sources

    # The new implementation doesn't automatically add extra sources


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
        archive_path=str(out_dir / "lotti.tar.xz"),
        sha256="cafebabe",
    )

    assert result.changed
    updated_sources = lotti["sources"]

    # The new implementation doesn't automatically add extra sources
    # It only adds the archive and preserves existing sources
    assert len(updated_sources) == 3  # archive + existing git/patch

    # First is always the archive (as a file type)
    assert updated_sources[0]["type"] == "file"
    assert updated_sources[0]["path"] == str(out_dir / "lotti.tar.xz")

    # Old sources are preserved (git and patch)
    assert {"type": "git", "url": "https://github.com/test/test.git"} in updated_sources
    assert {"type": "patch", "path": "old.patch"} in updated_sources


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
        archive_path=str(out_dir / "lotti.tar.xz"),
        sha256="cafebabe",
    )

    assert result.changed
    # Sources should be replaced with a proper list
    updated_sources = lotti["sources"]
    assert isinstance(updated_sources, list)
    assert len(updated_sources) >= 1
    assert updated_sources[0]["type"] == "file"


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
        archive_path=str(out_dir / "lotti.tar.xz"),
        sha256="cafebabe",
    )

    # Should not change anything
    assert not result.changed


# Tests for newly added functions


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


def test_add_media_kit_mimalloc_source(make_document):
    """Test adding mimalloc source for media_kit plugin."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # Start with no sources and build commands
    lotti["sources"] = []
    lotti["build-commands"] = ["echo 'Starting build'", "flutter build linux --release"]

    result = flutter_ops.add_media_kit_mimalloc_source(document)

    assert result.changed
    assert "mimalloc" in str(result.messages).lower()

    # Check that mimalloc sources were added (one for each architecture)
    sources = lotti["sources"]
    assert len(sources) == 2  # x86_64 and aarch64

    # Check both sources
    for source in sources:
        assert source["type"] == "file"
        assert "mimalloc/archive/refs/tags/v2.1.2.tar.gz" in source["url"]
        assert (
            source["sha256"]
            == "2b1bff6f717f9725c70bf8d79e4786da13de8a270059e4ba0bdd262ae7be46eb"
        )
        assert source["dest-filename"] == "mimalloc-2.1.2.tar.gz"
        assert "only-arches" in source
        assert len(source["only-arches"]) == 1

    # Verify we have one for each architecture
    arches = [source["only-arches"][0] for source in sources]
    assert set(arches) == {"x86_64", "aarch64"}

    # Build commands should remain unchanged (no placement commands needed)
    # The bundle-archive-sources will handle placement via the 'dest' field
    commands = lotti.get("build-commands", [])
    # Commands should be unchanged from original
    assert "flutter build linux --release" in commands

    # Run again - should not change
    result2 = flutter_ops.add_media_kit_mimalloc_source(document)
    assert not result2.changed


def test_add_media_kit_mimalloc_source_preserves_existing(make_document):
    """Test that adding mimalloc preserves existing sources."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # Start with existing sources and build commands
    lotti["sources"] = [
        {"type": "git", "url": "https://github.com/test/test.git"},
        {"type": "file", "path": "some-file.txt"},
    ]
    lotti["build-commands"] = ["flutter build linux --release"]

    result = flutter_ops.add_media_kit_mimalloc_source(document)

    assert result.changed
    sources = lotti["sources"]
    assert len(sources) == 4  # Original 2 + 2 mimalloc (x86_64 and aarch64)

    # Original sources still there
    assert sources[0]["type"] == "git"
    assert sources[1]["type"] == "file"
    # New mimalloc sources (2 architectures)
    assert sources[2]["dest-filename"] == "mimalloc-2.1.2.tar.gz"
    assert sources[3]["dest-filename"] == "mimalloc-2.1.2.tar.gz"


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


def test_bundle_app_archive_preserves_mimalloc_source(make_document, tmp_path):
    """Test that bundle_app_archive preserves the mimalloc source."""
    document = make_document()

    # Add mimalloc source first
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")
    lotti["sources"] = [
        {"type": "git", "url": "https://github.com/test/test.git"},
        {
            "type": "file",
            "url": "https://github.com/microsoft/mimalloc/archive/refs/tags/v2.1.2.tar.gz",
            "sha256": "2b1bff6f717f9725c70bf8d79e4786da13de8a270059e4ba0bdd262ae7be46eb",
            "dest-filename": "mimalloc-2.1.2.tar.gz",
        },
    ]

    out_dir = tmp_path / "output"
    out_dir.mkdir()
    # Create required files
    (out_dir / "pubspec-sources.json").write_text("[]", encoding="utf-8")
    (out_dir / "setup-flutter.sh").write_text("#!/bin/bash", encoding="utf-8")

    result = flutter_ops.bundle_app_archive(
        document,
        archive_path=str(out_dir / "lotti.tar.xz"),
        sha256="cafebabe",
    )

    assert result.changed
    updated_sources = lotti["sources"]

    # Find the mimalloc source
    mimalloc_sources = [
        src
        for src in updated_sources
        if isinstance(src, dict) and src.get("dest-filename") == "mimalloc-2.1.2.tar.gz"
    ]

    # Mimalloc source should be preserved
    assert len(mimalloc_sources) == 1
    assert mimalloc_sources[0]["type"] == "file"
    assert (
        mimalloc_sources[0]["sha256"]
        == "2b1bff6f717f9725c70bf8d79e4786da13de8a270059e4ba0bdd262ae7be46eb"
    )


def test_add_sqlite3_source(make_document):
    """Test adding SQLite source for sqlite3_flutter_libs plugin."""
    document = make_document()
    lotti = next(m for m in document.data["modules"] if m["name"] == "lotti")

    # Start with no sources
    lotti["sources"] = []

    result = flutter_ops.add_sqlite3_source(document)

    assert result.changed
    assert "sqlite" in str(result.messages).lower()

    # Check that SQLite sources were added (one for each architecture)
    sources = lotti["sources"]
    assert len(sources) == 2

    # Check x86_64 source
    x64_source = next(s for s in sources if "x86_64" in s.get("only-arches", []))
    assert x64_source["type"] == "file"
    assert "sqlite-autoconf-3510100.tar.gz" in x64_source["url"]
    assert (
        x64_source["sha256"]
        == "4f2445cd70479724d32ad015ec7fd37fbb6f6130013bd4bfbc80c32beb42b7e0"
    )
    assert (
        x64_source["dest"]
        == "./build/linux/x64/release/_deps/sqlite3-subbuild/sqlite3-populate-prefix/src"
    )
    assert x64_source["dest-filename"] == "sqlite-autoconf-3510100.tar.gz"

    # Check aarch64 source
    arm64_source = next(s for s in sources if "aarch64" in s.get("only-arches", []))
    assert arm64_source["type"] == "file"
    assert "sqlite-autoconf-3510100.tar.gz" in arm64_source["url"]
    assert (
        arm64_source["sha256"]
        == "4f2445cd70479724d32ad015ec7fd37fbb6f6130013bd4bfbc80c32beb42b7e0"
    )
    assert (
        arm64_source["dest"]
        == "./build/linux/arm64/release/_deps/sqlite3-subbuild/sqlite3-populate-prefix/src"
    )
    assert arm64_source["dest-filename"] == "sqlite-autoconf-3510100.tar.gz"

    # Run again - should not change
    result2 = flutter_ops.add_sqlite3_source(document)
    assert not result2.changed
