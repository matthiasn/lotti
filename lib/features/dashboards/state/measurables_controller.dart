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

// Record types keying the measurable provider families below. Each provider
// is parameterised by the record so distinct (data type / range / aggregation)
// combinations get independent, separately cached family members.

/// Keys [aggregationTypeControllerProvider]: the measurable plus the optional
/// dashboard-level aggregation override.
typedef AggregationTypeParams = ({
  String measurableDataTypeId,
  AggregationType? dashboardDefinedAggregationType,
});

/// Keys [measurableChartDataControllerProvider]: the measurable and the date
/// window to load.
typedef MeasurableChartDataParams = ({
  String measurableDataTypeId,
  DateTime rangeStart,
  DateTime rangeEnd,
});

/// Keys [measurableObservationsControllerProvider]: the measurable, the date
/// window, and the optional dashboard-level aggregation override.
typedef MeasurableObservationsParams = ({
  String measurableDataTypeId,
  DateTime rangeStart,
  DateTime rangeEnd,
  AggregationType? dashboardDefinedAggregationType,
});

/// Resolves the [MeasurableDataType] definition for an id, preferring the
/// in-memory [EntitiesCacheService] and falling back to the database. Cached
/// for `dashboardCacheDuration`.
final measurableDataTypeControllerProvider = AsyncNotifierProvider.autoDispose
    .family<MeasurableDataTypeController, MeasurableDataType?, String>(
      MeasurableDataTypeController.new,
    );

/// Loads one measurable's definition (cache-first, DB fallback). See
/// [measurableDataTypeControllerProvider].
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

/// Resolves the effective [AggregationType] for a measurable chart. See
/// [AggregationTypeController] for the precedence rule.
final aggregationTypeControllerProvider = AsyncNotifierProvider.autoDispose
    .family<AggregationTypeController, AggregationType, AggregationTypeParams>(
      AggregationTypeController.new,
    );

/// Computes the aggregation a measurable chart should use, with precedence:
/// the dashboard's explicit override → the measurable type's own default →
/// `AggregationType.dailySum`. Rebuilds if the measurable definition changes.
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
      measurableDataTypeControllerProvider(measurableDataTypeId).future,
    );

    return dashboardDefinedAggregationType ??
        measurableDataType?.aggregationType ??
        AggregationType.dailySum;
  }
}

/// Loads the raw measurement entities for one measurable within a date range
/// and keeps them live. See [MeasurableChartDataController].
final measurableChartDataControllerProvider = AsyncNotifierProvider.autoDispose
    .family<
      MeasurableChartDataController,
      List<JournalEntity>,
      MeasurableChartDataParams
    >(
      MeasurableChartDataController.new,
    );

/// Fetches the unaggregated measurement entities for one measurable in a date
/// window. Caches for `dashboardCacheDuration` and re-fetches when an
/// [UpdateNotifications] event names this measurable id (only pushing new state
/// when still mounted and the rows actually changed).
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
    _updateSubscription = _updateNotifications.updateStream.listen((
      affectedIds,
    ) async {
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

/// Chart-ready observations for one measurable, the source the measurable chart
/// widget renders. See [MeasurableObservationsController].
final measurableObservationsControllerProvider = AsyncNotifierProvider
    .autoDispose
    .family<
      MeasurableObservationsController,
      List<Observation>,
      MeasurableObservationsParams
    >(
      MeasurableObservationsController.new,
    );

/// Produces the chart points for a measurable: watches
/// [measurableChartDataControllerProvider] for raw measurements and
/// [aggregationTypeControllerProvider] for the effective aggregation, then
/// applies the matching reducer (none / dailySum / dailyMax / dailyAvg /
/// hourlySum).
///
/// Returns an empty list when there are no measurements in range, so the chart
/// shows its "No data" state. This is deliberate: the day/hour-bucketed
/// reducers prefill a zero bucket for every slot, so a non-empty result is
/// never empty and the chart would otherwise render a flat run of zero bars. A
/// genuinely all-zero but non-empty series (e.g. abstinence tracking) still
/// renders as bars.
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

    // No measurements in range -> return empty so the chart shows its "No data"
    // state. Without this, daily-sum/-max/-hourly aggregations prefill a zero
    // bucket for every day, so observations would never be empty and the chart
    // would render a flat run of zero bars instead. (A genuinely all-zero but
    // non-empty series, e.g. abstinence tracking, still renders as bars.)
    if (measurements.isEmpty) return const <Observation>[];

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
      AggregationType.dailyAvg => aggregateAvgByDay(
        measurements,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ),
      AggregationType.hourlySum => aggregateSumByHour(
        measurements,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ),
    };
  }
}

/// Quick-add value suggestions for a measurable. See
/// [MeasurableSuggestionsController].
final measurableSuggestionsControllerProvider = AsyncNotifierProvider
    .autoDispose
    .family<MeasurableSuggestionsController, List<num>?, String>(
      MeasurableSuggestionsController.new,
    );

/// Ranks a measurable's most frequently logged values over the last ~90 days
/// and returns up to five, powering the quick-add chips in the measurement
/// capture flow.
class MeasurableSuggestionsController extends AsyncNotifier<List<num>?> {
  MeasurableSuggestionsController(this._measurableDataTypeId);

  final String _measurableDataTypeId;

  String get measurableDataTypeId => _measurableDataTypeId;

  @override
  Future<List<num>?> build() async {
    ref.cacheFor(dashboardCacheDuration);

    final rangeStart = DateTime.now().dayAtMidnight.subtract(
      const Duration(days: 90),
    );
    final rangeEnd = DateTime.now().dayAtMidnight.add(const Duration(days: 1));

    final measurements = await ref.watch(
      measurableChartDataControllerProvider((
        measurableDataTypeId: measurableDataTypeId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      )).future,
    );

    // Surface up to five popular values so the quick-add chips cover more of a
    // high-frequency logger's habitual amounts (the chip row wraps).
    return rankedByPopularity(measurements: measurements, n: 5);
  }
}
