import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';

part 'habits_state.freezed.dart';

enum HabitDisplayFilter {
  openNow,
  pendingLater,
  completed,
  all,
}

@freezed
abstract class HabitsState with _$HabitsState {
  factory HabitsState({
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
  }) = _HabitsStateSaved;
}
