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
from tutorial_videos.avatar.characters import CHARACTERS


def _run(argv: list[str]) -> tuple[int, str, argparse.Namespace]:
    parser = argparse.ArgumentParser()
    cli.register(
        parser.add_subparsers(dest="command", required=True), default_out=Path("/out")
    )
    args = parser.parse_args(argv)
    stdout = io.StringIO()
    with contextlib.redirect_stdout(stdout):
        code = args.handler(args)
    return code, stdout.getvalue(), args


class AvatarPreviewTest(unittest.TestCase):
    def test_renders_every_character_by_default(self):
        with mock.patch.object(
            cli, "render_preview", side_effect=lambda c, wav, out, **_: out
        ) as render:
            code, stdout, _ = _run(["avatar-preview", "--wav", "n.wav"])

        self.assertEqual(code, 0)
        self.assertEqual(
            [call.args[0].name for call in render.call_args_list], list(CHARACTERS)
        )
        for name in CHARACTERS:
            self.assertIn(f"OK: /out/avatar/avatar_{name}.mp4", stdout)

    def test_renders_one_character_with_its_own_paths_and_settings(self):
        with mock.patch.object(cli, "render_preview") as render:
            _run(
                [
                    "avatar-preview",
                    "--wav",
                    "n.wav",
                    "--character",
                    "bolt",
                    "--size",
                    "240",
                    "--fps",
                    "25",
                    "--out-dir",
                    "/tmp/x",
                ]
            )

        render.assert_called_once_with(
            CHARACTERS["bolt"],
            Path("n.wav"),
            Path("/tmp/x/avatar_bolt.mp4"),
            size=240,
            work_dir=Path("/tmp/x/work/bolt"),
            fps=25,
        )

    def test_defaults_to_a_480px_30fps_preview(self):
        with mock.patch.object(cli, "render_preview") as render:
            _run(["avatar-preview", "--wav", "n.wav", "--character", "pip"])
        self.assertEqual(render.call_args.kwargs["size"], 480)
        self.assertEqual(render.call_args.kwargs["fps"], 30)

    def test_an_unknown_character_is_refused(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            _run(["avatar-preview", "--wav", "n.wav", "--character", "dragon"])


class AvatarOverlayTest(unittest.TestCase):
    def test_defaults_read_the_narration_mix_beside_the_video(self):
        with mock.patch.object(cli, "render_overlay") as render:
            code, stdout, _ = _run(["avatar-overlay", "--video", "/b/intro_de.mp4"])

        self.assertEqual(code, 0)
        render.assert_called_once_with(
            CHARACTERS["pip"],
            Path("/b/intro_de.mp4"),
            Path("/b/intro_de.narration.wav"),
            Path("/b/intro_de_avatar.mp4"),
            work_dir=Path("/b/avatar_work/intro_de_pip"),
            fps=30,
        )
        self.assertIn("OK: /b/intro_de_avatar.mp4", stdout)

    def test_explicit_narration_output_and_character_are_used(self):
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
                    "--character",
                    "mochi",
                    "--fps",
                    "24",
                ]
            )

        render.assert_called_once_with(
            CHARACTERS["mochi"],
            Path("/b/v.mp4"),
            Path("/n.wav"),
            Path("/o/final.mp4"),
            work_dir=Path("/o/avatar_work/v_mochi"),
            fps=24,
        )


if __name__ == "__main__":
    unittest.main()
