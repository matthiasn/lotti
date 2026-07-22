"""CLI for the tutorial-video workbench.

Usage (from ``tools/tutorial_videos``)::

    python3 -m tutorial_videos validate --scenario create_task_from_audio --locale de
    python3 -m tutorial_videos tts      --scenario create_task_from_audio --locale de
    python3 -m tutorial_videos build    --scenario create_task_from_audio --locale de
    python3 -m tutorial_videos publish  --scenario create_task_from_audio --locale de

Every command also takes ``--device desktop|mobile`` (default ``desktop``).
Mobile renders the real app at a phone-shaped window
(``DEVICE_SIZES['mobile']``, well under the app's 960px desktop breakpoint,
so it genuinely exercises the mobile bottom-nav layout, not a shrunk
desktop one). Desktop output keeps its original unsuffixed filename/R2 key
for backward compatibility; mobile output gets a ``_mobile`` suffix
(``<scenario>_<locale>_mobile.mp4`` etc.) so both variants coexist.

``validate`` checks the scenario is buildable for the locale without any
network access. ``tts`` runs the pre-pass: renders (or reuses cached) clips
and writes the durations manifest consumed by the Dart harness and the
compositor — narration is device-independent, so this manifest is shared by
the desktop and mobile builds of the same (scenario, locale). ``build`` runs
the full pipeline: TTS pre-pass, then the real app under Xvfb driven by
`flutter drive` with the virtual microphone and screen capture, then
OpenMontage composition into the final MP4, then WebVTT captions (see
``captions.py``) written alongside it. ``publish`` uploads the already-built
MP4 and its captions to Cloudflare R2 (see ``publish.py``) and prints their
public URLs.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

from .captions import build_vtt
from .compose import ComposeError, compose_video
from .publish import PublishError, publish_video
from .scenario import ScenarioError, load_scenario
from .session import ScreenCapture, SessionError, VirtualMic, XvfbDisplay
from .tts.base import load_voices, render_scenario_clips
from .tts.gemini import GeminiTts, read_env_key

TOOL_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = TOOL_ROOT.parents[1]
DEFAULT_OUT = REPO_ROOT / "build" / "tutorial_videos"

# Desktop keeps the original 1920x1080 capture with no filename suffix, so
# every already-published desktop video stays at its existing R2 key. Mobile
# is 2x the manual screenshots' logical phone size (402x874,
# test/features/daily_os_next/screenshot_harness.dart's `proDevice`) so the
# tutorial video matches the same device shape shown in phone screenshots —
# well under the app's own 960px isDesktopLayout breakpoint
# (lib/features/design_system/theme/breakpoints.dart), so it genuinely
# renders the real mobile bottom-nav UI, not a shrunk desktop layout.
DEVICE_SIZES = {"desktop": "1920x1080", "mobile": "804x1748"}

# GTK/GDK scale factor per device (GDK_SCALE env var). Xvfb + ffmpeg always
# capture at DEVICE_SIZES' full physical resolution — but `gtk_window_set_
# default_size` (linux/runner/my_application.cc's LOTTI_WINDOW_SIZE) takes
# GTK "application pixels", i.e. the LOGICAL size *before* GDK_SCALE is
# applied. Without a scale override, mobile's physical 804x1748 window is
# also its logical size, so Flutter's MediaQuery.sizeOf(context).width is
# 804 — comfortably past width-based phone breakpoints narrower than
# `kDesktopBreakpoint` (e.g. bottom sheets vs. centered dialogs below
# 560px), so those render in their desktop/tablet shape even though the
# bottom nav (which only checks the 960px breakpoint) looks right. Setting
# GDK_SCALE=2 alongside a HALVED LOTTI_WINDOW_SIZE keeps the physical/
# captured resolution at 804x1748 while Flutter sees the real phone logical
# size (402x874, matching `proDevice`) — the same trick real HiDPI phones
# use, and the reason `proDevice` itself pairs a 402x874 logical size with
# devicePixelRatio 3 for its screenshots.
DEVICE_SCALE = {"desktop": 1, "mobile": 2}


def _load(args: argparse.Namespace):
    scenario = load_scenario(
        TOOL_ROOT / "config" / "scenarios" / f"{args.scenario}.yaml"
    )
    scenario.validate_locale(args.locale)
    return scenario


def _scenario_locale(args: argparse.Namespace) -> str:
    device = getattr(args, "device", "desktop")
    suffix = "" if device == "desktop" else f"_{device}"
    return f"{args.scenario}_{args.locale}{suffix}"


def cmd_validate(args: argparse.Namespace) -> int:
    _load(args)
    print(f"OK: {args.scenario} is buildable for {args.locale}")
    return 0


def cmd_tts(args: argparse.Namespace) -> int:
    scenario = _load(args)
    engine_name, model, streams = load_voices(TOOL_ROOT / "config" / "voices.yaml")
    if engine_name != "gemini":
        raise SystemExit(f"unknown TTS engine: {engine_name}")
    engine = GeminiTts(read_env_key(REPO_ROOT / ".env", "GEMINI_API_KEY"), model)

    out_dir = Path(args.out_dir)
    manifest = render_scenario_clips(
        scenario,
        args.locale,
        engine,
        streams,
        cache_dir=out_dir / "tts_cache",
        manifest_path=out_dir / f"{scenario.name}_{args.locale}.manifest.json",
    )
    total = sum(s["narration"]["duration"] for s in manifest["steps"])
    print(
        f"OK: {len(manifest['steps'])} steps, {total:.1f}s narration -> "
        f"{out_dir / f'{scenario.name}_{args.locale}.manifest.json'}"
    )
    return 0


def _read_env_pairs(names: list[str]) -> dict[str, str]:
    return {name: read_env_key(REPO_ROOT / ".env", name) for name in names}


def cmd_build(args: argparse.Namespace) -> int:
    cmd_tts(args)
    out_dir = Path(args.out_dir)
    # Narration is identical regardless of device, so the TTS manifest is
    # shared across desktop/mobile builds of the same (scenario, locale) —
    # only the capture/timeline/video/captions are device-specific.
    manifest_path = out_dir / f"{args.scenario}_{args.locale}.manifest.json"
    scenario_locale = _scenario_locale(args)
    timeline_path = out_dir / f"{scenario_locale}.timeline.json"
    capture_path = out_dir / f"{scenario_locale}.capture.mkv"
    video_path = out_dir / f"{scenario_locale}.mp4"

    device = getattr(args, "device", "desktop")
    size = DEVICE_SIZES[device]
    scale = DEVICE_SCALE[device]
    capture_width, capture_height = (int(part) for part in size.split("x"))
    window_size = f"{capture_width // scale}x{capture_height // scale}"
    display, sink = ":99", "lotti_tutorial_mic"
    secrets = _read_env_pairs(["MELIOUS_API_KEY", "MELIOUS_BASE_URL"])

    with XvfbDisplay(display=display, size=size), VirtualMic(sink_name=sink):
        with ScreenCapture(
            display=display, size=size, output=capture_path
        ) as capture:
            env = {
                **os.environ,
                **secrets,
                "DISPLAY": display,
                "GDK_BACKEND": "x11",
                "WAYLAND_DISPLAY": "",
                # See DEVICE_SCALE's comment: makes Flutter's MediaQuery see
                # the real phone logical width while Xvfb/ffmpeg still
                # capture at the full physical resolution.
                "GDK_SCALE": str(scale),
                "LOTTI_MANUAL_LOCALE": args.locale,
                "LOTTI_TUTORIAL_MANIFEST": str(manifest_path),
                "LOTTI_TUTORIAL_TIMELINE": str(timeline_path),
                "LOTTI_TUTORIAL_MIC_SINK": sink,
                "LOTTI_SCREENSHOT_DIR": str(out_dir),
                # Honored by linux/runner/my_application.cc: sizes the GTK
                # window at startup (post-launch resizing is not honored on
                # the WM-less Xvfb display). GTK's `gtk_window_set_default_
                # size` takes application (logical) pixels, so this is the
                # LOGICAL size — physical capture resolution is `size`,
                # scaled up by GDK_SCALE.
                "LOTTI_WINDOW_SIZE": window_size,
                # Read by tutorial_harness.dart's tutorialDeviceIsMobile() so
                # scenario tests can branch where the real mobile layout
                # genuinely diverges from desktop (not just window size).
                "LOTTI_TUTORIAL_DEVICE": device,
            }
            drive = subprocess.run(
                [
                    "fvm", "flutter", "drive", "-d", "linux",
                    "--driver=test_driver/tutorial_driver.dart",
                    f"--target=integration_test/tutorial/"
                    f"{args.scenario}_tutorial_test.dart",
                ],
                cwd=REPO_ROOT,
                env=env,
                check=False,
            )
            capture_start = capture.start_epoch_ms
    session_path = out_dir / f"{scenario_locale}.session.json"
    session_path.write_text(
        json.dumps({"capture_start_epoch_ms": capture_start})
    )
    if drive.returncode != 0:
        print("ERROR: flutter drive failed — see output above", file=sys.stderr)
        return 1

    manifest = json.loads(manifest_path.read_text())
    compose_video(
        repo_root=REPO_ROOT,
        capture=capture_path,
        capture_start_epoch_ms=capture_start or 0,
        timeline_path=timeline_path,
        manifest=manifest,
        output=video_path,
        size=(capture_width, capture_height),
    )

    vtt_path = out_dir / f"{scenario_locale}.vtt"
    vtt_path.write_text(
        build_vtt(
            scenario=_load(args),
            locale=args.locale,
            timeline=json.loads(timeline_path.read_text()),
            manifest=manifest,
        )
    )

    print(f"OK: {video_path}")
    return 0


def cmd_publish(args: argparse.Namespace) -> int:
    out_dir = Path(args.out_dir)
    scenario_locale = _scenario_locale(args)
    video_path = out_dir / f"{scenario_locale}.mp4"
    url = publish_video(
        env_path=REPO_ROOT / ".env",
        video_path=video_path,
        key=f"tutorial-videos/{scenario_locale}.mp4",
    )
    print(f"OK: {url}")

    vtt_path = out_dir / f"{scenario_locale}.vtt"
    if vtt_path.is_file():
        caption_url = publish_video(
            env_path=REPO_ROOT / ".env",
            video_path=vtt_path,
            key=f"tutorial-videos/{scenario_locale}.vtt",
        )
        print(f"OK: {caption_url}")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="tutorial_videos")
    sub = parser.add_subparsers(dest="command", required=True)
    for name, handler in (
        ("validate", cmd_validate),
        ("tts", cmd_tts),
        ("build", cmd_build),
        ("publish", cmd_publish),
    ):
        p = sub.add_parser(name)
        p.add_argument("--scenario", required=True)
        p.add_argument("--locale", required=True)
        p.add_argument(
            "--device", choices=sorted(DEVICE_SIZES), default="desktop"
        )
        p.add_argument("--out-dir", default=str(DEFAULT_OUT))
        p.set_defaults(handler=handler)
    args = parser.parse_args(argv)
    try:
        return args.handler(args)
    except (
        ComposeError,
        PublishError,
        ScenarioError,
        SessionError,
        FileNotFoundError,
        KeyError,
    ) as err:
        print(f"ERROR: {err}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
