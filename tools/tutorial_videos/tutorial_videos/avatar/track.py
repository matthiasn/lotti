"""Combines the mouth track with blinking into per-frame poses, and collapses
them into runs — a clip only needs one image per run, not one per frame."""

from __future__ import annotations

import random

from .characters import Pose


def blink_track(
    frames: int,
    fps: int,
    *,
    seed: int = 7,
    interval: tuple[float, float] = (2.5, 5.5),
    blink_seconds: float = 0.12,
) -> list[bool]:
    """Which frames have the eyes closed: a short blink every few seconds.

    Seeded, so the same narration always blinks at the same moments and a
    rebuild is byte-for-byte reproducible."""
    rng = random.Random(seed)
    closed = [False] * frames
    length = max(1, round(blink_seconds * fps))
    at = rng.uniform(*interval)
    while (start := int(at * fps)) < frames:
        for index in range(start, min(frames, start + length)):
            closed[index] = True
        at += rng.uniform(*interval)
    return closed


def pad_track(mouths: list[int], frames: int) -> list[int]:
    """Extends ``mouths`` with a closed mouth up to ``frames`` long — the
    avatar keeps idling (and blinking) after the narration ends."""
    return mouths + [0] * (frames - len(mouths))


def pose_track(mouths: list[int], blinks: list[bool]) -> list[Pose]:
    if len(mouths) != len(blinks):
        raise ValueError(
            f"mouth track has {len(mouths)} frames, blink track {len(blinks)}"
        )
    return [Pose(mouth, closed) for mouth, closed in zip(mouths, blinks)]


def run_lengths(poses: list[Pose]) -> list[tuple[Pose, int]]:
    """Consecutive equal poses as (pose, frame count) pairs."""
    runs: list[tuple[Pose, int]] = []
    for pose in poses:
        if runs and runs[-1][0] == pose:
            runs[-1] = (pose, runs[-1][1] + 1)
        else:
            runs.append((pose, 1))
    return runs
