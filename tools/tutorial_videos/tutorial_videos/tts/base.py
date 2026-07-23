"""TTS engine interface, clip cache, and the pre-pass that renders a
scenario's clips and emits the durations manifest.

The manifest is the contract between the host orchestrator and both later
stages: the Dart tutorial harness paces each step to at least its narration
length, and the compositor places clips at the actual timestamps recorded in
``timeline.json``.
"""

from __future__ import annotations

import hashlib
import json
import wave
from dataclasses import dataclass
from pathlib import Path
from typing import Protocol

from ..scenario import Scenario


def read_env_key(env_path: Path, name: str) -> str:
    for line in env_path.read_text().splitlines():
        if line.startswith(f"{name}="):
            return line.split("=", 1)[1].strip()
    raise KeyError(f"{name} not found in {env_path}")


class TtsEngine(Protocol):
    """A text-to-speech backend (see ``gemini.py`` for the default)."""

    name: str
    model: str

    def synthesize(self, *, text: str, voice: str, style: str) -> bytes:
        """Return complete WAV bytes for ``text``."""
        ...


@dataclass(frozen=True)
class VoiceSpec:
    engine: str  # TtsEngine.name this stream renders through, e.g. "gemini"
    model: str
    voice: str
    style: dict[str, str]  # locale -> style instruction (ignored by engines
    # that don't take a natural-language style prompt, e.g. ElevenLabs — see
    # tts/elevenlabs.py's module docstring)


def load_voices(path: Path) -> dict[str, VoiceSpec]:
    """Load ``voices.yaml`` -> stream -> VoiceSpec.

    Each stream (``narrator``, ``user_voice``) picks its own engine/model, so
    e.g. the narrator can render through ElevenLabs while dictation stays on
    Gemini — the two streams have no reason to share a TTS vendor.
    """
    import yaml

    raw = yaml.safe_load(path.read_text())
    return {
        stream: VoiceSpec(
            engine=spec["engine"],
            model=spec["model"],
            voice=spec["voice"],
            style=dict(spec.get("style", {})),
        )
        for stream, spec in raw["streams"].items()
    }


def wav_duration_seconds(path: Path) -> float:
    with wave.open(str(path), "rb") as wav:
        return wav.getnframes() / wav.getframerate()


def clip_cache_key(
    *, engine: str, model: str, voice: str, style: str, text: str
) -> str:
    payload = "\x1f".join((engine, model, voice, style, text))
    return hashlib.sha256(payload.encode()).hexdigest()[:24]


def synthesize_cached(
    engine: TtsEngine,
    *,
    voice: str,
    style: str,
    text: str,
    cache_dir: Path,
) -> Path:
    """Return the cached WAV for this exact (engine, voice, style, text),
    synthesizing only on cache miss — repeat builds never re-hit the API."""
    cache_dir.mkdir(parents=True, exist_ok=True)
    key = clip_cache_key(
        engine=engine.name, model=engine.model, voice=voice, style=style, text=text
    )
    path = cache_dir / f"{key}.wav"
    if not path.exists():
        path.write_bytes(engine.synthesize(text=text, voice=voice, style=style))
    return path


def render_scenario_clips(
    scenario: Scenario,
    locale: str,
    engines: dict[str, TtsEngine],
    streams: dict[str, VoiceSpec],
    cache_dir: Path,
    manifest_path: Path,
) -> dict:
    """Render all clips for (scenario, locale) and write the manifest.

    ``engines`` maps a `VoiceSpec.engine` name (e.g. ``"gemini"``,
    ``"elevenlabs"``) to the constructed adapter for it — each stream
    resolves its own engine via ``streams[stream].engine``, so narrator and
    dictation can render through different TTS vendors.

    Manifest shape::

        {
          "scenario": ..., "locale": ...,
          "engines": {"narrator": {"name": ..., "model": ...},
                      "user_voice": {"name": ..., "model": ...}},
          "steps": [
            {"id": ..., "min_duration": ...,
             "narration": {"clip": "/abs.wav", "duration": 4.2},
             "dictation": {"clip": "/abs.wav", "duration": 8.9}}  # only where present
          ]
        }
    """
    scenario.validate_locale(locale)
    narrator = streams["narrator"]
    user_voice = streams["user_voice"]
    narrator_engine = engines[narrator.engine]
    user_voice_engine = engines[user_voice.engine]

    steps = []
    for step in scenario.steps:
        clip = synthesize_cached(
            narrator_engine,
            voice=narrator.voice,
            style=narrator.style[locale],
            text=step.narration[locale],
            cache_dir=cache_dir,
        )
        entry: dict = {
            "id": step.id,
            "min_duration": step.min_duration,
            "narration": {
                "clip": str(clip),
                "duration": round(wav_duration_seconds(clip), 3),
            },
        }
        if step.dictation:
            dictation_clip = synthesize_cached(
                user_voice_engine,
                voice=user_voice.voice,
                style=user_voice.style[locale],
                text=step.dictation_text[locale],
                cache_dir=cache_dir,
            )
            entry["dictation"] = {
                "clip": str(dictation_clip),
                "duration": round(wav_duration_seconds(dictation_clip), 3),
            }
        steps.append(entry)

    manifest = {
        "scenario": scenario.name,
        "locale": locale,
        "engines": {
            "narrator": {
                "name": narrator_engine.name,
                "model": narrator_engine.model,
            },
            "user_voice": {
                "name": user_voice_engine.name,
                "model": user_voice_engine.model,
            },
        },
        "title": scenario.title[locale],
        "dictionary": scenario.dictionary[locale],
        "steps": steps,
    }
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False))
    return manifest
