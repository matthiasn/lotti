const checklistActionIconFadeDuration = Duration(milliseconds: 300);

/// How long a just-checked item lingers (showing its checkmark + strike-through)
/// before the Open filter hides it. Held a touch past 1s so the completed state
/// is legible — the checkbox doesn't vanish the instant it's ticked — without
/// stalling the list.
const checklistCompletionAnimationDuration = Duration(milliseconds: 1150);
const checklistCompletionFadeDuration = Duration(milliseconds: 300);

// Nano Banana design animations
const checklistChevronRotationDuration = Duration(milliseconds: 200);
const checklistCardCollapseAnimationDuration = Duration(milliseconds: 250);

/// Filter mode for checklist items.
enum ChecklistFilter {
  /// Show only unchecked items.
  openOnly,

  /// Show only checked/completed items.
  doneOnly,

  /// Show all items (checked and unchecked).
  all,
}
