part of 'unified_daily_os_data_controller.dart';

/// The hour the timeline should start rendering at.
///
/// Returns a default of `8` when there are no slots. Otherwise it takes the
/// earliest start hour across the (pre-sorted) planned and actual slots,
/// subtracts a one-hour lead-in buffer, and clamps the result to `[0, 23]` so
/// the buffer never wraps before midnight.
int calculateDayStartHour(
  List<PlannedTimeSlot> planned,
  List<ActualTimeSlot> actual,
) {
  if (planned.isEmpty && actual.isEmpty) return 8;

  var earliest = 24;

  if (planned.isNotEmpty) {
    final plannedStart = planned.first.startTime.hour;
    if (plannedStart < earliest) earliest = plannedStart;
  }

  if (actual.isNotEmpty) {
    final actualStart = actual.first.startTime.hour;
    if (actualStart < earliest) earliest = actualStart;
  }

  // Add 1 hour buffer before, but not before midnight
  return (earliest - 1).clamp(0, 23);
}

/// The hour the timeline should stop rendering at.
///
/// Returns a default of `18` when there are no slots. Otherwise it takes the
/// latest end hour across all planned and actual slots — slots whose end is on
/// or after the following midnight count as hour `24` — adds a one-hour
/// tail-out buffer, and clamps the result to `[1, 24]`.
int calculateDayEndHour(
  List<PlannedTimeSlot> planned,
  List<ActualTimeSlot> actual,
  DateTime dayStart,
) {
  if (planned.isEmpty && actual.isEmpty) return 18;

  final nextDay = dayStart.add(const Duration(days: 1));
  var latest = 0;

  // Find max end time across all planned slots
  for (final slot in planned) {
    // If entry ends on the next day (crosses midnight), treat as hour 24
    final endHour = !slot.endTime.isBefore(nextDay)
        ? 24
        : slot.endTime.hour + 1;
    if (endHour > latest) latest = endHour;
  }

  // Find max end time across all actual slots
  for (final slot in actual) {
    // If entry ends on the next day (crosses midnight), treat as hour 24
    final endHour = !slot.endTime.isBefore(nextDay)
        ? 24
        : slot.endTime.hour + 1;
    if (endHour > latest) latest = endHour;
  }

  // Add 1 hour buffer after, but not past midnight
  return (latest + 1).clamp(1, 24);
}

/// Classifies a budget by the time remaining: negative remaining is over
/// budget, exactly zero is exhausted, fifteen minutes or less (by whole
/// minutes) is near the limit, anything beyond that is under budget.
BudgetProgressStatus calculateBudgetProgressStatus(
  Duration planned,
  Duration recorded,
) {
  final remaining = planned - recorded;

  if (remaining.isNegative) {
    return BudgetProgressStatus.overBudget;
  } else if (remaining == Duration.zero) {
    return BudgetProgressStatus.exhausted;
  } else if (remaining.inMinutes <= 15) {
    return BudgetProgressStatus.nearLimit;
  } else {
    return BudgetProgressStatus.underBudget;
  }
}
