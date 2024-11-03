import 'dart:async';
import 'dart:math';

import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:lotti/blocs/habits/habits_state.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:rxdart/rxdart.dart';
import 'package:visibility_detector/visibility_detector.dart';

class HabitsCubit extends Cubit<HabitsState> {
  HabitsCubit()
      : super(
          HabitsState(
            habitDefinitions: [],
            habitCompletions: [],
            completedToday: <String>{},
            openHabits: [],
            openNow: [],
            pendingLater: [],
            completed: [],
            days: getDays(14),
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
            timeSpanDays: 14,
            zeroBased: false,
            minY: 0,
            displayFilter: HabitDisplayFilter.openNow,
            showSearch: false,
            showTimeSpan: false,
            searchString: '',
            selectedCategoryIds: <String>{},
            isVisible: true,
          ),
        ) {
    _definitionsStream = _journalDb.watchHabitDefinitions();

    _definitionsSubscription = _definitionsStream.listen((habitDefinitions) {
      _habitDefinitions =
          habitDefinitions.where((habit) => habit.active).toList();

      _habitDefinitionsMap = <String, HabitDefinition>{};

      for (final habitDefinition in _habitDefinitions) {
        _habitDefinitionsMap[habitDefinition.id] = habitDefinition;
      }

      determineHabitSuccessByDays();
    });

    startWatching();
  }

  void updateVisibility(VisibilityInfo visibilityInfo) {
    final isVisible = visibilityInfo.visibleBounds.size.width > 0;
    if (!_isVisible && isVisible) {
      determineHabitSuccessByDays();
    }
    _isVisible = isVisible;
    emitState();
  }

  void startWatching() {
    _completionsStream = _journalDb
        .watchHabitCompletionsInRange(
          rangeStart: getStartOfDay(
            DateTime.now().subtract(const Duration(days: 180)),
          ),
        )
        .throttleTime(
          const Duration(seconds: 5),
          trailing: true,
          leading: true,
        );

    _completionsSubscription = _completionsStream.listen((habitCompletions) {
      _habitCompletions = habitCompletions;
      if (_isVisible) {
        determineHabitSuccessByDays();
      }
    });
  }

  void determineHabitSuccessByDays() {
    _completedToday = <String>{};
    _successfulToday = <String>{};
    _successfulByDay = <String, Set<String>>{};
    _skippedByDay = <String, Set<String>>{};
    _failedByDay = <String, Set<String>>{};

    final today = DateTime.now().ymd;

    void addId(Map<String, Set<String>> byDay, String day, String habitId) {
      byDay[day] = byDay[day] ?? <String>{}
        ..add(habitId);
    }

    void removeId(Map<String, Set<String>> byDay, String day, String habitId) {
      byDay[day] = byDay[day] ?? <String>{}
        ..remove(habitId);
    }

    for (final item in _habitCompletions) {
      final day = item.meta.dateFrom.ymd;

      if (item is HabitCompletionEntry &&
          _habitDefinitionsMap.containsKey(item.data.habitId)) {
        final completionType = item.data.completionType;
        final habitId = item.data.habitId;

        if (day == today) {
          _completedToday.add(item.data.habitId);
        }

        addId(_allByDay, day, habitId);

        if (completionType == HabitCompletionType.success) {
          addId(_successfulByDay, day, habitId);
          removeId(_skippedByDay, day, habitId);
          removeId(_failedByDay, day, habitId);

          if (day == today) {
            _successfulToday.add(item.data.habitId);
          }
        }

        if (completionType == HabitCompletionType.skip) {
          addId(_skippedByDay, day, habitId);
          removeId(_successfulByDay, day, habitId);
          removeId(_failedByDay, day, habitId);

          if (day == today) {
            _successfulToday.add(item.data.habitId);
          }
        }

        if (completionType == HabitCompletionType.fail) {
          addId(_failedByDay, day, habitId);
          removeId(_skippedByDay, day, habitId);
          removeId(_successfulByDay, day, habitId);
        }
      }
    }

    _openHabits = _habitDefinitions
        .where((item) => !_completedToday.contains(item.id))
        .sorted(habitSorter);

    _openNow = _openHabits.where(showHabit).toList();
    _pendingLater = _openHabits.where((item) => !showHabit(item)).toList();

    _completed = _habitDefinitions
        .where((item) => _completedToday.contains(item.id))
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
        final successDays = habitSuccessDays[item.data.habitId] ?? <String>{}
          ..add(day);
        habitSuccessDays[item.data.habitId] = successDays;
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

    _shortStreakCount = shortStreakCount;
    _longStreakCount = longStreakCount;

    emitState();
  }

  List<HabitDefinition> _habitDefinitions = [];
  Map<String, HabitDefinition> _habitDefinitionsMap = {};
  List<HabitDefinition> _openHabits = [];
  List<HabitDefinition> _openNow = [];
  bool _isVisible = true;
  List<HabitDefinition> _pendingLater = [];
  List<HabitDefinition> _completed = [];
  List<JournalEntity> _habitCompletions = [];
  HabitDisplayFilter _displayFilter = HabitDisplayFilter.openNow;

  var _completedToday = <String>{};
  final _selectedCategoryIds = <String>{};
  var _successfulToday = <String>{};
  final _allByDay = <String, Set<String>>{};
  var _successfulByDay = <String, Set<String>>{};
  var _skippedByDay = <String, Set<String>>{};
  var _failedByDay = <String, Set<String>>{};

  var _successPercentage = 0;
  var _skippedPercentage = 0;
  var _failedPercentage = 0;

  var _shortStreakCount = 0;
  var _longStreakCount = 0;
  var _zeroBased = true;
  var _showTimeSpan = false;
  var _showSearch = false;
  var _searchString = 'false';
  var _timeSpanDays = isDesktop ? 14 : 7;
  var _selectedInfoYmd = '';

  void setTimeSpan(int timeSpanDays) {
    _timeSpanDays = timeSpanDays;
    emitState();
  }

  void setDisplayFilter(HabitDisplayFilter? displayFilter) {
    if (displayFilter == null) {
      return;
    }
    _displayFilter = displayFilter;
    emitState();
  }

  void setSearchString(String searchString) {
    _searchString = searchString.toLowerCase();
    emitState();
  }

  void toggleZeroBased() {
    _zeroBased = !_zeroBased;
    emitState();
  }

  void toggleShowSearch() {
    _showSearch = !_showSearch;
    emitState();
  }

  void toggleShowTimeSpan() {
    _showTimeSpan = !_showTimeSpan;
    emitState();
  }

  void toggleSelectedCategoryIds(String categoryId) {
    if (_selectedCategoryIds.contains(categoryId)) {
      _selectedCategoryIds.remove(categoryId);
    } else {
      _selectedCategoryIds.add(categoryId);
    }
    emitState();
  }

  void setInfoYmd(String ymd) {
    _selectedInfoYmd = ymd;
    _successPercentage = completionRate(state, state.successfulByDay);
    _skippedPercentage = completionRate(state, state.skippedByDay);
    _failedPercentage = min(
      completionRate(state, state.failedByDay),
      100 - _successPercentage - _skippedPercentage,
    );

    emitState();

    EasyDebounce.debounce(
      'clearInfoYmd',
      const Duration(seconds: 15),
      () => setInfoYmd(''),
    );
  }

  final JournalDb _journalDb = getIt<JournalDb>();

  late final Stream<List<HabitDefinition>> _definitionsStream;
  late final StreamSubscription<List<HabitDefinition>> _definitionsSubscription;

  late Stream<List<JournalEntity>> _completionsStream;
  late final StreamSubscription<List<JournalEntity>> _completionsSubscription;

  void emitState() {
    emit(
      HabitsState(
        habitDefinitions: _habitDefinitions,
        habitCompletions: _habitCompletions,
        completedToday: _completedToday,
        openHabits: _openHabits,
        openNow: _selectedCategoryIds.isEmpty
            ? _openNow
            : _openNow
                .where(
                  (habit) => _selectedCategoryIds.contains(habit.categoryId),
                )
                .toList(),
        pendingLater: _selectedCategoryIds.isEmpty
            ? _pendingLater
            : _pendingLater
                .where(
                  (habit) => _selectedCategoryIds.contains(habit.categoryId),
                )
                .toList(),
        completed: _selectedCategoryIds.isEmpty
            ? _completed
            : _completed
                .where(
                  (habit) => _selectedCategoryIds.contains(habit.categoryId),
                )
                .toList(),
        days: getDays(_timeSpanDays),
        successfulToday: _successfulToday,
        successfulByDay: _successfulByDay,
        failedByDay: _failedByDay,
        selectedInfoYmd: _selectedInfoYmd,
        successPercentage: _successPercentage,
        skippedPercentage: _skippedPercentage,
        failedPercentage: _failedPercentage,
        skippedByDay: _skippedByDay,
        allByDay: _allByDay,
        shortStreakCount: _shortStreakCount,
        longStreakCount: _longStreakCount,
        timeSpanDays: _timeSpanDays,
        zeroBased: _zeroBased,
        minY: minY(
          days: getDays(_timeSpanDays),
          state: state,
        ),
        displayFilter: _displayFilter,
        showTimeSpan: _showTimeSpan,
        showSearch: _showSearch,
        searchString: _searchString,
        selectedCategoryIds: <String>{..._selectedCategoryIds},
        isVisible: _isVisible,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _definitionsSubscription.cancel();
    await _completionsSubscription.cancel();
    await super.close();
  }
}

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

int totalForDay(String ymd, HabitsState state) {
  final activeHabitIds = activeBy(
    state.habitDefinitions,
    ymd,
  ).map((habitDefinition) => habitDefinition.id).toSet();
  final allByDay = state.allByDay[ymd] ?? {};
  return allByDay.union(activeHabitIds).length;
}

List<HabitDefinition> activeBy(
  List<HabitDefinition> habitDefinitions,
  String ymd,
) {
  if (ymd.isEmpty) {
    return [];
  }
  final activeHabits = habitDefinitions.where((habitDefinition) {
    final activeFrom = habitDefinition.activeFrom ?? DateTime(0);
    return DateTime(activeFrom.year, activeFrom.month, activeFrom.day)
        .isBefore(DateTime.parse(ymd));
  }).toList();

  return activeHabits;
}

double minY({
  required List<String> days,
  required HabitsState state,
}) {
  var lowest = 100.0;

  for (final day in days) {
    final n = state.successfulByDay[day]?.length ?? 0;
    final total = totalForDay(day, state);
    lowest = total > 0 ? min(lowest, 100 * n / total) : 0;
  }
  return max(lowest - 20, 0);
}

List<String> getDays(int timeSpanDays) {
  final now = DateTime.now();
  final days = daysInRange(
    rangeStart: now.dayAtMidnight.subtract(Duration(days: timeSpanDays)),
    rangeEnd: now,
  )..sort();
  return days;
}
