#!/usr/bin/env python3
"""Phase-0 smoke: TTS -> Voxtral-on-Melious chat-endpoint round-trip.

Validates the workbench's full speech loop before any app involvement: the
Gemini-TTS "user dictation" clip (see smoke_tts_gemini.py) is encoded to MP3
and sent to Melious' /chat/completions with an OpenAI-style `input_audio`
content part — the exact payload shape Lotti's
`MeliousInferenceRepository.transcribeChatAudio` produces (see
temporary_mp3_chat_audio_transcriber.dart) — including speech-dictionary
terms merged into the prompt. Asserts the transcript contains the quirky
penguin vocabulary.

Dependency-free (urllib + ffmpeg). Reads MELIOUS_API_KEY / MELIOUS_BASE_URL
from the repo .env.

Usage: smoke_voxtral_roundtrip.py [OUT_DIR]  (default: build/tutorial_videos/smoke)
"""

from __future__ import annotations

import base64
import json
import subprocess
import sys
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
MODEL = "voxtral-small-24b-2507"

# Finding from the first run: with an English prompt, Voxtral TRANSLATES
# German audio into English instead of transcribing it. The prompt must be in
# the audio's language (and explicitly demand source-language transcription) —
# this carries over to the transcription-skill prompt seeded in Phase 2.
CASES = {
    "en": {
        "wav": "tts_user_voice_en.wav",
        "prompt": (
            "Transcribe this audio recording verbatim, in the language spoken. "
            "Return only the transcript. The speaker may use these terms: "
            "Project Waddle, sardine futures, emperor penguin."
        ),
        "expect": ["waddle", "sardine", "penguin"],
    },
    "de": {
        "wav": "tts_user_voice_de.wav",
        "prompt": (
            "Transkribiere diese Audioaufnahme wortwörtlich auf Deutsch, in der "
            "gesprochenen Sprache — nicht übersetzen. Gib nur das Transkript "
            "zurück. Mögliche Begriffe: Projekt Waddle, "
            "Sardinen-Termingeschäfte, Kaiserpinguine."
        ),
        "expect": ["waddle", "sardinen", "pinguin"],
    },
}


def read_env(name: str) -> str:
    for line in (REPO_ROOT / ".env").read_text().splitlines():
        if line.startswith(f"{name}="):
            return line.split("=", 1)[1].strip()
    raise SystemExit(f"{name} not found in {REPO_ROOT / '.env'}")


def wav_to_mp3_base64(wav: Path) -> str:
    mp3 = wav.with_suffix(".mp3")
    subprocess.run(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
         "-i", str(wav), "-codec:a", "libmp3lame", "-qscale:a", "4", str(mp3)],
        check=True,
    )
    return base64.b64encode(mp3.read_bytes()).decode()


def transcribe(base_url: str, api_key: str, mp3_b64: str, prompt: str) -> str:
    body = {
        "model": MODEL,
        "request_id": "melious-audio-smoke",
        "messages": [{
            "role": "user",
            "content": [
                {"type": "input_audio",
                 "input_audio": {"data": mp3_b64, "format": "mp3"}},
                {"type": "text", "text": prompt},
            ],
        }],
        "stream": False,
        "temperature": 0.0,
    }
    req = urllib.request.Request(
        f"{base_url.rstrip('/')}/chat/completions",
        data=json.dumps(body).encode(),
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
    )
    with urllib.request.urlopen(req, timeout=300) as resp:
        payload = json.load(resp)
    return payload["choices"][0]["message"]["content"]


def main() -> None:
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(
        "build/tutorial_videos/smoke"
    )
    api_key = read_env("MELIOUS_API_KEY")
    base_url = read_env("MELIOUS_BASE_URL")

    failures = []
    for locale, case in CASES.items():
        wav = out_dir / case["wav"]
        if not wav.exists():
            raise SystemExit(f"{wav} missing — run smoke_tts_gemini.py first")
        transcript = transcribe(
            base_url, api_key, wav_to_mp3_base64(wav), case["prompt"]
        )
        (out_dir / f"transcript_{locale}.txt").write_text(transcript)
        lowered = transcript.lower()
        missing = [term for term in case["expect"] if term not in lowered]
        status = "PASS" if not missing else f"FAIL (missing: {missing})"
        print(f"{status}: {locale} transcript: {transcript.strip()}")
        if missing:
            failures.append(locale)

    if failures:
        sys.exit(1)


if __name__ == "__main__":
    main()
