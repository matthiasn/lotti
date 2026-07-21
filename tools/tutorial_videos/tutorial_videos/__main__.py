"""CLI for the tutorial-video workbench.

Usage (from ``tools/tutorial_videos``)::

    python3 -m tutorial_videos validate --scenario create_task_from_audio --locale de
    python3 -m tutorial_videos tts      --scenario create_task_from_audio --locale de

``validate`` checks the scenario is buildable for the locale without any
network access. ``tts`` runs the pre-pass: renders (or reuses cached) clips
and writes the durations manifest consumed by the Dart harness and the
compositor.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from .scenario import ScenarioError, load_scenario
from .tts.base import load_voices, render_scenario_clips
from .tts.gemini import GeminiTts, read_env_key

TOOL_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = TOOL_ROOT.parents[1]
DEFAULT_OUT = REPO_ROOT / "build" / "tutorial_videos"


def _load(args: argparse.Namespace):
    scenario = load_scenario(
        TOOL_ROOT / "config" / "scenarios" / f"{args.scenario}.yaml"
    )
    scenario.validate_locale(args.locale)
    return scenario


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


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="tutorial_videos")
    sub = parser.add_subparsers(dest="command", required=True)
    for name, handler in (("validate", cmd_validate), ("tts", cmd_tts)):
        p = sub.add_parser(name)
        p.add_argument("--scenario", required=True)
        p.add_argument("--locale", required=True)
        p.add_argument("--out-dir", default=str(DEFAULT_OUT))
        p.set_defaults(handler=handler)
    args = parser.parse_args(argv)
    try:
        return args.handler(args)
    except ScenarioError as err:
        print(f"ERROR: {err}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
