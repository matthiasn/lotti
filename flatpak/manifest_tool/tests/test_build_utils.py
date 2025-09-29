"""Tests for build utilities."""

from __future__ import annotations

import os
import shutil
import tempfile
from pathlib import Path
from unittest.mock import patch

import pytest

from manifest_tool.build_utils import utils as build_utils


def test_find_flutter_sdk(tmp_path: Path):
    """Test finding a Flutter SDK."""
    # Create a fake Flutter SDK structure
    sdk_dir = tmp_path / "flutter"
    sdk_dir.mkdir()

    # Create expected Flutter SDK files
    bin_dir = sdk_dir / "bin"
    bin_dir.mkdir()
    flutter_bin = bin_dir / "flutter"
    flutter_bin.write_text("#!/bin/bash\necho flutter", encoding="utf-8")
    flutter_bin.chmod(0o755)

    dart_bin = bin_dir / "dart"
    dart_bin.write_text("#!/bin/bash\necho dart", encoding="utf-8")

    packages_dir = sdk_dir / "packages"
    packages_dir.mkdir()

    # Find the SDK
    result = build_utils.find_flutter_sdk(search_roots=[tmp_path], max_depth=3)

    assert result == sdk_dir


def test_find_flutter_sdk_with_exclusions(tmp_path: Path):
    """Test finding Flutter SDK with excluded paths."""
    # Create two Flutter SDK structures
    sdk1 = tmp_path / "work" / "flutter"
    sdk1.mkdir(parents=True)

    sdk2 = tmp_path / "cache" / "flutter"
    sdk2.mkdir(parents=True)

    for sdk_dir in [sdk1, sdk2]:
        bin_dir = sdk_dir / "bin"
        bin_dir.mkdir()
        flutter_bin = bin_dir / "flutter"
        flutter_bin.write_text("#!/bin/bash\necho flutter", encoding="utf-8")
        flutter_bin.chmod(0o755)

        dart_bin = bin_dir / "dart"
        dart_bin.write_text("#!/bin/bash\necho dart", encoding="utf-8")

        packages_dir = sdk_dir / "packages"
        packages_dir.mkdir()

    # Find SDK excluding the work directory
    result = build_utils.find_flutter_sdk(
        search_roots=[tmp_path], exclude_paths=[tmp_path / "work"], max_depth=3
    )

    assert result == sdk2


def test_find_flutter_sdk_not_found(tmp_path: Path):
    """Test when Flutter SDK is not found."""
    # Create a directory without Flutter SDK
    (tmp_path / "some_dir").mkdir()

    result = build_utils.find_flutter_sdk(search_roots=[tmp_path], max_depth=3)

    assert result is None


def test_find_flutter_sdk_invalid_sdk(tmp_path: Path):
    """Test finding invalid Flutter SDK (missing required files)."""
    # Create incomplete Flutter SDK structure
    sdk_dir = tmp_path / "flutter"
    sdk_dir.mkdir()

    # Only create flutter binary, missing dart and packages
    bin_dir = sdk_dir / "bin"
    bin_dir.mkdir()
    flutter_bin = bin_dir / "flutter"
    flutter_bin.write_text("#!/bin/bash\necho flutter", encoding="utf-8")
    flutter_bin.chmod(0o755)

    # Find should fail due to missing dart and packages
    result = build_utils.find_flutter_sdk(search_roots=[tmp_path], max_depth=3)

    assert result is None


def test_find_flutter_sdk_depth_limit(tmp_path: Path):
    """Test that max_depth is respected."""
    # Create Flutter SDK deep in directory structure
    deep_path = tmp_path
    for i in range(10):
        deep_path = deep_path / f"level{i}"

    sdk_dir = deep_path / "flutter"
    sdk_dir.mkdir(parents=True)

    bin_dir = sdk_dir / "bin"
    bin_dir.mkdir()
    flutter_bin = bin_dir / "flutter"
    flutter_bin.write_text("#!/bin/bash\necho flutter", encoding="utf-8")
    flutter_bin.chmod(0o755)

    dart_bin = bin_dir / "dart"
    dart_bin.write_text("#!/bin/bash\necho dart", encoding="utf-8")

    packages_dir = sdk_dir / "packages"
    packages_dir.mkdir()

    # Should not find SDK due to depth limit
    result = build_utils.find_flutter_sdk(search_roots=[tmp_path], max_depth=3)

    assert result is None

    # Should find with higher depth limit
    result = build_utils.find_flutter_sdk(search_roots=[tmp_path], max_depth=15)

    assert result == sdk_dir


def test_prepare_build_directory(tmp_path: Path):
    """Test preparing a build directory."""
    build_dir = tmp_path / "build"
    pubspec_yaml = tmp_path / "pubspec.yaml"
    pubspec_lock = tmp_path / "pubspec.lock"

    pubspec_yaml.write_text("name: test\nversion: 1.0.0", encoding="utf-8")
    pubspec_lock.write_text("packages: {}", encoding="utf-8")

    result = build_utils.prepare_build_directory(
        build_dir=build_dir,
        pubspec_yaml=pubspec_yaml,
        pubspec_lock=pubspec_lock,
        create_foreign_deps=True,
    )

    assert result is True
    assert build_dir.exists()
    assert (build_dir / "pubspec.yaml").exists()
    assert (build_dir / "pubspec.lock").exists()
    assert (build_dir / "foreign_deps.json").exists()
    assert (build_dir / "foreign_deps.json").read_text() == "{}"


def test_prepare_build_directory_no_foreign_deps(tmp_path: Path):
    """Test preparing build directory without foreign_deps.json."""
    build_dir = tmp_path / "build"

    result = build_utils.prepare_build_directory(
        build_dir=build_dir, create_foreign_deps=False
    )

    assert result is True
    assert build_dir.exists()
    assert not (build_dir / "foreign_deps.json").exists()


def test_prepare_build_directory_missing_files(tmp_path: Path):
    """Test preparing build directory with missing source files."""
    build_dir = tmp_path / "build"

    # Reference non-existent files
    result = build_utils.prepare_build_directory(
        build_dir=build_dir,
        pubspec_yaml=tmp_path / "nonexistent.yaml",
        pubspec_lock=tmp_path / "nonexistent.lock",
    )

    # Should still succeed, just skip missing files
    assert result is True
    assert build_dir.exists()
    assert not (build_dir / "pubspec.yaml").exists()
    assert not (build_dir / "pubspec.lock").exists()


def test_prepare_build_directory_existing_foreign_deps(tmp_path: Path):
    """Test that existing foreign_deps.json is not overwritten."""
    build_dir = tmp_path / "build"
    build_dir.mkdir()

    # Create existing foreign_deps.json with content
    foreign_deps = build_dir / "foreign_deps.json"
    foreign_deps.write_text('{"existing": "data"}', encoding="utf-8")

    result = build_utils.prepare_build_directory(
        build_dir=build_dir, create_foreign_deps=True
    )

    assert result is True
    # Should preserve existing content
    assert foreign_deps.read_text() == '{"existing": "data"}'


@patch("manifest_tool.build_utils.utils._LOGGER")
def test_prepare_build_directory_error_handling(mock_logger, tmp_path: Path):
    """Test error handling in prepare_build_directory."""
    # Create a file where we expect a directory
    build_dir = tmp_path / "build"
    build_dir.write_text("not a directory")

    pubspec_yaml = tmp_path / "pubspec.yaml"
    pubspec_yaml.write_text("name: test", encoding="utf-8")

    with patch("pathlib.Path.mkdir", side_effect=OSError("Permission denied")):
        result = build_utils.prepare_build_directory(
            build_dir=build_dir, pubspec_yaml=pubspec_yaml
        )

    assert result is False
    mock_logger.error.assert_called()


def test_copy_flutter_sdk(tmp_path: Path):
    """Test copying a Flutter SDK."""
    # Create source SDK
    source_sdk = tmp_path / "source" / "flutter"
    source_sdk.mkdir(parents=True)

    bin_dir = source_sdk / "bin"
    bin_dir.mkdir()
    flutter_bin = bin_dir / "flutter"
    flutter_bin.write_text("#!/bin/bash\necho flutter", encoding="utf-8")
    flutter_bin.chmod(0o755)

    dart_bin = bin_dir / "dart"
    dart_bin.write_text("#!/bin/bash\necho dart", encoding="utf-8")

    packages_dir = source_sdk / "packages"
    packages_dir.mkdir()
    (packages_dir / "test.dart").write_text("// test")

    # Copy to target
    target_dir = tmp_path / "target" / "flutter"

    result = build_utils.copy_flutter_sdk(
        source_sdk=source_sdk, target_dir=target_dir, clean_target=True
    )

    assert result is True
    assert target_dir.exists()
    assert (target_dir / "bin" / "flutter").exists()
    assert (target_dir / "bin" / "dart").exists()
    assert (target_dir / "packages" / "test.dart").exists()


def test_copy_flutter_sdk_clean_existing(tmp_path: Path):
    """Test copying Flutter SDK with cleaning existing target."""
    # Create source SDK
    source_sdk = tmp_path / "source" / "flutter"
    source_sdk.mkdir(parents=True)

    bin_dir = source_sdk / "bin"
    bin_dir.mkdir()
    flutter_bin = bin_dir / "flutter"
    flutter_bin.write_text("#!/bin/bash\necho flutter", encoding="utf-8")
    flutter_bin.chmod(0o755)

    # Create target with existing content
    target_dir = tmp_path / "target" / "flutter"
    target_dir.mkdir(parents=True)
    old_file = target_dir / "old_file.txt"
    old_file.write_text("should be removed")

    result = build_utils.copy_flutter_sdk(
        source_sdk=source_sdk, target_dir=target_dir, clean_target=True
    )

    assert result is True
    assert not old_file.exists()
    assert (target_dir / "bin" / "flutter").exists()


def test_copy_flutter_sdk_invalid_source(tmp_path: Path):
    """Test copying from invalid Flutter SDK."""
    # Create invalid source (no flutter binary)
    source_sdk = tmp_path / "source" / "flutter"
    source_sdk.mkdir(parents=True)

    target_dir = tmp_path / "target" / "flutter"

    result = build_utils.copy_flutter_sdk(source_sdk=source_sdk, target_dir=target_dir)

    assert result is False


@patch("manifest_tool.build_utils.utils._LOGGER")
def test_copy_flutter_sdk_copy_error(mock_logger, tmp_path: Path):
    """Test error handling during SDK copy."""
    # Create source SDK
    source_sdk = tmp_path / "source" / "flutter"
    source_sdk.mkdir(parents=True)

    bin_dir = source_sdk / "bin"
    bin_dir.mkdir()
    flutter_bin = bin_dir / "flutter"
    flutter_bin.write_text("#!/bin/bash\necho flutter", encoding="utf-8")

    target_dir = tmp_path / "target" / "flutter"

    with patch("shutil.copytree", side_effect=OSError("Copy failed")):
        result = build_utils.copy_flutter_sdk(
            source_sdk=source_sdk, target_dir=target_dir
        )

    assert result is False
    mock_logger.error.assert_called()


def test_copy_flutter_sdk_python37_fallback(tmp_path: Path):
    """Test copying Flutter SDK with Python 3.7 fallback (no dirs_exist_ok)."""
    # Create source SDK with nested directories
    source_sdk = tmp_path / "source" / "flutter"
    source_sdk.mkdir(parents=True)

    bin_dir = source_sdk / "bin"
    bin_dir.mkdir()
    flutter_bin = bin_dir / "flutter"
    flutter_bin.write_text("#!/bin/bash\necho flutter", encoding="utf-8")
    flutter_bin.chmod(0o755)

    dart_bin = bin_dir / "dart"
    dart_bin.write_text("#!/bin/bash\necho dart", encoding="utf-8")

    # Create nested directory structure
    nested_dir = source_sdk / "packages" / "flutter" / "lib"
    nested_dir.mkdir(parents=True)
    (nested_dir / "material.dart").write_text("// material")

    # Create target with partial existing structure to test the fallback
    target_dir = tmp_path / "target" / "flutter"
    target_dir.mkdir(parents=True)

    # Mock shutil.copytree to raise TypeError on dirs_exist_ok parameter
    original_copytree = shutil.copytree

    def mock_copytree(src, dst, *args, **kwargs):
        if "dirs_exist_ok" in kwargs:
            # Simulate Python < 3.8 which doesn't support dirs_exist_ok
            raise TypeError(
                "copytree() got an unexpected keyword argument 'dirs_exist_ok'"
            )
        return original_copytree(src, dst, *args, **kwargs)

    with patch.object(shutil, "copytree", side_effect=mock_copytree):
        result = build_utils.copy_flutter_sdk(
            source_sdk=source_sdk, target_dir=target_dir, clean_target=True
        )

    # Verify the copy succeeded using fallback logic
    assert result is True
    assert target_dir.exists()
    assert (target_dir / "bin" / "flutter").exists()
    assert (target_dir / "bin" / "dart").exists()
    assert (target_dir / "packages" / "flutter" / "lib" / "material.dart").exists()

    # Verify file contents were copied
    flutter_content = (target_dir / "bin" / "flutter").read_text()
    assert "echo flutter" in flutter_content
