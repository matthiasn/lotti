import 'dart:async';

import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/state/workout_data.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workout_chart_controller.g.dart';

@riverpod
class WorkoutChartDataController extends _$WorkoutChartDataController {
  WorkoutChartDataController() {
    getIt<HealthImport>().getWorkoutsHealthDataDelta();
  }

  final JournalDb _journalDb = getIt<JournalDb>();

  StreamSubscription<Set<String>>? _updateSubscription;
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();

  void listen() {
    _updateSubscription = _updateNotifications.updateStream.listen((
      affectedIds,
    ) async {
      if (affectedIds.contains(workoutNotification)) {
        final latest = await _fetch();
        if (latest != state.value) {
          state = AsyncData(latest);
        }
      }
    });
  }

  @override
  Future<List<JournalEntity>> build({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    ref
      ..onDispose(() {
        _updateSubscription?.cancel();
      })
      ..cacheFor(dashboardCacheDuration);

    final data = await _fetch();
    listen();
    return data;
  }

  Future<List<JournalEntity>> _fetch() async {
    return _journalDb.getWorkouts(
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }
}

@riverpod
class WorkoutObservationsController extends _$WorkoutObservationsController {
  @override
  Future<List<Observation>> build({
    required DashboardItem chartConfig,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    ref.cacheFor(dashboardCacheDuration);

    // Await the upstream future (don't read `.value ?? []`) so this provider
    // stays in AsyncLoading until the DB fetch completes. Resolving early from
    // an empty upstream would make the chart flash a run of prefilled zero bars
    // (aggregateWorkoutDailySum fills every day) before the data arrives.
    final items = await ref.watch(
      workoutChartDataControllerProvider(
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ).future,
    );

    // type casting is necessary because an issue in riverpod otherwise
    // generating InvalidType, also see
    // https://github.com/rrousselGit/riverpod/issues/2920
    final config = chartConfig as DashboardWorkoutItem;

    // No workout of this type in range -> return empty so the chart shows its
    // "No data" state rather than a flat row of prefilled zero buckets.
    final hasMatchingWorkout = items.whereType<WorkoutEntry>().any(
      (workout) => workout.data.workoutType == config.workoutType,
    );
    if (!hasMatchingWorkout) return const <Observation>[];

    return aggregateWorkoutDailySum(
      items,
      chartConfig: config,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }
}
