# Checklist UI Polish Plan

## Summary

- Elevate the checklist section visuals to a premium, Series‑A+ feel while keeping all existing behavior intact.
- Improve visual separation and readability of items, especially for multi‑line entries.
- Make the reordering affordance feel intentional and less noisy without changing when/where reordering is possible.
- Tidy the header: balance actions, remove awkward in‑content delete row, and keep export affordances.
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

- `ChecklistsWidget` wraps the section in `ModernBaseCard` (good foundation), toggles checklist‑level reordering.
- `ChecklistWidget` uses an `ExpansionTile` for the header+items and relies on `_isEditing` to show item drag handles and a delete affordance. The delete button currently lives in the content area as a separate row, which feels disjointed.
- `ChecklistItemWidget` builds on `CheckboxListTile` with an inline edit pencil, limited spacing, and little visual separation between rows; multi‑line titles blur into the next row.
- Checkbox interactions are correct but lack polish; background/row state changes are abrupt.

## Design Changes (UI‑only)

1) Header polish (ChecklistWidget)
- Keep the `ExpansionTile`, but move the delete action into the header actions row (only visible in edit mode).
- Keep export icon and long‑press/secondary‑click share behavior; add better spacing and ordering of actions.
- Slightly increase spacing and use subtle color/opacity changes to differentiate view vs edit modes.

2) Item row refinement (ChecklistItemWidget)
- Preserve `CheckboxListTile` for behavior and semantics, but wrap it in an `AnimatedContainer` with:
  - Soft background (`surfaceContainerHigh*` family) and hairline border for premium separation.
  - Rounded corners and subtle vertical spacing between items.
  - Smooth background animation on check/uncheck and while inline‑editing.
- Increase horizontal padding and add vertical padding so multi‑line text breathes.
- Keep the inline edit pencil, but ensure it doesn’t visually dominate.

3) Reordering affordance
- Keep current behavior (drag handles only in edit mode). Improve perceived affordance by:
  - Ensuring list rows look “card‑like” so the handle feels more natural when visible.
  - No persistent pencil‑gated reorder change (strictly visual polish).

4) Micro‑animations
- Add subtle animated background/tint when an item becomes checked or enters inline‑edit.
- Maintain Material ink and accessibility (no custom gestures that change behavior).

## Implementation Notes

- `lib/features/tasks/ui/checklists/checklist_widget.dart`
  - Move the delete icon from the first child row into the header action cluster, gated by `_isEditing`.
  - Keep all callbacks and semantics stable.

- `lib/features/tasks/ui/checklists/checklist_item_widget.dart`
  - Wrap `CheckboxListTile` in `Padding + AnimatedContainer` with a rounded border and tinted background.
  - Adjust `contentPadding` to `horizontal: 12–16`, `vertical: 6–8` for readability.
  - Animate background color on `_isChecked`/`_isEditing`.

- No database/state changes; no new providers.

## Testing Plan

- Update existing tests that depend on icon placement only if necessary (icon presence should remain unchanged).
- ChecklistWidget tests
  - Header edit toggle still reveals an editing state.
  - Delete icon is present in edit mode and triggers confirmation/callback.
  - Export icon still appears when callback provided and triggers it.
  - Adding a new item still calls creation callback.
- ChecklistItemWidget tests
  - Checkbox on/off flows and callback are unchanged.
  - Inline title edit callback still fires.
  - Read‑only behavior still disables the checkbox.
  - Additional expectations for container presence (non‑behavioral) where helpful to increase coverage.

Target: maintain or exceed current coverage; aim for 100% across the touched widgets.

## Accessibility

- Keep semantic labels on progress indicator and inputs.
- Maintain keyboard activation for editing and submission.
- Ensure contrast of new backgrounds meets theme’s baseline.

## Acceptance Criteria

- Visual polish is clearly improved: rows are crisply separated, multi‑line items read well, and the header actions feel balanced.
- No behavior changes: editing, reordering, deleting, exporting, and sharing work exactly as before.
- Analyzer reports zero warnings; formatter clean.
- Widget tests pass with coverage ≈100% for the affected components.

## Rollout

- Land UI changes and tests in one PR.
- Verify on macOS and iOS (via FVM) during manual QA.
- Add CHANGELOG entry and screenshots in the PR description.

