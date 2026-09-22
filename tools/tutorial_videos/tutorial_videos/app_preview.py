"""App Store App Preview narration: this workbench's TTS pass, laid over the
simulator recording that ``tool/store_screenshots/ios_preview.sh`` makes.

The preview is not a tutorial. It runs in real time — the walk never waits on
the cloud, so nothing is time-warped — and it needs no OpenMontage: the clips
only have to land at the right moments on one track. ios_preview.sh runs
three commands around the recording (from ``tools/tutorial_videos``)::

    python3 -m tutorial_videos.app_preview pacing  --manifest M
    python3 -m tutorial_videos.app_preview cut     --timeline T --recorder-start MS
    python3 -m tutorial_videos.app_preview narrate --manifest M --timeline T \\
        --recorder-start MS --out narration.wav

``pacing`` turns the TTS manifest into the walk's ``LOTTI_PREVIEW_BEATS``
dart-define: each beat's floor by the tutorial driver's rule,
``max(min_duration, narration + pad)``, as ``id=ms`` pairs. ``cut`` reads the
timeline the walk hands over and prints the slice between its marks as
``<start> <length>``, seconds on the recording's clock. ``narrate`` prints the
same and writes the narration track on that clock — each clip where its beat
began — for ``app_preview.sh`` to cut alongside the video.

The timeline is in epoch milliseconds. A simulator runs on its host's clock,
so the walk's timestamps and the recorder's start compare directly, with no
log transport in between to add latency.

Stdlib only: the cut must work for a silent preview too, built without the
TTS toolchain (and its yaml dependency) installed.
"""

from __future__ import annotations

import argparse
import json
import sys
import wave
from dataclasses import dataclass
from pathlib import Path

# TutorialDriver._postNarrationPad in
# integration_test/tutorial/tutorial_harness.dart — the same beat after a
# line in both kinds of video.
POST_NARRATION_PAD = 0.6

# App Store Connect's bounds for one App Preview, in seconds.
MAX_PREVIEW_SECONDS = 30.0


class PreviewError(ValueError):
    """The narration does not fit the preview, or its inputs disagree."""


@dataclass(frozen=True)
class Cut:
    """The slice of the recording that becomes the preview, in seconds on
    the recording's clock."""

    start: float
    length: float

    @property
    def end(self) -> float:
        return self.start + self.length


@dataclass(frozen=True)
class Placement:
    """One narration clip, placed where its beat began on the recording."""

    beat: str
    clip: Path
    start: float
    duration: float

    @property
    def end(self) -> float:
        return self.start + self.duration


def beat_floors(manifest: dict) -> dict[str, float]:
    """Each beat's minimum length in seconds: its choreography's own
    (``min_duration``) or its line plus the pad, whichever is longer."""
    return {
        step["id"]: max(
            float(step["min_duration"]),
            float(step["narration"]["duration"]) + POST_NARRATION_PAD,
        )
        for step in manifest["steps"]
    }


def pacing_define(manifest: dict) -> str:
    """The ``LOTTI_PREVIEW_BEATS`` value for [manifest]'s narration.

    Fails when the floors alone overrun the preview — before a multi-minute
    build and recording, rather than after it in ``app_preview.sh``.
    """
    floors = beat_floors(manifest)
    total = sum(floors.values())
    if total > MAX_PREVIEW_SECONDS:
        longest = max(floors, key=floors.__getitem__)
        raise PreviewError(
            f"the {manifest['locale']} narration needs {total:.1f}s of beats, "
            f"and an App Preview runs at most {MAX_PREVIEW_SECONDS:.0f}s — "
            f"shorten its lines (the longest beat is '{longest}', "
            f"{floors[longest]:.1f}s)"
        )
    return ",".join(
        f"{beat}={round(seconds * 1000)}" for beat, seconds in floors.items()
    )


def _on_recording(epoch_ms: int, recorder_start_epoch_ms: int) -> float:
    return (int(epoch_ms) - int(recorder_start_epoch_ms)) / 1000


def plan_cut(timeline: dict, recorder_start_epoch_ms: int) -> Cut:
    """The slice between the walk's cut marks, on the recording's clock."""
    start = _on_recording(
        timeline["cut"]["start_epoch_ms"], recorder_start_epoch_ms
    )
    end = _on_recording(timeline["cut"]["end_epoch_ms"], recorder_start_epoch_ms)
    if start < 0:
        raise PreviewError(
            f"the cut starts {-start:.2f}s before the recorder's first frame"
        )
    if end <= start:
        raise PreviewError(f"the cut ends ({end:.2f}s) before it starts ({start:.2f}s)")
    return Cut(start=start, length=end - start)


def place_narration(
    manifest: dict, timeline: dict, recorder_start_epoch_ms: int
) -> list[Placement]:
    """Every line at the moment its beat began, checked to stay inside the
    cut and clear of the next line.

    An overlap means the walk ran without this manifest's pacing — built
    with a stale or empty ``LOTTI_PREVIEW_BEATS``.
    """
    cut = plan_cut(timeline, recorder_start_epoch_ms)
    beats = {beat["id"]: beat for beat in timeline["beats"]}
    narrated = [step["id"] for step in manifest["steps"]]
    if set(beats) != set(narrated):
        raise PreviewError(
            f"the walk's beats {sorted(beats)} are not the narrated ones "
            f"{sorted(narrated)} — keep config/scenarios/app_store_preview.yaml "
            "in step with integration_test/store_preview_test.dart"
        )
    placements = sorted(
        (
            Placement(
                beat=step["id"],
                clip=Path(step["narration"]["clip"]),
                start=_on_recording(
                    beats[step["id"]]["start_epoch_ms"], recorder_start_epoch_ms
                ),
                duration=float(step["narration"]["duration"]),
            )
            for step in manifest["steps"]
        ),
        key=lambda placement: placement.start,
    )
    if placements[0].start < cut.start:
        raise PreviewError(
            f"the '{placements[0].beat}' line starts before the cut does"
        )
    for placement, following in zip(placements, placements[1:]):
        if placement.end > following.start:
            raise PreviewError(
                f"the '{placement.beat}' line runs "
                f"{placement.end - following.start:.2f}s into "
                f"'{following.beat}' — was the walk paced with this manifest?"
            )
    if placements[-1].end > cut.end:
        raise PreviewError(
            f"the '{placements[-1].beat}' line runs "
            f"{placements[-1].end - cut.end:.2f}s past the end of the cut"
        )
    return placements


def render_track(placements: list[Placement], *, length: float, out: Path) -> Path:
    """Write one mono track, at least [length] seconds long, holding each
    clip at its start and silence everywhere else.

    The clips must share the TTS engine's format (16-bit mono, one sample
    rate); the track keeps it, and ``app_preview.sh`` resamples to the
    stereo 48 kHz App Store Connect takes.
    """
    if not placements:
        raise PreviewError("no narration to place")
    rate: int | None = None
    pcm: list[tuple[Placement, bytes]] = []
    for placement in placements:
        with wave.open(str(placement.clip), "rb") as clip:
            if clip.getnchannels() != 1 or clip.getsampwidth() != 2:
                raise PreviewError(
                    f"{placement.clip}: not 16-bit mono, the TTS engine's format"
                )
            if rate is None:
                rate = clip.getframerate()
            elif clip.getframerate() != rate:
                raise PreviewError(
                    f"{placement.clip}: {clip.getframerate()} Hz, the other "
                    f"clips are {rate} Hz"
                )
            pcm.append((placement, clip.readframes(clip.getnframes())))
    assert rate is not None

    offsets = [(round(placement.start * rate) * 2, data) for placement, data in pcm]
    size = max(
        round(length * rate) * 2,
        max(offset + len(data) for offset, data in offsets),
    )
    track = bytearray(size)
    for offset, data in offsets:
        track[offset : offset + len(data)] = data

    out.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(out), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(rate)
        wav.writeframes(bytes(track))
    return out


def _read_json(path: Path) -> dict:
    return json.loads(path.read_text())


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="tutorial_videos.app_preview")
    sub = parser.add_subparsers(dest="command", required=True)
    pacing = sub.add_parser("pacing")
    pacing.add_argument("--manifest", type=Path, required=True)
    for name in ("cut", "narrate"):
        command = sub.add_parser(name)
        command.add_argument("--timeline", type=Path, required=True)
        command.add_argument("--recorder-start", type=int, required=True)
        if name == "narrate":
            command.add_argument("--manifest", type=Path, required=True)
            command.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)

    try:
        if args.command == "pacing":
            print(pacing_define(_read_json(args.manifest)))
            return 0
        timeline = _read_json(args.timeline)
        cut = plan_cut(timeline, args.recorder_start)
        if args.command == "narrate":
            placements = place_narration(
                _read_json(args.manifest), timeline, args.recorder_start
            )
            render_track(placements, length=cut.end, out=args.out)
        print(f"{cut.start:.3f} {cut.length:.3f}")
        return 0
    except (PreviewError, KeyError, FileNotFoundError, json.JSONDecodeError) as err:
        print(f"ERROR: {type(err).__name__}: {err}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
