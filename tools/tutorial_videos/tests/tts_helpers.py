"""Shared fixtures for the TTS adapter tests: a stand-in for urlopen."""

from __future__ import annotations

import io
import sys
import urllib.error
import urllib.request
import wave
from pathlib import Path
from unittest import mock

TOOL_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL_ROOT))


def respond_with(body: bytes):
    """Patches ``urllib.request.urlopen`` to answer every request with
    ``body``; the patch's mock records the requests."""
    return mock.patch.object(
        urllib.request, "urlopen", side_effect=lambda *_, **__: io.BytesIO(body)
    )


def fail_with(code: int, body: bytes):
    """Patches ``urllib.request.urlopen`` to raise an HTTP ``code`` error."""

    def raise_error(request, **_):
        raise urllib.error.HTTPError(
            request.full_url, code, "error", {}, io.BytesIO(body)
        )

    return mock.patch.object(urllib.request, "urlopen", side_effect=raise_error)


def wav_info(data: bytes) -> tuple[int, int, int, bytes]:
    """(channels, sample width, frame rate, frames) of WAV bytes."""
    with wave.open(io.BytesIO(data), "rb") as wav:
        return (
            wav.getnchannels(),
            wav.getsampwidth(),
            wav.getframerate(),
            wav.readframes(wav.getnframes()),
        )
