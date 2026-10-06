"""Tests for blink timing, pose tracks and run-length collapsing."""

from __future__ import annotations

import unittest

import avatar_helpers  # noqa: F401  (puts the tool on sys.path)

from tutorial_videos.avatar.characters import Pose
from tutorial_videos.avatar.track import (
    blink_track,
    pad_track,
    pose_track,
    run_lengths,
)


def _blink_starts(closed: list[bool]) -> list[int]:
    return [
        index
        for index, shut in enumerate(closed)
        if shut and (index == 0 or not closed[index - 1])
    ]


class BlinkTrackTest(unittest.TestCase):
    def test_no_frames_no_blinks(self):
        self.assertEqual(blink_track(0, 30), [])

    def test_a_clip_shorter_than_the_first_interval_never_blinks(self):
        self.assertEqual(blink_track(10, 30, interval=(1.0, 1.0)), [False] * 10)

    def test_the_same_seed_blinks_at_the_same_frames(self):
        self.assertEqual(blink_track(900, 30, seed=3), blink_track(900, 30, seed=3))

    def test_a_different_seed_blinks_at_different_frames(self):
        self.assertNotEqual(blink_track(900, 30, seed=3), blink_track(900, 30, seed=4))

    def test_blinks_are_spaced_within_the_interval(self):
        closed = blink_track(3000, 30, interval=(2.5, 5.5))
        starts = _blink_starts(closed)
        self.assertGreater(len(starts), 5)
        gaps = [later - earlier for earlier, later in zip(starts, starts[1:])]
        # Whole frames, so a gap can land one frame either side of the bound.
        self.assertTrue(all(2.5 * 30 - 1 <= gap <= 5.5 * 30 + 1 for gap in gaps), gaps)

    def test_each_blink_lasts_its_duration_in_frames(self):
        closed = blink_track(200, 30, interval=(2.0, 2.0), blink_seconds=0.12)
        self.assertEqual(closed[60:64], [True] * 4)
        self.assertEqual(closed[59], False)
        self.assertEqual(closed[64], False)

    def test_a_very_short_blink_still_closes_the_eyes_for_one_frame(self):
        closed = blink_track(40, 10, interval=(2.0, 2.0), blink_seconds=0.001)
        self.assertEqual(closed.count(True), 1)

    def test_a_blink_running_past_the_end_is_cut_off(self):
        closed = blink_track(12, 10, interval=(1.0, 1.0), blink_seconds=0.5)
        self.assertEqual(closed, [False] * 10 + [True, True])


class PadTrackTest(unittest.TestCase):
    def test_pads_a_short_track_with_a_closed_mouth(self):
        self.assertEqual(pad_track([2, 3], 4), [2, 3, 0, 0])

    def test_leaves_a_long_enough_track_alone(self):
        self.assertEqual(pad_track([2, 3, 1], 2), [2, 3, 1])

    def test_does_not_modify_the_input(self):
        mouths = [1]
        pad_track(mouths, 3)
        self.assertEqual(mouths, [1])


class PoseTrackTest(unittest.TestCase):
    def test_pairs_each_mouth_with_its_frame_eye_state(self):
        self.assertEqual(
            pose_track([0, 2], [False, True]), [Pose(0, False), Pose(2, True)]
        )

    def test_rejects_tracks_of_different_lengths(self):
        with self.assertRaises(ValueError):
            pose_track([0, 1], [False])


class RunLengthsTest(unittest.TestCase):
    def test_no_poses_no_runs(self):
        self.assertEqual(run_lengths([]), [])

    def test_collapses_consecutive_equal_poses(self):
        a, b = Pose(0, False), Pose(3, False)
        self.assertEqual(run_lengths([a, a, a, b, b]), [(a, 3), (b, 2)])

    def test_keeps_a_pose_that_comes_back_as_a_new_run(self):
        a, b = Pose(0, False), Pose(0, True)
        self.assertEqual(run_lengths([a, b, a]), [(a, 1), (b, 1), (a, 1)])


if __name__ == "__main__":
    unittest.main()
