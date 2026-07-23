#!/usr/bin/env python3
"""Smoke test: ElevenLabs TTS synthesis for a few candidate narrator voices.

Synthesizes the same narrator sample line with each candidate voice ID so
they can be compared by ear against the current Gemini narrator voice
(Algieba). Writes WAVs and prints their durations.

Usage: smoke_tts_elevenlabs.py [OUT_DIR]   (default: build/tutorial_videos/smoke)
"""

from __future__ import annotations

import sys
from pathlib import Path

TOOL_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = TOOL_ROOT.parents[1]
sys.path.insert(0, str(TOOL_ROOT))

from tutorial_videos.tts.base import read_env_key, wav_duration_seconds  # noqa: E402
from tutorial_videos.tts.elevenlabs import ElevenLabsTts  # noqa: E402

MODEL = "eleven_multilingual_v2"

NARRATOR_SAMPLE_EN = (
    "Let's create a new task by simply speaking. Tap the record button and "
    "describe what needs to be done."
)
NARRATOR_SAMPLE_DE = (
    "Lass uns eine neue Aufgabe erstellen, indem wir einfach sprechen. "
    "Tippe auf die Aufnahmetaste und beschreibe, was zu tun ist."
)

# Candidate narrator voice IDs to compare — add more as candidates surface.
CANDIDATES = {
    "christian": "NBqeXKdZHweef6y0B67V",
    "oliver_wagner": "z2xcDipUaaASfVjjn71T",
}


def main() -> None:
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(
        "build/tutorial_videos/smoke"
    )
    out_dir.mkdir(parents=True, exist_ok=True)
    api_key = read_env_key(REPO_ROOT / ".env", "ELEVEN_LABS_API_KEY")
    engine = ElevenLabsTts(api_key, MODEL)

    for label, voice_id in CANDIDATES.items():
        for locale, text in (("en", NARRATOR_SAMPLE_EN), ("de", NARRATOR_SAMPLE_DE)):
            wav_bytes = engine.synthesize(text=text, voice=voice_id, style="")
            path = out_dir / f"tts_elevenlabs_{label}_{locale}.wav"
            path.write_bytes(wav_bytes)
            duration = wav_duration_seconds(path)
            print(
                f"PASS: {label} ({voice_id}) / {locale} "
                f"{duration:.1f}s -> {path}"
            )


if __name__ == "__main__":
    main()
