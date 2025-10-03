import json
import tempfile
from pathlib import Path
from unittest import TestCase

from flatpak.manifest_tool.tools import get_fvm_flutter_version


class GetFvmFlutterVersionTests(TestCase):
    def test_read_version_primary_field(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp) / "config.json"
            config.write_text(json.dumps({"flutterSdkVersion": "3.40.0"}), encoding="utf-8")
            self.assertEqual(get_fvm_flutter_version.read_version(config), "3.40.0")

    def test_read_version_fallback_field(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp) / "config.json"
            config.write_text(json.dumps({"flutterSdk": "3.39.1"}), encoding="utf-8")
            self.assertEqual(get_fvm_flutter_version.read_version(config), "3.39.1")

    def test_main_with_env_returns_success(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp) / "config.json"
            config.write_text(json.dumps({"flutterSdkVersion": "3.38.0"}), encoding="utf-8")
            env = {"FVM_CONFIG_PATH": str(config)}
            self.assertEqual(get_fvm_flutter_version.main_with_env(env), 0)

    def test_main_with_env_returns_failure(self) -> None:
        self.assertEqual(
            get_fvm_flutter_version.main_with_env({"FVM_CONFIG_PATH": "/does/not/exist"}),
            1,
        )

    def test_main_returns_failure_when_file_missing(self) -> None:
        self.assertEqual(get_fvm_flutter_version.main_with_env({}), 1)


if __name__ == "__main__":
    import unittest

    unittest.main()
