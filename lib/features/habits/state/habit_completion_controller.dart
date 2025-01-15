import 'dart:async';

import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_data.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'habit_completion_controller.g.dart';

@riverpod
class HabitCompletionController extends _$HabitCompletionController {
  late final String _habitId;
  late final DateTime _rangeStart;
  late final DateTime _rangeEnd;

  StreamSubscription<Set<String>>? _updateSubscription;
  final JournalDb _journalDb = getIt<JournalDb>();
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();

  void listen() {
    _updateSubscription =
        _updateNotifications.updateStream.listen((affectedIds) async {
      if (affectedIds.contains(_habitId)) {
        final latest = await _fetch();
        if (latest != state.value) {
          state = AsyncData(latest);
        }
      }
    });
  }

  @override
  Future<List<HabitResult>> build({
    required String habitId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    _habitId = habitId;
    _rangeStart = rangeStart;
    _rangeEnd = rangeEnd;

    ref
      ..onDispose(() => _updateSubscription?.cancel())
      ..cacheFor(entryCacheDuration);

    final results = await _fetch();
    listen();
    return results;
  }

  Future<List<HabitResult>> _fetch() async {
    final entities = await _journalDb.getHabitCompletionsByHabitId(
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
