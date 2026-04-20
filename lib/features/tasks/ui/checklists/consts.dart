const checklistCrossFadeDuration = Duration(milliseconds: 100);
const checklistActionIconFadeDuration = Duration(milliseconds: 300);
const checklistCompletionAnimationDuration = Duration(milliseconds: 1000);
const checklistCompletionFadeDuration = Duration(milliseconds: 300);

// Nano Banana design animations
const checklistChevronRotationDuration = Duration(milliseconds: 200);
const checklistCardCollapseAnimationDuration = Duration(milliseconds: 250);

/// Maximum number of item rows rendered inline in a `ChecklistCard` before the
/// body truncates and shows a "View all" button that opens the full list in a
/// modal bottom sheet. Hardcoded by design — not user-configurable — so the
/// visible stack stays consistent across tasks.
const maxVisibleChecklistItems = 10;

/// Filter mode for checklist items.
enum ChecklistFilter {
  /// Show only unchecked items.
  openOnly,

  /// Show only checked/completed items.
  doneOnly,

  /// Show all items (checked and unchecked).
  all,
}
