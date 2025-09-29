"""Tests for YAML-based source operations."""

from __future__ import annotations

from pathlib import Path

import pytest
import yaml

from manifest_tool.operations import sources as sources_ops


def test_replace_url_with_path_yaml_based(tmp_path: Path):
    """Test the new YAML-based URL replacement function."""
    manifest_path = tmp_path / "manifest.yml"
    manifest_data = {
        "modules": [
            {
                "name": "test-module",
                "sources": [
                    {"type": "file", "url": "https://example.com/file.dat"},
                    {"type": "git", "url": "https://github.com/user/repo.git"},
                ],
            }
        ]
    }

    # Write manifest as YAML
    manifest_path.write_text(yaml.dump(manifest_data), encoding="utf-8")

    # Replace URL containing "file.dat" with local path
    result = sources_ops.replace_url_with_path(
        manifest_path=str(manifest_path),
        identifier="file.dat",
        path_value="local-file.dat",
    )

    assert result is True

    # Load and verify the changes
    updated = yaml.safe_load(manifest_path.read_text())
    sources = updated["modules"][0]["sources"]

    # First source should have path instead of url
    assert "url" not in sources[0]
    assert sources[0]["path"] == "local-file.dat"

    # Second source should be unchanged
    assert sources[1]["url"] == "https://github.com/user/repo.git"


def test_replace_url_with_path_no_match(tmp_path: Path):
    """Test when identifier is not found."""
    manifest_path = tmp_path / "manifest.yml"
    manifest_data = {
        "modules": [
            {
                "name": "test-module",
                "sources": [{"type": "git", "url": "https://github.com/user/repo.git"}],
            }
        ]
    }

    manifest_path.write_text(yaml.dump(manifest_data), encoding="utf-8")

    result = sources_ops.replace_url_with_path(
        manifest_path=str(manifest_path),
        identifier="nonexistent",
        path_value="local-file.dat",
    )

    assert result is False

    # Verify nothing changed
    updated = yaml.safe_load(manifest_path.read_text())
    assert (
        updated["modules"][0]["sources"][0]["url"] == "https://github.com/user/repo.git"
    )


def test_replace_url_with_path_multiple_matches(tmp_path: Path):
    """Test replacing multiple URLs containing the same identifier."""
    manifest_path = tmp_path / "manifest.yml"
    manifest_data = {
        "modules": [
            {
                "name": "module1",
                "sources": [
                    {"type": "file", "url": "https://example.com/myfile.tar.gz"}
                ],
            },
            {
                "name": "module2",
                "sources": [
                    {"type": "file", "url": "https://mirror.com/myfile.tar.gz"},
                    {"type": "git", "url": "https://github.com/user/repo"},
                ],
            },
        ]
    }

    manifest_path.write_text(yaml.dump(manifest_data), encoding="utf-8")

    result = sources_ops.replace_url_with_path(
        manifest_path=str(manifest_path),
        identifier="myfile.tar.gz",
        path_value="cached/myfile.tar.gz",
    )

    assert result is True

    updated = yaml.safe_load(manifest_path.read_text())

    # Both file sources should be replaced
    assert updated["modules"][0]["sources"][0]["path"] == "cached/myfile.tar.gz"
    assert "url" not in updated["modules"][0]["sources"][0]

    assert updated["modules"][1]["sources"][0]["path"] == "cached/myfile.tar.gz"
    assert "url" not in updated["modules"][1]["sources"][0]

    # Git source should be unchanged
    assert updated["modules"][1]["sources"][1]["url"] == "https://github.com/user/repo"


def test_replace_url_with_path_invalid_manifest(tmp_path: Path):
    """Test with invalid YAML."""
    manifest_path = tmp_path / "manifest.yml"
    manifest_path.write_text("invalid: yaml: content: [", encoding="utf-8")

    result = sources_ops.replace_url_with_path(
        manifest_path=str(manifest_path), identifier="test", path_value="test.dat"
    )

    # Should return None for invalid YAML (error state)
    assert result is None


def test_replace_url_with_path_nonexistent_file():
    """Test with non-existent file."""
    result = sources_ops.replace_url_with_path(
        manifest_path="/nonexistent/file.yml", identifier="test", path_value="test.dat"
    )

    # Should return None for non-existent file
    assert result is None


def test_replace_url_with_path_in_manifest_direct():
    """Test the direct manifest data manipulation function."""
    manifest_data = {
        "modules": [
            {
                "name": "test",
                "sources": [
                    {"type": "file", "url": "https://example.com/data.zip"},
                    {"type": "git", "url": "https://github.com/test/repo"},
                ],
            }
        ]
    }

    changed = sources_ops.replace_url_with_path_in_manifest(
        manifest_data, "data.zip", "local/data.zip"
    )

    assert changed is True
    assert manifest_data["modules"][0]["sources"][0]["path"] == "local/data.zip"
    assert "url" not in manifest_data["modules"][0]["sources"][0]
    assert (
        manifest_data["modules"][0]["sources"][1]["url"]
        == "https://github.com/test/repo"
    )
