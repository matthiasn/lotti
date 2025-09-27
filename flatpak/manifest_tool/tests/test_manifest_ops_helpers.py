"""Tests for manifest_ops helper functions."""

from __future__ import annotations

import pytest

from flatpak.manifest_tool import manifest_ops


def test_is_lotti_module():
    """Test _is_lotti_module helper."""
    assert manifest_ops._is_lotti_module({"name": "lotti"})
    assert manifest_ops._is_lotti_module({"name": "lotti", "sources": []})
    assert not manifest_ops._is_lotti_module({"name": "flutter-sdk"})
    assert not manifest_ops._is_lotti_module({})
    assert not manifest_ops._is_lotti_module("lotti")
    assert not manifest_ops._is_lotti_module(None)


def test_is_git_source():
    """Test _is_git_source helper."""
    assert manifest_ops._is_git_source({"type": "git"})
    assert manifest_ops._is_git_source({"type": "git", "url": "https://example.com"})
    assert not manifest_ops._is_git_source({"type": "archive"})
    assert not manifest_ops._is_git_source({"type": "file"})
    assert not manifest_ops._is_git_source({})
    assert not manifest_ops._is_git_source("git")
    assert not manifest_ops._is_git_source(None)


def test_normalize_repo_url():
    """Test _normalize_repo_url helper."""
    # HTTPS URLs
    assert (
        manifest_ops._normalize_repo_url("https://github.com/user/repo") == "user/repo"
    )
    assert (
        manifest_ops._normalize_repo_url("https://github.com/user/repo.git")
        == "user/repo"
    )

    # SSH URLs
    assert manifest_ops._normalize_repo_url("git@github.com:user/repo") == "user/repo"
    assert (
        manifest_ops._normalize_repo_url("git@github.com:user/repo.git") == "user/repo"
    )

    # Already normalized
    assert manifest_ops._normalize_repo_url("user/repo") == "user/repo"

    # Other URLs
    assert (
        manifest_ops._normalize_repo_url("https://gitlab.com/user/repo")
        == "https://gitlab.com/user/repo"
    )


def test_is_lotti_repo_url():
    """Test _is_lotti_repo_url helper - only accepts official repo."""
    # Official lotti URLs - these should all be accepted
    assert manifest_ops._is_lotti_repo_url("https://github.com/matthiasn/lotti")
    assert manifest_ops._is_lotti_repo_url("https://github.com/matthiasn/lotti.git")
    assert manifest_ops._is_lotti_repo_url("git@github.com:matthiasn/lotti")
    assert manifest_ops._is_lotti_repo_url("git@github.com:matthiasn/lotti.git")

    # Fork URLs - should NOT be accepted (only official repo allowed)
    assert not manifest_ops._is_lotti_repo_url("https://github.com/someuser/lotti")
    assert not manifest_ops._is_lotti_repo_url("git@github.com:someuser/lotti.git")

    # Non-lotti URLs
    assert not manifest_ops._is_lotti_repo_url("https://github.com/user/other-repo")
    assert not manifest_ops._is_lotti_repo_url(
        "https://github.com/matthiasn/lotti-fork"
    )
    assert not manifest_ops._is_lotti_repo_url("https://github.com/matthiasn/other")

    # Edge cases
    assert not manifest_ops._is_lotti_repo_url("")
    assert not manifest_ops._is_lotti_repo_url("lotti")  # Missing github.com prefix
    assert not manifest_ops._is_lotti_repo_url(
        "https://gitlab.com/matthiasn/lotti"
    )  # Wrong host


def test_update_source_for_pr():
    """Test _update_source_for_pr helper."""
    # URL needs updating
    source = {"url": "https://github.com/matthiasn/lotti", "commit": "old-commit"}
    changes = manifest_ops._update_source_for_pr(
        source, "https://github.com/fork/lotti", "new-commit"
    )
    assert source["url"] == "https://github.com/fork/lotti"
    assert source["commit"] == "new-commit"
    assert len(changes) == 2
    assert "Updated URL to https://github.com/fork/lotti" in changes
    assert "Pinned to PR commit new-commit" in changes

    # URL already correct, only commit needs updating
    source = {"url": "https://github.com/fork/lotti", "commit": "old-commit"}
    changes = manifest_ops._update_source_for_pr(
        source, "https://github.com/fork/lotti", "new-commit"
    )
    assert source["commit"] == "new-commit"
    assert len(changes) == 1
    assert "Pinned to PR commit new-commit" in changes

    # Everything already correct
    source = {"url": "https://github.com/fork/lotti", "commit": "new-commit"}
    changes = manifest_ops._update_source_for_pr(
        source, "https://github.com/fork/lotti", "new-commit"
    )
    assert len(changes) == 0

    # Branch should be removed
    source = {"url": "https://github.com/fork/lotti", "commit": "old", "branch": "main"}
    changes = manifest_ops._update_source_for_pr(
        source, "https://github.com/fork/lotti", "new-commit"
    )
    assert "branch" not in source
    assert source["commit"] == "new-commit"


def test_update_source_for_commit():
    """Test _update_source_for_commit helper."""
    # Replace placeholder
    source = {"commit": "COMMIT_PLACEHOLDER"}
    changes = manifest_ops._update_source_for_commit(source, "abc123")
    assert source["commit"] == "abc123"
    assert len(changes) == 1
    assert "Updated commit to abc123" in changes

    # Update different commit
    source = {"commit": "old-commit"}
    changes = manifest_ops._update_source_for_commit(source, "new-commit")
    assert source["commit"] == "new-commit"
    assert len(changes) == 1
    assert "Updated commit to new-commit" in changes

    # Same commit, but has branch
    source = {"commit": "abc123", "branch": "main"}
    changes = manifest_ops._update_source_for_commit(source, "abc123")
    assert source["commit"] == "abc123"
    assert "branch" not in source
    assert len(changes) == 1
    assert "Removed branch reference" in changes

    # Already correct
    source = {"commit": "abc123"}
    changes = manifest_ops._update_source_for_commit(source, "abc123")
    assert len(changes) == 0

    # Edge cases
    # No commit field at all
    source = {}
    changes = manifest_ops._update_source_for_commit(source, "abc123")
    assert source["commit"] == "abc123"
    assert len(changes) == 1
    assert "Updated commit to abc123" in changes

    # Empty commit field
    source = {"commit": ""}
    changes = manifest_ops._update_source_for_commit(source, "abc123")
    assert source["commit"] == "abc123"
    assert len(changes) == 1
    assert "Updated commit to abc123" in changes
