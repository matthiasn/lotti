#!/usr/bin/env python3
"""Inspect scenery image dimensions/channels and enforce full-frame alignment.

The blue-hour backdrop is a stack of same-size plates, masks and shader lookup
images in the master art coordinate space. Cropped object sprites are allowed
only when explicitly listed as exceptions.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[2]
DEFAULT_PATHS = [
    REPO / "assets/scenery",
    REPO / "tools/scenery_art/scenes/blue_hour_waterfront/masks",
]
DEFAULT_EXCEPTIONS = {
    "assets/scenery/lufthansa_747.png",
}


def _repo_path(path: Path) -> str:
    try:
        return path.resolve().relative_to(REPO).as_posix()
    except ValueError:
        return path.as_posix()


def _image_paths(roots: list[Path]) -> list[Path]:
    suffixes = {".png", ".webp", ".jpg", ".jpeg"}
    out: list[Path] = []
    for root in roots:
        if root.is_file() and root.suffix.lower() in suffixes:
            out.append(root)
        elif root.is_dir():
            out.extend(
                p for p in root.rglob("*") if p.suffix.lower() in suffixes
            )
    return sorted(out)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "paths",
        nargs="*",
        type=Path,
        default=DEFAULT_PATHS,
        help="Image files/directories to inspect.",
    )
    parser.add_argument("--width", type=int, default=2560)
    parser.add_argument("--height", type=int, default=1440)
    parser.add_argument(
        "--exception",
        action="append",
        default=sorted(DEFAULT_EXCEPTIONS),
        help="Repo-relative image path allowed to differ from the base size.",
    )
    args = parser.parse_args()

    expected = (args.width, args.height)
    exceptions = set(args.exception)
    failures: list[str] = []
    rows: list[tuple[str, str, str, str]] = []

    for path in _image_paths(args.paths):
        with Image.open(path) as image:
            rel = _repo_path(path)
            size = image.size
            status = "ok"
            if rel not in exceptions and size != expected:
                status = "BAD"
                failures.append(f"{rel}: {size[0]}x{size[1]} != {expected[0]}x{expected[1]}")
            elif rel in exceptions:
                status = "sprite"
            rows.append((status, f"{size[0]}x{size[1]}", image.mode, rel))

    width = max((len(r[3]) for r in rows), default=0)
    for status, size, mode, rel in rows:
        print(f"{status:>6}  {size:>9}  {mode:<5}  {rel:<{width}}")

    if failures:
        print("\nFull-frame alignment failures:")
        for failure in failures:
            print(f"  {failure}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
