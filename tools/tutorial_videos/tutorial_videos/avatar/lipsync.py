"""Turns narration audio into a mouth-openness track, one value per video frame.

Loudness-driven lip-sync: each frame's slice of the WAV gets an RMS level, and
the level, relative to the clip's own loud speech, picks one of the
character's mouth shapes. That works on any narration WAV — the Gemini clips
the workbench already renders included — without word timings. A TTS engine
that returns per-character timings could later feed visemes into the same
per-frame track.
"""

from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

from . import AvatarError
from .characters import MOUTH_LEVELS

# Fractions of the clip's loud-speech reference at which the mouth opens one
# level further (one threshold per open level).
DEFAULT_THRESHOLDS = (0.15, 0.4, 0.7)


def frame_levels(path: Path, fps: int) -> list[float]:
    """RMS loudness (0..1) of each video frame's slice of a 16-bit PCM WAV.

    Channels are not mixed down: the RMS over the interleaved samples is the
    frame's loudness either way."""
    if fps <= 0:
        raise ValueError(f"fps must be positive, got {fps}")
    with wave.open(str(path), "rb") as wav:
        width = wav.getsampwidth()
        channels = wav.getnchannels()
        rate = wav.getframerate()
        raw = wav.readframes(wav.getnframes())
    if width != 2:
        raise AvatarError(
            f"{path}: only 16-bit PCM WAV is supported, got {width * 8}-bit"
        )
    samples = struct.unpack(f"<{len(raw) // 2}h", raw)
    total = len(samples) // channels
    levels = []
    # Integer frame boundaries: float ones can round the last sample away.
    for index in range(-(-total * fps // rate)):
        start = index * rate // fps
        # A WAV with fewer samples than video frames per second still gives
        # every frame the sample playing at its moment.
        end = max(start + 1, min((index + 1) * rate // fps, total))
        chunk = samples[start * channels : end * channels]
        levels.append(math.sqrt(sum(v * v for v in chunk) / len(chunk)) / 32768)
    return levels


def mouth_track(
    levels: list[float],
    *,
    thresholds: tuple[float, ...] = DEFAULT_THRESHOLDS,
    close_hold: int = 2,
) -> list[int]:
    """Quantizes loudness into mouth levels 0..``MOUTH_LEVELS - 1``.

    Levels are judged against the clip's 95th-percentile loudness, so a quiet
    and a loud voice animate alike. The mouth only closes after
    ``close_hold`` quiet frames in a row: the short dips between syllables
    keep it moving instead of snapping shut on every one."""
    if len(thresholds) != MOUTH_LEVELS - 1:
        raise ValueError(f"need {MOUTH_LEVELS - 1} thresholds, got {len(thresholds)}")
    if not levels:
        return []
    reference = sorted(levels)[min(len(levels) - 1, int(0.95 * len(levels)))]
    if reference <= 0:
        return [0] * len(levels)
    track = []
    current = quiet = 0
    for level in levels:
        target = sum(1 for threshold in thresholds if level / reference >= threshold)
        if target:
            current, quiet = target, 0
        else:
            quiet += 1
            if quiet >= close_hold:
                current = 0
        track.append(current)
    return track
