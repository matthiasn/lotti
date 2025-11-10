# Checklist Ergonomics — Keyboard Shortcut, Focus Retention, and Open/All Filter (2025-11-09)

## Summary

- Align checklist text entry with the rest of the app by adding a desktop-friendly save shortcut:
  Cmd+S (macOS) / Ctrl+S (Windows/Linux).
- Keep the “Add item” field focused after saving so users can enter many items in a row without
  touching the mouse/trackpad.
- Add an open/all filter when a checklist is expanded so long lists can hide completed items by
  default, with a quick toggle to show everything.
- Preserve existing collapse/expand behavior; the new filter augments the expanded state.
- Show a compact visual indicator of completed items (e.g., “3/8 done”) in the header so it’s
  obvious how many are currently hidden when filtering.

## Goals

- Fast, consistent keyboard flow for creating items: type → save (Enter/Cmd+S/Ctrl+S) → keep typing.
- Reduce visual noise in long, mostly-completed lists via an “Open only” filter, with one-click
  switch to “All”.
- Keep reordering/editing predictable and safe while filtering is active.
- Zero analyzer warnings; focused tests for keyboard, focus, and filtering behavior.

## Non‑Goals

- Changing underlying data model or storage for checklists.
- Adding new visual grouping/sections beyond the open/all toggle.

Note: The filter choice is persisted per‑checklist (via AppPrefsService) and restored on revisit. A
global app‑wide preference is out of scope for this iteration.

## UX & Interaction

- Keyboard shortcut (save):
  - Applies to `TitleTextField` when focused.
  - Cmd+S on macOS, Ctrl+S on Windows/Linux triggers the same handler as Enter or the save icon.
  - No modal; a quick, reliable save gesture consistent with other entry points.

- Focus retention (add field):
  - The “Add item to checklist” field clears and immediately regains focus after a successful save.
  - Intended for rapid multi-item entry: type → save → type → save, without mouse/trackpad.
  - Rename fields (e.g., task/checklist titles) do not retain focus after save by default.

- Tri‑state behavior (practical):
  - Collapsed: current behavior (title row with progress; no items shown).
  - Expanded + filter: when expanded, add a compact toggle in the header to cycle between:
    - Open only (default)
    - All
  - While editing/reordering: show all items to avoid index drift and confusion. Visually indicate
    that filter is temporarily off while editing (optional small badge/tooltip).
  - Completed count: display a small count next to the filter toggle (keeps the title area clean),
    e.g., “3/8 done”. On desktop, a tooltip clarifies “Completed items”. The existing tiny ring
    remains unchanged.

- Defaults:
  - Default filter is “Open only”. The selected filter is persisted per checklist ID (via
    AppPrefsService) and restored when reopening the task.

## Design & Architecture

1) TitleTextField — save shortcut + focus retention

- Add a `SaveIntent` and wire platform shortcuts via `Shortcuts`/`Actions` around the internal
  `TextField`:
  - `LogicalKeySet(Meta, KeyS)` on macOS; `LogicalKeySet(Control, KeyS)` elsewhere.
  - Shortcut invokes the same local `onSave` path used by Enter / save icon.
- Add a `keepFocusOnSave` boolean (default: `false`). When `true` and a `focusNode` is provided, set
  a local `_requestRefocus = true` flag on save and, in `build()`, if `_requestRefocus` is true,
  call `focusNode.requestFocus()` and reset the flag. This avoids fragile `addPostFrameCallback`
  timing.
- Guard against rapid double‑save: in `ChecklistWidget`, add `_isCreatingItem` and no‑op `onSave`
  while in‑flight.
- Continue honoring `clearOnSave` and `resetToInitialValue` exactly as today.

2) ChecklistWidget — filter state + header toggle + counts

- Add local enum `ChecklistFilter { openOnly, all }` and `_filter` state.
- Add a small header `IconButton` adjacent to edit/export to toggle filter (use a filter glyph
  consistent with MDI set, e.g., `MdiIcons.filterVariant`):
  - Tooltips (desktop):
    - `checklistFilterShowAll`: “Show all items”
    - `checklistFilterShowOpen`: “Show open items”
- Default `_filter` is `openOnly`.
- Do not apply filtering while `_isEditing == true` to keep `ReorderableListView` lengths stable.
  Optionally render a badge/tooltip like “Filter off while editing”.
- Show a compact completed count next to the toggle (use subtle `Text` in `labelSmall`/`bodySmall`
  with outline color): “{completed}/{total} done”. Source counts from
  `ChecklistCompletionController` to avoid recomputation. Tooltip on desktop clarifies the meaning
  and that open‑only hides completed items.
- Debounce rapid toggles: ignore toggles within ~150ms of the previous one to reduce jank on large lists.

3) ChecklistItemWrapper — conditional hide

- Add `hideIfChecked` (default `false`). If true and the item is checked, return
  `SizedBox.shrink()`.
- Filtering is only passed as `true` when not editing; during editing this is always `false`.

4) Integration — keep “Add item” focused

- In the “Add item to checklist” field inside `ChecklistWidget`, pass:
  - `focusNode: _focusNode` (already present)
  - `clearOnSave: true` (already present)
  - `keepFocusOnSave: true` (new)

## i18n / Strings

Add to ARB (`lib/l10n/app_*.arb`):

- `checklistFilterShowAll`: “Show all items”
- `checklistFilterShowOpen`: “Show open items”
- Optional (if UI hint used): `checklistFilterDisabledWhileEditing`: “Filter disabled while editing”
- `checklistCompletedShort`: “{completed}/{total} done”
  - Placeholders: `completed: int`, `total: int`
  - Desktop tooltip (optional): `checklistCompletedTooltip`: “Completed items”
- `checklistFilterStateOpenOnly`: “Showing open items” (used for announcements)
- `checklistFilterStateAll`: “Showing all items” (used for announcements)
- `checklistFilterToggleSemantics`: “Toggle checklist filter (current: {state})”
- `checklistAllDone`: “All items completed!” (empty state when open‑only has no items)

Run `make l10n` and update `missing_translations.txt` if needed.

## Accessibility

- Shortcut works only when the input has focus; default platform a11y modifiers respected.
- Provide tooltips/semantics for filter toggle; ensure sufficient hit target and contrast.

## Testing Strategy

1) TitleTextField

- Save shortcut: when focused and non‑empty, pressing Cmd+S (macOS) or Ctrl+S (Win/Linux) calls
  `onSave` once.
- Focus retention: with `keepFocusOnSave: true` and a bound `FocusNode`, after save (
  Enter/icon/shortcut), `focusNode.hasFocus == true` on next frame; text resets according to
  `clearOnSave`/`resetToInitialValue`.
- No unintended saves: if unchanged and `resetToInitialValue` is true for rename flows, shortcut can
  be a no‑op (optional test depending on current semantics).
- Double‑submit guard: for the add‑item field, rapid double presses of Cmd/Ctrl+S result in only one
  item creation (guarded by `_isCreatingItem`).

2) ChecklistWidget filter

- Default filter is `openOnly` for all lists.
- Toggling filter switches between hiding/showing checked items when not editing.
- When `_isEditing == true`, all items are visible and drag handles behave as today.
- Reordering remains stable (list length unchanged during editing).

3) Accessibility

- Provide helpful tooltips. No dedicated keyboard shortcut or screen reader announcements in this pass.

3) Completed count indicator

- With mixed items, the header renders a short count (e.g., “3/8 done”).
- Count updates as items are checked/unchecked.
- Tooltip appears on desktop when hovering the count (optional, if implemented).

4) i18n

- Added keys compile; generated getters used in the widget.

Use targeted widget tests under `test/features/tasks/ui/checklists/` and unit tests for
`TitleTextField`.

5) Empty state

- When filter is `openOnly` and no open items remain, render a friendly empty‑state message (“All
  items completed!”) instead of an empty list.

## Files to Modify / Add

- Update: `lib/features/tasks/ui/title_text_field.dart`
  - Add `keepFocusOnSave` prop
  - Add `Shortcuts`/`Actions` with `SaveIntent` for Cmd/Ctrl+S
- Update: `lib/features/tasks/ui/checklists/checklist_widget.dart`
  - Header filter toggle; default `openOnly`; pass `hideIfChecked` to items; completed count next to
    progress/filter
  - `TitleTextField` (add field): add `keepFocusOnSave: true`
  - Add `_isCreatingItem` to guard rapid double‑save for add‑item field
- Handle debounce on the filter toggle
- Update: `lib/features/tasks/ui/checklists/checklist_item_wrapper.dart`
  - Add `hideIfChecked` and hide completed items when requested
- i18n: `lib/l10n/app_*.arb` (keys above); run `make l10n`
- Tests:
  - `test/features/tasks/ui/title_text_field_shortcuts_test.dart`
  - `test/features/tasks/ui/checklists/checklist_filter_toggle_test.dart`
  - `test/features/tasks/ui/checklists/checklist_empty_state_test.dart`
  - Extend existing checklist widget tests as needed

## Acceptance Criteria

- Cmd/Ctrl+S saves in all `TitleTextField` contexts without side effects.
- After saving a new item, the add field clears and retains focus for continued typing.
- Expanded checklists provide a filter toggle; “Open only” hides checked items, “All” shows
  everything.
- Default filter is “Open only”.
- Header shows a completed count (e.g., “N/M done”) that updates with state.
- While editing/reordering, all items remain visible; reordering behaves unchanged.
- When no open items remain, an empty‑state message is shown.
- Analyzer reports zero warnings; new tests are green.

## Rollout Plan

1) Implement `TitleTextField` shortcut + focus retention with tests.
2) Add filter toggle and hiding logic; add widget tests.
3) Add ARB keys; run `make l10n` and fix any missing translations.
4) Run `make analyze` and `make test`; verify no analyzer warnings and tests pass.
5) Manual sanity on desktop (macOS, Windows) and mobile (iOS/Android simulators).

## Risks & Mitigations

- Reorderable list + filtering: only hide outside editing to keep indices stable.
- Platform key mapping: use `Meta` (macOS) vs `Control` (others); add unit coverage for both paths.
- Web behavior: confirm that shortcuts and focus flow behave in Flutter web (out of scope to fix
  here if differences arise; document if needed).
- Persistence scope: For a first pass, persist the filter choice per checklist ID via
  `AppPrefsService` (`checklist_filter_mode_{id}`) so returning to a task restores the last chosen
  state. If persistence causes confusion, fall back to in‑memory state only.

## Related Plans

- 2025‑10‑19 — Checklist Markdown Export:
  `docs/implementation_plans/2025-10-19_checklist_markdown_export.md`
- 2025‑10‑28 — Checklist Item Parsing Hardening:
  `docs/implementation_plans/2025-10-28_checklist_item_parsing_hardening.md`
- 2025‑11‑06 — Checklist Multi‑Create (Array‑Only):
  `docs/implementation_plans/2025-11-06_checklist_multi_create_array_only_unification.md`

## Implementation Checklist

- [ ] Cmd/Ctrl+S wired in `TitleTextField`
- [ ] `keepFocusOnSave` added and used for add field
- [ ] Filter toggle in `ChecklistWidget` header
- [ ] Hiding logic applied only when not editing
- [ ] Completed count chip/label in header (uses `ChecklistCompletionController`)
- [ ] i18n keys added and generated
- [ ] Tests for shortcuts, focus retention, and filter toggle
- [ ] `make analyze` yields zero warnings

## Implementation discipline

- Always ensure the analyzer has no complaints and everything compiles. Also run the formatter
  frequently.
- Prefer running commands via the dart‑mcp server.
- Only move on to adding new test files when already created tests are all green.
- Write meaningful tests that actually assert on valuable information. Refrain from adding useless
  assertions such as finding a row or whatnot. Focus on useful information.
- Aim for full coverage of every code path.
