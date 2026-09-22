"""Tests for the App Store preview's narration: pacing, cut, placement and
the rendered track."""

from __future__ import annotations

import contextlib
import io
import json
import re
import struct
import sys
import tempfile
import unittest
import wave
from pathlib import Path

TOOL_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = TOOL_ROOT.parents[1]
sys.path.insert(0, str(TOOL_ROOT))

from tutorial_videos.app_preview import (  # noqa: E402
    POST_NARRATION_PAD,
    Cut,
    Placement,
    PreviewError,
    beat_floors,
    main,
    pacing_define,
    place_narration,
    plan_cut,
    render_track,
)
from tutorial_videos.scenario import load_scenario  # noqa: E402

RATE = 24_000
RECORDER_START = 1_700_000_000_000


def _write_wav(
    path: Path, seconds: float, *, value: int = 1000, rate: int = RATE, channels: int = 1
) -> Path:
    frames = round(seconds * rate)
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(channels)
        wav.setsampwidth(2)
        wav.setframerate(rate)
        wav.writeframes(struct.pack("<h", value) * frames * channels)
    return path


def _samples(path: Path) -> tuple[int, list[int]]:
    with wave.open(str(path), "rb") as wav:
        data = wav.readframes(wav.getnframes())
        return wav.getframerate(), list(struct.unpack(f"<{len(data) // 2}h", data))


def _manifest(steps: list[tuple[str, float, float, str]]) -> dict:
    """(id, min_duration, narration seconds, clip path) per step."""
    return {
        "scenario": "app_store_preview",
        "locale": "en",
        "steps": [
            {
                "id": beat,
                "min_duration": floor,
                "narration": {"clip": clip, "duration": duration},
            }
            for beat, floor, duration, clip in steps
        ],
    }


def _timeline(cut: tuple[float, float], beats: list[tuple[str, float, float]]) -> dict:
    """Seconds after RECORDER_START, as the walk's epoch milliseconds."""

    def epoch(seconds: float) -> int:
        return RECORDER_START + round(seconds * 1000)

    return {
        "cut": {"start_epoch_ms": epoch(cut[0]), "end_epoch_ms": epoch(cut[1])},
        "beats": [
            {"id": beat, "start_epoch_ms": epoch(start), "end_epoch_ms": epoch(end)}
            for beat, start, end in beats
        ],
    }


class PacingTest(unittest.TestCase):
    def test_floor_is_the_longer_of_choreography_and_line_plus_pad(self):
        floors = beat_floors(
            _manifest([("short", 4.5, 2.0, "a.wav"), ("long", 4.5, 5.0, "b.wav")])
        )
        self.assertEqual(floors["short"], 4.5)
        self.assertAlmostEqual(floors["long"], 5.0 + POST_NARRATION_PAD)

    def test_define_lists_every_beat_in_order_as_milliseconds(self):
        define = pacing_define(
            _manifest([("tasks", 4.5, 3.2, "a.wav"), ("task", 6.1, 6.0, "b.wav")])
        )
        self.assertEqual(define, "tasks=4500,task=6600")

    def test_narration_that_overruns_thirty_seconds_fails_before_the_build(self):
        manifest = _manifest(
            [("tasks", 4.5, 12.0, "a.wav"), ("habits", 4.5, 18.0, "b.wav")]
        )
        with self.assertRaises(PreviewError) as ctx:
            pacing_define(manifest)
        message = str(ctx.exception)
        self.assertIn("31.2s", message)
        self.assertIn("'habits'", message)


class CutTest(unittest.TestCase):
    def test_cut_is_measured_from_the_recorders_first_frame(self):
        cut = plan_cut(_timeline((1.25, 22.75), []), RECORDER_START)
        self.assertEqual(cut, Cut(start=1.25, length=21.5))
        self.assertAlmostEqual(cut.end, 22.75)

    def test_cut_before_the_recording_started_is_refused(self):
        with self.assertRaises(PreviewError):
            plan_cut(_timeline((-0.5, 20.0), []), RECORDER_START)

    def test_cut_that_ends_before_it_starts_is_refused(self):
        with self.assertRaises(PreviewError):
            plan_cut(_timeline((5.0, 5.0), []), RECORDER_START)


class PlacementTest(unittest.TestCase):
    MANIFEST = _manifest(
        [("tasks", 4.5, 3.0, "tasks.wav"), ("task", 6.1, 5.0, "task.wav")]
    )

    def test_each_line_starts_where_its_beat_began(self):
        placements = place_narration(
            self.MANIFEST,
            _timeline((1.0, 12.0), [("task", 5.5, 11.6), ("tasks", 1.0, 5.5)]),
            RECORDER_START,
        )
        self.assertEqual(
            placements,
            [
                Placement(beat="tasks", clip=Path("tasks.wav"), start=1.0, duration=3.0),
                Placement(beat="task", clip=Path("task.wav"), start=5.5, duration=5.0),
            ],
        )

    def test_beats_that_differ_from_the_narration_are_refused(self):
        with self.assertRaises(PreviewError) as ctx:
            place_narration(
                self.MANIFEST,
                _timeline((1.0, 12.0), [("tasks", 1.0, 5.5), ("habits", 5.5, 11.6)]),
                RECORDER_START,
            )
        self.assertIn("app_store_preview.yaml", str(ctx.exception))

    def test_a_line_that_runs_into_the_next_beat_is_refused(self):
        # An unpaced walk: 'tasks' lasted 2 s, its line lasts 3 s.
        with self.assertRaises(PreviewError) as ctx:
            place_narration(
                self.MANIFEST,
                _timeline((1.0, 12.0), [("tasks", 1.0, 3.0), ("task", 3.0, 11.0)]),
                RECORDER_START,
            )
        self.assertIn("'tasks' line runs 1.00s into 'task'", str(ctx.exception))

    def test_a_line_that_starts_before_the_cut_is_refused(self):
        with self.assertRaises(PreviewError):
            place_narration(
                self.MANIFEST,
                _timeline((2.0, 12.0), [("tasks", 1.0, 5.5), ("task", 5.5, 11.6)]),
                RECORDER_START,
            )

    def test_a_line_that_outlasts_the_cut_is_refused(self):
        with self.assertRaises(PreviewError) as ctx:
            place_narration(
                self.MANIFEST,
                _timeline((1.0, 9.0), [("tasks", 1.0, 5.5), ("task", 5.5, 9.0)]),
                RECORDER_START,
            )
        self.assertIn("past the end of the cut", str(ctx.exception))


class RenderTrackTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.tmp = Path(self._tmp.name)

    def test_clips_land_on_their_sample_with_silence_between(self):
        first = _write_wav(self.tmp / "a.wav", 0.5, value=1000)
        second = _write_wav(self.tmp / "b.wav", 0.25, value=-2000)
        out = render_track(
            [
                Placement(beat="a", clip=first, start=1.0, duration=0.5),
                Placement(beat="b", clip=second, start=2.0, duration=0.25),
            ],
            length=3.0,
            out=self.tmp / "track.wav",
        )
        rate, samples = _samples(out)
        self.assertEqual(rate, RATE)
        self.assertEqual(len(samples), 3 * RATE)
        self.assertEqual(samples[RATE - 1], 0)
        self.assertEqual(samples[RATE : RATE + RATE // 2], [1000] * (RATE // 2))
        self.assertEqual(samples[RATE + RATE // 2], 0)
        self.assertEqual(samples[2 * RATE : 2 * RATE + RATE // 4], [-2000] * (RATE // 4))
        self.assertEqual(set(samples[2 * RATE + RATE // 4 :]), {0})

    def test_track_grows_to_hold_a_clip_that_ends_past_length(self):
        clip = _write_wav(self.tmp / "a.wav", 1.0)
        out = render_track(
            [Placement(beat="a", clip=clip, start=0.5, duration=1.0)],
            length=1.0,
            out=self.tmp / "track.wav",
        )
        _, samples = _samples(out)
        self.assertEqual(len(samples), round(1.5 * RATE))
        self.assertEqual(samples[-1], 1000)

    def test_clips_at_different_sample_rates_are_refused(self):
        a = _write_wav(self.tmp / "a.wav", 0.1)
        b = _write_wav(self.tmp / "b.wav", 0.1, rate=48_000)
        with self.assertRaises(PreviewError):
            render_track(
                [
                    Placement(beat="a", clip=a, start=0.0, duration=0.1),
                    Placement(beat="b", clip=b, start=1.0, duration=0.1),
                ],
                length=2.0,
                out=self.tmp / "track.wav",
            )

    def test_stereo_clips_are_refused(self):
        clip = _write_wav(self.tmp / "a.wav", 0.1, channels=2)
        with self.assertRaises(PreviewError):
            render_track(
                [Placement(beat="a", clip=clip, start=0.0, duration=0.1)],
                length=1.0,
                out=self.tmp / "track.wav",
            )

    def test_nothing_to_place_is_refused(self):
        with self.assertRaises(PreviewError):
            render_track([], length=1.0, out=self.tmp / "track.wav")


class CliTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.tmp = Path(self._tmp.name)
        clip = _write_wav(self.tmp / "tasks.wav", 2.0)
        self.manifest = self.tmp / "manifest.json"
        self.manifest.write_text(json.dumps(_manifest([("tasks", 4.5, 2.0, str(clip))])))
        self.timeline = self.tmp / "timeline.json"
        self.timeline.write_text(
            json.dumps(_timeline((1.5, 21.5), [("tasks", 1.5, 21.5)]))
        )

    def _run(self, *argv: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = main(list(argv))
        return code, out.getvalue().strip(), err.getvalue().strip()

    def test_pacing_prints_the_define(self):
        self.assertEqual(
            self._run("pacing", "--manifest", str(self.manifest)),
            (0, "tasks=4500", ""),
        )

    def test_cut_prints_start_and_length(self):
        self.assertEqual(
            self._run(
                "cut",
                "--timeline", str(self.timeline),
                "--recorder-start", str(RECORDER_START),
            ),
            (0, "1.500 20.000", ""),
        )

    def test_narrate_writes_the_track_through_the_end_of_the_cut(self):
        track = self.tmp / "narration.wav"
        code, out, _ = self._run(
            "narrate",
            "--manifest", str(self.manifest),
            "--timeline", str(self.timeline),
            "--recorder-start", str(RECORDER_START),
            "--out", str(track),
        )
        self.assertEqual((code, out), (0, "1.500 20.000"))
        rate, samples = _samples(track)
        self.assertEqual(len(samples), round(21.5 * rate))
        self.assertEqual(samples[round(1.5 * rate)], 1000)

    def test_bad_input_exits_with_the_reason_on_stderr(self):
        self.timeline.write_text(json.dumps({"beats": []}))
        code, out, err = self._run(
            "cut",
            "--timeline", str(self.timeline),
            "--recorder-start", str(RECORDER_START),
        )
        self.assertEqual((code, out), (2, ""))
        self.assertIn("KeyError", err)


class RealScenarioTest(unittest.TestCase):
    """The narration script against the walk it narrates."""

    SCENARIO = TOOL_ROOT / "config" / "scenarios" / "app_store_preview.yaml"
    WALK = REPO_ROOT / "integration_test" / "store_preview_test.dart"

    def test_buildable_for_en_and_de(self):
        scenario = load_scenario(self.SCENARIO)
        scenario.validate_locale("en")
        scenario.validate_locale("de")
        self.assertIsNone(scenario.dictation_step)

    def test_steps_are_the_walks_beats_in_order(self):
        declared = re.search(
            r"const _beatIds = \[(.*?)\];", self.WALK.read_text(), re.DOTALL
        )
        self.assertIsNotNone(declared, "_beatIds not found in the walk")
        walk_beats = re.findall(r"'(\w+)'", declared.group(1))
        self.assertEqual(
            [step.id for step in load_scenario(self.SCENARIO).steps], walk_beats
        )


if __name__ == "__main__":
    unittest.main()
