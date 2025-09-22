from __future__ import annotations

from flatpak.manifest_tool import manifest_ops


def test_ensure_flutter_setup_helper(make_document):
    document = make_document()
    result = manifest_ops.ensure_flutter_setup_helper(document, helper_name="setup-flutter.sh")

    assert result.changed
    modules = document.data["modules"]
    flutter_sources = next(module for module in modules if module["name"] == "flutter-sdk")["sources"]
    assert any(source.get("dest-filename") == "setup-flutter.sh" for source in flutter_sources)

    lotti = next(module for module in modules if module["name"] == "lotti")
    assert lotti["build-options"]["env"]["PATH"].startswith("/app/flutter/bin")


def test_pin_commit_updates_sources(make_document):
    document = make_document()
    result = manifest_ops.pin_commit(document, commit="abc123")

    assert result.changed
    lotti = next(module for module in document.data["modules"] if module["name"] == "lotti")
    commits = [source.get("commit") for source in lotti["sources"] if isinstance(source, dict)]
    assert "abc123" in commits
    assert document.changed


def test_pin_commit_no_change_when_already_pinned(make_document):
    document = make_document()
    manifest_ops.pin_commit(document, commit="abc123")
    document.save()

    result = manifest_ops.pin_commit(document, commit="abc123")
    assert not result.changed
