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


class TtsEngine(Protocol):
    """A text-to-speech backend (see ``gemini.py`` for the default)."""

    name: str
    model: str

    def synthesize(self, *, text: str, voice: str, style: str) -> bytes:
        """Return complete WAV bytes for ``text``."""
        ...


@dataclass(frozen=True)
class VoiceSpec:
    voice: str
    style: dict[str, str]  # locale -> style instruction


def load_voices(path: Path) -> tuple[str, str, dict[str, VoiceSpec]]:
    """Load ``voices.yaml`` -> (engine name, model, stream -> VoiceSpec)."""
    import yaml

    raw = yaml.safe_load(path.read_text())
    streams = {
        stream: VoiceSpec(voice=spec["voice"], style=dict(spec.get("style", {})))
        for stream, spec in raw["streams"].items()
    }
    return raw["engine"], raw["model"], streams


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
    engine: TtsEngine,
    streams: dict[str, VoiceSpec],
    cache_dir: Path,
    manifest_path: Path,
) -> dict:
    """Render all clips for (scenario, locale) and write the manifest.

    Manifest shape::

        {
          "scenario": ..., "locale": ..., "engine": ..., "model": ...,
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

    steps = []
    for step in scenario.steps:
        clip = synthesize_cached(
            engine,
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
                engine,
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
        "engine": engine.name,
        "model": engine.model,
        "title": scenario.title[locale],
        "dictionary": scenario.dictionary[locale],
        "steps": steps,
    }
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False))
    return manifest
