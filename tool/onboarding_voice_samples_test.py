"""Deterministic checks for the onboarding voice-sample generator; no network,
no keys, no model."""

import base64
import contextlib
import io
import json
import os
import re
import struct
import sys
import tempfile
import types
import unittest
import wave
from pathlib import Path
from unittest.mock import MagicMock, patch

from tool import onboarding_voice_samples as gen

REPO = Path(__file__).resolve().parent.parent


def wav(rate=24000, width=2, frames=b"\x00\x00" * 2400):
    out = io.BytesIO()
    with wave.open(out, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(width)
        w.setframerate(rate)
        w.writeframes(frames)
    return out.getvalue()


def response(body):
    r = MagicMock()
    r.read.return_value = body
    r.__enter__.return_value = r
    return r


class SampleTextTest(unittest.TestCase):
    def test_the_sentence_is_the_one_the_app_lip_syncs_to(self):
        dart = (
            REPO / "lib/features/onboarding/ui/widgets/onboarding_voices_step.dart"
        ).read_text()
        match = re.search(r"onboardingVoiceSampleText =\s*\"([^\"]+)\"", dart)
        self.assertIsNotNone(match)
        self.assertEqual(match.group(1), gen.SAMPLE_TEXT)

    def test_the_on_device_voice_is_the_apps(self):
        dart = (REPO / "lib/features/tts/model/tts_model_option.dart").read_text()
        self.assertIn(f"'{gen.SUPERTONIC_REVISION}'", dart)
        voice = (REPO / "lib/features/tts/model/tts_voice.dart").read_text()
        self.assertIn(f"kDefaultTtsVoiceId = '{gen.SUPERTONIC_VOICE}'", voice)


class VoicePickTest(unittest.TestCase):
    def pick(self, voices):
        return gen.first_female_english(
            voices, gender=lambda v: v.get("g"), languages=lambda v: v.get("l", [])
        )

    def test_prefers_a_female_english_voice(self):
        voices = [
            {"id": 1, "g": "male", "l": ["en"]},
            {"id": 2, "g": "Female", "l": ["fr"]},
            {"id": 3, "g": "female", "l": ["en"]},
        ]
        self.assertEqual(self.pick(voices)["id"], 3)

    def test_falls_back_to_any_english_then_any_voice(self):
        self.assertEqual(
            self.pick([{"id": 1, "l": ["fr"]}, {"id": 2, "l": ["en"]}])["id"], 2
        )
        self.assertEqual(self.pick([{"id": 1, "l": ["fr"]}])["id"], 1)

    def test_an_empty_catalog_stops(self):
        with self.assertRaises(SystemExit):
            self.pick([])


class SelectionAndKeysTest(unittest.TestCase):
    def test_no_subset_means_every_voice(self):
        self.assertEqual(gen.selected(None), list(gen.VOICES))

    def test_a_subset_keeps_the_canonical_order(self):
        self.assertEqual(
            gen.selected("elevenlabs, on_device"), ["on_device", "elevenlabs"]
        )

    def test_an_unknown_voice_stops(self):
        with self.assertRaises(SystemExit):
            gen.selected("on_device,robot")

    def test_keys_come_from_the_environment(self):
        self.assertIsNone(gen.key_for("on_device", {}))
        self.assertEqual(gen.key_for("voxtral", {"MISTRAL_API_KEY": " m "}), "m")
        self.assertEqual(
            gen.key_for("elevenlabs", {"ELEVENLABS_API_KEY": "e"}), "e"
        )
        with self.assertRaises(SystemExit):
            gen.key_for("voxtral", {"MISTRAL_API_KEY": "  "})


class WavTest(unittest.TestCase):
    def test_pcm16_frames_clamp_and_scale(self):
        frames = gen.pcm16_frames([0.0, 1.0, -1.0, 2.0, -2.0, 0.5])
        self.assertEqual(
            struct.unpack("<6h", frames), (0, 32767, -32767, 32767, -32767, 16384)
        )

    def test_pcm16_wav_is_mono_16_bit_at_the_rate(self):
        data = gen.pcm16_wav(b"\x01\x00\x02\x00", 44100)
        with wave.open(io.BytesIO(data)) as w:
            self.assertEqual(
                (w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()),
                (1, 2, 44100, 2),
            )

    def test_check_pcm16_measures_a_good_clip(self):
        self.assertAlmostEqual(gen.check_pcm16("x", wav()), 0.1)

    def test_check_pcm16_rejects_other_widths_and_non_wav(self):
        with self.assertRaises(SystemExit):
            gen.check_pcm16("x", wav(width=1, frames=b"\x00" * 10))
        with self.assertRaises(SystemExit):
            gen.check_pcm16("x", b"not a wav")


class HttpTest(unittest.TestCase):
    def test_request_json_posts_json_and_decodes(self):
        with patch.object(
            gen.urllib.request, "urlopen", return_value=response(b'{"a": 1}')
        ) as urlopen:
            self.assertEqual(
                gen.request_json("https://x/y", headers={"K": "v"}, body={"b": 2}),
                {"a": 1},
            )
        req = urlopen.call_args.args[0]
        self.assertEqual(req.get_method(), "POST")
        self.assertEqual(json.loads(req.data), {"b": 2})
        self.assertEqual(req.get_header("Content-type"), "application/json")
        self.assertEqual(req.get_header("K"), "v")

    def test_request_json_without_a_body_is_a_get(self):
        with patch.object(
            gen.urllib.request, "urlopen", return_value=response(b"{}")
        ) as urlopen:
            gen.request_json("https://x/y", headers={})
        req = urlopen.call_args.args[0]
        self.assertEqual(req.get_method(), "GET")
        self.assertIsNone(req.get_header("Content-type"))

    def test_request_bytes_returns_the_raw_answer(self):
        with patch.object(
            gen.urllib.request, "urlopen", return_value=response(b"RIFF")
        ) as urlopen:
            self.assertEqual(
                gen.request_bytes("https://x", headers={}, body={"t": 1}), b"RIFF"
            )
        self.assertEqual(json.loads(urlopen.call_args.args[0].data), {"t": 1})


class CloudVoicesTest(unittest.TestCase):
    def test_voxtral_speaks_the_sentence_with_its_default_voice(self):
        calls = []

        def fake(url, *, headers, body=None):
            calls.append((url, headers, body))
            if url.endswith("/audio/voices?limit=100"):
                return {"items": [{"id": "v-f", "gender": "female", "languages": ["en"]}]}
            return {"audio_data": base64.b64encode(b"WAV").decode()}

        with patch.object(gen, "request_json", side_effect=fake):
            self.assertEqual(gen.render_voxtral("k"), b"WAV")
        url, headers, body = calls[-1]
        self.assertEqual(url, "https://api.mistral.ai/v1/audio/speech")
        self.assertEqual(headers, {"Authorization": "Bearer k"})
        self.assertEqual(
            body,
            {
                "model": "voxtral-mini-tts-3-0",
                "input": gen.SAMPLE_TEXT,
                "voice_id": "v-f",
                "response_format": "wav",
            },
        )

    def test_voxtral_with_no_items_stops(self):
        with patch.object(gen, "request_json", return_value={}):
            with self.assertRaises(SystemExit):
                gen.voxtral_voice("k")

    def test_elevenlabs_speaks_the_sentence_as_24k_wav(self):
        voices = {
            "voices": [
                {"voice_id": "m", "labels": {"gender": "male"}},
                {"voice_id": "f", "labels": {"gender": "female"}},
                {"voice_id": "n"},
            ]
        }
        with (
            patch.object(gen, "request_json", return_value=voices) as listing,
            patch.object(gen, "request_bytes", return_value=b"WAV") as speech,
        ):
            self.assertEqual(gen.render_elevenlabs("k"), b"WAV")
        self.assertEqual(
            listing.call_args.args[0], "https://api.elevenlabs.io/v1/voices"
        )
        self.assertEqual(listing.call_args.kwargs["headers"], {"xi-api-key": "k"})
        self.assertEqual(
            speech.call_args.args[0],
            "https://api.elevenlabs.io/v1/text-to-speech/f?output_format=wav_24000",
        )
        self.assertEqual(
            speech.call_args.kwargs["body"],
            {"text": gen.SAMPLE_TEXT, "model_id": "eleven_multilingual_v2"},
        )


class FakeAudio(list):
    def flatten(self):
        return self


class OnDeviceTest(unittest.TestCase):
    def test_renders_the_apps_voice_at_the_apps_revision(self):
        seen = {}

        class FakeTTS:
            sample_rate = 44100

            def __init__(self):
                seen["revision"] = os.environ.get("SUPERTONIC_MODEL_REVISION")

            def get_voice_style(self, name):
                seen["voice"] = name
                return "style"

            def synthesize(self, text, voice_style, lang):
                seen["call"] = (text, voice_style, lang)
                return FakeAudio([0.0, 0.5]), 0.0

        module = types.ModuleType("supertonic")
        module.TTS = FakeTTS
        with (
            patch.dict(sys.modules, {"supertonic": module}),
            patch.dict(os.environ, {}, clear=False),
        ):
            data = gen.render_on_device()
        self.assertEqual(seen["revision"], gen.SUPERTONIC_REVISION)
        self.assertEqual(seen["voice"], "F1")
        self.assertEqual(seen["call"], (gen.SAMPLE_TEXT, "style", "en"))
        with wave.open(io.BytesIO(data)) as w:
            self.assertEqual(w.getframerate(), 44100)
            self.assertEqual(struct.unpack("<2h", w.readframes(2)), (0, 16384))

    def test_without_the_package_it_says_how_to_get_it(self):
        with (
            patch.dict(sys.modules, {"supertonic": None}),
            patch.dict(os.environ, {}, clear=False),
        ):
            with self.assertRaises(SystemExit) as stop:
                gen.render_on_device()
        self.assertIn("pip install supertonic", str(stop.exception))


class MainTest(unittest.TestCase):
    def test_writes_each_selected_voice_and_reports_it(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "voice_samples"
            stdout = io.StringIO()
            with (
                patch.object(gen, "OUT_DIR", out),
                patch.object(gen, "render_on_device", return_value=wav()),
                patch.object(gen, "render_voxtral", return_value=wav()) as voxtral,
                patch.object(gen, "render_elevenlabs") as elevenlabs,
                contextlib.redirect_stdout(stdout),
            ):
                code = gen.main(
                    ["--only", "on_device,voxtral"], env={"MISTRAL_API_KEY": "m"}
                )
            self.assertEqual(code, 0)
            self.assertEqual(
                sorted(p.name for p in out.iterdir()), ["on_device.wav", "voxtral.wav"]
            )
            voxtral.assert_called_once_with("m")
            elevenlabs.assert_not_called()
            self.assertIn("on_device: 0.1 s", stdout.getvalue())

    def test_a_missing_key_stops_before_anything_is_rendered(self):
        with (
            patch.object(gen, "render_on_device") as on_device,
            patch.object(gen.Path, "mkdir") as mkdir,
        ):
            with self.assertRaises(SystemExit):
                gen.main([], env={})
        on_device.assert_not_called()
        mkdir.assert_not_called()

    def test_reads_the_process_environment_by_default(self):
        with (
            patch.dict(os.environ, {"ELEVENLABS_API_KEY": "e"}),
            patch.object(gen, "render_elevenlabs", return_value=b"bad"),
            patch.object(gen.Path, "mkdir"),
        ):
            with self.assertRaises(SystemExit) as stop:
                gen.main(["--only", "elevenlabs"])
        self.assertIn("not a PCM WAV", str(stop.exception))


if __name__ == "__main__":
    unittest.main()
