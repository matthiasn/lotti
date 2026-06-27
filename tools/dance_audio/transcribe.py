#!/usr/bin/env python3
"""Offline word-level transcription: audio file -> timestamped lyric JSON.

Authoring-time tooling only; this is **not** shipped inside the Flutter app. It
is "rung 5" of the dance pipeline: a choreographer later syncs mouth shapes and
lyric accents to the vocals, which needs *word-level* (and segment-level)
timestamps, not just text.

Engine: **WhisperX** (https://github.com/m-bain/whisperX, BSD-2-Clause). It runs
faster-whisper to transcribe, then wav2vec2 forced alignment to pull each word
onto the audio, yielding per-word ``start``/``end``/``score``. Diarization
(speaker labels) is intentionally skipped — it needs pyannote + an HF token and
we only want word timestamps. CPU only; default model ``base`` for a small
footprint.

Pipeline:

    audio --(librosa, 16 kHz mono)--> signal
          --(faster-whisper)--------> segments (text + coarse times)
          --(wav2vec2 align)--------> words (fine start/end/score)
          --(assemble)--------------> the transcription JSON below

Determinism: the JSON is a pure function of (audio bytes, model, flags). No
wall-clock time is written by default, so re-running on the same input yields
byte-identical output (clean diffs, reproducible reviews). Pass --stamp to embed
a creation time.

CAVEAT — sung vocals: Whisper and the wav2vec2 aligner are trained on *speech*.
On sung lyrics — sustained vowels, melisma, heavy backing instrumentation,
falsetto, ad-libs — both transcription text and word timing degrade. Treat the
output as a strong first draft to be hand-corrected, not ground truth. Feeding a
vocals-only stem (source-separated) improves results markedly.

Usage:
    python transcribe.py path/to/track.mp3 [-o out.json] [--model base]
    python transcribe.py track.mp3 --start 72 --duration 30 -o seg.json  # mid-song window
"""

from __future__ import annotations

import argparse
import json
import sys
from importlib.metadata import PackageNotFoundError, version

import librosa
import numpy as np

# Whisper / wav2vec2 operate on 16 kHz mono; decode straight to that rate so the
# transcription and the forced alignment run on one signal with no resample.
ASR_SR = 16000

# CPU-friendly knobs. ctranslate2/faster-whisper supports int8 on CPU (float16 is
# GPU-only); a small batch keeps the working set modest on a laptop CPU.
ASR_COMPUTE_TYPE = "int8"
ASR_BATCH_SIZE = 8

# Round-trip-friendly precision so the JSON stays compact and diff-stable.
_T = 3  # seconds / times -> milliseconds
_SCORE = 3


def _pkg_version(name: str) -> str:
    """Package version, or "unknown" when it is not installed.

    Lets assembly run (and be unit-tested) without the heavy WhisperX / torch
    stack present — the provenance string just records "unknown" for it.
    """
    try:
        return version(name)
    except PackageNotFoundError:
        return "unknown"


def load_audio(
    path: str,
    sr: int = ASR_SR,
    *,
    offset: float = 0.0,
    duration: float | None = None,
) -> tuple[np.ndarray, int]:
    """Decode `path` to a mono float32 signal at `sr` (default 16 kHz for Whisper).

    `offset` / `duration` (seconds) select a sub-window, so a 30 s segment in the
    *middle* of a track can be transcribed. The returned signal is 0-based, so the
    emitted word/segment times are relative to the segment start (the absolute
    offset is recorded separately as `segment_start_sec`).
    """
    y, sr = librosa.load(path, sr=sr, mono=True, offset=offset, duration=duration)
    return y.astype(np.float32), sr


def _run_asr(signal: np.ndarray, sr: int, *, model: str, language: str | None = None) -> dict:
    """Run WhisperX transcribe + wav2vec2 forced alignment on CPU.

    Returns ``{"language", "aligner", "segments", "words"}`` with raw (unrounded)
    floats; the caller rounds for determinism. ``segments`` is a list of
    ``{start, end, text}`` and ``words`` a flat list of ``{word, start, end,
    score}`` (start/end/score may be None when alignment fails for a token).

    The whisperx import is **lazy** so the unit tests — which monkeypatch this
    function — need neither whisperx nor torch installed. CPU only; diarization is
    deliberately not performed (no pyannote / HF token).
    """
    import whisperx

    device = "cpu"
    asr_model = whisperx.load_model(model, device, compute_type=ASR_COMPUTE_TYPE, language=language)
    result = asr_model.transcribe(signal, batch_size=ASR_BATCH_SIZE)
    lang = language or result.get("language", "en")

    align_model, metadata = whisperx.load_align_model(language_code=lang, device=device)
    aligned = whisperx.align(
        result["segments"],
        align_model,
        metadata,
        signal,
        device,
        return_char_alignments=False,
    )

    segments = [
        {"start": s.get("start"), "end": s.get("end"), "text": s.get("text", "")}
        for s in aligned.get("segments", [])
    ]
    words = [
        {
            "word": w.get("word", ""),
            "start": w.get("start"),
            "end": w.get("end"),
            "score": w.get("score"),
        }
        for w in aligned.get("word_segments", [])
    ]
    return {
        "language": lang,
        "aligner": f"{_align_model_name(lang)} (whisperx@{_pkg_version('whisperx')})",
        "segments": segments,
        "words": words,
    }


def _align_model_name(lang: str) -> str:
    """Best-effort name of WhisperX's default wav2vec2 aligner for `lang`.

    WhisperX picks the aligner from internal language->model tables; surface that
    name for provenance, falling back to a generic label if the tables move
    between versions.
    """
    try:
        from whisperx import alignment

        torch_name = alignment.DEFAULT_ALIGN_MODELS_TORCH.get(lang)
        hf_name = alignment.DEFAULT_ALIGN_MODELS_HF.get(lang)
        return torch_name or hf_name or "wav2vec2"
    except Exception:  # pragma: no cover - depends on whisperx internals at runtime
        return "wav2vec2"


def _round_t(value: float | None) -> float | None:
    """Round a time (seconds) to ms precision, passing None through."""
    return round(float(value), _T) if value is not None else None


# Common Whisper end-of-silence hallucinations (whole lines), normalized
# (lowercased, surrounding punctuation/space stripped). Matched per SEGMENT — not
# per word — so a real lyric word like "you" inside a line is never dropped.
_BOILERPLATE = {
    "thank you",
    "thank you for watching",
    "thanks for watching",
    "thanks",
    "you",
    "bye",
    "subscribe",
    "please subscribe",
}


def _is_boilerplate(text: str) -> bool:
    return text.strip().strip(".!?… ").lower() in _BOILERPLATE


def transcribe(
    signal: np.ndarray,
    sr: int,
    *,
    audio_path: str,
    model: str,
    language: str | None = None,
    stamp: str | None = None,
    segment_start: float = 0.0,
) -> dict:
    """Run ASR + alignment and assemble the transcription dict (schema 1.0).

    `segment_start` is the offset (seconds) this signal was decoded from; it is
    recorded for traceability. Word/segment times stay relative to the segment
    (0-based). The result is deterministic unless `stamp` is provided.
    """
    asr = _run_asr(signal, sr, model=model, language=language)

    raw_segments = [
        {
            "start_sec": _round_t(s.get("start")),
            "end_sec": _round_t(s.get("end")),
            "text": (s.get("text") or "").strip(),
        }
        for s in asr["segments"]
    ]
    # Drop whole-line hallucinations (e.g. a trailing "Thank you.") and any words
    # that fall inside a dropped segment's time window.
    boiler_ranges = [
        (s["start_sec"], s["end_sec"])
        for s in raw_segments
        if _is_boilerplate(s["text"]) and s["start_sec"] is not None and s["end_sec"] is not None
    ]

    def _in_boilerplate(t: float | None) -> bool:
        return t is not None and any(lo <= t <= hi for lo, hi in boiler_ranges)

    segments = [s for s in raw_segments if not _is_boilerplate(s["text"])]
    words = [
        {
            "word": (w.get("word") or "").strip(),
            "start_sec": _round_t(w.get("start")),
            "end_sec": _round_t(w.get("end")),
            "score": round(float(w["score"]), _SCORE) if w.get("score") is not None else None,
        }
        for w in asr["words"]
        if not _in_boilerplate(_round_t(w.get("start")))
    ]

    return {
        "schema_version": "1.0",
        "audio": {
            "path": audio_path,
            "duration_sec": round(len(signal) / sr, _T),
            "segment_start_sec": round(segment_start, _T),
        },
        "asr": {
            "model": model,
            "language": asr["language"],
            "aligner": asr["aligner"],
            "created_utc": stamp,  # None unless --stamp (keeps output deterministic)
        },
        "segments": segments,
        "words": words,
    }


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description="audio -> word/segment-timestamped transcription JSON (WhisperX, CPU)"
    )
    ap.add_argument("audio", help="path to an audio file (wav/mp3/flac/...)")
    ap.add_argument("-o", "--out", help="write JSON here (default: stdout)")
    ap.add_argument(
        "--model",
        default="base",
        help="faster-whisper model size (tiny/base/small/medium/large-v3); default base",
    )
    ap.add_argument(
        "--language",
        default=None,
        help="force language code (e.g. en); default: auto-detect",
    )
    ap.add_argument(
        "--start",
        type=float,
        default=0.0,
        help="transcribe from this offset in seconds (for a mid-song segment)",
    )
    ap.add_argument(
        "--duration",
        type=float,
        default=None,
        help="transcribe only this many seconds from --start (e.g. 30)",
    )
    ap.add_argument(
        "--stamp",
        action="store_true",
        help="embed a UTC creation time (breaks deterministic output)",
    )
    args = ap.parse_args(argv)

    stamp = None
    if args.stamp:
        import datetime

        stamp = datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds")

    signal, sr = load_audio(args.audio, offset=args.start, duration=args.duration)
    result = transcribe(
        signal,
        sr,
        audio_path=args.audio,
        model=args.model,
        language=args.language,
        stamp=stamp,
        segment_start=args.start,
    )
    text = json.dumps(result, indent=2)
    if args.out:
        with open(args.out, "w") as f:
            f.write(text + "\n")
        print(
            f"wrote {args.out}: {len(result['segments'])} segments, "
            f"{len(result['words'])} words, "
            f"model={result['asr']['model']} lang={result['asr']['language']}",
            file=sys.stderr,
        )
    else:
        print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
