---
name: dance-lipsync
description: Generate real mouth-shape lip-sync cues for the character dance demo from a song's vocal stem, using Rhubarb Lip Sync via tools/dance_audio/lipsync.py. Use when the user wants believable lip movement (not one-vowel-per-word), to "lip sync the cats", produce a mouth-cue track, build/run Rhubarb, or improve how the singers' mouths follow the vocals.
argument-hint: "<path to vocals-only stem> [+ lyrics file]"
---

# Lip-sync cues from the vocal audio (Rhubarb)

Offline, authoring-time pipeline that turns a **vocals-only stem** into a timeline
of **mouth shapes** the dance demo draws. Rhubarb analyses the audio directly, so
the mouths follow the actual phonemes (closures, F/V, rounding) instead of the
crude per-word vowel guess. Deterministic JSON; nothing runs in the Flutter app.

Tool: `tools/dance_audio/lipsync.py`. Engine: **Rhubarb Lip Sync 1.13.0**
(permissive license). Demo it feeds:
`lib/features/character/demo/character_dance_to_track_demo.dart`.

## The mouth shapes (Rhubarb's alphabet)

Rhubarb emits Preston-Blair-style shapes; the cue JSON carries the letters
verbatim and the Dart renderer maps each to a drawn mouth:

| Shape | Mouth | Triggered by |
| --- | --- | --- |
| `A` | closed | rest, M B P |
| `B` | slightly open, teeth near-closed | many consonants, "ee" |
| `C` | open | EH, AE |
| `D` | wide open | AA |
| `E` | slightly rounded | AO, ER |
| `F` | puckered | UW, OW, W |
| `G` | upper teeth on lower lip | F, V |
| `H` | tongue up | L |
| `X` | idle / rest | silence |

## Setup (once) — a native binary, no Docker in the tool

Rhubarb ships **x86-64 only**. On this **ARM64** box we build it natively from
source; every dependency is vendored **except Boost headers**. The built binary
plus the official release's `res/sphinx` model dir live in
`tools/dance_audio/vendor/rhubarb/` (the whole `vendor/` tree is gitignored —
it's a large third-party build, never commit it).

```bash
cd tools/dance_audio
# 1. Boost headers (the only external dependency)
sudo apt-get install -y libboost-dev
# 2. Source (vendored deps: pocketsphinx, sphinxbase, flite, webrtc, ogg/vorbis, fmt, gsl…)
git clone --depth 1 --branch v1.13.0 https://github.com/DanielSWolf/rhubarb-lip-sync.git vendor/rhubarb-src
cmake -S vendor/rhubarb-src -B vendor/rhubarb-src/build -DCMAKE_BUILD_TYPE=Release
cmake --build vendor/rhubarb-src/build -j"$(nproc)"   # the optional rhubarbForSpine extra fails — ignore it; the `rhubarb` target builds
# 3. res/ model data from the official release (architecture-independent), + native binary beside it
curl -sL -o /tmp/rh.zip https://github.com/DanielSWolf/rhubarb-lip-sync/releases/download/v1.13.0/Rhubarb-Lip-Sync-1.13.0-Linux.zip
mkdir -p vendor/rhubarb && unzip -q -o /tmp/rh.zip -d /tmp/rh && cp -r /tmp/rh/Rhubarb-Lip-Sync-*/res vendor/rhubarb/
cp vendor/rhubarb-src/build/rhubarb/rhubarb vendor/rhubarb/rhubarb
vendor/rhubarb/rhubarb --version   # -> Rhubarb Lip Sync version 1.13.0
```

`res/sphinx` **must** sit next to the binary — both recognizers fail without it
("Error creating speech decoder").

**Other architectures / can't build:** the official x86-64 binary runs as-is on
x86-64 Linux, or under emulation elsewhere
(`docker run --privileged --rm tonistiigi/binfmt --install amd64`, then run the
binary in an `--platform linux/amd64` container). Use that only as a fallback —
the native binary is the clean path here. Set `$RHUBARB_BIN` or `--rhubarb` to
point `lipsync.py` at whichever binary you use.

## Run it

`lipsync.py` decodes the audio to 16 kHz mono, runs Rhubarb, and writes the cue
JSON. Use the **Demucs vocal stem** (see the `dance-track-prep` skill), not the
full mix — Rhubarb keys off the voice.

```bash
. .venv-asr/bin/activate   # provides librosa + soundfile (lipsync.py needs them)
# Whole stem, phonetic recognizer (default; best for SUNG vocals)
python lipsync.py out/sep/htdemucs/song/vocals.wav -o out/song.cues.json
# A mid-song window
python lipsync.py out/sep/htdemucs/song/vocals.wav --start 72 --duration 30 -o out/song.cues.json
# English speech (e.g. spoken intro): pocketSphinx + the lyrics as a dialog hint
python lipsync.py out/sep/htdemucs/song/vocals.wav -r pocketSphinx --dialog out/song.lyrics.txt -o out/song.cues.json
```

Recognizers: **`phonetic`** (default) is language-independent and recognises
sounds — the right call for singing. **`pocketSphinx`** is English-speech only;
pair it with `--dialog <lyrics file>` (section headers and `(...)` are stripped to
plain words) when the vocal is clear English.

Flags: `-o/--out`, `-r/--recognizer`, `--dialog`, `--start`, `--duration`,
`--stamp` (embed a UTC time; omit for byte-identical reruns), `--rhubarb` (binary
path). Output is deterministic without `--stamp`.

## Cue schema (what the demo reads)

```json
{
  "schema_version": "1.0",
  "audio":   { "path": "...", "duration_sec": 30.0, "segment_start_sec": 72.0 },
  "lipsync": { "engine": "rhubarb", "recognizer": "phonetic",
               "shapes": "ABCDEFGHX", "created_utc": null },
  "cues":    [ { "start_sec": 0.0, "end_sec": 0.19, "shape": "B" }, ... ]
}
```

Cue times are relative to the decoded window; the absolute offset is
`audio.segment_start_sec`.

## How it composes with the rest

Rhubarb says **how the mouth moves**, not **who is singing**. Lead-vs-background
routing stays exactly where it is — the **lyric word tags** (`(...)` ad-libs +
sections from `transcribe.py --lyrics`). The demo plays the Rhubarb shapes,
**gated** by each voice's active word-windows: the frontman shows them on lead
words, the backups on ad-libs / group-hook sections, otherwise the mouth rests
closed. One stem → one cue track; truly independent per-singer mouths would need
lead-vs-backing-vocal audio separation, which Demucs does not do.

## IP / determinism rules

- **Never commit** audio, vocal stems, lyrics, or the derived cue/word JSON, nor
  the `vendor/` Rhubarb build — all are copyrighted, derived, or large
  third-party. Keep artifacts under `out/` (gitignored).
- Cue JSON is deterministic without `--stamp`, so reruns diff cleanly.

## Reuse for a new song — checklist

1. Have the **vocal stem** (`demucs --two-stems vocals`; see `dance-track-prep`).
2. `python lipsync.py vocals.wav -o out/song.cues.json` (phonetic).
3. Pass the cue JSON to the demo (`--dart-define=DANCE_CUES=/abs/out/song.cues.json`).
4. Routing still comes from the word tags — generate those with
   `transcribe.py --lyrics` if you want lead/background separation.

## See Also

- `choreo-phrase-authoring` for mapping the same song's beat/section structure
  into the body choreography.
- `character-motion-review-panel` for judging whether singing faces and body
  motion read together in rendered frames.
