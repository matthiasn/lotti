#!/usr/bin/env python3
"""Create same-size alpha WebP layers from one master plate and mask images."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw


def _save_webp(image: Image.Image, path: Path) -> None:
    image.save(path, "WEBP", lossless=True, quality=100, method=6)


@dataclass(frozen=True)
class LayerSpec:
    name: str
    mask_path: Path


def _parse_layer(value: str) -> LayerSpec:
    if "=" not in value:
        raise argparse.ArgumentTypeError("--layer must be NAME=MASK_PATH")
    name, path = value.split("=", 1)
    name = name.strip()
    if not name:
        raise argparse.ArgumentTypeError("layer name must not be empty")
    return LayerSpec(name=name, mask_path=Path(path))


def _normalized_mask(path: Path, size: tuple[int, int]) -> Image.Image:
    raw = Image.open(path).convert("L").resize(size, Image.Resampling.LANCZOS)

    def stretch(pixel: int) -> int:
        if pixel < 28:
            return 0
        if pixel > 214:
            return 255
        return int((pixel - 28) * 255 / (214 - 28))

    return raw.point(stretch)


def _gradient(size: tuple[int, int]) -> Image.Image:
    width, height = size
    image = Image.new("RGBA", size)
    draw = ImageDraw.Draw(image)
    for y in range(height):
        t = y / max(1, height - 1)
        draw.line(
            [(0, y), (width, y)],
            fill=(
                int(8 * (1 - t) + 12 * t),
                int(21 * (1 - t) + 50 * t),
                int(46 * (1 - t) + 66 * t),
                255,
            ),
        )
    draw.rectangle(
        [0, int(height * 0.58), width, int(height * 0.93)],
        fill=(8, 32, 45, 255),
    )
    return image


def _write_layer(
    master: Image.Image,
    spec: LayerSpec,
    out_dir: Path,
    preview_dir: Path,
) -> dict[str, object]:
    mask = _normalized_mask(spec.mask_path, master.size)
    mask_out = preview_dir / f"{spec.name}_mask.png"
    mask.save(mask_out)

    layer = master.copy()
    layer.putalpha(mask)
    layer_out = out_dir / f"{spec.name}.webp"
    _save_webp(layer, layer_out)

    preview = _gradient(master.size)
    preview.alpha_composite(layer)
    preview.save(preview_dir / f"{spec.name}_preview.png")

    return {
        "name": spec.name,
        "layer": str(layer_out),
        "mask": str(mask_out),
        "bbox": mask.getbbox(),
        "alpha": mask.getextrema(),
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="master plate + masks -> same-size alpha WebP layers",
    )
    parser.add_argument("--master", required=True, type=Path)
    parser.add_argument("--out-dir", required=True, type=Path)
    parser.add_argument("--preview-dir", required=True, type=Path)
    parser.add_argument(
        "--layer",
        action="append",
        default=[],
        type=_parse_layer,
        help="layer spec NAME=MASK_PATH; may be repeated",
    )
    args = parser.parse_args()
    if not args.layer:
        parser.error("provide at least one --layer NAME=MASK_PATH")

    args.out_dir.mkdir(parents=True, exist_ok=True)
    args.preview_dir.mkdir(parents=True, exist_ok=True)

    master = Image.open(args.master).convert("RGBA")

    summary = [
        _write_layer(master, spec, args.out_dir, args.preview_dir)
        for spec in args.layer
    ]

    stack = _gradient(master.size)
    for spec in args.layer:
        stack.alpha_composite(
            Image.open(args.out_dir / f"{spec.name}.webp").convert("RGBA"),
        )
    stack.save(args.preview_dir / "blue_hour_layers_preview.png")

    width, height = master.size
    phone = Image.new("RGBA", (1080, 1920), (7, 18, 38, 255))
    scale = max(1080 / width, 1920 / height)
    resized = stack.resize(
        (round(width * scale), round(height * scale)),
        Image.Resampling.LANCZOS,
    )
    phone.alpha_composite(
        resized,
        ((1080 - resized.width) // 2, (1920 - resized.height) // 2),
    )
    phone.save(args.preview_dir / "blue_hour_layers_preview_phone.png")

    for item in summary:
        print(
            f"{item['name']}: {item['layer']} bbox={item['bbox']} "
            f"alpha={item['alpha']}",
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
