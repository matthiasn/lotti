#!/usr/bin/env python3
"""Offline dance-audio analysis: audio file -> beat-map JSON.

Authoring-time tooling only; this is **not** shipped inside the Flutter app. It
produces the deterministic beat-map artifact that the Dart side
(`BeatMap` / `clipSecondsAt`) consumes to make the character dance land on the
real beat instead of a guessed constant BPM.

Pipeline (see docs/implementation_plans/2026-06-27_dance_audio_analysis.md):

    audio -> Beat This! (beats + downbeats)        # MIT, joint beat+downbeat
          -> librosa cross-check (global tempo)    # octave-error sanity
          -> assemble beat-map JSON (the §5 schema)

Determinism: the JSON is a pure function of (audio bytes, tool version, flags).
No wall-clock timestamp is written by default, so re-running on the same input
yields byte-identical output (clean diffs, reproducible reviews). Pass --stamp
to embed a creation time.

Usage:
    python analyze.py path/to/track.wav [-o out.json] [--bpm-hint 124]
    python analyze.py --selftest        # synthetic click track, no audio needed
"""

from __future__ import annotations

import argparse
import contextlib
import io
import json
import sys
from importlib.metadata import PackageNotFoundError, version

import librosa
import numpy as np

# Beat This! resamples internally to this rate; loading the audio here at the
# same rate avoids a second decode and keeps librosa + Beat This! on one signal.
ANALYSIS_SR = 22050

# A beat is "the same as" a downbeat (or two beat times coincide) within this
# tolerance, in seconds. Beat This! returns downbeats as a subset of beats.
_MATCH_TOL_S = 0.03

# Round-trip-friendly precision so the JSON stays compact and diff-stable.
_T = 3  # seconds / times -> milliseconds
_BPM = 2
_CONF = 3


def _pkg_version(name: str) -> str:
    """Package version, or "unknown" when it is not installed.

    Lets the analysis run (and be unit-tested) without the heavy Beat This! /
    torch stack present — the tracker string just records "unknown" for it.
    """
    try:
        return version(name)
    except PackageNotFoundError:
        return "unknown"


def load_audio(path: str, sr: int = ANALYSIS_SR) -> tuple[np.ndarray, int]:
    """Decode `path` to a mono float32 signal at `sr`."""
    y, sr = librosa.load(path, sr=sr, mono=True)
    return y.astype(np.float32), sr


def _run_beat_this(signal: np.ndarray, sr: int, *, dbn: bool) -> tuple[np.ndarray, np.ndarray]:
    """Run Beat This! and return (beat_times, downbeat_times) in seconds.

    Beat This!'s frame inference prints a progress meter to stdout; we swallow it
    so the tool's stdout stays clean for JSON. dbn=True needs madmom (NonCommercial
    models) and is intentionally not installed by default — see the README.
    """
    from beat_this.inference import Audio2Beats

    a2b = Audio2Beats(checkpoint_path="final0", device="cpu", dbn=dbn)
    with contextlib.redirect_stdout(io.StringIO()):
        beats, downbeats = a2b(signal, sr)
    return np.asarray(beats, dtype=float), np.asarray(downbeats, dtype=float)


def _librosa_global_bpm(signal: np.ndarray, sr: int) -> float:
    """A second, independent global tempo estimate for octave-error sanity."""
    tempo, _ = librosa.beat.beat_track(y=signal, sr=sr)
    return float(np.atleast_1d(tempo)[0])


def _onsets(signal: np.ndarray, sr: int) -> list[dict]:
    """Onset accents with a normalized 0..1 strength (drives later 'hit' accents)."""
    env = librosa.onset.onset_strength(y=signal, sr=sr)
    frames = librosa.onset.onset_detect(onset_envelope=env, sr=sr, backtrack=False)
    if len(frames) == 0:
        return []
    times = librosa.frames_to_time(frames, sr=sr)
    strengths = env[frames]
    peak = float(strengths.max()) or 1.0
    return [
        {"time_sec": round(float(t), _T), "strength": round(float(s) / peak, _CONF)}
        for t, s in zip(times, strengths)
    ]


def _match(beat: float, downbeats: np.ndarray) -> bool:
    if downbeats.size == 0:
        return False
    return bool(np.min(np.abs(downbeats - beat)) <= _MATCH_TOL_S)


def _beat_confidence(ibis: np.ndarray, median_ibi: float) -> np.ndarray:
    """Heuristic per-beat confidence from local tempo consistency.

    Beat This! (no DBN) gives no native per-beat confidence, but the consumer
    wants a 'hold tempo through shaky regions instead of snapping' signal. A beat
    whose inter-beat interval is close to the median scores ~1; a big local
    deviation scores lower. This is a deliberate placeholder, documented as such.
    """
    if median_ibi <= 0:
        return np.ones(len(ibis) + 1)
    dev = np.abs(ibis - median_ibi) / median_ibi
    conf = np.exp(-3.0 * dev)
    # ibis has len(beats)-1 entries; assign each beat the min of its adjacent IBIs.
    per_beat = np.ones(len(ibis) + 1)
    per_beat[:-1] = np.minimum(per_beat[:-1], conf)
    per_beat[1:] = np.minimum(per_beat[1:], conf)
    return per_beat


def _time_signature_numerator(beats: np.ndarray, downbeats: np.ndarray) -> int:
    """Median number of beats between consecutive downbeats (default 4)."""
    if downbeats.size < 2:
        return 4
    db_idx = [int(np.argmin(np.abs(beats - db))) for db in downbeats]
    spans = np.diff(db_idx)
    spans = spans[spans > 0]
    if spans.size == 0:
        return 4
    return int(np.median(spans))


def _tempo_segments(beats: np.ndarray) -> list[dict]:
    """Run-length-encode per-beat BPM (rounded) into constant-tempo segments."""
    if beats.size < 2:
        return []
    ibis = np.diff(beats)
    bpms = np.round(60.0 / ibis).astype(int)
    segments = []
    run_bpm = None
    for i, bpm in enumerate(bpms):
        if bpm != run_bpm:
            segments.append(
                {
                    "start_beat": int(i),
                    "start_time_sec": round(float(beats[i]), _T),
                    "bpm": float(bpm),
                }
            )
            run_bpm = bpm
    return segments


def analyze(
    signal: np.ndarray,
    sr: int,
    *,
    audio_path: str,
    bpm_hint: float | None = None,
    dbn: bool = False,
    stamp: str | None = None,
) -> dict:
    """Run the full pipeline and return the beat-map dict (§5 schema)."""
    beats, downbeats = _run_beat_this(signal, sr, dbn=dbn)
    if beats.size == 0:
        raise SystemExit("Beat This! found no beats — is the audio silent/too short?")

    ibis = np.diff(beats)
    median_ibi = float(np.median(ibis)) if ibis.size else 0.0
    global_bpm = round(60.0 / median_ibi, _BPM) if median_ibi else 0.0
    per_bpm = 60.0 / ibis if ibis.size else np.array([global_bpm])
    is_variable = bool(ibis.size and (np.std(ibis) / max(median_ibi, 1e-9)) > 0.04)
    conf = _beat_confidence(ibis, median_ibi)

    numerator = _time_signature_numerator(beats, downbeats)

    # Walk beats, assigning bar position (reset to 1 on each downbeat).
    beat_rows = []
    pos = 0
    for i, t in enumerate(beats):
        is_db = _match(float(t), downbeats)
        pos = 1 if is_db else pos + 1
        if i == 0 and not is_db:
            pos = 1  # phrase may start mid-bar; best-effort until the first downbeat
        beat_rows.append(
            {
                "index": i,
                "time_sec": round(float(t), _T),
                "beat_in_bar": int(pos),
                "is_downbeat": is_db,
                "confidence": round(float(conf[i]), _CONF),
            }
        )

    # Octave-error sanity: compare to an independent librosa tempo estimate.
    librosa_bpm = round(_librosa_global_bpm(signal, sr), _BPM)
    octave_flag = "ok"
    if global_bpm > 0 and librosa_bpm > 0:
        ratio = librosa_bpm / global_bpm
        if 0.45 <= ratio <= 0.55:
            octave_flag = "librosa_half"  # Beat This! may be double-time
        elif 1.9 <= ratio <= 2.1:
            octave_flag = "librosa_double"  # Beat This! may be half-time

    tracker = (
        f"beat_this@{_pkg_version('beat-this')} ({'dbn' if dbn else 'no-dbn'}); "
        f"librosa@{_pkg_version('librosa')}"
    )

    return {
        "schema_version": "1.0",
        "audio": {
            "path": audio_path,
            "duration_sec": round(len(signal) / sr, _T),
            "sample_rate": sr,
        },
        "analysis": {
            "tracker": tracker,
            "created_utc": stamp,  # None unless --stamp (keeps output deterministic)
            "human_corrected": False,
            "cross_check": {
                "librosa_global_bpm": librosa_bpm,
                "bpm_hint": bpm_hint,
                "octave_flag": octave_flag,
            },
        },
        "tempo": {
            "global_bpm": global_bpm,
            "is_variable": is_variable,
            "bpm_min": round(float(np.min(per_bpm)), _BPM),
            "bpm_max": round(float(np.max(per_bpm)), _BPM),
            "confidence": round(float(np.mean(conf)), _CONF),
        },
        "time_signature": {
            "numerator": numerator,
            "denominator": 4,
            "is_constant": True,
        },
        "beats": beat_rows,
        "tempo_segments": _tempo_segments(beats),
        "offset_sec": round(float(beats[0]), _T),
        "downbeats_sec": [round(float(d), _T) for d in downbeats],
        # Loop block is choreography-specific; defaults to 2 bars anchored on the
        # first detected downbeat. The Dart side / choreographer can override.
        "loop": {
            "length_beats": numerator * 2,
            "anchor_downbeat_index": 0,
        },
        "onsets": _onsets(signal, sr),
    }


def _synth_click(bpm: float = 120.0, n_beats: int = 16, sr: int = ANALYSIS_SR) -> np.ndarray:
    """A deterministic 4/4 click track for --selftest (no real audio needed)."""
    spb = 60.0 / bpm
    out = np.zeros(int(spb * n_beats * sr), dtype=np.float32)
    for b in range(n_beats):
        i0 = int(b * spb * sr)
        i1 = min(len(out), i0 + int(0.06 * sr))
        env = np.exp(-np.arange(i1 - i0) / (0.012 * sr))
        tone = np.sin(2 * np.pi * 1000.0 * (np.arange(i1 - i0) / sr)) * env
        if b % 4 == 0:  # accent the downbeat with a low thump
            tone = tone + 1.4 * np.sin(2 * np.pi * 60.0 * (np.arange(i1 - i0) / sr)) * env
        out[i0:i1] += tone
    return (out / np.max(np.abs(out)) * 0.9).astype(np.float32)


def _selftest() -> int:
    """Validate the pipeline end-to-end on a synthetic 120 BPM click.

    Asserts the *beat* grid is recovered (the robust signal). Downbeat phase is
    NOT asserted: a bare metronome is out-of-distribution for the bar model, so
    downbeat reliability must be judged on real music (the rung-3 feasibility
    gate), not here.
    """
    sig = _synth_click()
    bm = analyze(sig, ANALYSIS_SR, audio_path="<selftest-click>")
    bpm = bm["tempo"]["global_bpm"]
    n = len(bm["beats"])
    ok = abs(bpm - 120.0) <= 2.0 and n >= 15
    print(
        f"selftest: global_bpm={bpm} beats={n} downbeats={len(bm['downbeats_sec'])} "
        f"octave_flag={bm['analysis']['cross_check']['octave_flag']}"
    )
    print("selftest:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="audio -> beat-map JSON (Beat This! + librosa)")
    ap.add_argument("audio", nargs="?", help="path to an audio file (wav/mp3/flac/...)")
    ap.add_argument("-o", "--out", help="write JSON here (default: stdout)")
    ap.add_argument(
        "--bpm-hint",
        type=float,
        default=None,
        help="known/approx BPM, recorded for reference (octave sanity)",
    )
    ap.add_argument(
        "--dbn",
        action="store_true",
        help="use Beat This!'s DBN postproc (requires madmom — NonCommercial)",
    )
    ap.add_argument(
        "--stamp",
        action="store_true",
        help="embed a UTC creation time (breaks deterministic output)",
    )
    ap.add_argument(
        "--selftest", action="store_true", help="run the synthetic click-track self-test and exit"
    )
    args = ap.parse_args(argv)

    if args.selftest:
        return _selftest()
    if not args.audio:
        ap.error("provide an audio path, or --selftest")

    stamp = None
    if args.stamp:
        import datetime

        stamp = datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds")

    signal, sr = load_audio(args.audio)
    beatmap = analyze(
        signal,
        sr,
        audio_path=args.audio,
        bpm_hint=args.bpm_hint,
        dbn=args.dbn,
        stamp=stamp,
    )
    text = json.dumps(beatmap, indent=2)
    if args.out:
        with open(args.out, "w") as f:
            f.write(text + "\n")
        b = beatmap["beats"]
        print(
            f"wrote {args.out}: {len(b)} beats, {len(beatmap['downbeats_sec'])} downbeats, "
            f"{beatmap['tempo']['global_bpm']} BPM "
            f"(variable={beatmap['tempo']['is_variable']}), "
            f"octave={beatmap['analysis']['cross_check']['octave_flag']}",
            file=sys.stderr,
        )
    else:
        print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
