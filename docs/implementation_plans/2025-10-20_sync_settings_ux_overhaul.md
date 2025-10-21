# Sync Settings — Top-Level Menu, Stats Visibility, and Outbox Toggle Removal

## Summary

- Promote Sync to a first-class, top-level Settings menu item (like AI Settings).
- Hide the entire Sync menu when the sync config flag is disabled.
- Create a dedicated Sync Settings page that surfaces Sync Stats at the top level (no longer buried
  in a modal flow).
- Move Outbox Monitor under the Sync section and remove the redundant “enabled” toggle from the
  Outbox page. Ensure to use the sync config flag instead internal for the same decisions. Remove
  the unused code.
- Track a follow-up for restyling Sync Conflicts.

## Goals

- Provide a clear, discoverable Sync entry point under Settings.
- Ensure the Sync menu and pages disappear entirely when sync is disabled.
- Expose Sync Stats as a prominent top-level entry under the Sync section.
- Simplify Outbox Monitor by removing the extra on/off toggle (global sync flag alone governs sync
  outbox status).
- Sync setup as first item in the menu, then outbox, then conflicts, then stats.

## Non‑Goals

- Rewriting Sync internals or transport layer logic.
- Changing conflict resolution behavior (UI restyle tracked as follow-up).
- Replacing the current Matrix settings modal flow; we keep it accessible but move overall
  navigation.

## UX and Interaction

- Settings → Sync (new top-level tile).
  - Visible only when `enableSyncFlag` is true.
  - Navigates to a new Sync Settings page with:
    - Sync Stats (top-level entry) → new full-page view of `IncomingStats`.
    - Outbox Monitor → existing list view, but without the extra toggle.
    - Matrix/Account configuration entry that opens the existing modal flow.
    - Conflicts, moved from Advanced
- Advanced Settings
  - Remove the Matrix Settings card, Conflicts and Outbox tile from Advanced to reduce duplication.
  - Leave Logs, Maintenance, About where they are.

## Architecture

1) Navigation and routing (Beamer)

- Add Sync routes to `lib/beamer/locations/settings_location.dart`:
  - `/settings/sync` → SyncSettingsPage
  - `/settings/sync/stats` → SyncStatsPage (full-page wrapper for `IncomingStats`)
  - `/settings/sync/outbox` → OutboxMonitorPage
- Gate Sync pages on the sync feature flag:
  - At minimum, conditionally render the Sync tile and rely on direct navigation being rare.
  - Preferably, add a lightweight `SyncFeatureGate` (wrapper widget) that reads `enableSyncFlag` and
    shows child or redirects back to `/settings` when disabled.

2) Settings landing page

- Update `lib/features/settings/ui/pages/settings_page.dart` to add a new top-level tile:
  - Title: reuse `context.messages.settingsMatrixTitle` (or add a new localized string if needed).
  - Subtitle: concise description (e.g., “Configure sync and view stats”).
  - Icon: `Icons.sync`.
  - Visibility: wrap in a `StreamBuilder` watching `JournalDb.watchConfigFlag(enableSyncFlag)`; hide
    when false.
  - `onTap`: `context.beamToNamed('/settings/sync')`.

3) Sync Settings page

- New `lib/features/sync/ui/sync_settings_page.dart`:
  - AppBar title: reuse `settingsMatrixTitle`.
  - Cards:
    - Configure Matrix/Rooms/Devices (optional): opens the existing modal (via `MatrixSettingsCard`
        behavior) or a simple button to launch the modal.
    - Outbox Monitor: links to `/settings/sync/outbox` and shows the existing badge icon (
      `OutboxBadgeIcon`) as trailing.
    - Sync Conflicts
    - Sync Stats (last card): links to `/settings/sync/stats`.

  - Entire page wrapped in `SyncFeatureGate` to hide when sync is disabled.

4) Outbox toggle removal

- In `lib/features/settings/ui/pages/outbox/outbox_monitor.dart`, remove the extra UnifiedToggle
  from `OutboxAppBar` and the related `onlineStatus` UI.
  - Outbox state display can remain informational (e.g., pending/error/all segmented control).
  - `OutboxCubit.toggleStatus()` is no longer called from this page; confirm no other UI depends on
    it. Remove toggle from cubit.

5) Advanced cleanup

- In `lib/features/settings/ui/pages/advanced_settings_page.dart`:
  - Remove the `MatrixSettingsCard` tile and the Outbox tile.
  - Keep Logs, Health Import (mobile), Maintenance, About.

## Data Flow

- No functional changes to sync pipelines or outbox DB watching.
- Sync Stats continues to read from existing providers/services via `IncomingStats`.
- The global `enableSyncFlag` drives visibility and gating.

## i18n / Strings

- Reuse existing:
  - `settingsMatrixTitle` (Matrix Sync Settings)
  - `settingsMatrixStatsTitle` (Matrix Stats)
  - `settingsSyncOutboxTitle` (Sync Outbox)
- Optional additions (if we want more precise labels):
  - `settingsSyncTitle` = “Sync” (tile label on Settings landing)
  - `settingsSyncSubtitle` = “Configure sync and view stats”
- If the Outbox toggle string `outboxMonitorSwitchLabel` becomes unused, consider deprecating; leave
  for now to avoid unnecessary churn.

## Accessibility

- Maintain current semantics for pages and lists.
- Ensure the new pages have clear AppBar titles and sufficient contrast.
- Keep large tap targets for settings cards.

## Testing Strategy

1) Beamer routing tests

- Update `test/beamer/locations/settings_location_test.dart`:
  - Add tests for `/settings/sync`, `/settings/sync/stats`, `/settings/sync/outbox`.
  - Remove/adjust the `/settings/advanced/outbox_monitor` expectation.
  - Verify pages stack with `SettingsPage` as the first, then Sync pages.

2) Visibility tests

- Widget tests for `SettingsPage` to assert:
  - Sync tile appears when `enableSyncFlag` is true; disappears when false (mock
    `JournalDb.watchConfigFlag`).

3) Outbox UI tests

- Update `test/widgets/sync/outbox_monitor_test.dart` to:
  - Remove expectations around the UnifiedToggle.
  - Keep segmented filter behavior tests (pending/error/all) and list rendering.

4) Smoke test for Sync Stats

- Pump `/settings/sync/stats` and assert `IncomingStats` renders basic sections and strings (e.g.,
  “Matrix Stats”, table columns).

## Performance

- Neutral. Rendering changes are limited to new pages and removing a small toggle.

## Edge Cases & Handling

- Direct deep link to `/settings/sync/*` while sync is disabled:
  - With `SyncFeatureGate`, redirect to `/settings` (or show empty container) to avoid 404 feelings.
- If `IncomingStats` providers fail, existing error/loader states already cover this.

## Files to Modify / Add

- Modify
  - `lib/beamer/locations/settings_location.dart` (add new paths, pages, optional gate)
  - `lib/features/settings/ui/pages/settings_page.dart` (add Sync tile, flag-based visibility)
  - `lib/features/settings/ui/pages/advanced_settings_page.dart` (remove MatrixSettingsCard + Outbox
    tile)
  - `lib/features/settings/ui/pages/outbox/outbox_monitor.dart` (remove extra toggle from app bar)
  - Tests under `test/beamer/locations/settings_location_test.dart` and
    `test/widgets/sync/outbox_monitor_test.dart`
- Add
  - `lib/features/sync/ui/sync_settings_page.dart` (new page)
  - `lib/features/sync/ui/sync_stats_page.dart` (simple scaffolded page hosting `IncomingStats`)
  - `lib/features/sync/ui/widgets/sync_feature_gate.dart` (optional gate wrapper)

## Rollout Plan

1) Implement gated top-level Sync tile and routes.
2) Create Sync Settings and Sync Stats pages; wire navigation.
3) Move Outbox Monitor under `/settings/sync/outbox` and remove toggle.
4) Remove Matrix Settings card and Outbox tile from Advanced.
5) Update tests and fix analyzer warnings.
6) Manual verification on macOS and iOS simulators:
  - Toggle `enableSyncFlag` to verify visibility and routing.
  - Navigate to Sync Stats and Outbox; confirm UI and behavior.
7) Open PR, address automated review feedback, merge.

## Open Questions

- Feature flag source of truth: use `enableSyncFlag` only, or also gate on `enableMatrixFlag`?
  => enableMatrixFlag as the source of truth, remove enableSyncFlag together with the toggle 
- Keep Matrix settings as a modal or evolve into full-page flows later? Proposed: keep modal for now
  to limit scope.

## Implementation Checklist

- [x] Add `/settings/sync`, `/settings/sync/stats`, `/settings/sync/outbox` to Beamer settings
  location
- [x] Add `SyncSettingsPage` and `SyncStatsPage` (with `IncomingStats`)
- [x] Add Sync tile to `SettingsPage` guarded by `enableMatrixFlag`
- [x] Move Outbox Monitor under `/settings/sync/outbox`
- [x] Remove UnifiedToggle from Outbox app bar
- [x] Remove MatrixSettingsCard and Outbox tile from Advanced page
- [x] Update/extend routing and widget tests
- [x] Verify analyzer: zero warnings; format code; run tests
- [ ] Add CHANGELOG entry
- [ ] Follow-up: Create task to restyle Sync Conflicts UI

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
