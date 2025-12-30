import 'dart:math';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/charts/utils.dart';

part 'habits_state.freezed.dart';

/// Display filter for habits page.
enum HabitDisplayFilter { openNow, pendingLater, completed, all }

/// Immutable state for the habits page.
@freezed
abstract class HabitsState with _$HabitsState {
  const factory HabitsState({
    required List<HabitDefinition> habitDefinitions,
    required List<HabitDefinition> openHabits,
    required List<HabitDefinition> openNow,
    required List<HabitDefinition> pendingLater,
    required List<HabitDefinition> completed,
    required List<JournalEntity> habitCompletions,
    required Set<String> completedToday,
    required Set<String> successfulToday,
    required Set<String> selectedCategoryIds,
    required List<String> days,
    required Map<String, Set<String>> successfulByDay,
    required Map<String, Set<String>> skippedByDay,
    required Map<String, Set<String>> failedByDay,
    required Map<String, Set<String>> allByDay,
    required int successPercentage,
    required int skippedPercentage,
    required int failedPercentage,
    required String selectedInfoYmd,
    required int shortStreakCount,
    required int longStreakCount,
    required int timeSpanDays,
    required double minY,
    required bool zeroBased,
    required bool isVisible,
    required bool showTimeSpan,
    required bool showSearch,
    required String searchString,
    required HabitDisplayFilter displayFilter,
  }) = _HabitsState;

  /// Creates the initial state with default values.
  factory HabitsState.initial() => HabitsState(
        habitDefinitions: [],
        habitCompletions: [],
        completedToday: <String>{},
        openHabits: [],
        openNow: [],
        pendingLater: [],
        completed: [],
        days: getHabitDays(isDesktop ? 14 : 7),
        successfulToday: <String>{},
        successfulByDay: <String, Set<String>>{},
        skippedByDay: <String, Set<String>>{},
        failedByDay: <String, Set<String>>{},
        allByDay: <String, Set<String>>{},
        selectedInfoYmd: '',
        successPercentage: 0,
        skippedPercentage: 0,
        failedPercentage: 0,
        shortStreakCount: 0,
        longStreakCount: 0,
        timeSpanDays: isDesktop ? 14 : 7,
        zeroBased: true,
        minY: 0,
        displayFilter: HabitDisplayFilter.openNow,
        showSearch: false,
        showTimeSpan: false,
        searchString: '',
        selectedCategoryIds: <String>{},
        isVisible: true,
      );
}

/// Calculates the completion rate for a given day.
int completionRate(
  HabitsState state,
  Map<String, Set<String>> byDay,
) {
  final completionsByTypeOnDay = byDay[state.selectedInfoYmd] ?? {};
  final n = completionsByTypeOnDay.length;
  final total = totalForDay(state.selectedInfoYmd, state);

  if (total == 0) {
    return 0;
  }

  final percentage = (n / total) * 100;
  return percentage.round();
}

/// Counts the total habits that should be tracked for a given day.
int totalForDay(String ymd, HabitsState state) {
  final activeHabitIds = activeBy(
    state.habitDefinitions,
    ymd,
  ).map((habitDefinition) => habitDefinition.id).toSet();
  final allByDay = state.allByDay[ymd] ?? {};
  return allByDay.union(activeHabitIds).length;
}

/// Filters habit definitions to those active by a given date.
List<HabitDefinition> activeBy(
  List<HabitDefinition> habitDefinitions,
  String ymd,
) {
  if (ymd.isEmpty) {
    return [];
  }
  final activeHabits = habitDefinitions.where((habitDefinition) {
    final activeFrom = habitDefinition.activeFrom ?? DateTime(0);
    return !DateTime(activeFrom.year, activeFrom.month, activeFrom.day)
        .isAfter(DateTime.parse(ymd));
  }).toList();

  return activeHabits;
}

/// Calculates the minimum Y value for the chart.
double habitMinY({
  required List<String> days,
  required HabitsState state,
}) {
  double? lowest;

  for (final day in days) {
    final total = totalForDay(day, state);
    if (total > 0) {
      final n = state.successfulByDay[day]?.length ?? 0;
      final rate = 100 * n / total;
      lowest = lowest == null ? rate : min(lowest, rate);
    }
  }

  // Return 0 if no valid days with habits, otherwise apply the -20 offset
  if (lowest == null) {
    return 0;
  }
  return max(lowest - 20, 0);
}

/// Generates a list of date strings for the given time span.
List<String> getHabitDays(int timeSpanDays) {
  final now = DateTime.now();
  final days = daysInRange(
    rangeStart: now.dayAtMidnight.subtract(Duration(days: timeSpanDays)),
    rangeEnd: now,
  )..sort();
  return days;
}
