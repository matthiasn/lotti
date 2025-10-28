# Checklist UI Polish Plan

## Summary

- Elevate the checklist section visuals to a premium, Series‑A+ feel while keeping all existing
  behavior intact.
- Improve visual separation and readability of items, especially for multi‑line entries.
- Make the reordering affordance feel intentional and less noisy without changing when/where
  reordering is possible.
- Tidy the header: balance actions, remove awkward in‑content delete row, and keep export
  affordances.
- Add tasteful checkbox/state animation to feel responsive and modern.
- Ensure near‑100% widget test coverage for the updated components.

## Goals

- Keep behavior and data flow unchanged (no functional changes).
- Visually refine: spacing, backgrounds, dividers, hover/pressed feedback, and alignment.
- Clarify editing vs viewing states while keeping the existing “edit” toggle model.
- Maintain and, where practical, improve accessibility and semantics.
- Achieve 100% (or as close as possible) coverage for touched widgets.

## Non‑Goals

- Changing when/where reordering is allowed, persistence logic, or data contracts.
- Introducing new settings or feature flags.
- Adding new dependencies beyond what’s already in the project.

## Current Findings

- `ChecklistsWidget` wraps the section in `ModernBaseCard` (good foundation), toggles
  checklist‑level reordering.
- `ChecklistWidget` uses an `ExpansionTile` for the header+items and relies on `_isEditing` to show
  item drag handles and a delete affordance. The delete button currently lives in the content area
  as a separate row, which feels disjointed.
- `ChecklistItemWidget` builds on `CheckboxListTile` with an inline edit pencil, limited spacing,
  and little visual separation between rows; multi‑line titles blur into the next row.
- Checkbox interactions are correct but lack polish; background/row state changes are abrupt.

## Architecture Impact

These components are involved and must remain functionally identical:

1. ChecklistsWidget (container for a task’s checklists)

- Controls checklist-level reordering via `ReorderableListView` and `_isEditing`.

2. ChecklistWrapper

- Orchestrates state, export/share callbacks passed down to `ChecklistWidget`.

3. ChecklistWidget

- Single checklist with `ExpansionTile` header, item-level reordering, title editing.

4. ChecklistItemWrapper

- Wraps each item with `Dismissible` (swipe-to-delete) and drag-and-drop wiring.

5. ChecklistItemWithSuggestionWidget

- Overlays AI suggestion pulse indicator (Stack + `AnimationController`).

6. ChecklistItemWidget

- Core checkbox row with inline title editor cross-fade.

UI polish must respect this layering:

- Any row background/border radius is applied inside `ChecklistItemWidget` so it does not affect
  `Dismissible` gesture areas.
- `ChecklistItemWrapper`’s `Dismissible.background` will be clipped with the same radius to avoid
  visual glitches during swipe.
- `ChecklistItemWithSuggestionWidget`’s pulse indicator remains on top of the row (no z-order
  regression).

## Design Changes (UI‑only)

1) Header polish (ChecklistWidget)

- Keep the `ExpansionTile`. Add delete into the header actions cluster (visible only when
  `_isEditing == true`).
- Keep export icon and long‑press/secondary‑click share behavior; tighten icon spacing.
- Maintain the divider suppression (no ExpansionTile divider) to match the card look.

Exact header action order

- View mode: `[ProgressDot]  Title  [Edit]  [Export]`
- Edit mode: `[ProgressDot]  Title  [Edit active]  [Delete]  [Export]`
  - Delete appears only in edit mode to reduce visual noise.
  - Delete intentionally comes before Export so Export keeps a stable, last position.

2) Item row refinement (ChecklistItemWidget)

- Preserve `CheckboxListTile` for behavior and semantics. Wrap it in `Padding(vert: 4)` +
  `AnimatedContainer`:
  - Background (base): `colorScheme.surfaceContainerHigh` with alpha 0.08.
  - Background (checked): `colorScheme.primaryContainer` with alpha 0.10.
  - Background (editing): `colorScheme.surfaceContainerHighest` with alpha 0.12.
  - Border: `colorScheme.outline` with alpha 0.12.
  - Corner radius: 12.0 (intentionally smaller than outer card’s 20.0 for hierarchy).
- Content padding inside the tile: horizontal 16.0, vertical 8.0.
- Text: allow up to 4 lines (increased from 3) to reduce truncation for common multi‑line items.
  - Overflow handling: `TextOverflow.fade` after line 4; very long titles are expected to be edited
    down.
- Keep inline edit pencil; lower visual dominance via consistent 20px size and outline color.

3) Reordering affordance (two levels)

- Keep existing behavior: drag handles appear only in edit mode at both levels.
- Accept platform defaults for handle placement (left on some desktop platforms, right on mobile).
  Do not force side to preserve familiarity.
- Visual consistency: the new “card-like” item rows make handles feel deliberate in item-level
  reordering; checklist-level reordering remains unchanged but benefits from clearer section
  spacing.

4) Micro‑animations and interactions

- AnimatedContainer background color transition for item rows on check/uncheck/edit, 200ms
  `Curves.easeInOut`.
- Keep existing `AnimatedCrossFade` for inline edit transition (100ms as today). No changes.
- Keep AI suggestion pulse (`ChecklistItemWithSuggestionWidget`) unchanged; it can animate
  concurrently with row background without conflicts (different properties/trees).
- Maintain Material ink and semantics; no gesture or callback changes.

## Implementation Notes

- `lib/features/tasks/ui/checklists/checklist_widget.dart`
  - Move the delete icon to the header actions cluster, gated by `_isEditing`.
  - Preserve divider suppression and progress indicator semantics.
  - Keep export/long‑press share behavior unchanged.

- `lib/features/tasks/ui/checklists/checklist_item_widget.dart`
  - Wrap `CheckboxListTile` in `Padding + AnimatedContainer` using the tokens above.
  - `contentPadding`: horizontal 16.0, vertical 8.0.
  - Animate background color on `_isChecked`/`_isEditing` with 200ms easeInOut.
  - Dense theme override: remove the `minVerticalPadding` and `minTileHeight` overrides (retain
    `dense: true`), so the new paddings can apply cleanly.
  - Checked text style: `TextDecoration.lineThrough` + `TextStyle` color alpha, applied to the
    Text only (not the edit button). Use `textColor.withValues(alpha: textColor.a * 0.6)` to avoid
    offscreen buffers from `Opacity`; inline editing mode shows full‑opacity text.

- `lib/features/tasks/ui/checklists/checklist_item_wrapper.dart`
  - Wrap `Dismissible` background in `ClipRRect(borderRadius: 12)` and match horizontal padding so
    the swipe reveal respects the same rounding as the row container.
  - Exact padding: `Padding(padding: EdgeInsets.symmetric(horizontal: 16.0))` around the background,
    matching tile `contentPadding`.
  - Keep `DismissDirection.endToStart` and confirmation dialog as-is.

- `lib/features/tasks/ui/checklists/checklist_item_with_suggestion_widget.dart`
  - No structural change; ensure the left-side pulse indicator remains visible above the row
    background.

- “Add a new item” field (inside `ChecklistWidget` children)
  - Maintain `TitleTextField` and existing input decoration.
  - Add top/bottom spacing to visually align with the new row rhythm (bottom 8.0 already present;
    add top 4.0 if needed).

- No database/state changes; no new providers.

## Testing Plan

- Keep behavioral tests intact and extend with minimal layout assertions (no goldens required):
  - Verify `AnimatedContainer` wraps each row and that its color changes after checking an item:
    - `await tester.tap(...)`; `await tester.pump();` then
      `await tester.pump(const Duration(milliseconds: 200));` to complete the animation.
  - Verify header delete icon only appears in edit mode and triggers confirmation/callback.
  - Verify export icon presence/absence based on callback.
  - Verify strikethrough style when checked (inspect `Text` style).
  - Keep Dismissible swipe-to-delete covered via existing wrapper tests; add a check that the
    background is clipped (by type or key).
  - Ensure “Add a new item” field still submits and clears correctly.
  - Verify AI pulse indicator renders above the row background (assert order in `Stack` or that it
    remains visible during animations).
  - Concurrent animation case: check an item and immediately perform a swipe-to-delete; ensure no
    visual/behavioral glitches.

Target: maintain or exceed current coverage; aim for ≈100% across the touched widgets.

## Accessibility

- Keep semantic labels on progress indicator and inputs.
- Maintain keyboard activation for editing and submission.
- Ensure contrast of new backgrounds meets theme’s baseline.
- Verify keyboard tab order remains unchanged after wrapping list tiles in `AnimatedContainer`.
 - Validate checked‑text readability in both light and dark themes. If it looks washed out, raise
   text alpha to 0.7–0.75 or fall back to strikethrough without reduced opacity.

## Visual Consistency

- Checklist-level and item-level reordering both use edit-mode handles and feel coherent with the
  new row visuals.
- Platform-default handle side is respected; spacing around handles and row content remains
  balanced.

## Acceptance Criteria

- Visual polish is clearly improved: rows are crisply separated, multi‑line items read well, and the
  header actions feel balanced.
- No behavior changes: editing, reordering, deleting, exporting, and sharing work exactly as before.
- Analyzer reports zero warnings; formatter clean.
- Widget tests pass with coverage ≈100% for the affected components.

## Regression Checklist

- Swipe-to-delete works and background is clipped to the same radius.
- AI suggestion pulse remains visible and unobstructed.
- Drag/drop between checklists remains functional.
- Progress indicator semantics and visuals are unchanged.
- Export tap vs long-press share works as before.

## Rollout

- Land UI changes and tests in one PR.
- Verify on macOS and iOS (via FVM) during manual QA.
- Add CHANGELOG entry and screenshots in the PR description.
