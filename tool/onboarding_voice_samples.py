"""Renders the voice samples onboarding plays, one WAV per voice.

The companion's onboarding lets a new user hear the voices she can have before
choosing one: the on-device Supertonic voice, Mistral's Voxtral and
ElevenLabs. Each is the same sentence (`SAMPLE_TEXT`, mirrored by
`onboardingVoiceSampleText` in Dart), bundled as 16-bit PCM WAV so her mouth
follows the clip exactly, as it does synthesized speech.

Run from the repository root:

    pip install supertonic                       # for the on-device voice
    MISTRAL_API_KEY=... ELEVENLABS_API_KEY=... \\
      python3 tool/onboarding_voice_samples.py

`--only on_device` (or `voxtral`, `elevenlabs`, comma separated) renders a
subset; a cloud voice needs only its own key. Keys are read from the
environment and never written anywhere.
"""

from __future__ import annotations

import argparse
import base64
import io
import json
import os
import struct
import sys
import urllib.request
import wave
from pathlib import Path

SAMPLE_TEXT = "Hi, I'm Lotti. This is how I sound when I read your summaries aloud."

OUT_DIR = Path("assets/onboarding/voice_samples")

# The on-device voice exactly as the app runs it: Supertonic 3 at the app's
# pinned revision (`kSupertonic3Revision`) and its default voice
# (`kDefaultTtsVoiceId`).
SUPERTONIC_REVISION = "3cadd1ee6394adea1bd021217a0e650ede09a323"
SUPERTONIC_VOICE = "F1"

MISTRAL_BASE = "https://api.mistral.ai/v1"
VOXTRAL_MODEL = "voxtral-mini-tts-3-0"
ELEVENLABS_BASE = "https://api.elevenlabs.io/v1"
ELEVENLABS_MODEL = "eleven_multilingual_v2"

VOICES = ("on_device", "voxtral", "elevenlabs")


def request_json(url, *, headers, body=None):
    """Sends a JSON request (POST when [body] is given) and decodes the answer."""
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(
        url,
        data=data,
        headers={**headers, **({"Content-Type": "application/json"} if data else {})},
    )
    with urllib.request.urlopen(req, timeout=60) as response:
        return json.loads(response.read().decode())


def request_bytes(url, *, headers, body):
    """POSTs a JSON body and returns the raw answer."""
    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode(),
        headers={**headers, "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=60) as response:
        return response.read()


def first_female_english(voices, *, gender, languages):
    """The first voice in [voices] that is female and speaks English, else the
    first English one, else the first — the app's own default rule."""
    english = [v for v in voices if "en" in languages(v)]
    female = [v for v in english if (gender(v) or "").lower() == "female"]
    for pool in (female, english, voices):
        if pool:
            return pool[0]
    raise SystemExit("The voice catalog is empty.")


def voxtral_voice(key):
    """Voxtral's default English voice, chosen as the app chooses it."""
    page = request_json(
        f"{MISTRAL_BASE}/audio/voices?limit=100",
        headers={"Authorization": f"Bearer {key}"},
    )
    voice = first_female_english(
        page.get("items", []),
        gender=lambda v: v.get("gender"),
        languages=lambda v: v.get("languages") or [],
    )
    return voice["id"]


def render_voxtral(key):
    answer = request_json(
        f"{MISTRAL_BASE}/audio/speech",
        headers={"Authorization": f"Bearer {key}"},
        body={
            "model": VOXTRAL_MODEL,
            "input": SAMPLE_TEXT,
            "voice_id": voxtral_voice(key),
            "response_format": "wav",
        },
    )
    return base64.b64decode(answer["audio_data"])


def elevenlabs_voice(key):
    """ElevenLabs' default English voice, chosen as the app chooses it."""
    voices = request_json(
        f"{ELEVENLABS_BASE}/voices", headers={"xi-api-key": key}
    ).get("voices", [])
    voice = first_female_english(
        voices,
        gender=lambda v: (v.get("labels") or {}).get("gender"),
        # Premade voices speak every language of the multilingual model.
        languages=lambda v: ["en"],
    )
    return voice["voice_id"]


def render_elevenlabs(key):
    return request_bytes(
        f"{ELEVENLABS_BASE}/text-to-speech/{elevenlabs_voice(key)}"
        "?output_format=wav_24000",
        headers={"xi-api-key": key, "Accept": "audio/wav"},
        body={"text": SAMPLE_TEXT, "model_id": ELEVENLABS_MODEL},
    )


def render_on_device():
    # Read by the package at import time: the app's revision, not the
    # package's own pin.
    os.environ["SUPERTONIC_MODEL_REVISION"] = SUPERTONIC_REVISION
    try:
        from supertonic import TTS
    except ImportError as error:
        raise SystemExit("The on-device voice needs `pip install supertonic`.") from error
    tts = TTS()
    audio, _ = tts.synthesize(
        SAMPLE_TEXT, voice_style=tts.get_voice_style(SUPERTONIC_VOICE), lang="en"
    )
    return pcm16_wav(pcm16_frames(audio.flatten()), tts.sample_rate)


def pcm16_frames(samples):
    """Float [samples] in -1..1, clamped, as little-endian 16-bit frames."""
    values = [round(max(-1.0, min(1.0, float(x))) * 32767) for x in samples]
    return struct.pack(f"<{len(values)}h", *values)


def pcm16_wav(frames, rate):
    """Mono 16-bit PCM [frames] at [rate], as WAV bytes."""
    out = io.BytesIO()
    with wave.open(out, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(rate)
        wav.writeframes(frames)
    return out.getvalue()


def check_pcm16(name, data):
    """Fails unless [data] is 16-bit PCM WAV, the only format her lip-sync
    reads exactly; returns its length in seconds."""
    try:
        with wave.open(io.BytesIO(data)) as wav:
            if wav.getsampwidth() != 2:
                raise SystemExit(f"{name}: {8 * wav.getsampwidth()}-bit, not 16-bit PCM.")
            return wav.getnframes() / wav.getframerate()
    except (wave.Error, EOFError) as error:
        raise SystemExit(f"{name}: not a PCM WAV ({error}).") from error


def selected(only):
    """The voices `--only` names, in their canonical order."""
    if not only:
        return list(VOICES)
    names = [n.strip() for n in only.split(",") if n.strip()]
    unknown = [n for n in names if n not in VOICES]
    if unknown:
        raise SystemExit(f"Unknown voice(s): {', '.join(unknown)}.")
    return [v for v in VOICES if v in names]


def key_for(voice, env):
    """The API key [voice] needs from [env], or None for the on-device one."""
    name = {"voxtral": "MISTRAL_API_KEY", "elevenlabs": "ELEVENLABS_API_KEY"}.get(voice)
    if name is None:
        return None
    key = (env.get(name) or "").strip()
    if not key:
        raise SystemExit(f"{voice} needs {name} in the environment.")
    return key


def main(argv=None, env=None):
    env = os.environ if env is None else env
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--only", help="comma-separated subset of " + ", ".join(VOICES))
    args = parser.parse_args(argv)
    voices = selected(args.only)
    keys = {v: key_for(v, env) for v in voices}
    render = {
        "on_device": lambda _: render_on_device(),
        "voxtral": render_voxtral,
        "elevenlabs": render_elevenlabs,
    }
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for voice in voices:
        data = render[voice](keys[voice])
        seconds = check_pcm16(voice, data)
        (OUT_DIR / f"{voice}.wav").write_bytes(data)
        print(f"{voice}: {seconds:.1f} s, {len(data) // 1024} KiB")
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
