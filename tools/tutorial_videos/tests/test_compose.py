"""Tests for the compose stage's capture-length guard."""

from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import avatar_helpers  # noqa: F401  (puts the tool on sys.path)

from tutorial_videos import compose
from tutorial_videos.compose import (
    ComposeError,
    check_capture_length,
    compose_video,
    probe_duration,
)


class CheckCaptureLengthTest(unittest.TestCase):
    def test_a_capture_matching_the_apps_run_passes(self):
        # 77.7s of head before timeline zero, then a 103.5s timeline.
        check_capture_length(capture_seconds=181.6, offset=77.7, timeline_total=103.5)

    def test_a_capture_that_ran_long_is_refused(self):
        # The real drift seen once: 234s of capture for 181s of app time.
        with self.assertRaises(ComposeError) as raised:
            check_capture_length(
                capture_seconds=234.1, offset=77.7, timeline_total=103.5
            )
        self.assertIn("rebuild", str(raised.exception))
        self.assertIn("+52.9s", str(raised.exception))

    def test_a_capture_that_ran_short_is_refused(self):
        with self.assertRaises(ComposeError):
            check_capture_length(capture_seconds=120.0, offset=77.7, timeline_total=103.5)

    def test_small_jitter_is_tolerated_on_a_short_run(self):
        # Under the 3s floor: container rounding and capture start-up.
        check_capture_length(capture_seconds=22.9, offset=2.0, timeline_total=18.0)

    def test_the_tolerance_scales_with_a_long_run(self):
        # 5% of 400s is 20s: 15s of drift on a long run still passes.
        check_capture_length(capture_seconds=415.0, offset=100.0, timeline_total=300.0)
        with self.assertRaises(ComposeError):
            check_capture_length(capture_seconds=425.0, offset=100.0, timeline_total=300.0)


class ProbeDurationTest(unittest.TestCase):
    def test_reads_the_duration(self):
        with mock.patch.object(
            subprocess, "run", return_value=mock.Mock(returncode=0, stdout="12.5\n")
        ):
            self.assertEqual(probe_duration(Path("c.mkv")), 12.5)

    def test_a_failed_probe_raises(self):
        with mock.patch.object(
            subprocess, "run", return_value=mock.Mock(returncode=1, stderr="nope")
        ), self.assertRaises(ComposeError):
            probe_duration(Path("missing.mkv"))


class ComposeVideoGuardTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self._tmp.name)
        self.timeline = self.dir / "t.timeline.json"
        self.timeline.write_text(
            json.dumps({"total": 10.0, "zero_epoch_ms": 5000, "steps": [], "waits": []})
        )

    def tearDown(self):
        self._tmp.cleanup()

    def test_a_drifted_capture_stops_before_any_rendering(self):
        with mock.patch.object(
            compose, "probe_duration", return_value=60.0
        ), mock.patch.object(compose, "_warp_capture") as warp, self.assertRaises(
            ComposeError
        ):
            compose_video(
                repo_root=self.dir,
                capture=self.dir / "c.mkv",
                capture_start_epoch_ms=0,
                timeline_path=self.timeline,
                manifest={"steps": []},
                output=self.dir / "o.mp4",
            )
        warp.assert_not_called()


if __name__ == "__main__":
    unittest.main()
