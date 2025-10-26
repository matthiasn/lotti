# macOS Auto Gain and Post‑Record Normalization Plan

## Summary

## Status Update (2025‑10‑26)

- Added baseline recording metrics logging (avg RMS dBFS, peak dBFS) at stop(), using the existing VU buffer.
- Introduced `normalizeAudioOnDesktopFlag` config flag (seeded, default off) for staged rollout.
- Added `ffmpeg_kit_flutter_min_gpl` dependency in preparation for the normalization spike.
- Analyzer is clean; targeted speech tests pass via MCP.
- Next: scaffold `AudioNormalizationService` behind the flag and run ffmpeg‑kit spike (LUFS/true‑peak, dynaudnorm timing) to finalize thresholds.

- Mobile recordings show healthy levels and visually pleasing waveforms; macOS desktop recordings are significantly quieter despite loud speech and successful transcription.
- We already request auto gain via `record`’s `RecordConfig(autoGain: true)`, but desktop macOS likely doesn’t apply AGC the same way as iOS/Android.
- Plan: 1) verify and, if possible, fix gain at record time on macOS; 2) add a conservative, fast post‑record normalization step (before sync) as a reliable fallback so entries arrive on other devices with consistent loudness and waveforms.

## Goals

- Consistent perceived loudness and waveform amplitude across platforms for new recordings.
- Prefer fixing at capture time on macOS; fall back to deterministic post‑processing if capture‑time AGC is unavailable.
- Keep analyzer at zero warnings and tests green; follow repository process in `AGENTS.md`.

## Non‑Goals

- No UI redesign of the recorder or player in this pass.
- No live, in‑stream dynamic compression/limiting in the VU meter path.
- No retroactive normalization of already‑synced historical audio (can be a later migration).

## Findings (current code)

- We use `record` 6.1.2 with `RecordConfig(sampleRate: 48000, autoGain: true)` in `lib/features/speech/repository/audio_recorder_repository.dart`.
- macOS entitlements and microphone usage strings are present (`macos/Runner/*.entitlements`, `macos/Runner/Info.plist`).
- Waveforms are generated on playback via `just_waveform` and rendered by `AudioWaveformScrubber` (already normalized per UI width). Quiet source files still look quiet.
- No ffmpeg dependency present; no existing normalization pipeline.

## Investigation Tasks

1. Verify `record_macos` AGC behavior
   - Inspect the plugin’s macOS code for support of `autoGain`, `noiseSuppression`, and `echoCancellation`.
   - Determine whether it uses Apple’s Voice Processing I/O (AGC/NS/EC) or plain capture.
   - If `autoGain` is ignored on macOS, open an upstream issue and offer a patch adding a `voiceProcessing` option.
2. Measure macOS capture levels in practice
   - Log average RMS/dBFS during a 10–30s capture to quantify typical headroom.
   - Compare with mobile captures to set a sensible normalization target.
3. Evaluate post‑processing options
   - Prefer `ffmpeg-kit-flutter` (min_gpl variant) for cross‑platform availability and simple filter graphs.
   - Shortlist filters: `loudnorm` (2‑pass EBU R128) or `dynaudnorm` (single‑pass). Favor `dynaudnorm` for speed on short clips; reserve `loudnorm` for longer clips if needed.

## Baseline & Impact

- Measurement plan (Phase 0):
  - Capture 10–30 s speech samples on macOS desktop and mobile under similar conditions.
  - Collect: integrated LUFS, short‑term LUFS, RMS dBFS, true peak dBTP, and average VU from the in‑app buffer.
  - Record microphone type and input gain settings.
- Target baseline to document:
  - Mobile typical: RMS around −20 dBFS to −18 dBFS; LUFS around −18 to −16.
  - macOS suspected: RMS significantly lower (quantify delta in dB via Phase 0; do not assume values).
- User impact:
  - Add log counters for “quiet recording” sessions (avg RMS below threshold) and correlate with support feedback.
  - Track frequency per device to prioritize fixes.

## Design Overview

1. Record‑time improvements (Path A)
   - Attempt to enable voice processing on macOS:
     - If the plugin supports, set `noiseSuppression`/`echoCancellation` and verify effect.
     - If not exposed, propose PR to `record_macos` to enable Apple’s Voice Processing I/O node when `autoGain: true` (keeping current behavior on other platforms).
   - Keep `sampleRate: 48000`, mono, AAC.

2. Post‑record normalization (Path B)
   - Introduce `AudioNormalizationService`:
     - `Future<bool> maybeNormalize({required AudioNote note, required double avgDbfs})`.
     - macOS only; runs immediately after `stopRecording()` and before creating the journal entry.
     - Skip when `avgDbfs` is already near target (e.g., > −18 dBFS RMS).
   - Filter strategy:
     - Default: `dynaudnorm=f=150:g=7:p=0.9:m=7:s=10:r=0.5` with `-af volume=-1dBTP` limiter guard.
     - Optional 2‑pass `loudnorm` for > 3 min clips targeting −16 LUFS, −1 dBTP (guarded behind a flag initially).
   - Replace source file in place to keep metadata paths stable; preserve `.m4a` container with AAC.
   - Run work in an isolate; gate sync until normalization completes.

4. Feature Flags & Rollback
   - Add `normalizeAudioOnDesktop` flag (default: enabled on macOS only; disabled elsewhere).
   - Add hidden runtime override (developer settings) and env/read preference for emergency kill‑switch.
   - Rollback: if crash rate or audio quality regressions exceed thresholds, disable the flag and ship hotfix; fallback to Path A only.

3. Wiring
   - Hook into `AudioRecorderController.stop()`:
     - Compute/retain average RMS over the session (we already buffer dBFS samples for VU).
     - Call `AudioNormalizationService.maybeNormalize(...)` on macOS.
     - Proceed with `SpeechRepository.createAudioEntry(...)` after normalization.
   - Add a user‑hidden config or developer flag to disable normalization if needed.

4. User Experience (UX) During Normalization
   - For clips projected to take > 1.5 s, show a subtle non‑blocking indicator: "Normalizing audio…" with a spinner.
   - When ffmpeg‑kit progress callbacks are available, display percent progress; otherwise show indeterminate.
   - Keep the UI responsive but defer sync until completion; if normalized under 1.5 s, no UI needed.
   - On failure, proceed without blocking and add a toast: "Audio saved without normalization" (debug builds only).

## Code Changes

- New: `lib/features/speech/services/audio_normalization_service.dart` (platform‑aware; ffmpeg wrapper injected via GetIt).
- Update: `lib/features/speech/state/recorder_controller.dart` to capture avg RMS and call normalization before creating entries.
- Update: `lib/features/speech/repository/audio_recorder_repository.dart` to allow passing encoder/bitrate (no functional change initially).
- Optional: Settings flag (developer section) to toggle normalization on desktop.

## Performance & Size Budgets

- Normalization latency targets (desktop release builds):
  - 10 s clip: ≤ 500 ms (Apple Silicon), ≤ 900 ms (Intel).
  - 60 s clip: ≤ 1.5 s (Apple Silicon), ≤ 2.5 s (Intel).
  - 3 min clip: ≤ 4.0 s (Apple Silicon), ≤ 7.0 s (Intel).
- CPU/energy: keep average process CPU ≤ 150% during normalization burst; no background normalization while on battery if power saver enabled (future enhancement).
- Bundle size budget: ffmpeg‑kit min‑gpl adds significant size; budget increase ≤ 40 MB on macOS. Verify pre/post bundle sizes in CI. If exceeded, revisit approach or make normalization optional download.

## Testing Strategy

- Unit (no ffmpeg dependency):
  - `AudioNormalizationService` decision logic (when to normalize, thresholds, platform gating) using a mock runner.
  - `AudioRecorderController.stop()` flow calls normalization on macOS when avgDbfs below threshold and skips otherwise.
- Integration (platform/macOS only, opt‑in):
  - Golden assertion on file peak/RMS before/after normalization using a short fixture.
- Existing analyzer/test discipline:
  - Use MCP: `dart-mcp.analyze_files` and targeted tests via `dart-mcp.run_tests` for the speech suite; keep zero warnings (see `AGENTS.md`).

### Expanded Test Scenarios

- Edge cases:
  - Silent input (all zeros): ensure no gain pumping; skip normalization or keep no‑op result.
  - Clipped input (peaks at 0 dBFS): limiter holds true peak ≤ −1 dBTP; no additional distortion.
  - Very short clips (< 1 s): skip normalization (not worth the cost); UI remains consistent.
  - Very long clips (> 30 min): skip or degrade to lighter filter; ensure sync is not blocked excessively.
- Cross‑device sync:
  - Ensure normalization completes prior to persistence/sync; receiving devices should see consistent waveforms without recomputation glitches.
- Battery/CPU sanity:
  - Manual QA on laptops: record CPU time and approximate energy impact; ensure normalization is bounded by budget.

### Test File Layout

- `test/features/speech/services/audio_normalization_service_test.dart`
- `test/features/speech/state/recorder_controller_normalization_test.dart`
- Golden (optional): `test/features/speech/ui/widgets/audio_waveform_scrubber_golden_test.dart` comparing bar height distributions before/after normalization for a fixture.

## Rollout & Telemetry

- Ship with normalization enabled on macOS only; log normalization decisions and durations.
- If Path A (record‑time fix) lands upstream, prefer it and progressively disable post‑processing.

- Telemetry fields (LoggingService):
  - `norm_decision`: { enabled, reason, avgRmsDbfs, durationSec, filter, params }
  - `levels_before`: { lufsI, lufsS, rmsDbfs, truePeakDbtp }
  - `levels_after`: { lufsI, rmsDbfs, truePeakDbtp }
  - `perf`: { execMs, cpuAvgPct, fileSec, fileBytes, device }
  - Aggregate dashboards: normalization rate, median exec time, failure rate.
  - Progressive rollout: start disabled in production, enable for internal/beta builds first; then staged release with the flag on for macOS only. Maintain a kill‑switch for immediate rollback.

### LoggingService Integration Details

- Domain: `audio_normalization`.
- Subdomains: `start`, `progress`, `complete`, `decision`, `skipped`, `error`.
- Skipped reasons to log: `duration_short`, `rms_high_enough`, `duration_long`, `file_too_large`, `snr_low`, `platform_disabled`, `flag_disabled`.

## Risks & Mitigations

- FFmpeg binary size and licensing: use `ffmpeg-kit-flutter-min-gpl`; restrict to desktop; document in changelog.
- Performance on long clips: run in isolate; consider duration cutoff (> 10 min: skip or reduce quality).
- Over‑amplification/noise floor: apply conservative targets and limiter; skip when input already loud enough.
- Upstream plugin changes delayed: fallback normalization provides immediate user benefit.

- Noise floor amplification / SNR degradation:
  - Measure approximate SNR (speech vs silence windows) and skip or clamp gain when SNR < 10 dB.
  - Cap max gain and prefer dynamic normalization windows (dynaudnorm) to avoid raising background noise excessively.

## Success Metrics & Acceptance Criteria

- Loudness (post‑record on macOS):
  - Integrated LUFS: −18 ± 2 LU; True Peak ≤ −1.0 dBTP.
  - RMS dBFS: −20 ± 3 dB for typical speech segments.
- Skip thresholds:
  - Do not normalize if avg RMS ≥ −20 dBFS (already loud enough) or duration < 1 s.
  - Skip for duration > 30 min by default (configurable), or file > 200 MB.
- Visual waveform parity:
  - Median normalized bar height for macOS within 0.40–0.70 of mobile for comparable content (same renderer inputs).
- Reliability:
  - Normalization failure rate < 0.5%; on failure, proceed without blocking entry creation/sync.
- Performance:
  - Latency budgets met (see above) on Apple Silicon and Intel test devices.

## Phases & Tasks

### Phase 0 — Research & Spike
- Read `record_macos` implementation for `autoGain` handling; confirm current behavior.
- Create a local spike to run `ffmpeg-kit` on a sample `.m4a` and compare levels.
 - Collect baseline metrics (RMS/LUFS/true peak) on mobile vs macOS; document results.

### Phase 1 — Record‑time Improvements (if feasible)
- Expose/apply voice processing flags on macOS via plugin config or PR.
- Verify improved captured levels; log avg RMS/dBFS before/after.

### Phase 2 — Post‑record Normalization
- Add `ffmpeg-kit-flutter-min-gpl` (desktop‑only if possible) and `AudioNormalizationService`.
- Wire into `AudioRecorderController.stop()`; block sync until done.
- Add decision thresholds and logging.

### Phase 3 — Tests, Docs, and QA
- Unit tests for decision logic and controller wiring.
- Optional macOS integration test for normalization.
- Update feature README(s) and CHANGELOG.
 - Add docs on flags, thresholds, and known tradeoffs (noise floor, size impact).

### Phase 4 — Validate & Iterate
- Compare new macOS recordings vs mobile; tweak thresholds/filters as needed.
- If upstream AGC fix lands, reduce reliance on post‑processing.

## Timeline & Effort (estimates)

- Phase 0: 2 days — investigation, baseline, spike ffmpeg normalization.
- Phase 1: 3–5 days — plugin options/PR (if feasible), local verification.
- Phase 2: 2–3 days — service implementation, wiring, isolate, flags.
- Phase 3: 1–2 days — tests, docs, analyzer cleanups.
- Phase 4: 1–2 days — validation, tuning, release prep.

## Alternatives Considered

- Native Voice Processing I/O (Core Audio): robust AGC/NS/EC at capture time; requires plugin changes (AudioUnit) rather than AVAudioRecorder; higher complexity but ideal (Path A).
- speexdsp AGC (FFI): lightweight AGC; adds native build and maintenance overhead; not preferred initially.
- sox or system ffmpeg: external runtime dependency; undesirable for distribution and sandboxing.
- Switching recording plugin (e.g., flutter_sound): larger migration risk; we already use `record` elsewhere.

## Upstream Contribution Strategy

- Open issue in `record_macos` with baseline measurements and proposal to expose a `voiceProcessing` toggle or infer it from `autoGain: true` on desktop.
- Provide PR with:
  - Config plumbing (`RecordConfig.voiceProcessing`), macOS implementation using Voice Processing I/O.
  - Backward compatibility (no change unless enabled).
  - Smoke tests and docs.
- If PR is not accepted: maintain local fallback (Path B) and re‑evaluate later; avoid long‑term fork unless necessary.

## Process Alignment (AGENTS.md)

- Use MCP tools for analyze/tests/formatting; keep analyzer at zero warnings.
- Don’t edit generated files; add tests alongside new code; one test file per implementation file.
- Update docs/READMEs and changelog with any new flags/flows.
- Prefer targeted tests first; then broader runs; format with `dart-mcp.dart_format`.

## Compatibility Matrix

- Platforms: macOS only for normalization; iOS/Android unchanged.
- Architectures: Apple Silicon (arm64) and Intel (x86_64) supported by ffmpeg‑kit min‑gpl.
- Minimum OS: follow repo’s `MACOSX_DEPLOYMENT_TARGET`; validate on 12+.
- Media: `.m4a` AAC mono at 48 kHz as produced by current recorder.

## References

- Existing implementation plans: 2025‑10‑23 and 2025‑10‑24 for structure rigor.
- `record` (llfbandit) 6.1.2 — verify macOS AGC behavior and flags.
- Apple Voice Processing I/O (AGC/NS/EC) background for potential plugin PR.
- `AGENTS.md` — repository collaboration/process guidance.
