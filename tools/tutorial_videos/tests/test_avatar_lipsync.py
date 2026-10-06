"""Tests for loudness-driven lip-sync."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from avatar_helpers import write_wav

from tutorial_videos.avatar import AvatarError
from tutorial_videos.avatar.lipsync import frame_levels, mouth_track


class FrameLevelsTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self._tmp.name)

    def tearDown(self):
        self._tmp.cleanup()

    def _wav(self, samples, **kwargs) -> Path:
        return write_wav(self.dir / "clip.wav", samples, **kwargs)

    def test_rejects_a_non_positive_fps(self):
        with self.assertRaises(ValueError):
            frame_levels(self._wav([0] * 10), 0)

    def test_rejects_anything_but_16_bit_samples(self):
        with self.assertRaises(AvatarError) as raised:
            frame_levels(self._wav([0] * 10, sample_width=1), 10)
        self.assertIn("8-bit", str(raised.exception))

    def test_an_empty_wav_has_no_frames(self):
        self.assertEqual(frame_levels(self._wav([]), 10), [])

    def test_silence_is_level_zero(self):
        self.assertEqual(frame_levels(self._wav([0] * 100), 10), [0.0] * 10)

    def test_a_constant_amplitude_is_its_rms_relative_to_full_scale(self):
        levels = frame_levels(self._wav([16384, -16384] * 50), 10)
        self.assertEqual(levels, [0.5] * 10)

    def test_each_frame_measures_only_its_own_slice(self):
        levels = frame_levels(self._wav([16384] * 50 + [0] * 50), 2)
        self.assertEqual(levels, [0.5, 0.0])

    def test_a_partial_last_frame_still_gets_a_level(self):
        # 5 samples per frame, 7 samples: the 2nd frame holds only two.
        levels = frame_levels(self._wav([0] * 5 + [16384] * 2, rate=10), 2)
        self.assertEqual(levels, [0.0, 0.5])

    def test_a_fractional_samples_per_frame_loses_no_sample(self):
        # 15 Hz at 11 fps: float frame boundaries put the 11th frame's end at
        # sample 14, dropping the last sample — the only loud one. The last
        # frame (samples 13 and 14) must still hear it.
        levels = frame_levels(self._wav([0] * 14 + [32767], rate=15), 11)
        self.assertEqual(len(levels), 11)
        self.assertAlmostEqual(levels[-1], 32767 / 2**0.5 / 32768)

    def test_fewer_samples_than_frames_never_yields_an_empty_slice(self):
        # 2 samples per second at 4 fps: each frame shows the sample playing.
        levels = frame_levels(self._wav([16384, 0], rate=2), 4)
        self.assertEqual(levels, [0.5, 0.5, 0.0, 0.0])

    def test_stereo_frames_measure_both_channels(self):
        # Left loud, right silent: RMS over the interleaved samples.
        levels = frame_levels(self._wav([16384, 0] * 10, channels=2), 1)
        self.assertAlmostEqual(levels[0], 0.5 / 2**0.5)
        self.assertEqual(len(levels), 1)


class MouthTrackTest(unittest.TestCase):
    def test_rejects_the_wrong_number_of_thresholds(self):
        with self.assertRaises(ValueError):
            mouth_track([0.5], thresholds=(0.5,))

    def test_no_levels_is_no_track(self):
        self.assertEqual(mouth_track([]), [])

    def test_silence_keeps_the_mouth_closed(self):
        self.assertEqual(mouth_track([0.0] * 5), [0] * 5)

    def test_loudness_relative_to_the_reference_picks_the_level(self):
        # The reference is the loudest frame here; each threshold opens one
        # level further.
        levels = [0.1, 0.2, 0.5, 0.8, 1.0]
        self.assertEqual(
            mouth_track(levels, thresholds=(0.15, 0.4, 0.7), close_hold=1),
            [0, 1, 2, 3, 3],
        )

    def test_a_quiet_voice_animates_like_a_loud_one(self):
        loud = [0.0, 0.3, 0.9, 0.5, 0.0, 0.0]
        quiet = [level / 10 for level in loud]
        self.assertEqual(mouth_track(quiet), mouth_track(loud))

    def test_a_single_quiet_frame_between_syllables_keeps_the_mouth_open(self):
        self.assertEqual(
            mouth_track([1.0, 0.0, 1.0, 0.0, 0.0, 0.0], close_hold=2),
            [3, 3, 3, 3, 0, 0],
        )

    def test_one_loud_spike_does_not_flatten_the_rest(self):
        # The 95th percentile, not the maximum, is the reference: normal
        # speech still opens the mouth fully.
        levels = [0.1] * 99 + [1.0]
        self.assertEqual(mouth_track(levels)[:99], [3] * 99)


if __name__ == "__main__":
    unittest.main()
