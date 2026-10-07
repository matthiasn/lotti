"""Tests for the ElevenLabs TTS adapter (no network: urlopen is patched)."""

from __future__ import annotations

import json
import unittest

from tts_helpers import fail_with, respond_with, wav_info

from tutorial_videos.tts.base import TtsError
from tutorial_videos.tts.elevenlabs import ElevenLabsTts

PCM = b"\x10\x00\x20\x00" * 120  # 240 samples


def _synthesize(**overrides) -> bytes:
    request = dict(text="Hallo Lotti", voice="voice-1", style="", settings={})
    request.update(overrides)
    return ElevenLabsTts("secret-key", "eleven_multilingual_v2").synthesize(**request)


class RequestTest(unittest.TestCase):
    def _sent(self, **overrides):
        with respond_with(PCM) as urlopen:
            _synthesize(**overrides)
        (request,), kwargs = urlopen.call_args
        return request, kwargs

    def test_posts_to_the_voice_asking_for_24khz_pcm(self):
        request, kwargs = self._sent()
        self.assertEqual(request.get_method(), "POST")
        self.assertEqual(
            request.full_url,
            "https://api.elevenlabs.io/v1/text-to-speech/voice-1"
            "?output_format=pcm_24000",
        )
        self.assertEqual(kwargs["timeout"], 120)

    def test_authenticates_with_the_api_key_header(self):
        request, _ = self._sent()
        self.assertEqual(request.get_header("Xi-api-key"), "secret-key")
        self.assertEqual(request.get_header("Content-type"), "application/json")

    def test_sends_the_text_as_is_with_the_model(self):
        request, _ = self._sent(style="Speak calmly:")
        # No instruction prompt: a style must never be read out as text.
        self.assertEqual(
            json.loads(request.data),
            {"text": "Hallo Lotti", "model_id": "eleven_multilingual_v2"},
        )

    def test_sends_voice_settings_when_configured(self):
        request, _ = self._sent(settings={"stability": 0.4, "speed": 1.1})
        self.assertEqual(
            json.loads(request.data)["voice_settings"],
            {"stability": 0.4, "speed": 1.1},
        )

    def test_escapes_the_voice_id_in_the_path(self):
        request, _ = self._sent(voice="a/b c")
        self.assertIn("/text-to-speech/a%2Fb%20c?", request.full_url)


class ResponseTest(unittest.TestCase):
    def test_wraps_the_pcm_as_a_24khz_mono_16_bit_wav(self):
        with respond_with(PCM):
            self.assertEqual(wav_info(_synthesize()), (1, 2, 24_000, PCM))

    def test_no_audio_is_an_error(self):
        with respond_with(b""), self.assertRaises(TtsError) as raised:
            _synthesize()
        self.assertIn("voice-1", str(raised.exception))

    def test_an_http_error_names_the_status_and_the_apis_reason(self):
        detail = b'{"detail":{"status":"voice_not_found"}}'
        with fail_with(404, detail), self.assertRaises(TtsError) as raised:
            _synthesize()
        message = str(raised.exception)
        self.assertIn("HTTP 404", message)
        self.assertIn("voice_not_found", message)
        self.assertIn("voice-1", message)

    def test_an_http_error_never_reveals_the_api_key(self):
        with fail_with(401, b"invalid api key"), self.assertRaises(TtsError) as raised:
            _synthesize()
        self.assertNotIn("secret-key", str(raised.exception))

    def test_a_long_error_page_is_cut_short(self):
        with fail_with(500, b"x" * 5000), self.assertRaises(TtsError) as raised:
            _synthesize()
        self.assertEqual(str(raised.exception).count("x"), 500)


if __name__ == "__main__":
    unittest.main()
