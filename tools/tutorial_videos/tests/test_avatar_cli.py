"""Tests for the avatar-preview and avatar-overlay commands."""

from __future__ import annotations

import argparse
import contextlib
import io
import unittest
from pathlib import Path
from unittest import mock

import avatar_helpers  # noqa: F401  (puts the tool on sys.path)

from tutorial_videos.avatar import cli
from tutorial_videos.avatar.characters import PIP


def _run(argv: list[str]) -> tuple[int, str]:
    parser = argparse.ArgumentParser()
    cli.register(
        parser.add_subparsers(dest="command", required=True), default_out=Path("/out")
    )
    args = parser.parse_args(argv)
    stdout = io.StringIO()
    with contextlib.redirect_stdout(stdout):
        code = args.handler(args)
    return code, stdout.getvalue()


class AvatarPreviewTest(unittest.TestCase):
    def test_defaults_to_a_480px_30fps_preview_in_the_build_folder(self):
        with mock.patch.object(
            cli, "render_preview", side_effect=lambda c, wav, out, **_: out
        ) as render:
            code, stdout = _run(["avatar-preview", "--wav", "n.wav"])

        self.assertEqual(code, 0)
        render.assert_called_once_with(
            PIP,
            Path("n.wav"),
            Path("/out/avatar/avatar_pip.mp4"),
            size=480,
            work_dir=Path("/out/avatar/work"),
            fps=30,
        )
        self.assertIn("OK: /out/avatar/avatar_pip.mp4", stdout)

    def test_size_fps_and_folder_can_be_chosen(self):
        with mock.patch.object(cli, "render_preview") as render:
            _run(
                [
                    "avatar-preview",
                    "--wav",
                    "n.wav",
                    "--size",
                    "240",
                    "--fps",
                    "25",
                    "--out-dir",
                    "/tmp/x",
                ]
            )

        render.assert_called_once_with(
            PIP,
            Path("n.wav"),
            Path("/tmp/x/avatar_pip.mp4"),
            size=240,
            work_dir=Path("/tmp/x/work"),
            fps=25,
        )

    def test_a_wav_is_required(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            _run(["avatar-preview"])


class AvatarOverlayTest(unittest.TestCase):
    def test_defaults_read_the_narration_mix_beside_the_video(self):
        with mock.patch.object(cli, "render_overlay") as render:
            code, stdout = _run(["avatar-overlay", "--video", "/b/intro_de.mp4"])

        self.assertEqual(code, 0)
        render.assert_called_once_with(
            PIP,
            Path("/b/intro_de.mp4"),
            Path("/b/intro_de.narration.wav"),
            Path("/b/intro_de_avatar.mp4"),
            work_dir=Path("/b/avatar_work/intro_de"),
            fps=30,
        )
        self.assertIn("OK: /b/intro_de_avatar.mp4", stdout)

    def test_explicit_narration_and_output_are_used(self):
        with mock.patch.object(cli, "render_overlay") as render:
            _run(
                [
                    "avatar-overlay",
                    "--video",
                    "/b/v.mp4",
                    "--narration",
                    "/n.wav",
                    "--out",
                    "/o/final.mp4",
                    "--fps",
                    "24",
                ]
            )

        render.assert_called_once_with(
            PIP,
            Path("/b/v.mp4"),
            Path("/n.wav"),
            Path("/o/final.mp4"),
            work_dir=Path("/o/avatar_work/v"),
            fps=24,
        )


if __name__ == "__main__":
    unittest.main()
