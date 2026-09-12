"""Deterministic checks for the diagnostic probe; no live inference calls."""

import contextlib
import io
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

from tool import deepseek_image_probe as probe


class DeepseekImageProbeTest(unittest.TestCase):
    def test_image_does_not_change_tool_serialization_or_decoding_parameters(self):
        for choice in ("absent", "forced", "auto", "required"):
            with self.subTest(choice=choice):
                text = probe.build_request(
                    "deepseek-v4.1-flash", "text", choice, "unused"
                )
                image = probe.build_request(
                    "deepseek-v4.1-flash", "image", choice, "data:image/png;base64,AA=="
                )
                self.assertEqual(
                    {k: v for k, v in text.items() if k != "messages"},
                    {k: v for k, v in image.items() if k != "messages"},
                )
                self.assertEqual(text["messages"][0], image["messages"][0])
                self.assertEqual(
                    image["messages"][1]["content"][1],
                    {
                        "type": "image_url",
                        "image_url": {"url": "data:image/png;base64,AA=="},
                    },
                )
                for field in (
                    "stop",
                    "temperature",
                    "reasoning_effort",
                    "max_completion_tokens",
                ):
                    self.assertNotIn(field, image)

    def test_forced_and_auto_differ_only_in_tool_choice(self):
        forced = probe.build_request("model", "image", "forced", "image")
        auto = probe.build_request("model", "image", "auto", "image")
        self.assertEqual(
            forced.pop("tool_choice"),
            {
                "type": "function",
                "function": {"name": "publish_entry_summary"},
            },
        )
        self.assertEqual(auto.pop("tool_choice"), "auto")
        self.assertEqual(forced, auto)
        self.assertEqual(
            forced["tools"][0]["function"]["parameters"]["required"],
            ["oneLiner", "tldr", "summary"],
        )

    def test_no_tool_request_has_no_tool_instruction(self):
        body = probe.build_request("model", "image", "absent", "image")
        self.assertNotIn("tools", body)
        self.assertNotIn("tool_choice", body)
        self.assertNotIn(probe.TOOL_NAME, json.dumps(body))

    def test_credentials_respect_environment_and_do_not_execute_shell(self):
        with tempfile.TemporaryDirectory() as directory:
            env_file = Path(directory) / "settings.env"
            marker = Path(directory) / "must-not-exist"
            env_file.write_text(
                'UP_UPSTREAM_API_KEY="file-key"\n'
                'UP_UPSTREAM_BASE_URL="https://api.melious.ai/v1"\n'
                f"UNRELATED=$(touch {marker})\n"
            )
            with patch.dict(os.environ, {"MELIOUS_API_KEY": "env-key"}, clear=True):
                self.assertEqual(
                    probe.credentials(env_file),
                    ("env-key", "https://api.melious.ai/v1"),
                )
            self.assertFalse(marker.exists())

    def test_raw_dsml_and_stream_frames_survive_unchanged(self):
        raw = '<｜DSML｜ invoke name="publish_entry_summary">true</｜DSML｜ invoke>'
        json_body = json.dumps(
            {"choices": [{"message": {"content": raw}}]}, ensure_ascii=False
        ).encode()
        for stream in (False, True):
            with (
                self.subTest(stream=stream),
                tempfile.TemporaryDirectory() as directory,
            ):
                root = Path(directory)
                image_file = root / "sample.png"
                image_file.write_bytes(b"synthetic-image-bytes")
                output = root / "results"
                body = (
                    b"data: " + json_body + b"\n\ndata: [DONE]\n\n"
                    if stream
                    else json_body
                )
                response = MagicMock()
                response.status = 200
                response.read.return_value = body
                opener = MagicMock()
                opener.open.return_value = response
                argv = [
                    "probe",
                    "--image",
                    str(image_file),
                    "--output",
                    str(output),
                    "--cases",
                    "image-forced",
                ] + (["--stream"] if stream else [])
                stdout = io.StringIO()
                with (
                    patch("sys.argv", argv),
                    patch.dict(
                        os.environ, {"MELIOUS_API_KEY": "secret-key"}, clear=True
                    ),
                    patch.object(
                        probe.urllib.request, "build_opener", return_value=opener
                    ),
                    contextlib.redirect_stdout(stdout),
                ):
                    self.assertEqual(probe.main(), 0)
                self.assertEqual(
                    (output / "image-forced.response.raw").read_bytes(), body
                )
                self.assertIn(body.decode(), stdout.getvalue())
                self.assertNotIn("secret-key", stdout.getvalue())
                metadata = (output / "image-forced.request.json").read_text()
                self.assertNotIn("secret-key", metadata)
                self.assertIn("<omitted;sha256=", metadata)
                request = opener.open.call_args.args[0]
                self.assertEqual(
                    request.get_header("Authorization"), "Bearer secret-key"
                )
                self.assertEqual(json.loads(request.data)["stream"], stream)

    def test_redirect_does_not_forward_credential(self):
        self.assertIsNone(
            probe.NoRedirect().redirect_request(
                None, None, 302, "redirect", {}, "https://elsewhere.example"
            )
        )


if __name__ == "__main__":
    unittest.main()
