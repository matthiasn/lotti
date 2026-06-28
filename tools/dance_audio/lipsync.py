#!/usr/bin/env python3
"""Offline lip-sync cue track via **Rhubarb Lip Sync** ("rung 5b": real mouth
shapes from the vocal audio, not one-vowel-per-word guesses).

```
audio --(librosa, 16 kHz mono)--> wav --(rhubarb)--> mouth cues (A-F + G,H,X)
      --(assemble)--------------------------------> cue-track JSON (schema 1.0)
```

Rhubarb analyses the **vocal stem** and emits a timeline of Preston-Blair-style
mouth shapes. We keep the letters verbatim; mapping a letter to a drawn mouth is
a rendering concern (the Dart demo owns it). This is authoring-time tooling — it
is **not** shipped in the Flutter app; it produces a deterministic JSON artifact,
exactly like `analyze.py` and `transcribe.py`.

Rhubarb's mouth shapes:
- ``A`` closed (rest / M, B, P)        ``B`` slightly open, teeth closed (many consonants, EE)
- ``C`` open (EH, AE)                  ``D`` wide open (AA)
- ``E`` slightly rounded (AO, ER)      ``F`` puckered (UW, OW, W)
- ``G`` upper teeth on lower lip (F, V) ``H`` "L" (tongue up)   ``X`` idle / rest

Recognizers: ``phonetic`` (language-independent, recognises sounds — the right
default for **sung** vocals) or ``pocketSphinx`` (English speech; pair with
``--dialog`` for best accuracy on clear English).
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np

# Rhubarb is happy with 16 kHz mono; matches the ASR tool and keeps temp files small.
CUE_SR = 16000

# The shapes Rhubarb can emit (six basic + three extended). Recorded in the JSON
# so a consumer knows the alphabet without hard-coding it.
RHUBARB_SHAPES = "ABCDEFGHX"

# The native binary built from tools/dance_audio/vendor/rhubarb-src (see README).
# Override with $RHUBARB_BIN or --rhubarb.
DEFAULT_RHUBARB = os.environ.get("RHUBARB_BIN") or str(
    Path(__file__).resolve().parent / "vendor" / "rhubarb" / "rhubarb"
)


def load_audio(
    path: str,
    *,
    sr: int = CUE_SR,
    offset: float = 0.0,
    duration: float | None = None,
) -> tuple[np.ndarray, int]:
    """Decode `path` to a mono float32 signal at `sr` (default 16 kHz).

    `offset` / `duration` (seconds) select a sub-window; the emitted cue times are
    relative to the segment start (the absolute offset is recorded separately as
    `segment_start_sec`).
    """
    import librosa

    y, sr = librosa.load(path, sr=sr, mono=True, offset=offset, duration=duration)
    return y.astype(np.float32), sr


def dialog_text(lyrics: str) -> str:
    """Reduce a tagged lyrics sheet to plain dialog for Rhubarb's ``--dialogFile``.

    Drops ``[section]`` headers and the ``(...)`` ad-lib parentheses (keeping the
    words inside), leaving one plain line per lyric line. Rhubarb only wants the
    words, not who sings them — voice routing stays with the word tags elsewhere.
    """
    out: list[str] = []
    for raw in lyrics.splitlines():
        line = raw.strip()
        if not line or re.fullmatch(r"\[.+\]", line):
            continue
        out.append(line.replace("(", "").replace(")", "").strip())
    return "\n".join(out)


def _run_rhubarb(
    wav_path: str,
    *,
    recognizer: str,
    dialog_path: str | None,
    rhubarb_bin: str,
) -> dict:
    """Run Rhubarb on a WAV and return its parsed JSON. Mockable in tests (the
    only function that shells out to the binary)."""
    with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as tf:
        out_path = tf.name
    try:
        cmd = [
            rhubarb_bin,
            "--recognizer",
            recognizer,
            "--exportFormat",
            "json",
            "--machineReadable",
            "--quiet",
            "-o",
            out_path,
        ]
        if dialog_path:
            cmd += ["--dialogFile", dialog_path]
        cmd.append(wav_path)
        subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL)
        return json.loads(Path(out_path).read_text())
    finally:
        Path(out_path).unlink(missing_ok=True)


def _round_t(t: float | None) -> float | None:
    return None if t is None else round(float(t), 3)


def lipsync(
    signal: np.ndarray,
    sr: int,
    *,
    audio_path: str,
    recognizer: str = "phonetic",
    dialog: str | None = None,
    stamp: str | None = None,
    segment_start: float = 0.0,
    rhubarb_bin: str = DEFAULT_RHUBARB,
) -> dict:
    """Assemble the cue-track JSON for `signal` by running Rhubarb on it."""
    import soundfile as sf

    tmp_wav = tmp_dialog = None
    try:
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as wf:
            tmp_wav = wf.name
        sf.write(tmp_wav, signal, sr, subtype="PCM_16")
        if dialog:
            with tempfile.NamedTemporaryFile(
                suffix=".txt", delete=False, mode="w", encoding="utf-8"
            ) as df:
                df.write(dialog)
                tmp_dialog = df.name
        raw = _run_rhubarb(
            tmp_wav,
            recognizer=recognizer,
            dialog_path=tmp_dialog,
            rhubarb_bin=rhubarb_bin,
        )
    finally:
        for p in (tmp_wav, tmp_dialog):
            if p:
                Path(p).unlink(missing_ok=True)

    cues = [
        {
            "start_sec": _round_t(c["start"]),
            "end_sec": _round_t(c["end"]),
            "shape": c["value"],
        }
        for c in raw.get("mouthCues", [])
    ]
    return {
        "schema_version": "1.0",
        "audio": {
            "path": audio_path,
            "duration_sec": round(len(signal) / sr, 3),
            "segment_start_sec": round(float(segment_start), 3),
        },
        "lipsync": {
            "engine": "rhubarb",
            "recognizer": recognizer,
            "shapes": RHUBARB_SHAPES,
            "created_utc": stamp,
        },
        "cues": cues,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Rhubarb lip-sync cue track for the dance demo.")
    parser.add_argument("audio", help="path to the audio (ideally a vocals-only stem)")
    parser.add_argument("-o", "--out", help="output JSON path (default: stdout)")
    parser.add_argument(
        "-r",
        "--recognizer",
        default="phonetic",
        choices=["phonetic", "pocketSphinx"],
        help="phonetic (default; best for sung vocals) or pocketSphinx (English speech)",
    )
    parser.add_argument(
        "--dialog",
        help="lyrics file; its plain text improves pocketSphinx accuracy",
    )
    parser.add_argument("--start", type=float, default=0.0, help="window start (seconds)")
    parser.add_argument("--duration", type=float, default=None, help="window length (seconds)")
    parser.add_argument("--stamp", help="embed this UTC timestamp (default: none, for clean diffs)")
    parser.add_argument("--rhubarb", default=DEFAULT_RHUBARB, help="path to the rhubarb binary")
    args = parser.parse_args(argv)

    signal, sr = load_audio(args.audio, offset=args.start, duration=args.duration)
    dialog = None
    if args.dialog:
        dialog = dialog_text(Path(args.dialog).read_text(encoding="utf-8"))

    result = lipsync(
        signal,
        sr,
        audio_path=args.audio,
        recognizer=args.recognizer,
        dialog=dialog,
        stamp=args.stamp,
        segment_start=args.start,
        rhubarb_bin=args.rhubarb,
    )

    text = json.dumps(result, indent=2)
    if args.out:
        Path(args.out).write_text(text + "\n")
        cues = result["cues"]
        print(
            f"wrote {args.out}: {len(cues)} cues, recognizer={args.recognizer}",
            file=sys.stderr,
        )
    else:
        print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
