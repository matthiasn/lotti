# Align Labels Management with Categories Scaffolding

Refers to and builds on:

- 2025-10-26 — Task Labels System Plan: `docs/implementation_plans/2025-10-26_task_labels_system.md`
- 2025-10-31 — Labels Applicable Categories: `docs/implementation_plans/2025-10-31_task_labels_applicable_categories.md`
- 2025-10-24 — Settings Header Modernization: `docs/implementation_plans/2025-10-24_settings_header_modernization.md`

## Summary

The labels feature shipped with a list page and a modal editor. While functional, it diverges from the interaction patterns used in Settings > Categories:

- Labels list cards are not fully clickable and use a popup menu → modal flow.
- Categories use full-card navigation with a trailing chevron to a dedicated details page.
- The Category details screen shows two save affordances (top-right and a bottom bar) and the bottom area can collide with the delete icon.

This plan aligns the labels management UX with categories by:

1) Move label editing from a modal to a dedicated details page (keeping a modal only for category selection).
2) Update the labels list to use full-card navigation (chevron on the right) and remove the popup-menu → modal path.
3) Keep Category Details’ overall structure but remove the top-right Save to use a single, consistent bottom action bar (see Rationale) and increase its spacing to prevent collisions.
4) Start without extracting a generic scaffold; revisit a minimal shared wrapper only if duplication emerges during implementation.

## Decisions (confirmed)

- Single Save location: bottom bar only. Do not introduce a top‑right Save anywhere. Remove the existing top‑right Save from Category Details.

No data model or sync changes are needed; this is a UI/UX refactor grounded in the already‑shipped labels system and category scoping plans.

## Goals

- Reuse the categories “details” interaction pattern for labels (full-card tap → details page).
- Create a new `LabelDetailsPage` directly using SliverAppBar + `FormBottomBar` (no shared scaffold for now).
- Transplant the current `LabelEditorSheet` content into `LabelDetailsPage`; keep only category selection as a modal.
- Update the labels list page to use `ModernBaseCard` + `ListTile` with a trailing chevron; remove popup menu.
- Remove top-right Save from Category Details and enlarge the bottom action area to avoid icon collisions.
- Maintain analyzer zero warnings and test coverage; update existing tests and add new ones.

## Non‑Goals

- Changing task label assignment flows in task pages/sheets (already covered by 2025‑10‑26 and 2025‑10‑31 plans).
- Removing `LabelEditorSheet` from the codebase in this PR. It remains in use for task flows (`task_labels_sheet.dart`, `label_selection_modal_content.dart`) and tests; settings will stop using it.
- Data model, DB schema, or sync changes.
- Broad theming/header redesign (we follow the existing categories details style).

## Current Findings (grounded in code)

- Labels list page: `lib/features/labels/ui/pages/labels_list_page.dart`
  - Custom container cards with popup menu; edit opens `LabelEditorSheet` modal.
- Label editor (modal): `lib/features/labels/ui/widgets/label_editor_sheet.dart`
  - Contains all editing UI (name, description, color picker with presets, applicable categories via modal, privacy, actions).
- Categories list: `lib/features/categories/ui/pages/categories_list_page.dart`
  - Uses `ModernBaseCard` + `ListTile`; whole card navigates to details; trailing chevron.
- Category details: `lib/features/categories/ui/pages/category_details_page.dart`
  - SliverAppBar with top-right Save + bottom `FormBottomBar` (duplicate save). Rich multi‑section form.
- Bottom bar widget: `lib/widgets/ui/form_bottom_bar.dart` (spacing can be tight vs delete icon).
- Routing: `lib/beamer/locations/settings_location.dart` (labels currently only list route; categories have list + create + details).
- Reusable cards: `lib/widgets/cards/modern_base_card.dart`
- Reusable modal tools: `lib/widgets/modal/modal_utils.dart`
- Entities cache/labels scoping: `lib/services/entities_cache_service.dart`

Related commits for context and verification:

- #2362 feat: task labels system (commit `e49be4974`)
- #2364 refactor: address labels system review issues (commit `d6926cbb6`)
- #2365 feat: auto assign labels (commit `35bd5e9bb`)
- #2385 feat: label category assignment (commit `0573569e5`)

## Design Overview

1) Rationale & scaffolding approach
- Do NOT introduce a new `DetailsFormScaffold` yet. CategoryDetailsPage is substantially more complex (create/edit modes, AI settings, language) than labels. We will:
  - Implement `LabelDetailsPage` directly (SliverAppBar + FormBottomBar), transplanting editor content.
  - If duplication becomes material, extract a minimal shared wrapper later (follow‑up PR).

2) Category Details refinement (remove top Save; spacing)
- Keep the current SliverAppBar + body code structure.
- Remove the top‑right Save button entirely in favor of a single Save location in the bottom bar. Do not add a new Save action to the app bar.
- Increase bottom area spacing via `FormBottomBar` adjustments (see “FormBottomBar spacing improvement”).

Rationale for removing the top‑right Save
- Consistency: all settings edit pages converge on a single, predictable action area.
- Simplicity: one authoritative disabled/enabled state reduces UI state complexity and avoids collisions.
- Desktop ergonomics preserved: keyboard shortcut (⌘S on macOS, Ctrl+S on others) triggers Save, minimizing cursor travel.
- Accessibility: prevents duplicate focus order and reduces cognitive load.

3) Label Details page (new)
- New: `lib/features/labels/ui/pages/label_details_page.dart`.
- Constructor/signature:

```dart
class LabelDetailsPage extends ConsumerStatefulWidget {
  const LabelDetailsPage({
    this.labelId,
    this.initialName,
    super.key,
  });

  final String? labelId;     // Edit mode when non-null
  final String? initialName; // Create mode prefill when non-null

  bool get isCreateMode => labelId == null;
}
```

- State management: reuse existing controller
  - Use `labelEditorControllerProvider(LabelEditorArgs)`
    - Edit mode: `LabelEditorArgs(label: existingLabel)`
    - Create mode: `LabelEditorArgs(initialName: prefillName)`
  - Mirror `CategoryDetailsPage` pattern to keep local `TextEditingController`s in sync with provider state and avoid clobbering user edits.
- Body sections (transplanted from `LabelEditorSheet`):
  - Basic settings (name, optional description)
  - Color (presets + wheel)
  - Applicable categories (colored chips with contrast-aware text; “Add category” opens `CategorySelectionModalContent`)
  - Privacy switch
- Bottom actions only; no top-right Save.
- Keep modal usage only for category selection.

- Form synchronization (match CategoryDetailsPage):
  - Track `_lastSyncedName` to prevent overwriting user-typed text.
  - On provider state change, update `TextEditingController` only when the upstream value changed externally.
  - On field edits, call controller notifier methods to update state.

- Bottom actions pattern:
  - `FormBottomBar(
       leftButton: Delete (edit mode only, destructive),
       rightButtons: [Cancel, Save],
     )`
  - Delete opens a confirmation dialog (reuse strings); on confirm, delete → pop page → snackbar.

  Example delete dialog:

```dart
void _showDeleteDialog() {
  showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.messages.settingsLabelsDeleteConfirmTitle),
      content: Text(
        context.messages.settingsLabelsDeleteConfirmMessage(label.name),
      ),
      actions: [
        LottiTertiaryButton(
          onPressed: () => Navigator.pop(context),
          label: context.messages.cancelButton,
        ),
        LottiTertiaryButton(
          onPressed: () async {
            Navigator.pop(context);
            await controller.deleteLabel(label.id);
            if (context.mounted) {
              Navigator.pop(context); // pop details page
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    context.messages.settingsLabelsDeleteSuccess(label.name),
                  ),
                ),
              );
            }
          },
          label: context.messages.settingsLabelsDeleteConfirmAction,
          isDestructive: true,
        ),
      ],
    ),
  );
}
```

- Category selection modal from page context
  - Use the same component as today (`CategorySelectionModalContent`) via `showModalBottomSheet` with `isScrollControlled: true` and `useRootNavigator: true` to retain behavior.

4) Labels list page alignment
- Update cards to `ModernBaseCard` + `ListTile` with full‑tile `onTap` → details route and a trailing chevron.
- Remove popup menu + modal editor path (defer deletion behavior to details page).
- Keep “Create from search” CTA; navigate to create route with prefilled name.

5) Routing (exact changes)
- `SettingsLocation` additions:
  - Add two branches mirroring categories:

```dart
// After the existing labels list page branch
if (pathContains('labels/create'))
  BeamPage(
    key: const ValueKey('settings-labels-create'),
    child: LabelDetailsPage(
      initialName: state.uri.queryParameters['name'],
    ),
  ),

if (pathContains('labels') && pathContainsKey('labelId'))
  BeamPage(
    key: ValueKey('settings-labels-${state.pathParameters['labelId']}'),
    child: LabelDetailsPage(labelId: state.pathParameters['labelId']!),
  ),
```

Also update `SettingsLocation.pathPatterns` to include:

```
'/settings/labels/create',
'/settings/labels/:labelId',
```

6) `FormBottomBar` spacing improvement
- Use SafeArea inside the container (preserves shadow/decoration):

```dart
// lib/widgets/ui/form_bottom_bar.dart
@override
Widget build(BuildContext context) {
  return Container(
    decoration: BoxDecoration(
      color: context.colorScheme.surface,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 4,
          offset: const Offset(0, -2),
        ),
      ],
    ),
    child: SafeArea(
      bottom: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 12, 16, 12),
        child: Row(
          // existing layout
        ),
      ),
    ),
  );
}
```

7) Deprecation note
- Mark `LabelEditorSheet` as deprecated in a comment for settings usage; retain for task flows.

## Implementation Steps

1. Scaffolding
- Update `form_bottom_bar.dart` to include SafeArea and increased padding (see exact code above).

2. Categories
- Remove top‑right Save action from `CategoryDetailsPage`; keep bottom bar.
- Verify keyboard shortcut Save (⌘S/Ctrl+S) continues to work.

3. Labels
- Add `label_details_page.dart` (SliverAppBar + body + bottom bar) and transplant content from `LabelEditorSheet`.
- Update `labels_list_page.dart` to:
  - Use `ModernBaseCard` + `ListTile` with trailing chevron.
  - Navigate on full‑tile tap to details.
  - Remove `PopupMenuButton` and modal editor path.
  - FAB navigates to `/settings/labels/create`.
- Keep `LabelEditorSheet` present (deprecated); migrate internal usages here off of it.

  Concrete diffs to apply in `labels_list_page.dart`:

```dart
// 1) FAB handler
floatingActionButton: FloatingActionButton(
  onPressed: () => beamToNamed('/settings/labels/create'),
  // ...
),

// 2) Create-from-search CTA
onPressed: () {
  final encoded = Uri.encodeComponent(query);
  beamToNamed('/settings/labels/create?name=$encoded');
},

// 3) Replace custom Container card with ModernBaseCard + ListTile
return ModernBaseCard(
  onTap: () => beamToNamed('/settings/labels/${label.id}'),
  padding: EdgeInsets.zero,
  child: ListTile(
    // leading/title/subtitle retained from current content
    trailing: Icon(
      Icons.chevron_right,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  ),
);

// 4) Remove helpers now obsolete in this page
// - _openEditor()
// - _openEditorWithInitial()
// - _confirmDelete()
// - PopupMenuButton in _LabelListCard
```

4. Routing
- Extend `SettingsLocation` with labels create/edit routes and add corresponding tests.

5. L10n
- Add `settingsLabelsDetailsLabel`: “Label Details”.
- Reuse existing delete confirmation strings for Labels:
  - `settingsLabelsDeleteConfirmTitle`
  - `settingsLabelsDeleteConfirmMessage(name)`
  - `settingsLabelsDeleteSuccess(name)`
- Run `make l10n`.

6. Tests (see next section for details)
- Update affected existing tests and add new targetted suites.

7. Docs and Changelog
- Update `features/labels/README.md` to reflect page navigation vs modal.
- Add CHANGELOG entry.

## Testing Plan (high‑quality, targeted, near‑complete coverage)

General
- Use `flutter_test` + repository helpers; avoid flaky UI assertions; assert on meaningful state.
- Follow the repo guidelines: analyze/format before broad runs. Prefer targeted suites first.

Updated/Added test files
- Labels list alignment (UPDATE)
  - `test/features/labels/ui/labels_list_page_test.dart`
    - Remove popup‑menu assertions; add:
      - Full‑tile tap navigates to details (`LabelDetailsPage`).
      - Trailing chevron present; no `PopupMenuButton` in tree.
      - “Create from search” navigates to create route and pre‑fills the name field.
- Label details (ADD)
  - `test/features/labels/ui/label_details_page_test.dart` (new)
    - Create and edit modes render.
    - Editing name/description toggles `hasChanges`; Save enabled/disabled accordingly; CMD/CTRL+S triggers `onSave`.
    - Color preset selection updates hex in controller; assertions on state.
    - Applicable categories: opens selection modal, returns categories; chips render with category colors and contrast‑aware text.
    - Private toggle updates state; Save persists via repository; snackbar shows and page pops.
    - Delete (edit mode): confirm dialog uses label name; confirm deletes and pops.
- Category details regression (UPDATE existing file)
  - `test/features/categories/ui/pages/category_details_page_test.dart`
    - Add assertions that top‑right Save is removed; bottom bar present with Delete/Cancel/Save; Save enabled only when `hasChanges`.
- Form bottom bar
  - `test/widgets/ui/form_bottom_bar_test.dart` (new): SafeArea present; updated padding applied.
- Routing (UPDATE)
  - `test/beamer/locations/settings_location_test.dart`: add coverage for `/settings/labels/create` and `/settings/labels/:id`.

Performance/behavior sanity
- Existing label workflow integration tests (`test/features/labels/integration/label_workflow_test.dart`) should continue to pass; adjust navigation expectations where necessary.

## Acceptance Criteria

- Labels list cards are fully clickable; trailing chevron visible; visual style matches current design.
- Visual regression checklist for labels list:
  - Border radius matches target spec (ModernBaseCard vs current container).
  - Shadow depth and opacity align with card guidelines.
  - Internal padding consistent with current design.
  - Category chips maintain contrast-aware foreground color.
  - Private badge styling preserved (size, color, typography).
- Tapping a label navigates to `Label Details`; editor content is on a dedicated page (no sheet), except category selection remains a modal.
- Category Details has a single save area (bottom bar) with no top‑right Save.
- Bottom bar spacing no longer collides with the delete button/icon.
- Analyzer reports zero warnings; all updated/added tests pass locally.

## Risks & Mitigations

- Navigation regressions after route changes
  - Mitigation: Beamer location tests for new routes; targeted widget tests for navigation from list → details.
- Accidental removal of still‑needed modal flows
  - Mitigation: Keep `LabelEditorSheet` (deprecated), change only the settings list to the page flow.
- Visual regressions in Category Details after scaffold swap
  - Mitigation: Snapshot review; targeted test to ensure Save is bottom‑only and keyboard shortcut works.

## Rollout & Verification

1) Implement scaffolding + category adjustments; run analyzer and category tests.
2) Add label details page + routing; migrate labels list to navigation pattern; update tests.
3) L10n generation and final format.
4) Run focused suites, then full `make test`; review coverage deltas.
5) Manual smoke on desktop + mobile sizes:
   - Settings → Labels list
   - Create from FAB and from search
   - Edit label (color, categories, privacy) and save
   - Delete label
   - Settings → Categories: confirm single save area (bottom) + spacing

Keyboard shortcuts
- macOS: ⌘S (LogicalKeyboardKey.keyS + meta).
- Windows/Linux: Ctrl+S (LogicalKeyboardKey.keyS + control).
- We will mirror the pattern already present in `CategoryDetailsPage`.

Example usage:

```dart
return CallbackShortcuts(
  bindings: {
    const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _handleSave,
    const SingleActivator(LogicalKeyboardKey.keyS, control: true): _handleSave,
  },
  child: Scaffold(
    // ...
  ),
);
```

## Process & Tooling

- Prefer MCP tools:
  - Analyze: `dart-mcp.analyze_files`
  - Format: `dart-mcp.dart_format`
  - Tests: `dart-mcp.run_tests` (start with specific files, then the suite)
- Do not edit generated files; regenerate via `make build_runner` only if needed (not expected here).
- Maintain the analyzer zero‑warning policy before opening PRs.

## Appendix: File‑by‑file changes (sketch)

- UPDATE `lib/widgets/ui/form_bottom_bar.dart` (SafeArea + padding)
- UPDATE `lib/features/categories/ui/pages/category_details_page.dart` (remove top Save)
- ADD `lib/features/labels/ui/pages/label_details_page.dart` (transplant editor content)
- UPDATE `lib/features/labels/ui/pages/labels_list_page.dart` (ModernBaseCard + full‑tile navigation; remove popup menu)
- UPDATE `lib/beamer/locations/settings_location.dart` (labels create/edit routes)
- (Optional) MARK DEPRECATED `lib/features/labels/ui/widgets/label_editor_sheet.dart` (settings usage)
- L10n: add `settingsLabelsDetailsLabel`, run `make l10n`
- Tests: UPDATE/ADD files listed above

## Finalized Decisions

- Labels list subtitle density: keep the richer design (usage count + applicable category chips). Categories are simpler; labels benefit from this context.
- “Create from search” prefill: use query parameter approach for cleaner separation.

Create-from-search navigation snippet:

```dart
// In LabelsListPage when offering the CTA
final encoded = Uri.encodeComponent(query);
beamToNamed('/settings/labels/create?name=$encoded');
```

Reading the value for prefill (via SettingsLocation → page argument):

```dart
if (pathContains('labels/create'))
  BeamPage(
    key: const ValueKey('settings-labels-create'),
    child: LabelDetailsPage(initialName: state.uri.queryParameters['name']),
  ),
```
