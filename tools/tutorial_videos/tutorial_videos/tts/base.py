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
import struct
import wave
from dataclasses import dataclass, field
from pathlib import Path
from typing import Protocol

from ..scenario import Scenario


class TtsError(Exception):
    """A TTS engine is misconfigured or its API refused a request."""


class TtsEngine(Protocol):
    """A text-to-speech backend (``gemini.py``, ``elevenlabs.py``).

    An engine uses whichever of ``style`` and ``settings`` it understands:
    Gemini takes a per-locale style instruction, ElevenLabs per-voice
    settings. ``voices.yaml`` only configures the one each engine reads."""

    name: str
    model: str

    def synthesize(
        self, *, text: str, voice: str, style: str, settings: dict
    ) -> bytes:
        """Return complete WAV bytes for ``text``."""
        ...


@dataclass(frozen=True)
class VoiceSpec:
    voice: str
    style: dict[str, str]  # locale -> style instruction
    settings: dict = field(default_factory=dict)  # engine-specific voice settings

    def style_for(self, locale: str) -> str:
        """The style instruction for ``locale``.

        Empty for an engine configured without style instructions (the
        voice and its settings carry the delivery); a locale missing from a
        configured style map is a config gap and raises ``KeyError``."""
        if not self.style:
            return ""
        return self.style[locale]


def load_voices(
    path: Path, engine: str | None = None
) -> tuple[str, str, dict[str, VoiceSpec]]:
    """Load ``voices.yaml`` -> (engine name, model, stream -> VoiceSpec).

    ``engine`` picks one of the configured engines; ``None`` takes the
    file's default ``engine:``."""
    import yaml

    raw = yaml.safe_load(path.read_text())
    name = engine or raw["engine"]
    if name not in raw["engines"]:
        raise TtsError(
            f"no voices configured for TTS engine {name!r} in {path} "
            f"(configured: {', '.join(raw['engines'])})"
        )
    config = raw["engines"][name]
    streams = {
        stream: VoiceSpec(
            voice=spec["voice"],
            style=dict(spec.get("style", {})),
            settings=dict(spec.get("settings", {})),
        )
        for stream, spec in config["streams"].items()
    }
    return name, config["model"], streams


def pcm_to_wav(pcm: bytes, sample_rate: int) -> bytes:
    """Wraps 16-bit mono little-endian PCM — what both engines return — in
    a WAV container."""
    header = struct.pack(
        "<4sI4s4sIHHIIHH4sI",
        b"RIFF", 36 + len(pcm), b"WAVE", b"fmt ", 16, 1, 1,
        sample_rate, sample_rate * 2, 2, 16, b"data", len(pcm),
    )
    return header + pcm


def wav_duration_seconds(path: Path) -> float:
    with wave.open(str(path), "rb") as wav:
        return wav.getnframes() / wav.getframerate()


def clip_cache_key(
    *,
    engine: str,
    model: str,
    voice: str,
    style: str,
    text: str,
    settings: dict | None = None,
) -> str:
    parts = [engine, model, voice, style, text]
    # Only voices with settings add them, so every clip cached before
    # settings existed keeps its key and is never synthesized again.
    if settings:
        parts.append(json.dumps(settings, sort_keys=True))
    payload = "\x1f".join(parts)
    return hashlib.sha256(payload.encode()).hexdigest()[:24]


def synthesize_cached(
    engine: TtsEngine,
    *,
    voice: str,
    style: str,
    text: str,
    cache_dir: Path,
    settings: dict | None = None,
) -> Path:
    """Return the cached WAV for this exact (engine, voice, style, settings,
    text), synthesizing only on cache miss — repeat builds never re-hit the
    API."""
    settings = settings or {}
    cache_dir.mkdir(parents=True, exist_ok=True)
    key = clip_cache_key(
        engine=engine.name,
        model=engine.model,
        voice=voice,
        style=style,
        text=text,
        settings=settings,
    )
    path = cache_dir / f"{key}.wav"
    if not path.exists():
        path.write_bytes(
            engine.synthesize(text=text, voice=voice, style=style, settings=settings)
        )
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
            style=narrator.style_for(locale),
            settings=narrator.settings,
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
                style=user_voice.style_for(locale),
                settings=user_voice.settings,
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
        # Empty for a scenario without one (see scenario.py); the tutorial
        # harness seeds whatever is here into the category.
        "dictionary": scenario.dictionary.get(locale, []),
        "steps": steps,
    }
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False))
    return manifest
