#!/usr/bin/env python3
"""Rewrites 8-bit RGBA PNGs as opaque RGB, in place.

`xcrun simctl io <udid> screenshot` always writes RGBA, and App Store Connect
rejects a screenshot that carries an alpha channel — with the same message it
uses for a wrong size, which is how this was found. The alpha here is fully
opaque (the simulator has no transparent pixels), so dropping the channel loses
nothing; the pixel dimensions and the sRGB profile chunk are kept. A PNG with
any pixel that is not fully opaque is refused rather than silently changed.

Pure standard library, so it runs on a stock macOS runner without a pip step.

    strip_alpha.py FILE.png [FILE.png ...]
"""

from __future__ import annotations

import struct
import sys
import zlib
from pathlib import Path

_SIGNATURE = b"\x89PNG\r\n\x1a\n"
_RGBA = 6
_RGB = 2


def _chunks(data: bytes):
    pos = len(_SIGNATURE)
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos : pos + 4])
        kind = data[pos + 4 : pos + 8]
        body = data[pos + 8 : pos + 8 + length]
        yield kind, body
        pos += 12 + length


def _chunk(kind: bytes, body: bytes) -> bytes:
    return (
        struct.pack(">I", len(body))
        + kind
        + body
        + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)
    )


def _unfilter(raw: bytes, width: int, height: int, bpp: int) -> bytearray:
    """Undoes PNG's per-row filters; returns the bare pixel bytes."""
    stride = width * bpp
    out = bytearray(stride * height)
    prev = bytearray(stride)
    pos = 0
    for row in range(height):
        kind = raw[pos]
        line = bytearray(raw[pos + 1 : pos + 1 + stride])
        pos += 1 + stride
        for i in range(stride):
            a = line[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            if kind == 1:
                line[i] = (line[i] + a) & 0xFF
            elif kind == 2:
                line[i] = (line[i] + b) & 0xFF
            elif kind == 3:
                line[i] = (line[i] + ((a + b) >> 1)) & 0xFF
            elif kind == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if pa <= pb and pa <= pc else b if pb <= pc else c
                line[i] = (line[i] + pred) & 0xFF
            elif kind != 0:
                raise ValueError(f"unknown PNG filter {kind}")
        out[row * stride : (row + 1) * stride] = line
        prev = line
    return out


def strip_alpha(path: Path) -> bool:
    """Returns True when the file was rewritten, False when it had no alpha."""
    data = path.read_bytes()
    if not data.startswith(_SIGNATURE):
        raise ValueError(f"{path} is not a PNG")
    kept: list[bytes] = []
    idat = b""
    header = None
    for kind, body in _chunks(data):
        if kind == b"IHDR":
            header = body
        elif kind == b"IDAT":
            idat += body
            continue
        elif kind == b"IEND":
            continue
        kept.append(_chunk(kind, body) if kind != b"IHDR" else b"")
    if header is None:
        raise ValueError(f"{path} has no IHDR")
    width, height, depth, color, comp, filt, interlace = struct.unpack(
        ">IIBBBBB", header
    )
    if color != _RGBA:
        return False
    if depth != 8 or interlace != 0:
        raise ValueError(f"{path}: only 8-bit non-interlaced RGBA is handled")

    pixels = _unfilter(zlib.decompress(idat), width, height, 4)
    alpha = pixels[3::4]
    if alpha.count(255) != len(alpha):
        # Dropping a real alpha would change how the pixel looks; this tool
        # exists for simulator captures, whose alpha is opaque throughout.
        # Anything else must be composited against a background first.
        raise ValueError(
            f"{path}: has non-opaque pixels; composite it before stripping"
        )
    stride = width * 4
    rows = bytearray()
    for row in range(height):
        line = pixels[row * stride : (row + 1) * stride]
        del line[3::4]
        rows += b"\x00" + line
    new_header = struct.pack(">IIBBBBB", width, height, 8, _RGB, comp, filt, 0)
    out = bytearray(_SIGNATURE)
    out += _chunk(b"IHDR", new_header)
    out += b"".join(kept)
    out += _chunk(b"IDAT", zlib.compress(bytes(rows), 9))
    out += _chunk(b"IEND", b"")
    # Atomic: nothing reading the path meanwhile sees a half-written file.
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_bytes(out)
    tmp.replace(path)
    return True


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__, file=sys.stderr)
        return 2
    for name in argv:
        path = Path(name)
        print(f"{'flattened' if strip_alpha(path) else 'already opaque'}: {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
