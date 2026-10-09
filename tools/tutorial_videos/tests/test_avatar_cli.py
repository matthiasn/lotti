"""Tests for the avatar-preview and avatar-overlay commands, and the in-place
overlay the build runs."""

from __future__ import annotations

import argparse
import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from avatar_helpers import write_wav

from tutorial_videos.avatar import AvatarError, cli
from tutorial_videos.avatar.characters import PIP, THEO


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


class _TempDirTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self._tmp.name)

    def tearDown(self):
        self._tmp.cleanup()


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

    def test_another_character_can_be_previewed_under_its_own_name(self):
        with mock.patch.object(
            cli, "render_preview", side_effect=lambda c, wav, out, **_: out
        ) as render:
            _, stdout = _run(
                ["avatar-preview", "--wav", "n.wav", "--character", "theo"]
            )

        self.assertIs(render.call_args.args[0], THEO)
        self.assertEqual(render.call_args.args[2], Path("/out/avatar/avatar_theo.mp4"))
        self.assertIn("avatar_theo.mp4", stdout)

    def test_an_unknown_character_is_refused(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            _run(["avatar-preview", "--wav", "n.wav", "--character", "walrus"])


class SidecarPathsTest(unittest.TestCase):
    def test_a_desktop_video_names_its_own_manifest_and_timeline(self):
        self.assertEqual(
            cli.sidecar_paths(Path("/b/intro_de.mp4")),
            (Path("/b/intro_de.manifest.json"), Path("/b/intro_de.timeline.json")),
        )

    def test_a_mobile_video_shares_the_desktop_manifest_but_not_the_timeline(self):
        self.assertEqual(
            cli.sidecar_paths(Path("/b/intro_de_mobile.mp4")),
            (
                Path("/b/intro_de.manifest.json"),
                Path("/b/intro_de_mobile.timeline.json"),
            ),
        )


class LevelsForTest(_TempDirTest):
    def _sidecars(self, stem: str = "intro_de") -> tuple[Path, Path, Path]:
        video = self.dir / f"{stem}.mp4"
        manifest = self.dir / "intro_de.manifest.json"
        timeline = self.dir / f"{stem}.timeline.json"
        manifest.write_text(json.dumps({"steps": []}))
        timeline.write_text(json.dumps({"total": 1, "steps": [], "waits": []}))
        return video, manifest, timeline

    def test_the_narrator_clips_are_used_when_the_build_files_are_beside_the_video(self):
        video, *_ = self._sidecars()
        with mock.patch.object(
            cli, "narration_levels", return_value=[0.5]
        ) as narration:
            self.assertEqual(cli.levels_for(video, fps=10), [0.5])
        narration.assert_called_once_with(
            {"steps": []}, {"total": 1, "steps": [], "waits": []}, 10
        )

    def test_a_mobile_video_finds_the_shared_manifest(self):
        video, *_ = self._sidecars("intro_de_mobile")
        with mock.patch.object(cli, "narration_levels", return_value=[0.5]):
            self.assertEqual(cli.levels_for(video, fps=10), [0.5])

    def test_explicit_build_files_are_read_from_where_they_are_named(self):
        video = self.dir / "clip.mp4"
        manifest = self.dir / "elsewhere.manifest.json"
        timeline = self.dir / "elsewhere.timeline.json"
        manifest.write_text(json.dumps({"steps": [1]}))
        timeline.write_text(json.dumps({"total": 2}))
        with mock.patch.object(cli, "narration_levels", return_value=[1.0]) as narration:
            levels = cli.levels_for(video, fps=10, manifest=manifest, timeline=timeline)
        self.assertEqual(levels, [1.0])
        narration.assert_called_once_with({"steps": [1]}, {"total": 2}, 10)

    def test_a_named_build_file_that_is_missing_is_an_error_not_a_fallback(self):
        video, manifest, _ = self._sidecars()
        write_wav(video.with_suffix(".narration.wav"), [0] * 10)
        with self.assertRaises(AvatarError) as raised:
            cli.levels_for(
                video, fps=10, manifest=manifest, timeline=self.dir / "nope.json"
            )
        self.assertIn("nope.json", str(raised.exception))

    def test_without_build_files_the_narration_mix_beside_the_video_is_used(self):
        video = self.dir / "old_build.mp4"
        # 100 Hz, 1 fps: one frame at RMS 0.5.
        write_wav(video.with_suffix(".narration.wav"), [16384] * 100)
        self.assertEqual(cli.levels_for(video, fps=1), [0.5])

    def test_a_wav_given_explicitly_wins_over_the_build_files(self):
        video, *_ = self._sidecars()
        wav = write_wav(self.dir / "other.wav", [16384] * 100)
        with mock.patch.object(cli, "narration_levels") as narration:
            self.assertEqual(cli.levels_for(video, fps=1, narration=wav), [0.5])
        narration.assert_not_called()

    def test_nothing_to_sync_to_is_an_error_naming_what_was_looked_for(self):
        with self.assertRaises(AvatarError) as raised:
            cli.levels_for(self.dir / "lonely.mp4", fps=10)
        message = str(raised.exception)
        for name in ("lonely.manifest.json", "lonely.timeline.json", "lonely.narration.wav"):
            self.assertIn(name, message)


class AvatarOverlayTest(unittest.TestCase):
    def test_defaults_sync_to_the_build_files_and_sit_top_right(self):
        with mock.patch.object(
            cli, "levels_for", return_value=[0.5]
        ) as levels, mock.patch.object(cli, "render_overlay") as render:
            code, stdout = _run(["avatar-overlay", "--video", "/b/intro_de.mp4"])

        self.assertEqual(code, 0)
        levels.assert_called_once_with(
            Path("/b/intro_de.mp4"), fps=30, manifest=None, timeline=None, narration=None
        )
        render.assert_called_once_with(
            PIP,
            Path("/b/intro_de.mp4"),
            [0.5],
            Path("/b/intro_de_avatar.mp4"),
            work_dir=Path("/b/avatar_work/intro_de"),
            fps=30,
            position="top_right",
        )
        self.assertIn("OK: /b/intro_de_avatar.mp4", stdout)

    def test_sources_output_corner_and_fps_can_be_chosen(self):
        with mock.patch.object(
            cli, "levels_for", return_value=[]
        ) as levels, mock.patch.object(cli, "render_overlay") as render:
            _run(
                [
                    "avatar-overlay",
                    "--video",
                    "/b/v.mp4",
                    "--manifest",
                    "/m.json",
                    "--timeline",
                    "/t.json",
                    "--narration",
                    "/n.wav",
                    "--out",
                    "/o/final.mp4",
                    "--position",
                    "bottom_left",
                    "--fps",
                    "24",
                ]
            )

        levels.assert_called_once_with(
            Path("/b/v.mp4"),
            fps=24,
            manifest=Path("/m.json"),
            timeline=Path("/t.json"),
            narration=Path("/n.wav"),
        )
        render.assert_called_once_with(
            PIP,
            Path("/b/v.mp4"),
            [],
            Path("/o/final.mp4"),
            work_dir=Path("/o/avatar_work/v"),
            fps=24,
            position="bottom_left",
        )

    def test_another_character_can_be_overlaid(self):
        with mock.patch.object(cli, "levels_for", return_value=[]), mock.patch.object(
            cli, "render_overlay"
        ) as render:
            _run(["avatar-overlay", "--video", "/b/v.mp4", "--character", "theo"])

        self.assertIs(render.call_args.args[0], THEO)

    def test_an_unknown_corner_is_refused(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            _run(["avatar-overlay", "--video", "v.mp4", "--position", "middle"])


class OverlayInPlaceTest(_TempDirTest):
    def test_replaces_the_video_with_the_overlaid_one(self):
        video = self.dir / "scene_en.mp4"
        video.write_bytes(b"plain")

        def fake_render(character, source, levels, out, **kwargs):
            out.write_bytes(b"with pip")
            return out

        with mock.patch.object(
            cli, "narration_levels", return_value=[0.1]
        ) as levels, mock.patch.object(
            cli, "render_overlay", side_effect=fake_render
        ) as render:
            result = cli.overlay_in_place(
                video,
                manifest={"steps": []},
                timeline={"total": 1},
                position="top_right",
                work_dir=self.dir / "w",
            )

        self.assertEqual(result, video)
        self.assertEqual(video.read_bytes(), b"with pip")
        self.assertEqual([p.name for p in self.dir.iterdir()], ["scene_en.mp4"])
        levels.assert_called_once_with({"steps": []}, {"total": 1}, 30)
        render.assert_called_once_with(
            PIP,
            video,
            [0.1],
            self.dir / "scene_en.avatar_tmp.mp4",
            work_dir=self.dir / "w",
            fps=30,
            position="top_right",
        )

    def test_a_failed_render_leaves_the_video_untouched(self):
        video = self.dir / "scene_en.mp4"
        video.write_bytes(b"plain")
        with mock.patch.object(cli, "narration_levels", return_value=[]), mock.patch.object(
            cli, "render_overlay", side_effect=AvatarError("ffmpeg failed")
        ), self.assertRaises(AvatarError):
            cli.overlay_in_place(
                video,
                manifest={"steps": []},
                timeline={"total": 1},
                position="top_right",
                work_dir=self.dir / "w",
            )
        self.assertEqual(video.read_bytes(), b"plain")

    def test_lays_in_the_named_character(self):
        video = self.dir / "scene_en.mp4"
        video.write_bytes(b"plain")

        def fake_render(character, source, levels, out, **kwargs):
            out.write_bytes(character.name.encode())
            return out

        with mock.patch.object(cli, "narration_levels", return_value=[]), mock.patch.object(
            cli, "render_overlay", side_effect=fake_render
        ):
            cli.overlay_in_place(
                video,
                manifest={"steps": []},
                timeline={"total": 1},
                position="top_right",
                work_dir=self.dir / "w",
                character="theo",
            )
        self.assertEqual(video.read_bytes(), b"theo")


if __name__ == "__main__":
    unittest.main()
