"""Shared fixtures for the avatar tests: WAV writing and PNG decoding."""

from __future__ import annotations

import struct
import sys
import wave
import zlib
from pathlib import Path

TOOL_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL_ROOT))


def write_wav(
    path: Path,
    samples: list[int],
    *,
    rate: int = 100,
    channels: int = 1,
    sample_width: int = 2,
) -> Path:
    """Writes interleaved integer ``samples`` as a PCM WAV."""
    fmt = {1: "b", 2: "h"}[sample_width]
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(channels)
        wav.setsampwidth(sample_width)
        wav.setframerate(rate)
        # 8-bit WAV is unsigned; shift so the caller's signed values fit.
        data = (
            bytes(value + 128 for value in samples)
            if sample_width == 1
            else struct.pack(f"<{len(samples)}{fmt}", *samples)
        )
        wav.writeframes(data)
    return path


def decode_png(data: bytes) -> tuple[int, int, bytes]:
    """(width, height, RGBA bytes) of an unfiltered 8-bit RGBA PNG, checking
    the signature and every chunk's CRC on the way."""
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "not a PNG signature"
    offset, idat, width, height = 8, b"", 0, 0
    while offset < len(data):
        (length,) = struct.unpack(">I", data[offset : offset + 4])
        kind = data[offset + 4 : offset + 8]
        body = data[offset + 8 : offset + 8 + length]
        (crc,) = struct.unpack(">I", data[offset + 8 + length : offset + 12 + length])
        assert crc == zlib.crc32(kind + body) & 0xFFFFFFFF, f"bad CRC on {kind!r}"
        if kind == b"IHDR":
            width, height, depth, color_type = struct.unpack(">IIBB", body[:10])
            assert (depth, color_type) == (8, 6), "expected 8-bit RGBA"
        elif kind == b"IDAT":
            idat += body
        offset += 12 + length
    raw = zlib.decompress(idat)
    stride = width * 4 + 1
    rows = [raw[row * stride : (row + 1) * stride] for row in range(height)]
    assert all(row[0] == 0 for row in rows), "expected filter type 0 rows"
    return width, height, b"".join(row[1:] for row in rows)


def pixel(rgba: bytes, size: int, x: int, y: int) -> tuple[int, int, int, int]:
    index = (y * size + x) * 4
    return tuple(rgba[index : index + 4])
