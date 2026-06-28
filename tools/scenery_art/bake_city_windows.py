#!/usr/bin/env python3
"""Bake a REGISTERED city-window field from the painted master plate.

The blue-hour master (`assets/scenery/blue_hour_master.png`) already paints every
building with its real window grid. Rather than ship a second skyline render whose
windows never line up (the discarded `city_bridge.png`), we DETECT the painted
windows in the master itself, so the runtime glow lands exactly on them by
construction.

Pipeline (all in the master's own pixel space, so output is pixel-registered):
  1. luminance L of the master
  2. high-pass  detail = L - GaussianBlur(L, 2.5)   -> isolates the fine window
     grid from the smooth facade/sky gradients
  3. wmag = |detail|                                -> window-edge magnitude
  4. dens = GaussianBlur(wmag, 16)                  -> texture density; high only
     where many window edges cluster (= building faces), low on blank sky/water
  5. interior = clip((dens - 4)/7, 0, 1)            -> soft building-interior mask
  6. gate interior to the skyline band (above the far waterline, below the sky)
     and subtract the foreground (deck/palms) and yacht alphas so their texture
     never reads as windows
  7. erode interior (MinFilter 9) so glowing silhouette outlines / wireframe rims
     drop out and only deep interior survives
  8. FILL the window panes, never the edges. The field must mark window GLASS
     (filled cells) + a solid building-face base, NOT the high-pass edge lattice:
        panes = clip((blur - L)/12, 0, 1)   -> recessed dark window glass, filled.
            Because panes are the DARK cells, this lights pane INTERIORS and is 0
            on every bright edge (mullions AND the building's own silhouette
            sides), so nothing streaks vertically up the tower edges or past the
            roofline the way an |edge| field does.
        face  = smoothstep(.35,.65, interiorEroded) -> solid lit-able face base, so
            faces with sky-bright (reflective) windows still light whole floors.
        wfield = clip(0.40*face + 0.85*panes, 0, 1), hard-stopped at the waterline.

Output `assets/scenery/city_windows.png` (RGBA, opaque). Channel packing:
  * R: city window field — "is this a lit-able window face, how strong". The
    city-lights shader paints its own per-floor lit/dark selection + tint +
    flicker on top. SOLID faces + registered pane fills, never edges, so lit
    windows read as filled panes/floors instead of a glowing wireframe.
  * G: yacht TV-window mask — the large lower-deck swoop pane (shader fills a
    flickering screen glow here).
  * B: yacht cabin-window mask — the sky-lounge and main-saloon windows in the
    bright superstructure (shader fills the warm interior cabin glow here).

Run:  python3 tools/scenery_art/bake_city_windows.py
(needs Pillow + numpy)
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

REPO = Path(__file__).resolve().parents[2]
MASTER = REPO / "assets/scenery/blue_hour_master.png"
FOREGROUND = REPO / "assets/scenery/foreground.png"
YACHT = REPO / "assets/scenery/yacht.png"
OUT = REPO / "assets/scenery/city_windows.png"

# Skyline band in normalized art-y: above the tallest tower top, down to the far
# shore waterline. Buildings live entirely inside this band.
BAND_TOP = 0.15
BAND_BOTTOM = 0.515

# Normalized art-x span of the cable-stayed bridge (left approach + piers + tower
# + cable fan + right deck). The dynamic window field is hard-zeroed across this
# whole span: a bridge has NO lit windows. The nearest real highrise ends at
# x~0.527, so BRIDGE_X0 sits just right of it (soft-edged) to keep it fully lit.
BRIDGE_X0 = 0.532
BRIDGE_X1 = 0.80


def _smoothstep(a: float, b: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _alpha(path: Path, size: tuple[int, int]) -> np.ndarray:
    img = Image.open(path).convert("RGBA").resize(size, Image.Resampling.LANCZOS)
    return np.asarray(img, dtype=np.float64)[..., 3] / 255.0


def _erode_y(mask: np.ndarray, k: int) -> np.ndarray:
    """Binary erosion along Y only: a pixel survives iff all of its +-k vertical
    neighbours are set. Erases horizontal lines up to 2k px tall while leaving
    taller features (window panes) intact apart from a k-px trim top and bottom."""
    out = mask.copy()
    for dy in range(1, k + 1):
        out &= np.roll(mask, dy, axis=0)
        out &= np.roll(mask, -dy, axis=0)
    return out


def _dilate_y(mask: np.ndarray, k: int) -> np.ndarray:
    """Binary dilation along Y only — inverse of `_erode_y`; together they form a
    vertical opening that removes thin horizontal structures and restores the
    surviving panes to their original height."""
    out = mask.copy()
    for dy in range(1, k + 1):
        out |= np.roll(mask, dy, axis=0)
        out |= np.roll(mask, -dy, axis=0)
    return out


def main() -> int:
    master = Image.open(MASTER).convert("RGB")
    w, h = master.size
    lum = np.asarray(master.convert("L"), dtype=np.float64)

    # High-pass: the painted window grid vs. the smooth facade gradient.
    blur = np.asarray(
        master.convert("L").filter(ImageFilter.GaussianBlur(2.5)),
        dtype=np.float64,
    )
    wmag = np.abs(lum - blur)

    # Texture density -> building interiors (many window edges clustered). A
    # tighter blur than the lit area so the face mask hugs the silhouette and
    # does not spread far up into the sky above the roofline.
    dens = np.asarray(
        Image.fromarray(np.clip(wmag, 0, 255).astype(np.uint8)).filter(
            ImageFilter.GaussianBlur(12),
        ),
        dtype=np.float64,
    )
    interior = np.clip((dens - 4.0) / 7.0, 0.0, 1.0)

    # Skyline band + exclude foreground (deck/palms) and yacht texture.
    yy = np.mgrid[0:h, 0:w][0].astype(np.float64) / h
    band = _smoothstep(BAND_TOP, BAND_TOP + 0.02, yy) * (
        1.0 - _smoothstep(BAND_BOTTOM - 0.02, BAND_BOTTOM, yy)
    )
    interior *= band
    interior *= 1.0 - _alpha(FOREGROUND, (w, h))
    interior *= 1.0 - _alpha(YACHT, (w, h))

    # Erode so glowing rooflines / cable rims / hull edges drop out and the face
    # mask sits INSIDE the painted silhouette (no emission past the roofline).
    interior_eroded = (
        np.asarray(
            Image.fromarray((interior * 255).astype(np.uint8)).filter(
                ImageFilter.MinFilter(9),
            ),
            dtype=np.float64,
        )
        / 255.0
    )

    # FILL the panes, never the edges. `panes` lights the recessed DARK window
    # glass (filled cells), which is 0 on every bright edge — mullions and the
    # tower's own silhouette sides — so nothing streaks vertically up the towers
    # or bleeds past the roofline the way an |edge| field does. `face` is a solid
    # lit-able base so sky-bright (reflective) facades still light whole floors.
    panes = np.clip((blur - lum) / 12.0, 0.0, 1.0) * interior_eroded
    face = _smoothstep(0.35, 0.65, interior_eroded)
    wfield = np.clip(0.40 * face + 0.85 * panes, 0.0, 1.0)

    # Hard-zero the whole cable-stayed BRIDGE span. Its towers, cable fan, deck
    # and piers carry dense structure that the texture detector reads as a
    # building, but a bridge has NO lit windows — if the field marks it, the
    # runtime lights it like a tower full of windows (and the occupancy churn then
    # blinks them, which reads as a malfunction). A bridge's only night lighting
    # is the deck streetlights PAINTED into the master plate (static) and the red
    # aircraft beacons (drawn by the canvas layer), both untouched here. We zero a
    # solid x-band over the span, soft-edged so the nearest real highrise just to
    # its left (ending ~0.527) stays fully lit.
    xx = np.mgrid[0:h, 0:w][1].astype(np.float64) / w
    bridge_band = _smoothstep(BRIDGE_X0, BRIDGE_X0 + 0.012, xx) * (
        1.0 - _smoothstep(BRIDGE_X1 - 0.02, BRIDGE_X1, xx)
    )
    wfield *= 1.0 - bridge_band

    # Distant buildings behind the foreground palm on the FAR RIGHT show through
    # its sparse fronds as ugly bright window squares (the palm alpha is too thin
    # to mask them). They are deep background beside the yacht, so drop the
    # dynamic field there and let them sit as dim painted silhouettes under the
    # sunset instead of a lit "house" behind the palm.
    far_right = _smoothstep(0.86, 0.90, xx)
    wfield *= 1.0 - far_right

    wfield[yy > BAND_BOTTOM] = 0.0

    # --- Yacht TV-window mask (GREEN channel) ---
    # The large lower-deck window is a distinctive dark "swoop" pane. Detect its
    # EXACT painted glass — the dark pixels in its tight footprint, right of the
    # hull porthole — so the runtime TV glow fills the real window shape and
    # position by construction, never a hand-placed box. The shader reads this
    # from `.g`; the city window field stays in `.r`.
    yt = Image.open(YACHT).convert("RGBA").resize((w, h), Image.Resampling.LANCZOS)
    yt_arr = np.asarray(yt, dtype=np.float64)
    yt_lum = (
        0.299 * yt_arr[..., 0] + 0.587 * yt_arr[..., 1] + 0.114 * yt_arr[..., 2]
    )
    yt_a = yt_arr[..., 3] / 255.0
    tv_region = (
        (yy > 0.552) & (yy < 0.609) & (xx > 0.806) & (xx < 0.882)
    )
    tv_mask = (tv_region & (yt_lum < 65.0) & (yt_a > 0.05)).astype(np.float64)
    # Soften so the screen reads as a glow filling the pane, not a hard cut-out.
    tv_mask = (
        np.asarray(
            Image.fromarray((tv_mask * 255.0).astype(np.uint8)).filter(
                ImageFilter.GaussianBlur(2.5),
            ),
            dtype=np.float64,
        )
        / 255.0
    )

    # --- Yacht cabin-window mask (BLUE channel) ---
    # The sky-lounge and main-saloon windows are recessed DARK panes set into the
    # bright white superstructure. Detect them by a band-pass that FILLS panes but
    # REJECTS the dark hull: a window pane is dark AND sits inside brighter
    # structure, so a large-radius blur of the luminance is much brighter than the
    # pane (recessBig high across the WHOLE pane); the dark bow hull is dark with
    # dark neighbours, so recessBig stays low in its interior and it drops out.
    #
    # The stubborn false-positive is the long, thin, near-horizontal sheer/rubrail
    # hairline (2-4px tall) that runs the full hull length: a square MinFilter
    # cannot kill a continuous line, and when blurred it smears a warm "gold piping"
    # stripe across the topsides. A VERTICAL OPENING (erode-Y then dilate-Y, k=4)
    # erases every horizontal structure <=8px tall while the >=9px window panes
    # survive at full height. The band is then confined to the superstructure
    # (x>0.72, y<0.55): the bow carries no glass (only hull, anchor and the hawse
    # marking) and the lower bound stops above the porthole row and the waterline,
    # dropping the boot-stripe / bow-wave specks. The shader fills the warm cabin
    # glow from `.b`; the TV window (`.g`) is excluded so it is not double-lit. No
    # hand-placed boxes — the glow lands on the real window shapes by construction.
    blur_big = np.asarray(
        Image.fromarray(np.clip(yt_lum, 0, 255).astype(np.uint8)).filter(
            ImageFilter.GaussianBlur(14),
        ),
        dtype=np.float64,
    )
    recess_big = blur_big - yt_lum
    # Threshold BELOW the dark-navy hull topsides (lum ~30) so the long hull sheer
    # band is NOT mistaken for a window: real glass is lum ~6-21 (saloon 6,
    # upper-deck 17), the hull/superstructure is 23-93. lum<22 keeps every window
    # and rejects the hull, killing the warm stripe an over-loose threshold smeared
    # across the topsides.
    dark = (yt_lum < 22.0) & (yt_a > 0.10)
    # Vertical opening: erase thin horizontal hairlines (sheer / rubrail / boot
    # stripe, <=8px tall) but keep the >=9px window panes at full height.
    dark_core = _dilate_y(_erode_y(dark, 4), 4)
    cabin_band = (yy > 0.40) & (yy < 0.55) & (xx > 0.72) & (xx < 0.99)
    cabin_mask = (
        cabin_band
        & dark_core
        & (recess_big > 9.0)
        & (yt_a > 0.10)
        & (~tv_region)
    ).astype(np.float64)
    cabin_mask = (
        np.asarray(
            Image.fromarray((cabin_mask * 255.0).astype(np.uint8)).filter(
                ImageFilter.GaussianBlur(2.0),
            ),
            dtype=np.float64,
        )
        / 255.0
    )

    v = (np.clip(wfield, 0.0, 1.0) * 255.0).astype(np.uint8)
    tv = (np.clip(tv_mask, 0.0, 1.0) * 255.0).astype(np.uint8)
    cabin = (np.clip(cabin_mask, 0.0, 1.0) * 255.0).astype(np.uint8)
    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[..., 0] = v      # R: city window field
    rgba[..., 1] = tv     # G: yacht TV-window mask
    rgba[..., 2] = cabin  # B: yacht cabin-window mask (warm interior glow)
    rgba[..., 3] = 255
    Image.fromarray(rgba, "RGBA").save(OUT)
    print(
        f"wrote {OUT}  city px(>0.1)={int((wfield > 0.1).sum())}  "
        f"tv px(>0.1)={int((tv_mask > 0.1).sum())}  "
        f"cabin px(>0.1)={int((cabin_mask > 0.1).sum())}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
