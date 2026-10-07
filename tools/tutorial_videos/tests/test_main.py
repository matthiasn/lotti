"""Tests for the workbench CLI entry point."""

from __future__ import annotations

import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import avatar_helpers  # noqa: F401  (puts the tool on sys.path)

from tutorial_videos import __main__ as entry
from tutorial_videos.avatar import AvatarError
from tutorial_videos.avatar import cli as avatar_cli
from tutorial_videos.tts.base import TtsError

from test_tts import FakeEngine


class AvatarCommandsTest(unittest.TestCase):
    def test_avatar_commands_need_no_scenario(self):
        with mock.patch.object(
            avatar_cli, "render_preview", return_value=Path("o.mp4")
        ) as render, contextlib.redirect_stdout(io.StringIO()):
            code = entry.main(["avatar-preview", "--wav", "n.wav"])

        self.assertEqual(code, 0)
        render.assert_called_once()

    def test_avatar_previews_default_into_the_build_folder(self):
        with mock.patch.object(
            avatar_cli, "render_preview", return_value=Path("o.mp4")
        ) as render, contextlib.redirect_stdout(io.StringIO()):
            entry.main(["avatar-preview", "--wav", "n.wav"])

        self.assertEqual(
            render.call_args.args[2], entry.DEFAULT_OUT / "avatar" / "avatar_pip.mp4"
        )

    def test_an_avatar_failure_is_reported_as_an_error_exit(self):
        stderr = io.StringIO()
        with mock.patch.object(
            avatar_cli, "render_overlay", side_effect=AvatarError("ffmpeg failed")
        ), contextlib.redirect_stderr(stderr):
            code = entry.main(["avatar-overlay", "--video", "v.mp4"])

        self.assertEqual(code, 2)
        self.assertIn("ERROR: ffmpeg failed", stderr.getvalue())


class TtsCommandTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.out = Path(self._tmp.name)

    def tearDown(self):
        self._tmp.cleanup()

    def _tts(self, *extra: str) -> tuple[int, FakeEngine, mock.Mock]:
        engine = FakeEngine()
        argv = ["tts", "--scenario", "category_setup", "--locale", "en"]
        with mock.patch.object(
            entry, "create_engine", return_value=engine
        ) as create, contextlib.redirect_stdout(io.StringIO()):
            code = entry.main([*argv, "--out-dir", str(self.out), *extra])
        return code, engine, create

    def test_uses_voices_yamls_default_engine(self):
        code, engine, create = self._tts()

        self.assertEqual(code, 0)
        name, model, env_path = create.call_args.args
        self.assertEqual(name, "gemini")
        self.assertEqual(env_path, entry.REPO_ROOT / ".env")
        # Gemini voices carry a spoken style instruction per locale.
        self.assertTrue(all(request["style"] for request in engine.requests))

    def test_tts_engine_switches_to_elevenlabs_voices(self):
        code, engine, create = self._tts("--tts-engine", "elevenlabs")

        self.assertEqual(code, 0)
        self.assertEqual(
            create.call_args.args[:2], ("elevenlabs", "eleven_multilingual_v2")
        )
        narrator = engine.requests[0]
        self.assertEqual(narrator["style"], "")
        self.assertIn("stability", narrator["settings"])
        manifest = json.loads(
            (self.out / "category_setup_en.manifest.json").read_text()
        )
        self.assertEqual(manifest["engine"], "fake")

    def test_a_tts_failure_is_reported_as_an_error_exit(self):
        stderr = io.StringIO()
        with mock.patch.object(
            entry, "create_engine", side_effect=TtsError("HTTP 401 bad key")
        ), contextlib.redirect_stderr(stderr):
            code = entry.main(["tts", "--scenario", "category_setup", "--locale", "en"])

        self.assertEqual(code, 2)
        self.assertIn("ERROR: HTTP 401 bad key", stderr.getvalue())

    def test_only_synthesizing_commands_take_an_engine(self):
        for command in ("validate", "publish"):
            with self.subTest(command=command), contextlib.redirect_stderr(
                io.StringIO()
            ), self.assertRaises(SystemExit):
                entry.main(
                    [
                        command,
                        "--scenario",
                        "category_setup",
                        "--locale",
                        "en",
                        "--tts-engine",
                        "elevenlabs",
                    ]
                )

    def test_an_unknown_engine_is_refused(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            self._tts("--tts-engine", "polly")


if __name__ == "__main__":
    unittest.main()
