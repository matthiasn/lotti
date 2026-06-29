#!/usr/bin/env python3
"""Probe full-frame scenery layer registration against a master plate."""

from __future__ import annotations

import argparse
import math
from pathlib import Path

from PIL import Image, ImageDraw


MASTER_SIZE = (2560, 1440)
JET_START_DELAY_SECONDS = 0.18
JET_PASS_SECONDS = 60.0
JET_ASSET_RATIO = 338 / 1414


def _parse_box(value: str) -> tuple[int, int, int, int]:
    parts = [int(part.strip()) for part in value.split(",")]
    if len(parts) != 4:
        raise argparse.ArgumentTypeError("crop must be left,top,right,bottom")
    left, top, right, bottom = parts
    if left >= right or top >= bottom:
        raise argparse.ArgumentTypeError("crop right/bottom must exceed left/top")
    return left, top, right, bottom


def _alpha_image(path: Path, expected_size: tuple[int, int]) -> Image.Image:
    image = Image.open(path)
    if image.size != expected_size:
        raise SystemExit(
            f"{path} is {image.size[0]}x{image.size[1]}, "
            f"expected {expected_size[0]}x{expected_size[1]}"
        )
    if image.mode == "L":
        return image
    return image.convert("RGBA").getchannel("A")


def _overlay(master: Image.Image, alpha: Image.Image) -> Image.Image:
    red = Image.new("RGBA", master.size, (255, 0, 0, 0))
    red.putalpha(alpha.point(lambda value: min(160, value) if value > 8 else 0))
    out = master.copy()
    out.alpha_composite(red)
    return out


def _jet_bbox(time_seconds: float) -> tuple[float, float, float, float] | None:
    local = (time_seconds % 144.0) - JET_START_DELAY_SECONDS
    if local < 0 or local > JET_PASS_SECONDS:
        return None
    progress = local / JET_PASS_SECONDS
    eased = progress * progress * (3 - 2 * progress)
    x = 0.98 - progress * 1.10
    y = 0.295 - eased * 0.055 + math.sin(progress * math.pi) * 0.002
    width = MASTER_SIZE[0] * (0.06 - progress * 0.0015)
    height = width * JET_ASSET_RATIO
    cx = x * MASTER_SIZE[0]
    cy = y * MASTER_SIZE[1]
    return (
        cx - width / 2,
        cy - height / 2,
        cx + width / 2,
        cy + height / 2,
    )


def _draw_jet(out: Image.Image, time_seconds: float) -> None:
    bbox = _jet_bbox(time_seconds)
    if bbox is None:
        return
    draw = ImageDraw.Draw(out)
    left, top, right, bottom = bbox
    cx = (left + right) / 2
    cy = (top + bottom) / 2
    draw.rectangle(bbox, outline=(255, 255, 0, 255), width=4)
    draw.line((cx - 18, cy, cx + 18, cy), fill=(255, 255, 0, 255), width=3)
    draw.line((cx, cy - 18, cx, cy + 18), fill=(255, 255, 0, 255), width=3)
    draw.text(
        (left, max(0, top - 24)),
        f"jet t={time_seconds:.3f}",
        fill=(255, 255, 0, 255),
    )


def _save_crop(
    image: Image.Image,
    path: Path,
    crop: tuple[int, int, int, int] | None,
    scale: int,
) -> None:
    if crop is None:
        return
    cropped = image.crop(crop)
    if scale > 1:
        cropped = cropped.resize(
            (cropped.width * scale, cropped.height * scale),
            Image.Resampling.NEAREST,
        )
    cropped.save(path)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--master", required=True, type=Path)
    parser.add_argument("--layer", action="append", default=[], type=Path)
    parser.add_argument("--mask", action="append", default=[], type=Path)
    parser.add_argument("--out-dir", default=Path("tmp/scenery_work/registration_probe"), type=Path)
    parser.add_argument("--crop", type=_parse_box)
    parser.add_argument("--scale", type=int, default=4)
    parser.add_argument("--jet-time", type=float)
    args = parser.parse_args()

    master = Image.open(args.master).convert("RGBA")
    if master.size != MASTER_SIZE:
        raise SystemExit(
            f"{args.master} is {master.size[0]}x{master.size[1]}, "
            f"expected {MASTER_SIZE[0]}x{MASTER_SIZE[1]}"
        )

    args.out_dir.mkdir(parents=True, exist_ok=True)
    subjects = [(path, "layer") for path in args.layer] + [
        (path, "mask") for path in args.mask
    ]
    if not subjects:
        parser.error("provide at least one --layer or --mask")

    for path, kind in subjects:
        alpha = _alpha_image(path, master.size)
        out = _overlay(master, alpha)
        if args.jet_time is not None:
            _draw_jet(out, args.jet_time)
        stem = f"{path.stem}_{kind}"
        out.save(args.out_dir / f"{stem}_overlay.png")
        _save_crop(
            out,
            args.out_dir / f"{stem}_overlay_crop.png",
            args.crop,
            max(1, args.scale),
        )
        bbox = alpha.getbbox()
        print(
            f"{path}: ok {master.size[0]}x{master.size[1]} "
            f"alpha_bbox={bbox} alpha_extrema={alpha.getextrema()}"
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
