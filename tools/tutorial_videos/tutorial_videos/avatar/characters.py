"""The avatar: Pip, a cartoon penguin from Lotti's demo world, drawn from flat
shapes.

A character is pure data — a background badge, its fixed body, two eye states
and ``MOUTH_LEVELS`` mouth shapes from closed to wide open. ``shapes(pose)``
stacks the layers for one pose; the renderer only ever draws the handful of
poses a narration actually uses.

Any change to the art should still read as friendly at the ~200px a corner
badge gets, and keep the beak clearly visible so the lip-sync carries — check
it with ``avatar-preview``.
"""

from __future__ import annotations

from dataclasses import dataclass

from .raster import Color, Ellipse, Polygon, Ring, Shape

MOUTH_LEVELS = 4  # 0 = closed … 3 = wide open

# The badge the character sits in: the whole canvas, masked round.
BADGE = Ellipse(0.5, 0.5, 0.5, 0.5, (0, 0, 0, 255))

_TEAL: Color = (20, 184, 166, 255)
_INK: Color = (24, 28, 40, 255)
_WHITE: Color = (255, 255, 255, 255)
_BLUSH: Color = (255, 150, 165, 170)


@dataclass(frozen=True)
class Pose:
    mouth: int
    eyes_closed: bool


@dataclass(frozen=True)
class Character:
    name: str
    background: Color
    base: tuple[Shape, ...]
    eyes_open: tuple[Shape, ...]
    eyes_closed: tuple[Shape, ...]
    mouths: tuple[tuple[Shape, ...], ...]  # indexed by mouth level

    def __post_init__(self) -> None:
        if len(self.mouths) != MOUTH_LEVELS:
            raise ValueError(
                f"{self.name}: needs {MOUTH_LEVELS} mouth shapes, got {len(self.mouths)}"
            )

    def shapes(self, pose: Pose) -> list[Shape]:
        """All layers for ``pose``, back to front, ending in the badge ring."""
        if not 0 <= pose.mouth < MOUTH_LEVELS:
            raise ValueError(f"mouth level {pose.mouth} outside 0..{MOUTH_LEVELS - 1}")
        return [
            Ellipse(0.5, 0.5, 0.5, 0.5, self.background),
            *self.base,
            *(self.eyes_closed if pose.eyes_closed else self.eyes_open),
            *self.mouths[pose.mouth],
            # Reaches past the badge edge, so the round mask, not the ring,
            # draws the outline — no sliver of background outside it.
            Ring(0.5, 0.5, 0.48, 0.06, _TEAL),
        ]


def _pair(shape: Ellipse) -> tuple[Ellipse, Ellipse]:
    """``shape`` plus its mirror image — eyes, cheeks."""
    return shape, Ellipse(1 - shape.cx, shape.cy, shape.rx, shape.ry, shape.color)


def _dot_eyes(y: float, spacing: float) -> tuple[tuple[Shape, ...], tuple[Shape, ...]]:
    """Round ink eyes with a highlight, and the thin line they close to."""
    x = 0.5 - spacing
    opened = (
        *_pair(Ellipse(x, y, 0.036, 0.046, _INK)),
        *_pair(Ellipse(x + 0.012, y - 0.016, 0.013, 0.013, _WHITE)),
    )
    closed = _pair(Ellipse(x, y + 0.01, 0.038, 0.009, _INK))
    return opened, closed


def _penguin() -> Character:
    navy: Color = (34, 46, 72, 255)
    orange: Color = (255, 170, 51, 255)
    opened, closed = _dot_eyes(0.47, 0.075)

    def beak(gap: float) -> tuple[Shape, ...]:
        # The upper half stays put; the lower half drops by `gap`, showing
        # the dark inside of the beak.
        inside = (
            (Ellipse(0.5, 0.565 + gap / 2, 0.04, gap / 2 + 0.012, _INK),) if gap else ()
        )
        lower = Polygon(
            ((0.46, 0.565 + gap), (0.54, 0.565 + gap), (0.5, 0.6 + gap)), orange
        )
        upper = Polygon(((0.44, 0.545), (0.56, 0.545), (0.5, 0.588)), orange)
        return (*inside, lower, upper)

    return Character(
        name="pip",
        background=(220, 238, 246, 255),
        base=(
            Ellipse(0.5, 0.86, 0.36, 0.36, navy),
            Ellipse(0.5, 0.95, 0.24, 0.26, _WHITE),
            Ellipse(0.5, 0.47, 0.3, 0.28, navy),
            *_pair(Ellipse(0.425, 0.49, 0.125, 0.15, _WHITE)),
            Ellipse(0.5, 0.57, 0.17, 0.12, _WHITE),
            *_pair(Ellipse(0.35, 0.57, 0.04, 0.025, _BLUSH)),
        ),
        eyes_open=opened,
        eyes_closed=closed,
        mouths=tuple(beak(gap) for gap in (0.0, 0.018, 0.034, 0.05)),
    )


PIP = _penguin()
