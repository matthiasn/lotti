"""Tests for the avatar character: the generic layering and Pip's art."""

from __future__ import annotations

import unittest

from avatar_helpers import pixel

from tutorial_videos.avatar.characters import (
    BADGE,
    MOUTH_LEVELS,
    PIP,
    Character,
    Pose,
    _pair,
)
from tutorial_videos.avatar.raster import Ellipse, Polygon, Ring, rasterize

ALL_POSES = [
    Pose(mouth, closed) for mouth in range(MOUTH_LEVELS) for closed in (False, True)
]
INK = (24, 28, 40, 255)


def _character(**overrides) -> Character:
    values = dict(
        name="test",
        background=(1, 2, 3, 255),
        base=(),
        eyes_open=(Ellipse(0.4, 0.4, 0.1, 0.1, INK),),
        eyes_closed=(Ellipse(0.4, 0.4, 0.1, 0.01, INK),),
        mouths=tuple(
            (Ellipse(0.5, 0.6, 0.1, 0.01 + level / 100, INK),)
            for level in range(MOUTH_LEVELS)
        ),
    )
    values.update(overrides)
    return Character(**values)


class CharacterTest(unittest.TestCase):
    def test_rejects_the_wrong_number_of_mouth_shapes(self):
        with self.assertRaises(ValueError):
            _character(mouths=((),) * (MOUTH_LEVELS - 1))

    def test_shapes_rejects_a_mouth_level_out_of_range(self):
        for mouth in (-1, MOUTH_LEVELS):
            with self.subTest(mouth=mouth), self.assertRaises(ValueError):
                _character().shapes(Pose(mouth, False))

    def test_shapes_stack_background_base_eyes_mouth_then_ring(self):
        base = Ellipse(0.5, 0.5, 0.3, 0.3, INK)
        character = _character(base=(base,))

        shapes = character.shapes(Pose(2, False))

        self.assertEqual(shapes[0], Ellipse(0.5, 0.5, 0.5, 0.5, (1, 2, 3, 255)))
        self.assertEqual(
            shapes[1:4], [base, *character.eyes_open, *character.mouths[2]]
        )
        self.assertIsInstance(shapes[-1], Ring)

    def test_closed_eyes_swap_only_the_eye_layers(self):
        character = _character()
        opened = character.shapes(Pose(0, False))
        closed = character.shapes(Pose(0, True))
        self.assertEqual(closed[1], character.eyes_closed[0])
        self.assertEqual(opened[:1] + opened[2:], closed[:1] + closed[2:])


class PairTest(unittest.TestCase):
    def test_adds_the_mirror_image(self):
        left = Ellipse(0.3, 0.4, 0.05, 0.06, INK)
        self.assertEqual(_pair(left), (left, Ellipse(0.7, 0.4, 0.05, 0.06, INK)))


class PipTest(unittest.TestCase):
    def test_every_mouth_level_looks_different(self):
        self.assertEqual(len(set(PIP.mouths)), MOUTH_LEVELS)

    def test_blinking_changes_the_eyes(self):
        self.assertNotEqual(PIP.eyes_open, PIP.eyes_closed)

    def test_every_pose_renders_as_a_round_badge(self):
        for pose in ALL_POSES:
            with self.subTest(pose=pose):
                rgba = rasterize(PIP.shapes(pose), 24, clip=BADGE)
                self.assertEqual(pixel(rgba, 24, 0, 0)[3], 0)
                self.assertEqual(pixel(rgba, 24, 12, 12)[3], 255)

    def test_the_beak_drops_further_at_each_level(self):
        lower_tips = []
        for level, mouth in enumerate(PIP.mouths):
            *inside, lower, _upper = mouth
            # Closed shows no inside of the beak; every open level does.
            self.assertEqual(len(inside), 0 if level == 0 else 1)
            self.assertIsInstance(lower, Polygon)
            lower_tips.append(lower.points[2][1])
        self.assertEqual(lower_tips, sorted(set(lower_tips)))


if __name__ == "__main__":
    unittest.main()
