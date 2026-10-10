#!/usr/bin/env python3
"""Capture the raw Melious /audio/transcriptions response, headers and all.

Answers one question: does the transcription endpoint report cost the way a
non-streaming chat completion does (`billing_cost.credits`,
`environment_impact.*`, `usage`)? The request mirrors
MeliousInferenceRepository's multipart upload. Nothing is parsed into typed
fields first, so no field the app does not know about yet can be missed.

Credentials come from MELIOUS_API_KEY (or UP_UPSTREAM_API_KEY) and the base URL
from MELIOUS_BASE_URL, defaulting to the app's; the repo's .env is the
fallback for both. Without --audio a short WAV is
synthesized. --control-chat also sends a one-word non-streaming chat
completion, so the two cost shapes can be compared. The key is never printed.
"""

from __future__ import annotations

import argparse
import io
import json
import math
import mimetypes
import os
import shlex
import struct
import sys
import time
import urllib.error
import urllib.request
import uuid
import wave
from pathlib import Path

DEFAULT_BASE_URL = "https://api.melious.ai/v1"
DEFAULT_MODEL = "whisper-large-v3"
DEFAULT_CHAT_MODEL = "mistral-small-4-119b-instruct"
COST_KEYS = ("billing_cost", "environment_impact", "usage", "cost", "credits")
REDACTED_HEADERS = {"authorization", "set-cookie", "cookie"}


def dotenv(path):
    """Only the connection keys from a dotenv file; anything else is ignored."""
    allowed = ("MELIOUS_API_KEY", "MELIOUS_BASE_URL", "UP_UPSTREAM_API_KEY")
    values = {}
    if path and path.is_file():
        for line in path.read_text().splitlines():
            key, sep, value = line.removeprefix("export ").partition("=")
            if sep and key.strip() in allowed:
                tokens = shlex.split(value, comments=True)
                values[key.strip()] = tokens[0] if tokens else ""
    return values


def credentials(environment):
    """API key and base URL from the environment; the key is required."""
    key = environment.get("MELIOUS_API_KEY") or environment.get("UP_UPSTREAM_API_KEY")
    if not key:
        raise SystemExit("Set MELIOUS_API_KEY (or UP_UPSTREAM_API_KEY)")
    base = environment.get("MELIOUS_BASE_URL") or DEFAULT_BASE_URL
    return key.strip(), base.strip().rstrip("/")


def synthesize_wav(seconds=2.0, rate=16000):
    """A mono 16-bit tone: enough audio to be billed, no speech to transcribe."""
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(rate)
        frames = int(seconds * rate)
        out.writeframes(
            b"".join(
                struct.pack("<h", int(8000 * math.sin(2 * math.pi * 440 * i / rate)))
                for i in range(frames)
            )
        )
    return buffer.getvalue()


def multipart(fields, file_field, filename, payload):
    """Encode form fields plus one file as multipart/form-data."""
    boundary = uuid.uuid4().hex
    content_type = mimetypes.guess_type(filename)[0] or "application/octet-stream"
    parts = []
    for name, value in fields.items():
        parts.append(
            f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"'
            f"\r\n\r\n{value}\r\n".encode()
        )
    parts.append(
        f'--{boundary}\r\nContent-Disposition: form-data; name="{file_field}"; '
        f'filename="{filename}"\r\nContent-Type: {content_type}\r\n\r\n'.encode()
        + payload
        + b"\r\n"
    )
    parts.append(f"--{boundary}--\r\n".encode())
    return b"".join(parts), f"multipart/form-data; boundary={boundary}"


def send(request, timeout):
    """Status, headers and body of one request, HTTP errors included."""
    started = time.monotonic()
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            status, headers, body = response.status, response.headers, response.read()
    except urllib.error.HTTPError as error:
        status, headers, body = error.code, error.headers, error.read()
    return {
        "status": status,
        "elapsed_ms": round((time.monotonic() - started) * 1000),
        "headers": {
            k: ("<redacted>" if k.lower() in REDACTED_HEADERS else v)
            for k, v in headers.items()
        },
        "body": body.decode("utf-8", errors="replace"),
    }


def transcription_request(base, key, model, audio, filename, response_format):
    body, content_type = multipart(
        {"model": model, "response_format": response_format},
        "file",
        filename,
        audio,
    )
    return urllib.request.Request(
        f"{base}/audio/transcriptions",
        data=body,
        method="POST",
        headers={"Authorization": f"Bearer {key}", "Content-Type": content_type},
    )


def chat_request(base, key, model):
    payload = {
        "model": model,
        "messages": [{"role": "user", "content": "Reply with the word: ok"}],
        "max_tokens": 5,
        "stream": False,
    }
    return urllib.request.Request(
        f"{base}/chat/completions",
        data=json.dumps(payload).encode(),
        method="POST",
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
    )


def cost_fields(body_text):
    """Every cost-looking key found anywhere in a JSON body, by dotted path."""
    try:
        decoded = json.loads(body_text)
    except ValueError:
        return {}
    found = {}

    def walk(value, path):
        if isinstance(value, dict):
            for key, child in value.items():
                child_path = f"{path}.{key}" if path else key
                if any(marker in key.lower() for marker in COST_KEYS):
                    found[child_path] = child
                walk(child, child_path)
        elif isinstance(value, list):
            for index, child in enumerate(value):
                walk(child, f"{path}[{index}]")

    walk(decoded, "")
    return found


def cost_headers(headers):
    markers = ("cost", "credit", "billing", "usage", "impact", "energy", "carbon")
    return {k: v for k, v in headers.items() if any(m in k.lower() for m in markers)}


def report(label, result, out=None):
    out = out or sys.stdout
    print(f"\n=== {label}: HTTP {result['status']} in {result['elapsed_ms']} ms ===", file=out)
    print("--- headers ---", file=out)
    for key, value in result["headers"].items():
        print(f"{key}: {value}", file=out)
    print("--- body ---", file=out)
    try:
        print(json.dumps(json.loads(result["body"]), indent=2, ensure_ascii=False), file=out)
    except ValueError:
        print(result["body"], file=out)
    print("--- cost-looking fields ---", file=out)
    fields = cost_fields(result["body"])
    headers = cost_headers(result["headers"])
    if not fields and not headers:
        print("(none)", file=out)
    for path, value in fields.items():
        print(f"body.{path} = {json.dumps(value)}", file=out)
    for key, value in headers.items():
        print(f"header.{key} = {value}", file=out)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--audio", type=Path, help="audio file; a tone WAV if omitted")
    parser.add_argument("--seconds", type=float, default=2.0, help="synthesized length")
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument(
        "--response-format",
        action="append",
        help="json, verbose_json, text …; repeatable (default: json and verbose_json)",
    )
    parser.add_argument("--control-chat", action="store_true")
    parser.add_argument("--chat-model", default=DEFAULT_CHAT_MODEL)
    parser.add_argument("--timeout", type=float, default=120)
    parser.add_argument("--save", type=Path, help="write every capture to this JSON file")
    parser.add_argument(
        "--env-file",
        type=Path,
        default=Path(__file__).resolve().parent.parent / ".env",
        help="dotenv fallback for the key; exported variables win",
    )
    args = parser.parse_args(argv)

    key, base = credentials({**dotenv(args.env_file), **os.environ})
    if args.audio:
        audio, filename = args.audio.read_bytes(), args.audio.name
    else:
        audio, filename = synthesize_wav(args.seconds), "probe.wav"
    print(f"POST {base}/audio/transcriptions model={args.model} file={filename} "
          f"({len(audio)} bytes)")

    captures = {}
    for response_format in args.response_format or ["json", "verbose_json"]:
        label = f"transcription[{response_format}]"
        captures[label] = send(
            transcription_request(base, key, args.model, audio, filename, response_format),
            args.timeout,
        )
        report(label, captures[label])
    if args.control_chat:
        captures["chat-control"] = send(chat_request(base, key, args.chat_model), args.timeout)
        report("chat-control", captures["chat-control"])
    if args.save:
        args.save.write_text(json.dumps(captures, indent=2, ensure_ascii=False))
        print(f"\nSaved to {args.save}")
    return 0 if all(c["status"] < 400 for c in captures.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
