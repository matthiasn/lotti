# UI Polish: Remove Label Toaster & Replace Rating Modal with Pulsating Button

**Date:** 2026-03-11
**Status:** Planning
**Version:** 0.9.915

## Background

Two UI elements have been identified as no longer needed or too intrusive:

1. **Label assignment snackbar/toaster** — Shows "Assigned: [labels]" with Undo
   whenever AI assigns labels. Now redundant because label assignments go through
   individually-reviewable change sets.

2. **Automatic rating modal** — A full-screen modal bottom sheet that pops up
   automatically when a timer session ends (>= 1 minute). Considered too intrusive;
   users want control over when they rate.

## Goals

- Remove unnecessary UI interruptions
- Give users control over session rating without losing discoverability
- Maintain access to the rating flow via the triple-dot menu

---

## Implementation Plan

### Phase 1: Remove Label Assignment Snackbar

**Files to modify:**

| File | Action |
|------|--------|
| `lib/features/tasks/ui/labels/task_labels_wrapper.dart` | Remove snackbar listener logic (lines 32-126) |
| `lib/features/labels/services/label_assignment_event_service.dart` | Remove if no other consumers exist |
| `lib/features/labels/state/label_assignment_event_provider.dart` | Remove if no other consumers exist |
| `test/features/tasks/ui/labels/task_labels_wrapper_toast_test.dart` | Remove test file |

**Steps:**
1. Verify that `labelAssignmentEventsProvider` has no consumers besides the
   snackbar in `TaskLabelsWrapper`.
2. Remove the snackbar `ref.listen(...)` block from `TaskLabelsWrapper`.
3. If the event service and provider are unused after step 2, delete them.
4. Remove or update the corresponding test file.
5. Run analyzer + tests to verify nothing breaks.

### Phase 2: Identify Other UI Elements to Remove

**Action:** Manual app testing + codebase audit for intrusive notifications.

**Candidates to investigate:**
- Other `ScaffoldMessenger.showSnackBar` calls — are any redundant?
- Any other auto-opening modals or dialogs
- Confirmation dialogs that could be replaced by undo patterns

**Deliverable:** List of suggestions to discuss with the team before implementing.

### Phase 3: Disable Automatic Rating Modal

**Files to modify:**

| File | Action |
|------|--------|
| `lib/features/journal/state/entry_controller.dart` | Remove auto-rating trigger (lines 256-272) |
| `lib/features/ratings/state/rating_prompt_controller.dart` | Remove if no longer needed |
| `lib/features/ratings/ui/rating_prompt_listener.dart` | Remove if no longer needed |
| Related test files | Update to reflect new behavior |

**Steps:**
1. In `entry_controller.dart`, remove the block that calls
   `ratingPromptControllerProvider.notifier.requestRating()` after timer stop.
2. If `RatingPromptController` and `RatingPromptListener` have no other callers,
   remove them entirely.
3. Update tests in `test/features/ratings/` accordingly.
4. Verify the rating feature flag (`enableSessionRatingsFlag`) is still used by
   the triple-dot menu item — do not remove the flag itself.

### Phase 4: Add Pulsating "Rate" Outline Button

**New behavior:** After a timer stops (session >= 1 minute, flag enabled), instead
of opening a modal, show a pulsating outlined "Rate" button next to the timer area.

**Design spec:**
- **Style:** `OutlinedButton` with a pulsating border/glow animation
- **Animation:** Pulse for 5-10 seconds after timer stops, then stop pulsing
- **Persistence:** Button remains visible (non-pulsating) if no rating has been set
- **Tap action:** Opens the existing `RatingModal` on demand
- **Disappearance:** Button hides once a rating is saved

**Files to create/modify:**

| File | Action |
|------|--------|
| `lib/features/ratings/ui/pulsating_rate_button.dart` | New widget with animation |
| Timer/session header area widget (TBD — locate exact file) | Integrate the button |
| `lib/features/ratings/state/` | Add provider to track "should show rate button" state |
| Test files | Full test coverage for the new widget |

**Animation implementation:**
- Use `AnimationController` with `repeat(reverse: true)` for the pulse effect
- Duration: ~1 second per pulse cycle
- Effect: Animate border color opacity or scale (subtle, not jarring)
- Auto-stop after 5-10 seconds via a separate timer or fixed repeat count

**State logic:**
```text
shouldShowRateButton =
  sessionJustEnded &&
  sessionDuration >= 1 minute &&
  ratingsFeatureEnabled &&
  noExistingRating

shouldPulsate =
  shouldShowRateButton &&
  timeSinceSessionEnd < 10 seconds
```

### Phase 5: Ensure Triple-Dot Menu Still Works

**Files to verify:**
- `lib/features/journal/ui/widgets/entry_details/header/initial_modal_page_content.dart`
  — "Rate Session" menu item
- `lib/features/ratings/ui/modern_action_items.dart` — `ModernRateSessionItem`

**Steps:**
1. Verify the "Rate Session" / "View Rating" item still appears in the menu.
2. Verify tapping it still opens `RatingModal`.
3. No code changes expected here — just verification.

---

## Testing Strategy

1. **Unit tests:** Rating state providers, button visibility logic
2. **Widget tests:** Pulsating button animation, button interactions, snackbar
   removal verification
3. **Integration:** End-to-end timer flow → button appears → tap → modal → save
4. **Manual:** Verify no regressions in label assignment or timer workflows

## Rollout

- All changes in a single PR
- Feature flag `enableSessionRatingsFlag` continues to gate the rating feature
- No migration needed — purely UI changes

## Open Questions

- Exact placement of the "Rate" button relative to the timer display
- Should the button use an icon (star) or text ("Rate") or both?
- Should there be a brief delay before showing the button (e.g., 500ms after
  timer stops) to avoid visual jarring?
