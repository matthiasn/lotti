"""Tests for the update-manifest command."""

from __future__ import annotations

import yaml

from manifest_tool.operations import manifest as manifest_ops
from manifest_tool.core import ManifestDocument


def test_update_manifest_for_build_non_pr(tmp_path):
    """Test updating manifest for non-PR build."""
    manifest_path = tmp_path / "test.yml"
    manifest_data = {
        "modules": [
            {
                "name": "lotti",
                "sources": [
                    {
                        "type": "git",
                        "url": "https://github.com/matthiasn/lotti",
                        "commit": "COMMIT_PLACEHOLDER",
                    }
                ],
            }
        ]
    }
    manifest_path.write_text(yaml.dump(manifest_data))

    # Load and update
    doc = ManifestDocument.load(manifest_path)
    result = manifest_ops.update_manifest_for_build(doc, commit="abc123", pr_url=None, pr_commit=None)

    assert result.changed
    assert any("Updated commit to abc123" in msg for msg in result.messages)

    # Save and verify
    doc.save()
    updated = yaml.safe_load(manifest_path.read_text())
    assert updated["modules"][0]["sources"][0]["commit"] == "abc123"


def test_update_manifest_for_build_pr(tmp_path):
    """Test updating manifest for PR build."""
    manifest_path = tmp_path / "test.yml"
    manifest_data = {
        "modules": [
            {
                "name": "lotti",
                "sources": [
                    {
                        "type": "git",
                        "url": "https://github.com/matthiasn/lotti",
                        "commit": "COMMIT_PLACEHOLDER",
                    }
                ],
            }
        ]
    }
    manifest_path.write_text(yaml.dump(manifest_data))

    # Load and update
    doc = ManifestDocument.load(manifest_path)
    result = manifest_ops.update_manifest_for_build(
        doc,
        commit=None,
        pr_url="https://github.com/someuser/lotti",
        pr_commit="def456",
    )

    assert result.changed
    messages_str = " ".join(result.messages)
    assert "Updated URL to https://github.com/someuser/lotti" in messages_str
    assert "Pinned to PR commit def456" in messages_str

    # Save and verify
    doc.save()
    updated = yaml.safe_load(manifest_path.read_text())
    assert updated["modules"][0]["sources"][0]["url"] == "https://github.com/someuser/lotti"
    assert updated["modules"][0]["sources"][0]["commit"] == "def456"


def test_update_manifest_for_build_no_change(tmp_path):
    """Test updating manifest when already at target state."""
    manifest_path = tmp_path / "test.yml"
    manifest_data = {
        "modules": [
            {
                "name": "lotti",
                "sources": [
                    {
                        "type": "git",
                        "url": "https://github.com/matthiasn/lotti",
                        "commit": "abc123",
                    }
                ],
            }
        ]
    }
    manifest_path.write_text(yaml.dump(manifest_data))

    # Load and update with same commit
    doc = ManifestDocument.load(manifest_path)
    result = manifest_ops.update_manifest_for_build(doc, commit="abc123", pr_url=None, pr_commit=None)

    assert not result.changed
    assert result.messages == []


def test_update_manifest_ignores_non_git_sources(tmp_path):
    """Test that non-git sources are ignored."""
    manifest_path = tmp_path / "test.yml"
    manifest_data = {
        "modules": [
            {
                "name": "lotti",
                "sources": [
                    {
                        "type": "archive",
                        "url": "https://example.com/archive.tar.gz",
                    },
                    {
                        "type": "git",
                        "url": "https://github.com/matthiasn/lotti",
                        "commit": "COMMIT_PLACEHOLDER",
                    },
                ],
            }
        ]
    }
    manifest_path.write_text(yaml.dump(manifest_data))

    # Load and update
    doc = ManifestDocument.load(manifest_path)
    result = manifest_ops.update_manifest_for_build(doc, commit="abc123", pr_url=None, pr_commit=None)

    assert result.changed
    doc.save()
    updated = yaml.safe_load(manifest_path.read_text())

    # Archive source should be unchanged
    assert updated["modules"][0]["sources"][0]["type"] == "archive"
    assert "commit" not in updated["modules"][0]["sources"][0]

    # Git source should be updated
    assert updated["modules"][0]["sources"][1]["commit"] == "abc123"
