import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart';
import 'package:lotti/blocs/habits/habits_state.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/widgets/charts/utils.dart';

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
          ),
        ) {
    _definitionsStream = _journalDb.watchHabitDefinitions();
    _definitionsSubscription = _definitionsStream.listen((habitDefinitions) {
      _habitDefinitions = habitDefinitions;
      emitState();
    });

    _completionsStream = _journalDb.watchHabitCompletionsInRange(
      rangeStart: getStartOfDay(DateTime.now()),
    );
    _completionsSubscription = _completionsStream.listen((habitCompletions) {
      _habitCompletions = habitCompletions;

      _completedToday = <String>{};

      for (final item in _habitCompletions) {
        if (item is HabitCompletionEntry) {
          _completedToday.add(item.data.habitId);
        }
      }

      _openHabits = _habitDefinitions
          .where((item) => !state.completedToday.contains(item.id))
          .sorted(habitSorter);

      _openNow = _openHabits.where(showHabit).toList();
      _pendingLater = _openHabits.where((item) => !showHabit(item)).toList();

      _completed = _habitDefinitions
          .where((item) => _completedToday.contains(item.id))
          .sorted(habitSorter);

      emitState();
    });
  }

  List<HabitDefinition> _habitDefinitions = [];

  List<HabitDefinition> _openHabits = [];
  List<HabitDefinition> _openNow = [];
  List<HabitDefinition> _pendingLater = [];
  List<HabitDefinition> _completed = [];

  List<JournalEntity> _habitCompletions = [];
  var _completedToday = <String>{};

  final JournalDb _journalDb = getIt<JournalDb>();

  late final Stream<List<HabitDefinition>> _definitionsStream;
  late final StreamSubscription<List<HabitDefinition>> _definitionsSubscription;

  late final Stream<List<JournalEntity>> _completionsStream;
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
