"""Tests for the avatar's acting: phrases, stresses, glances and the per-frame
poses and motion they become."""

from __future__ import annotations

import unittest

import avatar_helpers  # noqa: F401  (puts the tool on sys.path)

from tutorial_videos.avatar import acting
from tutorial_videos.avatar.acting import Motion, Spring, act, onsets, phrases
from tutorial_videos.avatar.characters import GAZE_AT_APP
from tutorial_videos.avatar.lipsync import mouth_track

FPS = 10


def _speech(
    *spans: tuple[float, float], total: float, level: float = 0.5
) -> list[float]:
    """Loudness per frame: ``level`` inside each (start, end) second span, an
    alternating syllable pattern so there are stresses to find."""
    levels = [0.0] * round(total * FPS)
    for start, end in spans:
        for i in range(round(start * FPS), round(end * FPS)):
            levels[i] = level if (i // 2) % 2 == 0 else level * 0.2
    return levels


class SpringTest(unittest.TestCase):
    def test_settles_on_its_target(self):
        spring = Spring(0.0, 2.0, 0.8)
        for _ in range(200):
            value = spring.step(1.0, 0.05)
        self.assertAlmostEqual(value, 1.0, places=3)

    def test_an_underdamped_spring_overshoots(self):
        spring = Spring(0.0, 2.0, 0.4)
        self.assertGreater(max(spring.step(1.0, 0.02) for _ in range(100)), 1.0)


class PhrasesTest(unittest.TestCase):
    def test_silence_has_no_phrases(self):
        self.assertEqual(phrases([0.0] * 20, FPS), [])

    def test_a_short_pause_stays_inside_the_phrase(self):
        levels = [0.5, 0.5, 0.0, 0.0, 0.5, 0.5]
        self.assertEqual(phrases(levels, FPS), [(0, 5)])

    def test_a_long_pause_splits_phrases(self):
        levels = [0.5] * 3 + [0.0] * 8 + [0.5] * 2
        self.assertEqual(phrases(levels, FPS), [(0, 2), (11, 12)])


class OnsetsTest(unittest.TestCase):
    def test_silence_has_no_stresses(self):
        self.assertEqual(onsets([0.0] * 20, FPS), [])

    def test_a_jump_in_loudness_is_a_stress(self):
        levels = [0.0] * 5 + [0.8] * 5
        self.assertEqual(onsets(levels, FPS), [(5, 1.0)])

    def test_steady_speech_has_no_stresses_after_its_start(self):
        levels = [0.0] + [0.8] * 20
        self.assertEqual([frame for frame, _ in onsets(levels, FPS)], [1])

    def test_stresses_closer_than_the_spacing_keep_the_stronger(self):
        levels = [0.0, 0.5, 0.0, 0.0, 1.0] + [0.0] * 5
        found = onsets(levels, FPS)
        self.assertEqual([frame for frame, _ in found], [4])

    def test_a_close_weaker_stress_is_dropped(self):
        levels = [0.0, 1.0, 0.0, 0.0, 0.6] + [0.0] * 5
        self.assertEqual([frame for frame, _ in onsets(levels, FPS)], [1])


class GlancesTest(unittest.TestCase):
    def test_a_long_silence_between_phrases_is_watched(self):
        spans = acting._glances([(0, 9), (40, 49)], 50, FPS)
        self.assertEqual(spans, [(12, 36)])

    def test_a_short_silence_is_not(self):
        self.assertEqual(acting._glances([(0, 9), (15, 20)], 21, FPS), [])

    def test_a_long_watch_looks_back_at_the_viewer_now_and_then(self):
        spans = acting._glances([(0, 9), (200, 209)], 210, FPS)
        watch = round(acting.WATCH_SECONDS * FPS)
        back = round(acting.LOOK_BACK_SECONDS * FPS)
        self.assertGreater(len(spans), 2)
        for (a, b), (c, _) in zip(spans, spans[1:]):
            self.assertEqual(b - a, watch)
            self.assertEqual(c - b, back)


class ActTest(unittest.TestCase):
    def setUp(self):
        # Two phrases with a silence long enough to glance at the app.
        self.levels = _speech((0.5, 2.5), (5.0, 7.0), total=8.0)
        self.poses, self.motions = act(self.levels, FPS, 90)

    def test_one_pose_and_motion_per_frame_padded_past_the_narration(self):
        self.assertEqual(len(self.poses), 90)
        self.assertEqual(len(self.motions), 90)
        self.assertIsInstance(self.motions[0], Motion)

    def test_the_mouth_follows_the_mouth_track(self):
        expected = mouth_track(self.levels) + [0] * 10
        self.assertEqual([p.mouth for p in self.poses], expected)

    def test_the_same_seed_acts_the_same_and_another_differently(self):
        self.assertEqual(act(self.levels, FPS, 90), (self.poses, self.motions))
        self.assertNotEqual(act(self.levels, FPS, 90, seed=8)[1], self.motions)

    def test_the_silence_is_spent_watching_the_app(self):
        watching = [p for p in self.poses[30:45] if not p.eyes_closed]
        self.assertTrue(watching)
        self.assertTrue(all(p.gaze == GAZE_AT_APP for p in watching))
        # Turned toward the app: the face slides left of the head.
        turned = self.motions[44]
        self.assertLess(turned.face[0], turned.head[0])

    def test_it_faces_the_viewer_again_before_speaking(self):
        before = self.poses[48]
        self.assertNotEqual(before.gaze, GAZE_AT_APP)

    def test_the_two_phrases_tilt_the_head_to_opposite_sides(self):
        first, second = self.motions[20].roll, self.motions[65].roll
        self.assertLess(first * second, 0)

    def test_eyes_close_as_a_phrase_starts(self):
        self.assertTrue(self.poses[4].eyes_closed)

    def test_closed_eyes_carry_no_gaze(self):
        self.assertTrue(all(p.gaze == 0 for p in self.poses if p.eyes_closed))

    def test_a_stress_nods_the_head_down_and_lifts_the_brows(self):
        levels = [0.0] * 10 + [1.0] * 2 + [0.0] * 8
        poses, motions = act(levels, FPS, 20)
        self.assertTrue(poses[11].brows_up)
        self.assertGreater(max(m.head[1] for m in motions[10:16]), 0.0)

    def test_a_weaker_stress_nods_but_leaves_the_brows_alone(self):
        # One phrase: a strong stress at frame 5, a weaker one at frame 11.
        levels = [0.0] * 5 + [1.0] * 2 + [0.1] * 4 + [0.5] * 2 + [0.0] * 7
        self.assertEqual([f for f, _ in onsets(levels, FPS)], [5, 11])
        poses, motions = act(levels, FPS, 20)
        self.assertFalse(poses[11].brows_up)
        self.assertGreater(motions[13].head[1], motions[11].head[1])

    def test_a_silent_track_just_watches_the_app(self):
        poses, _ = act([0.0] * 30, FPS, 30)
        self.assertIn(GAZE_AT_APP, [p.gaze for p in poses])
        self.assertEqual({p.mouth for p in poses}, {0})

    def test_the_body_breathes(self):
        bodies = {round(m.body, 4) for m in self.motions}
        self.assertGreater(len(bodies), 5)


if __name__ == "__main__":
    unittest.main()
