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
  - Persist the raw waveform data to `/Documents/audio_waveforms/<audioId>_<bucketCount>.json` so
    width-specific caches can be reused locally (these caches remain device-local; no sync).
2. **Cubit & State**
  - Extend `AudioPlayerState` with `WaveformStatus { loading, ready, unavailable }` and
    `List<double> waveform`.
  - `AudioPlayerCubit.setAudioNote` kicks off waveform load immediately when the player card becomes
    active (before playback starts) and emits state transitions.
  - Populate a keep-alive Riverpod cache (15-minute TTL) mapping `<audioId>_<bucketCount>` to the
    processed amplitudes so UI rebuilds avoid disk hits.
  - Cache events logged via `LoggingService`; failures fall back without user-facing errors.
3. **UI Rendering**
  - Replace `AudioProgressBar` with `AudioWaveformScrubber` when status is `ready`.
  - Determine the number of visible bars directly from the available layout width (compact vs.
    standard breakpoints) so narrow cards render fewer, wider bars while wide layouts show more
    detail. Aim for a fixed bar width and gap, and calculate the exact number of buckets 
    required to meet that goal.
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
  - Handle cache read/write, duration gating, and versioning, using `<audioId>_<bucketCount>.json`
    naming so per-density caches are independent.
- Unit tests using small fixture audio under `test/test_resources/audio/`.
- Hook into GetIt registration.

#### Tests

- **AudioPlayerCubit completion handler**
  - Completion event pushes progress to the full duration after the 50 ms delay guard.
  - Completion with a null `audioNote` leaves progress untouched.
  - Constructor wires the completion subscription exactly once.
  - `close()` cancels the completion subscription to avoid leaks.
  - Multiple `play()` calls do not create duplicate completion subscriptions (regression guard).
  - Completion delay is respected before emitting the terminal state.
- **AudioWaveformService cache invalidation**
  - Cache invalidates when file size changes.
  - Cache invalidates when modified timestamp changes.
  - Cache invalidates on version mismatch.
  - Cache invalidates when bucket count differs.
  - Cache invalidates when the relative path changes.
  - Stale cache entries trigger a fresh extraction and reseed metadata.
- **AudioWaveformService cache pruning**
  - Pruning activates when the cache exceeds 1000 entries and only the newest 1000 remain.
  - LRU behavior deletes the oldest files first.
  - Pruning removes the correct number of files and logs the event with counts.
  - Pruning handles I/O errors gracefully without crashing.
  - Pruning is skipped when the cache is under the limit.
  - Pruning handles a missing cache directory without exceptions.

### Phase 2 — State & Cubit Wiring

- Extend `AudioPlayerState` + Freezed factory/tests.
- Update `AudioPlayerCubit.setAudioNote` to:
  - Emit `loading`, await service (on isolate where needed), update state.
  - Debounce repeated loads; cancel when switching audio.
  - Seed the keep-alive Riverpod cache with freshly fetched amplitudes (with 15-minute TTL) so
    on-screen rebuilds stay fast.
- Add logging + error handling; write cubit tests with a mocked service.

#### Tests

- **AudioWaveformProvider**
  - Returns waveform data for valid requests.
  - Creates a keep-alive link and sets the 15-minute timer.
  - Cancels the keep-alive timer after the TTL expires.
  - Cancels the timer on provider disposal.
  - Returns cached results for identical requests.
  - Produces new results when the bucket count changes.
- **AudioWaveformService normalization edge cases**
  - Handles empty waveforms by returning an empty list.
  - Handles single-pixel waveforms.
  - Honors 8-bit (`flags != 0`) waveforms (max amplitude of 128).
  - Avoids downsampling when target buckets exceed pixel count.
  - Supports a single target bucket.
  - Produces accurate RMS/peak blended amplitudes.
  - Produces all-zero output when the waveform is all zeros.
  - Clamps normalized values to the `[0.0, 1.0]` range.
- **AudioWaveformService extraction failures**
  - Returns null and logs when the extractor throws.
  - Throws `StateError` for null waveform responses.
  - Returns null when the audio file is missing.
  - Returns null for unreadable audio files (permission errors).
  - Cleans up temporary files on success.
  - Cleans up temporary files on failure.

### Phase 3 — UI Integration

- Create `AudioWaveformScrubber` widget (progress-overlaid bars with scrubbing).
- Compute bar count at layout time from the available width, resampling cached amplitudes so bar
  spacing stays within design targets across breakpoints.
- Ensure window resize/orientation changes trigger recomputation for every visible waveform (not
  just the active player) via layout listeners and provider updates.
- Swap into `AudioPlayerWidget` with fallback logic.
- Add accessibility semantics and animations mirroring the current progress bar.
- Widget tests for waveform rendering, adaptive bar count, progress tint, and seek invocation.

#### Tests

- **AudioWaveformScrubber interactions**
  - Tap triggers an immediate seek based on tap position.
  - Drag gestures throttle seeks to 60 ms intervals.
  - Drag end emits the pending seek position.
  - Rapid drags remain throttled without flooding `onSeek`.
  - Disabled state prevents seeking.
  - Zero total duration disables interaction.
  - Semantics labels update with progress changes.
  - Empty amplitudes render without errors.
- **AudioWaveformScrubber painter edge cases**
  - Handles empty amplitude lists gracefully.
  - Handles a single amplitude.
  - Clamps progress ratios > 1.0.
  - Clamps buffered ratios > 1.0.
  - Ignores negative progress/buffered inputs.
  - Handles zero-width constraints without painting.
  - Renders under very wide constraints (≥2000 px).
  - `shouldRepaint` respects identity and data changes.
- **AudioWaveformService cache I/O failures**
  - Handles corrupted JSON cache entries by logging and regenerating data.
  - Handles non-JSON cache content.
  - Handles empty cache files.
  - Handles cache files with the wrong structure (e.g., arrays).
  - Handles write failures (disk full or permission issues) by logging.
  - Handles parent directory creation failures gracefully.
- **AudioWaveformService path sanitization**
  - Sanitizes audio IDs with special characters.
  - Handles very long audio IDs (>255 chars) with safe truncation.
  - Handles Unicode audio IDs.
  - Pads single-character IDs with the `00` directory prefix.
  - Creates subdirectories safely for nested cache paths.

### Phase 4 — Polish & Verification

- Update docs (`lib/features/speech/README.md`, changelog).
- Run `dart-mcp.analyze_files`, targeted widget/service tests, then broader `dart-mcp.run_tests` for
  the speech suite.
- Manual QA: confirm waveform appears for ≤3 min clips, longer clips fall back gracefully, and
  scrubbing works.

### Phase 5 — Sync Metadata Persistence

- Persist waveform metadata (bucket duration, amplitudes hash, cache version) alongside the audio
  entry so other devices can reuse precomputed waveforms.
- Extend sync payloads to include the metadata (or flag when waveform data is available), and teach
  the receiving side to hydrate cache files from synced metadata.
- Add migration logic that backfills metadata when local caches exist but the synced entry lacks it.
- Integration tests to confirm multi-device playback reuses shared waveform data without
  recomputation.

## Risks & Mitigations

- **Decoding cost on large files** — guard with a duration cutoff and offload work to an isolate.
- **Cache drift after file replacement** — include file stat hash (size + modified timestamp) in the
  cache key; invalidate on mismatch.
- **Cross-platform decoder quirks** — add integration test fixtures and sanity-check on macOS +
  Android emulator before merging.
- **UI regressions in compact mode** — widget tests at narrow widths; adaptive bar counts clamp
  results to avoid overdraw or sub-pixel bars.

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
- Scope Phase 5 sync metadata work: decide whether metadata rides along journal payloads or via a
  dedicated attachment channel, and document storage limits per platform.
- Schedule nice-to-have coverage: bucket duration calculations, `AudioWaveformRequest` equality,
  and waveform integration states in `AudioPlayerWidget`.
