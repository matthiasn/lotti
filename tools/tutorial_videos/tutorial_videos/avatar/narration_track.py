"""The avatar's loudness track from the narrator clips alone, each placed
where ``compose.py`` places it on the warped output clock.

The narration mix ``compose.py`` writes beside the video also carries the
dictation clip — the "user" speaking into the app — so lip-syncing to that
file makes the avatar mouth the user's words too. This module reads the
manifest's per-step narrator clips instead and drops each one at its step's
warped start, exactly as the mix and the captions do; the dictation clips are
never opened.
"""

from __future__ import annotations

import math
from pathlib import Path

from ..timewarp import output_time, plan_segments, total_output
from .lipsync import frame_levels


def narration_levels(manifest: dict, timeline: dict, fps: int) -> list[float]:
    """Per-frame loudness (0..1) of the narrator across the whole warped video.

    Each timeline step's narrator clip starts at the step's warped start;
    where two clips overlap, the louder frame wins; a step the manifest has
    no clip for contributes nothing. The track covers the warped total, and
    grows if a clip runs past it."""
    narration_by_id = {
        step["id"]: step["narration"] for step in manifest["steps"]
    }
    segments = plan_segments(
        timeline,
        {
            step_id: narration["duration"]
            for step_id, narration in narration_by_id.items()
        },
    )
    levels = [0.0] * math.ceil(total_output(segments) * fps)
    for step in timeline["steps"]:
        narration = narration_by_id.get(step["id"])
        if narration is None:
            continue
        first = round(output_time(segments, float(step["start"])) * fps)
        clip = frame_levels(Path(narration["clip"]), fps)
        levels.extend([0.0] * (first + len(clip) - len(levels)))
        for index, level in enumerate(clip, first):
            levels[index] = max(levels[index], level)
    return levels
