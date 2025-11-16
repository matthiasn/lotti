# Checklist Completion Feedback — Subtle Animation and Fade-Out (2025-11-16)

## Summary

- Make checking off a checklist item feel intentional and satisfying instead of abrupt, especially
  when “Open only” filtering causes items to disappear.
- Introduce a short completion “fanfare” that visually anchors the user’s action: a subtle success
  highlight (e.g., green-tinted border/glow) followed by a smooth fade-out and height collapse.
- Keep data semantics and completion counts unchanged: items become completed immediately on check;
  the animation is purely presentational.
- Ensure behavior fits cleanly into the existing checklist architecture (`ChecklistWidget` +
  `ChecklistItemWrapper` + `ChecklistItemWithSuggestionWidget` + `ChecklistItemWidget`) and doesn’t
  regress drag, swipe-to-delete, or AI suggestion overlays.

## Related Prior Work (Checklist Domain)

We should respect and build on:

- 2025-10-28 — `2025-10-28_checklist_ui_polish.md`
  - Rounded/tinted rows, strikethrough for checked items, and clipped swipe-to-delete backgrounds.
  - Establishes current checklist item visual hierarchy and spacing.
- 2025-10-19 — `2025-10-19_checklist_markdown_export.md`
  - Adds export/share actions and header affordances; relevant because completion feedback should
    not conflict with export/share interactions.
- 2025-11-06 — `2025-11-06_checklist_multi_create_array_only_unification.md`
  - Checklist items created via AI function-calling; completion feedback must be robust when items
    are created/checked in bursts.
- 2025-11-09 — `2025-11-09_checklist_ergonomics_keyboard_focus_and_filter.md`
  - Introduces the `ChecklistFilter { openOnly, all }` behavior, per-checklist persisted filter, and
    the “All done” empty state message.
  - The “open only” filter is the main reason items visually disappear immediately after checking.
- 2025-11-09 — `2025-11-09_checklist_updates_entry_directives_and_scoping.md`
  - Checklist Updates prompt behavior and entry-scoped directives; important to ensure AI-driven
    completions don’t feel harsher than manual ones.
- 2025-11-11 — `2025-11-11_checklist_creation_current_entry_default.md`
  - Current-entry semantics and completion tools; ties into how/when multiple items might be
    batch-completed and how the UI should respond.

Code touchpoints to keep in mind:

- `lib/features/tasks/ui/checklists/checklist_widget.dart`
  - Owns `ChecklistFilter`, “Open only vs All” segmented control, per-checklist filter persistence,
    and the “All done” empty state.
  - Builds the `ReorderableListView` of `ChecklistItemWrapper` with `hideIfChecked` wired from
    filter/editing state.
- `lib/features/tasks/ui/checklists/checklist_item_wrapper.dart`
  - Wraps each item in `Dismissible` + drag/drop (`DragItemWidget` / `DraggableWidget`) and
    currently short-circuits to `SizedBox.shrink()` when `hideIfChecked && item.data.isChecked`.
- `lib/features/tasks/ui/checklists/checklist_item_with_suggestion_widget.dart`
  - Hosts the AI completion suggestion pulse (left-side bar with `AnimationController`) stacked over
    `ChecklistItemWidget`.
- `lib/features/tasks/ui/checklists/checklist_item_widget.dart`
  - Owns row visuals (rounded `AnimatedContainer`, hover background, strikethrough when checked) and
    edit cross-fade.

## Problem

- When a checklist is in “Open only” mode, checking an item instantly removes it from the list
  because `ChecklistItemWrapper` returns `SizedBox.shrink()` for checked items.
- Combined with the existing strikethrough styling, there’s effectively no temporal buffer: the user
  sees a brief checkbox tick and then the row pops out of existence.
- This feels abrupt and slightly irritating, especially for users who want a small moment of
  “completion satisfaction” or need a fraction of a second to visually confirm which item they just
  completed.

## Goals

- Provide a clear, pleasant completion feedback sequence:
  - Checkbox tick → subtle success highlight (e.g., green border/glow) → smooth fade-out and height
    collapse (≈500–1000 ms total).
- Preserve all functional behavior:
  - Completion counts update immediately.
  - Filters, drag-and-drop reordering, swipe-to-delete, export/share, and AI suggestion overlays
    continue to work as today.
- Keep the effect tasteful and non-distracting:
  - Works for rapid “check down the list” flows and long lists.
  - Does not introduce motion sickness or excessive visual noise.
- Maintain zero analyzer warnings and solid test coverage for the new behavior.

## Non-Goals

- Changing underlying checklist data model, storage, or AI tooling.
- Introducing new settings/feature flags for animations in this first pass (unless UX feedback or
  accessibility requirements demand it).
- Redesigning header or filter semantics beyond what’s required to support the new completion
  feedback.

## UX & Interaction (Proposed)

Baseline assumption: the harshness is most visible in “Open only” mode, but we also keep the visual
fanfare in the “All” view; in “All”, items do not collapse or disappear.

- Manual completion (Open only)
  - User taps/clicks the checkbox on an item.
  - The checkbox ticks immediately and the item counts as completed (progress indicator and header
    counts update as today).
  - The row:
    - Briefly shows a subtle success state (stronger green-tinted border or inner glow, optionally a
      tiny left-edge accent).
    - Then fades its opacity to 0 and collapses vertically over ~700–900 ms.
  - After the fade-out finishes, the row is removed from the layout (list closes the gap).

- Manual completion (All mode)
  - User taps/clicks the checkbox on an item.
  - Checkbox ticks and the row transitions to the “checked” background + strikethrough as
    implemented in checklist UI polish.
  - Apply the same success highlight (border/glow/flash), but do not fade-out the row; the item
    stays visible in the list.

- Bulk/AI completion
  - When one or more items are marked complete via AI suggestions or tools, each affected row
    follows the same sequence.
  - For multiple simultaneous completions, animations may overlap; the list should remain stable (no
    wild jumps).

- Undo / uncheck
  - If the user unchecks an item before the fade-out finishes:
    - We cancel the fade-out, remove the success highlight, and leave the item visible (and counted
      as open).
  - If the item is already removed due to filter, the user would bring it back via switching to
    “All” mode; we don’t introduce an explicit “Undo” UI for this change in the first iteration.

## Design & Architecture (High-Level)

1) Delay hiding vs. animated visibility

- Today:
  - `ChecklistWidget` passes `hideIfChecked: !_isEditing && _filter == ChecklistFilter.openOnly`.
  - `ChecklistItemWrapper` immediately returns `SizedBox.shrink()` when
    `hideIfChecked && item.data.isChecked`.
- Proposed direction:
  - Introduce an animated “completion visibility” layer that:
    - Keeps the row in the tree after `isChecked` flips to true.
    - Drives a fade + size collapse animation.
    - Only removes the row from layout once the animation completes.
  - Implementation options (to be finalized after open questions):
    - A) Convert `ChecklistItemWrapper` into a `ConsumerStatefulWidget` and wrap its `Dismissible`
      child in an `AnimatedOpacity` + `AnimatedSize` or `SizeTransition`. When
      `hideIfChecked && item.data.isChecked`, trigger the animation and, on completion, effectively
      hide/remove.
    - B) Keep `ChecklistItemWrapper` mostly passive and wrap items in `ChecklistWidget`’s
      `ReorderableListView` children with `AnimatedSwitcher` / `SliverAnimatedList`-style
      transitions keyed by `itemId`.
  - We should bias toward the smallest, least invasive change that plays nicely with `Dismissible`
    and reordering.

2) Success highlight styling

- Likely hosted inside `ChecklistItemWidget`’s `AnimatedContainer` decoration:
  - Add a transient “completion highlight” state that temporarily:
    - Increases border color intensity and/or thickness using `colorScheme.primary` or
      `colorScheme.tertiary`.
    - Optionally adds a soft outer shadow or inner glow (low elevation).
  - Transition this highlight away over the same duration as the fade-out.
- Important: do not conflict with the existing AI suggestion pulse:
  - `ChecklistItemWithSuggestionWidget` overlays a pulsing bar via `Stack`.
  - Completion highlight should stay compatible and not obscure that bar.

3) Filter and list semantics

- Completion semantics:
  - Completion counts and filter state remain source-of-truth as today.
  - The animation layer is purely visual; it does not delay the logical “checked” state.
- Filter interactions:
  - When `_filter == ChecklistFilter.openOnly` and `_isEditing == false`, items should still
    eventually disappear from the open-only view.
  - While the fade-out is running, the item is logically completed but visually in a “transition
    out” state.
  - Once the animation completes, the row is effectively removed/hidden to match filter
    expectations.
- Editing mode:
  - When `_isEditing == true`, we currently show all items (filter off) to keep reordering stable.
  - Completion feedback should not re-introduce hidden items while editing; animations can still
    run, but rows remain visible.

4) Performance and robustness

- Keep animations lightweight:
  - Prefer implicit animations (`AnimatedOpacity`, `AnimatedContainer`, `AnimatedSize`) over heavy
    manual `AnimationController`s, unless we need precise sequencing.
  - Ensure we don’t accidentally trigger rebuild storms when many items are completed in rapid
    succession.
- Error handling:
  - If anything about the animation state becomes inconsistent (e.g., race between filter changes
    and completion), we should favor showing the final correct list state over keeping a broken
    animation alive.

## i18n / Strings

- No new strings are strictly required for the first iteration.
- Optional follow-ups (if desired):
  - A short, optional “All done!” toast or inline hint when the last open item in a checklist is
    completed. This would reuse or complement `checklistAllDone` and should be coordinated with the
    existing empty-state text in `ChecklistWidget`.

## Accessibility

- Respect user motion/accessibility preferences:
  - If the platform provides a “reduce motion” or similar setting that we can query, we may need to:
    - Shorten or disable the fade/size transitions.
    - Keep the success highlight but avoid large positional movement.
- Ensure that:
  - Focus order is not disrupted during the fade-out (e.g., keyboard focus should not jump
    unexpectedly while items transition out).
  - Screen readers still announce the item as “checked” immediately; the visual animation is
    secondary.

## Testing Strategy (High-Level)

- Widget tests under `test/features/tasks/ui/checklists/`:
  - `checklist_item_wrapper_completion_animation_test.dart` (new):
    - Verifies that when an item is checked in “Open only” mode:
      - It does not disappear immediately from the widget tree.
      - A completion highlight/fade state is active for the expected duration (simulated via `pump`/
        `pumpAndSettle`).
      - After the animation completes, the item is gone from the open-only view.
    - Verifies that unchecking during the animation cancels the fade-out and keeps the item visible.
  - Extend existing tests where needed:
    - `checklist_widget_test.dart`: ensure counts and “All done” message still behave correctly when
      items are completed and animated out.
    - `checklist_item_widget_test.dart`: ensure the success highlight styling plays nicely with the
      existing checked state visuals.
    - `checklist_item_with_suggestion_widget_test.dart`: confirm that AI suggestion overlays remain
      visible and unaffected by completion feedback.

- Manual QA:
  - Long lists with many items; rapid checking down the list.
  - Toggling between “Open only” and “All” while items are completing.
  - Desktop (mouse/keyboard) and mobile (tap/swipe) interactions.

## Files to Modify / Add (Tentative)

- Update:
  - `lib/features/tasks/ui/checklists/checklist_item_wrapper.dart`
    - Introduce animated visibility for completed items in “Open only” mode, instead of immediate
      `SizedBox.shrink()`.
    - Potentially convert to `ConsumerStatefulWidget` to manage a short-lived fade-out/size
      animation.
  - `lib/features/tasks/ui/checklists/checklist_item_widget.dart`
    - Add a transient completion highlight state integrated into the existing `AnimatedContainer`
      decoration.
  - `lib/features/tasks/ui/checklists/checklist_widget.dart`
    - If needed, coordinate item completion callbacks with filter state and manage any per-checklist
      animation configuration (e.g., durations).
- Tests:
  - Add `test/features/tasks/ui/checklists/checklist_item_wrapper_completion_animation_test.dart`.
  - Extend existing checklist widget/item tests as described above.

## Decisions

1) Scope of animation

- Apply the full “highlight + fade-out + collapse” sequence when the checklist is in “Open only”
  mode (i.e., when items would otherwise disappear).
- In “All” mode, apply the same completion highlight (border/glow/flash) but do not fade or remove
  the item; completed items remain visible there.

2) Timing and feel

- Use a total duration of 1000 ms for the completion glow/fade sequence, exposed via a `const`
  duration so it’s easy to tweak.
- Front‑load the highlight: the success state should appear quickly, then transition into fade/size
  collapse rather than staying constant throughout.

3) Visual intensity

- Use a slightly thicker border with a subtle green tint, optionally paired with a soft, low‑
  elevation glow and a brief but noticeable green “flash” on the border/background when completion
  is triggered.
- No special brand/theming constraints beyond existing theming; using the normal success green from
  the color scheme is acceptable.

4) Behavior with bulk and AI completions

- When many items are completed in rapid succession (manual or AI), run their animations
  simultaneously rather than staggering them.
- It is acceptable if the list height shrinks in small “waves” as items fade out and collapse.

5) Interaction with “All done” state

- In “All” view, nothing disappears when items are completed; only the visual state changes.
- In “Open only” view, items disappear after their completion animation finishes; when the last open
  item completes and fades out, the checklist transitions to the `checklistAllDone` empty-state
  message.
- No additional microcopy or toast/snackbar is added specifically for “last item completed”.

6) Accessibility and motion preferences

- Ship completion animations as always-on motion; no separate feature flag or hidden preference is
  required for this iteration.
- There is no additional special-casing for OS-level “reduce motion” in the first pass; if we add
  that later, it will be an incremental enhancement.

7) Undo semantics

- Do not add an explicit “Undo” affordance (e.g., snackbar with Undo) for completions.
- Users can still switch to “All” view and uncheck items there if they need to reverse a completion.

## Acceptance Criteria (Draft)

- In “Open only” mode, checking an item:
  - Immediately marks it as completed (counts and progress update).
  - Shows a subtle but noticeable completion highlight and a smooth fade/height collapse instead of
    an instant disappearance.
  - Leaves no visual glitches in drag handles, swipe-to-delete, or AI suggestion overlays.
- In “All” mode, checking an item still feels clean; any added highlight is tasteful and
  non-distracting.
- Unchecking during the animation keeps the item visible and restores its open state.
- When the last open item is completed, the checklist transitions into the “All done” state without
  jank.
- Analyzer reports zero warnings; formatter clean.
- New and updated tests pass, including the new completion animation tests and existing checklist
  tests.
