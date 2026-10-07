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
        with mock.patch.object(avatar_cli, "levels_for", return_value=[]), mock.patch.object(
            avatar_cli, "render_overlay", side_effect=AvatarError("ffmpeg failed")
        ), contextlib.redirect_stderr(stderr):
            code = entry.main(["avatar-overlay", "--video", "v.mp4"])

        self.assertEqual(code, 2)
        self.assertIn("ERROR: ffmpeg failed", stderr.getvalue())


class BuildCommandTest(unittest.TestCase):
    """``build`` with the recording, composition and captions stubbed out:
    what it does around them, and what ``--avatar`` adds."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.out = Path(self._tmp.name)
        self.timeline = {
            "total": 1.0,
            "zero_epoch_ms": 0,
            "steps": [],
            "waits": [],
            "dictations": [],
        }
        (self.out / "category_setup_en.timeline.json").write_text(
            json.dumps(self.timeline)
        )

    def tearDown(self):
        self._tmp.cleanup()

    def _build(self, *extra: str, drive_code: int = 0) -> tuple[int, dict]:
        def fake_compose(**kwargs):
            kwargs["output"].write_bytes(b"mp4")
            return kwargs["output"]

        argv = ["build", "--scenario", "category_setup", "--locale", "en"]
        with mock.patch.object(
            entry, "create_engine", return_value=FakeEngine()
        ), mock.patch.object(entry, "_read_env_pairs", return_value={}), mock.patch.object(
            entry, "XvfbDisplay"
        ), mock.patch.object(entry, "VirtualMic"), mock.patch.object(
            entry, "ScreenCapture"
        ) as capture, mock.patch.object(
            entry.subprocess, "run", return_value=mock.Mock(returncode=drive_code)
        ), mock.patch.object(
            entry, "compose_video", side_effect=fake_compose
        ) as compose, mock.patch.object(
            entry, "build_vtt", return_value="WEBVTT\n"
        ), mock.patch.object(entry, "overlay_in_place") as overlay, contextlib.redirect_stdout(
            io.StringIO()
        ), contextlib.redirect_stderr(io.StringIO()):
            capture.return_value.__enter__.return_value.start_epoch_ms = 0
            code = entry.main([*argv, "--out-dir", str(self.out), *extra])
        return code, {"compose": compose, "overlay": overlay}

    def test_without_the_flag_the_video_is_composed_captioned_and_left_alone(self):
        code, calls = self._build()

        self.assertEqual(code, 0)
        calls["compose"].assert_called_once()
        self.assertTrue((self.out / "category_setup_en.vtt").is_file())
        calls["overlay"].assert_not_called()

    def test_avatar_lays_pip_into_the_finished_video_top_right(self):
        code, calls = self._build("--avatar")

        self.assertEqual(code, 0)
        calls["overlay"].assert_called_once()
        video = calls["overlay"].call_args.args[0]
        kwargs = calls["overlay"].call_args.kwargs
        self.assertEqual(video, self.out / "category_setup_en.mp4")
        self.assertEqual(kwargs["position"], "top_right")
        self.assertEqual(kwargs["timeline"], self.timeline)
        self.assertTrue(kwargs["manifest"]["steps"])
        self.assertEqual(kwargs["work_dir"], self.out / "avatar_work" / "category_setup_en")

    def test_the_avatars_corner_can_be_chosen(self):
        _, calls = self._build("--avatar", "--avatar-position", "bottom_left")
        self.assertEqual(calls["overlay"].call_args.kwargs["position"], "bottom_left")

    def test_a_mobile_build_overlays_its_own_suffixed_video(self):
        (self.out / "category_setup_en_mobile.timeline.json").write_text(
            json.dumps(self.timeline)
        )
        _, calls = self._build("--avatar", "--device", "mobile")
        self.assertEqual(
            calls["overlay"].call_args.args[0], self.out / "category_setup_en_mobile.mp4"
        )

    def test_a_failed_drive_stops_before_composing(self):
        code, calls = self._build("--avatar", drive_code=1)

        self.assertEqual(code, 1)
        calls["compose"].assert_not_called()
        calls["overlay"].assert_not_called()


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
