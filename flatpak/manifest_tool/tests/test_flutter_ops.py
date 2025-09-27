from __future__ import annotations

from pathlib import Path

import pytest

from flatpak.manifest_tool import flutter_ops
from flatpak.manifest_tool.manifest import ManifestDocument


def test_ensure_nested_sdk(make_document, tmp_path: Path):
    document = make_document()
    out_dir = tmp_path / "out"
    out_dir.mkdir()
    (out_dir / "flutter-sdk-offline.json").write_text("{}", encoding="utf-8")

    result = flutter_ops.ensure_nested_sdk(document, output_dir=out_dir)

    assert result.changed
    lotti = next(module for module in document.data["modules"] if module["name"] == "lotti")
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
    commands = next(module for module in document.data["modules"] if module["name"] == "flutter-sdk")["build-commands"]
    assert commands == ["mv flutter /app/flutter", "export PATH=/app/flutter/bin:$PATH"]


def test_normalize_lotti_env_top_layout(make_document):
    document = make_document()
    result = flutter_ops.normalize_lotti_env(document, flutter_bin="/app/flutter/bin", ensure_append_path=True)

    assert result.changed
    lotti = next(module for module in document.data["modules"] if module["name"] == "lotti")
    env_path = lotti["build-options"]["env"]["PATH"]
    append_path = lotti["build-options"]["append-path"]
    assert env_path.startswith("/app/flutter/bin")
    assert append_path.endswith("/app/flutter/bin")


def test_ensure_setup_helper_source_and_command(make_document):
    document = make_document()
    source_result = flutter_ops.ensure_setup_helper_source(document, helper_name="setup-flutter.sh")
    command_result = flutter_ops.ensure_setup_helper_command(
        document,
        helper_name="setup-flutter.sh",
        working_dir="/app",
    )

    assert source_result.changed
    assert command_result.changed

    lotti = next(module for module in document.data["modules"] if module["name"] == "lotti")
    sources = lotti["sources"]
    assert any(isinstance(src, dict) and src.get("path") == "setup-flutter.sh" for src in sources)

    commands = lotti["build-commands"]
    # The helper command resolves the helper and invokes it; assert the command contains -C /app
    assert any("setup-flutter.sh" in cmd and "-C /app" in cmd for cmd in commands)


def test_ensure_rust_sdk_env(make_document):
    document = make_document()
    result = flutter_ops.ensure_rust_sdk_env(document)
    assert result.changed
    lotti = next(module for module in document.data["modules"] if module["name"] == "lotti")
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
    commands = next(module for module in document.data["modules"] if module["name"] == "lotti")["build-commands"]
    assert commands[0].startswith("if [ -d /var/lib/flutter ]")


def test_convert_flutter_git_to_archive(make_document):
    document = make_document()
    result = flutter_ops.convert_flutter_git_to_archive(
        document,
        archive_name="flutter.tar.xz",
        sha256="deadbeef",
    )

    assert result.changed
    flutter_module = next(module for module in document.data["modules"] if module["name"] == "flutter-sdk")
    assert flutter_module["sources"][0]["type"] == "archive"
    assert flutter_module["sources"][0]["path"] == "flutter.tar.xz"
    assert flutter_module["sources"][0]["sha256"] == "deadbeef"

    lotti = next(module for module in document.data["modules"] if module["name"] == "lotti")
    assert not any(
        source.get("dest") == "flutter"
        for source in lotti["sources"]
        if isinstance(source, dict)
    )


def test_rewrite_flutter_git_url(make_document):
    document = make_document()
    lotti = next(module for module in document.data["modules"] if module["name"] == "lotti")
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

    lotti = next(module for module in document.data["modules"] if module["name"] == "lotti")
    first_source = lotti["sources"][0]
    assert first_source["path"] == "lotti.tar.xz"
    assert first_source["sha256"] == "cafebabe"
    assert "flutter-sdk-offline.json" in lotti.get("modules", [])


@pytest.mark.parametrize("layout,expected_dir", [("top", "/app"), ("nested", "/var/lib")])
def test_ensure_setup_helper_command_layout(make_document, layout: str, expected_dir: str):
    document = make_document()
    result = flutter_ops.ensure_setup_helper_command(
        document,
        helper_name="setup-flutter.sh",
        working_dir="/app" if layout == "top" else "/var/lib",
    )

    assert result.changed
    lotti = next(module for module in document.data["modules"] if module["name"] == "lotti")
    commands = lotti["build-commands"]
    assert any(expected_dir in command for command in commands)
