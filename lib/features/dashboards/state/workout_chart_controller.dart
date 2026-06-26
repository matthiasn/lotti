import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/state/workout_data.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:lotti/widgets/charts/utils.dart';

/// Loads *all* workout entities in a date range (not filtered by type) and
/// keeps them live; one instance backs every workout chart sharing the same
/// range.
///
/// On construction it triggers a background workout-import delta so newly
/// recorded workouts appear without a manual refresh. Caches for
/// `dashboardCacheDuration` and re-fetches on workout [UpdateNotifications]
/// events. Per-type filtering and aggregation happen downstream in
/// [WorkoutObservationsController].
final AsyncNotifierProviderFamily<
  WorkoutChartDataController,
  List<JournalEntity>,
  ({DateTime rangeEnd, DateTime rangeStart})
>
workoutChartDataControllerProvider = AsyncNotifierProvider.autoDispose
    .family<
      WorkoutChartDataController,
      List<JournalEntity>,
      ({DateTime rangeStart, DateTime rangeEnd})
    >(
      WorkoutChartDataController.new,
      name: 'workoutChartDataControllerProvider',
    );

class WorkoutChartDataController extends AsyncNotifier<List<JournalEntity>> {
  WorkoutChartDataController(this._providerArgs) {
    getIt<HealthImport>().getWorkoutsHealthDataDelta();
  }

  final ({DateTime rangeStart, DateTime rangeEnd}) _providerArgs;
  DateTime get rangeStart => _providerArgs.rangeStart;
  DateTime get rangeEnd => _providerArgs.rangeEnd;

  final JournalDb _journalDb = getIt<JournalDb>();

  StreamSubscription<Set<String>>? _updateSubscription;
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();

  /// Subscribes to workout update notifications and re-fetches on change.
  /// Called once from `build`; cancelled on dispose.
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
  Future<List<JournalEntity>> build() async {
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

/// Chart-ready daily-sum observations for one workout series (a workout type +
/// value dimension described by `chartConfig`).
///
/// Watches [WorkoutChartDataController] for all workouts in range, then sums the
/// configured dimension per day via `aggregateWorkoutDailySum`. `chartConfig` is
/// typed as `DashboardItem` and cast to `DashboardWorkoutItem` to work around a
/// Riverpod codegen limitation. Returns an empty list when no workout of this
/// type exists in range so the chart shows "No data" rather than a flat row of
/// the prefilled zero buckets the aggregator produces.
final AsyncNotifierProviderFamily<
  WorkoutObservationsController,
  List<Observation>,
  ({DashboardItem chartConfig, DateTime rangeEnd, DateTime rangeStart})
>
workoutObservationsControllerProvider = AsyncNotifierProvider.autoDispose
    .family<
      WorkoutObservationsController,
      List<Observation>,
      ({DashboardItem chartConfig, DateTime rangeStart, DateTime rangeEnd})
    >(
      WorkoutObservationsController.new,
      name: 'workoutObservationsControllerProvider',
    );

class WorkoutObservationsController extends AsyncNotifier<List<Observation>> {
  WorkoutObservationsController(this._providerArgs);

  final ({DashboardItem chartConfig, DateTime rangeStart, DateTime rangeEnd})
  _providerArgs;
  DashboardItem get chartConfig => _providerArgs.chartConfig;
  DateTime get rangeStart => _providerArgs.rangeStart;
  DateTime get rangeEnd => _providerArgs.rangeEnd;

  @override
  Future<List<Observation>> build() async {
    ref.cacheFor(dashboardCacheDuration);

    // Await the upstream future (don't read `.value ?? []`) so this provider
    // stays in AsyncLoading until the DB fetch completes. Resolving early from
    // an empty upstream would make the chart flash a run of prefilled zero bars
    // (aggregateWorkoutDailySum fills every day) before the data arrives.
    final items = await ref.watch(
      workoutChartDataControllerProvider((
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      )).future,
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
