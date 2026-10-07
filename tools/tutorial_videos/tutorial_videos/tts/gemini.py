"""Gemini native TTS adapter (default engine).

Calls ``models/<model>:generateContent`` with AUDIO response modality via
plain urllib — no SDK dependency. Gemini returns 24 kHz mono s16le PCM,
which is wrapped into a WAV container here. The API key comes from the repo
``.env`` (``GEMINI_API_KEY``), matching the key already configured in the
app's AI settings.
"""

from __future__ import annotations

import base64
import json
import urllib.request
from pathlib import Path

from .base import pcm_to_wav

SAMPLE_RATE = 24_000


def read_env_key(env_path: Path, name: str) -> str:
    for line in env_path.read_text().splitlines():
        if line.startswith(f"{name}="):
            return line.split("=", 1)[1].strip()
    raise KeyError(f"{name} not found in {env_path}")


class GeminiTts:
    name = "gemini"

    def __init__(self, api_key: str, model: str) -> None:
        self._api_key = api_key
        self.model = model

    def synthesize(
        self, *, text: str, voice: str, style: str, settings: dict
    ) -> bytes:
        # Gemini has no per-voice settings: the style instruction, spoken
        # ahead of the text, carries the delivery.
        body = {
            "contents": [{"parts": [{"text": f"{style} {text}"}]}],
            "generationConfig": {
                "responseModalities": ["AUDIO"],
                "speechConfig": {
                    "voiceConfig": {"prebuiltVoiceConfig": {"voiceName": voice}}
                },
            },
        }
        req = urllib.request.Request(
            "https://generativelanguage.googleapis.com/v1beta/"
            f"{self.model}:generateContent",
            data=json.dumps(body).encode(),
            headers={
                "Content-Type": "application/json",
                "x-goog-api-key": self._api_key,
            },
        )
        with urllib.request.urlopen(req, timeout=120) as resp:
            payload = json.load(resp)
        candidates = payload.get("candidates") or []
        if not candidates or not candidates[0].get("content", {}).get("parts"):
            raise RuntimeError(
                f"Gemini TTS returned no audio for voice {voice!r}: {payload}"
            )
        part = candidates[0]["content"]["parts"][0]
        return pcm_to_wav(base64.b64decode(part["inlineData"]["data"]), SAMPLE_RATE)
