"""Tests for the Gemini TTS adapter (no network: urlopen is patched)."""

from __future__ import annotations

import base64
import json
import tempfile
import unittest
from pathlib import Path

from tts_helpers import respond_with, wav_info

from tutorial_videos.tts.gemini import GeminiTts, read_env_key

PCM = b"\x01\x00\x02\x00" * 50
AUDIO_REPLY = json.dumps(
    {
        "candidates": [
            {
                "content": {
                    "parts": [{"inlineData": {"data": base64.b64encode(PCM).decode()}}]
                }
            }
        ]
    }
).encode()


def _synthesize(**overrides) -> bytes:
    request = dict(text="Hello", voice="Algieba", style="Speak calmly:", settings={})
    request.update(overrides)
    return GeminiTts("secret-key", "models/gemini-tts").synthesize(**request)


class GeminiTtsTest(unittest.TestCase):
    def test_speaks_the_style_instruction_ahead_of_the_text(self):
        with respond_with(AUDIO_REPLY) as urlopen:
            _synthesize()
        (request,), _ = urlopen.call_args
        body = json.loads(request.data)
        self.assertEqual(body["contents"][0]["parts"][0]["text"], "Speak calmly: Hello")
        self.assertEqual(
            body["generationConfig"]["speechConfig"]["voiceConfig"],
            {"prebuiltVoiceConfig": {"voiceName": "Algieba"}},
        )
        self.assertTrue(request.full_url.endswith("/models/gemini-tts:generateContent"))
        self.assertEqual(request.get_header("X-goog-api-key"), "secret-key")

    def test_ignores_voice_settings_it_has_no_use_for(self):
        with respond_with(AUDIO_REPLY) as urlopen:
            _synthesize(settings={"stability": 0.5})
        (request,), _ = urlopen.call_args
        self.assertNotIn("stability", request.data.decode())

    def test_wraps_the_returned_audio_as_a_24khz_mono_wav(self):
        with respond_with(AUDIO_REPLY):
            self.assertEqual(wav_info(_synthesize()), (1, 2, 24_000, PCM))

    def test_a_reply_without_audio_is_an_error(self):
        with respond_with(b'{"candidates": []}'), self.assertRaises(RuntimeError):
            _synthesize()


class ReadEnvKeyTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.env = Path(self._tmp.name) / ".env"
        self.env.write_text("OTHER=1\nGEMINI_API_KEY= abc=def \n")

    def tearDown(self):
        self._tmp.cleanup()

    def test_reads_the_value_after_the_first_equals_sign(self):
        self.assertEqual(read_env_key(self.env, "GEMINI_API_KEY"), "abc=def")

    def test_a_missing_key_names_the_key_and_the_file(self):
        with self.assertRaises(KeyError) as raised:
            read_env_key(self.env, "ELEVENLABS_API_KEY")
        self.assertIn("ELEVENLABS_API_KEY", str(raised.exception))


if __name__ == "__main__":
    unittest.main()
