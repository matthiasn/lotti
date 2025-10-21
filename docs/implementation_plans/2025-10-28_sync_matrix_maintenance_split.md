# Sync Maintenance — Dedicated Matrix Settings Entry

## Summary

- Move the sync-specific maintenance actions out of Advanced → Maintenance and surface them under
  Sync → Matrix Sync Settings → Maintenance.
- Introduce dedicated Sync routes/pages so Matrix setup and maintenance tooling live together behind
  the sync feature gate.
- Update existing widget/routing tests and add coverage for the new navigation path and maintenance
  page behaviour.

## Goals

- Relocate the three sync maintenance actions (`Delete Sync Database`, `Sync definitions`,
  `Re-sync messages`) so they are discoverable from the Sync area.
- Keep non-sync maintenance (other database deletions, purge deleted items, reset hints, AI 
  suggestions cleanup) under Advanced → Maintenance.
- Ensure navigation breadcrumbs, Beamer routes, and localization strings remain coherent after the
  move.
- Maintain existing modal flows (Matrix setup, purge, FTS5, re-sync) and reuse them on the new page.

## Non‑Goals

- Overhauling non-sync maintenance actions or deleting them.
- Replacing the multi-page Matrix setup modal with a full-page flow.
- Changing sync controller logic, repository behaviour, or maintenance implementations.
- Revisiting the Outbox/Conflicts placement (already covered in the sync UX overhaul).

## UX and Interaction

- Settings → Sync
  - Replace the current `Matrix Sync Settings` card tap behaviour with navigation to a new Matrix
    Sync Settings page instead of opening the modal directly.
  - The new Matrix Sync Settings page lists:
    - A card to launch the existing Matrix setup modal (reuse current `MatrixSettingsCard` content).
    - A `Maintenance` card that navigates to `/settings/sync/matrix/maintenance`.
    - (Optional) space for future cards (e.g., diagnostics); leave layout consistent with other
      settings pages.
- Settings → Sync → Matrix Sync Settings → Maintenance
  - Show the three sync maintenance actions as animated settings cards that trigger the existing
    modals:
    - Sync definitions modal
    - Recreate FTS5 index modal
    - Re-sync messages modal
  - Preserve confirmation and progress modals exactly as today.
- Advanced → Maintenance
  - Remove the three sync cards; leave the rest unchanged so muscle memory for reset/purge/db
    deletion still works.
- All Sync routes remain hidden (and redirect back to `/settings`) when the Matrix flag is disabled
  via `SyncFeatureGate`.

## Architecture

1) Beamer Routing
  - Add `/settings/sync/matrix` → `MatrixSyncSettingsPage`.
  - Add `/settings/sync/matrix/maintenance` → `MatrixSyncMaintenancePage`.
  - Ensure both pages wrap content with `SyncFeatureGate` (redirect or empty state when disabled).
  - Update `SettingsLocation.buildPages` to push the new pages between `SyncSettingsPage` and deeper
    routes.

2) Sync Settings Landing Card
  - In `lib/features/sync/ui/sync_settings_page.dart`, replace the direct `MatrixSettingsCard` with
    an `AnimatedModernSettingsCardWithIcon` that beams to `/settings/sync/matrix`.
  - Keep the iconography, title, and subtitle identical to avoid UX churn.
  - Ensure the Outbox, Conflicts, and Stats cards remain unaffected.

3) Matrix Sync Settings Page
  - Create `lib/features/sync/ui/matrix_sync_settings_page.dart` (or reuse existing folder layout).
  - Scaffold via `SliverBoxAdapterPage` to match other settings pages; title uses
    `settingsMatrixTitle`.
  - Move the existing `MatrixSettingsCard` widget into this page so tapping “Launch Matrix setup”
    opens the multi-page modal as before.
  - Add a new `AnimatedModernSettingsCardWithIcon` for maintenance that calls
    `context.beamToNamed('/settings/sync/matrix/maintenance')`.
  - Extract reusable logic from `MatrixSettingsCard` if necessary (e.g., rename to
    `MatrixSettingsLauncherCard`) so tests stay focused.

4) Matrix Sync Maintenance Page
  - New file `lib/features/sync/ui/matrix_sync_maintenance_page.dart`.
  - Wrap the column of cards in `SyncFeatureGate` + `SliverBoxAdapterPage` with a title such as
    `context.messages.maintenanceSyncMenuTitle` (add localization if required).
  - Each card replicates the behaviour currently in `Advanced Maintenance`:
    - Sync definitions → `SyncModal.show(context)`.
    - Recreate FTS5 → `Fts5RecreateModal.show(context)`.
    - Re-sync messages → `ReSyncModal.show(context)`.
  - Consider a short descriptive subtitle for the page to clarify the scope (e.g., “Matrix sync
    maintenance tools”).

5) Advanced Maintenance Page Cleanup
  - Remove the three sync cards from
    `lib/features/settings/ui/pages/advanced/maintenance_page.dart`.
  - Ensure spacing/layout still looks balanced (no dangling dividers, etc.).
  - Leave dependency injection (getIt lookups) untouched since advanced maintenance still needs
    them.

6) Docs & Localizations
  - Update `lib/features/settings/README.md` and any sync READMEs to document the new menu path.
  - Add new localization strings if titles/subtitles are needed (likely
    `settingsMatrixMaintenanceTitle` and `settingsMatrixMaintenanceSubtitle`); update ARB files and
    regenerate `app_localizations_*.dart`.

## Data Flow

- No changes to providers or controllers; the new pages invoke existing modals/controller methods.
- `SyncFeatureGate` continues to source `enableMatrixFlag`.

## i18n / Strings

- Reuse existing maintenance string keys for card labels.
- Introduce new strings if the Matrix maintenance page or card requires distinct titles/subtitles;
  run `make l10n` after updating ARB files.
- Verify no unused strings remain in Advanced maintenance (update or deprecate only if obviously
  obsolete).

## Accessibility

- Keep settings cards accessible with descriptive titles/subtitles.
- Ensure the new pages provide clear AppBar titles for screen readers.
- Maintain focus management within modals (unchanged).

## Testing Strategy

1) Routing / Beamer
  - Extend `test/beamer/locations/settings_location_test.dart` with cases for:
    - `/settings/sync/matrix`
    - `/settings/sync/matrix/maintenance`
  - Update the existing maintenance test to expect the sync maintenance cards to be absent under
    `/settings/advanced/maintenance`.

2) Sync Settings Page Tests
  - Update `test/features/sync/ui/sync_settings_page_test.dart` to expect the Matrix card to
    navigate (no direct modal) and that other cards remain.
  - Add an interaction test (using a fake `BeamerDelegate`) if needed to assert navigation occurs.

3) Matrix Sync Settings Page Tests
  - New widget test verifying:
    - The page renders the launch card and maintenance card.
    - Tapping the launch card still opens the Matrix setup modal (can reuse existing mock pattern).
    - Tapping maintenance navigates via a mocked `Beamer` context or verifies route invocation.

4) Matrix Sync Maintenance Page Tests
  - New widget tests asserting the three maintenance cards render.
  - Interaction tests that each card triggers the appropriate modal helper (`SyncModal`,
    `Fts5RecreateModal`, `ReSyncModal`), leveraging `mocktail` to spy on static `.show` calls (scope
    with `MethodChannelMocks` or wrappers if needed).

5) Advanced Maintenance Page Tests
  - Update `test/features/settings/ui/pages/maintenance_page_test.dart` to remove expectations for
    the three moved cards and ensure remaining actions still work.

6) Regression Sweep
  - Run analyzer (`dart-mcp.analyze_files`) and targeted widget tests; follow with relevant suites
    once code changes are complete.

## Performance

- Neutral; the new pages reuse existing widgets without introducing heavy operations.

## Edge Cases & Handling

- Sync flag disabled: `SyncFeatureGate` should hide/redirect both new pages; add a test to ensure
  the maintenance page doesn’t render when gated.
- Deep links directly into `/settings/sync/matrix/maintenance`: ensure the gate gracefully handles
  disabling (redirect or fallback).
- Modal stacking: confirm launching maintenance modals from the new page still closes them cleanly
  when complete.

## Files to Modify / Add

- Modify:
  - `lib/beamer/locations/settings_location.dart`
  - `lib/features/sync/ui/sync_settings_page.dart`
  - `lib/features/settings/ui/pages/advanced/maintenance_page.dart`
  - `lib/features/settings/ui/pages/advanced_settings_page.dart` (if navigation breadcrumbs need
    tweaking)
  - `test/beamer/locations/settings_location_test.dart`
  - `test/features/settings/ui/pages/maintenance_page_test.dart`
  - `test/features/sync/ui/sync_settings_page_test.dart`
  - Documentation under `lib/features/settings/README.md`
- Add:
  - `lib/features/sync/ui/matrix_sync_settings_page.dart`
  - `lib/features/sync/ui/matrix_sync_maintenance_page.dart`
  - Corresponding widget tests (e.g., `test/features/sync/ui/matrix_sync_settings_page_test.dart`,
    `matrix_sync_maintenance_page_test.dart`)
  - New localization entries (ARB + generated files)

## Rollout Plan

1) Implement routing and page scaffolding.
2) Move the three maintenance cards and confirm the modals fire from the new page.
3) Adjust Advanced maintenance layout and verify remaining actions.
4) Update docs/localizations.
5) Refresh widget and routing tests; add new coverage for the added pages.
6) Run analyzer + targeted widget tests; fix any warnings.
7) Optional manual QA: toggle Matrix flag, verify navigation/gating, launch maintenance actions.

## Implementation Checklist

- [ ] Add new Beamer routes for Matrix Sync Settings + Maintenance.
- [ ] Update SyncSettingsPage to navigate to the new Matrix page.
- [ ] Scaffold MatrixSyncSettingsPage with launch + maintenance cards.
- [ ] Create MatrixSyncMaintenancePage and wire modals.
- [ ] Remove sync cards from Advanced Maintenance.
- [ ] Update documentation and localization strings.
- [ ] Update/extend widget and routing tests.
- [ ] Run analyzer and relevant test suites (record results).

