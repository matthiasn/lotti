import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/habits/repository/habits_repository.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:visibility_detector/visibility_detector.dart';

part 'habits_controller.g.dart';

/// Notifier managing the complete habits page state.
/// Marked as keepAlive since habits state should persist across navigation.
@Riverpod(keepAlive: true)
class HabitsController extends _$HabitsController {
  StreamSubscription<List<HabitDefinition>>? _definitionsSubscription;
  StreamSubscription<Set<String>>? _updateSubscription;

  List<HabitDefinition> _habitDefinitions = [];
  Map<String, HabitDefinition> _habitDefinitionsMap = {};
  List<JournalEntity> _habitCompletions = [];

  late HabitsRepository _repository;

  @override
  HabitsState build() {
    _repository = ref.read(habitsRepositoryProvider);

    ref.onDispose(_cleanup);
    // Schedule initialization after build() completes to avoid
    // reading state before it's initialized
    Future.microtask(_init);
    return HabitsState.initial();
  }

  void _cleanup() {
    _definitionsSubscription?.cancel();
    _updateSubscription?.cancel();
    EasyDebounce.cancel('clearInfoYmd');
  }

  Future<void> _init() async {
    _definitionsSubscription =
        _repository.watchHabitDefinitions().listen((habitDefinitions) {
      _habitDefinitions =
          habitDefinitions.where((habit) => habit.active).toList();

      _habitDefinitionsMap = <String, HabitDefinition>{};

      for (final habitDefinition in _habitDefinitions) {
        _habitDefinitionsMap[habitDefinition.id] = habitDefinition;
      }

      _determineHabitSuccessByDays();
    });

    await _startWatching();
  }

  Future<void> _startWatching() async {
    await _fetchHabitCompletions();
    _determineHabitSuccessByDays();

    _updateSubscription = _repository.updateStream.listen((affectedIds) async {
      if (affectedIds.contains(habitCompletionNotification)) {
        await _fetchHabitCompletions();
        await Future<void>.delayed(const Duration(milliseconds: 200));
        _determineHabitSuccessByDays();
      }
    });
  }

  Future<void> _fetchHabitCompletions() async {
    final rangeStart = DateTime.now().dayAtMidnight.subtract(
          Duration(days: state.timeSpanDays),
        );
    _habitCompletions = await _repository.getHabitCompletionsInRange(
      rangeStart: rangeStart,
    );
  }

  void _determineHabitSuccessByDays() {
    final completedToday = <String>{};
    final successfulToday = <String>{};
    final successfulByDay = <String, Set<String>>{};
    final skippedByDay = <String, Set<String>>{};
    final failedByDay = <String, Set<String>>{};
    final allByDay = <String, Set<String>>{};

    final today = DateTime.now().ymd;

    void addId(Map<String, Set<String>> byDay, String day, String habitId) {
      byDay.putIfAbsent(day, () => <String>{}).add(habitId);
    }

    void removeId(Map<String, Set<String>> byDay, String day, String habitId) {
      byDay[day]?.remove(habitId);
    }

    for (final item in _habitCompletions) {
      final day = item.meta.dateFrom.ymd;

      if (item is HabitCompletionEntry &&
          _habitDefinitionsMap.containsKey(item.data.habitId)) {
        final completionType = item.data.completionType;
        final habitId = item.data.habitId;

        if (day == today) {
          completedToday.add(item.data.habitId);
        }

        addId(allByDay, day, habitId);

        if (completionType == HabitCompletionType.success) {
          addId(successfulByDay, day, habitId);
          removeId(skippedByDay, day, habitId);
          removeId(failedByDay, day, habitId);

          if (day == today) {
            successfulToday.add(item.data.habitId);
          }
        }

        if (completionType == HabitCompletionType.skip) {
          addId(skippedByDay, day, habitId);
          removeId(successfulByDay, day, habitId);
          removeId(failedByDay, day, habitId);

          if (day == today) {
            successfulToday.add(item.data.habitId);
          }
        }

        if (completionType == HabitCompletionType.fail) {
          addId(failedByDay, day, habitId);
          removeId(skippedByDay, day, habitId);
          removeId(successfulByDay, day, habitId);
        }
      }
    }

    final openHabits = _habitDefinitions
        .where((item) => !completedToday.contains(item.id))
        .sorted(habitSorter);

    final openNow = openHabits.where(showHabit).toList();
    final pendingLater = openHabits.where((item) => !showHabit(item)).toList();

    final completed = _habitDefinitions
        .where((item) => completedToday.contains(item.id))
        .sorted(habitSorter);

    final now = DateTime.now();

    final shortStreakDays = daysInRange(
      rangeStart: now.subtract(const Duration(days: 3)),
      rangeEnd: getEndOfToday(),
    );

    final longStreakDays = daysInRange(
      rangeStart: now.subtract(const Duration(days: 7)),
      rangeEnd: getEndOfToday(),
    );

    final habitSuccessDays = <String, Set<String>>{};

    for (final item in _habitCompletions) {
      if (item is HabitCompletionEntry &&
          _habitDefinitionsMap.containsKey(item.data.habitId) &&
          (item.data.completionType == HabitCompletionType.success ||
              item.data.completionType == HabitCompletionType.skip ||
              item.data.completionType == null)) {
        final day = item.meta.dateFrom.ymd;
        habitSuccessDays
            .putIfAbsent(item.data.habitId, () => <String>{})
            .add(day);
      }
    }

    var shortStreakCount = 0;
    var longStreakCount = 0;

    habitSuccessDays.forEach((habitId, days) {
      if (days.containsAll(shortStreakDays)) {
        shortStreakCount++;
      }

      if (days.containsAll(longStreakDays)) {
        longStreakCount++;
      }
    });

    final selectedCategoryIds = state.selectedCategoryIds;

    final filteredOpenNow = selectedCategoryIds.isEmpty
        ? openNow
        : openNow
            .where(
              (habit) => selectedCategoryIds.contains(habit.categoryId),
            )
            .toList();

    final filteredPendingLater = selectedCategoryIds.isEmpty
        ? pendingLater
        : pendingLater
            .where(
              (habit) => selectedCategoryIds.contains(habit.categoryId),
            )
            .toList();

    final filteredCompleted = selectedCategoryIds.isEmpty
        ? completed
        : completed
            .where(
              (habit) => selectedCategoryIds.contains(habit.categoryId),
            )
            .toList();

    final days = getHabitDays(state.timeSpanDays);

    // Build intermediate state with all freshly computed fields
    // so habitMinY can use accurate data from totalForDay
    final nextState = state.copyWith(
      habitDefinitions: _habitDefinitions,
      habitCompletions: _habitCompletions,
      completedToday: completedToday,
      openHabits: openHabits,
      openNow: filteredOpenNow,
      pendingLater: filteredPendingLater,
      completed: filteredCompleted,
      days: days,
      successfulToday: successfulToday,
      successfulByDay: successfulByDay,
      skippedByDay: skippedByDay,
      failedByDay: failedByDay,
      allByDay: allByDay,
      shortStreakCount: shortStreakCount,
      longStreakCount: longStreakCount,
      isVisible: state.isVisible,
    );

    state = nextState.copyWith(
      minY: habitMinY(days: days, state: nextState),
    );
  }

  /// Updates visibility state based on widget visibility.
  void updateVisibility(VisibilityInfo visibilityInfo) {
    // Guard against callback after disposal
    if (!ref.mounted) return;

    final isVisible = visibilityInfo.visibleBounds.size.width > 0;
    final wasNotVisible = !state.isVisible;

    if (wasNotVisible && isVisible) {
      _determineHabitSuccessByDays();
    }

    state = state.copyWith(isVisible: isVisible);
  }

  /// Sets the time span for habit history display.
  Future<void> setTimeSpan(int timeSpanDays) async {
    state = state.copyWith(
      timeSpanDays: timeSpanDays,
      days: getHabitDays(timeSpanDays),
    );
    await _fetchHabitCompletions();
    _determineHabitSuccessByDays();
  }

  /// Sets the display filter for habits.
  void setDisplayFilter(HabitDisplayFilter? displayFilter) {
    if (displayFilter == null) {
      return;
    }
    state = state.copyWith(displayFilter: displayFilter);
  }

  /// Sets the search string for filtering habits.
  void setSearchString(String searchString) {
    state = state.copyWith(searchString: searchString.toLowerCase());
  }

  /// Toggles whether the chart is zero-based.
  void toggleZeroBased() {
    state = state.copyWith(zeroBased: !state.zeroBased);
  }

  /// Toggles the search UI visibility.
  void toggleShowSearch() {
    state = state.copyWith(showSearch: !state.showSearch);
  }

  /// Toggles the time span selector visibility.
  void toggleShowTimeSpan() {
    state = state.copyWith(showTimeSpan: !state.showTimeSpan);
  }

  /// Toggles a category ID in the selected categories filter.
  void toggleSelectedCategoryIds(String categoryId) {
    final currentIds = state.selectedCategoryIds;
    final newIds = currentIds.contains(categoryId)
        ? (Set<String>.from(currentIds)..remove(categoryId))
        : (Set<String>.from(currentIds)..add(categoryId));

    state = state.copyWith(selectedCategoryIds: newIds);
    _determineHabitSuccessByDays();
  }

  /// Sets the selected day for info display in the chart.
  void setInfoYmd(String ymd) {
    final newState = state.copyWith(selectedInfoYmd: ymd);
    final successPercentage =
        completionRate(newState, newState.successfulByDay);
    final skippedPercentage = completionRate(newState, newState.skippedByDay);
    final failedPercentage = min(
      completionRate(newState, newState.failedByDay),
      100 - successPercentage - skippedPercentage,
    );

    state = newState.copyWith(
      successPercentage: successPercentage,
      skippedPercentage: skippedPercentage,
      failedPercentage: failedPercentage,
    );

    EasyDebounce.debounce(
      'clearInfoYmd',
      const Duration(seconds: 15),
      () => setInfoYmd(''),
    );
  }
}
