"""WebVTT caption generation for tutorial videos.

Every scenario step's narration text and (post-time-warp) timing are already
known at compose time — the scenario YAML has the text, and the timeline +
manifest have the timing the same way ``compose.py`` places narration audio.
This module reuses that data to emit one caption cue per step, so the
published video is accessible to viewers who can't (or don't want to) rely on
the narrated audio alone.
"""

from __future__ import annotations

from .scenario import Scenario
from .timewarp import plan_segments, output_time


def build_vtt(*, scenario: Scenario, locale: str, timeline: dict, manifest: dict) -> str:
    """Builds WebVTT captions, one cue per step, at its warped timestamp."""
    narration_by_id = {
        step["id"]: step["narration"] for step in manifest["steps"]
    }
    text_by_id = {step.id: step.narration[locale] for step in scenario.steps}
    segments = plan_segments(
        timeline,
        {
            step_id: narration["duration"]
            for step_id, narration in narration_by_id.items()
        },
    )

    lines = ["WEBVTT", ""]
    for step in timeline["steps"]:
        step_id = step["id"]
        text = text_by_id.get(step_id)
        if text is None:
            continue
        duration = narration_by_id[step_id]["duration"]
        start = output_time(segments, float(step["start"]))
        end = start + duration
        lines.append(f"{_format_timestamp(start)} --> {_format_timestamp(end)}")
        lines.append(" ".join(text.split()))
        lines.append("")
    return "\n".join(lines)


def _format_timestamp(seconds: float) -> str:
    seconds = max(seconds, 0.0)
    hours, remainder = divmod(seconds, 3600)
    minutes, remainder = divmod(remainder, 60)
    return f"{int(hours):02d}:{int(minutes):02d}:{remainder:06.3f}"
