"""Tests for WebVTT caption generation."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

TOOL_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL_ROOT))

from tutorial_videos.captions import build_vtt  # noqa: E402
from tutorial_videos.scenario import Scenario, Step  # noqa: E402


def _scenario(steps: dict[str, str]) -> Scenario:
    return Scenario(
        name="sample",
        title={"en": "Sample"},
        dictionary={"en": ["Sample"]},
        steps=[
            Step(id=step_id, min_duration=1.0, narration={"en": text})
            for step_id, text in steps.items()
        ],
    )


def _manifest(durations: dict[str, float]) -> dict:
    return {
        "steps": [
            {"id": step_id, "narration": {"duration": duration}}
            for step_id, duration in durations.items()
        ]
    }


def _timeline(total: float, steps, waits=()):
    return {
        "total": total,
        "steps": [
            {"id": sid, "start": start, "end": end} for sid, start, end in steps
        ],
        "waits": [{"start": start, "end": end} for start, end in waits],
    }


class CaptionsTest(unittest.TestCase):
    def test_one_cue_per_step_at_narration_duration(self):
        scenario = _scenario({"intro": "Hello there", "outro": "Goodbye"})
        manifest = _manifest({"intro": 4.0, "outro": 2.5})
        timeline = _timeline(10, [("intro", 0, 6), ("outro", 6, 10)])

        vtt = build_vtt(
            scenario=scenario, locale="en", timeline=timeline, manifest=manifest
        )

        self.assertTrue(vtt.startswith("WEBVTT\n\n"))
        self.assertIn("00:00:00.000 --> 00:00:04.000\nHello there", vtt)
        self.assertIn("00:00:06.000 --> 00:00:08.500\nGoodbye", vtt)

    def test_cue_timing_follows_the_warped_output_clock_not_raw_input(self):
        # A 20s wait inside a 30s step, 3s narration: gets fast-forwarded, so
        # the second step's cue must start well before its raw 30s timestamp.
        scenario = _scenario({"wait_step": "We are working on it", "done": "Done"})
        manifest = _manifest({"wait_step": 3.0, "done": 1.0})
        timeline = _timeline(
            40,
            [("wait_step", 0, 30), ("done", 30, 40)],
            waits=[(2, 28)],
        )

        vtt = build_vtt(
            scenario=scenario, locale="en", timeline=timeline, manifest=manifest
        )
        lines = [line for line in vtt.splitlines() if "-->" in line]
        second_cue_start = lines[1].split(" --> ")[0]
        # Raw input timestamp would be 00:00:30.000; the warped clock must be
        # earlier because the wait was compressed.
        self.assertLess(second_cue_start, "00:00:30.000")

    def test_multi_word_narration_is_normalized_to_one_line(self):
        scenario = _scenario({"intro": "Line one\nand   line two"})
        manifest = _manifest({"intro": 2.0})
        timeline = _timeline(5, [("intro", 0, 5)])

        vtt = build_vtt(
            scenario=scenario, locale="en", timeline=timeline, manifest=manifest
        )

        self.assertIn("Line one and line two", vtt)
        self.assertNotIn("\nand", vtt)

    def test_locale_selects_the_matching_narration_text(self):
        scenario = Scenario(
            name="sample",
            title={"en": "Sample", "de": "Beispiel"},
            dictionary={"en": ["Sample"], "de": ["Beispiel"]},
            steps=[
                Step(
                    id="intro",
                    min_duration=1.0,
                    narration={"en": "Hello", "de": "Hallo"},
                ),
            ],
        )
        manifest = _manifest({"intro": 1.5})
        timeline = _timeline(3, [("intro", 0, 3)])

        vtt = build_vtt(
            scenario=scenario, locale="de", timeline=timeline, manifest=manifest
        )

        self.assertIn("Hallo", vtt)
        self.assertNotIn("Hello", vtt)


if __name__ == "__main__":
    unittest.main()
