"""Tests for the TTS pre-pass: caching, manifest shape, durations."""

from __future__ import annotations

import json
import struct
import sys
import tempfile
import unittest
from pathlib import Path

TOOL_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL_ROOT))

from tutorial_videos.scenario import load_scenario  # noqa: E402
from tutorial_videos.tts.base import (  # noqa: E402
    VoiceSpec,
    load_voices,
    render_scenario_clips,
    synthesize_cached,
    wav_duration_seconds,
)

SAMPLE_RATE = 24_000


def _wav(seconds: float) -> bytes:
    pcm = b"\x00\x00" * int(SAMPLE_RATE * seconds)
    header = struct.pack(
        "<4sI4s4sIHHIIHH4sI",
        b"RIFF", 36 + len(pcm), b"WAVE", b"fmt ", 16, 1, 1,
        SAMPLE_RATE, SAMPLE_RATE * 2, 2, 16, b"data", len(pcm),
    )
    return header + pcm


class FakeEngine:
    """Deterministic engine: 1s of silence per 10 chars; counts calls."""

    name = "fake"
    model = "fake-1"

    def __init__(self) -> None:
        self.calls: list[str] = []

    def synthesize(self, *, text: str, voice: str, style: str) -> bytes:
        self.calls.append(text)
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

    def test_voices_yaml_loads_streams(self):
        engine_name, model, streams = load_voices(
            TOOL_ROOT / "config" / "voices.yaml"
        )
        self.assertEqual(engine_name, "gemini")
        self.assertIn("narrator", streams)
        self.assertIn("user_voice", streams)
        # Distinct voices (user decision, config/voices.yaml's own doc
        # comment): the narrator audibly "speaks into Lotti" when dictating,
        # so a shared voice would confuse the two streams.
        self.assertNotEqual(
            streams["narrator"].voice, streams["user_voice"].voice
        )
        self.assertNotEqual(
            streams["narrator"].style["en"], streams["user_voice"].style["en"]
        )
        for spec in streams.values():
            self.assertIn("en", spec.style)
            self.assertIn("de", spec.style)


if __name__ == "__main__":
    unittest.main()
