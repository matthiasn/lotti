const checklistCrossFadeDuration = Duration(milliseconds: 100);
const checklistActionIconFadeDuration = Duration(milliseconds: 300);
const checklistCompletionAnimationDuration = Duration(milliseconds: 1000);
const checklistCompletionFadeDuration = Duration(milliseconds: 300);

// Nano Banana design animations
const checklistChevronRotationDuration = Duration(milliseconds: 200);
const checklistCardCollapseAnimationDuration = Duration(milliseconds: 250);

/// Filter mode for checklist items.
enum ChecklistFilter {
  /// Show only unchecked items.
  openOnly,

  /// Show all items (checked and unchecked).
  all,
}
