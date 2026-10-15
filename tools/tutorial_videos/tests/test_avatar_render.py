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
from tutorial_videos.avatar.acting import Motion, act
from tutorial_videos.avatar.characters import PIP, THEO, Pose
from tutorial_videos.avatar.lipsync import frame_levels
from tutorial_videos.avatar.render import (
    POSITIONS,
    BadgeTrack,
    badge_size,
    build_track,
    overlay_command,
    pose_image_name,
    preview_command,
    probe_video,
    render_layers,
    render_overlay,
    render_pose_images,
    render_preview,
    run_ffmpeg,
    head_canvas,
    write_commands,
    write_concat,
)

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

    def _levels(self, seconds: float = 1.0, fps: int = 10) -> list[float]:
        """The per-frame loudness of ``_speech``: loud, then silent."""
        return frame_levels(self._speech(seconds), fps)


class PoseImagesTest(_TempDirTest):
    def test_the_name_spells_out_mouth_eyes_gaze_and_brows(self):
        self.assertEqual(
            pose_image_name(PIP, Pose(2, True)), "pip_mouth2_eyes_closed.png"
        )
        self.assertEqual(
            pose_image_name(PIP, Pose(0, False)), "pip_mouth0_eyes_open0.png"
        )
        self.assertEqual(
            pose_image_name(THEO, Pose(1, False, 3, True)),
            "theo_mouth1_eyes_open3_brows.png",
        )

    def test_writes_one_face_png_per_distinct_pose(self):
        a, b = Pose(0, False), Pose(3, True)

        images = render_pose_images(PIP, [a, b, a, a], 20, self.dir / "poses")

        self.assertEqual(list(images), [a, b])
        self.assertEqual(
            sorted(p.name for p in (self.dir / "poses").iterdir()),
            sorted(path.name for path in images.values()),
        )
        width, height, rgba = decode_png(images[b].read_bytes())
        self.assertEqual((width, height), (30, 30))  # the head canvas
        # Only the face: the corners are see-through.
        self.assertEqual(pixel(rgba, 30, 0, 0)[3], 0)


class LayersTest(_TempDirTest):
    def setUp(self):
        super().setUp()
        self.layers = render_layers(THEO, 40, self.dir / "l")

    def _png(self, name: str, size: int = 40) -> bytes:
        width, height, rgba = decode_png(self.layers[name].read_bytes())
        self.assertEqual((width, height), (size, size))
        return rgba

    def test_writes_the_five_still_layers(self):
        self.assertEqual(
            sorted(self.layers), ["background", "body", "head", "mask", "ring"]
        )
        for path in self.layers.values():
            self.assertTrue(path.is_file(), path)

    def test_the_background_fills_the_square(self):
        rgba = self._png("background")
        self.assertEqual(pixel(rgba, 40, 0, 0), (*THEO.background[:3], 255))

    def test_the_mask_is_a_white_disc_on_black(self):
        rgba = self._png("mask")
        self.assertEqual(pixel(rgba, 40, 0, 0), (0, 0, 0, 255))
        self.assertEqual(pixel(rgba, 40, 20, 20), (255, 255, 255, 255))

    def test_the_head_is_drawn_around_its_pivot_on_a_larger_canvas(self):
        # 1.5 times the badge, so the hair above a low pivot is not cut off.
        rgba = self._png("head", head_canvas(40))
        # Theo's neck pivot sits just inside his chin: the canvas centre is
        # skin, and every edge of the canvas is clear.
        self.assertEqual(pixel(rgba, 60, 30, 29)[3], 255)
        for x, y in ((30, 0), (0, 30), (59, 30), (30, 59)):
            self.assertEqual(pixel(rgba, 60, x, y)[3], 0, (x, y))


class WriteCommandsTest(_TempDirTest):
    def test_moves_every_layer_in_supersampled_pixels_and_skips_repeats(self):
        still = Motion(0.1, (0.0, 0.0), (0.0, 0.0), 0.0)
        moved = Motion(0.1, (0.1, 0.0), (0.2, 0.05), 0.05)
        path = self.dir / "c.cmd"

        write_commands([still, still, moved], 10, 100, (5, 7), path)

        lines = path.read_text().splitlines()
        self.assertEqual(len(lines), 2)  # the repeated frame says nothing
        self.assertEqual(
            lines[0],
            "0.0000 rotate@head a 0.10000, rotate@face a 0.10000, overlay@body y 0, "
            "overlay@head x 5, overlay@head y 7, overlay@face x 5, overlay@face y 7;",
        )
        self.assertEqual(
            lines[1],
            "0.2000 overlay@body y 5, overlay@head x 15, overlay@face x 25, "
            "overlay@face y 12;",
        )


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
    def _track(self, **kwargs) -> BadgeTrack:
        return build_track(
            PIP, self._levels(1.0), fps=10, size=8, work_dir=self.dir / "w", **kwargs
        )

    def test_the_track_lasts_as_long_as_the_narration(self):
        track = self._track()

        self.assertEqual(track.faces, self.dir / "w" / "pip.ffconcat")
        self.assertAlmostEqual(sum(_concat_durations(track.faces)), 1.0)

    def test_the_mouth_moves_while_speaking_and_rests_after(self):
        files = [
            line
            for line in self._track().faces.read_text().splitlines()
            if line.startswith("file")
        ]
        self.assertTrue(any("mouth3" in f for f in files[:3]))
        self.assertIn("mouth0", files[-1])

    def test_min_frames_keeps_the_avatar_idling_past_the_narration(self):
        track = self._track(min_frames=30)
        self.assertAlmostEqual(sum(_concat_durations(track.faces)), 3.0)
        last = track.commands.read_text().splitlines()[-1]
        self.assertLess(float(last.split()[0]), 3.0)

    def test_every_file_exists_and_layers_are_drawn_at_twice_the_size(self):
        track = self._track()
        for path in (track.background, track.body, track.ring, track.mask):
            self.assertEqual(decode_png(path.read_bytes())[:2], (16, 16), path)
        self.assertEqual(decode_png(track.head.read_bytes())[:2], (24, 24))
        for line in track.faces.read_text().splitlines():
            if line.startswith("file"):
                self.assertTrue((track.faces.parent / line.split("'")[1]).is_file())
        self.assertTrue(track.commands.is_file())
        self.assertEqual(track.size, 8)

    def test_the_layers_sit_where_the_pivot_puts_them(self):
        # Pip's pivot is (0.5, 0.72) of 16px, i.e. (8, 12); the 24px head
        # canvas is centred on it.
        self.assertEqual(self._track().origin, (-4, 0))

    def test_an_empty_narration_is_an_error(self):
        with self.assertRaises(AvatarError):
            build_track(PIP, [], fps=10, size=8, work_dir=self.dir / "w")


class BadgeSizeTest(unittest.TestCase):
    def test_is_the_height_fraction_rounded_down_to_even(self):
        self.assertEqual(badge_size(1080), 236)
        self.assertEqual(badge_size(1748), 384)
        self.assertEqual(badge_size(100, fraction=0.5), 50)

    def test_never_shrinks_below_two_pixels(self):
        self.assertEqual(badge_size(1), 2)


TRACK = BadgeTrack(
    background=Path("bg.png"),
    body=Path("body.png"),
    head=Path("head.png"),
    faces=Path("faces.ffconcat"),
    commands=Path("/w/pip.cmd"),
    ring=Path("ring.png"),
    mask=Path("mask.png"),
    size=40,
    origin=(0, 18),
)


class CommandsTest(unittest.TestCase):
    def _graph(self, command: list[str]) -> str:
        return command[command.index("-filter_complex") + 1]

    def test_the_badge_is_composited_from_its_layers_and_moved_by_commands(self):
        graph = self._graph(
            overlay_command(
                video=Path("v.mp4"), track=TRACK, out=Path("o.mp4"), fps=30, margin=6
            )
        )
        self.assertIn("sendcmd=f='/w/pip.cmd'", graph)
        self.assertIn("rotate@head=", graph)
        self.assertIn("rotate@face=", graph)
        self.assertIn("overlay@head=x=0:y=18", graph)
        self.assertIn("alphamerge", graph)
        self.assertIn("scale=40:40:flags=area[badge]", graph)

    def test_every_layer_is_an_input_after_the_video(self):
        command = overlay_command(
            video=Path("v.mp4"), track=TRACK, out=Path("o.mp4"), fps=30, margin=6
        )
        inputs = [command[i + 1] for i, a in enumerate(command) if a == "-i"]
        self.assertEqual(
            inputs,
            ["v.mp4", "bg.png", "body.png", "head.png", "faces.ffconcat",
             "ring.png", "mask.png"],
        )  # fmt: skip

    def test_a_windows_style_command_path_is_escaped_for_the_filtergraph(self):
        track = BadgeTrack(**{**TRACK.__dict__, "commands": Path("C:/w/pip.cmd")})
        graph = self._graph(
            overlay_command(
                video=Path("v.mp4"), track=track, out=Path("o.mp4"), fps=30, margin=6
            )
        )
        self.assertIn("sendcmd=f='C\\:/w/pip.cmd'", graph)

    def test_the_preview_centers_the_badge_and_plays_the_narration(self):
        command = preview_command(
            track=TRACK, narration=Path("n.wav"), out=Path("o.mp4"), fps=25, canvas=64
        )
        self.assertEqual(command[0], "ffmpeg")
        self.assertIn("color=c=0xF4F1EA:s=64x64:r=25", command)
        self.assertIn("overlay=(W-w)/2:(H-h)/2:shortest=1", self._graph(command))
        self.assertEqual(
            command[command.index("-map", command.index("[v]")) + 1], "7:a"
        )
        self.assertEqual(command[-1], "o.mp4")

    def test_the_overlay_slides_in_top_right_by_default_and_keeps_the_audio(self):
        command = overlay_command(
            video=Path("v.mp4"), track=TRACK, out=Path("o.mp4"), fps=30, margin=12
        )
        self.assertIn(
            "overlay='W-w-12+(52)*pow(1-min(1,max(0,(t-0.3)/0.6)),3):12'"
            ":eval=frame:shortest=1",
            self._graph(command),
        )
        self.assertIn("0:a?", command)
        self.assertEqual(command[command.index("-c:a") + 1], "copy")

    def test_every_corner_places_the_badge_a_margin_in_from_its_edges(self):
        expected = {
            "top_right": "overlay='W-w-12+",
            "top_left": "overlay='12-",
            "bottom_right": "overlay='W-w-12+",
            "bottom_left": "overlay='12-",
        }
        rows = {"top_right": ":12'", "top_left": ":12'", "bottom_right": ":H-h-12'",
                "bottom_left": ":H-h-12'"}  # fmt: skip
        self.assertEqual(sorted(expected), sorted(POSITIONS))
        for position, placement in expected.items():
            with self.subTest(position=position):
                graph = self._graph(
                    overlay_command(
                        video=Path("v.mp4"),
                        track=TRACK,
                        out=Path("o.mp4"),
                        fps=30,
                        margin=12,
                        position=position,
                    )
                )
                self.assertIn(placement, graph)
                self.assertIn(rows[position], graph)

    def test_an_unknown_corner_is_refused(self):
        with self.assertRaises(AvatarError) as raised:
            overlay_command(
                video=Path("v.mp4"),
                track=TRACK,
                out=Path("o.mp4"),
                fps=30,
                margin=12,
                position="centre",
            )
        self.assertIn("centre", str(raised.exception))


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
                self._levels(1.0),
                out,
                work_dir=self.dir / "w",
                fps=10,
            )

        self.assertEqual(result, out)
        concat = self.dir / "w" / "pip.ffconcat"
        # Narration is 1s; the video is 2s, so the badge idles for the rest
        # and one frame beyond — the overlay then ends with the video.
        self.assertAlmostEqual(sum(_concat_durations(concat)), 2.1)
        image = self.dir / "w" / "pip_background.png"
        # 22% of 100px, even, drawn at twice that.
        self.assertEqual(decode_png(image.read_bytes())[:2], (44, 44))
        command = run.call_args.args[0]
        graph = command[command.index("-filter_complex") + 1]
        # Top right by default, 15% of the 22px badge in from the edges.
        self.assertIn("overlay='W-w-3+(25)*", graph)
        self.assertIn("scale=22:22:", graph)
        self.assertEqual(command[-1], str(out))

    def test_the_corner_is_passed_through(self):
        with mock.patch.object(
            render, "probe_video", return_value=(1920, 100, 2.0)
        ), mock.patch.object(render, "run_ffmpeg") as run:
            render_overlay(
                PIP,
                Path("tutorial.mp4"),
                self._levels(1.0),
                self.dir / "o.mp4",
                work_dir=self.dir / "w",
                fps=10,
                position="bottom_left",
            )
        command = run.call_args.args[0]
        graph = command[command.index("-filter_complex") + 1]
        self.assertIn("overlay='3-(25)*", graph)
        self.assertIn(":H-h-3'", graph)


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
            frame_levels(self._speech(0.5, rate=8000), 10),
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
            frame_levels(self._speech(3.0, rate=8000), 10),
            self.dir / "o.mp4",
            work_dir=self.dir / "w",
            fps=10,
        )
        self.assertEqual(self._video_stream(out)["nb_frames"], "10")

    def test_the_badge_acts_between_frames_even_while_silent(self):
        """The sendcmd motion reaches the picture: with no speech at all the
        badge still breathes and turns to watch the app."""
        source = self.dir / "wide.mp4"
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-f", "lavfi",
             "-i", "color=c=gray:s=480x270:r=10", "-t", "3",
             "-c:v", "libx264", "-pix_fmt", "yuv420p", str(source)],
            check=True,
        )  # fmt: skip
        silence = [0.0] * 30
        out = render_overlay(
            THEO, source, silence, self.dir / "o.mp4", work_dir=self.dir / "w", fps=10
        )
        # Two frames with the very same face image: only motion can tell
        # them apart.
        poses, _ = act(silence, 10, 31)
        self.assertEqual(poses[10], poses[24])
        crops = []
        for frame in (10, 24):  # both after the slide-in
            crops.append(
                subprocess.run(
                    ["ffmpeg", "-loglevel", "error", "-i", str(out),
                     "-vf", f"select=eq(n\\,{frame}),crop=58:58:413:8",
                     "-frames:v", "1", "-f", "rawvideo", "-pix_fmt", "gray", "-"],
                    capture_output=True,
                    check=True,
                ).stdout
            )  # fmt: skip
        # Encoding noise alone stays far below one grey level on average.
        difference = sum(abs(a - b) for a, b in zip(*crops)) / len(crops[0])
        self.assertGreater(difference, 0.5)


if __name__ == "__main__":
    unittest.main()
