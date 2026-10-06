"""Renders the avatar into video: a standalone preview of one character talking,
or the round badge overlaid in the corner of a finished tutorial MP4.

The clip is never rendered frame by frame. Each distinct pose becomes one PNG,
and an ffconcat list holds every run of identical frames as one entry with its
duration, so ffmpeg rebuilds the timeline from a few dozen images.
"""

from __future__ import annotations

import json
import math
import subprocess
from pathlib import Path

from . import AvatarError
from .characters import BADGE, Character, Pose
from .lipsync import frame_levels, mouth_track
from .raster import encode_png, rasterize
from .track import blink_track, pad_track, pose_track, run_lengths

DEFAULT_FPS = 30

# The badge's diameter as a share of the video height, and its gap to the
# bottom-right corner as a share of the badge.
BADGE_HEIGHT_FRACTION = 0.22
BADGE_MARGIN_FRACTION = 0.15


def pose_image_name(character: Character, pose: Pose) -> str:
    eyes = "closed" if pose.eyes_closed else "open"
    return f"{character.name}_mouth{pose.mouth}_eyes_{eyes}.png"


def render_pose_images(
    character: Character, poses: list[Pose], size: int, out_dir: Path
) -> dict[Pose, Path]:
    """Writes one PNG per distinct pose in ``poses``."""
    out_dir.mkdir(parents=True, exist_ok=True)
    images = {}
    for pose in dict.fromkeys(poses):
        path = out_dir / pose_image_name(character, pose)
        rgba = rasterize(character.shapes(pose), size, clip=BADGE)
        path.write_bytes(encode_png(rgba, size, size))
        images[pose] = path
    return images


def write_concat(
    runs: list[tuple[Pose, int]], images: dict[Pose, Path], fps: int, path: Path
) -> None:
    """Writes the ffconcat list playing each run's image for its duration.

    The image files must sit next to ``path``: entries are resolved relative
    to the list itself."""
    if not runs:
        raise AvatarError(
            "the avatar track is empty — is the narration silent and zero-length?"
        )
    lines = ["ffconcat version 1.0"]
    for pose, frames in runs:
        lines.append(f"file '{images[pose].name}'")
        lines.append(f"duration {frames / fps:.6f}")
    # The concat demuxer ignores the last entry's duration unless that file
    # is listed once more.
    lines.append(f"file '{images[runs[-1][0]].name}'")
    path.write_text("\n".join(lines) + "\n")


def build_track(
    character: Character,
    narration: Path,
    *,
    fps: int,
    size: int,
    work_dir: Path,
    min_frames: int = 0,
    seed: int = 7,
) -> Path:
    """Lip-syncs ``character`` to ``narration`` (blinking, idling to at least
    ``min_frames``) and returns the ffconcat list of its pose images."""
    mouths = pad_track(mouth_track(frame_levels(narration, fps)), min_frames)
    poses = pose_track(mouths, blink_track(len(mouths), fps, seed=seed))
    images = render_pose_images(character, poses, size, work_dir)
    concat = work_dir / f"{character.name}.ffconcat"
    write_concat(run_lengths(poses), images, fps, concat)
    return concat


def badge_size(video_height: int, fraction: float = BADGE_HEIGHT_FRACTION) -> int:
    """The badge diameter for a video this tall — even, as yuv420p needs."""
    return max(2, int(video_height * fraction) // 2 * 2)


def preview_command(
    *, concat: Path, narration: Path, out: Path, fps: int, canvas: int
) -> list[str]:
    """The ffmpeg call for a square preview: the badge centered on a plain
    backdrop, talking along with ``narration``."""
    return [
        "ffmpeg",
        "-y",
        "-loglevel",
        "error",
        "-f",
        "lavfi",
        "-i",
        f"color=c=0xF4F1EA:s={canvas}x{canvas}:r={fps}",
        "-f",
        "concat",
        "-safe",
        "0",
        "-i",
        str(concat),
        "-i",
        str(narration),
        "-filter_complex",
        "[1:v]format=rgba[badge];"
        "[0:v][badge]overlay=(W-w)/2:(H-h)/2:shortest=1,format=yuv420p[v]",
        "-map",
        "[v]",
        "-map",
        "2:a",
        "-r",
        str(fps),
        "-c:v",
        "libx264",
        "-c:a",
        "aac",
        "-shortest",
        str(out),
    ]


def overlay_command(
    *, video: Path, concat: Path, out: Path, fps: int, margin: int
) -> list[str]:
    """The ffmpeg call laying the badge into ``video``'s bottom-right corner,
    keeping its audio untouched.

    ``shortest=1`` ends the output with the tutorial: without it, ffmpeg
    freezes the tutorial's last frame for as long as the badge track runs.
    The track is always built a little longer than the video, so only the
    badge is ever cut short."""
    return [
        "ffmpeg",
        "-y",
        "-loglevel",
        "error",
        "-i",
        str(video),
        "-f",
        "concat",
        "-safe",
        "0",
        "-i",
        str(concat),
        "-filter_complex",
        f"[1:v]format=rgba[badge];"
        f"[0:v][badge]overlay=W-w-{margin}:H-h-{margin}:shortest=1,"
        f"format=yuv420p[v]",
        "-map",
        "[v]",
        "-map",
        "0:a?",
        "-r",
        str(fps),
        "-c:v",
        "libx264",
        "-c:a",
        "copy",
        str(out),
    ]


def run_ffmpeg(command: list[str]) -> None:
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        raise AvatarError(f"{command[0]} failed:\n{result.stderr.strip()}")


def probe_video(video: Path) -> tuple[int, int, float]:
    """(width, height, duration in seconds) of ``video``'s first video stream."""
    result = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=width,height:format=duration",
            "-of",
            "json",
            str(video),
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise AvatarError(f"ffprobe failed on {video}:\n{result.stderr.strip()}")
    info = json.loads(result.stdout)
    stream = info["streams"][0]
    return (
        int(stream["width"]),
        int(stream["height"]),
        float(info["format"]["duration"]),
    )


def render_preview(
    character: Character,
    narration: Path,
    out: Path,
    *,
    size: int,
    work_dir: Path,
    fps: int = DEFAULT_FPS,
) -> Path:
    """A ``size``-pixel square clip of ``character`` saying ``narration``."""
    concat = build_track(character, narration, fps=fps, size=size, work_dir=work_dir)
    out.parent.mkdir(parents=True, exist_ok=True)
    run_ffmpeg(
        preview_command(
            concat=concat, narration=narration, out=out, fps=fps, canvas=size
        )
    )
    return out


def render_overlay(
    character: Character,
    video: Path,
    narration: Path,
    out: Path,
    *,
    work_dir: Path,
    fps: int = DEFAULT_FPS,
) -> Path:
    """``video`` with ``character`` lip-syncing ``narration`` in its corner.

    The badge is sized from the video's height, so a desktop and a mobile
    build get the same proportions, and idles to the video's very end — its
    track runs one frame past the video, so ``overlay_command`` always cuts
    the badge, never the tutorial."""
    _, height, duration = probe_video(video)
    size = badge_size(height)
    concat = build_track(
        character,
        narration,
        fps=fps,
        size=size,
        work_dir=work_dir,
        min_frames=math.ceil(duration * fps) + 1,
    )
    out.parent.mkdir(parents=True, exist_ok=True)
    run_ffmpeg(
        overlay_command(
            video=video,
            concat=concat,
            out=out,
            fps=fps,
            margin=round(size * BADGE_MARGIN_FRACTION),
        )
    )
    return out
