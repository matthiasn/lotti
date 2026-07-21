"""Time-warp planning: fast-forward pure-wait footage, never the narrator.

The Dart harness records wait spans (cloud transcription / agent roundtrips)
in ``timeline.json``. This module plans a piecewise-speed edit of the capture:
wait spans play fast (up to ``max_speed``), everything else at 1x, with two
constraints that protect the narration:

* a short lead-in of each wait stays at 1x so UI settle remains readable;
* each step's narration must still FIT between the (remapped) start of its
  step and the start of the next step's narration — the compressor slows a
  span down rather than let narrator voices overlap.

All functions are pure (unit-tested); the ffmpeg execution lives in
``compose.py``.
"""

from __future__ import annotations

from dataclasses import dataclass

MAX_SPEED = 8.0
LEAD_IN_SECONDS = 0.6
NARRATION_GAP_SECONDS = 0.5


@dataclass(frozen=True)
class Segment:
    start: float
    end: float
    speed: float

    @property
    def input_duration(self) -> float:
        return self.end - self.start

    @property
    def output_duration(self) -> float:
        return self.input_duration / self.speed


def plan_segments(
    timeline: dict,
    narration_by_step: dict[str, float],
    *,
    max_speed: float = MAX_SPEED,
) -> list[Segment]:
    """Plan alternating 1x / fast segments covering [0, total]."""
    total = float(timeline["total"])
    steps = timeline["steps"]
    waits = sorted(
        (float(w["start"]), float(w["end"])) for w in timeline.get("waits", [])
    )

    fast_spans: list[Segment] = []
    for wait_start, wait_end in waits:
        start = wait_start + LEAD_IN_SECONDS
        if wait_end - start < 1.0:
            continue
        step = _covering_step(steps, start)
        if step is None:
            continue
        speed = _clamped_speed(
            step=step,
            narration=narration_by_step.get(step["id"], 0.0),
            span=(start, wait_end),
            max_speed=max_speed,
        )
        if speed > 1.05:
            fast_spans.append(Segment(start=start, end=wait_end, speed=speed))

    segments: list[Segment] = []
    cursor = 0.0
    for span in fast_spans:
        if span.start > cursor:
            segments.append(Segment(start=cursor, end=span.start, speed=1.0))
        segments.append(span)
        cursor = span.end
    if cursor < total:
        segments.append(Segment(start=cursor, end=total, speed=1.0))
    return segments


def _covering_step(steps: list[dict], t: float) -> dict | None:
    for step in steps:
        if float(step["start"]) <= t < float(step["end"]):
            return step
    return None


def _clamped_speed(
    *,
    step: dict,
    narration: float,
    span: tuple[float, float],
    max_speed: float,
) -> float:
    """Largest speed that keeps the step's output long enough for its
    narration (plus a breathing gap) to finish before the next step."""
    span_length = span[1] - span[0]
    step_length = float(step["end"]) - float(step["start"])
    unwarped = step_length - span_length
    required_output = narration + NARRATION_GAP_SECONDS - unwarped
    min_span_output = max(span_length / max_speed, required_output, 0.2)
    return max(1.0, span_length / min_span_output)


def output_time(segments: list[Segment], t: float) -> float:
    """Map an input (capture) timestamp to the warped output timestamp."""
    out = 0.0
    for segment in segments:
        if t <= segment.start:
            break
        if t >= segment.end:
            out += segment.output_duration
        else:
            out += (t - segment.start) / segment.speed
            break
    return round(out, 3)


def total_output(segments: list[Segment]) -> float:
    return round(sum(s.output_duration for s in segments), 3)
