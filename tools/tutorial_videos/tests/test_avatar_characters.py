"""Tests for the avatar character: the generic layering and Pip's art."""

from __future__ import annotations

import unittest

from avatar_helpers import pixel

from tutorial_videos.avatar.characters import (
    BADGE,
    BROW_LIFT,
    CHARACTERS,
    DEFAULT_CHARACTER,
    GAZES,
    MOUTH_LEVELS,
    PIP,
    RING,
    THEO,
    Character,
    Pose,
    _pair,
    moved,
)
from tutorial_videos.avatar.raster import Ellipse, Polygon, Ring, rasterize

ALL_POSES = [
    Pose(mouth, closed, gaze, brows)
    for mouth in range(MOUTH_LEVELS)
    for closed in (False, True)
    for gaze in range(len(GAZES))
    for brows in (False, True)
]
INK = (24, 28, 40, 255)


def _character(**overrides) -> Character:
    values = dict(
        name="test",
        background=(1, 2, 3, 255),
        body=(Ellipse(0.5, 0.9, 0.3, 0.2, INK),),
        head=(Ellipse(0.5, 0.45, 0.25, 0.25, INK),),
        features=(Ellipse(0.5, 0.5, 0.02, 0.02, INK),),
        brows=(Polygon(((0.4, 0.3), (0.45, 0.3), (0.45, 0.32)), INK),),
        eyes_open=(Ellipse(0.4, 0.4, 0.1, 0.1, INK),),
        eyes_closed=(Ellipse(0.4, 0.4, 0.1, 0.01, INK),),
        mouths=tuple(
            (Ellipse(0.5, 0.6, 0.1, 0.01 + level / 100, INK),)
            for level in range(MOUTH_LEVELS)
        ),
        pivot=(0.5, 0.7),
    )
    values.update(overrides)
    return Character(**values)


class CharacterTest(unittest.TestCase):
    def test_rejects_the_wrong_number_of_mouth_shapes(self):
        with self.assertRaises(ValueError):
            _character(mouths=((),) * (MOUTH_LEVELS - 1))

    def test_rejects_a_mouth_level_out_of_range(self):
        for mouth in (-1, MOUTH_LEVELS):
            with self.subTest(mouth=mouth), self.assertRaises(ValueError):
                _character().face_shapes(Pose(mouth, False))

    def test_rejects_a_gaze_out_of_range(self):
        for gaze in (-1, len(GAZES)):
            with self.subTest(gaze=gaze), self.assertRaises(ValueError):
                _character().face_shapes(Pose(0, False, gaze))

    def test_the_still_picture_stacks_every_layer_then_the_ring(self):
        c = _character()
        shapes = c.shapes(Pose(2, False))
        self.assertEqual(shapes[0], Ellipse(0.5, 0.5, 0.5, 0.5, (1, 2, 3, 255)))
        self.assertEqual(
            shapes[1:-1], [*c.body, *c.head, *c.face_shapes(Pose(2, False))]
        )
        self.assertEqual(shapes[-1], RING)

    def test_the_face_is_features_brows_eyes_then_mouth(self):
        c = _character()
        self.assertEqual(
            c.face_shapes(Pose(1, False)),
            [*c.features, *c.brows, *c.eyes_open, *c.mouths[1]],
        )

    def test_closed_eyes_swap_only_the_eyes(self):
        c = _character()
        opened = c.face_shapes(Pose(0, False))
        closed = c.face_shapes(Pose(0, True))
        self.assertEqual(closed[2], c.eyes_closed[0])
        self.assertEqual(opened[:2] + opened[3:], closed[:2] + closed[3:])

    def test_the_gaze_moves_only_the_open_eyes(self):
        c = _character()
        gx, gy = GAZES[3]
        self.assertEqual(
            c.face_shapes(Pose(0, False, 3))[2], moved(c.eyes_open[0], gx, gy)
        )
        self.assertEqual(c.face_shapes(Pose(0, True, 3))[2], c.eyes_closed[0])

    def test_lifted_brows_rise(self):
        c = _character()
        lifted = c.face_shapes(Pose(0, False, brows_up=True))[1]
        self.assertEqual(lifted, moved(c.brows[0], 0, -BROW_LIFT))


class MovedTest(unittest.TestCase):
    def test_shifts_every_kind_of_shape(self):
        self.assertEqual(
            moved(Ellipse(0.25, 0.5, 0.1, 0.1, INK), 0.25, -0.25),
            Ellipse(0.5, 0.25, 0.1, 0.1, INK),
        )
        self.assertEqual(
            moved(Ring(0.25, 0.5, 0.1, 0.1, INK), 0.25, 0.0),
            Ring(0.5, 0.5, 0.1, 0.1, INK),
        )
        self.assertEqual(
            moved(Polygon(((0, 0), (0.5, 0), (0, 0.5)), INK), 0.25, 0.25),
            Polygon(((0.25, 0.25), (0.75, 0.25), (0.25, 0.75)), INK),
        )


class PairTest(unittest.TestCase):
    def test_adds_the_mirror_image(self):
        left = Ellipse(0.3, 0.4, 0.05, 0.06, INK)
        self.assertEqual(_pair(left), (left, Ellipse(0.7, 0.4, 0.05, 0.06, INK)))

    def test_mirrors_a_ring_as_a_ring(self):
        left = Ring(0.25, 0.47, 0.06, 0.01, INK)
        self.assertEqual(_pair(left), (left, Ring(0.75, 0.47, 0.06, 0.01, INK)))


class RegistryTest(unittest.TestCase):
    def test_names_every_character_by_its_own_name(self):
        self.assertEqual(CHARACTERS, {"pip": PIP, "theo": THEO})

    def test_pip_stays_the_default(self):
        self.assertIs(CHARACTERS[DEFAULT_CHARACTER], PIP)


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


class PivotTest(unittest.TestCase):
    def test_each_head_turns_about_a_point_inside_its_own_chin(self):
        for character in (PIP, THEO):
            with self.subTest(character=character.name):
                rgba = rasterize(list(character.head), 50)
                x, y = (round(v * 50) for v in character.pivot)
                self.assertGreater(pixel(rgba, 50, x, y - 1)[3], 0)


class TheoTest(unittest.TestCase):
    def test_every_mouth_level_looks_different(self):
        self.assertEqual(len(set(THEO.mouths)), MOUTH_LEVELS)

    def test_blinking_changes_the_eyes(self):
        self.assertNotEqual(THEO.eyes_open, THEO.eyes_closed)

    def test_every_pose_renders_as_a_round_badge(self):
        for pose in ALL_POSES:
            with self.subTest(pose=pose):
                rgba = rasterize(THEO.shapes(pose), 24, clip=BADGE)
                self.assertEqual(pixel(rgba, 24, 0, 0)[3], 0)
                self.assertEqual(pixel(rgba, 24, 12, 12)[3], 255)

    def test_the_closed_mouth_is_one_smile_and_the_open_ones_show_teeth(self):
        closed, *opened = THEO.mouths
        self.assertEqual(len(closed), 1)
        smile = closed[0].points
        corners_y = (smile[0][1], smile[8][1])
        middle_y = smile[4][1]
        self.assertTrue(all(middle_y > y for y in corners_y))  # corners up
        for mouth in opened:
            teeth = mouth[1]
            self.assertEqual(teeth.color[:3], (255, 255, 255))

    def test_the_mouth_opens_further_at_each_level_and_shows_the_tongue_wide(self):
        bottoms = [max(y for _, y in mouth[0].points) for mouth in THEO.mouths[1:]]
        self.assertEqual(bottoms, sorted(set(bottoms)))
        self.assertEqual([len(mouth) for mouth in THEO.mouths[1:]], [2, 3, 3])

    def test_the_mouth_shows_at_badge_size(self):
        # The open mouth's dark inside must survive rasterising at 48px.
        wide = rasterize(THEO.shapes(Pose(3, False)), 48, clip=BADGE)
        shut = rasterize(THEO.shapes(Pose(0, False)), 48, clip=BADGE)
        self.assertLess(
            sum(pixel(wide, 48, 24, 30)[:3]), sum(pixel(shut, 48, 24, 30)[:3])
        )


if __name__ == "__main__":
    unittest.main()
