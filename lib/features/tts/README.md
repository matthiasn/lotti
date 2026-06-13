# Text-to-speech (Supertonic)

On-device text-to-speech that reads a task's AI **TL;DR** aloud, intended to run
the [Supertonic 3](https://huggingface.co/Supertone/supertonic-3) ONNX model
(~99M params, 44.1kHz 16-bit WAV) locally and play the result through the app's
existing `media_kit` stack. No cloud, no API.

The full Dart architecture — voice/model catalogs, the playback state machine,
controllers, the HF model-download repository, the redesigned AI-card playback
control, and the text/tokenizer/WAV engine core — is built and tested behind a
`TtsEngine` interface. The **concrete ONNX engine** (via `flutter_onnxruntime`)
is **not yet wired**: adding that dependency broke the macOS CocoaPods build (it
pulls statically-linked onnxruntime under `use_frameworks!`), so it was reverted
and left as a deliberate native-integration step (see Remaining work). Until
then `ttsEngine` returns an unavailable fallback, so the playback control is
hidden. This feature **replaces** the previous MLX/Qwen3-TTS "speak summary"
path and is gated behind the `enable_ai_summary_tts` config flag.

## Architecture

```
features/tts/
  engine/                      pure, ONNX-independent core (no Flutter deps beyond services)
    text_preprocessing.dart    NFKD/Hangul/Latin normalization + language tags
    text_chunker.dart          sentence-aware chunking (KO/JA-aware max length)
    wav_writer.dart            encodeWavBytes (16-bit mono PCM) + file writer
    unicode_processor.dart     code-point -> token-id tokenizer + padding mask
    tts_engine.dart            TtsEngine interface (synthesize boundary)
  model/                       immutable value types + catalogs
    tts_voice.dart             10 Supertonic voices (F1-F5 / M1-M5), default female
    tts_model_option.dart      model catalog (Supertone/supertonic-3)
    tts_playback_state.dart    utterance state machine + progress
    tts_settings.dart          persisted voice/model/speed prefs
  state/                       Riverpod controllers + IO boundaries
    tts_settings_controller.dart   persists prefs via SettingsDb
    tts_audio_player.dart          TtsAudioPlayer interface + media_kit impl
    tts_model_repository.dart      first-run Hugging Face download boundary
    tts_engine_provider.dart       engine provider (+ Unavailable fallback)
    tts_playback_controller.dart   orchestrates ensure-model -> synthesize -> play
  ui/widgets/
    tts_play_button.dart       focal 44pt play/stop control (filled-accent
                               circle; play/stop by shape+label, progress arc)
```

The **AI-card header** integration lives in the agents feature
(`lib/features/agents/ui/ai_summary_card.dart` + `.../ai_summary_card/
tldr_section_part.dart`): the card builds a `TtsPlayButton` from
`TtsPlaybackController` (gated on the `enable_ai_summary_tts` flag + a non-empty
TL;DR + a supported engine), and the agent "Thinking…" pill is visually
distinct from the audio control. This **replaced** the old fire-and-forget MLX
`_speakSummary` path.

## Remaining work (handoff)

- **Settings → Speech page** (voice / model / playback-speed selectors, in the
  entity-definition design language) — `tts_settings_controller` and the voice/
  model catalogs are ready; the page/body widgets + mobile nav + desktop v2
  panel are not yet built.
- **Dead-code cleanup:** `MlxAudioChannel.speakText`/`stopSpeaking` and the
  Qwen3-TTS catalog entry are now unreachable but still co-tested with ASR
  behaviour; remove them in a focused pass that preserves the ASR tests.
- **Native:** ship the voice-style JSONs as bundled assets (declare
  `assets/tts/voice_styles/` in pubspec) and add the iOS deployment-target 16.0
  / static-linkage Podfile config `flutter_onnxruntime` needs.
- **Verify** the exact `Supertone/supertonic-3/onnx/` filenames and run the
  real model end-to-end on macOS before enabling the flag by default; add the
  CHANGELOG entry when the feature becomes user-visible.

The engine is split so the correctness-sensitive, deterministic logic
(normalization, tokenization, WAV encoding) is unit-tested without the native
ONNX runtime, and the playback orchestration is tested against fakes for the
engine, player, and model repository (see `test/features/tts/test_utils.dart`).

The preprocessing/tokenization is ported 1:1 from Supertone's open-source
Flutter example (MIT) because the models were trained against exactly that
normalization — divergence degrades synthesis quality.

## Playback flow

```mermaid
flowchart LR
  A[Play pressed] --> B{model installed?}
  B -- no --> D[download from HF + progress] --> C
  B -- yes --> C[engine.synthesizeToFile<br/>text, voiceId, modelDir, language]
  C --> E[44.1kHz WAV file] --> F[media_kit Player]
  F --> G[playing + position/duration]
  G -->|stop / completes| H[stopped]
```

## Playback state machine

```mermaid
stateDiagram-v2
  [*] --> idle
  idle --> downloadingModel: speak (model missing)
  downloadingModel --> synthesizing: download ok
  downloadingModel --> error: download failed
  idle --> synthesizing: speak (model present)
  synthesizing --> playing: wav ready
  synthesizing --> error: synth failed
  playing --> stopped: stop / complete
  error --> idle
  stopped --> idle
```

## Provisioning

The `onnx/` model files (`duration_predictor`, `text_encoder`,
`vector_estimator`, `vocoder`, plus `tts.json` and `unicode_indexer.json`) are
~hundreds of MB and are **downloaded from Hugging Face on first use**, not
bundled. The tiny voice-style JSONs (`voice_styles/<id>.json`) are bundled
assets. `flutter_onnxruntime` fetches its native runtime at install time and
needs iOS deployment target 16.0.

## Testing

- `test/features/tts/engine/` — normalization, chunking, WAV bytes, tokenizer.
- `test/features/tts/model/` — value types + state machine.
- `test/features/tts/state/` — settings persistence + playback orchestration
  (download/synthesize/play/stop/complete) via injected fakes.
- Async tests use `pumpEventQueue` and microtask yields — no real timers/delays.
