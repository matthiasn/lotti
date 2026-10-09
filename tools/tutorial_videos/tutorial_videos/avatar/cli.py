"""The ``avatar-preview`` and ``avatar-overlay`` commands, and the in-place
overlay ``build --avatar`` runs.

``avatar-preview`` renders a character (Pip unless ``--character`` names
another) saying a WAV, for judging the art and the lip-sync on their own.
``avatar-overlay`` adds the badge to an already-built tutorial MP4, lip-synced
to the narrator clips the build's manifest and timeline name (so the dictation
never moves the mouth), or — for a video without those — to a WAV.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from . import AvatarError
from .characters import CHARACTERS, DEFAULT_CHARACTER
from .lipsync import frame_levels
from .narration_track import narration_levels
from .render import (
    DEFAULT_FPS,
    DEFAULT_POSITION,
    POSITIONS,
    render_overlay,
    render_preview,
)

# ``__main__`` suffixes a mobile build's outputs; the TTS manifest is shared
# with the desktop build and carries no suffix.
MOBILE_SUFFIX = "_mobile"


def register(sub: argparse._SubParsersAction, *, default_out: Path) -> None:
    preview = sub.add_parser("avatar-preview")
    preview.add_argument("--wav", required=True, type=Path)
    preview.add_argument(
        "--character", choices=sorted(CHARACTERS), default=DEFAULT_CHARACTER
    )
    preview.add_argument("--size", type=int, default=480)
    preview.add_argument("--fps", type=int, default=DEFAULT_FPS)
    preview.add_argument("--out-dir", type=Path, default=default_out / "avatar")
    preview.set_defaults(handler=cmd_avatar_preview)

    overlay = sub.add_parser("avatar-overlay")
    overlay.add_argument("--video", required=True, type=Path)
    overlay.add_argument(
        "--manifest",
        type=Path,
        help="the build's TTS manifest (defaults to "
        "<scenario>_<locale>.manifest.json beside the video; a _mobile "
        "video shares the desktop one)",
    )
    overlay.add_argument(
        "--timeline",
        type=Path,
        help="the build's timeline (defaults to <video stem>.timeline.json)",
    )
    overlay.add_argument(
        "--narration",
        type=Path,
        help="lip-sync to this WAV instead of the narrator clips — for a "
        "video without a manifest and timeline (those missing, "
        "<video stem>.narration.wav is tried)",
    )
    overlay.add_argument("--out", type=Path, help="defaults to <video stem>_avatar.mp4")
    overlay.add_argument(
        "--position", choices=sorted(POSITIONS), default=DEFAULT_POSITION
    )
    overlay.add_argument("--fps", type=int, default=DEFAULT_FPS)
    overlay.add_argument(
        "--character", choices=sorted(CHARACTERS), default=DEFAULT_CHARACTER
    )
    overlay.set_defaults(handler=cmd_avatar_overlay)


def sidecar_paths(video: Path) -> tuple[Path, Path]:
    """The manifest and timeline a built tutorial's name points at.

    The timeline is per device, so it keeps the video's stem; the manifest
    is shared between the desktop and mobile builds, so a ``_mobile`` stem
    drops the suffix to find it."""
    stem = video.stem
    shared = stem.removesuffix(MOBILE_SUFFIX)
    return (
        video.with_name(f"{shared}.manifest.json"),
        video.with_name(f"{stem}.timeline.json"),
    )


def levels_for(
    video: Path,
    *,
    fps: int,
    manifest: Path | None = None,
    timeline: Path | None = None,
    narration: Path | None = None,
) -> list[float]:
    """The per-frame loudness the badge lip-syncs to.

    A WAV given as ``narration`` wins. Otherwise the narrator clips, placed
    through the build's manifest and timeline (named explicitly, or found
    beside the video). For a video with neither, the narration mix beside
    it — which also carries the dictation, so the beak follows that too."""
    if narration is not None:
        return frame_levels(narration, fps)
    default_manifest, default_timeline = sidecar_paths(video)
    explicit = manifest is not None or timeline is not None
    manifest = manifest or default_manifest
    timeline = timeline or default_timeline
    if manifest.is_file() and timeline.is_file():
        return narration_levels(
            json.loads(manifest.read_text()), json.loads(timeline.read_text()), fps
        )
    if explicit:
        raise AvatarError(f"{manifest} and {timeline} must both exist")
    mix = video.with_suffix(".narration.wav")
    if mix.is_file():
        return frame_levels(mix, fps)
    raise AvatarError(
        f"nothing to lip-sync {video.name} to: no {manifest.name} with "
        f"{timeline.name}, and no {mix.name}"
    )


def overlay_in_place(
    video: Path,
    *,
    manifest: dict,
    timeline: dict,
    position: str,
    work_dir: Path,
    fps: int = DEFAULT_FPS,
    character: str = DEFAULT_CHARACTER,
) -> Path:
    """Puts ``character``'s badge onto a just-built ``video`` under its own
    name, so the captions, ``publish`` and the docs site see one file."""
    levels = narration_levels(manifest, timeline, fps)
    temp = video.with_name(f"{video.stem}.avatar_tmp.mp4")
    render_overlay(
        CHARACTERS[character],
        video,
        levels,
        temp,
        work_dir=work_dir,
        fps=fps,
        position=position,
    )
    os.replace(temp, video)
    return video


def cmd_avatar_preview(args: argparse.Namespace) -> int:
    character = CHARACTERS[args.character]
    out = render_preview(
        character,
        args.wav,
        args.out_dir / f"avatar_{character.name}.mp4",
        size=args.size,
        work_dir=args.out_dir / "work",
        fps=args.fps,
    )
    print(f"OK: {out}")
    return 0


def cmd_avatar_overlay(args: argparse.Namespace) -> int:
    video: Path = args.video
    out = args.out or video.with_name(f"{video.stem}_avatar.mp4")
    levels = levels_for(
        video,
        fps=args.fps,
        manifest=args.manifest,
        timeline=args.timeline,
        narration=args.narration,
    )
    render_overlay(
        CHARACTERS[args.character],
        video,
        levels,
        out,
        work_dir=out.parent / "avatar_work" / video.stem,
        fps=args.fps,
        position=args.position,
    )
    print(f"OK: {out}")
    return 0
