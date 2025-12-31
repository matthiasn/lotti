import 'package:flutter/material.dart';
import 'package:lotti/themes/colors.dart';

/// Represents the urgency status of a due date.
enum DueDateUrgency {
  /// Due date is in the future (not today)
  normal,

  /// Due date is today
  dueToday,

  /// Due date has passed
  overdue,
}

/// Result of evaluating a due date's status.
class DueDateStatus {
  const DueDateStatus({
    required this.urgency,
    required this.daysUntilDue,
  });

  /// Creates a status for when there's no due date.
  const DueDateStatus.none()
      : urgency = DueDateUrgency.normal,
        daysUntilDue = null;

  final DueDateUrgency urgency;

  /// Number of days until due. Negative if overdue, 0 if today, positive if future.
  /// Null if no due date was provided.
  final int? daysUntilDue;

  /// Whether this status requires urgent styling (overdue or due today).
  bool get isUrgent =>
      urgency == DueDateUrgency.overdue || urgency == DueDateUrgency.dueToday;

  /// Returns the appropriate color for this status, or null for normal.
  Color? get urgentColor {
    switch (urgency) {
      case DueDateUrgency.overdue:
        return taskStatusRed;
      case DueDateUrgency.dueToday:
        return taskStatusOrange;
      case DueDateUrgency.normal:
        return null;
    }
  }
}

/// Calculates the due date status relative to a reference date.
///
/// [dueDate] is the task's due date. If null, returns a non-urgent status.
/// [referenceDate] is the date to compare against (typically today).
DueDateStatus getDueDateStatus({
  required DateTime? dueDate,
  required DateTime referenceDate,
}) {
  if (dueDate == null) {
    return const DueDateStatus.none();
  }

  final today = DateTime(
    referenceDate.year,
    referenceDate.month,
    referenceDate.day,
  );
  final dueDateDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
  final daysUntilDue = dueDateDay.difference(today).inDays;

  final DueDateUrgency urgency;
  if (daysUntilDue < 0) {
    urgency = DueDateUrgency.overdue;
  } else if (daysUntilDue == 0) {
    urgency = DueDateUrgency.dueToday;
  } else {
    urgency = DueDateUrgency.normal;
  }

  return DueDateStatus(
    urgency: urgency,
    daysUntilDue: daysUntilDue,
  );
}
