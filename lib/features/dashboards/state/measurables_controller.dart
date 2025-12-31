// ignore_for_file: specify_nonobvious_property_types

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
final measurableDataTypeControllerProvider = AsyncNotifierProvider.autoDispose
    .family<MeasurableDataTypeController, MeasurableDataType?, String>(
  MeasurableDataTypeController.new,
);

class MeasurableDataTypeController extends AsyncNotifier<MeasurableDataType?> {
  MeasurableDataTypeController(this._id);

  final String _id;
  final JournalDb _journalDb = getIt<JournalDb>();

  String get id => _id;

  @override
  Future<MeasurableDataType?> build() async {
    ref.cacheFor(dashboardCacheDuration);
    return _fetch();
  }

  Future<MeasurableDataType?> _fetch() async {
    final dataType = getIt<EntitiesCacheService>().getDataTypeById(id);
    return dataType ?? await _journalDb.getMeasurableDataTypeById(id);
  }
}

// AggregationTypeController - two params
final aggregationTypeControllerProvider = AsyncNotifierProvider.autoDispose
    .family<AggregationTypeController, AggregationType, AggregationTypeParams>(
  AggregationTypeController.new,
);

class AggregationTypeController extends AsyncNotifier<AggregationType> {
  AggregationTypeController(this._params);

  final AggregationTypeParams _params;

  String get measurableDataTypeId => _params.measurableDataTypeId;
  AggregationType? get dashboardDefinedAggregationType =>
      _params.dashboardDefinedAggregationType;

  @override
  Future<AggregationType> build() async {
    ref.cacheFor(dashboardCacheDuration);

    // Watch the measurable data type for changes
    final measurableDataType = await ref.watch(
        measurableDataTypeControllerProvider(measurableDataTypeId).future);

    return dashboardDefinedAggregationType ??
        measurableDataType?.aggregationType ??
        AggregationType.dailySum;
  }
}

// MeasurableChartDataController - three params
final measurableChartDataControllerProvider = AsyncNotifierProvider.autoDispose
    .family<MeasurableChartDataController, List<JournalEntity>,
        MeasurableChartDataParams>(
  MeasurableChartDataController.new,
);

class MeasurableChartDataController extends AsyncNotifier<List<JournalEntity>> {
  MeasurableChartDataController(this._params);

  final MeasurableChartDataParams _params;
  final JournalDb _journalDb = getIt<JournalDb>();
  StreamSubscription<Set<String>>? _updateSubscription;
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();

  String get measurableDataTypeId => _params.measurableDataTypeId;
  DateTime get rangeStart => _params.rangeStart;
  DateTime get rangeEnd => _params.rangeEnd;

  @override
  Future<List<JournalEntity>> build() async {
    ref
      ..cacheFor(dashboardCacheDuration)
      ..onDispose(() => _updateSubscription?.cancel());
    _listen();
    return _fetch();
  }

  void _listen() {
    _updateSubscription =
        _updateNotifications.updateStream.listen((affectedIds) async {
      if (affectedIds.contains(measurableDataTypeId)) {
        final latest = await _fetch();
        if (ref.mounted && latest != state.value) {
          state = AsyncData(latest);
        }
      }
    });
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
final measurableObservationsControllerProvider =
    AsyncNotifierProvider.autoDispose.family<MeasurableObservationsController,
        List<Observation>, MeasurableObservationsParams>(
  MeasurableObservationsController.new,
);

class MeasurableObservationsController
    extends AsyncNotifier<List<Observation>> {
  MeasurableObservationsController(this._params);

  final MeasurableObservationsParams _params;

  String get measurableDataTypeId => _params.measurableDataTypeId;
  DateTime get rangeStart => _params.rangeStart;
  DateTime get rangeEnd => _params.rangeEnd;
  AggregationType? get dashboardDefinedAggregationType =>
      _params.dashboardDefinedAggregationType;

  @override
  Future<List<Observation>> build() async {
    ref.cacheFor(dashboardCacheDuration);

    // Watch both dependencies - this will rebuild when either changes
    final measurements = await ref.watch(
      measurableChartDataControllerProvider((
        measurableDataTypeId: measurableDataTypeId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      )).future,
    );

    final aggregationType = await ref.watch(
      aggregationTypeControllerProvider((
        measurableDataTypeId: measurableDataTypeId,
        dashboardDefinedAggregationType: dashboardDefinedAggregationType,
      )).future,
    );

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
final measurableSuggestionsControllerProvider = AsyncNotifierProvider
    .autoDispose
    .family<MeasurableSuggestionsController, List<num>?, String>(
  MeasurableSuggestionsController.new,
);

class MeasurableSuggestionsController extends AsyncNotifier<List<num>?> {
  MeasurableSuggestionsController(this._measurableDataTypeId);

  final String _measurableDataTypeId;

  String get measurableDataTypeId => _measurableDataTypeId;

  @override
  Future<List<num>?> build() async {
    ref.cacheFor(dashboardCacheDuration);

    final rangeStart =
        DateTime.now().dayAtMidnight.subtract(const Duration(days: 90));
    final rangeEnd = DateTime.now().dayAtMidnight.add(const Duration(days: 1));

    final measurements = await ref.watch(
      measurableChartDataControllerProvider((
        measurableDataTypeId: measurableDataTypeId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      )).future,
    );

    return rankedByPopularity(measurements: measurements);
  }
}
