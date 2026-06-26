import 'dart:async';

import 'package:collection/collection.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/habits/repository/habits_repository.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/charts/utils.dart';

/// Owns the whole [HabitsState] for the habits tab.
///
/// Subscribes to three sources and recomputes derived state whenever any
/// fires: the repository's habit-definition stream, the update stream filtered
/// for `habitCompletionNotification`, and the nav-index stream (to refresh the
/// time-sensitive due/later split when the tab is re-entered). The heavy lift
/// is _determineHabitSuccessByDays, which buckets completions into the
/// per-day maps, splits open habits into due-now vs. pending-later via
/// `showHabit`, applies the category filter, counts streaks and recomputes the
/// chart's [HabitsState.minY].
///
/// Marked `keepAlive` so the (relatively expensive) state survives navigating
/// away from and back to the tab.
final habitsControllerProvider =
    NotifierProvider<HabitsController, HabitsState>(
      HabitsController.new,
      name: 'habitsControllerProvider',
    );

class HabitsController extends Notifier<HabitsState> {
  StreamSubscription<List<HabitDefinition>>? _definitionsSubscription;
  StreamSubscription<Set<String>>? _updateSubscription;
  StreamSubscription<int>? _navIndexSubscription;

  List<HabitDefinition> _habitDefinitions = [];
  Map<String, HabitDefinition> _habitDefinitionsMap = {};
  List<JournalEntity> _habitCompletions = [];

  /// Tracks whether the habits tab was the active top-level tab on the
  /// previous nav-index emission. Used to detect the off→on edge that
  /// triggers a recompute — `showHabit()` depends on `DateTime.now()`,
  /// so re-entering the tab is the cue to refresh the due/later split
  /// without keeping a background ticker alive.
  bool _wasHabitsActive = false;

  late HabitsRepository _repository;
  late final NavService _navService = getIt<NavService>();

  @override
  HabitsState build() {
    _repository = ref.read(habitsRepositoryProvider);

    ref.onDispose(_cleanup);

    // Subscribe synchronously inside build() so the subscriptions are
    // anchored to this controller's lifecycle even if disposal races
    // with init — they are guaranteed to be cancelled by _cleanup.
    _wasHabitsActive = _navService.index == _navService.habitsIndex;
    _navIndexSubscription = _navService.getIndexStream().listen(
      _handleNavIndex,
    );
    _definitionsSubscription = _repository.watchHabitDefinitions().listen((
      habitDefinitions,
    ) {
      _habitDefinitions = habitDefinitions
          .where((habit) => habit.active)
          .toList();

      _habitDefinitionsMap = <String, HabitDefinition>{};

      for (final habitDefinition in _habitDefinitions) {
        _habitDefinitionsMap[habitDefinition.id] = habitDefinition;
      }

      _determineHabitSuccessByDays();
    });

    // The initial fetch + update-stream subscription is async, so it
    // runs as a microtask. The mounted-guard inside _startWatching
    // avoids touching disposed state if the provider is torn down
    // before the microtask drains.
    Future.microtask(_startWatching);
    return HabitsState.initial();
  }

  void _cleanup() {
    _definitionsSubscription?.cancel();
    _updateSubscription?.cancel();
    _navIndexSubscription?.cancel();
    EasyDebounce.cancel('clearInfoYmd');
  }

  Future<void> _startWatching() async {
    if (!ref.mounted) return;
    await _fetchHabitCompletions();
    if (!ref.mounted) return;
    _determineHabitSuccessByDays();

    _updateSubscription = _repository.updateStream.listen((affectedIds) async {
      if (affectedIds.contains(habitCompletionNotification)) {
        await _fetchHabitCompletions();
        await Future<void>.delayed(const Duration(milliseconds: 200));
        if (!ref.mounted) return;
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

    final shortStreakCount = countHabitsWithStreak(
      habitSuccessDays,
      shortStreakDays,
    );
    final longStreakCount = countHabitsWithStreak(
      habitSuccessDays,
      longStreakDays,
    );

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
    );

    state = nextState.copyWith(
      minY: habitMinY(days: days, state: nextState),
    );
  }

  /// Recomputes habit success on the inactive→active edge of the habits
  /// tab — time may have passed while the tab was off-screen, so the
  /// due/later split needs refreshing. Refetches completions first so a
  /// midnight rollover (which extends the relevant day range) is also
  /// reflected, not just the wall-clock-driven `showHabit` bucketing.
  Future<void> _handleNavIndex(int newIndex) async {
    if (!ref.mounted) return;

    final isHabitsActive = newIndex == _navService.habitsIndex;
    final wasActive = _wasHabitsActive;
    _wasHabitsActive = isHabitsActive;

    if (isHabitsActive && !wasActive) {
      await _fetchHabitCompletions();
      if (!ref.mounted) return;
      _determineHabitSuccessByDays();
    }
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

  /// Replaces the selected categories filter in a single write (used by the
  /// deferred category picker, which commits the whole set on Apply).
  void setSelectedCategoryIds(Set<String> categoryIds) {
    state = state.copyWith(selectedCategoryIds: {...categoryIds});
    _determineHabitSuccessByDays();
  }

  /// Selects [ymd] as the day whose success/skipped/failed breakdown the chart
  /// popover shows, recomputing the three percentages via [dayPercentages].
  ///
  /// Schedules a debounced self-call with an empty `ymd` 15 seconds later so
  /// the popover auto-dismisses; a fresh tap restarts the timer. Passing `''`
  /// (the debounce callback's own argument) clears the selection.
  void setInfoYmd(String ymd) {
    final newState = state.copyWith(selectedInfoYmd: ymd);
    final percentages = dayPercentages(newState);

    state = newState.copyWith(
      successPercentage: percentages.success,
      skippedPercentage: percentages.skipped,
      failedPercentage: percentages.failed,
    );

    EasyDebounce.debounce(
      'clearInfoYmd',
      const Duration(seconds: 15),
      () => setInfoYmd(''),
    );
  }
}

/// Counts the habits whose success-day sets cover every day in [streakDays].
///
/// A habit only counts toward a streak when it has a qualifying completion
/// on each day of the window — a single missing day disqualifies it.
int countHabitsWithStreak(
  Map<String, Set<String>> habitSuccessDays,
  List<String> streakDays,
) {
  return habitSuccessDays.values
      .where((days) => days.containsAll(streakDays))
      .length;
}
