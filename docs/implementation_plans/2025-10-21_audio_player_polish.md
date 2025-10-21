# Audio Playback Card — Premium UX

## Summary

- Replace the current barebones playback strip with a visually rich, responsive audio card.
- Keep the existing play/pause/speed controls but redesign their layout, spacing, and states for
  clarity.
- Remove the third-party slider; build a custom progress + buffer bar that adapts to tight widths
  and dark theme.

## Goals

- Deliver a card that reads unmistakably as “audio player” at a glance, on mobile and desktop.
- Ensure the layout is resilient below 320 px width and scales up elegantly.
- Provide tactile hover/focus/press feedback, accessible semantics, and smooth micro-interactions.
- Preserve current playback functionality (Cubit + media_kit), zero analyzer warnings, all tests
  passing.

## Non-Goals

- No changes to playback business logic, cubit APIs, or audio file handling.
- No overhaul of transcript toggles or recording widgets outside this player.
- No localization text changes beyond new strings for tooltips/labels if needed.

## Findings

- `lib/features/speech/ui/widgets/audio_player.dart`: hard-coded `Row` with minimal padding; relies
  on a default `Slider` with poor theming and overflow on narrow layouts.
- `AudioPlayerState` already tracks `progress`, `totalDuration`, `speed`, and button
  status—sufficient for richer UI.
- `AudioPlayerCubit` exposes play/pause/stop/speed adjustments; we can reuse actions without
  modification.
- Tests (`test/features/speech/ui/widgets/audio_player_test.dart` ?) absent; need coverage for
  redesigned widget.
- Feature README (`features/speech/README.md`) does not describe the audio playback UI.

## Design Overview

- Wrap controls in a `ModernBaseCard`-style container with glassmorphism (blurred backdrop), subtle
  gradient stroke, and consistent padding.
- Layout:
  - Left: Circular play/pause button with progress ring.
  - Center: Track title/timecodes stacked vertically; progress bar beneath with custom painter
    indicating buffer + played segments.
  - Right: Secondary actions (stop, speed selector) in a pill with dividers.
- Use `LayoutBuilder` to switch between horizontal (>=360 px) and vertical compact mode (<360 px).
- Build progress indicator with `CustomPaint` + `GestureDetector` for scrubbing, fallback to
  `LinearProgressIndicator` when disabled.
- Animate state transitions via `AnimatedSwitcher` and `TweenAnimationBuilder`.
- Apply focusable semantics for keyboard navigation; include tooltip text from `AppLocalizations`.

## Phases and Changes

### Phase 1 — Audit & Foundation (P0)

- Document intended design tokens (spacing, typography, color references) in feature README.
- Add TODO flag in issue tracker if extra design assets needed.

### Phase 2 — Component Structure (P0)

- Refactor `AudioPlayerWidget` into composable private widgets:
  - `_AudioPlayerCardShell`
  - `_PrimaryControls` (play/pause)
  - `_ProgressBar` (custom painter + gestures)
  - `_SecondaryControls` (stop, speed, transcripts toggle)
- Ensure state is derived solely from `AudioPlayerState`.
- Introduce responsive `Flex` layout with breakpoints and intrinsic width guards.

### Phase 3 — Visual Styling & Interaction (P0)

- Implement glass card (clip, gradient border, drop shadow) using theme tokens.
- Add glowing focus ring, hover scale, and pressed opacity feedback (desktop/mobile).
- Replace default `Slider` with custom painter progress bar supporting:
  - Buffered vs played segments
  - Scrubbing with `GestureDetector` + `AudioPlayerCubit.seek`
  - Handle keyboard and semantics actions.
- Integrate subtle animations (progress smoothing, button state transitions).

### Phase 4 — Compact Mode Handling (P0)

- Add layout switch for narrow widths: vertical stack with controls on top, progress below.
- Use `MediaQuery.sizeOf(context)` guard to avoid overflow warnings.
- Write constraint tests to ensure rendering down to 280 px without overflow.

### Phase 5 — Accessibility & Localization (P0/P1)

- Provide descriptive `Semantics` labels for controls (play, pause, scrub, speed).
- Add localized tooltip strings if missing (`messages.audioPlayerPlayTooltip`, etc.).
- Verify contrast ratios meet WCAG in dark/light themes.

### Phase 6 — Tests & Docs (P0)

- Add widget tests:
  - Layout smoke test for wide and narrow constraints.
  - Interaction tests for play/pause taps, scrubbing updates, speed menu.
  - Semantics test ensuring labels/states exposed.
- Update `features/speech/README.md` with new UI description and screenshot placeholder.
- Append changelog entry noting audio player redesign.

## Data Flow

- `AudioPlayerWidget` continues to consume `AudioPlayerCubit` via `BlocBuilder`.
- Gesture handlers call existing cubit methods (`play`, `pause`, `seek`, `setSpeed`).
- State drives custom painter progress and button visuals; no new providers introduced.

## Files to Modify / Add

- Modify
  - `lib/features/speech/ui/widgets/audio_player.dart`
  - `lib/features/speech/ui/widgets/audio_player_controls.dart` (if extracted or new utility)
  - `lib/features/speech/theme/audio_player_theme.dart` (new theme helpers if needed)
  - `features/speech/README.md`
  - `CHANGELOG.md`
  - `l10n/*.arb` (new tooltip strings, run `make l10n` as required)
- Add
  - `test/features/speech/ui/widgets/audio_player_widget_test.dart` (or expand existing)
  - Optional `lib/features/speech/ui/widgets/progress/audio_progress_bar.dart` for modularity.
  - Golden assets under `test/goldens/audio_player/` if approved.

## Tests

- Widget tests covering play/pause transitions, scrubbing, and compact layout.
- Existing speech test suite (`make test` subset) must remain green.

## Performance

- Ensure custom painter renders in O(1); use `RepaintBoundary` around progress bar.
- Avoid rebuilding on every progress tick by leveraging `AnimatedBuilder` with `ValueListenable` or
  throttled `setState`.

## Edge Cases & Handling

- Disabled state when audio fails: show neutral styling with retry message.
- Long durations/timecodes: truncate with ellipsis, ensure digits fit in compact mode.
- Speed menu on small screens: fallback to modal bottom sheet if overflow detected.

## Rollout Plan

1. Implement structural refactor (Phase 2) behind existing visual style to verify functionality.
2. Layer in visual styling + custom progress (Phase 3) and compact mode (Phase 4).
3. Add accessibility + localization adjustments (Phase 5).
4. Land tests, docs, changelog (Phase 6).
5. Run `dart-mcp.analyze_files`, `dart-mcp.dart_format`, targeted widget tests, then full
   `make test`.

## Open Questions

- Do we want waveform visualization (requires audio data) or keep simple bar? => yes but only in 
  a follow-up PR, not right away.
- Should speed control remain an icon button or become a segmented control? => I'm open to what 
  is best practice.

## Detailed Task Breakdown

- **Phase 1**
  - Audit current theme tokens; document gaps in `features/speech/README.md`.
  - Capture before/after screenshots for release notes (placeholder acceptable).
- **Phase 2**
  - Extract shell widgets and ensure they accept fully controlled state from cubit.
  - Introduce responsive `Flex` layout and breakpoint helper.
  - Add TODOs for transitions until Phase 3 rounds out interactions.
- **Phase 3**
  - Implement glass treatment using shared theme mixins (`ModernBaseCard`, blur shader mask).
  - Replace slider with `_AudioProgressBar` custom painter and semantics actions.
  - Wire `GestureDetector` callbacks to `AudioPlayerCubit.seek` with throttling utility.
- **Phase 4**
  - Create compact-mode layout tests to enforce max 2 lines of text in narrow widths.
  - Gate icon-label ordering to ensure accessibility in RTL locales.
- **Phase 5**
  - Add localized tooltips (`audioPlayerPlayTooltip`, `audioPlayerSpeedTooltip`, etc.) and update
    ARB files.
  - Run accessibility audit checklist: screen reader labels, focus order, contrast logs.
- **Phase 6**
  - Add golden or screenshot tests if design sign-off requires.
  - Update changelog and README; verify doc build passes (if applicable).

## QA & Testing Strategy

- Widget tests cover:
  - Wide layout renders without overflow and exposes expected semantics.
  - Compact layout gracefully reflows controls, progress bar remains interactive.
  - Play/pause toggles dispatch correct cubit calls; speed selector updates state.
- Integration tests (optional) to ensure playback flow works end-to-end on at least one platform.
- Manual QA checklist:
  - Compare design tokens in light/dark themes (desktop + mobile breakpoints).
  - Screen reader pass (VoiceOver) confirming announcements for primary controls.
  - Keyboard navigation: tab order, space/enter triggers, arrow key scrubbing.
  - Scrub gesture accuracy verified at 10%, 50%, 90% durations.
  - Regression pass for transcript toggles to ensure no overlapping focus states.


## Risks & Mitigations

- **Custom painter complexity** — risk of visual glitches when progress updates rapidly; mitigate by
  throttling updates and writing golden tests at various progress values.
- **Accessibility regressions** — ensure semantics tree snapshot is reviewed before launch; add
  widget test verifying `SemanticsTester` output.
- **Performance on low-end devices** — guard animations with inexpensive tweens and cache gradients.
- **Design drift** — weekly design check-ins; store references in repo to avoid ambiguity.
- **Localization overflow** — proactively test long translations (e.g., German) in compact layout
  via test fixtures.

## Definition of Done

- All phases merged with zero analyzer warnings and `dart format` compliant code.
- Widget tests, analyzer, and targeted integration tests (if added) pass in CI and locally.
- Feature README updated with visuals + guidance; changelog entry merged.
- Localization artifacts generated and committed; `missing_translations.txt` clean.
- Design, accessibility, and product stakeholders sign off on staging build.
- Monitoring hooks configured and documented for post-release follow-up.

## Follow-Up Opportunities

- Waveform visualization prototype tracked as a separate initiative.
- Evaluate segmented speed control UI after gathering analytics on usage of existing menu.
- Consider sharing glass card primitives across other media widgets for consistency.
