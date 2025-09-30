from __future__ import annotations

import itertools
import sys
import textwrap
from pathlib import Path

# Ensure repository root is importable when executing tests from `flatpak/`.
PACKAGE_ROOT = Path(__file__).resolve().parents[3]
if str(PACKAGE_ROOT) not in sys.path:
    sys.path.insert(0, str(PACKAGE_ROOT))

import pytest  # noqa: E402

from manifest_tool.core.manifest import ManifestDocument  # noqa: E402

SAMPLE_MANIFEST = textwrap.dedent(
    """
    modules:
      - name: flutter-sdk
        build-commands:
          - mv flutter /app/flutter
          - export PATH=/app/flutter/bin:$PATH
          - /app/flutter/bin/flutter --version
        sources:
          - type: git
            url: https://github.com/flutter/flutter.git
            dest: flutter
      - name: lotti
        modules: []
        sources:
          - type: git
            url: https://github.com/matthiasn/lotti
            commit: COMMIT_PLACEHOLDER
          - type: git
            url: https://example.com/alt.git
            dest: flutter
          - type: archive
            url: https://example.com/archive.tar.gz
          - type: file
            url: https://example.com/helper.dat
        build-options:
          append-path: /usr/bin
          env:
            PATH: /usr/bin
        build-commands:
          - cp -r /app/flutter /run/build/lotti/flutter_sdk
          - echo build
    """
)


@pytest.fixture
def sample_manifest_text() -> str:
    return SAMPLE_MANIFEST


@pytest.fixture
def make_document(tmp_path: Path, sample_manifest_text: str):
    counter = itertools.count()

    def _make(text: str | None = None) -> ManifestDocument:
        manifest_text = text or sample_manifest_text
        path = tmp_path / f"manifest_{next(counter)}.yml"
        path.write_text(manifest_text, encoding="utf-8")
        return ManifestDocument.load(path)

    return _make


@pytest.fixture
def manifest_file(tmp_path: Path, sample_manifest_text: str) -> Path:
    path = tmp_path / "manifest_cli.yml"
    path.write_text(sample_manifest_text, encoding="utf-8")
    return path


@pytest.fixture
def output_dir(tmp_path: Path) -> Path:
    path = tmp_path / "output"
    path.mkdir()
    return path
