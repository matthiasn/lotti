import 'package:lotti/features/design_system/theme/motion_tokens.dart';

const Duration checklistActionIconFadeDuration = MotionDurations.medium2;

/// How long a just-checked item lingers (showing its checkmark + strike-through)
/// before the Open filter hides it. Held a touch past 1s so the completed state
/// is legible — the checkbox doesn't vanish the instant it's ticked — without
/// stalling the list.
const checklistCompletionAnimationDuration = Duration(milliseconds: 1150);
const Duration checklistCompletionFadeDuration = MotionDurations.medium2;

const Duration checklistChevronRotationDuration = MotionDurations.short4;
const Duration checklistCardCollapseAnimationDuration = MotionDurations.medium1;

/// Filter mode for checklist items.
enum ChecklistFilter {
  /// Show only unchecked items.
  openOnly,

  /// Show only checked/completed items.
  doneOnly,

  /// Show all items (checked and unchecked).
  all,
}
