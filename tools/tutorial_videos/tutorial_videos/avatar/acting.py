"""How the avatar acts: per frame, which face it pulls (``Pose``) and how its
head, face and body move (``Motion``), all derived from the narrator's
loudness track.

A presenter does not hold still between mouth shapes, so the narration is
read for its structure first:

- **phrases** — runs of speech, gaps under ``PHRASE_GAP`` merged;
- **onsets** — sharp rises in loudness, i.e. stressed syllables.

Each phrase gets its own head attitude (a tilt and a slight turn), so the
avatar re-poses as a speaker does. Onsets kick a springy nod and, for the
strongest, a quick brow lift. In a silence long enough for something to
happen in the app (``GLANCE_GAP``) the avatar turns to watch the app and is
back facing the viewer just before speaking again; a long watch is broken by
looks back at the viewer, and small nods acknowledge what happens. Underneath run breathing,
small eye darts, a little drift and blinks — random, at phrase starts and on
every glance.

Damped springs turn those targets into motion with ease, overshoot and
settle. Everything is seeded: the same narration always acts the same way.
"""

from __future__ import annotations

import math
import random
from dataclasses import dataclass

from .characters import GAZE_AT_APP, Pose
from .lipsync import NOISE_FLOOR, mouth_track
from .track import blink_track, pad_track

PHRASE_GAP = 0.3  # seconds of quiet that still count as one phrase
GLANCE_GAP = 1.0  # seconds of quiet worth a look at the app
WATCH_SECONDS = 4.0  # a long watch is broken by a look back this often…
LOOK_BACK_SECONDS = 1.2  # …for this long
BLINK_FRAMES_SECONDS = 0.12


@dataclass(frozen=True)
class Motion:
    """Offsets in badge units (1.0 = the badge's width) and a roll in
    radians, clockwise, about the character's neck pivot."""

    roll: float
    head: tuple[float, float]
    face: tuple[float, float]
    body: float


class Spring:
    """A damped spring, stepped in fixed substeps. ``zeta`` < 1 overshoots
    and settles."""

    def __init__(self, value: float, freq: float, zeta: float):
        self.x = value
        self.v = 0.0
        self.freq = freq
        self.zeta = zeta

    def step(self, target: float, dt: float) -> float:
        w = 2 * math.pi * self.freq
        h = dt / 4
        for _ in range(4):
            self.v += (w * w * (target - self.x) - 2 * self.zeta * w * self.v) * h
            self.x += self.v * h
        return self.x


def phrases(levels: list[float], fps: int) -> list[tuple[int, int]]:
    """(first, last) frame of each run of speech."""
    runs: list[list[int]] = []
    gap = max(1, round(PHRASE_GAP * fps))
    for i, level in enumerate(levels):
        if level <= NOISE_FLOOR:
            continue
        if runs and i - runs[-1][1] <= gap:
            runs[-1][1] = i
        else:
            runs.append([i, i])
    return [(a, b) for a, b in runs]


def onsets(levels: list[float], fps: int) -> list[tuple[int, float]]:
    """(frame, strength 0..1) of each stressed syllable: a jump in loudness
    against the clip's own loud speech, at least 0.4 s apart."""
    speech = sorted(level for level in levels if level > NOISE_FLOOR)
    if not speech:
        return []
    reference = speech[min(len(speech) - 1, int(0.95 * len(speech)))]
    spacing = round(0.4 * fps)
    found: list[tuple[int, float]] = []
    for i in range(1, len(levels)):
        jump = levels[i] - min(levels[max(0, i - 4) : i])
        if levels[i] < 0.35 * reference or jump < 0.22 * reference:
            continue
        strength = min(1.0, jump / reference)
        if found and i - found[-1][0] < spacing:
            if strength > found[-1][1]:
                found[-1] = (i, strength)
            continue
        found.append((i, strength))
    return found


def _noise(t: float, seed: float) -> float:
    """Smooth drift in -1..1: incommensurate sines."""
    return (
        0.5 * math.sin(t * 1.13 + seed * 7.1)
        + 0.3 * math.sin(t * 2.31 + seed * 3.7)
        + 0.2 * math.sin(t * 0.47 + seed * 1.9)
    )


def _glances(
    runs: list[tuple[int, int]], frames: int, fps: int
) -> list[tuple[int, int]]:
    """Frame spans in which the avatar watches the app: long silences, minus
    a beat after the last phrase and a beat to turn back before the next."""
    edges = [(-fps, -fps)] + runs + [(frames + fps, frames + fps)]
    out = []
    for (_, end), (start, _) in zip(edges, edges[1:]):
        first = max(0, end + round(0.3 * fps))
        last = min(frames, start - round(0.35 * fps))
        if (start - end) / fps < GLANCE_GAP or last - first < round(0.4 * fps):
            continue
        # A long watch looks back at the viewer every WATCH_SECONDS.
        watch, back = round(WATCH_SECONDS * fps), round(LOOK_BACK_SECONDS * fps)
        while last - first > watch + back + round(1.0 * fps):
            out.append((first, first + watch))
            first += watch + back
        out.append((first, last))
    return out


def act(
    levels: list[float], fps: int, frames: int, *, seed: int = 7
) -> tuple[list[Pose], list[Motion]]:
    """Poses and motion for ``frames`` frames of narration ``levels``."""
    rng = random.Random(seed)
    dt = 1.0 / fps
    mouths = pad_track(mouth_track(levels), frames)[:frames]
    runs = phrases(levels, fps)
    glances = _glances(runs, frames, fps)
    stresses = dict(onsets(levels, fps))
    strong = sorted(stresses.values())[int(0.7 * len(stresses))] if stresses else 2.0

    # Head attitude per phrase: alternate the tilt side, vary the turn.
    attitude = []
    side = rng.choice((-1, 1))
    for _ in runs:
        side = -side
        attitude.append((side * rng.uniform(0.03, 0.08), rng.uniform(-0.4, 0.4)))

    blinks = blink_track(frames, fps, seed=seed)
    blink_len = max(1, round(BLINK_FRAMES_SECONDS * fps))
    for frame in [a for a, _ in runs] + [g for span in glances for g in span]:
        for i in range(max(0, frame - 1), min(frames, frame - 1 + blink_len)):
            blinks[i] = True

    roll, yaw, pitch = Spring(0, 1.3, 0.7), Spring(0, 1.5, 0.75), Spring(0, 1.8, 0.7)
    nod, energy = Spring(0, 2.4, 0.4), Spring(0, 6.0, 1.0)
    gaze, next_dart, brows_until = 0, 0, -1
    run_index = 0
    poses: list[Pose] = []
    motions: list[Motion] = []
    for i in range(frames):
        t = i * dt
        while run_index < len(runs) and runs[run_index][1] < i:
            run_index += 1
        speaking = run_index < len(runs) and runs[run_index][0] <= i
        watching = any(a <= i < b for a, b in glances)
        if watching:
            targets = (-0.05, -0.75, 0.5)
        elif speaking:
            tilt, turn = attitude[run_index]
            targets = (tilt, turn, 0.0)
        else:
            targets = (0.0, 0.0, 0.0)
        if watching and (i - next_dart) % round(2.5 * fps) == 0:
            nod.v += 1.6  # "mm-hm"
        if i in stresses:
            nod.v += 4.0 * stresses[i]
            if stresses[i] >= strong:
                brows_until = i + round(0.4 * fps)
        if speaking and runs[run_index][0] == i:
            brows_until = max(brows_until, i + round(0.25 * fps))
        if watching:
            gaze = GAZE_AT_APP
        elif i >= next_dart or gaze == GAZE_AT_APP:
            gaze = rng.choices((0, 1, 2), weights=(6, 2, 2))[0]
            next_dart = i + round(rng.uniform(0.7, 1.8) * fps)

        level = levels[i] if i < len(levels) else 0.0
        r = roll.step(targets[0], dt) + 0.015 * _noise(t * 0.5, 1)
        y = yaw.step(targets[1], dt) + 0.06 * _noise(t * 0.4, 2)
        p = pitch.step(targets[2], dt)
        n = nod.step(0.0, dt)
        e = energy.step(min(1.0, level * 4), dt)
        breath = 0.0035 * math.sin(2 * math.pi * t / 4.2)
        head = (y * 0.008, breath + n * 0.014 + p * 0.007 - e * 0.006)
        face = (head[0] + y * 0.03, head[1] + p * 0.014 + n * 0.01)
        motions.append(Motion(r, head, face, breath))
        closed = blinks[i]
        poses.append(Pose(mouths[i], closed, 0 if closed else gaze, i < brows_until))
    return poses, motions
