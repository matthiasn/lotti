part of 'daily_timeline.dart';

/// Visual inset in pixels for each nesting level.
const double _nestedInset = 4;

/// Assigns lanes to nested children and builds their widgets.
///
/// This handles the case where nested children overlap with each other
/// (e.g., two calls within a morning block that overlap in time).
List<Widget> _buildNestedChildWidgets({
  required List<ActualTimeSlot> nestedChildren,
  required ActualTimeSlot parent,
  required double parentWidth,
  required int nestingDepth,
  required int startHour,
  required DateTime date,
}) {
  if (nestedChildren.isEmpty) return [];

  // Apply lane assignment to handle overlapping siblings
  final assignments = assignLanesToSlots(nestedChildren);
  final laneCount = assignments.isEmpty
      ? 1
      : assignments.map((a) => a.laneIndex).reduce(math.max) + 1;

  return assignments.map((assignment) {
    return _NestedChildBlock(
      child: assignment.slot,
      parent: parent,
      parentWidth: parentWidth,
      nestingDepth: nestingDepth,
      startHour: startHour,
      date: date,
      laneIndex: assignment.laneIndex,
      laneCount: laneCount,
    );
  }).toList();
}
