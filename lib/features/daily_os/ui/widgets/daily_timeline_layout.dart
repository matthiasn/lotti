part of 'daily_timeline.dart';

/// Represents a slot assigned to a specific lane, with optional nested children.
class _LaneAssignment {
  const _LaneAssignment({
    required this.slot,
    required this.laneIndex,
    this.children = const [],
  });

  final ActualTimeSlot slot;
  final int laneIndex;

  /// Nested children that render inside this slot (same category, contained).
  final List<ActualTimeSlot> children;
}

/// Tracks a lane's end time for priority queue ordering.
class _LaneEndTime {
  const _LaneEndTime({required this.laneIndex, required this.endTime});

  final int laneIndex;
  final DateTime endTime;
}

/// Checks if [parent] fully contains [child] (same category, time-wise).
bool _slotContains(ActualTimeSlot parent, ActualTimeSlot child) {
  // Must be same category
  if (parent.categoryId != child.categoryId) return false;
  if (parent.categoryId == null) return false;

  // Parent must fully contain child
  return !parent.startTime.isAfter(child.startTime) &&
      !parent.endTime.isBefore(child.endTime) &&
      // Must not be the exact same slot
      (parent.startTime != child.startTime || parent.endTime != child.endTime);
}

/// Groups same-category entries into parent-child relationships.
///
/// Returns a map where keys are parent slots and values are their nested children.
/// Entries without a parent are their own key with an empty children list.
Map<ActualTimeSlot, List<ActualTimeSlot>> _groupNestedSlots(
  List<ActualTimeSlot> slots,
) {
  if (slots.isEmpty) return {};

  // Sort by duration descending (longest first = potential parents)
  final sorted = [...slots]..sort((a, b) => b.duration.compareTo(a.duration));

  final parentChildMap = <ActualTimeSlot, List<ActualTimeSlot>>{};
  final assignedChildren = <ActualTimeSlot>{};

  // For each slot, find children (slots contained within this one).
  // Since sorted is by duration descending, children must appear after parent.
  for (var i = 0; i < sorted.length; i++) {
    final slot = sorted[i];
    if (assignedChildren.contains(slot)) continue;

    // Initialize this slot as a potential parent
    parentChildMap[slot] = [];

    // Find children: only need to check slots after this one (shorter duration)
    for (var j = i + 1; j < sorted.length; j++) {
      final other = sorted[j];
      if (assignedChildren.contains(other)) continue;

      if (_slotContains(slot, other)) {
        parentChildMap[slot]!.add(other);
        assignedChildren.add(other);
      }
    }
  }

  return parentChildMap;
}

/// Assigns time slots to lanes to prevent visual overlap.
///
/// Uses a greedy algorithm with a min-heap for O(N log K) complexity,
/// where N is the number of slots and K is the number of lanes.
///
/// Same-category entries that are fully contained within another entry
/// (parent-child relationship) are nested visually instead of getting
/// separate lanes.
List<_LaneAssignment> _assignLanes(List<ActualTimeSlot> slots) {
  if (slots.isEmpty) return [];

  // First, group slots by parent-child relationships
  final nestedGroups = _groupNestedSlots(slots);

  // Get only the parent slots for lane assignment (children will nest inside)
  final parentSlots = nestedGroups.keys.toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));

  // Min-heap ordered by lane end time (earliest first)
  final laneHeap = PriorityQueue<_LaneEndTime>(
    (a, b) => a.endTime.compareTo(b.endTime),
  );

  final assignments = <_LaneAssignment>[];
  var nextLaneIndex = 0;

  for (final parentSlot in parentSlots) {
    int assignedLane;

    if (laneHeap.isNotEmpty &&
        !parentSlot.startTime.isBefore(laneHeap.first.endTime)) {
      // Reuse the earliest-ending lane (no overlap)
      final reusedLane = laneHeap.removeFirst();
      assignedLane = reusedLane.laneIndex;
    } else {
      // Create a new lane
      assignedLane = nextLaneIndex++;
    }

    // Add/update lane in heap with new end time
    laneHeap.add(
      _LaneEndTime(laneIndex: assignedLane, endTime: parentSlot.endTime),
    );

    // Create assignment with nested children
    final children = nestedGroups[parentSlot] ?? [];
    assignments.add(
      _LaneAssignment(
        slot: parentSlot,
        laneIndex: assignedLane,
        children: children,
      ),
    );
  }

  return assignments;
}

/// Returns the number of lanes needed for the given assignments.
int _getLaneCount(List<_LaneAssignment> assignments) {
  if (assignments.isEmpty) return 1;
  return assignments.map((a) => a.laneIndex).reduce(math.max) + 1;
}

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
  final assignments = _assignLanesToSlots(nestedChildren);
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

/// Simple lane assignment for a list of slots (used for nested children).
List<({ActualTimeSlot slot, int laneIndex})> _assignLanesToSlots(
  List<ActualTimeSlot> slots,
) {
  if (slots.isEmpty) return [];

  final sorted = [...slots]..sort((a, b) => a.startTime.compareTo(b.startTime));

  final laneHeap = PriorityQueue<_LaneEndTime>(
    (a, b) => a.endTime.compareTo(b.endTime),
  );

  final assignments = <({ActualTimeSlot slot, int laneIndex})>[];
  var nextLaneIndex = 0;

  for (final slot in sorted) {
    int assignedLane;

    if (laneHeap.isNotEmpty &&
        !slot.startTime.isBefore(laneHeap.first.endTime)) {
      final reusedLane = laneHeap.removeFirst();
      assignedLane = reusedLane.laneIndex;
    } else {
      assignedLane = nextLaneIndex++;
    }

    laneHeap.add(_LaneEndTime(laneIndex: assignedLane, endTime: slot.endTime));
    assignments.add((slot: slot, laneIndex: assignedLane));
  }

  return assignments;
}
