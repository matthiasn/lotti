"""ElevenLabs TTS adapter.

Calls ``POST /v1/text-to-speech/<voice id>`` via plain urllib — no SDK
dependency — asking for ``pcm_24000`` (16-bit mono little-endian PCM at
24 kHz, the same as Gemini returns), which is wrapped into a WAV container
here. The API key comes from the repo ``.env`` (``ELEVENLABS_API_KEY``).

ElevenLabs takes no spoken style instruction: the voice and its
``voice_settings`` (stability, similarity_boost, style, speed,
use_speaker_boost — passed through from ``voices.yaml`` as they are) carry
the delivery, and the multilingual models read the language off the text,
so the same voice narrates every locale.
"""

from __future__ import annotations

import json
import urllib.error
import urllib.parse
import urllib.request

from .base import TtsError, pcm_to_wav

API_BASE = "https://api.elevenlabs.io/v1/text-to-speech"
SAMPLE_RATE = 24_000

# How much of an error response to quote: enough for ElevenLabs' validation
# detail, short of dumping an HTML error page.
_ERROR_DETAIL_CHARS = 500


class ElevenLabsTts:
    name = "elevenlabs"

    def __init__(self, api_key: str, model: str) -> None:
        self._api_key = api_key
        self.model = model

    def synthesize(self, *, text: str, voice: str, style: str, settings: dict) -> bytes:
        # `style` is unused: ElevenLabs has no instruction prompt (see the
        # module docstring); the voice settings are the equivalent.
        body: dict = {"text": text, "model_id": self.model}
        if settings:
            body["voice_settings"] = dict(settings)
        request = urllib.request.Request(
            f"{API_BASE}/{urllib.parse.quote(voice, safe='')}"
            f"?output_format=pcm_{SAMPLE_RATE}",
            data=json.dumps(body).encode(),
            headers={"Content-Type": "application/json", "xi-api-key": self._api_key},
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                pcm = response.read()
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", "replace")[:_ERROR_DETAIL_CHARS]
            raise TtsError(
                f"ElevenLabs TTS failed for voice {voice!r}: HTTP {error.code} {detail}"
            ) from None
        if not pcm:
            raise TtsError(f"ElevenLabs TTS returned no audio for voice {voice!r}")
        return pcm_to_wav(pcm, SAMPLE_RATE)
