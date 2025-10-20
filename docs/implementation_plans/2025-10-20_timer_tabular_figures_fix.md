# Timer Text — Tabular Figures, No “Breathing”

## Summary

- Eliminate width “breathing”/jitter in any live timer text across the app.
- Enforce tabular figures (and monospace where needed) so changing digits do not shift layout.
- Audit the running timers in:
  - Journal entry cards rendered within tasks
  - Task header progress (compact header and any variants)
  - Floating/overlay time recording indicator
  - Entry detail footer duration and any list summaries that tick

## Goals

- Zero layout shift as seconds roll over (e.g., 00:41 → 00:48) in every timer surface.
- Consistent, legible timer styling using the shared theme.
- Add tests that catch regressions in width stability.

## Non‑Goals

- Changing the time formatting (HH:MM[:SS]) or localization of time.
- Altering unrelated typography or layout outside the timer labels.

## UX and Interaction

- Timers should feel static in position while values update.
- Keep current sizes; only adjust font features to be tabular figures and monospace where warranted.
- If space is tight (chips/headers), reserve a consistent width to prevent shifts (e.g., via a fixed‑width box sized to the widest representation).

## Architecture

1) Centralize timer text styling
   - Reuse existing `monospaceTextStyle` / `monospaceTextStyleSmall` from `lib/themes/theme.dart` which already include `FontFeature.tabularFigures()`.
   - Add a small helper if beneficial (optional):
     - `AppTheme.timerTextStyle({Color? color, double? fontSize})` returning a copy of `monospaceTextStyleSmall` with overrides.

2) Apply styling uniformly
   - Journal entry card (in task context): ensure any running time label uses `monospaceTextStyle[Small]` or has `fontFeatures: [FontFeature.tabularFigures()]`.
   - Task header progress (`CompactTaskProgress`): already uses tabular figures—verify and keep.
   - Floating time indicator (`TimeRecordingIndicator`): already uses tabular figures—verify and keep.
   - Entry detail footer (`DurationWidget` / `FormattedTime`): already uses tabular figures—verify and keep.

3) Prevent residual jitter in tight layouts
   - For labels embedded in rows with dynamic width constraints, wrap timer text in a fixed or baseline width container sized for the maximum string for that surface (e.g., `88:88` or `88:88:88`).
   - Keep truncation off for timers; they should always fit once the width is reserved.

## Data Flow

- No changes. Timers continue to read durations from existing providers/services.

## i18n / Strings

- No new strings. Time formatting remains unchanged.

## Accessibility

- Preserve semantics and contrast; only typography features change.
- Ensure timers remain focusable/selectable where they previously were.

## Testing Strategy

1) Width‑stability unit/widget tests (RenderBox sizing)
   - File(s):
     - `test/features/tasks/ui/compact_task_progress_timer_text_test.dart`
     - `test/widgets/misc/time_recording_indicator_timer_text_test.dart`
     - `test/features/journal/ui/widgets/entry_details/duration_widget_timer_text_test.dart`
     - If a timer text exists inside the journal card in task context, add: `test/features/journal/ui/widgets/list_cards/modern_journal_card_timer_text_test.dart`
   - Approach:
     - Pump the widget with two sample strings (e.g., `00:41`, `00:48`, and if HH:MM:SS `08:08:08`) using the same text style.
     - Measure `RenderBox.size.width` and assert equality to verify tabular figures.
     - Where width is reserved via a container, assert the container’s width remains constant across values.

2) Snapshot/golden (optional)
   - A single small golden per surface to ensure visual parity if helpful, but the width assertion is primary.

## Performance

- Negligible; font feature toggles are static and layout widths are fixed once.

## Edge Cases & Handling

- Fonts without tabular figures on some platforms: fallback remains our monospace style defined in theme, which already specifies tabular figures. If a platform still lacks them, enforced fixed container width will prevent jitter.
- Surfaces displaying only minutes (no hours) should reserve space for hours (`HH:MM`) to avoid shift when crossing 59 → 60 minutes.

## Files to Modify / Add

- Verify/adapt (most already correct):
  - `lib/widgets/misc/time_recording_indicator.dart` (tabular figures present)
  - `lib/features/journal/ui/widgets/entry_details/duration_widget.dart` (tabular figures present)
  - `lib/features/tasks/ui/compact_task_progress.dart` (tabular figures present)
  - `lib/features/tasks/ui/linked_duration.dart` (uses `monospaceTextStyleSmall`)
  - `lib/features/journal/ui/widgets/list_cards/modern_journal_card.dart` (inspect status row for any timer label; apply style or fixed width if present)
- Optional helper:
  - `lib/themes/theme.dart` (add `AppTheme.timerTextStyle` if helpful)
- Tests:
  - `test/features/tasks/ui/compact_task_progress_timer_text_test.dart`
  - `test/widgets/misc/time_recording_indicator_timer_text_test.dart`
  - `test/features/journal/ui/widgets/entry_details/duration_widget_timer_text_test.dart`
  - `test/features/journal/ui/widgets/list_cards/modern_journal_card_timer_text_test.dart` (only if a timer text is actually rendered there)

## Rollout Plan

1) Confirm all timer surfaces and add missing style/fixed‑width wrappers where needed.
2) Add the width‑stability tests and run them locally.
3) Run `make analyze` and `make test`; ensure zero analyzer warnings.
4) Manual sanity check in task view (header + journal card), entry details, and the floating indicator while the timer is running.

## Open Questions

- Do we want to unify all timer text through a single `AppTheme.timerTextStyle` helper for easier future changes? Proposed: yes, but optional. YES
- If we find no timer text in the journal card for tasks (only the red dot), should we still reserve placeholder space to anticipate later? NO

## Implementation Checklist

- [ ] Audit all timer surfaces (journal card in task context, task header progress, floating indicator, entry detail footer)
- [ ] Apply `monospaceTextStyle[Small]` or explicit `FontFeature.tabularFigures()` everywhere a timer renders
- [ ] Add fixed‑width container where layout is tight or could still jitter
- [ ] Add width‑stability tests for each surface
- [ ] `make analyze` yields zero warnings
- [ ] Manual verification across the identified screens

## Implementation discipline

- Always ensure the analyzer has no complaints and everything compiles. Also run the formatter 
  frequently.
- Prefer running commands via the dart-mcp server.
- Only move on to adding new files when already created tests are all green.
- Write meaningful tests that actually assert on valuable information. Refrain from adding BS 
  assertions such as finding a row or whatnot. Focus on useful information.
- Aim for full coverage of every code path.
- Add CHANGELOG entry

