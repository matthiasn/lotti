# Sync Outbox & Conflicts — Modern List Polish

## Summary

- Shared `SyncListScaffold`, `OutboxListItem`, and `ConflictListItem` now power the refreshed sync
  list experience; next we need to relocate everything into `lib/features/sync` to match the feature
  boundaries.
- Headers, filters, spacing, and empty states have been modernized with chips + inline summaries;
  we still owe additional test coverage (empty/loading, retry confirmation, semantics).
- Preserve existing data streams and interactions (retry, deep links) while tightening
  accessibility, localization, and tests.

## Goals

- Replace ad-hoc `Card` + `ListTile` stacks with `ModernBaseCard` + `ModernCardContent` driven
  layouts.
- Standardize segmented filters, padding, typography, and background treatments across both list
  pages.
- Provide strong empty/loading states and status chips that communicate pending/error/resolved at a
  glance.
- Keep analyzer output clean and all tests passing; expand widget coverage for the new UI flows.

## Non‑Goals

- No changes to sync/outbox/conflict processing logic or database schemas.
- No restyle of the conflict detail view or other sync detail pages (tracked separately).
- No introduction of new navigation routes; reuse existing Beamer paths.

## Findings

- Modern list polish shipped for Outbox and Conflicts, but the code still lives under
  `lib/features/settings/...`; we need to relocate the shared scaffold, list items, and pages into
  `lib/features/sync/...` (plus move tests accordingly) so the feature structure and custom lint
  expectations line up.
  - Files: `lib/features/settings/ui/pages/outbox/outbox_monitor.dart`,
    `lib/features/settings/ui/pages/advanced/conflicts_page.dart`,
    `lib/features/settings/ui/widgets/sync_list_scaffold.dart`,
    `lib/features/settings/ui/widgets/outbox/outbox_list_item.dart`,
    `lib/features/settings/ui/widgets/conflicts/conflict_list_item.dart`,
    `lib/features/settings/ui/view_models/*`
- `SyncListScaffold` owns the empty/loading states and chip filters now, yet we still lack direct
  widget coverage for empty/loading transitions or filter semantics. Tests only exercise the happy
  path with populated data.
  - Files: `test/widgets/sync/outbox_monitor_test.dart`,
    `test/features/settings/ui/pages/conflicts_page_test.dart`
- `OutboxListItemViewModel` and `ConflictListItemViewModel` encapsulate formatting logic but have no
  dedicated unit tests; edge cases (attachments missing, localized retry plurals, resolved conflicts
  semantics) remain unverified.
  - Files: `lib/features/settings/ui/view_models/outbox_list_item_view_model.dart`,
    `lib/features/settings/ui/view_models/conflict_list_item_view_model.dart`
- Outbox filter chips rely on hard-coded accent colors (`Colors.orange`, `Colors.green`); we should
  switch to tokens from `ColorScheme`/`AppTheme` for consistency.
  - File: `lib/features/settings/ui/pages/outbox/outbox_monitor.dart`

## Design Overview

- Introduce a reusable `SyncListScaffold` that wraps `SliverBoxAdapterPage` with a segmented filter
  header, consistent padding, and animated list body.
- Replace `CupertinoSegmentedControl` with themed `SegmentedButton` widgets (leveraging
  `SegmentedButtonThemeData` in `theme.dart`) and localized titles.
- Render each row via `ModernBaseCard` + `ModernCardContent`:
  - Leading: icon/avatar representing pending/error/sent/resolved.
  - Title: timestamp with status chip (using `ModernStatusChip` and palette helpers).
  - Subtitle: structured metadata (retries, attachment path, payload kind, conflict IDs) using
    `RichText` or `Column` for clear hierarchy.
  - Trailing: explicit contextual actions (e.g., “Retry” button for failed outbox rows) coupled with
    confirmation dialogs where appropriate.
- Add `EmptyStateWidget` for zero results and a subtle progress indicator while waiting for first
  stream emission.
- Apply consistent scroll physics, 24 px horizontal padding, and section headings where helpful.

## Visual Direction

- Adopt the same gradient-backed cards and soft shadows seen on Settings cards (`ModernBaseCard`
  with default gradient).
- Use status-specific chips (pending → tertiary, error → error, sent/resolved → primaryContainer)
  plus appropriate symbols.
- Present filter buttons with title case labels (“Pending”, “Errors”, “All”) and badge counts fed by
  aggregate counts for each status.
- Ensure high-contrast typography (titleSmall for headings, bodySmall for metadata) and at least 16
  px vertical rhythm between rows.

## Phases and Changes

### Phase 1 — Shared Sync List Scaffolding (P0)

- Status: Planned
- Create `SyncListScaffold` + `SyncListFilterBar` widgets in `lib/features/settings/ui/widgets/`.
- Accept a `Stream<List<T>>`, filter tabs config, and builders for card + empty state.
- Wire into theme animations and provide built-in loading/empty/error handling.

### Phase 2 — Outbox Card Modernization (P0)

- Status: Delivered ✅ (pending theme + module follow-ups)
- `OutboxMonitorPage` now consumes `SyncListScaffold` and `OutboxListItemViewModel`; filter chips
  default to Pending/Error/Success with localized title case labels.
- Retry affordance moved to a trailing button with confirmation modal; attachments, payload kind,
  and subject metadata are surfaced as structured rows.
- Follow-ups:
  - Move page + widgets/view models beneath `lib/features/sync/ui/...`.
  - Swap chip colors to use `ColorScheme.tertiary/primary/error` helpers instead of hard-coded
    `Colors.orange`/`Colors.green`.

### Phase 3 — Conflicts Card Modernization (P0)

- Status: Delivered ✅ (pending module relocation + tests)
- `ConflictsPage` now uses `SyncListScaffold` with localized unresolved/resolved chips and new card
  presentation via `ConflictListItem`.
- Vector clock summaries, entity labels, and semantics strings are handled by
  `ConflictListItemViewModel`.
- Follow-ups: relocate page/view model/widget into `lib/features/sync` and add unit/widget tests
  covering resolved conflicts and semantics labels.

### Phase 4 — Empty & Loading States (P1)

- Status: In progress
- Empty/loading states and inline count summaries ship inside `SyncListScaffold`; polish carries
  through both list pages.
- Follow-up: add widget tests that exercise empty/loading paths and verify the localized copy.

### Phase 5 — QA, Docs, and Polish (P0)

- Status: Ongoing
- Updated widget tests assert on localized filter labels and retry chips, but empty-state coverage
  is still missing; add focused tests for both lists plus view-model unit coverage.
- Refresh `lib/features/settings/README.md`, `lib/features/sync/README.md`, and `CHANGELOG.md` to
  reflect the new sync section ownership and card polish (README updated, changelog pending).
- Continue to gate merges on clean `dart-mcp.analyze_files`/`dart-mcp.run_tests`.

## Data Flow

- Continue sourcing data from `SyncDatabase.watchOutboxItems` and `JournalDb.watchConflicts`; the
  new scaffold only manages presentation and filtering.
- Filtering enums map cleanly to existing `OutboxStatus` values and `ConflictStatus` watchers.
- Outbox retry action still updates status through `OutboxCompanion`; only the trigger surface
  changes (explicit button instead of whole-card tap).

## UX & Interaction

- Filters stay sticky per page instance; consider persisting the last selection via
  `PageStorageKey`.
- Card tap opens detail (conflict detail route) while retries are initiated exclusively via the
  trailing action button, guarded by a confirmation modal.
- Provide context menu or copy-to-clipboard affordance for file paths and conflict IDs to help
  support workflows.
- Segmented filters surface aggregate counts directly on each option to aid triage.

## Accessibility

- Maintain minimum 44 px tap targets by ensuring cards and retry buttons respect Material touch
  targets.
- Supply `Semantics` labels describing status + timestamp (e.g., “Error: October 21, 2025 at 13:
  14”).
- Ensure segmented buttons announce state changes and include focus order aligned with header → list
  items.

## Testing Strategy

- Update `test/widgets/sync/outbox_monitor_test.dart` for the new scaffold, localized labels, and
  retry button behavior (use keys for segments/actions).
- Expand `test/features/settings/ui/pages/conflicts_page_test.dart` to assert empty state, filter
  toggles, navigation callback, and badge count display.
- Add golden/widget snapshots if needed for regression (optional, pending team appetite).
- Run integration smoke via `dart-mcp.run_tests` on relevant suites plus analyzer.

## Performance

- Expected neutral/slightly improved: `ListView.builder` (instead of `List.generate`) will handle
  long lists efficiently.
- Shared scaffold avoids rebuilding streams unnecessarily; ensures only card list rebuilds on filter
  changes.

## Edge Cases & Handling

- No items emitted → show empty state with guidance.
- Very large lists → ensure virtualization via `ListView.builder`.
- Stream errors (unlikely) → surface a toast/snackbar with retry or fallback message.
- Offline / DB unavailable → degrade gracefully with loader + error text.

## Files to Modify / Add

- Modify:
  - `lib/features/sync/ui/pages/outbox/outbox_monitor_page.dart` (relocated from settings)
  - `lib/features/sync/ui/pages/conflicts/conflicts_page.dart`
  - `lib/features/sync/ui/widgets/sync_list_scaffold.dart`
  - `lib/features/sync/ui/widgets/outbox/outbox_list_item.dart`
  - `lib/features/sync/ui/widgets/conflicts/conflict_list_item.dart`
  - `lib/features/sync/ui/view_models/outbox_list_item_view_model.dart`
  - `lib/features/sync/ui/view_models/conflict_list_item_view_model.dart`
  - `lib/features/settings/README.md`
  - `lib/features/sync/README.md`
  - `CHANGELOG.md`
  - Tests under `test/features/sync/ui/...` and `test/widgets/sync/...`
- Add:
  - Focused unit tests for `OutboxListItemViewModel` and `ConflictListItemViewModel`
  - Widget tests covering scaffold empty/loading states (likely under `test/features/sync/ui/pages/`)

## Decisions

- Retry interactions move to a dedicated trailing button that always confirms before requeueing.
- Payload kind metadata is displayed alongside retries/attachments to aid debugging.
- Segmented filters display aggregate counts, sourced from combined stream data.

## Implementation Checklist

- [x] Implement shared `SyncListScaffold` + filter widgets with loading/empty support.
- [x] Refactor Outbox monitor to use new scaffold, cards, and retry affordances.
- [x] Refactor Conflicts list to new scaffold with modern cards and chips.
- [x] Update localization usages (title case labels) and adjust widget smoke tests.
- [ ] Relocate sync list pages/widgets/view models into `lib/features/sync/...` and update imports.
- [x] Replace hard-coded filter colors with theme tokens.
- [x] Add empty-state/loading widget coverage plus unit tests for the new view models.
- [x] Refresh Settings and Sync READMEs plus `CHANGELOG.md` entry.
- [x] Run `dart-mcp.analyze_files`, `dart-mcp.dart_format`, and targeted `dart-mcp.run_tests`.

## Next

- Land the module relocation (move sync list UI + tests under `features/sync`) and run analyzer/tests.
- Revisit the conflict detail page styling once list polish ships.
- Consider surfacing aggregate diagnostics (counts, last sync) above the lists as a follow-up.
