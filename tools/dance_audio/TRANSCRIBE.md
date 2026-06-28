# Word-level transcription (`transcribe.py`)

Offline, CPU-only **automatic speech recognition with word- and segment-level
timestamps** for the dance pipeline ("rung 5": lyric / vocal alignment). A
choreographer later syncs mouth shapes and lyric accents to the vocals, which
needs each word pinned to the audio — not just the text.

This is authoring-time tooling. It is **not** shipped inside the Flutter app; it
emits a deterministic JSON artifact, just like `analyze.py`'s beat map.

## What it does

```
audio --(librosa, 16 kHz mono)--> signal
      --(faster-whisper)--------> segments (text + coarse times)
      --(wav2vec2 forced align)-> words (fine start/end/score)
      --(assemble)--------------> transcription JSON (schema 1.0)
```

Engine: **[WhisperX](https://github.com/m-bain/whisperX)**. It transcribes with
faster-whisper, then runs wav2vec2 forced alignment to recover per-word
`start` / `end` / `score`. **Diarization (speaker labels) is intentionally
skipped** — it needs pyannote plus a Hugging Face token, and we only want word
timestamps.

### Output schema (1.0)

```json
{
  "schema_version": "1.0",
  "audio": { "path": "...", "duration_sec": 30.0, "segment_start_sec": 72.0 },
  "asr":   { "model": "base", "language": "en",
             "aligner": "WAV2VEC2_ASR_BASE_960H (whisperx@3.x)",
             "created_utc": null },
  "segments": [ { "start_sec": 0.0, "end_sec": 2.41, "text": "..." } ],
  "words":    [ { "word": "moving", "start_sec": 0.12, "end_sec": 0.55,
                  "score": 0.93 } ]
}
```

- Times are relative to the decoded segment (0-based); the absolute offset lives
  in `audio.segment_start_sec`.
- `created_utc` is `null` by default so re-running on the same input yields
  byte-identical JSON (clean diffs). Pass `--stamp` to embed a UTC time.
- An unaligned token has `null` for `start_sec` / `end_sec` / `score`.

## Install

Use a **dedicated** virtualenv (`.venv-asr`) so the heavy WhisperX/torch stack
cannot disturb the beat-map venv (`.venv`). Install CPU torch first, then the
rest. Always `--no-cache-dir` to avoid pip-cache bloat.

```bash
cd tools/dance_audio
python3 -m venv .venv-asr && . .venv-asr/bin/activate
pip install --no-cache-dir torch torchaudio --index-url https://download.pytorch.org/whl/cpu
pip install --no-cache-dir -r requirements-asr.txt
```

The first run downloads the chosen Whisper model (`base` ≈ 145 MB) and the
wav2vec2 aligner (≈ 360 MB) into your Hugging Face / torch cache. Budget a few
GB of free disk for the full stack plus models.

## Usage

```bash
# Whole file to stdout
python transcribe.py path/to/track.mp3

# A 30 s mid-song window to a file, base model
python transcribe.py track.mp3 --start 72 --duration 30 -o out/track.words.json --model base

# Force the language (skip auto-detect) and stamp the output
python transcribe.py track.mp3 --language en --stamp -o out/track.words.json
```

Flags: `-o/--out`, `--model` (tiny/base/small/medium/large-v3; default `base`),
`--language` (default auto-detect), `--lyrics PATH` (force-align known lyrics —
see below), `--start`, `--duration`, `--stamp`.

## Best accuracy: force-align your own lyrics (`--lyrics`)

If you have the song's lyrics, give them to the tool and it **force-aligns** that
exact text to the audio (wav2vec2): the text is correct by construction, so only
the *timing* is estimated — no mishearing, and full coverage. It also tags each
word **lead vs background** so a consumer can move different mouths.

```bash
python transcribe.py out/sep/htdemucs/song/vocals.wav \
  --lyrics out/song.lyrics.txt --language en -o out/song.words.json
```

Lyrics file (`out/song.lyrics.txt`, plain text, kept local / gitignored):
- a line in `[...]` is a **section** header (recorded per word);
- text in `(...)` is tagged **background** (ad-libs / harmonies); the rest is **lead**.

```text
[Chorus]
lead line here (ad-lib)
another lead line
```

Output adds `voice: lead|background` and `section` to each word, and `asr.model`
is `lyrics-aligned`. **Do not fetch lyrics off the web into the project** — that
reproduces copyrighted material; the user supplies the text, the tool only aligns
it. Aligned 237/237 words in ~20 s on the reference track.

Outputs belong under `out/` (gitignored). Original-artwork audio and the
transcription JSON are **never** committed.

## Better captions: separate the vocals first (Demucs)

Whisper's voice-activity stage skips vocals it can't pick out of a dense mix, so
on full-mix Afrobeats it leaves large gaps **even with `large-v3`**. Transcribing
a **vocals-only stem** closes most of them. Separate with **Demucs**, then point
`transcribe.py` at the stem — the stem keeps the original timeline, so the word
times still line up with the track.

```bash
. .venv-asr/bin/activate
pip install --no-cache-dir demucs
# isolate the vocal stem (htdemucs; ~1-2 min CPU for a ~2.5-min track)
python -m demucs --two-stems vocals -o out/sep track.mp3
# transcribe the stem (large-v3 for best coverage)
python transcribe.py out/sep/htdemucs/track/vocals.wav -o out/track.words.json --model large-v3
```

Measured on the Afrobeats reference (full mix → vocal stem, both `large-v3`):
word coverage rose from ~57 s to ~75 s of 144 s and the two ~20 s mid-song gaps
disappeared. Demucs is **MIT**-licensed. Stems live under `out/` (gitignored) —
never commit them.

## License

WhisperX is **BSD-2-Clause** — license-clean for this use. We deliberately avoid
the copyleft alternatives: `whisper-timestamped` (AGPL) and AutoLyrixAlign (GPL).
The skipped diarization path (pyannote) is the only token-gated piece, and we
don't use it.

## Caveat — sung vocals

Whisper and the wav2vec2 aligner are trained on **speech**. On sung lyrics —
sustained vowels, melisma, falsetto, ad-libs, and loud backing instrumentation —
both the transcription text and the word timing degrade. Treat the output as a
strong **first draft to hand-correct**, not ground truth. The biggest win is a
**vocals-only stem** (see *Better captions* above); a larger `--model` helps text
accuracy at the cost of speed.

## Testing

Unit tests are **torch-free**: they monkeypatch `_run_asr` (the only function
that imports whisperx), so `pytest tests/test_transcribe.py` runs with just
numpy + soundfile + librosa — no whisperx or torch needed.
