import 'package:lotti/features/design_system/components/lists/grouped_card_row_interactions.dart';

/// Computes how a task row should visually merge with its neighbours in a
/// grouped list, based on which of the three rows (this/previous/next) is
/// selected or hovered.
///
/// A higher-priority row "absorbs" the gap to a lower-priority neighbour
/// (top/bottom overlap), and a divider is drawn below only when both this row
/// and the next are inactive. The trio's priorities come from
/// [taskRowInteractionPriority].
GroupedCardRowInteraction buildTaskBrowseRowInteraction({
  required String taskId,
  required String? previousTaskIdInSection,
  required String? nextTaskIdInSection,
  String? selectedTaskId,
  String? hoveredTaskId,
  double overlap = 1,
}) {
  final currentPriority = taskRowInteractionPriority(
    taskId: taskId,
    selectedTaskId: selectedTaskId,
    hoveredTaskId: hoveredTaskId,
  );
  final previousPriority = previousTaskIdInSection == null
      ? 0
      : taskRowInteractionPriority(
          taskId: previousTaskIdInSection,
          selectedTaskId: selectedTaskId,
          hoveredTaskId: hoveredTaskId,
        );
  final nextPriority = nextTaskIdInSection == null
      ? 0
      : taskRowInteractionPriority(
          taskId: nextTaskIdInSection,
          selectedTaskId: selectedTaskId,
          hoveredTaskId: hoveredTaskId,
        );

  final hasUpperInteraction =
      previousTaskIdInSection != null &&
      (currentPriority > 0 || previousPriority > 0);
  final hasLowerInteraction =
      nextTaskIdInSection != null && (currentPriority > 0 || nextPriority > 0);

  return GroupedCardRowInteraction(
    topOverlap: hasUpperInteraction && currentPriority > previousPriority
        ? overlap
        : 0,
    bottomOverlap: hasLowerInteraction && currentPriority >= nextPriority
        ? overlap
        : 0,
    showDividerBelow:
        nextTaskIdInSection != null &&
        currentPriority == 0 &&
        nextPriority == 0,
  );
}

/// Ranks a row's interaction state: `2` when selected, `1` when hovered,
/// `0` otherwise. Selection outranks hover.
int taskRowInteractionPriority({
  required String taskId,
  required String? selectedTaskId,
  required String? hoveredTaskId,
}) {
  if (taskId == selectedTaskId) {
    return 2;
  }
  if (taskId == hoveredTaskId) {
    return 1;
  }
  return 0;
}
