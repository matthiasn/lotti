"""The ``avatar-preview`` and ``avatar-overlay`` commands.

``avatar-preview`` renders every candidate character (or one) saying a WAV,
for picking a character and judging the lip-sync. ``avatar-overlay`` adds the
badge to an already-built tutorial MP4, lip-synced to the narration mix
``compose.py`` writes next to it (``<video stem>.narration.wav``).
"""

from __future__ import annotations

import argparse
from pathlib import Path

from .characters import CHARACTERS, get_character
from .render import DEFAULT_FPS, render_overlay, render_preview


def register(sub: argparse._SubParsersAction, *, default_out: Path) -> None:
    preview = sub.add_parser("avatar-preview")
    preview.add_argument("--wav", required=True, type=Path)
    preview.add_argument("--character", choices=[*CHARACTERS, "all"], default="all")
    preview.add_argument("--size", type=int, default=480)
    preview.add_argument("--fps", type=int, default=DEFAULT_FPS)
    preview.add_argument("--out-dir", type=Path, default=default_out / "avatar")
    preview.set_defaults(handler=cmd_avatar_preview)

    overlay = sub.add_parser("avatar-overlay")
    overlay.add_argument("--video", required=True, type=Path)
    overlay.add_argument(
        "--narration",
        type=Path,
        help="defaults to the narration mix next to the video "
        "(<video stem>.narration.wav)",
    )
    overlay.add_argument("--character", choices=list(CHARACTERS), default="pip")
    overlay.add_argument("--out", type=Path, help="defaults to <video stem>_avatar.mp4")
    overlay.add_argument("--fps", type=int, default=DEFAULT_FPS)
    overlay.set_defaults(handler=cmd_avatar_overlay)


def cmd_avatar_preview(args: argparse.Namespace) -> int:
    names = list(CHARACTERS) if args.character == "all" else [args.character]
    for name in names:
        out = render_preview(
            get_character(name),
            args.wav,
            args.out_dir / f"avatar_{name}.mp4",
            size=args.size,
            work_dir=args.out_dir / "work" / name,
            fps=args.fps,
        )
        print(f"OK: {out}")
    return 0


def cmd_avatar_overlay(args: argparse.Namespace) -> int:
    video: Path = args.video
    narration = args.narration or video.with_suffix(".narration.wav")
    out = args.out or video.with_name(f"{video.stem}_avatar.mp4")
    render_overlay(
        get_character(args.character),
        video,
        narration,
        out,
        work_dir=out.parent / "avatar_work" / f"{video.stem}_{args.character}",
        fps=args.fps,
    )
    print(f"OK: {out}")
    return 0
