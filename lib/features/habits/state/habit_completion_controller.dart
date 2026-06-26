import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/habits/repository/habits_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_data.dart';

/// Owns one habit card's completion-history strip for a fixed date range.
///
/// Deliberately separate from `HabitsController`: it fetches completions for a
/// single `habitId` + range and, via listen, refreshes only when an update
/// notification's affected IDs include that habit — so one new completion
/// repaints one card instead of recomputing the whole tab. Keyed by
/// `(habitId, rangeStart, rangeEnd)`.
final AsyncNotifierProviderFamily<
  HabitCompletionController,
  List<HabitResult>,
  ({String habitId, DateTime rangeEnd, DateTime rangeStart})
>
habitCompletionControllerProvider = AsyncNotifierProvider.autoDispose
    .family<
      HabitCompletionController,
      List<HabitResult>,
      ({String habitId, DateTime rangeStart, DateTime rangeEnd})
    >(
      HabitCompletionController.new,
      name: 'habitCompletionControllerProvider',
    );

class HabitCompletionController extends AsyncNotifier<List<HabitResult>> {
  HabitCompletionController([
    ({String habitId, DateTime rangeStart, DateTime rangeEnd})? providerArgs,
  ]) : _providerArgs =
           providerArgs ??
           (
             habitId: '',
             rangeStart: DateTime.fromMillisecondsSinceEpoch(0),
             rangeEnd: DateTime.fromMillisecondsSinceEpoch(0),
           );

  final ({String habitId, DateTime rangeStart, DateTime rangeEnd})
  _providerArgs;
  String get habitId => _providerArgs.habitId;
  DateTime get rangeStart => _providerArgs.rangeStart;
  DateTime get rangeEnd => _providerArgs.rangeEnd;

  late final String _habitId;
  late final DateTime _rangeStart;
  late final DateTime _rangeEnd;

  StreamSubscription<Set<String>>? _updateSubscription;
  late HabitsRepository _repository;

  /// Subscribes to the repository update stream and refetches this habit's
  /// strip when an emitted batch of affected IDs contains [_habitId], emitting
  /// new state only when the fetched result actually differs.
  void listen() {
    _updateSubscription = _repository.updateStream.listen((affectedIds) async {
      if (affectedIds.contains(_habitId)) {
        final latest = await _fetch();
        if (latest != state.value) {
          state = AsyncData(latest);
        }
      }
    });
  }

  @override
  Future<List<HabitResult>> build() async {
    _habitId = habitId;
    _rangeStart = rangeStart;
    _rangeEnd = rangeEnd;
    _repository = ref.read(habitsRepositoryProvider);

    ref
      ..onDispose(() => _updateSubscription?.cancel())
      ..cacheFor(entryCacheDuration);

    final results = await _fetch();
    listen();
    return results;
  }

  Future<List<HabitResult>> _fetch() async {
    final entities = await _repository.getHabitCompletionsByHabitId(
      habitId: _habitId,
      rangeStart: _rangeStart,
      rangeEnd: _rangeEnd,
    );

    final habitDefinition = getIt<EntitiesCacheService>().getHabitById(
      _habitId,
    );

    if (habitDefinition == null) {
      return [];
    }

    return habitResultsByDay(
      entities,
      habitDefinition: habitDefinition,
      rangeStart: _rangeStart,
      rangeEnd: _rangeEnd,
    );
  }
}
