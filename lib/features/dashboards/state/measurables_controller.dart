import 'dart:async';

import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/utils/measurable_utils.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'measurables_controller.g.dart';

@riverpod
class MeasurableDataTypeController extends _$MeasurableDataTypeController {
  final JournalDb _journalDb = getIt<JournalDb>();

  @override
  Future<MeasurableDataType?> build({
    required String id,
  }) async {
    ref
      ..onDispose(() {})
      ..cacheFor(dashboardCacheDuration);
    final result = await _fetch();
    return result;
  }

  Future<MeasurableDataType?> _fetch() async {
    return _journalDb.getMeasurableDataTypeById(id);
  }
}

@riverpod
class AggregationTypeController extends _$AggregationTypeController {
  @override
  Future<AggregationType> build({
    required String measurableDataTypeId,
    required AggregationType? dashboardDefinedAggregationType,
  }) async {
    ref.cacheFor(dashboardCacheDuration);
    final measurableDataType = ref
        .watch(measurableDataTypeControllerProvider(id: measurableDataTypeId))
        .valueOrNull;

    return dashboardDefinedAggregationType ??
        measurableDataType?.aggregationType ??
        AggregationType.dailySum;
  }
}

@riverpod
class MeasurableChartDataController extends _$MeasurableChartDataController {
  final JournalDb _journalDb = getIt<JournalDb>();

  StreamSubscription<Set<String>>? _updateSubscription;
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();

  void listen() {
    _updateSubscription =
        _updateNotifications.updateStream.listen((affectedIds) async {
      if (affectedIds.contains(measurableDataTypeId)) {
        final latest = await _fetch();
        if (latest != state.value) {
          state = AsyncData(latest);
        }
      }
    });
  }

  @override
  Future<List<JournalEntity>> build({
    required String measurableDataTypeId,
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
    return _journalDb.getMeasurementsByType(
      type: measurableDataTypeId,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }
}

@riverpod
class MeasurableObservationsController
    extends _$MeasurableObservationsController {
  @override
  Future<List<Observation>> build({
    required String measurableDataTypeId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    AggregationType? dashboardDefinedAggregationType,
  }) async {
    ref.cacheFor(dashboardCacheDuration);

    final measurements = ref
            .watch(
              measurableChartDataControllerProvider(
                measurableDataTypeId: measurableDataTypeId,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
              ),
            )
            .valueOrNull ??
        [];

    final aggregationType = ref
            .watch(
              aggregationTypeControllerProvider(
                measurableDataTypeId: measurableDataTypeId,
                dashboardDefinedAggregationType:
                    dashboardDefinedAggregationType,
              ),
            )
            .valueOrNull ??
        AggregationType.dailySum;

    return switch (aggregationType) {
      AggregationType.none => aggregateMeasurementNone(measurements),
      AggregationType.dailySum => aggregateSumByDay(
          measurements,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ),
      AggregationType.dailyMax => aggregateMaxByDay(
          measurements,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ),
      // TODO: implement average
      AggregationType.dailyAvg => <Observation>[],
      AggregationType.hourlySum => aggregateSumByHour(
          measurements,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ),
    };
  }
}

@riverpod
class MeasurableSuggestionsController
    extends _$MeasurableSuggestionsController {
  @override
  Future<List<num>?> build({
    required String measurableDataTypeId,
  }) async {
    ref.cacheFor(dashboardCacheDuration);

    final rangeStart =
        DateTime.now().dayAtMidnight.subtract(const Duration(days: 90));
    final rangeEnd = DateTime.now().dayAtMidnight.add(const Duration(days: 1));

    return rankedByPopularity(
      measurements: ref
          .watch(
            measurableChartDataControllerProvider(
              measurableDataTypeId: measurableDataTypeId,
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ),
          )
          .valueOrNull,
    );
  }
}
