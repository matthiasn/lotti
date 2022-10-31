import 'dart:core';

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/themes/themes.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/charts/utils.dart';

class HabitResult extends Equatable {
  const HabitResult(this.dayString, this.hexColor);

  final String dayString;
  final String hexColor;

  @override
  String toString() {
    return '$dayString $hexColor}';
  }

  @override
  List<Object?> get props => [dayString, hexColor];
}

final successColor = colorToCssHex(primaryColor);
final failColor = colorToCssHex(alarm);
final skipColor = colorToCssHex(
  styleConfig().secondaryTextColor.withOpacity(0.4),
);

List<HabitResult> habitResultsByDay(
  List<JournalEntity> entities, {
  required HabitDefinition habitDefinition,
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  final resultsByDay = <String, String>{};
  final range = rangeEnd.difference(rangeStart);
  final dayStrings = List<String>.generate(range.inDays + 1, (days) {
    final day = rangeStart.add(Duration(days: days));
    return ymd(day);
  });

  final activeFrom = habitDefinition.activeFrom ?? DateTime(0);
  final activeUntil = habitDefinition.activeUntil ?? DateTime(9999);

  for (final dayString in dayStrings) {
    final day = DateTime.parse(dayString);
    final hexColor = (day.isAfter(activeFrom) || day == activeFrom) &&
            day.isBefore(activeUntil)
        ? failColor
        : skipColor;

    resultsByDay[dayString] = hexColor;
  }

  for (final entity in entities.sortedBy((entity) => entity.meta.dateFrom)) {
    final dayString = ymd(entity.meta.dateFrom);
    final hexColor = entity.maybeMap(
      habitCompletion: (completion) {
        final completionType = completion.data.completionType;
        final hexColor = completionType == HabitCompletionType.fail
            ? failColor
            : completionType == HabitCompletionType.skip
                ? skipColor
                : successColor;

        return hexColor;
      },
      orElse: () => skipColor,
    );

    resultsByDay[dayString] = hexColor;
  }

  final aggregated = <HabitResult>[];
  for (final dayString in resultsByDay.keys.sorted()) {
    aggregated.add(HabitResult(dayString, resultsByDay[dayString]!));
  }

  return aggregated;
}
