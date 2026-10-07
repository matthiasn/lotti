"""Tests for the TTS pre-pass: caching, manifest shape, durations."""

from __future__ import annotations

import json
import struct
import sys
import tempfile
import unittest
import wave
from pathlib import Path

TOOL_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL_ROOT))

from tutorial_videos.scenario import load_scenario  # noqa: E402
from tutorial_videos.tts.base import (  # noqa: E402
    TtsError,
    VoiceSpec,
    clip_cache_key,
    load_voices,
    pcm_to_wav,
    render_scenario_clips,
    synthesize_cached,
    wav_duration_seconds,
)

SAMPLE_RATE = 24_000


def _wav(seconds: float) -> bytes:
    pcm = b"\x00\x00" * int(SAMPLE_RATE * seconds)
    header = struct.pack(
        "<4sI4s4sIHHIIHH4sI",
        b"RIFF",
        36 + len(pcm),
        b"WAVE",
        b"fmt ",
        16,
        1,
        1,
        SAMPLE_RATE,
        SAMPLE_RATE * 2,
        2,
        16,
        b"data",
        len(pcm),
    )
    return header + pcm


class FakeEngine:
    """Deterministic engine: 1s of silence per 10 chars; counts calls."""

    name = "fake"
    model = "fake-1"

    def __init__(self) -> None:
        self.calls: list[str] = []
        self.requests: list[dict] = []

    def synthesize(self, *, text: str, voice: str, style: str, settings: dict) -> bytes:
        self.calls.append(text)
        self.requests.append({"voice": voice, "style": style, "settings": settings})
        return _wav(max(0.5, len(text) / 10))


STREAMS = {
    "narrator": VoiceSpec(voice="N", style={"en": "calm:", "de": "ruhig:"}),
    "user_voice": VoiceSpec(voice="U", style={"en": "natural:", "de": "locker:"}),
}


class TtsPrePassTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.addCleanup(self._tmp.cleanup)
        self.scenario = load_scenario(
            TOOL_ROOT / "config" / "scenarios" / "create_task_from_audio.yaml"
        )

    def _render(self, engine: FakeEngine, locale: str = "de") -> dict:
        return render_scenario_clips(
            self.scenario,
            locale,
            engine,
            STREAMS,
            cache_dir=self.tmp / "cache",
            manifest_path=self.tmp / "manifest.json",
        )

    def test_manifest_covers_all_steps_with_real_durations(self):
        engine = FakeEngine()
        manifest = self._render(engine)
        self.assertEqual(manifest["locale"], "de")
        self.assertEqual(
            [s["id"] for s in manifest["steps"]],
            [s.id for s in self.scenario.steps],
        )
        for step in manifest["steps"]:
            clip = Path(step["narration"]["clip"])
            self.assertTrue(clip.exists())
            self.assertAlmostEqual(
                step["narration"]["duration"],
                wav_duration_seconds(clip),
                places=3,
            )
        dictation_steps = [s for s in manifest["steps"] if "dictation" in s]
        self.assertEqual(len(dictation_steps), 1)
        self.assertTrue(Path(dictation_steps[0]["dictation"]["clip"]).exists())
        self.assertEqual(manifest["dictionary"], self.scenario.dictionary["de"])
        # Manifest file round-trips.
        on_disk = json.loads((self.tmp / "manifest.json").read_text())
        self.assertEqual(on_disk, manifest)

    def test_scenario_without_a_dictionary_renders_an_empty_one(self):
        preview = load_scenario(
            TOOL_ROOT / "config" / "scenarios" / "app_store_preview.yaml"
        )
        engine = FakeEngine()
        manifest = render_scenario_clips(
            preview,
            "en",
            engine,
            STREAMS,
            cache_dir=self.tmp / "cache",
            manifest_path=self.tmp / "preview.json",
        )
        self.assertEqual(manifest["dictionary"], [])
        self.assertEqual(
            [s["id"] for s in manifest["steps"]], [s.id for s in preview.steps]
        )
        # Narrator only: nothing is dictated.
        self.assertEqual(len(engine.calls), len(preview.steps))
        self.assertFalse(any("dictation" in s for s in manifest["steps"]))

    def test_cache_prevents_resynthesis_and_distinguishes_inputs(self):
        engine = FakeEngine()
        self._render(engine)
        first_calls = len(engine.calls)
        self.assertEqual(first_calls, len(self.scenario.steps) + 1)  # +dictation

        self._render(engine)  # identical inputs -> all cache hits
        self.assertEqual(len(engine.calls), first_calls)

        self._render(engine, locale="en")  # different locale -> new synthesis
        self.assertEqual(len(engine.calls), 2 * first_calls)

    def test_cached_clip_content_is_reused_not_rewritten(self):
        engine = FakeEngine()
        path = synthesize_cached(
            engine, voice="N", style="s", text="hello", cache_dir=self.tmp
        )
        stamp = path.stat().st_mtime_ns
        again = synthesize_cached(
            engine, voice="N", style="s", text="hello", cache_dir=self.tmp
        )
        self.assertEqual(path, again)
        self.assertEqual(path.stat().st_mtime_ns, stamp)
        self.assertEqual(len(engine.calls), 1)

    def test_voice_settings_reach_the_engine_and_style_can_be_empty(self):
        engine = FakeEngine()
        streams = {
            "narrator": VoiceSpec(voice="N", style={}, settings={"stability": 0.5}),
            "user_voice": VoiceSpec(voice="U", style={}, settings={"speed": 1.1}),
        }
        render_scenario_clips(
            self.scenario,
            "de",
            engine,
            streams,
            cache_dir=self.tmp / "cache",
            manifest_path=self.tmp / "manifest.json",
        )
        self.assertIn(
            {"voice": "N", "style": "", "settings": {"stability": 0.5}},
            engine.requests,
        )
        self.assertIn(
            {"voice": "U", "style": "", "settings": {"speed": 1.1}}, engine.requests
        )

    def test_changed_voice_settings_synthesize_again(self):
        engine = FakeEngine()
        for settings in ({"stability": 0.5}, {"stability": 0.5}, {"stability": 0.6}):
            synthesize_cached(
                engine,
                voice="N",
                style="",
                text="hello",
                settings=settings,
                cache_dir=self.tmp,
            )
        self.assertEqual(len(engine.calls), 2)


class ClipCacheKeyTest(unittest.TestCase):
    def test_a_clip_without_settings_keeps_the_key_it_always_had(self):
        # Recorded before voice settings existed: every Gemini clip already
        # in a cache must stay a hit, never be synthesized (and paid) again.
        self.assertEqual(
            clip_cache_key(
                engine="gemini",
                model="models/gemini-3.1-flash-tts-preview",
                voice="Algieba",
                style="Speak calmly:",
                text="Hello Lotti",
            ),
            "3dcd1c8e5083c67867b87688",
        )

    def test_empty_settings_are_the_same_as_none(self):
        base = dict(engine="e", model="m", voice="v", style="", text="t")
        self.assertEqual(clip_cache_key(**base, settings={}), clip_cache_key(**base))

    def test_settings_change_the_key_whatever_their_order(self):
        base = dict(engine="e", model="m", voice="v", style="", text="t")
        ordered = clip_cache_key(**base, settings={"a": 1, "b": 2})
        self.assertNotEqual(ordered, clip_cache_key(**base))
        self.assertEqual(ordered, clip_cache_key(**base, settings={"b": 2, "a": 1}))
        self.assertNotEqual(ordered, clip_cache_key(**base, settings={"a": 1, "b": 3}))


class VoiceSpecTest(unittest.TestCase):
    def test_style_for_returns_the_locales_instruction(self):
        spec = VoiceSpec(voice="N", style={"en": "calm:", "de": "ruhig:"})
        self.assertEqual(spec.style_for("de"), "ruhig:")

    def test_style_for_is_empty_without_style_instructions(self):
        self.assertEqual(VoiceSpec(voice="N", style={}).style_for("de"), "")

    def test_style_for_a_missing_locale_is_a_config_gap(self):
        with self.assertRaises(KeyError):
            VoiceSpec(voice="N", style={"en": "calm:"}).style_for("de")

    def test_settings_default_to_empty(self):
        self.assertEqual(VoiceSpec(voice="N", style={}).settings, {})


class PcmToWavTest(unittest.TestCase):
    def test_wraps_pcm_as_16_bit_mono_at_the_given_rate(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "clip.wav"
            path.write_bytes(pcm_to_wav(b"\x01\x00" * 16_000, 16_000))
            self.assertEqual(wav_duration_seconds(path), 1.0)
            with wave.open(str(path), "rb") as wav:
                self.assertEqual(
                    (wav.getnchannels(), wav.getsampwidth(), wav.getframerate()),
                    (1, 2, 16_000),
                )
                self.assertEqual(wav.readframes(2), b"\x01\x00\x01\x00")


VOICES_YAML = TOOL_ROOT / "config" / "voices.yaml"


class LoadVoicesTest(unittest.TestCase):
    def test_defaults_to_gemini_with_a_style_per_locale(self):
        engine_name, model, streams = load_voices(VOICES_YAML)
        self.assertEqual(engine_name, "gemini")
        self.assertTrue(model.startswith("models/gemini"))
        for spec in streams.values():
            self.assertIn("en", spec.style)
            self.assertIn("de", spec.style)
            self.assertEqual(spec.settings, {})

    def test_elevenlabs_is_configured_with_voice_settings_not_styles(self):
        engine_name, model, streams = load_voices(VOICES_YAML, engine="elevenlabs")
        self.assertEqual(engine_name, "elevenlabs")
        self.assertEqual(model, "eleven_multilingual_v2")
        for spec in streams.values():
            self.assertEqual(spec.style, {})
            self.assertIn("stability", spec.settings)

    def test_every_engine_gives_the_dictation_its_own_voice(self):
        # Distinct voices (user decision, config/voices.yaml's own doc
        # comment): the narrator audibly "speaks into Lotti" when dictating,
        # so a shared voice would confuse the two streams.
        for engine in ("gemini", "elevenlabs"):
            with self.subTest(engine=engine):
                _name, _model, streams = load_voices(VOICES_YAML, engine=engine)
                self.assertEqual(set(streams), {"narrator", "user_voice"})
                self.assertNotEqual(
                    streams["narrator"].voice, streams["user_voice"].voice
                )

    def test_gemini_styles_differ_between_the_two_voices(self):
        _name, _model, streams = load_voices(VOICES_YAML)
        self.assertNotEqual(
            streams["narrator"].style["en"], streams["user_voice"].style["en"]
        )

    def test_an_unconfigured_engine_names_the_configured_ones(self):
        with self.assertRaises(TtsError) as raised:
            load_voices(VOICES_YAML, engine="polly")
        self.assertIn("polly", str(raised.exception))
        self.assertIn("gemini, elevenlabs", str(raised.exception))


if __name__ == "__main__":
    unittest.main()
