"""ElevenLabs TTS adapter (alternative engine).

Calls ``POST /v1/text-to-speech/{voice_id}`` for MP3 audio via plain
urllib — no SDK dependency. ElevenLabs doesn't take a natural-language
"style" instruction the way Gemini does (`style` primes Gemini's own
persona; ElevenLabs would just read it aloud as text), so `style` is
accepted for protocol compatibility but ignored here — the target voice's
own character carries the style. MP3 is decoded to 24 kHz mono WAV via
ffmpeg (already a hard dependency of this whole pipeline) so downstream
duration measurement (`wav_duration_seconds`) works identically across
engines. The API key comes from the repo ``.env`` (``ELEVEN_LABS_API_KEY``).
"""

from __future__ import annotations

import json
import subprocess
import tempfile
import urllib.request
from pathlib import Path

SAMPLE_RATE = 24_000


def _mp3_to_wav(mp3_bytes: bytes) -> bytes:
    with tempfile.TemporaryDirectory() as tmp:
        mp3_path = Path(tmp) / "clip.mp3"
        wav_path = Path(tmp) / "clip.wav"
        mp3_path.write_bytes(mp3_bytes)
        subprocess.run(
            [
                "ffmpeg", "-y", "-loglevel", "error",
                "-i", str(mp3_path),
                "-ar", str(SAMPLE_RATE), "-ac", "1",
                str(wav_path),
            ],
            check=True,
        )
        return wav_path.read_bytes()


class ElevenLabsTts:
    name = "elevenlabs"

    def __init__(self, api_key: str, model: str) -> None:
        self._api_key = api_key
        self.model = model

    def synthesize(self, *, text: str, voice: str, style: str) -> bytes:
        del style  # not applicable to ElevenLabs — see module docstring
        body = {
            "text": text,
            "model_id": self.model,
        }
        req = urllib.request.Request(
            f"https://api.elevenlabs.io/v1/text-to-speech/{voice}"
            "?output_format=mp3_44100_128",
            data=json.dumps(body).encode(),
            headers={
                "Content-Type": "application/json",
                "xi-api-key": self._api_key,
            },
        )
        with urllib.request.urlopen(req, timeout=120) as resp:
            mp3_bytes = resp.read()
        if not mp3_bytes:
            raise RuntimeError(
                f"ElevenLabs TTS returned no audio for voice {voice!r}"
            )
        return _mp3_to_wav(mp3_bytes)


def list_voices(api_key: str) -> list[dict]:
    """Returns the account's available voices (premade + custom)."""
    req = urllib.request.Request(
        "https://api.elevenlabs.io/v1/voices",
        headers={"xi-api-key": api_key},
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        payload = json.load(resp)
    return payload.get("voices", [])
