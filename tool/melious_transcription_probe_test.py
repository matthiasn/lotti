"""Deterministic checks for the transcription probe; no live inference calls."""

import contextlib
import io
import json
import tempfile
import unittest
import urllib.error
import wave
from pathlib import Path
from unittest.mock import MagicMock, patch

from tool import melious_transcription_probe as probe


def fake_response(status, headers, body):
    response = MagicMock()
    response.status = status
    response.headers = headers
    response.read.return_value = body.encode()
    response.__enter__.return_value = response
    return response


class MeliousTranscriptionProbeTest(unittest.TestCase):
    def test_credentials_require_a_key_and_default_the_base_url(self):
        with self.assertRaises(SystemExit):
            probe.credentials({})
        self.assertEqual(
            probe.credentials({"UP_UPSTREAM_API_KEY": " k "}),
            ("k", "https://api.melious.ai/v1"),
        )
        self.assertEqual(
            probe.credentials(
                {"MELIOUS_API_KEY": "a", "MELIOUS_BASE_URL": "https://x/v1/"}
            ),
            ("a", "https://x/v1"),
        )

    def test_dotenv_reads_only_connection_keys(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / ".env"
            path.write_text(
                "export MELIOUS_API_KEY='from-file'  # comment\nOTHER=x\nbroken\n"
            )
            self.assertEqual(probe.dotenv(path), {"MELIOUS_API_KEY": "from-file"})
        self.assertEqual(probe.dotenv(Path("/nonexistent/.env")), {})

    def test_synthesized_wav_has_the_requested_length(self):
        with wave.open(io.BytesIO(probe.synthesize_wav(1.5, 8000))) as audio:
            self.assertEqual(audio.getnframes(), 12000)
            self.assertEqual(audio.getframerate(), 8000)

    def test_multipart_carries_fields_and_file(self):
        body, content_type = probe.multipart(
            {"model": "whisper-large-v3", "response_format": "json"},
            "file",
            "probe.wav",
            b"RIFFDATA",
        )
        boundary = content_type.split("boundary=")[1]
        self.assertTrue(body.endswith(f"--{boundary}--\r\n".encode()))
        self.assertIn(b'name="model"\r\n\r\nwhisper-large-v3\r\n', body)
        self.assertIn(b'filename="probe.wav"\r\nContent-Type: audio/x-wav', body)
        self.assertIn(b"\r\n\r\nRIFFDATA\r\n", body)

    def test_cost_fields_finds_nested_keys_and_ignores_non_json(self):
        body = json.dumps(
            {
                "text": "hi",
                "billing_cost": {"credits": 0.0012},
                "usage": {"seconds": 2, "total_tokens": 7},
                "segments": [{"meta": {"cost_hint": 1}}],
            }
        )
        found = probe.cost_fields(body)
        self.assertEqual(found["billing_cost"], {"credits": 0.0012})
        self.assertEqual(found["billing_cost.credits"], 0.0012)
        self.assertEqual(found["usage"], {"seconds": 2, "total_tokens": 7})
        self.assertEqual(found["segments[0].meta.cost_hint"], 1)
        self.assertNotIn("text", found)
        self.assertEqual(probe.cost_fields("plain transcript"), {})

    def test_send_redacts_secrets_and_keeps_http_errors(self):
        ok = fake_response(200, {"X-Credits-Used": "3", "Set-Cookie": "s"}, "{}")
        with patch("urllib.request.urlopen", return_value=ok):
            result = probe.send(MagicMock(), 1)
        self.assertEqual(result["status"], 200)
        self.assertEqual(result["headers"]["Set-Cookie"], "<redacted>")
        self.assertEqual(probe.cost_headers(result["headers"]), {"X-Credits-Used": "3"})

        error = urllib.error.HTTPError(
            "u", 402, "Payment Required", {"A": "b"}, io.BytesIO(b'{"error":"x"}')
        )
        with patch("urllib.request.urlopen", side_effect=error):
            result = probe.send(MagicMock(), 1)
        self.assertEqual((result["status"], result["body"]), (402, '{"error":"x"}'))

    def test_main_probes_both_formats_and_saves_without_leaking_the_key(self):
        transcript = json.dumps({"text": "", "usage": {"seconds": 2}})
        chat = json.dumps({"billing_cost": {"credits": 0.5}})
        requests = []

        def urlopen(request, timeout):
            requests.append(request)
            body = chat if request.full_url.endswith("/chat/completions") else transcript
            return fake_response(200, {}, body)

        with tempfile.TemporaryDirectory() as directory:
            saved = Path(directory) / "capture.json"
            out = io.StringIO()
            with (
                patch.dict("os.environ", {"MELIOUS_API_KEY": "secret-key"}, clear=True),
                patch("urllib.request.urlopen", side_effect=urlopen),
                contextlib.redirect_stdout(out),
            ):
                code = probe.main(
                    ["--control-chat", "--save", str(saved), "--env-file", ""]
                )
            captures = json.loads(saved.read_text())

        self.assertEqual(code, 0)
        self.assertEqual(
            list(captures),
            ["transcription[json]", "transcription[verbose_json]", "chat-control"],
        )
        self.assertEqual(
            [r.full_url for r in requests],
            [
                "https://api.melious.ai/v1/audio/transcriptions",
                "https://api.melious.ai/v1/audio/transcriptions",
                "https://api.melious.ai/v1/chat/completions",
            ],
        )
        self.assertIn(b"verbose_json", requests[1].data)
        self.assertIn('body.usage = {"seconds": 2}', out.getvalue())
        self.assertIn("body.billing_cost.credits = 0.5", out.getvalue())
        self.assertNotIn("secret-key", out.getvalue())
        self.assertNotIn("secret-key", json.dumps(captures))


if __name__ == "__main__":
    unittest.main()
