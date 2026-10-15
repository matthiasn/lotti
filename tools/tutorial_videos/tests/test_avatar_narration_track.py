"""Tests for the narrator-only loudness track placed through the time warp."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from avatar_helpers import write_wav

from tutorial_videos.avatar.narration_track import narration_levels
from tutorial_videos.timewarp import output_time, plan_segments

# 100 Hz audio at 10 fps: ten samples per frame, so a level is easy to read.
RATE, FPS = 100, 10
HALF, QUARTER = 16384, 8192  # RMS 0.5 and 0.25 of full scale


def _timeline(total: float, steps, waits=(), dictations=()) -> dict:
    return {
        "total": total,
        "zero_epoch_ms": 0,
        "steps": [
            {"id": sid, "start": start, "end": end} for sid, start, end in steps
        ],
        "waits": [{"start": start, "end": end} for start, end in waits],
        "dictations": [{"start": start, "end": end} for start, end in dictations],
    }


class NarrationLevelsTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self._tmp.name)

    def tearDown(self):
        self._tmp.cleanup()

    def _clip(self, name: str, seconds: float, amplitude: int = HALF) -> Path:
        return write_wav(
            self.dir / f"{name}.wav", [amplitude] * int(seconds * RATE), rate=RATE
        )

    def _manifest(self, **clips: tuple[Path, float]) -> dict:
        return {
            "steps": [
                {"id": sid, "narration": {"clip": str(path), "duration": duration}}
                for sid, (path, duration) in clips.items()
            ]
        }

    def test_each_clip_lands_at_its_steps_start_and_the_track_spans_the_total(self):
        manifest = self._manifest(
            intro=(self._clip("intro", 0.5), 0.5), outro=(self._clip("outro", 0.5), 0.5)
        )
        timeline = _timeline(3.0, [("intro", 0, 1.5), ("outro", 1.5, 3.0)])

        levels = narration_levels(manifest, timeline, FPS)

        self.assertEqual(len(levels), 30)
        self.assertEqual(levels[0:5], [0.5] * 5)
        self.assertEqual(levels[5:15], [0.0] * 10)
        self.assertEqual(levels[15:20], [0.5] * 5)
        self.assertEqual(levels[20:], [0.0] * 10)

    def test_a_clip_after_a_fast_forwarded_wait_lands_on_the_warped_clock(self):
        # A 20s wait inside a 30s step gets sped up, so the second step's
        # clip must start where compose.py places its audio — well before
        # the raw 30s mark.
        manifest = self._manifest(
            waiting=(self._clip("waiting", 3.0), 3.0), done=(self._clip("done", 1.0), 1.0)
        )
        timeline = _timeline(
            40, [("waiting", 0, 30), ("done", 30, 40)], waits=[(2, 28)]
        )
        segments = plan_segments(timeline, {"waiting": 3.0, "done": 1.0})
        warped_start = round(output_time(segments, 30.0) * FPS)

        levels = narration_levels(manifest, timeline, FPS)

        self.assertLess(warped_start, 300)
        self.assertEqual(levels[warped_start - 1], 0.0)
        self.assertEqual(levels[warped_start : warped_start + 10], [0.5] * 10)

    def test_the_dictation_clip_is_never_read(self):
        manifest = self._manifest(say=(self._clip("say", 0.2), 0.2))
        manifest["steps"][0]["dictation"] = {"clip": str(self.dir / "missing.wav")}
        timeline = _timeline(2.0, [("say", 0, 2.0)], dictations=[(0.5, 1.5)])

        levels = narration_levels(manifest, timeline, FPS)

        # Opening the dictation clip would raise; its span stays quiet.
        self.assertEqual(levels[5:15], [0.0] * 10)

    def test_overlapping_clips_keep_the_louder_frame(self):
        quiet_then_loud = self._manifest(
            a=(self._clip("a", 0.5, QUARTER), 0.5), b=(self._clip("b", 0.3, HALF), 0.3)
        )
        timeline = _timeline(1.0, [("a", 0, 0.2), ("b", 0.2, 1.0)])

        levels = narration_levels(quiet_then_loud, timeline, FPS)

        self.assertEqual(levels[0:2], [0.25, 0.25])
        self.assertEqual(levels[2:5], [0.5, 0.5, 0.5])

        loud_then_quiet = self._manifest(
            a=(self._clip("a", 0.5, HALF), 0.5), b=(self._clip("b", 0.3, QUARTER), 0.3)
        )
        levels = narration_levels(loud_then_quiet, timeline, FPS)
        self.assertEqual(levels[2:5], [0.5, 0.5, 0.5])

    def test_a_step_without_a_clip_in_the_manifest_contributes_nothing(self):
        manifest = self._manifest(intro=(self._clip("intro", 0.2), 0.2))
        timeline = _timeline(1.0, [("intro", 0, 0.5), ("extra", 0.5, 1.0)])

        levels = narration_levels(manifest, timeline, FPS)

        self.assertEqual(len(levels), 10)
        self.assertEqual(levels[5:], [0.0] * 5)

    def test_a_clip_running_past_the_total_extends_the_track(self):
        manifest = self._manifest(intro=(self._clip("intro", 0.5), 0.5))
        timeline = _timeline(0.3, [("intro", 0, 0.3)])

        levels = narration_levels(manifest, timeline, FPS)

        self.assertEqual(levels, [0.5] * 5)


if __name__ == "__main__":
    unittest.main()
