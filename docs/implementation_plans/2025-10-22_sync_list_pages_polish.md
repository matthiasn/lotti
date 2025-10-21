# Sync Outbox & Conflicts — Modern List Polish

## Summary

- Rebuild the Sync Outbox and Sync Conflicts list pages around the modern card system so they
  present like a polished Series A product.
- Align headers, filters, spacing, and empty states with the rest of Settings by introducing a
  shared sync list scaffold.
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

- Outbox monitor still uses a raw `Scaffold` with `CupertinoSegmentedControl` and manual `Card`
  tinting, producing cramped spacing and inconsistent color tokens.
  - File: `lib/features/settings/ui/pages/outbox/outbox_monitor.dart:33`
- Outbox cards format multiline subtitles with manual `\n` joins, lack icons, and only allow retry
  via whole-card tap; typography ignores new title/subtitle styles.
  - File: `lib/features/settings/ui/pages/outbox/outbox_monitor.dart:125`
- Conflicts list mirrors the same legacy pattern, including `CupertinoSegmentedControl`, no empty
  state, and basic `Card` styling with minimal hierarchy.
  - File: `lib/features/settings/ui/pages/advanced/conflicts_page.dart:52`
- Both pages surface lower-case filter labels (`pending`, `all`, `resolved`) that bypass
  localization casing and clash with new segmented-button theming.
  - File: `lib/features/settings/ui/pages/outbox/outbox_monitor.dart:188`
  - File: `lib/features/settings/ui/pages/advanced/conflicts_page.dart:71`
- Widget tests assert on the literal lowercase labels, so changing to localized polished text will
  require test updates.
  - File: `test/widgets/sync/outbox_monitor_test.dart:51`
  - File: `test/features/settings/ui/pages/conflicts_page_test.dart:36`
- Neither page handles the empty state gracefully; when streams emit an empty list the body is just
  blank black.

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

- Status: Planned
- Refactor `OutboxMonitorPage` to use the new scaffold and segmented button enum (
  Pending/Error/All).
- Build `OutboxListItemViewModel` to format retries, attachment labels, and action availability.
- Render rows with `ModernBaseCard`, `ModernCardContent`, `ModernStatusChip`, and a trailing retry
  button (using existing `OutboxCompanion` update) that launches a confirmation modal before
  proceeding.
- Highlight attachment presence with icons and allow tap to copy file path (if provided).

### Phase 3 — Conflicts Card Modernization (P0)

- Status: Planned
- Migrate `ConflictsPage` onto `SyncListScaffold` with filters for unresolved/resolved.
- Introduce `ConflictListItemViewModel` encapsulating vector clock snippet, conflict kind, and
  navigation callback.
- Use `ModernStatusChip` (Resolved vs Unresolved), include mini badges for entity type (journal
  entry/task), and adopt consistent typography.

### Phase 4 — Empty & Loading States (P1)

- Status: Planned
- Provide descriptive empty states (“No pending outbox items”) using `EmptyStateWidget`.
- Show a center `CircularProgressIndicator.adaptive` while the first snapshot is loading.
- Add inline count summary above the list (e.g., “6 pending items”) to mirror segmented badge
  totals.

### Phase 5 — QA, Docs, and Polish (P0)

- Status: Planned
- Update widget tests to cover new segmented buttons, empty-state rendering, retry button behavior,
  and navigation.
- Refresh `lib/features/settings/README.md`, `lib/features/sync/README.md`, and `CHANGELOG.md` to
  document the visual overhaul.
- Verify analyzer/test runs and capture before/after screenshots for review.

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
  - `lib/features/settings/ui/pages/outbox/outbox_monitor.dart`
  - `lib/features/settings/ui/pages/advanced/conflicts_page.dart`
  - `test/widgets/sync/outbox_monitor_test.dart`
  - `test/features/settings/ui/pages/conflicts_page_test.dart`
  - `lib/features/settings/README.md`
  - `lib/features/sync/README.md`
  - `CHANGELOG.md`
- Add:
  - `lib/features/settings/ui/widgets/sync_list_scaffold.dart`
  - `lib/features/settings/ui/widgets/outbox/outbox_list_item.dart` (or similar helper)
  - `lib/features/settings/ui/widgets/conflicts/conflict_list_item.dart`
  - Supporting view-models or mappers under `lib/features/settings/ui/view_models/`

## Decisions

- Retry interactions move to a dedicated trailing button that always confirms before requeueing.
- Payload kind metadata is displayed alongside retries/attachments to aid debugging.
- Segmented filters display aggregate counts, sourced from combined stream data.

## Implementation Checklist

- [ ] Implement shared `SyncListScaffold` + filter widgets with loading/empty support.
- [ ] Refactor Outbox monitor to use new scaffold, cards, and retry affordances.
- [ ] Refactor Conflicts list to new scaffold with modern cards and chips.
- [ ] Update localization usages (title case labels) and adjust tests accordingly.
- [ ] Add empty state coverage and interaction tests (filter toggles, retry).
- [ ] Refresh Settings and Sync READMEs plus `CHANGELOG.md` entry.
- [ ] Run `dart-mcp.analyze_files`, `dart-mcp.dart_format`, and targeted `dart-mcp.run_tests`.

## Next

- Revisit the conflict detail page styling once list polish ships.
- Consider surfacing aggregate diagnostics (counts, last sync) above the lists as a follow-up.
