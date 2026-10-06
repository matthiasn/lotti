"""Tests for the workbench CLI entry point."""

from __future__ import annotations

import contextlib
import io
import unittest
from pathlib import Path
from unittest import mock

import avatar_helpers  # noqa: F401  (puts the tool on sys.path)

from tutorial_videos import __main__ as entry
from tutorial_videos.avatar import AvatarError
from tutorial_videos.avatar import cli as avatar_cli


class AvatarCommandsTest(unittest.TestCase):
    def test_avatar_commands_need_no_scenario(self):
        with mock.patch.object(
            avatar_cli, "render_preview", return_value=Path("o.mp4")
        ) as render, contextlib.redirect_stdout(io.StringIO()):
            code = entry.main(
                ["avatar-preview", "--wav", "n.wav", "--character", "pip"]
            )

        self.assertEqual(code, 0)
        render.assert_called_once()

    def test_avatar_previews_default_into_the_build_folder(self):
        with mock.patch.object(
            avatar_cli, "render_preview", return_value=Path("o.mp4")
        ) as render, contextlib.redirect_stdout(io.StringIO()):
            entry.main(["avatar-preview", "--wav", "n.wav", "--character", "pip"])

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


if __name__ == "__main__":
    unittest.main()
