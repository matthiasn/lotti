from __future__ import annotations

from pathlib import Path

import pytest
import yaml

from flatpak.manifest_tool.manifest import (
    ManifestDocument,
    OperationResult,
    merge_results,
)


def test_manifest_document_load_and_save(make_document):
    document = make_document()
    assert document.data["modules"], "Expected modules to be present"
    assert not document.changed

    document.mark_changed()
    assert document.changed

    document.save()
    assert not document.changed

    # Parse the saved YAML and verify structure
    content = document.path.read_text(encoding="utf-8")
    parsed = yaml.safe_load(content)
    assert "modules" in parsed
    assert isinstance(parsed["modules"], list)


def test_manifest_document_allow_missing(tmp_path: Path):
    missing = tmp_path / "missing.yml"
    document = ManifestDocument.load(missing, allow_missing=True)
    assert document.data == {}
    assert document.path == missing


def test_manifest_document_ensure_modules_type_error(make_document):
    document = make_document(text="{}\n")
    with pytest.raises(TypeError):
        document.ensure_modules()


def test_operation_result_helpers():
    result = OperationResult.changed_result("changed")
    assert result.changed
    assert result.messages == ["changed"]

    result.add_message("extra")
    assert result.messages[-1] == "extra"

    merged = merge_results([OperationResult.unchanged(), result])
    assert merged.changed
    assert merged.messages[-1] == "extra"
