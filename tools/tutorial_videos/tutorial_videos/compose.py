"""Composition stage: capture + TTS clips + timeline -> final MP4.

Thin host-side wrapper around the pinned OpenMontage checkout (an external
AGPLv3 dev tool, sibling directory like `lotti-docs`). All OpenMontage API
usage lives in `om_compose_driver.py`, executed with OpenMontage's own venv
python from its repo root; this module only assembles the job (timeline
offset math) and validates the result with ffprobe.
"""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

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
    tracks = [
        {
            "path": narration_by_id[step["id"]]["clip"],
            "start_seconds": round(step["start"], 3),
        }
        for step in timeline["steps"]
    ]

    root = openmontage_root(repo_root)
    job = {
        "tracks": tracks,
        "capture": {
            "path": str(capture),
            "in_seconds": round(offset, 3),
            "out_seconds": round(offset + timeline["total"], 3),
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

    _validate(output, expected_duration=timeline["total"], size=size)
    return output


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
