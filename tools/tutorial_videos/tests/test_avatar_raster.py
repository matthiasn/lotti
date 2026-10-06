"""Tests for the avatar's shape rasterizer and PNG encoder."""

from __future__ import annotations

import unittest

from avatar_helpers import decode_png, pixel

from tutorial_videos.avatar.raster import (
    Ellipse,
    Polygon,
    Ring,
    encode_png,
    rasterize,
)

RED = (255, 0, 0, 255)
BLUE = (0, 0, 255, 255)
SQUARE = ((0.25, 0.25), (0.75, 0.25), (0.75, 0.75), (0.25, 0.75))


def _assert_bounds(test: unittest.TestCase, actual, expected) -> None:
    for got, want in zip(actual, expected, strict=True):
        test.assertAlmostEqual(got, want)


class EllipseTest(unittest.TestCase):
    def test_rejects_non_positive_radii(self):
        for rx, ry in ((0, 0.1), (0.1, 0), (-0.1, 0.1)):
            with self.subTest(rx=rx, ry=ry), self.assertRaises(ValueError):
                Ellipse(0.5, 0.5, rx, ry, RED)

    def test_bounds_span_both_radii(self):
        _assert_bounds(
            self, Ellipse(0.5, 0.4, 0.2, 0.1, RED).bounds(), (0.3, 0.3, 0.7, 0.5)
        )

    def test_distance_is_negative_inside_zero_on_edge_positive_outside(self):
        circle = Ellipse(0.5, 0.5, 0.25, 0.25, RED)
        self.assertAlmostEqual(circle.distance(0.5, 0.5), -0.25)
        self.assertAlmostEqual(circle.distance(0.75, 0.5), 0.0)
        self.assertAlmostEqual(circle.distance(1.0, 0.5), 0.25)


class PolygonTest(unittest.TestCase):
    def test_rejects_fewer_than_three_points(self):
        with self.assertRaises(ValueError):
            Polygon(((0, 0), (1, 1)), RED)

    def test_bounds_are_the_point_extremes(self):
        _assert_bounds(self, Polygon(SQUARE, RED).bounds(), (0.25, 0.25, 0.75, 0.75))

    def test_distance_is_signed_by_containment(self):
        square = Polygon(SQUARE, RED)
        self.assertAlmostEqual(square.distance(0.5, 0.5), -0.25)
        self.assertAlmostEqual(square.distance(0.25, 0.5), 0.0)
        self.assertAlmostEqual(square.distance(0.0, 0.5), 0.25)

    def test_distance_beyond_a_corner_is_to_the_corner(self):
        square = Polygon(SQUARE, RED)
        self.assertAlmostEqual(square.distance(0.0, 0.0), (2 * 0.25**2) ** 0.5)

    def test_a_repeated_point_does_not_break_the_distance(self):
        # The zero-length edge between the duplicates must not divide by zero.
        square = Polygon((SQUARE[0], *SQUARE), RED)
        self.assertAlmostEqual(square.distance(0.0, 0.5), 0.25)


class RingTest(unittest.TestCase):
    def test_rejects_non_positive_radius_or_width(self):
        for radius, width in ((0, 0.1), (0.3, 0), (-0.3, 0.1)):
            with self.subTest(radius=radius, width=width), self.assertRaises(
                ValueError
            ):
                Ring(0.5, 0.5, radius, width, RED)

    def test_bounds_include_half_the_stroke(self):
        _assert_bounds(
            self, Ring(0.5, 0.5, 0.3, 0.1, RED).bounds(), (0.15, 0.15, 0.85, 0.85)
        )

    def test_distance_is_inside_only_on_the_stroke(self):
        ring = Ring(0.5, 0.5, 0.3, 0.1, RED)
        self.assertAlmostEqual(ring.distance(0.8, 0.5), -0.05)
        self.assertAlmostEqual(ring.distance(0.5, 0.5), 0.25)
        self.assertAlmostEqual(ring.distance(1.0, 0.5), 0.15)


class RasterizeTest(unittest.TestCase):
    def test_rejects_a_non_positive_size(self):
        with self.assertRaises(ValueError):
            rasterize([], 0)

    def test_no_shapes_is_a_fully_transparent_canvas(self):
        self.assertEqual(rasterize([], 4), bytes(4 * 4 * 4))

    def test_an_opaque_shape_fills_its_inside_and_nothing_else(self):
        rgba = rasterize([Ellipse(0.5, 0.5, 0.3, 0.3, RED)], 16)
        self.assertEqual(pixel(rgba, 16, 8, 8), RED)
        self.assertEqual(pixel(rgba, 16, 0, 0), (0, 0, 0, 0))

    def test_a_pixel_centered_on_the_edge_is_half_covered(self):
        # Pixel (6, 4) of an 8px canvas has its center at (0.8125, 0.5625):
        # exactly on this circle's edge.
        rgba = rasterize([Ellipse(0.5625, 0.5625, 0.25, 0.25, RED)], 8)
        self.assertEqual(pixel(rgba, 8, 6, 4)[3], 128)

    def test_later_shapes_paint_over_earlier_ones(self):
        rgba = rasterize([Polygon(SQUARE, RED), Polygon(SQUARE, BLUE)], 8)
        self.assertEqual(pixel(rgba, 8, 4, 4), BLUE)

    def test_a_translucent_shape_blends_with_what_is_below(self):
        rgba = rasterize([Polygon(SQUARE, RED), Polygon(SQUARE, (0, 0, 255, 51))], 8)
        self.assertEqual(pixel(rgba, 8, 4, 4), (204, 0, 51, 255))

    def test_a_translucent_shape_on_nothing_keeps_its_color_and_alpha(self):
        rgba = rasterize([Polygon(SQUARE, (0, 0, 255, 51))], 8)
        self.assertEqual(pixel(rgba, 8, 4, 4), (0, 0, 255, 51))

    def test_a_fully_transparent_shape_changes_nothing(self):
        rgba = rasterize([Polygon(SQUARE, RED), Polygon(SQUARE, (0, 0, 255, 0))], 8)
        self.assertEqual(pixel(rgba, 8, 4, 4), RED)

    def test_a_shape_reaching_past_the_canvas_is_clipped_to_it(self):
        rgba = rasterize([Ellipse(0.0, 0.0, 0.5, 0.5, RED)], 8)
        self.assertEqual(len(rgba), 8 * 8 * 4)
        self.assertEqual(pixel(rgba, 8, 0, 0), RED)
        self.assertEqual(pixel(rgba, 8, 7, 7), (0, 0, 0, 0))

    def test_the_clip_masks_corners_but_keeps_the_middle(self):
        full = Polygon(((0, 0), (1, 0), (1, 1), (0, 1)), RED)
        clipped = rasterize([full], 16, clip=Ellipse(0.5, 0.5, 0.5, 0.5, RED))
        unclipped = rasterize([full], 16)
        self.assertEqual(pixel(clipped, 16, 0, 0)[3], 0)
        self.assertEqual(pixel(clipped, 16, 8, 8), RED)
        self.assertEqual(pixel(unclipped, 16, 0, 0), RED)


class EncodePngTest(unittest.TestCase):
    def test_round_trips_the_pixels(self):
        rgba = bytes(range(2 * 3 * 4))
        self.assertEqual(decode_png(encode_png(rgba, 2, 3)), (2, 3, rgba))

    def test_rejects_a_buffer_of_the_wrong_length(self):
        with self.assertRaises(ValueError):
            encode_png(bytes(15), 2, 2)


if __name__ == "__main__":
    unittest.main()
