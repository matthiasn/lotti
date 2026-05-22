import 'dart:core';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/logic/habits/habit_completion_resolution.dart';
import 'package:lotti/utils/date_utils_extension.dart';

class HabitResult extends Equatable {
  const HabitResult({
    required this.dayString,
    required this.completionType,
  });

  final String dayString;
  final HabitCompletionType completionType;

  @override
  String toString() {
    return '$dayString}';
  }

  @override
  List<Object?> get props => [dayString, completionType];
}

/// Day-strip cell color for a completion type, driven by DS tokens.
///
/// Mirrors the Streak Cards palette: success uses the Lotti interactive teal
/// (same as the filled "Success" quick-action), fail uses `alert.error`, skip
/// uses `alert.warning`, and the "open" (no entry recorded) day uses the muted
/// decorative wash so the row reads as a gap rather than a fail.
Color habitCompletionColor(
  DsTokens tokens,
  HabitCompletionType completionType,
) {
  switch (completionType) {
    case HabitCompletionType.success:
      return tokens.colors.interactive.enabled;
    case HabitCompletionType.fail:
      return tokens.colors.alert.error.defaultColor;
    case HabitCompletionType.skip:
      return tokens.colors.alert.warning.defaultColor;
    case HabitCompletionType.open:
      return tokens.colors.decorative.level01;
  }
}

List<HabitResult> habitResultsByDay(
  List<JournalEntity> entities, {
  required HabitDefinition habitDefinition,
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  final rangeStartAtMidnight = rangeStart.dayAtMidnight;
  final rangeEndAtMidnight = rangeEnd.dayAtMidnight;

  final resultsByDay = <String, HabitResult>{};
  final range = rangeEndAtMidnight.dayAtMidnight.difference(
    rangeStartAtMidnight,
  );
  final dayStrings = List<String>.generate(range.inDays + 1, (days) {
    final day = rangeStartAtMidnight.add(Duration(days: days));
    return day.ymd;
  });

  final activeFrom = habitDefinition.activeFrom ?? DateTime(0);
  final activeUntil = habitDefinition.activeUntil ?? DateTime(9999);

  for (final dayString in dayStrings) {
    final day = DateTime.parse(dayString);
    final completionType =
        (day.isAfter(activeFrom) || day == activeFrom) &&
            day.isBefore(activeUntil)
        ? HabitCompletionType.open
        : HabitCompletionType.skip;

    resultsByDay[dayString] = HabitResult(
      dayString: dayString,
      completionType: completionType,
    );
  }

  for (final entity in latestHabitCompletionsByDay(entities)) {
    final dayString = entity.meta.dateFrom.ymd;
    final completionType = entity.data.completionType;

    if (completionType != null) {
      resultsByDay[dayString] = HabitResult(
        dayString: dayString,
        completionType: completionType,
      );
    }
  }

  final aggregated = <HabitResult>[];
  for (final dayString in resultsByDay.keys.sorted()) {
    aggregated.add(resultsByDay[dayString]!);
  }

  return aggregated;
}
