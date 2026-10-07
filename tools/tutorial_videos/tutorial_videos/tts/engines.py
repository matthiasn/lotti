"""Builds the TTS engine ``voices.yaml`` (or ``--tts-engine``) names, with its
API key read from the repo ``.env``."""

from __future__ import annotations

from pathlib import Path

from .base import TtsEngine, TtsError
from .elevenlabs import ElevenLabsTts
from .gemini import GeminiTts, read_env_key

# Engine name -> (the .env key holding its API key, its adapter).
ENGINES = {
    "elevenlabs": ("ELEVENLABS_API_KEY", ElevenLabsTts),
    "gemini": ("GEMINI_API_KEY", GeminiTts),
}


def create_engine(name: str, model: str, env_path: Path) -> TtsEngine:
    if name not in ENGINES:
        raise TtsError(f"unknown TTS engine {name!r}; choose from {', '.join(ENGINES)}")
    key_name, adapter = ENGINES[name]
    return adapter(read_env_key(env_path, key_name), model)
