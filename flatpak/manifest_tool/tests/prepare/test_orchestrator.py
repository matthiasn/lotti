import tarfile
import tempfile
import unittest
from pathlib import Path

import io
import shutil
import yaml
from contextlib import redirect_stdout

from flatpak.manifest_tool.prepare.orchestrator import (
    PrepareFlathubContext,
    PrepareFlathubOptions,
    _StatusPrinter,
    _assert_commit_pinned,
    _prepare_directories,
    _prepare_manifest_for_flatpak_flutter,
    _ensure_setup_helper_reference,
    _stage_package_config,
    _ensure_flutter_archive,
    _copy_assets_and_metadata,
    _remove_flutter_sdk_module,
    _stage_pubdev_archive,
    _cleanup,
    _print_summary,
)
from flatpak.manifest_tool.core.manifest import ManifestDocument


def _make_context(base: Path) -> PrepareFlathubContext:
    repo_root = base / "repo"
    flatpak_dir = base / "flatpak"
    work_dir = base / "work"
    output_dir = base / "work" / "output"
    for path in (repo_root, flatpak_dir, work_dir, output_dir):
        path.mkdir(parents=True, exist_ok=True)

    manifest_path = work_dir / "com.matthiasn.lotti.yml"
    manifest_path.write_text("modules: []\n", encoding="utf-8")

    options = PrepareFlathubOptions(
        repository_root=repo_root,
        flatpak_dir=flatpak_dir,
        work_dir=work_dir,
        output_dir=output_dir,
        clean_after_gen=True,
        pin_commit=True,
        use_nested_flutter=False,
        download_missing_sources=False,
        no_flatpak_flutter=True,
        extra_env={},
    )

    context = PrepareFlathubContext(
        options=options,
        repo_root=repo_root,
        flatpak_dir=flatpak_dir,
        script_dir=flatpak_dir,
        python_cli=flatpak_dir / "manifest_tool" / "cli.py",
        work_dir=work_dir,
        output_dir=output_dir,
        manifest_template=flatpak_dir / "com.matthiasn.lotti.source.yml",
        manifest_work=manifest_path,
        manifest_output=output_dir / "com.matthiasn.lotti.yml",
        env={},
        lotti_version="0.0.0",
        release_date="1970-01-01",
        current_branch="main",
        app_commit="deadbeef",
        flutter_tag="3.35.4",
        cached_flutter_dir=None,
        flatpak_flutter_repo=flatpak_dir / "flatpak-flutter",
        flatpak_flutter_log=work_dir / "flatpak-flutter.log",
        setup_helper_basename="setup-flutter.sh",
        setup_helper_source=flatpak_dir / "helpers" / "setup-flutter.sh",
        flatpak_flutter_status=None,
    )
    context.setup_helper_source.parent.mkdir(parents=True, exist_ok=True)
    context.setup_helper_source.write_text("#!/bin/bash\n", encoding="utf-8")
    return context


class PrepareOrchestratorTests(unittest.TestCase):
    def test_assert_commit_pinned_success(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            manifest = Path(tmp) / "manifest.yml"
            manifest.write_text("modules: []\n", encoding="utf-8")
            _assert_commit_pinned(manifest, "test")

    def test_assert_commit_pinned_failure(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            manifest = Path(tmp) / "manifest.yml"
            manifest.write_text("commit: COMMIT_PLACEHOLDER\n", encoding="utf-8")
            with self.assertRaises(Exception):
                _assert_commit_pinned(manifest, "test")

    def test_remove_flutter_sdk_module(self) -> None:
        manifest = ManifestDocument(
            path=Path("manifest.yml"),
            data={
                "modules": [
                    {"name": "flutter-sdk"},
                    {"name": "lotti"},
                ]
            },
        )
        changed = _remove_flutter_sdk_module(manifest)
        self.assertTrue(changed)
        self.assertEqual(manifest.data["modules"], [{"name": "lotti"}])

    def test_stage_pubdev_archive(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            context = _make_context(base)
            package_dir = (
                context.repo_root
                / ".pub-cache"
                / "hosted"
                / "pub.dev"
                / "example-1.0.0"
            )
            package_dir.mkdir(parents=True)
            (package_dir / "dummy.txt").write_text("hello", encoding="utf-8")

            printer = _StatusPrinter()
            _stage_pubdev_archive(context, printer, "example", "1.0.0")

            archive = context.flatpak_dir / "cache/pub.dev/example-1.0.0.tar.gz"
            self.assertTrue(archive.is_file())
            with tarfile.open(archive, "r:gz") as tar:
                names = tar.getnames()
            self.assertTrue(any(name.endswith("dummy.txt") for name in names))

    def test_prepare_directories(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            context = _make_context(Path(tmp))
            (context.work_dir / "stale.txt").write_text("old", encoding="utf-8")
            (context.work_dir / "sub").mkdir()
            printer = _StatusPrinter()
            _prepare_directories(context, printer)
            self.assertTrue(context.output_dir.exists())
            remaining = list(context.work_dir.iterdir())
            self.assertEqual(remaining, [context.output_dir])

    def test_prepare_manifest_for_flatpak_flutter(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            context = _make_context(base)
            context.manifest_template.parent.mkdir(parents=True, exist_ok=True)
            context.manifest_template.write_text(
                yaml.safe_dump(
                    {
                        "modules": [
                            {
                                "name": "flutter-sdk",
                                "sources": [
                                    {
                                        "type": "git",
                                        "url": "https://github.com/flutter/flutter.git",
                                        "tag": "3.35.4",
                                    }
                                ],
                            },
                            {
                                "name": "lotti",
                                "sources": [
                                    {
                                        "type": "git",
                                        "url": "https://github.com/matthiasn/lotti",
                                        "commit": "COMMIT_PLACEHOLDER",
                                    }
                                ],
                            },
                        ]
                    }
                ),
                encoding="utf-8",
            )
            printer = _StatusPrinter()
            _prepare_manifest_for_flatpak_flutter(context, printer)
            data = yaml.safe_load(context.manifest_work.read_text(encoding="utf-8"))
            lotti_sources = data["modules"][1]["sources"]
            self.assertIn("branch", lotti_sources[1])
            self.assertEqual(lotti_sources[1]["branch"], context.current_branch)
            flutter_entry = lotti_sources[0]
            self.assertEqual(flutter_entry.get("dest"), "flutter")

    def test_ensure_setup_helper_reference(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            context = _make_context(base)
            context.manifest_work.parent.mkdir(parents=True, exist_ok=True)
            context.manifest_work.write_text(
                yaml.safe_dump(
                    {
                        "modules": [
                            {
                                "name": "flutter-sdk",
                                "sources": [],
                            },
                            {
                                "name": "lotti",
                                "sources": [],
                            },
                        ]
                    }
                ),
                encoding="utf-8",
            )
            printer = _StatusPrinter()
            _ensure_setup_helper_reference(context, printer)
            data = yaml.safe_load(context.manifest_work.read_text(encoding="utf-8"))
            sources = data["modules"][0]["sources"]
            self.assertTrue(
                any(s.get("dest-filename") == "setup-flutter.sh" for s in sources)
            )

    def test_stage_package_config(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            context = _make_context(base)
            tools_dir = (
                context.work_dir
                / ".flatpak-builder"
                / "build"
                / "tool"
                / "flutter"
                / "packages"
                / "flutter_tools"
            )
            tools_dir.mkdir(parents=True, exist_ok=True)
            (tools_dir / "pubspec.lock").write_text("", encoding="utf-8")
            pkg_dir = tools_dir / ".dart_tool"
            pkg_dir.mkdir()
            (pkg_dir / "package_config.json").write_text("{}", encoding="utf-8")
            printer = _StatusPrinter()
            _stage_package_config(context, printer)
            self.assertTrue((context.output_dir / "package_config.json").is_file())

    def test_ensure_flutter_archive(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            context = _make_context(base)
            context.manifest_work.parent.mkdir(parents=True, exist_ok=True)
            manifest_data = {
                "modules": [
                    {
                        "name": "flutter-sdk",
                        "sources": [
                            {
                                "type": "git",
                                "url": "https://github.com/flutter/flutter",
                            }
                        ],
                    }
                ]
            }
            context.output_dir.mkdir(parents=True, exist_ok=True)
            context.output_dir.joinpath(context.manifest_work.name).write_text(
                yaml.safe_dump(manifest_data), encoding="utf-8"
            )
            archive = (
                context.output_dir
                / f"flutter_linux_{context.flutter_tag}-stable.tar.xz"
            )
            archive.write_bytes(b"dummy")
            document = ManifestDocument.load(
                context.output_dir / context.manifest_work.name
            )
            printer = _StatusPrinter()
            _ensure_flutter_archive(context, printer, document)
            document = ManifestDocument.load(
                context.output_dir / context.manifest_work.name
            )
            sources = document.data["modules"][0]["sources"]
            self.assertEqual(sources[0]["type"], "archive")

    def test_copy_helper_directories(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            context = _make_context(base)
            context.manifest_work.parent.mkdir(parents=True, exist_ok=True)
            outgoing_manifest = context.output_dir / context.manifest_work.name
            outgoing_manifest.parent.mkdir(parents=True, exist_ok=True)
            outgoing_manifest.write_text(
                yaml.safe_dump({"modules": []}), encoding="utf-8"
            )

            helper_root = context.work_dir / "sqlite3_flutter_libs"
            helper_root.mkdir(parents=True, exist_ok=True)
            (helper_root / "dummy.patch").write_text("patch", encoding="utf-8")
            cargokit_root = context.work_dir / "cargokit"
            cargokit_root.mkdir(parents=True, exist_ok=True)
            (cargokit_root / "Cargo.lock").write_text("", encoding="utf-8")

            printer = _StatusPrinter()
            _copy_assets_and_metadata(context, printer)

            self.assertTrue(
                (context.output_dir / "sqlite3_flutter_libs" / "dummy.patch").is_file()
            )
            self.assertTrue((context.output_dir / "cargokit" / "Cargo.lock").is_file())

    def test_cleanup_removes_builder(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            context = _make_context(base)
            builder_dir = context.work_dir / ".flatpak-builder"
            builder_dir.mkdir(parents=True, exist_ok=True)
            (builder_dir / "dummy").write_text("x", encoding="utf-8")
            printer = _StatusPrinter()
            _cleanup(context, printer)
            self.assertFalse(builder_dir.exists())

    def test_print_summary_outputs(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            context = _make_context(base)
            context.output_dir.mkdir(parents=True, exist_ok=True)
            (context.output_dir / "example.txt").write_text("", encoding="utf-8")
            printer = _StatusPrinter()
            buffer = io.StringIO()
            with redirect_stdout(buffer):
                _print_summary(context, printer)
            output = buffer.getvalue()
            self.assertIn("Preparation complete", output)
            self.assertIn("example.txt", output)


if __name__ == "__main__":
    unittest.main()
