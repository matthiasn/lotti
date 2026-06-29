#!/usr/bin/env python3
"""Bake a REGISTERED city-window field from the painted master plate.

The blue-hour master (`assets/scenery/blue_hour_master.webp`) already paints every
building with its real window grid. Rather than ship a second skyline render whose
windows never line up (the discarded `city_bridge.webp`), we DETECT the painted
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
     (filled cells), NOT a solid facade mask and NOT the high-pass edge lattice:
        panes = clip((blur - L)/12, 0, 1)   -> recessed dark window glass, filled.
            Because panes are the DARK cells, this lights pane INTERIORS and is 0
            on every bright edge (mullions AND the building's own silhouette
            sides), so nothing streaks vertically up the tower edges or past the
            roofline the way an |edge| field does.
        wfield = paneCore, hard-stopped above the waterfront/bridge band.

Output `assets/scenery/city_windows.webp` (RGBA, opaque). Channel packing:
  * R: city window field — "is this a lit-able window face, how strong". The
    city-lights shader paints its own per-floor lit/dark selection + tint +
    flicker on top. Registered pane fills only, never solid facade regions, so
    lit windows read as panes instead of glowing building-shaped blocks whose
    reflections become fake bridge/pylon structures in the water.
  * G: unused (0). Formerly an offset hand-placed "TV window" box; removed — every
    lit yacht window now lives in the cabin mask (B).
  * B: yacht cabin-window mask — every window lit warm from inside. Authoritative
    source is the hand-cut `yacht_windows.webp` layer (opaque ONLY on the window
    glass); its alpha is read straight in. A luminance detector is the fallback.
    The shader fills the warm cabin glow exactly there.

Run:  python3 tools/scenery_art/bake_city_windows.py
(needs Pillow + numpy)
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

REPO = Path(__file__).resolve().parents[2]
MASTER = REPO / "assets/scenery/blue_hour_master.webp"
FOREGROUND = REPO / "assets/scenery/foreground.webp"
YACHT = REPO / "assets/scenery/yacht.webp"
# HAND-CUT lit-window layer (opaque ONLY on the window glass,
# transparent everywhere else), aligned 1:1 to yacht.webp. Its ALPHA is the
# authoritative B-channel mask — the shader fills warm interior glow exactly on
# the cut pixels. When absent, the luminance detector below is the fallback.
YACHT_WINDOWS = REPO / "assets/scenery/yacht_windows.webp"
OUT = REPO / "assets/scenery/city_windows.webp"

# Skyline band in normalized art-y: above the tallest tower top, down to the far
# shore waterline. Buildings live entirely inside this band.
BAND_TOP = 0.15
BAND_BOTTOM = 0.515

# Stop city-window detection before the far-shore bridge/deck/waterfront clutter.
# Those low structures contain dense lines and bright/dark edges that the detector
# cannot distinguish from high-rise windows; if they enter the R channel, the
# shader's water-reflection pass mirrors them into fake pylons/blocks in the
# lagoon. Keep this conservative: dynamic city lights belong to the high-rises;
# the low waterfront remains baked into the master plate.
WINDOW_FIELD_BOTTOM = 0.405

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


def _bright_within(lum: np.ndarray, lo: int, hi: int, thresh: float) -> np.ndarray:
    """True where the MAX luminance among rows [lo..hi] away (positive = below,
    negative = above) exceeds `thresh`. Used to test that a dark pane is set into
    BRIGHT structure on a given side."""
    acc = np.zeros(lum.shape, dtype=bool)
    a, b = sorted((lo, hi))
    for dy in range(a, b + 1):
        acc |= np.roll(lum, -dy, axis=0) > thresh
    return acc


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
    # or bleeds past the roofline the way an |edge| field does. Do NOT add a
    # solid "face" component: it turns whole facades/low waterfront structures
    # into light-emitting masks, and the reflection shader mirrors those blocks
    # into fake bridge/pylon shapes in the water.
    panes = np.clip((blur - lum) / 12.0, 0.0, 1.0) * interior_eroded
    pane_core = _smoothstep(0.16, 0.72, panes)
    # Feather back a little of the sub-threshold pane edge after the hard core
    # selection so individual windows still glow softly, without resurrecting
    # the broad facade mask.
    pane_soft = np.clip((panes - 0.06) / 0.42, 0.0, 1.0) * 0.28
    wfield = np.clip(np.maximum(pane_core, pane_soft), 0.0, 1.0)

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

    # Distant/yacht-adjacent right-side structure and mast detail is not part of
    # the high-rise window field. The yacht is lit by the B-channel cabin mask and
    # canvas navigation lamps; leaving city-window R pixels here makes antennas
    # and palm slivers emit like high-rise panes.
    far_right = _smoothstep(0.80, 0.84, xx)
    wfield *= 1.0 - far_right

    wfield[yy > WINDOW_FIELD_BOTTOM] = 0.0

    yt = Image.open(YACHT).convert("RGBA").resize((w, h), Image.Resampling.LANCZOS)
    yt_arr = np.asarray(yt, dtype=np.float64)
    yt_lum = (
        0.299 * yt_arr[..., 0] + 0.587 * yt_arr[..., 1] + 0.114 * yt_arr[..., 2]
    )
    yt_a = yt_arr[..., 3] / 255.0

    # --- Yacht cabin-window mask (BLUE channel) ---
    # The HAND-CUT `yacht_windows.webp` layer is AUTHORITATIVE when present: a
    # cut-out aligned 1:1 to yacht.webp that is opaque ONLY over the window glass.
    # Its alpha is read straight in (resized to the bake canvas), so the shader
    # fills the warm interior glow exactly on the cut pixels — the lit windows
    # match the painted glass by construction.
    #
    # Luminance auto-detection can NOT cleanly isolate this yacht's glass — the
    # panes are mid-tone, the open side decks and under-overhang recesses sit at the
    # same luminance, and thresholds leave speckle — so the cut-out is the reliable
    # source. The detector below is only a fallback when no cut-out is present.
    if YACHT_WINDOWS.exists():
        # The cut-out's ALPHA is the lit-window map (opaque = lit glass).
        cm = Image.open(YACHT_WINDOWS).convert("RGBA").resize(
            (w, h), Image.Resampling.LANCZOS
        ).split()[-1]
        cabin_mask = np.asarray(cm, dtype=np.float64) / 255.0
        # Feather the painted edges so the glow has no hard cut line.
        cabin_mask = (
            np.asarray(
                Image.fromarray((cabin_mask * 255.0).astype(np.uint8)).filter(
                    ImageFilter.GaussianBlur(1.5),
                ),
                dtype=np.float64,
            )
            / 255.0
        )
    else:
        # Fallback: a dark pane set into bright structure (bright above AND below),
        # cleaned with a close+open to fill mullions and drop speckle.
        px = h / 100.0
        reach = int(4.5 * px)
        near = int(0.6 * px)
        dark = (yt_lum < 26.0) & (yt_a > 0.20)
        set_in_struct = _bright_within(
            yt_lum, -reach, -near, 70.0
        ) & _bright_within(yt_lum, near, reach, 70.0)
        cabin_band = (yy > 0.40) & (yy < 0.605) & (xx > 0.70) & (xx < 0.99)
        cabin_bool = dark & set_in_struct & cabin_band & (yt_a > 0.20)
        cabin_mask = (
            np.asarray(
                Image.fromarray((cabin_bool.astype(np.uint8) * 255))
                .filter(ImageFilter.MaxFilter(7))
                .filter(ImageFilter.MinFilter(7))   # close: fill mullions
                .filter(ImageFilter.MinFilter(5))
                .filter(ImageFilter.MaxFilter(5))   # open: drop speckle
                .filter(ImageFilter.GaussianBlur(1.0)),
                dtype=np.float64,
            )
            / 255.0
        )

    v = (np.clip(wfield, 0.0, 1.0) * 255.0).astype(np.uint8)
    cabin = (np.clip(cabin_mask, 0.0, 1.0) * 255.0).astype(np.uint8)
    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[..., 0] = v       # R: city window field
    rgba[..., 1] = 0       # G: unused (the former offset TV box is removed)
    rgba[..., 2] = cabin   # B: yacht cabin-window mask (warm interior glow)
    rgba[..., 3] = 255
    Image.fromarray(rgba, "RGBA").save(
        OUT,
        "WEBP",
        lossless=True,
        quality=100,
        method=6,
    )
    print(
        f"wrote {OUT}  city px(>0.1)={int((wfield > 0.1).sum())}  "
        f"cabin px(>0.1)={int((cabin_mask > 0.1).sum())}  "
        f"mask={'hand-cut' if YACHT_WINDOWS.exists() else 'detector fallback'}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
