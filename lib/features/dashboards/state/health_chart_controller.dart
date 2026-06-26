import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/state/health_data.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:lotti/widgets/charts/utils.dart';

/// Loads the raw quantitative health entities of one `healthDataType` within a
/// date range and keeps them fresh.
///
/// Holds the result for `dashboardCacheDuration` so flipping between dashboards
/// doesn't re-query, and subscribes to [UpdateNotifications] so an inbound
/// change to this exact health type re-fetches and pushes new data (skipping
/// the rebuild when the rows are unchanged). The returned entities are
/// unaggregated; [HealthObservationsController] turns them into chart points.
final AsyncNotifierProviderFamily<
  HealthChartDataController,
  List<JournalEntity>,
  ({String healthDataType, DateTime rangeEnd, DateTime rangeStart})
>
healthChartDataControllerProvider = AsyncNotifierProvider.autoDispose
    .family<
      HealthChartDataController,
      List<JournalEntity>,
      ({String healthDataType, DateTime rangeStart, DateTime rangeEnd})
    >(
      HealthChartDataController.new,
      name: 'healthChartDataControllerProvider',
    );

class HealthChartDataController extends AsyncNotifier<List<JournalEntity>> {
  HealthChartDataController(this._providerArgs);

  final ({String healthDataType, DateTime rangeStart, DateTime rangeEnd})
  _providerArgs;
  String get healthDataType => _providerArgs.healthDataType;
  DateTime get rangeStart => _providerArgs.rangeStart;
  DateTime get rangeEnd => _providerArgs.rangeEnd;

  final JournalDb _journalDb = getIt<JournalDb>();

  StreamSubscription<Set<String>>? _updateSubscription;
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();

  /// Starts watching [UpdateNotifications] for changes to this controller's
  /// `healthDataType` and re-fetches when one arrives. Called once from
  /// `build`; the subscription is cancelled on dispose.
  void listen() {
    _updateSubscription = _updateNotifications.updateStream.listen((
      affectedIds,
    ) async {
      if (affectedIds.contains(healthDataType)) {
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
    return _journalDb.getQuantitativeByType(
      type: healthDataType,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }
}

/// Chart-ready observations for one health type: watches
/// [HealthChartDataController] for the raw entities and reduces them via
/// `aggregateByType` (the per-type rule from `healthTypes`).
///
/// On construction (outside tests) it kicks off a short, jittered-delay
/// background health-data sync for this type so the chart refreshes itself with
/// freshly imported samples without blocking first paint. The build awaits the
/// upstream future (rather than reading a possibly-empty cached value) so the
/// provider stays in `AsyncLoading` until the DB read completes — otherwise the
/// chart's stale-while-revalidate wrapper would flash an empty "No data" state.
final AsyncNotifierProviderFamily<
  HealthObservationsController,
  List<Observation>,
  ({String healthDataType, DateTime rangeEnd, DateTime rangeStart})
>
healthObservationsControllerProvider = AsyncNotifierProvider.autoDispose
    .family<
      HealthObservationsController,
      List<Observation>,
      ({String healthDataType, DateTime rangeStart, DateTime rangeEnd})
    >(
      HealthObservationsController.new,
      name: 'healthObservationsControllerProvider',
    );

class HealthObservationsController extends AsyncNotifier<List<Observation>> {
  HealthObservationsController(this._providerArgs) {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      Future.delayed(Duration(milliseconds: 500 + Random().nextInt(500)), () {
        getIt<HealthImport>().fetchHealthDataDelta(healthDataType);
      });
    }
  }

  final ({String healthDataType, DateTime rangeStart, DateTime rangeEnd})
  _providerArgs;
  String get healthDataType => _providerArgs.healthDataType;
  DateTime get rangeStart => _providerArgs.rangeStart;
  DateTime get rangeEnd => _providerArgs.rangeEnd;

  @override
  Future<List<Observation>> build() async {
    ref.cacheFor(dashboardCacheDuration);

    // Await the upstream future (don't read `.value ?? []`) so this provider
    // stays in AsyncLoading until the DB fetch completes. Resolving early from
    // an empty upstream would make the chart's stale-while-revalidate wrapper
    // see a value and flash an empty "No data" state on first load.
    final items = await ref.watch(
      healthChartDataControllerProvider((
        healthDataType: healthDataType,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      )).future,
    );

    return aggregateByType(items, healthDataType);
  }
}
