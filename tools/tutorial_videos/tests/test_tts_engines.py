"""Tests for building the configured TTS engine."""

from __future__ import annotations

import base64
import json
import tempfile
import unittest
from pathlib import Path

from tts_helpers import respond_with

from tutorial_videos.tts.base import TtsError
from tutorial_videos.tts.engines import create_engine

GEMINI_REPLY = json.dumps(
    {
        "candidates": [
            {
                "content": {
                    "parts": [
                        {"inlineData": {"data": base64.b64encode(b"\0\0").decode()}}
                    ]
                }
            }
        ]
    }
).encode()


class CreateEngineTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.env = Path(self._tmp.name) / ".env"
        self.env.write_text(
            "GEMINI_API_KEY=gemini-key\nELEVENLABS_API_KEY=eleven-key\n"
        )

    def tearDown(self):
        self._tmp.cleanup()

    def _sent_request(self, name: str, reply: bytes):
        engine = create_engine(name, "model-x", self.env)
        with respond_with(reply) as urlopen:
            engine.synthesize(text="hi", voice="v", style="", settings={})
        return engine, urlopen.call_args.args[0]

    def test_elevenlabs_uses_its_own_key_and_the_model(self):
        engine, request = self._sent_request("elevenlabs", b"\0\0")
        self.assertEqual((engine.name, engine.model), ("elevenlabs", "model-x"))
        self.assertEqual(request.get_header("Xi-api-key"), "eleven-key")

    def test_gemini_uses_its_own_key_and_the_model(self):
        engine, request = self._sent_request("gemini", GEMINI_REPLY)
        self.assertEqual((engine.name, engine.model), ("gemini", "model-x"))
        self.assertEqual(request.get_header("X-goog-api-key"), "gemini-key")

    def test_a_missing_key_names_it(self):
        self.env.write_text("GEMINI_API_KEY=gemini-key\n")
        with self.assertRaises(KeyError) as raised:
            create_engine("elevenlabs", "m", self.env)
        self.assertIn("ELEVENLABS_API_KEY", str(raised.exception))

    def test_an_unknown_engine_lists_the_known_ones(self):
        with self.assertRaises(TtsError) as raised:
            create_engine("polly", "m", self.env)
        message = str(raised.exception)
        self.assertIn("polly", message)
        self.assertIn("elevenlabs, gemini", message)


if __name__ == "__main__":
    unittest.main()
