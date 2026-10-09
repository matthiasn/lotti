"""Renders the avatar into video: a standalone preview of one character talking,
or the round badge overlaid in the corner of a finished tutorial MP4.

The badge is never drawn frame by frame in Python. Its layers are drawn once,
at twice the badge size: the background, the body, the head (on a larger
canvas centred on the neck pivot) and the round mask and ring — plus one face
image per distinct pose (mouth, eyes, gaze,
brows), listed in an ffconcat file that holds each run of identical frames as
one entry. The acting (``acting.py``) becomes an ffmpeg ``sendcmd`` file that
rolls the head and face about the neck and shifts the layers every frame.
ffmpeg composites, clips the result round, scales it down (which turns
whole-pixel steps into smooth sub-pixel motion), slides it in at the start and
lays it into the video.
"""

from __future__ import annotations

import json
import math
import subprocess
from dataclasses import dataclass, replace
from pathlib import Path

from . import AvatarError
from .acting import Motion, act
from .characters import BADGE, RING, Character, Pose
from .lipsync import frame_levels
from .raster import Polygon, Ring, encode_png, rasterize
from .track import run_lengths

DEFAULT_FPS = 30
SUPERSAMPLE = 2

# The badge's diameter as a share of the video height, and its gap to the
# corner as a share of the badge.
BADGE_HEIGHT_FRACTION = 0.22
BADGE_MARGIN_FRACTION = 0.15

# The badge slides in from its side of the frame over this long, after a beat.
ENTER_DELAY = 0.3
ENTER_SECONDS = 0.6

# Where the badge sits: ffmpeg overlay ``x:y`` expressions, with ``{m}`` for
# the margin and ``{slide}`` for the entrance offset. Top right is the default
# — on desktop the bottom-right corner holds the form's primary button
# (Create, Save), on mobile the bottom navigation, while the top row carries
# only the page title on the left and the real-time HUD in the centre.
POSITIONS = {
    "top_right": "W-w-{m}+{slide}:{m}",
    "top_left": "{m}-{slide}:{m}",
    "bottom_right": "W-w-{m}+{slide}:H-h-{m}",
    "bottom_left": "{m}-{slide}:H-h-{m}",
}
DEFAULT_POSITION = "top_right"


@dataclass(frozen=True)
class BadgeTrack:
    """Everything ffmpeg needs to animate one badge, in one folder."""

    background: Path
    body: Path
    head: Path
    faces: Path  # ffconcat of face images
    commands: Path  # sendcmd file
    ring: Path
    mask: Path
    size: int  # final badge diameter in pixels
    origin: tuple[int, int]  # top-left of the head and face layers, supersampled


def pose_image_name(character: Character, pose: Pose) -> str:
    eyes = "closed" if pose.eyes_closed else f"open{pose.gaze}"
    brows = "_brows" if pose.brows_up else ""
    return f"{character.name}_mouth{pose.mouth}_eyes_{eyes}{brows}.png"


def _write(path: Path, shapes, size: int) -> Path:
    path.write_bytes(encode_png(rasterize(shapes, size), size, size))
    return path


# The head and face layers get a canvas this much larger than the badge, so
# nothing above or beside the neck pivot is cut off when centred on it and
# rolled.
HEAD_CANVAS = 1.5


def head_canvas(size: int) -> int:
    """The pixel size of the head and face layers for a ``size`` badge."""
    return round(size * HEAD_CANVAS) // 2 * 2


def _centred(character: Character, shapes) -> list:
    """``shapes`` scaled into the larger head canvas with the neck pivot at its
    centre, which is where ffmpeg's rotate turns them about."""
    px, py = character.pivot
    k = 1 / HEAD_CANVAS

    def place(x: float, y: float) -> tuple[float, float]:
        return (x - px) * k + 0.5, (y - py) * k + 0.5

    out = []
    for shape in shapes:
        if isinstance(shape, Polygon):
            out.append(
                Polygon(tuple(place(x, y) for x, y in shape.points), shape.color)
            )
        elif isinstance(shape, Ring):
            cx, cy = place(shape.cx, shape.cy)
            out.append(
                replace(
                    shape, cx=cx, cy=cy, radius=shape.radius * k, width=shape.width * k
                )
            )
        else:
            cx, cy = place(shape.cx, shape.cy)
            out.append(replace(shape, cx=cx, cy=cy, rx=shape.rx * k, ry=shape.ry * k))
    return out


def render_layers(character: Character, size: int, out_dir: Path) -> dict[str, Path]:
    """The still layers, drawn once at ``size`` pixels square."""
    out_dir.mkdir(parents=True, exist_ok=True)
    square = ((0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0))
    name = character.name
    white = (255, 255, 255, 255)
    return {
        "background": _write(
            out_dir / f"{name}_background.png",
            [Polygon(square, character.background)],
            size,
        ),
        "body": _write(out_dir / f"{name}_body.png", character.body, size),
        "head": _write(
            out_dir / f"{name}_head.png",
            _centred(character, character.head),
            head_canvas(size),
        ),
        "ring": _write(out_dir / f"{name}_ring.png", [RING], size),
        "mask": _write(
            out_dir / f"{name}_mask.png",
            [Polygon(square, (0, 0, 0, 255)), replace(BADGE, color=white)],
            size,
        ),
    }


def render_pose_images(
    character: Character, poses: list[Pose], size: int, out_dir: Path
) -> dict[Pose, Path]:
    """One face-layer PNG per distinct pose in ``poses``, pivot-centred on the
    head canvas for a ``size`` badge."""
    out_dir.mkdir(parents=True, exist_ok=True)
    images = {}
    for pose in dict.fromkeys(poses):
        path = out_dir / pose_image_name(character, pose)
        _write(
            path, _centred(character, character.face_shapes(pose)), head_canvas(size)
        )
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


def write_commands(
    motions: list[Motion], fps: int, size: int, origin: tuple[int, int], path: Path
) -> None:
    """The sendcmd file moving the layers each frame. Offsets become whole
    supersampled pixels; a frame only lists what changed."""
    lines = []
    last: dict[str, str] = {}
    for i, m in enumerate(motions):
        values = {
            "rotate@head a": f"{m.roll:.5f}",
            "rotate@face a": f"{m.roll:.5f}",
            "overlay@body y": str(round(m.body * size)),
            "overlay@head x": str(origin[0] + round(m.head[0] * size)),
            "overlay@head y": str(origin[1] + round(m.head[1] * size)),
            "overlay@face x": str(origin[0] + round(m.face[0] * size)),
            "overlay@face y": str(origin[1] + round(m.face[1] * size)),
        }
        changed = [f"{k} {v}" for k, v in values.items() if last.get(k) != v]
        last.update(values)
        if changed:
            lines.append(f"{i / fps:.4f} " + ", ".join(changed) + ";")
    path.write_text("\n".join(lines) + "\n")


def build_track(
    character: Character,
    levels: list[float],
    *,
    fps: int,
    size: int,
    work_dir: Path,
    min_frames: int = 0,
    seed: int = 7,
) -> BadgeTrack:
    """Acts ``character`` out to the per-frame loudness ``levels`` (idling to
    at least ``min_frames``) and writes everything the badge needs."""
    frames = max(len(levels), min_frames)
    if frames == 0:
        raise AvatarError(
            "the avatar track is empty — is the narration silent and zero-length?"
        )
    poses, motions = act(levels, fps, frames, seed=seed)
    big = size * SUPERSAMPLE
    layers = render_layers(character, big, work_dir)
    images = render_pose_images(character, poses, big, work_dir)
    faces = work_dir / f"{character.name}.ffconcat"
    write_concat(run_lengths(poses), images, fps, faces)
    half = head_canvas(big) // 2
    origin = (
        round(character.pivot[0] * big) - half,
        round(character.pivot[1] * big) - half,
    )
    commands = work_dir / f"{character.name}.cmd"
    write_commands(motions, fps, big, origin, commands)
    return BadgeTrack(
        faces=faces, commands=commands, size=size, origin=origin, **layers
    )


def badge_size(video_height: int, fraction: float = BADGE_HEIGHT_FRACTION) -> int:
    """The badge diameter for a video this tall — even, as yuv420p needs."""
    return max(2, int(video_height * fraction) // 2 * 2)


def _badge_inputs(track: BadgeTrack, fps: int) -> list[str]:
    still = ["-loop", "1", "-framerate", str(fps), "-i"]
    return [
        *still, str(track.background),
        *still, str(track.body),
        *still, str(track.head),
        "-f", "concat", "-safe", "0", "-i", str(track.faces),
        *still, str(track.ring),
        *still, str(track.mask),
    ]  # fmt: skip


def _badge_graph(track: BadgeTrack, first: int) -> str:
    """The filtergraph building ``[badge]`` from the six inputs starting at
    index ``first`` (background, body, head, faces, ring, mask)."""
    bg, body, head, faces, ring, mask = range(first, first + 6)
    ox, oy = track.origin
    commands = str(track.commands).replace("\\", "/").replace(":", "\\:")
    spin = "a=0:c=none:ow=iw:oh=ih"
    return (
        f"[{bg}:v]sendcmd=f='{commands}',format=rgba[bg];"
        f"[{body}:v]format=rgba[body];"
        f"[{head}:v]format=rgba,rotate@head={spin}[head];"
        f"[{faces}:v]format=rgba,rotate@face={spin}[face];"
        f"[{mask}:v]format=gray[mask];"
        f"[bg][body]overlay@body=x=0:y=0:format=rgb[b1];"
        f"[b1][head]overlay@head=x={ox}:y={oy}:format=rgb[b2];"
        f"[b2][face]overlay@face=x={ox}:y={oy}:format=rgb[b3];"
        f"[b3][mask]alphamerge[b4];"
        f"[b4][{ring}:v]overlay=format=rgb[b5];"
        f"[b5]scale={track.size}:{track.size}:flags=area[badge]"
    )


def _slide(size: int, margin: int) -> str:
    """How far off its corner the badge still is at time ``t``: eased out."""
    k = f"min(1,max(0,(t-{ENTER_DELAY})/{ENTER_SECONDS}))"
    return f"({size + margin})*pow(1-{k},3)"


def preview_command(
    *, track: BadgeTrack, narration: Path, out: Path, fps: int, canvas: int
) -> list[str]:
    """The ffmpeg call for a square preview: the badge centered on a plain
    backdrop, talking along with ``narration``."""
    return [
        "ffmpeg", "-y", "-loglevel", "error",
        "-f", "lavfi", "-i", f"color=c=0xF4F1EA:s={canvas}x{canvas}:r={fps}",
        *_badge_inputs(track, fps),
        "-i", str(narration),
        "-filter_complex",
        _badge_graph(track, 1)
        + ";[0:v][badge]overlay=(W-w)/2:(H-h)/2:shortest=1,format=yuv420p[v]",
        "-map", "[v]", "-map", "7:a",
        "-r", str(fps), "-c:v", "libx264", "-c:a", "aac", "-shortest", str(out),
    ]  # fmt: skip


def overlay_command(
    *,
    video: Path,
    track: BadgeTrack,
    out: Path,
    fps: int,
    margin: int,
    position: str = DEFAULT_POSITION,
) -> list[str]:
    """The ffmpeg call laying the badge into ``video``'s ``position`` corner,
    keeping its audio untouched.

    ``shortest=1`` ends the output with the tutorial: without it, ffmpeg
    freezes the tutorial's last frame for as long as the badge track runs.
    The track is always built a little longer than the video, so only the
    badge is ever cut short."""
    if position not in POSITIONS:
        raise AvatarError(
            f"unknown avatar position {position!r}; choose from "
            f"{', '.join(POSITIONS)}"
        )
    place = POSITIONS[position].format(m=margin, slide=_slide(track.size, margin))
    return [
        "ffmpeg", "-y", "-loglevel", "error",
        "-i", str(video),
        *_badge_inputs(track, fps),
        "-filter_complex",
        _badge_graph(track, 1)
        + f";[0:v][badge]overlay='{place}':eval=frame:shortest=1,format=yuv420p[v]",
        "-map", "[v]", "-map", "0:a?",
        "-r", str(fps), "-c:v", "libx264", "-c:a", "copy", str(out),
    ]  # fmt: skip


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
    levels = frame_levels(narration, fps)
    track = build_track(character, levels, fps=fps, size=size, work_dir=work_dir)
    out.parent.mkdir(parents=True, exist_ok=True)
    run_ffmpeg(
        preview_command(track=track, narration=narration, out=out, fps=fps, canvas=size)
    )
    return out


def render_overlay(
    character: Character,
    video: Path,
    levels: list[float],
    out: Path,
    *,
    work_dir: Path,
    fps: int = DEFAULT_FPS,
    position: str = DEFAULT_POSITION,
) -> Path:
    """``video`` with ``character`` in its ``position`` corner, acting out the
    per-frame loudness ``levels``.

    The badge is sized from the video's height, so a desktop and a mobile
    build get the same proportions, and idles to the video's very end — its
    track runs one frame past the video, so ``overlay_command`` always cuts
    the badge, never the tutorial."""
    _, height, duration = probe_video(video)
    size = badge_size(height)
    track = build_track(
        character,
        levels,
        fps=fps,
        size=size,
        work_dir=work_dir,
        min_frames=math.ceil(duration * fps) + 1,
    )
    out.parent.mkdir(parents=True, exist_ok=True)
    run_ffmpeg(
        overlay_command(
            video=video,
            track=track,
            out=out,
            fps=fps,
            margin=round(size * BADGE_MARGIN_FRACTION),
            position=position,
        )
    )
    return out
