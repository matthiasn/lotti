#!/usr/bin/env python3
"""Tests for the Flathub Flutter pin guard.

The guard's whole value is that it fires. Most of these tests therefore pin the
ways it could quietly stop firing — an unparsed manifest, a restructured source
list, a commented-out tag — rather than only the happy path.
"""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from check_flutter_pin import read_fvmrc_version, read_manifest_flutter_tag


MANIFEST = """\
modules:
  - name: lotti
    sources:
      - type: git
        url: https://github.com/matthiasn/lotti
        commit: COMMIT_PLACEHOLDER
        disable-lfs: true
      - type: git
        url: https://github.com/flutter/flutter.git
        tag: {tag}
        dest: flutter
        disable-lfs: true
      - type: script
        dest-filename: lotti-wrapper.sh
"""


class ReadFvmrcVersionTest(unittest.TestCase):
    def _write(self, contents: str) -> Path:
        directory = Path(tempfile.mkdtemp())
        path = directory / ".fvmrc"
        path.write_text(contents)
        return path

    def test_reads_the_pinned_version(self):
        path = self._write(json.dumps({"flutter": "3.44.8"}))
        self.assertEqual(read_fvmrc_version(path), "3.44.8")

    def test_tolerates_surrounding_whitespace(self):
        path = self._write(json.dumps({"flutter": " 3.44.8\n"}))
        self.assertEqual(read_fvmrc_version(path), "3.44.8")

    def test_rejects_a_missing_flutter_entry(self):
        # Comparing against None would make every manifest tag "wrong" — but
        # for the wrong reason, and with a baffling message.
        path = self._write(json.dumps({"channel": "stable"}))
        with self.assertRaises(ValueError):
            read_fvmrc_version(path)

    def test_rejects_a_non_string_version(self):
        path = self._write(json.dumps({"flutter": 3.44}))
        with self.assertRaises(ValueError):
            read_fvmrc_version(path)


class ReadManifestFlutterTagTest(unittest.TestCase):
    def _write(self, contents: str) -> Path:
        directory = Path(tempfile.mkdtemp())
        path = directory / "manifest.yml"
        path.write_text(contents)
        return path

    def test_reads_the_flutter_sdk_tag(self):
        path = self._write(MANIFEST.format(tag="3.44.8"))
        self.assertEqual(read_manifest_flutter_tag(path), "3.44.8")

    def test_ignores_the_app_source_which_carries_a_commit(self):
        # The app source sits directly above the SDK source and is also a git
        # source. Confusing the two would read COMMIT_PLACEHOLDER as a version.
        path = self._write(MANIFEST.format(tag="3.44.8"))
        self.assertNotIn("PLACEHOLDER", read_manifest_flutter_tag(path))

    def test_does_not_walk_past_the_end_of_its_own_source(self):
        # A tag belonging to a *later* source must not be attributed to the
        # Flutter SDK when the SDK's own tag is gone.
        path = self._write(
            """\
    sources:
      - type: git
        url: https://github.com/flutter/flutter.git
        dest: flutter
      - type: git
        url: https://github.com/example/other.git
        tag: 9.9.9
"""
        )
        with self.assertRaises(ValueError):
            read_manifest_flutter_tag(path)

    def test_rejects_a_manifest_with_no_flutter_source(self):
        # The vacuous-pass case: if the manifest is restructured and the URL no
        # longer appears, the guard must fail loudly rather than report success.
        path = self._write("modules:\n  - name: lotti\n    sources: []\n")
        with self.assertRaises(ValueError):
            read_manifest_flutter_tag(path)

    def test_rejects_two_flutter_sources(self):
        path = self._write(
            MANIFEST.format(tag="3.44.8") + MANIFEST.format(tag="3.44.0")
        )
        with self.assertRaises(ValueError):
            read_manifest_flutter_tag(path)

    def test_ignores_a_commented_out_tag(self):
        path = self._write(
            """\
    sources:
      - type: git
        url: https://github.com/flutter/flutter.git
        # tag: 3.44.0
        tag: 3.44.8
"""
        )
        self.assertEqual(read_manifest_flutter_tag(path), "3.44.8")


class RepositoryPinsTest(unittest.TestCase):
    def test_the_checked_in_pins_agree(self):
        # Guards the guard: proves it runs against the real files and that the
        # manifest parser still finds a tag in the manifest as committed.
        repo_root = Path(__file__).resolve().parents[1]
        manifest = repo_root / "flatpak" / "com.matthiasn.lotti.flatpak-flutter.yml"
        self.assertEqual(
            read_fvmrc_version(repo_root / ".fvmrc"),
            read_manifest_flutter_tag(manifest),
        )


if __name__ == "__main__":
    unittest.main()
