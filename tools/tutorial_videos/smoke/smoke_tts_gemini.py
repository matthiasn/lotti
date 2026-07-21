#!/usr/bin/env python3
"""Phase-0 smoke: Gemini TTS synthesis for both workbench streams.

Synthesizes the two distinct TTS streams the tutorial-video workbench needs —
`narrator` (off-screen voice-over) and `user_voice` (dictation played into the
virtual microphone) — in English and German, using different prebuilt voices
and style instructions per stream. Writes WAVs and prints their durations.

Dependency-free (urllib only). Reads GEMINI_API_KEY from the repo .env.

Usage: smoke_tts_gemini.py [OUT_DIR]   (default: build/tutorial_videos/smoke)
"""

from __future__ import annotations

import base64
import json
import struct
import sys
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
MODEL = "models/gemini-3.1-flash-tts-preview"
SAMPLE_RATE = 24_000  # Gemini TTS returns 24 kHz mono s16le PCM

SAMPLES = {
    ("narrator", "en"): (
        "Kore",
        "Speak as a calm, friendly tutorial narrator:",
        "Let's create a new task by simply speaking. "
        "Tap the record button and describe what needs to be done.",
    ),
    ("narrator", "de"): (
        "Kore",
        "Sprich als ruhige, freundliche Tutorial-Erzählerin:",
        "Lass uns eine neue Aufgabe erstellen, indem wir einfach sprechen. "
        "Tippe auf die Aufnahmetaste und beschreibe, was zu tun ist.",
    ),
    ("user_voice", "en"): (
        "Puck",
        "Speak naturally, as someone dictating a note to their phone:",
        "Schedule the emperor penguin roll call for Project Waddle, "
        "and double-check the sardine futures paperwork.",
    ),
    ("user_voice", "de"): (
        "Puck",
        "Sprich natürlich, wie jemand, der seinem Telefon eine Notiz diktiert:",
        "Plane den Appell der Kaiserpinguine für Projekt Waddle "
        "und prüfe die Unterlagen für die Sardinen-Termingeschäfte.",
    ),
}


def read_env_key(name: str) -> str:
    for line in (REPO_ROOT / ".env").read_text().splitlines():
        if line.startswith(f"{name}="):
            return line.split("=", 1)[1].strip()
    raise SystemExit(f"{name} not found in {REPO_ROOT / '.env'}")


def synthesize(api_key: str, voice: str, style: str, text: str) -> bytes:
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
        f"https://generativelanguage.googleapis.com/v1beta/{MODEL}:generateContent",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "x-goog-api-key": api_key},
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        payload = json.load(resp)
    part = payload["candidates"][0]["content"]["parts"][0]
    return base64.b64decode(part["inlineData"]["data"])


def write_wav(path: Path, pcm: bytes) -> float:
    """Wrap raw s16le mono PCM in a WAV header; return duration in seconds."""
    header = struct.pack(
        "<4sI4s4sIHHIIHH4sI",
        b"RIFF", 36 + len(pcm), b"WAVE", b"fmt ", 16, 1, 1,
        SAMPLE_RATE, SAMPLE_RATE * 2, 2, 16, b"data", len(pcm),
    )
    path.write_bytes(header + pcm)
    return len(pcm) / 2 / SAMPLE_RATE


def main() -> None:
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(
        "build/tutorial_videos/smoke"
    )
    out_dir.mkdir(parents=True, exist_ok=True)
    api_key = read_env_key("GEMINI_API_KEY")

    for (stream, locale), (voice, style, text) in SAMPLES.items():
        pcm = synthesize(api_key, voice, style, text)
        path = out_dir / f"tts_{stream}_{locale}.wav"
        duration = write_wav(path, pcm)
        print(f"PASS: {stream}/{locale} voice={voice} {duration:.1f}s -> {path}")


if __name__ == "__main__":
    main()
