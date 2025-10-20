# Feature Gating — Habits, Dashboards, Measurables, and Journal Filters

## Summary

- Hide Habits, Dashboards, and Measurables UI when the corresponding feature tabs are disabled via
  config flags.
- Gate journal filter chips so entry types for disabled features never appear (Habits, Measured,
  Health, Events).
- Enforce the gating at query time so stale persisted selections cannot leak disabled types into
  results.
- Localize hard-coded labels in the create modal and filter chips; stabilize loading states to avoid
  flicker.

Config flags used:

- `enableHabitsPageFlag` — hides Habits tab and Habits settings card; removes `HabitCompletionEntry`
  from journal filter.
- `enableDashboardsPageFlag` — hides Dashboards tab and settings card; hides Measurables settings
  card; removes `MeasurementEntry` and `QuantitativeEntry` (Measured/Health) from journal filter.
- `enableEventsFlag` — already wired; continue pattern to hide Events chip and creation item.

## Goals

- Journal filters only show entry types relevant to enabled features.
- Settings show only Habits/Dashboards/Measurables when enabled.
- Queries intersect selected entry types with allowed types for consistent results.
- Localized labels and stable rendering while flags load.

## Non‑Goals

- Changing the actual data model or migrating existing entries.
- Introducing new navigation patterns beyond light guards in Settings.
- Redesigning Settings or the filter UI.

## UX and Interaction

- Filters: Users only see chips for enabled features; "All" chip respects the filtered list.
- Settings: Cards for Habits, Dashboards, and Measurables disappear when disabled; no dead ends.
- Create modal: Event item hidden when disabled; all titles localized.
- No layout flicker while flags load: render with stable defaults.

## Architecture

1) Centralize entry-type gating

- Add a small utility:
  `computeAllowedEntryTypes({required bool events, required bool habits, required bool dashboards}) -> List<String>`
  that filters from `entryTypes`.
- Rules:
  - `events == false` → drop `JournalEvent`.
  - `habits == false` → drop `HabitCompletionEntry`.
  - `dashboards == false` → drop `MeasurementEntry`, `QuantitativeEntry`, `SurveyEntry`, `WorkoutEntry`.

2) EntryTypeFilter: riverpod-driven, localized, no flicker

- Watch flags via `configFlagProvider(flag).value ?? false` for stable immediate render.
- Build `filteredEntryTypes = computeAllowedEntryTypes(...)`.
- Replace `entryTypeDisplayNames` with a function that returns localized labels using
  `AppLocalizations`.
- Localize the "All" chip label.

Files:

- lib/widgets/search/entry_type_filter.dart
- lib/features/journal/utils/entry_type_gating.dart (new)

3) JournalPageCubit: enforce gating at query time

- Subscribe to flags once (via `JournalDb.watchActiveConfigFlagNames()` or similar) and cache
  booleans in the cubit.
- In `_runQuery`, compute `allowed = computeAllowedEntryTypes(...)` and intersect with
  `state.selectedEntryTypes` before passing to `getJournalEntities`.
- Keep current behavior when selection is empty (do not auto-expand).

Files:

- lib/blocs/journal/journal_page_cubit.dart

4) SettingsPage gating

- Convert to `ConsumerWidget` and watch `enableHabitsPageFlag` and `enableDashboardsPageFlag`.
- Show/hide cards:
  - Habits card only when `enableHabitsPageFlag` is true.
  - Dashboards and Measurables cards only when `enableDashboardsPageFlag` is true.
- Optional (guard routes): In `SettingsLocation`, gate the build of corresponding pages behind the
  same flags to avoid deep-linking into disabled pages. -> no there is no deep linking, and even 
  if there was, the link can still be followed, it's only about not overloading the UI for new 
  users.

Files:

- lib/features/settings/ui/pages/settings_page.dart
- lib/beamer/locations/settings_location.dart (optional)

5) Create modal: localization + stable flag handling

- Replace hard-coded titles with `context.messages.*` keys.
- For `CreateEventItem`, use the same stable flag pattern (`value ?? false`).

Files:

- lib/features/journal/ui/widgets/create/create_entry_items.dart

## Data Flow

- Read config flags via `configFlagProvider(flagName)`; in cubit, subscribe to db flag stream for
  parity with other places.
- Query layer remains unchanged except the types list is filtered.

## i18n / Strings

- Add localization keys for filter chip labels (Task, Text, Event, Audio, Photo, Measured, Survey,
  Workout, Habit, Health, Checklist, ChecklistItem, AI Response) and for "All".
- Add/create modal titles: `addActionAddEvent`, `addActionAddTask`, `addActionAddAudio`,
  `addActionAddTimer`, `addActionAddText`, `addActionImportImage`, `addActionScreenshot`,
  `addActionPasteImage` (ensure they exist and are used).
- Run `make l10n` and `make sort_arb_files`.

## Accessibility

- No changes to semantics. Hiding cards and chips does not alter accessibility where items are not
  rendered.
- Localized labels improve clarity.

## Recent Changes

- Prior events gating and provider migration landed in dd19f020ae9bc5d135e877912ddc8cebe9f3507e.
- Critique addressed here:
  - Intersect selected types with allowed list in the cubit.
  - Localize create modal titles and filter chip labels.
  - Stabilize loading (use `value ?? false`).

## Testing Strategy

1) EntryTypeFilter gating tests

- Extend `test/widgets/search/entry_type_filter_test.dart`:
  - Assert Event chip hidden when events flag off (existing).
  - Add tests for Habits off → no `Habit` chip.
  - Add tests for Dashboards off → no `Measured`, `Health`, `Survey`, or `Workout` chips.
  - Switch expectations to localized text via `AppLocalizations` in the test harness.

2) JournalPageCubit intersection test

- New test in `test/blocs/journal/journal_page_cubit_test.dart`:
  - Persist a selection including disabled types.
  - Simulate flags: dashboards off (and/or habits off).
  - Verify `_db.getJournalEntities` is called with the intersected `types`.

3) SettingsPage gating tests

- Update/Add tests in `test/features/settings/ui/pages/settings_page_test.dart`:
  - Provide flag overrides.
  - Assert visibility of Habits/Dashboards/Measurables cards according to flags.

4) Create modal localization

- Adjust tests that look up hard-coded titles to use localized strings.
  - Where necessary, assert presence/absence by icon match plus localized label.

General

- Run `make analyze` and `make test`; keep Zero‑Warning policy.

## Performance

- Negligible. Gating creates tiny lists and a simple set intersection; flag streams are already in
  use elsewhere.

## Edge Cases & Handling

- Stale persisted entry type selections: intersection at query time prevents disabled types from
  being used.
- Empty selection semantics: unchanged; we do not auto-expand selection.
- Deep links into disabled settings pages: optional guards in `SettingsLocation` if needed.
- Loading flicker: avoided by using `.value ?? false` instead of rendering nothing while loading.

## Files to Modify / Add

- New: `lib/features/journal/utils/entry_type_gating.dart`.
- Modify: `lib/widgets/search/entry_type_filter.dart` (gating + localization + stable loading).
- Modify: `lib/blocs/journal/journal_page_cubit.dart` (intersect allowed types before query;
  subscribe to flags).
- Modify: `lib/features/settings/ui/pages/settings_page.dart` (gate cards via flags; convert to
  ConsumerWidget).
- Optional: `lib/beamer/locations/settings_location.dart` (guard routes behind flags).
- Localizations: `lib/l10n/*.arb` add keys and regenerate.
- Tests: update and add as outlined above.

## Rollout Plan

1) Implement utility + EntryTypeFilter changes with tests.
2) Add cubit intersection + targeted test.
3) Gate SettingsPage cards + tests; decide on optional route guards.
4) Localize create modal titles and adjust tests.
5) `make analyze`, `make test`, zero warnings; manual sanity check filters and settings.

## Open Questions

- Should we also hide any health import Settings entry when Dashboards are off? Proposed: NO (
  separate concern).
- Do we want to proactively clear disabled types from persisted selections upon flag change?
  Proposed: NO, rely on intersection to keep behavior reversible.

## Implementation Checklist

- [x] Provide broadcast shared stream for config flags; derive `configFlag` from it to avoid multi‑listen errors.
- [x] Fix tests infra: default `MockJournalDb.watchActiveConfigFlagNames()` returns broadcast empty set and remains stub‑friendly.
- [ ] Add `entry_type_gating.dart` and unit test the rules.
- [x] EntryTypeFilter: watch all three flags; localize labels; stable loading; tests cover
  events/habits/dashboards.
- [x] JournalPageCubit: intersect selected vs allowed; subscribe to flags; add test verifying
  `types` passed to DB.
- [ ] SettingsPage: switch to ConsumerWidget; gate Habits/Dashboards/Measurables cards; tests.
- [ ] Create modal: localize all item titles; stable flag read for Event; tests use localized texts.
- [ ] Add/confirm l10n keys; run `make l10n` and `make sort_arb_files`.
- [x] Run `make analyze`, fix all diagnostics; `dart format .`.
- [ ] Run full test suite and ensure green.
- [ ] Update CHANGELOG and any feature READMEs touched.

## Implementation discipline

- Always ensure the analyzer has no complaints and everything compiles. Also run the formatter
  frequently.
- Prefer running commands via the dart-mcp server.
- Only move on to adding new files when already created tests are all green.
- Write meaningful tests that actually assert on valuable information. Refrain from adding BS
  assertions such as finding a row or whatnot. Focus on useful information.
- Aim for full coverage of every code path.
- Every widget we touch should get as close to full test coverage as is reasonable, with meaningful
  tests.
- Add CHANGELOG entry.
- Update the feature README files we touch such that they match reality in the codebase, not only
  for what we touch but in their entirety.
- In most cases we prefer one test file for one implementation file.
- When creating l10n labels edit the arb files.
- Keep the checklist in the plan updated as you check off items.
