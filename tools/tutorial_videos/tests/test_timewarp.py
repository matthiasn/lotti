"""Tests for the pure time-warp planning (fast-forwarded wait footage)."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

TOOL_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL_ROOT))

from tutorial_videos.timewarp import (  # noqa: E402
    LEAD_IN_SECONDS,
    output_time,
    plan_segments,
    total_output,
)


def _timeline(total: float, steps, waits):
    return {
        "total": total,
        "steps": [
            {"id": sid, "start": start, "end": end} for sid, start, end in steps
        ],
        "waits": [{"start": start, "end": end} for start, end in waits],
    }


class TimewarpTest(unittest.TestCase):
    def test_no_waits_is_single_realtime_segment(self):
        timeline = _timeline(30, [("a", 0, 30)], [])
        segments = plan_segments(timeline, {"a": 5})
        self.assertEqual(len(segments), 1)
        self.assertEqual(segments[0].speed, 1.0)
        self.assertEqual(total_output(segments), 30)
        self.assertEqual(output_time(segments, 17.5), 17.5)

    def test_long_wait_compresses_up_to_max_speed(self):
        # 60s wait inside a 70s step with 6s narration: plenty of slack.
        timeline = _timeline(
        	80, [("a", 0, 5), ("b", 5, 75), ("c", 75, 80)], [(8, 68)]
        )
        segments = plan_segments(timeline, {"a": 3, "b": 6, "c": 3})
        fast = [s for s in segments if s.speed > 1]
        self.assertEqual(len(fast), 1)
        self.assertEqual(fast[0].speed, 8.0)
        self.assertAlmostEqual(fast[0].start, 8 + LEAD_IN_SECONDS)
        # Total shrinks by the saved time.
        saved = fast[0].input_duration - fast[0].output_duration
        self.assertAlmostEqual(total_output(segments), 80 - saved, places=2)

    def test_speed_clamped_so_narration_still_fits(self):
        # Step b: 20s long, wait covers 2..19 (17s), narration is 14s.
        # Full 8x would leave ~5s of step output < narration -> clamp.
        timeline = _timeline(25, [("b", 0, 20), ("c", 20, 25)], [(2, 19)])
        segments = plan_segments(timeline, {"b": 14, "c": 3})
        fast = next(s for s in segments if s.speed > 1)
        step_output = output_time(segments, 20) - output_time(segments, 0)
        self.assertGreaterEqual(step_output, 14 + 0.5 - 0.01)
        self.assertLess(fast.speed, 8.0)

    def test_short_waits_are_ignored(self):
        timeline = _timeline(20, [("a", 0, 20)], [(5, 6.2)])
        segments = plan_segments(timeline, {"a": 4})
        self.assertTrue(all(s.speed == 1.0 for s in segments))

    def test_output_time_is_monotonic_and_piecewise(self):
        timeline = _timeline(40, [("a", 0, 40)], [(10, 30)])
        segments = plan_segments(timeline, {"a": 4})
        times = [output_time(segments, t) for t in range(41)]
        self.assertEqual(times, sorted(times))
        # Before the warp: identity. After: earlier than input time.
        self.assertEqual(output_time(segments, 10), 10)
        self.assertLess(output_time(segments, 30), 30)
        self.assertAlmostEqual(
            output_time(segments, 40), total_output(segments), places=3
        )


if __name__ == "__main__":
    unittest.main()
