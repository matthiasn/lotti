#!/usr/bin/env python3
"""Extract movable cloud layers and a cloudless plate from the master scene.

The detector intentionally starts from image signal instead of a hand-painted
cloud mask:

* local luma contrast finds painted cloud edges/details;
* broad luma lift catches cloud highlights over the row's clean-sky colour;
* colour gates reject pure blue sky and saturated non-cloud pixels;
* existing alpha layers exclude palms, skyline, bridge and yacht structure.

OpenCV is only used at art-build time for masking/inpainting. Flutter consumes
plain WebP assets and has no Python/OpenCV runtime dependency.
"""

from __future__ import annotations

import argparse
import math
from dataclasses import dataclass
from pathlib import Path

try:
    import cv2
    import numpy as np
except ModuleNotFoundError as error:  # pragma: no cover - developer setup path
    raise SystemExit(
        "isolate_clouds.py needs OpenCV + NumPy. Install them in a venv, e.g.\n"
        "  python3 -m venv /tmp/lotti-scenery-opencv\n"
        "  /tmp/lotti-scenery-opencv/bin/python -m pip install "
        "opencv-python-headless pillow\n"
        "Then run: make -C tools/scenery_art "
        "PYTHON=/tmp/lotti-scenery-opencv/bin/python blue-hour",
    ) from error

from PIL import Image, ImageDraw


def _save_webp(image: Image.Image, path: Path) -> None:
    image.save(path, "WEBP", lossless=True, quality=100, method=6)


@dataclass(frozen=True)
class CloudLayer:
    name: str
    x_min: int
    x_max: int
    y_min: int
    y_max: int
    feather: float


_CLOUD_LAYERS = (
    CloudLayer("clouds_far", 0, 2560, 70, 360, 42),
    CloudLayer("clouds_mid", 0, 2560, 180, 520, 56),
    CloudLayer("clouds_near", 0, 2560, 350, 690, 48),
)


def _rgba(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def _alpha(path: Path, size: tuple[int, int]) -> np.ndarray:
    image = _rgba(path).getchannel("A")
    if image.size != size:
        image = image.resize(size, Image.Resampling.LANCZOS)
    return np.asarray(image)


def _structural_exclusion(paths: list[Path], size: tuple[int, int]) -> np.ndarray:
    """Pixels that must never be allowed into drifting cloud layers."""

    height, width = size[1], size[0]
    excluded = np.zeros((height, width), np.uint8)
    for path, kernel_size in zip(paths, (17, 15, 11), strict=True):
        alpha = _alpha(path, size)
        mask = (alpha > 0).astype(np.uint8)
        if path.name in {"city_bridge.png", "city_bridge.webp"}:
            upward = mask.copy()
            for shift in range(1, 121):
                upward[:-shift, :] = np.maximum(upward[:-shift, :], mask[shift:, :])
            mask = np.maximum(mask, upward)
        kernel = np.ones((kernel_size, kernel_size), np.uint8)
        excluded = np.maximum(excluded, cv2.dilate(mask, kernel, iterations=1))
    return excluded


def _cloud_region(size: tuple[int, int]) -> np.ndarray:
    """Broad art-directed sky regions where clouds exist in the source plate."""

    width, height = size
    region = Image.new("L", size, 0)
    draw = ImageDraw.Draw(region)
    for box in (
        (420, 55, 1030, 360),
        (640, 185, 1350, 405),
        (940, 295, 1585, 535),
        (1360, 230, 2505, 610),
        (0, 305, 420, 555),
        (1740, 500, 2220, 660),
        (1380, 115, 1790, 315),
        (1030, 225, 1300, 340),
    ):
        draw.ellipse(box, fill=255)

    # Keep low clouds around the left skyline baked into the base plate. The
    # contrast detector can isolate legitimate cloud highlights immediately
    # behind tower silhouettes, but once those highlights move they read as
    # chunks of the buildings sliding sideways.
    draw.rectangle((0, 285, 980, 700), fill=0)
    return np.asarray(region) > 0


@dataclass(frozen=True)
class CloudMasks:
    motion: np.ndarray
    stencil: np.ndarray
    erase: np.ndarray


def _estimate_clean_sky(rgb: np.ndarray, excluded: np.ndarray) -> np.ndarray:
    """Estimate each row's cloud-free sky colour from blue, unsaturated pixels."""

    height = rgb.shape[0]
    red = rgb[:, :, 0]
    green = rgb[:, :, 1]
    blue = rgb[:, :, 2]
    luma = 0.299 * red + 0.587 * green + 0.114 * blue
    max_channel = np.maximum.reduce((red, green, blue))
    min_channel = np.minimum.reduce((red, green, blue))
    saturation = max_channel - min_channel
    blue_gap = blue - (red + green) * 0.5

    clean_sky = np.zeros((height, 3), np.float32)
    last = np.array([12, 40, 80], np.float32)
    for row in range(height):
        if row > 720:
            clean_sky[row] = last
            continue
        valid = (
            (excluded[row] == 0)
            & (blue[row] > red[row] + 25)
            & (blue[row] > green[row] + 3)
            & (saturation[row] < 120)
            & (luma[row] > 12)
        )
        xs = np.where(valid)[0]
        if xs.size > 30:
            row_blue_gap = blue_gap[row, xs]
            keep = xs[row_blue_gap >= np.percentile(row_blue_gap, 60)]
            value = np.median(rgb[row, keep, :], axis=0)
            last = 0.88 * last + 0.12 * value
        clean_sky[row] = last
    return cv2.GaussianBlur(
        clean_sky.reshape(height, 1, 3),
        (1, 85),
        0,
    ).reshape(height, 3)


def _cloud_masks(master: Image.Image, excluded: np.ndarray) -> CloudMasks:
    """Build motion + stencil cloud masks from luma contrast + colour gates.

    Confident bright/textured pixels seed connected components; nearby darker
    cloud-body pixels are kept only when connected to those seeds. That moves
    the full cloud mass while rejecting broad smooth sky gradients.

    The stencil mask is deliberately sparser: only confident highlights are
    removed from the base plate. Broad dark bodies are left in the plate and also
    emitted as low-alpha movable overlays; this avoids large ugly inpaint patches.
    """

    width, height = master.size
    rgb = np.asarray(master.convert("RGB")).astype(np.float32)
    red = rgb[:, :, 0]
    green = rgb[:, :, 1]
    blue = rgb[:, :, 2]
    luma = 0.299 * red + 0.587 * green + 0.114 * blue
    max_channel = np.maximum.reduce((red, green, blue))
    min_channel = np.minimum.reduce((red, green, blue))
    saturation = max_channel - min_channel
    blue_gap = blue - (red + green) * 0.5
    warm_lift = (red + green) * 0.5 - blue * 0.62

    small_blur = cv2.GaussianBlur(luma, (0, 0), sigmaX=9, sigmaY=9)
    broad_blur = cv2.GaussianBlur(luma, (0, 0), sigmaX=38, sigmaY=38)
    local_contrast = np.abs(luma - small_blur)
    highlight_lift = luma - broad_blur
    shadow_lift = broad_blur - luma
    texture = cv2.GaussianBlur(local_contrast, (0, 0), sigmaX=2.2, sigmaY=2.2)

    region = _cloud_region(master.size)
    y = np.arange(height)[:, None]
    x = np.arange(width)[None, :]
    left_skyline_static_zone = (x < 760) & (y > 185) & (y < 720)

    # Dark clouds are "far from clean sky" even when their local luma contrast
    # is subtle.
    clean_sky = _estimate_clean_sky(rgb, excluded)
    sky_distance = np.sqrt(((rgb - clean_sky[:, None, :]) ** 2).sum(axis=2))

    bright_score = (
        texture * 3.1
        + np.maximum(highlight_lift - 1, 0) * 2.0
        + np.maximum(shadow_lift - 5, 0) * 0.8
        + np.maximum(warm_lift + 2, 0) * 0.18
    )
    bright_threshold = (
        31
        + np.where(y > 430, 9, 0)
        + np.where(y > 540, 12, 0)
        + np.where((x > 1880) & (y > 420), 13, 0)
    )
    colour_gate = ((blue_gap < 84) & (saturation < 118)) | (texture > 7.5)
    sky_gate = np.clip((720 - y) / 160, 0, 1)
    stencil = np.where(
        (bright_score > bright_threshold) & colour_gate & region,
        np.clip((bright_score - bright_threshold) * 9, 0, 255),
        0,
    ).astype(np.float32)
    stencil *= sky_gate
    stencil = stencil.astype(np.uint8)
    stencil[excluded > 0] = 0
    stencil = cv2.morphologyEx(stencil, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    stencil = cv2.morphologyEx(stencil, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    stencil = cv2.dilate(stencil, np.ones((5, 5), np.uint8), iterations=1)
    stencil = cv2.GaussianBlur(stencil, (0, 0), sigmaX=2.0, sigmaY=2.0)
    stencil = np.where(stencil < 10, 0, stencil).astype(np.uint8)
    stencil[excluded > 0] = 0
    stencil[left_skyline_static_zone] = 0

    seed_signal = (
        texture * 2.8
        + np.maximum(highlight_lift, 0) * 1.9
        + np.maximum(warm_lift, 0) * 0.22
    )
    seed = (
        region
        & (excluded == 0)
        & (y < 700)
        & (saturation < 128)
        & (blue_gap < 96)
        & ((seed_signal > 28) | ((texture > 8) & (sky_distance > 14)))
    )
    body_signal = (
        (texture > 4.2)
        | (shadow_lift > 7.2)
        | ((sky_distance > 22) & ((texture > 3.0) | (shadow_lift > 5.2)))
        | ((highlight_lift > 4.5) & (texture > 2.2))
    )
    body = (
        region
        & (excluded == 0)
        & (y < 700)
        & (saturation < 145)
        & (blue_gap < 112)
        & body_signal
    )
    # Keep the right horizon glow mostly baked; only textured cloud details there
    # should drift.
    body &= ~(
        (x > 1650)
        & (y > 410)
        & (texture < 5.6)
        & (shadow_lift < 9.5)
        & (np.abs(highlight_lift) < 8)
    )

    body = cv2.morphologyEx(body.astype(np.uint8), cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    body = cv2.morphologyEx(body, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
    seed = cv2.dilate(seed.astype(np.uint8), np.ones((7, 7), np.uint8), iterations=1)

    labels_count, labels, stats, _ = cv2.connectedComponentsWithStats(body, 8)
    kept = np.zeros((height, width), np.uint8)
    for label in range(1, labels_count):
        area = stats[label, cv2.CC_STAT_AREA]
        if area < 90:
            continue
        component = labels == label
        seed_count = int(seed[component].sum())
        top = stats[label, cv2.CC_STAT_TOP]
        if seed_count >= 20 or (area > 1800 and top < 380 and seed_count >= 5):
            kept[component] = 255

    strength = np.clip(
        texture * 12
        + np.maximum(highlight_lift, 0) * 6
        + np.maximum(shadow_lift - 4, 0) * 10.5
        + np.maximum(sky_distance - 12, 0) * 3.8
        - 28,
        0,
        255,
    )
    motion = np.where(kept > 0, strength, 0).astype(np.uint8)

    motion = cv2.GaussianBlur(motion, (0, 0), sigmaX=2.2, sigmaY=2.2)
    motion = np.where(motion < 8, 0, motion).astype(np.uint8)
    # Preserve the confident highlights from the sparse mask inside the broader
    # motion mask so bright cloud details move fully with the cloud body.
    motion = np.maximum(motion, stencil)
    motion[excluded > 0] = 0
    motion = _repair_occluded_alpha_holes(motion, excluded)
    motion[left_skyline_static_zone] = 0

    erase_strength = np.where(
        kept > 0,
        np.clip(
            38
            + np.maximum(sky_distance - 13, 0) * 2.8
            + np.maximum(shadow_lift - 4, 0) * 6.8
            + texture * 2.6,
            0,
            225,
        ),
        0,
    ).astype(np.uint8)
    erase = np.maximum(stencil, erase_strength)
    erase = cv2.GaussianBlur(erase, (0, 0), sigmaX=5.5, sigmaY=5.5)
    erase = np.where(erase < 7, 0, erase).astype(np.uint8)
    erase[excluded > 0] = 0
    erase[left_skyline_static_zone] = 0
    return CloudMasks(motion=motion, stencil=stencil, erase=erase)


def _repair_occluded_alpha_holes(alpha: np.ndarray, excluded: np.ndarray) -> np.ndarray:
    """Fill occluder-shaped holes so drifting clouds do not reveal silhouettes.

    The detector excludes buildings, yacht and palms while deciding what is a
    cloud. That keeps structure pixels out of the mask, but it also punches
    city-shaped holes into continuous clouds. Those holes become visible once
    the cloud layer drifts horizontally, so we inpaint alpha only in sky pixels
    close to an existing cloud mass.
    """

    height, width = alpha.shape
    y = np.arange(height)[:, None]
    near_cloud = cv2.dilate(
        (alpha > 0).astype(np.uint8),
        np.ones((73, 73), np.uint8),
        iterations=1,
    )
    repair_region = (
        (excluded > 0)
        & (y < 730)
        & (near_cloud > 0)
        & (np.arange(width)[None, :] > 240)
    )
    if not repair_region.any():
        return alpha

    repaired = cv2.inpaint(
        alpha,
        repair_region.astype(np.uint8) * 255,
        23,
        cv2.INPAINT_TELEA,
    )
    out = alpha.copy()
    out[repair_region] = repaired[repair_region]
    out = cv2.GaussianBlur(out, (0, 0), sigmaX=1.4, sigmaY=1.4)
    return np.where(out < 7, 0, out).astype(np.uint8)


def _deoccluded_cloud_source(master: Image.Image, excluded: np.ndarray) -> Image.Image:
    """Remove fixed scene structure from the RGB source used by cloud layers."""

    rgb = np.asarray(master.convert("RGB"))
    rgb_f32 = rgb.astype(np.float32)
    height = rgb.shape[0]
    y = np.arange(height)[:, None]
    repair_region = ((excluded > 0) & (y < 760)).astype(np.uint8) * 255
    repair_region = cv2.dilate(
        repair_region,
        np.ones((9, 9), np.uint8),
        iterations=1,
    )
    bgr = cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)
    repaired = cv2.inpaint(bgr, repair_region, 19, cv2.INPAINT_TELEA)
    repaired_rgb = cv2.cvtColor(repaired, cv2.COLOR_BGR2RGB).astype(np.float32)
    clean_sky = _estimate_clean_sky(rgb_f32, excluded)
    sky_field = np.repeat(clean_sky[:, None, :], master.width, axis=1)
    broad_colour = cv2.GaussianBlur(rgb_f32, (0, 0), sigmaX=70, sigmaY=36)
    sky_field = sky_field * 0.86 + broad_colour * 0.14
    repair_alpha = cv2.GaussianBlur(
        (repair_region > 0).astype(np.float32),
        (0, 0),
        sigmaX=5,
        sigmaY=5,
    )
    repair_alpha = np.clip(repair_alpha, 0, 1)
    repaired_rgb = (
        repaired_rgb * (1 - repair_alpha[:, :, None])
        + sky_field * repair_alpha[:, :, None]
    )
    repaired_rgb = np.clip(repaired_rgb, 0, 255).astype(np.uint8)
    alpha = np.full((master.height, master.width), 255, np.uint8)
    return Image.fromarray(np.dstack((repaired_rgb, alpha)), "RGBA")


def _layer_gate(size: tuple[int, int], spec: CloudLayer) -> np.ndarray:
    width, height = size
    y = np.arange(height)[:, None]
    x = np.arange(width)[None, :]

    def smoothstep(edge0: float, edge1: float, value: np.ndarray) -> np.ndarray:
        t = np.clip((value - edge0) / (edge1 - edge0), 0, 1)
        return t * t * (3 - 2 * t)

    horizontal = smoothstep(spec.x_min, spec.x_min + spec.feather, x) * (
        1 - smoothstep(spec.x_max - spec.feather, spec.x_max, x)
    )
    vertical = smoothstep(spec.y_min, spec.y_min + spec.feather, y) * (
        1 - smoothstep(spec.y_max - spec.feather, spec.y_max, y)
    )
    return horizontal * vertical


def _write_cloud_layers(
    master: Image.Image,
    mask: np.ndarray,
    excluded: np.ndarray,
    out_dir: Path,
    preview_dir: Path,
) -> None:
    all_mask = Image.fromarray(mask, "L")
    all_mask.save(preview_dir / "clouds_all_mask.png")
    cloud_source = _deoccluded_cloud_source(master, excluded)
    cloud_source.save(preview_dir / "cloud_source_deoccluded.png")

    for spec in _CLOUD_LAYERS:
        gated = np.clip(mask.astype(np.float32) * _layer_gate(master.size, spec), 0, 255)
        layer_mask = Image.fromarray(gated.astype(np.uint8), "L")
        layer = cloud_source.copy()
        layer.putalpha(layer_mask)
        _save_webp(layer, out_dir / f"{spec.name}.webp")
        layer_mask.save(preview_dir / f"{spec.name}_mask.png")

    overlay = master.copy()
    tint = Image.new("RGBA", master.size, (255, 92, 28, 0))
    tint.putalpha(Image.fromarray((mask * 0.7).astype(np.uint8), "L"))
    overlay.alpha_composite(tint)
    overlay.save(preview_dir / "cloud_mask_preview.png")


def _write_cloudless_plate(
    master: Image.Image,
    stencil_mask: np.ndarray,
    erase_mask: np.ndarray,
    excluded: np.ndarray,
    out_dir: Path,
    preview_dir: Path,
) -> None:
    rgb_u8 = np.asarray(master.convert("RGB"))
    rgb = rgb_u8.astype(np.float32)
    bgr = cv2.cvtColor(rgb_u8, cv2.COLOR_RGB2BGR)
    inpaint_mask = cv2.dilate(
        (stencil_mask > 12).astype(np.uint8) * 255,
        np.ones((17, 17), np.uint8),
        iterations=1,
    )
    inpaint_mask[excluded > 0] = 0
    cloudless = cv2.inpaint(bgr, inpaint_mask, 9, cv2.INPAINT_TELEA)
    cloudless_rgb = cv2.cvtColor(cloudless, cv2.COLOR_BGR2RGB).astype(np.float32)

    clean_sky = _estimate_clean_sky(rgb, excluded)
    sky_field = np.repeat(clean_sky[:, None, :], master.width, axis=1)
    sky_texture = cv2.GaussianBlur(rgb, (0, 0), sigmaX=90, sigmaY=42)
    sky_field = sky_field * 0.78 + sky_texture * 0.22
    erase_alpha = cv2.GaussianBlur(
        erase_mask.astype(np.float32) / 255,
        (0, 0),
        sigmaX=7,
        sigmaY=7,
    )
    erase_alpha = np.clip(erase_alpha * 0.92, 0, 0.92)
    erase_alpha[excluded > 0] = 0
    cloudless_rgb = (
        cloudless_rgb * (1 - erase_alpha[:, :, None])
        + sky_field * erase_alpha[:, :, None]
    )
    cloudless_rgb = np.clip(cloudless_rgb, 0, 255).astype(np.uint8)

    alpha = np.full((master.height, master.width), 255, np.uint8)
    cloudless_image = Image.fromarray(np.dstack((cloudless_rgb, alpha)), "RGBA")
    _save_webp(cloudless_image, out_dir / "blue_hour_cloudless.webp")
    cloudless_image.save(preview_dir / "blue_hour_cloudless.png")
    Image.fromarray(erase_mask, "L").save(preview_dir / "clouds_erase_mask.png")

    recomposed = cloudless_image.copy()
    for spec in _CLOUD_LAYERS:
        recomposed.alpha_composite(_rgba(out_dir / f"{spec.name}.webp"))
    recomposed.save(preview_dir / "clouds_recomposed.png")


def _alpha_summary(mask: np.ndarray) -> str:
    ys, xs = np.nonzero(mask)
    if xs.size == 0:
        return "empty"
    bbox = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    coverage = xs.size / math.prod(mask.shape)
    return f"bbox={bbox} alpha=({int(mask.min())},{int(mask.max())}) coverage={coverage:.2%}"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="extract exact cloud pixels into parallax layers",
    )
    parser.add_argument("--master", required=True, type=Path)
    parser.add_argument("--city-bridge", required=True, type=Path)
    parser.add_argument("--yacht", required=True, type=Path)
    parser.add_argument("--foreground", required=True, type=Path)
    parser.add_argument("--out-dir", required=True, type=Path)
    parser.add_argument("--preview-dir", required=True, type=Path)
    args = parser.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)
    args.preview_dir.mkdir(parents=True, exist_ok=True)

    master = _rgba(args.master)
    excluded = _structural_exclusion(
        [args.foreground, args.yacht, args.city_bridge],
        master.size,
    )
    masks = _cloud_masks(master, excluded)
    _write_cloud_layers(
        master,
        masks.motion,
        excluded,
        args.out_dir,
        args.preview_dir,
    )
    masks_image = Image.fromarray(masks.stencil, "L")
    masks_image.save(args.preview_dir / "clouds_stencil_mask.png")
    _write_cloudless_plate(
        master,
        masks.stencil,
        masks.erase,
        excluded,
        args.out_dir,
        args.preview_dir,
    )

    print(
        f"clouds: motion {_alpha_summary(masks.motion)}; "
        f"stencil {_alpha_summary(masks.stencil)}",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
