"""Tests for rendering the avatar into preview and overlay videos."""

from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from avatar_helpers import decode_png, pixel, write_wav

from tutorial_videos.avatar import AvatarError
from tutorial_videos.avatar import render
from tutorial_videos.avatar.characters import Pose, get_character
from tutorial_videos.avatar.render import (
    badge_size,
    build_track,
    overlay_command,
    pose_image_name,
    preview_command,
    probe_video,
    render_overlay,
    render_pose_images,
    render_preview,
    run_ffmpeg,
    write_concat,
)

PIP = get_character("pip")
HAS_FFMPEG = bool(shutil.which("ffmpeg") and shutil.which("ffprobe"))


def _concat_durations(path: Path) -> list[float]:
    return [
        float(line.split()[1])
        for line in path.read_text().splitlines()
        if line.startswith("duration ")
    ]


class _TempDirTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self._tmp.name)

    def tearDown(self):
        self._tmp.cleanup()

    def _speech(self, seconds: float = 1.0, rate: int = 1000) -> Path:
        """Loud for the first half, silent for the second."""
        half = int(seconds * rate / 2)
        return write_wav(
            self.dir / "speech.wav",
            [12000, -12000] * (half // 2) + [0] * half,
            rate=rate,
        )


class PoseImagesTest(_TempDirTest):
    def test_the_name_spells_out_mouth_and_eyes(self):
        self.assertEqual(
            pose_image_name(PIP, Pose(2, True)), "pip_mouth2_eyes_closed.png"
        )
        self.assertEqual(
            pose_image_name(PIP, Pose(0, False)), "pip_mouth0_eyes_open.png"
        )

    def test_writes_one_round_badge_png_per_distinct_pose(self):
        a, b = Pose(0, False), Pose(3, True)

        images = render_pose_images(PIP, [a, b, a, a], 20, self.dir / "poses")

        self.assertEqual(list(images), [a, b])
        self.assertEqual(
            sorted(p.name for p in (self.dir / "poses").iterdir()),
            sorted(path.name for path in images.values()),
        )
        width, height, rgba = decode_png(images[b].read_bytes())
        self.assertEqual((width, height), (20, 20))
        self.assertEqual(pixel(rgba, 20, 0, 0)[3], 0)
        self.assertEqual(pixel(rgba, 20, 10, 10)[3], 255)


class WriteConcatTest(_TempDirTest):
    def test_an_empty_track_is_an_error(self):
        with self.assertRaises(AvatarError):
            write_concat([], {}, 30, self.dir / "x.ffconcat")

    def test_lists_each_run_with_its_duration_and_repeats_the_last_file(self):
        a, b = Pose(0, False), Pose(1, False)
        images = {a: self.dir / "a.png", b: self.dir / "b.png"}
        path = self.dir / "track.ffconcat"

        write_concat([(a, 3), (b, 5)], images, 10, path)

        self.assertEqual(
            path.read_text(),
            "ffconcat version 1.0\n"
            "file 'a.png'\nduration 0.300000\n"
            "file 'b.png'\nduration 0.500000\n"
            "file 'b.png'\n",
        )


class BuildTrackTest(_TempDirTest):
    def test_the_track_lasts_as_long_as_the_narration(self):
        concat = build_track(
            PIP, self._speech(1.0), fps=10, size=8, work_dir=self.dir / "w"
        )

        self.assertEqual(concat, self.dir / "w" / "pip.ffconcat")
        self.assertAlmostEqual(sum(_concat_durations(concat)), 1.0)

    def test_the_mouth_moves_while_speaking_and_rests_after(self):
        concat = build_track(
            PIP, self._speech(1.0), fps=10, size=8, work_dir=self.dir / "w"
        )

        files = [
            line for line in concat.read_text().splitlines() if line.startswith("file")
        ]
        self.assertIn("mouth3", files[0])
        self.assertIn("mouth0", files[-1])

    def test_min_frames_keeps_the_avatar_idling_past_the_narration(self):
        concat = build_track(
            PIP,
            self._speech(1.0),
            fps=10,
            size=8,
            work_dir=self.dir / "w",
            min_frames=30,
        )
        self.assertAlmostEqual(sum(_concat_durations(concat)), 3.0)

    def test_every_listed_image_exists_next_to_the_list(self):
        concat = build_track(
            PIP, self._speech(1.0), fps=10, size=8, work_dir=self.dir / "w"
        )
        for line in concat.read_text().splitlines():
            if line.startswith("file"):
                self.assertTrue((concat.parent / line.split("'")[1]).is_file(), line)


class BadgeSizeTest(unittest.TestCase):
    def test_is_the_height_fraction_rounded_down_to_even(self):
        self.assertEqual(badge_size(1080), 236)
        self.assertEqual(badge_size(1748), 384)
        self.assertEqual(badge_size(100, fraction=0.5), 50)

    def test_never_shrinks_below_two_pixels(self):
        self.assertEqual(badge_size(1), 2)


class CommandsTest(unittest.TestCase):
    def test_the_preview_centers_the_badge_and_plays_the_narration(self):
        command = preview_command(
            concat=Path("t.ffconcat"),
            narration=Path("n.wav"),
            out=Path("o.mp4"),
            fps=25,
            canvas=64,
        )
        self.assertEqual(command[0], "ffmpeg")
        self.assertIn("color=c=0xF4F1EA:s=64x64:r=25", command)
        self.assertIn(
            "overlay=(W-w)/2:(H-h)/2:shortest=1",
            command[command.index("-filter_complex") + 1],
        )
        self.assertEqual(
            command[command.index("-map", command.index("[v]")) + 1], "2:a"
        )
        self.assertEqual(command[-1], "o.mp4")

    def test_the_overlay_sits_bottom_right_and_keeps_the_audio(self):
        command = overlay_command(
            video=Path("v.mp4"),
            concat=Path("t.ffconcat"),
            out=Path("o.mp4"),
            fps=30,
            margin=12,
        )
        graph = command[command.index("-filter_complex") + 1]
        self.assertIn("overlay=W-w-12:H-h-12:shortest=1", graph)
        self.assertIn("0:a?", command)
        self.assertEqual(command[command.index("-c:a") + 1], "copy")
        self.assertEqual(command[command.index("-i") + 1], "v.mp4")


class RunFfmpegTest(unittest.TestCase):
    def test_a_successful_run_returns_quietly(self):
        with mock.patch.object(
            subprocess, "run", return_value=mock.Mock(returncode=0)
        ) as run:
            run_ffmpeg(["ffmpeg", "-version"])
        run.assert_called_once()

    def test_a_failed_run_raises_with_ffmpegs_message(self):
        failed = mock.Mock(returncode=1, stderr="bad filter graph\n")
        with mock.patch.object(subprocess, "run", return_value=failed):
            with self.assertRaises(AvatarError) as raised:
                run_ffmpeg(["ffmpeg", "-bogus"])
        self.assertIn("bad filter graph", str(raised.exception))


class ProbeVideoTest(unittest.TestCase):
    def test_reads_size_and_duration(self):
        output = json.dumps(
            {
                "streams": [{"width": 804, "height": 1748}],
                "format": {"duration": "12.5"},
            }
        )
        with mock.patch.object(
            subprocess, "run", return_value=mock.Mock(returncode=0, stdout=output)
        ):
            self.assertEqual(probe_video(Path("v.mp4")), (804, 1748, 12.5))

    def test_a_failed_probe_raises(self):
        failed = mock.Mock(returncode=1, stderr="No such file")
        with mock.patch.object(subprocess, "run", return_value=failed):
            with self.assertRaises(AvatarError) as raised:
                probe_video(Path("missing.mp4"))
        self.assertIn("missing.mp4", str(raised.exception))


class RenderPreviewTest(_TempDirTest):
    def test_renders_the_track_and_runs_the_preview_command(self):
        out = self.dir / "out" / "pip.mp4"
        with mock.patch.object(render, "run_ffmpeg") as run:
            result = render_preview(
                PIP, self._speech(), out, size=16, work_dir=self.dir / "w", fps=10
            )

        self.assertEqual(result, out)
        self.assertTrue(out.parent.is_dir())
        command = run.call_args.args[0]
        self.assertIn("color=c=0xF4F1EA:s=16x16:r=10", command)
        self.assertEqual(command[-1], str(out))


class RenderOverlayTest(_TempDirTest):
    def test_sizes_the_badge_from_the_video_and_idles_to_its_end(self):
        out = self.dir / "out" / "tutorial_avatar.mp4"
        with mock.patch.object(
            render, "probe_video", return_value=(1920, 100, 2.0)
        ), mock.patch.object(render, "run_ffmpeg") as run:
            result = render_overlay(
                PIP,
                Path("tutorial.mp4"),
                self._speech(1.0),
                out,
                work_dir=self.dir / "w",
                fps=10,
            )

        self.assertEqual(result, out)
        concat = self.dir / "w" / "pip.ffconcat"
        # Narration is 1s; the video is 2s, so the badge idles for the rest
        # and one frame beyond — the overlay then ends with the video.
        self.assertAlmostEqual(sum(_concat_durations(concat)), 2.1)
        image = next((self.dir / "w").glob("*.png"))
        self.assertEqual(decode_png(image.read_bytes())[:2], (22, 22))
        command = run.call_args.args[0]
        # 15% of the 22px badge, rounded.
        self.assertIn(
            "overlay=W-w-3:H-h-3", command[command.index("-filter_complex") + 1]
        )
        self.assertEqual(command[-1], str(out))


@unittest.skipUnless(HAS_FFMPEG, "ffmpeg/ffprobe not installed")
class RealFfmpegTest(_TempDirTest):
    """End to end through the real ffmpeg: the commands produce playable video."""

    def _streams(self, path: Path) -> list[dict]:
        result = subprocess.run(
            [
                "ffprobe",
                "-v",
                "error",
                "-show_entries",
                "stream=codec_type,width,height",
                "-of",
                "json",
                str(path),
            ],
            capture_output=True,
            text=True,
            check=True,
        )
        return json.loads(result.stdout)["streams"]

    def test_the_preview_is_a_video_with_the_narration_audio(self):
        out = render_preview(
            PIP,
            self._speech(0.6, rate=8000),
            self.dir / "p.mp4",
            size=32,
            work_dir=self.dir / "w",
            fps=10,
        )
        streams = self._streams(out)
        video = next(s for s in streams if s["codec_type"] == "video")
        self.assertEqual((video["width"], video["height"]), (32, 32))
        self.assertIn("audio", [s["codec_type"] for s in streams])

    def _tutorial(self) -> Path:
        """A 1s, 10-frame 128x72 stand-in for a built tutorial, with audio.

        ``-t`` rather than ``-shortest``: the latter against an endless
        ``anullsrc`` gives a different audio length from run to run."""
        source = self.dir / "tutorial.mp4"
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-loglevel",
                "error",
                "-f",
                "lavfi",
                "-i",
                "color=c=gray:s=128x72:r=10",
                "-f",
                "lavfi",
                "-i",
                "anullsrc=r=8000:cl=mono",
                "-t",
                "1",
                "-c:v",
                "libx264",
                "-pix_fmt",
                "yuv420p",
                str(source),
            ],
            check=True,
        )
        return source

    def _video_stream(self, path: Path) -> dict:
        result = subprocess.run(
            [
                "ffprobe",
                "-v",
                "error",
                "-select_streams",
                "v:0",
                "-show_entries",
                "stream=width,height,nb_frames",
                "-of",
                "json",
                str(path),
            ],
            capture_output=True,
            text=True,
            check=True,
        )
        return json.loads(result.stdout)["streams"][0]

    def test_the_overlay_keeps_the_videos_size_frames_and_audio(self):
        out = render_overlay(
            PIP,
            self._tutorial(),
            self._speech(0.5, rate=8000),
            self.dir / "o.mp4",
            work_dir=self.dir / "w",
            fps=10,
        )
        video = self._video_stream(out)
        self.assertEqual((video["width"], video["height"]), (128, 72))
        self.assertEqual(video["nb_frames"], "10")
        self.assertIn("audio", [s["codec_type"] for s in self._streams(out)])

    def test_a_narration_longer_than_the_video_never_stretches_it(self):
        out = render_overlay(
            PIP,
            self._tutorial(),
            self._speech(3.0, rate=8000),
            self.dir / "o.mp4",
            work_dir=self.dir / "w",
            fps=10,
        )
        self.assertEqual(self._video_stream(out)["nb_frames"], "10")


if __name__ == "__main__":
    unittest.main()
