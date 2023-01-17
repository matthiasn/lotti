import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:lotti/blocs/habits/habits_state.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:rxdart/rxdart.dart';

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
            successfulToday: <String>{},
            successfulByDay: <String, Set<String>>{},
            skippedByDay: <String, Set<String>>{},
            failedByDay: <String, Set<String>>{},
            allByDay: <String, Set<String>>{},
            selectedInfoYmd: '',
            shortStreakCount: 0,
            longStreakCount: 0,
            timeSpanDays: 14,
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

  void startWatching() {
    _completionsStream = _journalDb.watchHabitCompletionsInRange(
      rangeStart: getStartOfDay(
        DateTime.now().subtract(const Duration(days: 90)),
      ),
    );

    if (!isTestEnv) {
      _completionsStream = _completionsStream.throttleTime(
        const Duration(seconds: 5),
        trailing: true,
        leading: true,
      );
    }

    _completionsSubscription = _completionsStream.listen((habitCompletions) {
      _habitCompletions = habitCompletions;
      determineHabitSuccessByDays();
    });
  }

  void determineHabitSuccessByDays() {
    _completedToday = <String>{};
    _successfulToday = <String>{};
    _successfulByDay = <String, Set<String>>{};
    _skippedByDay = <String, Set<String>>{};
    _failedByDay = <String, Set<String>>{};

    final today = ymd(DateTime.now());

    void addId(Map<String, Set<String>> byDay, String day, String habitId) {
      byDay[day] = byDay[day] ?? <String>{}
        ..add(habitId);
    }

    void removeId(Map<String, Set<String>> byDay, String day, String habitId) {
      byDay[day] = byDay[day] ?? <String>{}
        ..remove(habitId);
    }

    for (final item in _habitCompletions) {
      final day = ymd(item.meta.dateFrom);

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
        final day = ymd(item.meta.dateFrom);
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
  List<HabitDefinition> _pendingLater = [];
  List<HabitDefinition> _completed = [];
  List<JournalEntity> _habitCompletions = [];

  var _completedToday = <String>{};
  var _successfulToday = <String>{};
  final _allByDay = <String, Set<String>>{};
  var _successfulByDay = <String, Set<String>>{};
  var _skippedByDay = <String, Set<String>>{};
  var _failedByDay = <String, Set<String>>{};

  var _shortStreakCount = 0;
  var _longStreakCount = 0;
  var _timeSpanDays = isDesktop ? 14 : 7;
  var _selectedInfoYmd = '';

  void setTimeSpan(int timeSpanDays) {
    _timeSpanDays = timeSpanDays;
    emitState();
  }

  void setInfoYmd(String ymd) {
    _selectedInfoYmd = ymd;
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
        openNow: _openNow,
        pendingLater: _pendingLater,
        completed: _completed,
        successfulToday: _successfulToday,
        successfulByDay: _successfulByDay,
        failedByDay: _failedByDay,
        selectedInfoYmd: _selectedInfoYmd,
        skippedByDay: _skippedByDay,
        allByDay: _allByDay,
        shortStreakCount: _shortStreakCount,
        longStreakCount: _longStreakCount,
        timeSpanDays: _timeSpanDays,
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
