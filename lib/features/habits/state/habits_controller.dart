import 'dart:async';

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/habits/model/habit_completion_record.dart';
import 'package:lotti/features/habits/repository/habits_repository.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/lockdown/state/lockdown_controller.dart';
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

/// Provides the current instant used for habit bucketing and range queries.
/// Tests override this with a fixed clock so midnight and due-time behavior is
/// deterministic without sleeping or consulting the process wall clock.
final habitsNowProvider = Provider<DateTime Function()>((ref) => clock.now);

class HabitsController extends Notifier<HabitsState> {
  StreamSubscription<List<HabitDefinition>>? _definitionsSubscription;
  StreamSubscription<Set<String>>? _updateSubscription;
  StreamSubscription<int>? _navIndexSubscription;

  Timer? _refreshTimer;
  Future<void>? _refreshFuture;
  bool _refreshRequested = false;
  int _generation = 0;

  List<HabitDefinition> _habitDefinitions = [];
  Map<String, HabitDefinition> _habitDefinitionsMap = {};
  List<HabitCompletionRecord> _habitCompletions = [];

  /// Tracks whether a habits-rendering surface (the Habits tab or the
  /// unified Goals tab — see [_isHabitsSurfaceActive]) was active on the
  /// previous nav-index emission. Used to detect the off→on edge that
  /// triggers a recompute — `showHabit()` depends on the current time,
  /// so re-entering such a tab is the cue to refresh the due/later split
  /// without keeping a background ticker alive.
  bool _wasHabitsActive = false;

  /// The previous nav-index emission, so a DIRECT switch between the two
  /// habits-rendering surfaces (Habits tab ↔ unified Goals tab) still counts
  /// as entering one — [_wasHabitsActive] alone stays true across it and
  /// would swallow the refresh.
  int _lastNavIndex = -1;

  late HabitsRepository _repository;
  late final NavService _navService = getIt<NavService>();
  late DateTime Function() _now;

  @override
  HabitsState build() {
    _refreshFuture = null;
    _refreshRequested = false;
    _repository = ref.read(habitsRepositoryProvider);
    _now = ref.read(habitsNowProvider);

    ref.onDispose(_cleanup);

    // Subscribe synchronously inside build() so the subscriptions are
    // anchored to this controller's lifecycle even if disposal races
    // with init — they are guaranteed to be cancelled by _cleanup.
    _wasHabitsActive = _isHabitsSurfaceActive(_navService.index);
    _lastNavIndex = _navService.index;
    _navIndexSubscription = _navService.getIndexStream().listen(
      _handleNavIndex,
    );
    // Entering or leaving lockdown changes the effective category filter
    // without any habit changing, so the visible buckets must be recomputed.
    ref.listen(lockdownControllerProvider, (previous, next) {
      _determineHabitSuccessByDays();
    });
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
    final generation = _generation;
    Future.microtask(() => _startWatching(generation));
    return HabitsState.initial(now: _now());
  }

  void _cleanup() {
    _generation++;
    _refreshTimer?.cancel();
    _definitionsSubscription?.cancel();
    _updateSubscription?.cancel();
    _navIndexSubscription?.cancel();
    EasyDebounce.cancel('clearInfoYmd');
  }

  Future<void> _startWatching(int generation) async {
    if (!ref.mounted || generation != _generation) return;
    // Listen before the first read, so a write arriving during that read
    // requests a trailing refresh instead of being lost.
    _updateSubscription = _repository.updateStream.listen((affectedIds) {
      if (affectedIds.contains(habitCompletionNotification)) {
        _refreshTimer?.cancel();
        _refreshTimer = Timer(const Duration(milliseconds: 200), () {
          _refreshTimer = null;
          unawaited(refreshNow());
        });
      }
    });
    await refreshNow();
  }

  /// Serializes completion reads and collapses requests arriving during a read
  /// into one trailing read with the latest range. All callers await that same
  /// drain; an older result never overwrites the latest requested projection.
  Future<void> _refreshCompletions() {
    if (!ref.mounted) return Future<void>.value();
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _refreshRequested = true;
    final existing = _refreshFuture;
    if (existing != null) return existing;
    final generation = _generation;
    final completer = Completer<void>();
    _refreshFuture = completer.future;
    unawaited(() async {
      try {
        while (_refreshRequested && ref.mounted && generation == _generation) {
          _refreshRequested = false;
          final rangeStart = _now().dayAtMidnight.subtract(
            Duration(days: state.timeSpanDays),
          );
          final completions = await _repository.getHabitCompletionsInRange(
            rangeStart: rangeStart,
          );
          if (!ref.mounted || generation != _generation) break;
          if (!_refreshRequested) {
            _habitCompletions = completions;
            _determineHabitSuccessByDays();
          }
        }
        completer.complete();
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        if (generation == _generation) _refreshFuture = null;
      }
    }());
    return completer.future;
  }

  void _determineHabitSuccessByDays() {
    final completedToday = <String>{};
    final successfulToday = <String>{};
    final autoCompletedToday = <String, String?>{};
    final successfulByDay = <String, Set<String>>{};
    final skippedByDay = <String, Set<String>>{};
    final failedByDay = <String, Set<String>>{};
    final allByDay = <String, Set<String>>{};

    final now = _now();
    final today = now.ymd;

    void addId(Map<String, Set<String>> byDay, String day, String habitId) {
      byDay.putIfAbsent(day, () => <String>{}).add(habitId);
    }

    void removeId(Map<String, Set<String>> byDay, String day, String habitId) {
      byDay[day]?.remove(habitId);
    }

    for (final item in _habitCompletions) {
      final day = item.dateFrom.ymd;

      if (_habitDefinitionsMap.containsKey(item.habitId)) {
        final completionType = item.completionType;
        final habitId = item.habitId;

        if (day == today) {
          completedToday.add(habitId);
          if (item.source == HabitCompletionSource.auto) {
            autoCompletedToday[habitId] = item.autoCompleteReason;
          }
        }

        addId(allByDay, day, habitId);

        if (completionType == HabitCompletionType.success) {
          addId(successfulByDay, day, habitId);
          removeId(skippedByDay, day, habitId);
          removeId(failedByDay, day, habitId);

          if (day == today) {
            successfulToday.add(habitId);
          }
        }

        if (completionType == HabitCompletionType.skip) {
          addId(skippedByDay, day, habitId);
          removeId(successfulByDay, day, habitId);
          removeId(failedByDay, day, habitId);

          if (day == today) {
            successfulToday.add(habitId);
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

    final openNow = openHabits
        .where((item) => showHabit(item, now: now))
        .toList();
    final pendingLater = openHabits
        .where((item) => !showHabit(item, now: now))
        .toList();

    final completed = _habitDefinitions
        .where((item) => completedToday.contains(item.id))
        .sorted(habitSorter);

    final shortStreakDays = daysInRange(
      rangeStart: now.subtract(const Duration(days: 3)),
      rangeEnd: getEndOfToday(now: now),
    );

    final longStreakDays = daysInRange(
      rangeStart: now.subtract(const Duration(days: 7)),
      rangeEnd: getEndOfToday(now: now),
    );

    final habitSuccessDays = <String, Set<String>>{};

    for (final item in _habitCompletions) {
      if (_habitDefinitionsMap.containsKey(item.habitId) &&
          item.completionType == HabitCompletionType.success) {
        final day = item.dateFrom.ymd;
        habitSuccessDays.putIfAbsent(item.habitId, () => <String>{}).add(day);
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

    // Lockdown clamps the user's category filter to the locked set (an
    // empty filter becomes the locked set, never "all"), so a demo shows
    // only the locked category's habits whatever the chips say.
    final selectedCategoryIds = ref
        .read(lockdownControllerProvider)
        .restrict(state.selectedCategoryIds);

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

    final days = getHabitDays(state.timeSpanDays, now: now);

    // Build intermediate state with all freshly computed fields
    // so habitMinY can use accurate data from totalForDay
    final nextState = state.copyWith(
      habitDefinitions: _habitDefinitions,
      habitCompletions: _habitCompletions,
      completedToday: completedToday,
      autoCompletedToday: autoCompletedToday,
      openHabits: openHabits,
      openNow: filteredOpenNow,
      pendingLater: filteredPendingLater,
      completed: filteredCompleted,
      openNowAll: openNow,
      pendingLaterAll: pendingLater,
      completedAll: completed,
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

  /// Recomputes habit success on the inactive→active edge of a
  /// habits-rendering surface (Habits tab or unified Goals tab) — time may
  /// have passed while the tab was off-screen, so the
  /// due/later split needs refreshing. Refetches completions first so a
  /// midnight rollover (which extends the relevant day range) is also
  /// reflected, not just the wall-clock-driven `showHabit` bucketing.
  Future<void> _handleNavIndex(int newIndex) async {
    if (!ref.mounted) return;

    final isHabitsActive = _isHabitsSurfaceActive(newIndex);
    final wasActive = _wasHabitsActive;
    final switchedTab = newIndex != _lastNavIndex;
    _wasHabitsActive = isHabitsActive;
    _lastNavIndex = newIndex;

    if (isHabitsActive && (!wasActive || switchedTab)) {
      await refreshNow();
    }
  }

  /// Refetches completions and rebuckets for the current instant — the
  /// day-boundary refresh a habits-rendering surface requests when its own
  /// midnight timer fires while it stays mounted (no nav emission, no
  /// database event): `showHabit` bucketing and the per-day maps are
  /// time-derived and would otherwise serve yesterday's split.
  Future<void> refreshNow() async {
    await _refreshCompletions();
  }

  /// Whether [navIndex] is a tab that renders habit rows from this
  /// controller. The unified Goals page (flag-gated) reuses the habits state
  /// wholesale, so it must trigger the same on-activation refresh the Habits
  /// tab gets — otherwise its rows would go stale the moment the old tab is
  /// disabled. A disabled tab's index getter returns -1, which no live
  /// [navIndex] matches.
  bool _isHabitsSurfaceActive(int navIndex) =>
      navIndex == _navService.habitsIndex || navIndex == _navService.goalsIndex;

  /// Sets the time span for habit history display.
  Future<void> setTimeSpan(int timeSpanDays) async {
    state = state.copyWith(
      timeSpanDays: timeSpanDays,
      days: getHabitDays(timeSpanDays, now: _now()),
    );
    await refreshNow();
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
