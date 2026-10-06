"""Rasterizes the avatar's flat cartoon shapes and encodes the result as PNG.

The avatar is only filled ellipses, polygons and rings, so it needs no imaging
library: every shape reports a signed distance to its edge, and a one-pixel
ramp across that edge is the anti-aliasing. Coordinates are fractions of the
square canvas (0..1, y pointing down), so one character renders at any size.
"""

from __future__ import annotations

import math
import struct
import zlib
from dataclasses import dataclass

Color = tuple[int, int, int, int]  # RGBA, 0-255, straight (not premultiplied)

Point = tuple[float, float]


@dataclass(frozen=True)
class Ellipse:
    cx: float
    cy: float
    rx: float
    ry: float
    color: Color

    def __post_init__(self) -> None:
        if self.rx <= 0 or self.ry <= 0:
            raise ValueError(f"ellipse radii must be positive: {self}")

    def bounds(self) -> tuple[float, float, float, float]:
        return (
            self.cx - self.rx,
            self.cy - self.ry,
            self.cx + self.rx,
            self.cy + self.ry,
        )

    def distance(self, x: float, y: float) -> float:
        # Exact on circles; a close-enough edge ramp for the flat ellipses a
        # cartoon mouth or eyelid needs.
        normalized = math.hypot((x - self.cx) / self.rx, (y - self.cy) / self.ry)
        return (normalized - 1.0) * min(self.rx, self.ry)


@dataclass(frozen=True)
class Polygon:
    points: tuple[Point, ...]
    color: Color

    def __post_init__(self) -> None:
        if len(self.points) < 3:
            raise ValueError(f"a polygon needs at least 3 points: {self}")

    def bounds(self) -> tuple[float, float, float, float]:
        xs = [x for x, _ in self.points]
        ys = [y for _, y in self.points]
        return min(xs), min(ys), max(xs), max(ys)

    def distance(self, x: float, y: float) -> float:
        edges = zip(self.points, self.points[1:] + self.points[:1])
        nearest = min(_segment_distance(x, y, a, b) for a, b in edges)
        return -nearest if self._contains(x, y) else nearest

    def _contains(self, x: float, y: float) -> bool:
        inside = False
        for (ax, ay), (bx, by) in zip(self.points, self.points[1:] + self.points[:1]):
            if (ay > y) != (by > y) and x < ax + (y - ay) * (bx - ax) / (by - ay):
                inside = not inside
        return inside


@dataclass(frozen=True)
class Ring:
    cx: float
    cy: float
    radius: float
    width: float
    color: Color

    def __post_init__(self) -> None:
        if self.radius <= 0 or self.width <= 0:
            raise ValueError(f"ring radius and width must be positive: {self}")

    def bounds(self) -> tuple[float, float, float, float]:
        reach = self.radius + self.width / 2
        return self.cx - reach, self.cy - reach, self.cx + reach, self.cy + reach

    def distance(self, x: float, y: float) -> float:
        from_center = math.hypot(x - self.cx, y - self.cy)
        return abs(from_center - self.radius) - self.width / 2


Shape = Ellipse | Polygon | Ring


def rasterize(shapes: list[Shape], size: int, clip: Ellipse | None = None) -> bytes:
    """Paints ``shapes`` in order onto a transparent ``size``×``size`` canvas
    and returns straight-alpha RGBA bytes. ``clip``, when given, masks the
    finished image to that shape (the avatar's round badge)."""
    if size <= 0:
        raise ValueError(f"canvas size must be positive, got {size}")
    canvas = [0.0] * (size * size * 4)
    for shape in shapes:
        red, green, blue, alpha = (channel / 255 for channel in shape.color)
        left, top, right, bottom = shape.bounds()
        # One extra pixel each side so the anti-aliasing ramp is never cut.
        for py in range(
            max(0, math.floor(top * size) - 1), min(size, math.ceil(bottom * size) + 1)
        ):
            y = (py + 0.5) / size
            for px in range(
                max(0, math.floor(left * size) - 1),
                min(size, math.ceil(right * size) + 1),
            ):
                source_alpha = alpha * _coverage(
                    shape.distance((px + 0.5) / size, y) * size
                )
                if source_alpha <= 0:
                    continue
                _blend_over(
                    canvas, (py * size + px) * 4, red, green, blue, source_alpha
                )
    if clip is not None:
        for py in range(size):
            for px in range(size):
                index = (py * size + px) * 4 + 3
                canvas[index] *= _coverage(
                    clip.distance((px + 0.5) / size, (py + 0.5) / size) * size
                )
    return bytes(round(value * 255) for value in canvas)


def encode_png(rgba: bytes, width: int, height: int) -> bytes:
    """Encodes straight-alpha RGBA bytes as an 8-bit RGBA PNG."""
    if len(rgba) != width * height * 4:
        raise ValueError(
            f"expected {width * height * 4} bytes for {width}x{height} RGBA, got {len(rgba)}"
        )
    stride = width * 4
    # Filter type 0 (none) in front of every scanline.
    scanlines = b"".join(
        b"\x00" + rgba[row * stride : (row + 1) * stride] for row in range(height)
    )
    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + _png_chunk(b"IHDR", header)
        + _png_chunk(b"IDAT", zlib.compress(scanlines, 9))
        + _png_chunk(b"IEND", b"")
    )


def _png_chunk(kind: bytes, data: bytes) -> bytes:
    crc = zlib.crc32(kind + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", crc)


def _coverage(distance_px: float) -> float:
    """How much of a pixel at this signed distance (in pixels) is inside."""
    return min(1.0, max(0.0, 0.5 - distance_px))


def _blend_over(
    canvas: list[float], index: int, red: float, green: float, blue: float, alpha: float
) -> None:
    below = canvas[index + 3]
    out_alpha = alpha + below * (1 - alpha)
    for offset, channel in enumerate((red, green, blue)):
        canvas[index + offset] = (
            channel * alpha + canvas[index + offset] * below * (1 - alpha)
        ) / out_alpha
    canvas[index + 3] = out_alpha


def _segment_distance(x: float, y: float, a: Point, b: Point) -> float:
    (ax, ay), (bx, by) = a, b
    dx, dy = bx - ax, by - ay
    length_squared = dx * dx + dy * dy
    t = 0.0 if length_squared == 0 else ((x - ax) * dx + (y - ay) * dy) / length_squared
    t = min(1.0, max(0.0, t))
    return math.hypot(x - (ax + t * dx), y - (ay + t * dy))
