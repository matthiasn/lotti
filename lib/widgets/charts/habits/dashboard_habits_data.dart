import 'dart:core';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/themes/themes.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/charts/utils.dart';

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
  List<Object?> get props => [dayString];
}

final successColor = colorToCssHex(primaryColor);
final failColor = colorToCssHex(alarm);
final skipColor = colorToCssHex(
  styleConfig().secondaryTextColor.withOpacity(0.4),
);

String hexColorForHabitCompletion(HabitCompletionType completionType) {
  return completionType == HabitCompletionType.fail
      ? failColor
      : completionType == HabitCompletionType.skip
          ? skipColor
          : successColor;
}

Color habitCompletionColor(HabitCompletionType completionType) {
  return completionType == HabitCompletionType.fail
      ? alarm
      : completionType == HabitCompletionType.skip
          ? styleConfig().secondaryTextColor.withOpacity(0.4)
          : completionType == HabitCompletionType.success
              ? primaryColor
              : alarm.withOpacity(0.6);
}

List<HabitResult> habitResultsByDay(
  List<JournalEntity> entities, {
  required HabitDefinition habitDefinition,
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  final resultsByDay = <String, HabitResult>{};
  final range = rangeEnd.difference(rangeStart);
  final dayStrings = List<String>.generate(range.inDays + 1, (days) {
    final day = rangeStart.add(Duration(days: days));
    return ymd(day);
  });

  final activeFrom = habitDefinition.activeFrom ?? DateTime(0);
  final activeUntil = habitDefinition.activeUntil ?? DateTime(9999);

  for (final dayString in dayStrings) {
    final day = DateTime.parse(dayString);
    final completionType = (day.isAfter(activeFrom) || day == activeFrom) &&
            day.isBefore(activeUntil)
        ? HabitCompletionType.open
        : HabitCompletionType.skip;

    resultsByDay[dayString] = HabitResult(
      dayString: dayString,
      completionType: completionType,
    );
  }

  for (final entity in entities.sortedBy((entity) => entity.meta.dateFrom)) {
    final dayString = ymd(entity.meta.dateFrom);

    final completionType = entity.maybeMap(
      habitCompletion: (completion) {
        final completionType = completion.data.completionType;
        return completionType;
      },
      orElse: () => null,
    );

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
