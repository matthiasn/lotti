"""Composition stage: capture + TTS clips + timeline -> final MP4.

Thin host-side wrapper around the pinned OpenMontage checkout (an external
AGPLv3 dev tool, sibling directory like `lotti-docs`). This module:

1. plans and applies the TIME WARP (see `timewarp.py`): pure-wait footage
   (cloud transcription / agent roundtrips) fast-forwards while the on-screen
   real-time HUD races — narration timestamps are remapped so the narrator
   keeps talking at normal speed over the sped-up footage;
2. hands the warped capture + remapped narration to OpenMontage
   (`om_compose_driver.py`, executed with OpenMontage's own venv python);
3. validates the result with ffprobe.
"""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

from .timewarp import Segment, output_time, plan_segments, total_output

TOOL_ROOT = Path(__file__).resolve().parents[1]
DRIVER = Path(__file__).resolve().parent / "om_compose_driver.py"


class ComposeError(RuntimeError):
    pass


def openmontage_root(repo_root: Path) -> Path:
    pin = (TOOL_ROOT / "config" / "openmontage.pin").read_text()
    root = repo_root.parent / "OpenMontage"
    if not (root / "tools").is_dir():
        raise ComposeError(
            f"OpenMontage checkout not found at {root} — clone and set it up "
            f"per {TOOL_ROOT / 'config' / 'openmontage.pin'}"
        )
    pinned = next(
        line.split("=", 1)[1].strip()
        for line in pin.splitlines()
        if line.startswith("commit=")
    )
    actual = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "HEAD"],
        capture_output=True,
        text=True,
        check=False,
    ).stdout.strip()
    if actual and actual != pinned:
        print(
            f"WARNING: OpenMontage at {actual[:12]} differs from pinned "
            f"{pinned[:12]} — composition output may drift."
        )
    return root


def compose_video(
    *,
    repo_root: Path,
    capture: Path,
    capture_start_epoch_ms: int,
    timeline_path: Path,
    manifest: dict,
    output: Path,
    size: tuple[int, int] = (1280, 720),
) -> Path:
    timeline = json.loads(timeline_path.read_text())
    offset = (timeline["zero_epoch_ms"] - capture_start_epoch_ms) / 1000
    if offset < 0:
        raise ComposeError(
            f"capture started after timeline zero (offset {offset:.2f}s)"
        )

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
    warped = _warp_capture(
        capture=capture,
        offset=offset,
        segments=segments,
        out_path=output.with_suffix(".warped.mkv"),
    )
    tracks = [
        {
            "path": narration_by_id[step["id"]]["clip"],
            "start_seconds": output_time(segments, float(step["start"])),
        }
        for step in timeline["steps"]
    ]
    warped_total = total_output(segments)

    root = openmontage_root(repo_root)
    job = {
        "tracks": tracks,
        "capture": {
            "path": str(warped),
            "in_seconds": 0,
            "out_seconds": warped_total,
        },
        "size": {"width": size[0], "height": size[1]},
        "mixed_out": str(output.with_suffix(".narration.wav")),
        "video_out": str(output),
    }
    result = subprocess.run(
        [str(root / ".venv" / "bin" / "python"), str(DRIVER), json.dumps(job)],
        cwd=root,
        env={**os.environ, "PYTHONPATH": str(root)},
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise ComposeError(
            f"OpenMontage compose failed:\n{result.stdout}\n{result.stderr}"
        )

    _validate(output, expected_duration=warped_total, size=size)
    return output


def _warp_capture(
    *,
    capture: Path,
    offset: float,
    segments: list[Segment],
    out_path: Path,
) -> Path:
    """Render the piecewise-speed edit of the capture (video only)."""
    parts = []
    labels = []
    for i, segment in enumerate(segments):
        start = offset + segment.start
        end = offset + segment.end
        parts.append(
            f"[0:v]trim=start={start:.3f}:end={end:.3f},"
            f"setpts=(PTS-STARTPTS)/{segment.speed:.4f}[v{i}]"
        )
        labels.append(f"[v{i}]")
    graph = (
        ";".join(parts)
        + f";{''.join(labels)}concat=n={len(segments)}:v=1:a=0,fps=30[v]"
    )
    result = subprocess.run(
        [
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
            "-i", str(capture),
            "-filter_complex", graph,
            "-map", "[v]",
            "-c:v", "libx264", "-preset", "ultrafast", "-crf", "18",
            "-pix_fmt", "yuv420p", "-an",
            str(out_path),
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise ComposeError(f"time-warp render failed: {result.stderr}")
    return out_path


def _validate(output: Path, *, expected_duration: float, size: tuple[int, int]) -> None:
    probe = json.loads(
        subprocess.run(
            [
                "ffprobe", "-v", "error", "-print_format", "json",
                "-show_format", "-show_streams", str(output),
            ],
            capture_output=True,
            text=True,
            check=True,
        ).stdout
    )
    duration = float(probe["format"]["duration"])
    video = next(s for s in probe["streams"] if s["codec_type"] == "video")
    has_audio = any(s["codec_type"] == "audio" for s in probe["streams"])
    problems = []
    if abs(duration - expected_duration) > max(2, expected_duration * 0.05):
        problems.append(
            f"duration {duration:.1f}s vs timeline {expected_duration:.1f}s"
        )
    if (video["width"], video["height"]) != size:
        problems.append(f"resolution {video['width']}x{video['height']}")
    if not has_audio:
        problems.append("no audio stream")
    if problems:
        raise ComposeError(f"{output}: {'; '.join(problems)}")
