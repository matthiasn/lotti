"""The avatars, drawn from flat shapes: Pip, a cartoon penguin from Lotti's
demo world, and Theo, a friendly man in round glasses.

A character is pure data, split into the layers the renderer moves
independently so the badge can act rather than just swap mouths:

- ``body`` — shoulders and neck; breathes, otherwise still.
- ``head`` — face shape, ears, hair; rolls about the neck ``pivot``.
- ``features`` and ``brows`` — the face on top of the head. They roll with
  the head and slide a little further when it turns, which reads as a
  three-quarter turn without any 3D. Brows also lift for emphasis.
- ``eyes_open`` / ``eyes_closed`` and ``MOUTH_LEVELS`` mouth shapes.

A ``Pose`` picks the mouth, the eyes (with a gaze direction from ``GAZES``)
and the brows; ``face_shapes(pose)`` is the face layer for it, and
``shapes(pose)`` the whole still picture.

Any change to the art should still read as friendly at the ~200px a corner
badge gets, and keep the beak or mouth clearly visible so the lip-sync carries
— check it with ``avatar-preview``. ``CHARACTERS`` is what a scenario's
``avatar:`` key and the ``--character`` flags choose from.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, replace

from .raster import Color, Ellipse, Polygon, Ring, Shape

MOUTH_LEVELS = 4  # 0 = closed … 3 = wide open

# Where the open eyes look, as an offset in badge units: at the viewer, a
# little left, a little right, and down-left toward the app (the badge sits
# top right, the app is below and to its left).
GAZES: tuple[tuple[float, float], ...] = (
    (0.0, 0.0),
    (-0.011, 0.0),
    (0.011, 0.0),
    (-0.017, 0.011),
)
GAZE_AT_APP = 3
BROW_LIFT = 0.016

# The badge the character sits in: the whole canvas, masked round.
BADGE = Ellipse(0.5, 0.5, 0.5, 0.5, (0, 0, 0, 255))

_TEAL: Color = (20, 184, 166, 255)
_INK: Color = (24, 28, 40, 255)
_WHITE: Color = (255, 255, 255, 255)
_BLUSH: Color = (255, 150, 165, 170)

# Reaches past the badge edge, so the round mask, not the ring, draws the
# outline — no sliver of background outside it.
RING = Ring(0.5, 0.5, 0.48, 0.06, _TEAL)


@dataclass(frozen=True)
class Pose:
    mouth: int
    eyes_closed: bool
    gaze: int = 0
    brows_up: bool = False


def moved(shape: Shape, dx: float, dy: float) -> Shape:
    """``shape`` shifted by (dx, dy)."""
    if isinstance(shape, Polygon):
        return Polygon(tuple((x + dx, y + dy) for x, y in shape.points), shape.color)
    return replace(shape, cx=shape.cx + dx, cy=shape.cy + dy)


@dataclass(frozen=True)
class Character:
    name: str
    background: Color
    body: tuple[Shape, ...]
    head: tuple[Shape, ...]
    features: tuple[Shape, ...]
    brows: tuple[Shape, ...]
    eyes_open: tuple[Shape, ...]
    eyes_closed: tuple[Shape, ...]
    mouths: tuple[tuple[Shape, ...], ...]  # indexed by mouth level
    pivot: tuple[float, float]  # where the head meets the neck

    def __post_init__(self) -> None:
        if len(self.mouths) != MOUTH_LEVELS:
            raise ValueError(
                f"{self.name}: needs {MOUTH_LEVELS} mouth shapes, got {len(self.mouths)}"
            )

    def face_shapes(self, pose: Pose) -> list[Shape]:
        """The face layer for ``pose``: features, brows, eyes and mouth."""
        if not 0 <= pose.mouth < MOUTH_LEVELS:
            raise ValueError(f"mouth level {pose.mouth} outside 0..{MOUTH_LEVELS - 1}")
        if not 0 <= pose.gaze < len(GAZES):
            raise ValueError(f"gaze {pose.gaze} outside 0..{len(GAZES) - 1}")
        gx, gy = GAZES[pose.gaze]
        lift = -BROW_LIFT if pose.brows_up else 0.0
        eyes = (
            self.eyes_closed
            if pose.eyes_closed
            else tuple(moved(s, gx, gy) for s in self.eyes_open)
        )
        return [
            *self.features,
            *(moved(s, 0.0, lift) for s in self.brows),
            *eyes,
            *self.mouths[pose.mouth],
        ]

    def shapes(self, pose: Pose) -> list[Shape]:
        """The whole still picture for ``pose``, back to front, ending in the
        badge ring."""
        return [
            Ellipse(0.5, 0.5, 0.5, 0.5, self.background),
            *self.body,
            *self.head,
            *self.face_shapes(pose),
            RING,
        ]


def _pair(shape: Ellipse | Ring) -> tuple[Shape, Shape]:
    """``shape`` plus its mirror image — eyes, cheeks, glasses rims."""
    return shape, replace(shape, cx=1 - shape.cx)


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
        body=(
            Ellipse(0.5, 0.86, 0.36, 0.36, navy),
            Ellipse(0.5, 0.95, 0.24, 0.26, _WHITE),
        ),
        head=(
            Ellipse(0.5, 0.47, 0.3, 0.28, navy),
            *_pair(Ellipse(0.425, 0.49, 0.125, 0.15, _WHITE)),
            Ellipse(0.5, 0.57, 0.17, 0.12, _WHITE),
            *_pair(Ellipse(0.35, 0.57, 0.04, 0.025, _BLUSH)),
        ),
        features=(),
        brows=(),
        eyes_open=opened,
        eyes_closed=closed,
        mouths=tuple(beak(gap) for gap in (0.0, 0.018, 0.034, 0.05)),
        pivot=(0.5, 0.72),
    )


PIP = _penguin()


def _theo() -> Character:
    """Head and shoulders of a man in his thirties: side-swept brown hair, round
    glasses, light stubble and a mustard crewneck over a white collar."""
    skin: Color = (241, 201, 171, 255)
    skin_shade: Color = (222, 173, 141, 255)
    hair: Color = (101, 64, 40, 255)
    hair_light: Color = (139, 93, 61, 255)
    stubble: Color = (120, 82, 58, 34)
    sweater: Color = (222, 162, 58, 255)
    sweater_shade: Color = (190, 134, 40, 255)
    frame: Color = (38, 40, 52, 255)
    mouth_in: Color = (92, 30, 36, 255)
    tongue: Color = (226, 112, 120, 255)
    opened, closed = _dot_eyes(0.47, 0.082)

    def mouth(gap: float) -> tuple[Shape, ...]:
        if not gap:
            # A closed smile: a thin crescent, corners up.
            xs = [0.44 + 0.015 * k for k in range(9)]
            top = [(x, 0.596 + 0.014 * (1 - ((x - 0.5) / 0.06) ** 2)) for x in xs]
            bottom = [
                (x, y + 0.009 * (1 - ((x - 0.5) / 0.06) ** 2)) for x, y in reversed(top)
            ]
            return (Polygon(tuple(top + bottom), mouth_in),)
        # Open: flat top, round bottom, teeth along the top, tongue once wide.
        depth = gap + 0.012
        rim = tuple(
            (0.5 + 0.064 * math.cos(a), 0.598 + depth * math.sin(a))
            for a in (k * math.pi / 8 for k in range(9))
        )
        shapes: list[Shape] = [Polygon(rim, mouth_in)]
        shapes.append(
            Polygon(
                ((0.444, 0.598), (0.556, 0.598), (0.545, 0.608), (0.455, 0.608)), _WHITE
            )
        )
        if gap > 0.02:
            shapes.append(
                Ellipse(0.5, 0.598 + depth * 0.78, 0.03, depth * 0.24, tongue)
            )
        return tuple(shapes)

    return Character(
        name="theo",
        background=(252, 238, 222, 255),
        body=(
            # The neck, shoulders in a crewneck, a white collar peeking out.
            Polygon(
                ((0.455, 0.6), (0.545, 0.6), (0.555, 0.76), (0.445, 0.76)), skin_shade
            ),
            Ellipse(0.5, 1.04, 0.43, 0.3, sweater),
            Ellipse(0.5, 1.04, 0.36, 0.25, sweater_shade),
            Ellipse(0.5, 1.04, 0.35, 0.25, sweater),
            Polygon(((0.4, 0.745), (0.5, 0.79), (0.46, 0.83)), _WHITE),
            Polygon(((0.6, 0.745), (0.5, 0.79), (0.54, 0.83)), _WHITE),
            Ellipse(0.5, 0.75, 0.1, 0.035, sweater_shade),
        ),
        head=(
            # Ears, then the head with a squarer jaw.
            *_pair(Ellipse(0.285, 0.48, 0.04, 0.06, skin_shade)),
            Ellipse(0.5, 0.45, 0.215, 0.25, skin),
            Polygon(
                (
                    (0.29, 0.47),
                    (0.71, 0.47),
                    (0.66, 0.62),
                    (0.56, 0.69),
                    (0.44, 0.69),
                    (0.34, 0.62),
                ),
                skin,
            ),
            Ellipse(0.5, 0.625, 0.125, 0.058, stubble),
            *_pair(Ellipse(0.355, 0.56, 0.035, 0.02, _BLUSH)),
            # Hair: a rounded crown, short sides and a fringe swept to the right.
            Ellipse(0.5, 0.27, 0.225, 0.13, hair),
            *_pair(Ellipse(0.3, 0.36, 0.035, 0.08, hair)),
            Polygon(
                (
                    (0.28, 0.37),
                    (0.31, 0.25),
                    (0.45, 0.19),
                    (0.62, 0.2),
                    (0.73, 0.3),
                    (0.72, 0.38),
                    (0.63, 0.31),
                    (0.5, 0.33),
                    (0.38, 0.36),
                ),
                hair,
            ),
            Ellipse(0.44, 0.22, 0.09, 0.026, hair_light),
        ),
        features=(
            # Nose and round glasses: two rims and a bridge.
            Polygon(((0.5, 0.49), (0.475, 0.545), (0.525, 0.545)), skin_shade),
            *_pair(Ring(0.418, 0.47, 0.062, 0.013, frame)),
            Polygon(
                ((0.474, 0.46), (0.526, 0.46), (0.526, 0.47), (0.474, 0.47)), frame
            ),
        ),
        brows=(
            Polygon(
                ((0.37, 0.405), (0.46, 0.395), (0.465, 0.413), (0.372, 0.422)), hair
            ),
            Polygon(
                ((0.63, 0.405), (0.54, 0.395), (0.535, 0.413), (0.628, 0.422)), hair
            ),
        ),
        eyes_open=opened,
        eyes_closed=closed,
        mouths=tuple(mouth(gap) for gap in (0.0, 0.016, 0.03, 0.046)),
        pivot=(0.5, 0.68),
    )


THEO = _theo()

# What a scenario's ``avatar:`` key and the ``--character`` flags name.
CHARACTERS: dict[str, Character] = {PIP.name: PIP, THEO.name: THEO}
DEFAULT_CHARACTER = PIP.name
