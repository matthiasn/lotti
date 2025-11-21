from __future__ import annotations

from manifest_tool.operations import manifest as manifest_ops


def test_ensure_flutter_setup_helper(make_document):
    document = make_document()
    result = manifest_ops.ensure_flutter_setup_helper(document, helper_name="setup-flutter.sh")

    assert result.changed
    modules = document.data["modules"]
    flutter_sources = next(module for module in modules if module["name"] == "flutter-sdk")["sources"]
    assert any(source.get("dest-filename") == "setup-flutter.sh" for source in flutter_sources)

    lotti = next(module for module in modules if module["name"] == "lotti")
    assert lotti["build-options"]["append-path"].startswith("/app/flutter/bin")


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


def test_ensure_screenshot_asset_adds_entries(make_document):
    manifest_text = """
modules:
  - name: flutter-common
    build-commands:
      - echo existing
    sources:
      - type: file
        path: existing.txt
"""
    document = make_document(manifest_text)

    result = manifest_ops.ensure_screenshot_asset(
        document,
        screenshot_source="screenshot.png",
        install_path="/app/share/app-info/screenshots/com.matthiasn.lotti/main.png",
    )

    assert result.changed
    module = document.data["modules"][0]
    assert (
        "install -D screenshot.png /app/share/app-info/screenshots/com.matthiasn.lotti/main.png"
        in module["build-commands"]
    )
    assert any(source.get("path") == "screenshot.png" for source in module["sources"])


def test_ensure_screenshot_asset_idempotent(make_document):
    manifest_text = """
modules:
  - name: flutter-common
    build-commands:
      - install -D screenshot.png /app/share/app-info/screenshots/com.matthiasn.lotti/main.png
    sources:
      - type: file
        path: screenshot.png
"""
    document = make_document(manifest_text)

    result = manifest_ops.ensure_screenshot_asset(
        document,
        screenshot_source="screenshot.png",
        install_path="/app/share/app-info/screenshots/com.matthiasn.lotti/main.png",
    )

    assert not result.changed
