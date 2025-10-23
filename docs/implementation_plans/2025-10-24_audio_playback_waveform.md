# Audio Playback Waveform — just_waveform Integration Plan

## Summary

- The refreshed audio player still relies on a plain progress bar, missing the premium waveform
  detail expected in polished voice journaling experiences.
- We will generate normalized waveform samples with `just_waveform`, cache them per audio asset, and
  swap the progress bar for an adaptive waveform scrubber once data is available.
- Shorter clips (≤3 min) render waveforms immediately; longer audio falls back to the existing bar
  until we confirm decoding costs are acceptable.

## Goals

- Ship a background-friendly waveform service that derives 160–240 samples from `.m4a` sources using
  `just_waveform`.
- Persist normalized amplitudes alongside metadata (duration, sample rate, version) so subsequent
  loads are instant.
- Update `AudioPlayerCubit`/UI to load waveform data on `setAudioNote`, expose status in state, and
  render a seekable waveform once ready.
- Maintain analyzer + targeted widget test cleanliness (`dart-mcp.analyze_files`, focused
  `dart-mcp.run_tests`).

## Non-Goals

- No live waveform during recording (VU meter remains unchanged).
- No streaming/remote decoding; this pass targets locally stored journal audio only.
- No redesign of recorder caching or transcript UI.

## Findings Recap

- Recorder flow already samples dBFS for the VU meter, but playback has no stored amplitudes;
  decoding must happen post-recording.
- `media_kit` exposes position/buffer but not PCM samples, so we need an external decoder.
- `just_waveform` supports `.m4a` and provides batched peaks with an isolate-friendly API, giving us
  a pure Dart solution that works on iOS/Android/macOS/Linux.
- `WaveformBars` from the AI chat experience can be reused with minimal tweaks (supports normalized
  amplitudes, right-aligned layout, semantics-friendly).

## Design Overview

1. **Waveform Service**
  - Introduce `AudioWaveformService` (GetIt singleton) wrapping `just_waveform`.
  - Compute reduced sample sets sized to the target UI width (default 200 buckets), normalize to
    0–1.
  - Serialize to JSON `{ version, durationMs, bucketIntervalMs, samples[] }` under
    `/Documents/audio_waveforms/<audioId>.json`.
2. **Cubit & State**
  - Extend `AudioPlayerState` with `WaveformStatus { loading, ready, unavailable }` and
    `List<double> waveform`.
  - `AudioPlayerCubit.setAudioNote` kicks off waveform load (respecting duration cutoff) and emits
    state transitions.
  - Cache events logged via `LoggingService`; failures fall back without user-facing errors.
3. **UI Rendering**
  - Replace `AudioProgressBar` with `AudioWaveformScrubber` when status is `ready`.
  - Overlay progress/buffer shading atop bars, maintain existing seek semantics (drag/tap →
    `cubit.seek`).
  - Provide skeleton bar while loading; revert to progress bar if unavailable or disabled.
4. **Tooling & Docs**
  - Add unit/widget tests around the service, cubit integration, and waveform scrubber rendering.
  - Update `lib/features/speech/README.md`, changelog, and any feature READMEs touched.
  - Document the package addition and build steps.

## Data Flow & API Changes

- `pubspec.yaml`: add `just_waveform`.
- New service file `lib/features/speech/services/audio_waveform_service.dart` and corresponding
  tests under `test/features/speech/services/`.
- `AudioPlayerState` gains waveform fields; serializer remains unaffected (Freezed).
- UI imports `WaveformBars` (possibly extracted to a shared widget or inline wrapper) and the new
  scrubber widget.

## Implementation Phases

### Phase 0 — Prep & Spike

- Verify `just_waveform` decoding on a macOS clip (60 s `.m4a` fixture) via a quick harness.
- Confirm output sample count, normalization, and isolate behavior; profile runtime.

### Phase 1 — Service & Cache

- Implement `AudioWaveformService`:
  - `Future<AudioWaveformData> load(JournalAudio note, {int targetSamples = 200})`.
  - Handle cache read/write, duration gating, and versioning.
- Unit tests using small fixture audio under `test/test_resources/audio/`.
- Hook into GetIt registration.

### Phase 2 — State & Cubit Wiring

- Extend `AudioPlayerState` + Freezed factory/tests.
- Update `AudioPlayerCubit.setAudioNote` to:
  - Emit `loading`, await service (on isolate where needed), update state.
  - Debounce repeated loads; cancel when switching audio.
- Add logging + error handling; write cubit tests with a mocked service.

### Phase 3 — UI Integration

- Create `AudioWaveformScrubber` widget (progress-overlaid bars with scrubbing).
- Swap into `AudioPlayerWidget` with fallback logic.
- Add accessibility semantics and animations mirroring the current progress bar.
- Widget tests for waveform rendering, progress tint, and seek invocation.

### Phase 4 — Polish & Verification

- Update docs (`lib/features/speech/README.md`, changelog).
- Run `dart-mcp.analyze_files`, targeted widget/service tests, then broader `dart-mcp.run_tests` for
  the speech suite.
- Manual QA: confirm waveform appears for ≤3 min clips, longer clips fall back gracefully, and
  scrubbing works.

## Risks & Mitigations

- **Decoding cost on large files** — guard with a duration cutoff and offload work to an isolate.
- **Cache drift after file replacement** — include file stat hash (size + modified timestamp) in the
  cache key; invalidate on mismatch.
- **Cross-platform decoder quirks** — add integration test fixtures and sanity-check on macOS +
  Android emulator before merging.
- **UI regressions in compact mode** — widget tests at narrow widths; clamp bar count to avoid
  overflow.

## Decisions

- Adopt `just_waveform` for decoding; no native binaries required.
- Limit waveform generation to clips ≤3 min (configurable) in the first release.
- Store cache under documents to align with the existing audio storage hierarchy.
- Reuse the `WaveformBars` painter, wrapping it to add progress overlay rather than rebuilding it.

## Implementation Summary (Target)

- New waveform service providing normalized amplitudes with disk cache + tests.
- `AudioPlayerCubit` loads waveform data, exposes status, and logs failures.
- Playback UI displays a waveform scrubber with progress/buffer overlay and scrubbing parity.
- Analyzer/tests clean; documentation and changelog updated; manual verification complete.

## Remaining Follow-Ups

- Evaluate lifting the duration limit after profiling longer clips.
- Monitor bundle size impact of `just_waveform` in CI.
- Explore reusing cached waveform data for AI exports or future desktop visualizations.
