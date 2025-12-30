import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/utils/measurable_utils.dart';
import 'package:lotti/widgets/charts/utils.dart';

// Record types for multi-param providers
typedef AggregationTypeParams = ({
  String measurableDataTypeId,
  AggregationType? dashboardDefinedAggregationType,
});

typedef MeasurableChartDataParams = ({
  String measurableDataTypeId,
  DateTime rangeStart,
  DateTime rangeEnd,
});

typedef MeasurableObservationsParams = ({
  String measurableDataTypeId,
  DateTime rangeStart,
  DateTime rangeEnd,
  AggregationType? dashboardDefinedAggregationType,
});

// MeasurableDataTypeController - single param
final AutoDisposeAsyncNotifierProviderFamily<MeasurableDataTypeController,
        MeasurableDataType?, String> measurableDataTypeControllerProvider =
    AsyncNotifierProvider.autoDispose
        .family<MeasurableDataTypeController, MeasurableDataType?, String>(
  MeasurableDataTypeController.new,
);

class MeasurableDataTypeController
    extends AutoDisposeFamilyAsyncNotifier<MeasurableDataType?, String> {
  final JournalDb _journalDb = getIt<JournalDb>();

  String get id => arg;

  @override
  Future<MeasurableDataType?> build(String arg) async {
    ref
      ..onDispose(() {})
      ..cacheFor(dashboardCacheDuration);
    final result = await _fetch();
    return result;
  }

  Future<MeasurableDataType?> _fetch() async {
    final dataType = getIt<EntitiesCacheService>().getDataTypeById(id);
    return dataType ?? await _journalDb.getMeasurableDataTypeById(id);
  }
}

// AggregationTypeController - two params
final AutoDisposeAsyncNotifierProviderFamily<
        AggregationTypeController,
        AggregationType,
        AggregationTypeParams> aggregationTypeControllerProvider =
    AsyncNotifierProvider.autoDispose.family<AggregationTypeController,
        AggregationType, AggregationTypeParams>(
  AggregationTypeController.new,
);

class AggregationTypeController extends AutoDisposeFamilyAsyncNotifier<
    AggregationType, AggregationTypeParams> {
  String get measurableDataTypeId => arg.measurableDataTypeId;
  AggregationType? get dashboardDefinedAggregationType =>
      arg.dashboardDefinedAggregationType;

  @override
  Future<AggregationType> build(AggregationTypeParams arg) async {
    ref.cacheFor(dashboardCacheDuration);
    final measurableDataType = ref
        .watch(measurableDataTypeControllerProvider(measurableDataTypeId))
        .valueOrNull;

    return dashboardDefinedAggregationType ??
        measurableDataType?.aggregationType ??
        AggregationType.dailySum;
  }
}

// MeasurableChartDataController - three params
final AutoDisposeAsyncNotifierProviderFamily<
        MeasurableChartDataController,
        List<JournalEntity>,
        MeasurableChartDataParams> measurableChartDataControllerProvider =
    AsyncNotifierProvider.autoDispose.family<MeasurableChartDataController,
        List<JournalEntity>, MeasurableChartDataParams>(
  MeasurableChartDataController.new,
);

class MeasurableChartDataController extends AutoDisposeFamilyAsyncNotifier<
    List<JournalEntity>, MeasurableChartDataParams> {
  final JournalDb _journalDb = getIt<JournalDb>();

  StreamSubscription<Set<String>>? _updateSubscription;
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();

  String get measurableDataTypeId => arg.measurableDataTypeId;
  DateTime get rangeStart => arg.rangeStart;
  DateTime get rangeEnd => arg.rangeEnd;

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
  Future<List<JournalEntity>> build(MeasurableChartDataParams arg) async {
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

// MeasurableObservationsController - four params
final AutoDisposeAsyncNotifierProviderFamily<
        MeasurableObservationsController,
        List<Observation>,
        MeasurableObservationsParams> measurableObservationsControllerProvider =
    AsyncNotifierProvider.autoDispose.family<MeasurableObservationsController,
        List<Observation>, MeasurableObservationsParams>(
  MeasurableObservationsController.new,
);

class MeasurableObservationsController extends AutoDisposeFamilyAsyncNotifier<
    List<Observation>, MeasurableObservationsParams> {
  String get measurableDataTypeId => arg.measurableDataTypeId;
  DateTime get rangeStart => arg.rangeStart;
  DateTime get rangeEnd => arg.rangeEnd;
  AggregationType? get dashboardDefinedAggregationType =>
      arg.dashboardDefinedAggregationType;

  @override
  Future<List<Observation>> build(MeasurableObservationsParams arg) async {
    ref.cacheFor(dashboardCacheDuration);

    final measurements = ref
            .watch(
              measurableChartDataControllerProvider((
                measurableDataTypeId: measurableDataTypeId,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
              )),
            )
            .valueOrNull ??
        [];

    final aggregationType = ref
            .watch(
              aggregationTypeControllerProvider((
                measurableDataTypeId: measurableDataTypeId,
                dashboardDefinedAggregationType:
                    dashboardDefinedAggregationType,
              )),
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

// MeasurableSuggestionsController - single param
final AutoDisposeAsyncNotifierProviderFamily<MeasurableSuggestionsController,
        List<num>?, String> measurableSuggestionsControllerProvider =
    AsyncNotifierProvider.autoDispose
        .family<MeasurableSuggestionsController, List<num>?, String>(
  MeasurableSuggestionsController.new,
);

class MeasurableSuggestionsController
    extends AutoDisposeFamilyAsyncNotifier<List<num>?, String> {
  String get measurableDataTypeId => arg;

  @override
  Future<List<num>?> build(String arg) async {
    ref.cacheFor(dashboardCacheDuration);

    final rangeStart =
        DateTime.now().dayAtMidnight.subtract(const Duration(days: 90));
    final rangeEnd = DateTime.now().dayAtMidnight.add(const Duration(days: 1));

    return rankedByPopularity(
      measurements: ref
          .watch(
            measurableChartDataControllerProvider((
              measurableDataTypeId: measurableDataTypeId,
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            )),
          )
          .valueOrNull,
    );
  }
}
