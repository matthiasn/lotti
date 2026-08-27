import 'dart:async';
import 'dart:collection';

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:health/health.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_daily_steps.dart'
    as health_daily_steps
    show resolveDailySteps, sumNumericHealthValues;
import 'package:lotti/logic/health_data_types.dart';
import 'package:lotti/logic/health_import_result.dart';
import 'package:lotti/logic/health_permission_gate.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/health_service.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/utils/platform.dart';
import 'package:permission_handler/permission_handler.dart';

export 'package:lotti/logic/health_data_types.dart';
export 'package:lotti/logic/health_import_result.dart';
export 'package:lotti/logic/health_permission_gate.dart';

/// Reads samples out of Apple Health / Health Connect and persists them as
/// quantitative and workout journal entries.
///
/// Two entry points drive it:
///
/// - **Dashboards**, via [fetchHealthDataDelta] / [getWorkoutsHealthDataDelta]:
///   background, incremental (from the newest stored sample forward), and
///   queued so a dashboard full of charts does not fan out into one health
///   request per chart.
/// - **Settings → Health Import**, via [getActivityHealthData],
///   [fetchHealthData] and [getWorkoutsHealthData]: an explicit user-chosen
///   date range, awaited so the page can report what happened.
///
/// Every path into the health plugin is funnelled through [_serialized]. See
/// that member for why concurrency here is not merely wasteful but visibly
/// broken.
class HealthImport {
  HealthImport({
    required this.persistenceLogic,
    required this._db,
    required this.health,
    required this.deviceInfo,
    Future<void> Function()? requestPermissions,
    HealthPermissionGate? permissionGate,
  }) : _requestPermissions = requestPermissions ?? _defaultRequestPermissions,
       permissionGate = permissionGate ?? HealthPermissionGate(health) {
    _platformReady = _resolvePlatform();
  }
  final PersistenceLogic persistenceLogic;
  final JournalDb _db;
  final HealthService health;
  final DeviceInfoPlugin deviceInfo;
  final Future<void> Function() _requestPermissions;

  /// Decides when the system authorization sheet may be raised, and for which
  /// types. Every import goes through it rather than calling
  /// `requestAuthorization` directly — see [HealthPermissionGate] for why
  /// asking on every import was itself the bug.
  final HealthPermissionGate permissionGate;

  /// Companion permissions that Health Connect needs before it will hand over
  /// step and distance data on Android.
  ///
  /// iOS is deliberately excluded: HealthKit governs every read through its own
  /// authorization sheet, `Permission.activityRecognition` has no iOS strategy
  /// at all (it resolves to permanently-denied without ever asking), and
  /// `Permission.location` would pop an unrelated *location* prompt in front of
  /// the HealthKit sheet — two system dialogs racing each other for one tap on
  /// "Import Activity Data".
  static Future<void> _defaultRequestPermissions() async {
    if (!isAndroid) {
      return;
    }
    await Permission.activityRecognition.request();
    await Permission.location.request();
  }

  Duration defaultFetchDuration = const Duration(days: 90);

  /// How many calendar days before the newest stored day a cumulative delta
  /// re-reads. A source that syncs its day late — a band that uploads
  /// overnight — lands its final total after that day already has a row, and
  /// a delta that only looked forward would never see it.
  static const cumulativeDeltaLookBackDays = 1;

  final queue = Queue<String>();
  bool running = false;
  bool workoutImportRunning = false;

  late final String platform;
  String? deviceType;
  Map<String, DateTime> lastFetched = {};

  /// Completes once [platform] and [deviceType] are known. Awaited before any
  /// sample is persisted so the first import after launch does not stamp its
  /// entries with a null device type simply because the device-info channel had
  /// not answered yet.
  late final Future<void> _platformReady;

  /// Serializes every call into the health plugin.
  ///
  /// HealthKit presents **one** authorization sheet at a time: a second
  /// `requestAuthorization` raised while the first is still on screen replaces
  /// it, and the visible result is a sheet that appears and vanishes without
  /// the user getting to answer it. That is reachable with no user error at
  /// all — opening a dashboard schedules a background delta fetch per chart,
  /// and the settings page fires an import on tap — so the fix belongs here
  /// rather than in either caller.
  ///
  /// Each caller waits on its predecessor's completion and publishes its own
  /// baton for the next one. The baton is completed in a `finally`, never with
  /// an error, so a failing import releases the lock and propagates its failure
  /// to *its own* caller without wedging everyone queued behind it.
  ///
  /// The baton is created lazily rather than seeded with a resolved future:
  /// a `Future` captures the zone it was constructed in, and one built in the
  /// constructor would schedule its continuations on that zone forever — which
  /// among other things makes the queue undrainable under `fakeAsync`.
  Future<void>? _healthAccessGate;

  Future<T> _serialized<T>(Future<T> Function() operation) async {
    final predecessor = _healthAccessGate;
    final baton = Completer<void>();
    _healthAccessGate = baton.future;

    try {
      if (predecessor != null) {
        await predecessor;
      }
      return await operation();
    } finally {
      baton.complete();
    }
  }

  DomainLogger get _logger => getIt<DomainLogger>();

  Future<void> _resolvePlatform() async {
    platform = isIOS
        ? 'IOS'
        : isAndroid
        ? 'ANDROID'
        : '';
    try {
      if (isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceType = iosInfo.utsname.machine;
      }
      if (isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceType = androidInfo.model;
      }
    } catch (error, stackTrace) {
      // Device model is descriptive metadata on each sample, not something an
      // import depends on — losing it must not take the import with it.
      _logger.error(
        LogDomain.health,
        error,
        stackTrace: stackTrace,
        subDomain: 'resolvePlatform',
      );
    }
  }

  List<DateTime> getDays(DateTime dateFrom, DateTime dateTo) {
    final range = dateTo.difference(dateFrom);
    return List<DateTime>.generate(range.inDays + 1, (days) {
      final day = dateFrom.add(Duration(days: days));
      return DateTime(
        day.year,
        day.month,
        day.day,
      );
    });
  }

  Future<void> fetchAndProcessActivityDataForDay(
    DateTime dateFrom,
    Map<DateTime, num> stepsByDay,
    Map<DateTime, num> flightsByDay,
    Map<DateTime, num> distanceByDay,
  ) async {
    final now = clock.now();
    if (dateFrom.isBefore(now)) {
      final dateTo = DateTime(
        dateFrom.year,
        dateFrom.month,
        dateFrom.day,
        23,
        59,
        59,
        999,
      );

      final mergedSteps = await health.getTotalStepsInInterval(
        dateFrom,
        dateTo,
      );
      final samplesByType = (await health.getHealthDataFromTypes(
        types: activityTypes,
        startTime: dateFrom,
        endTime: dateTo,
      )).groupListsBy((point) => point.type);
      final flightsClimbedDataPoints =
          samplesByType[HealthDataType.FLIGHTS_CLIMBED] ?? const [];
      final distanceDataPoints =
          samplesByType[HealthDataType.DISTANCE_WALKING_RUNNING] ?? const [];

      // Steps go through the raw samples as well — see [resolveDailySteps].
      // Flights and distance keep their plain sum, as they always have.
      stepsByDay[dateFrom] = health_daily_steps.resolveDailySteps(
        mergedSteps,
        samplesByType[HealthDataType.STEPS] ?? const [],
      );
      flightsByDay[dateFrom] = sumNumericHealthValues(flightsClimbedDataPoints);
      distanceByDay[dateFrom] = sumNumericHealthValues(distanceDataPoints);
    }
  }

  /// Persists one cumulative entry per day in [data], returning how many the
  /// database accepted — not how many were attempted.
  ///
  /// Each entry spans its whole calendar day, except the day in progress, whose
  /// end is capped at the current instant so a chart never plots a total into
  /// the future.
  ///
  /// A day is keyed by its type and date, not by its value:
  /// `createQuantitativeEntry` updates the stored day in place when the total
  /// has changed and leaves it alone when it has not, so re-importing after a
  /// late-syncing source has landed replaces the stale figure rather than
  /// sitting a second row next to it (see `createQuantitativeEntryImpl`).
  Future<int> addActivityEntries(
    Map<DateTime, num> data,
    String type,
    String unit,
  ) async {
    await _platformReady;
    final now = clock.now();
    final entries = List<MapEntry<DateTime, num>>.from(data.entries)
      ..sort((a, b) => a.key.compareTo(b.key));
    var written = 0;

    for (final dailyStepsEntry in entries) {
      final dayStart = dailyStepsEntry.key;
      final dayEnd = dayStart
          .add(const Duration(days: 1))
          .subtract(const Duration(milliseconds: 1));
      final dateToOrNow = dayEnd.isAfter(now) ? now : dayEnd;
      final activityForDay = CumulativeQuantityData(
        dateFrom: dayStart,
        dateTo: dateToOrNow,
        value: dailyStepsEntry.value,
        dataType: type,
        unit: unit,
        deviceType: deviceType,
        platformType: platform,
      );
      final stored = await persistenceLogic.createQuantitativeEntry(
        activityForDay,
      );
      if (stored != null) {
        written++;
      }
    }

    return written;
  }

  /// Imports steps, flights climbed and walking/running distance for each day
  /// in the range, aggregated per day.
  ///
  /// Serialized against every other health request — see [_serialized].
  Future<HealthImportResult> getActivityHealthData({
    required DateTime dateFrom,
    required DateTime dateTo,
    bool userInitiated = true,
  }) => _serialized(
    () => _getActivityHealthData(
      dateFrom: dateFrom,
      dateTo: dateTo,
      userInitiated: userInitiated,
    ),
  );

  Future<HealthImportResult> _getActivityHealthData({
    required DateTime dateFrom,
    required DateTime dateTo,
    required bool userInitiated,
  }) async {
    if (isDesktop) {
      return const HealthImportResult.unsupportedPlatform();
    }

    try {
      await _requestPermissions();
      final authorization = await authorizeHealth(
        activityTypes,
        userInitiated: userInitiated,
      );

      if (authorization == HealthAuthorization.denied) {
        _logger.log(
          LogDomain.health,
          'authorization denied for activity types',
          subDomain: 'getActivityHealthData',
          level: InsightLevel.warn,
        );
        return const HealthImportResult.permissionDenied();
      }

      final stepsByDay = <DateTime, num>{};
      final flightsByDay = <DateTime, num>{};
      final distanceByDay = <DateTime, num>{};

      final days = getDays(dateFrom, dateTo);

      for (final day in days) {
        await fetchAndProcessActivityDataForDay(
          day,
          stepsByDay,
          flightsByDay,
          distanceByDay,
        );
      }

      // Every day in the range reads as zero. That is what a switched-off
      // permission looks like on iOS, and also what a genuinely idle range
      // looks like — so it is only worth reporting when nothing was ever
      // imported for these types either. Checked *before* writing, so a denied
      // permission does not fill the journal with fabricated zero-step days.
      final readNothing = [
        stepsByDay,
        flightsByDay,
        distanceByDay,
      ].every((byDay) => byDay.values.every((value) => value == 0));

      if (readNothing &&
          authorization != HealthAuthorization.granted &&
          !await _hasStoredHistory(activityStorageTypes)) {
        _logger.log(
          LogDomain.health,
          'no activity data over ${days.length} days and none ever stored — '
          'read access may be off',
          subDomain: 'getActivityHealthData',
          level: InsightLevel.warn,
        );
        return const HealthImportResult.noDataOrAccess();
      }

      final imported =
          await addActivityEntries(
            stepsByDay,
            'cumulative_step_count',
            'count',
          ) +
          await addActivityEntries(
            flightsByDay,
            'cumulative_flights_climbed',
            'count',
          ) +
          await addActivityEntries(
            distanceByDay,
            'cumulative_distance',
            'meters',
          );

      _logger.log(
        LogDomain.health,
        'imported $imported activity entries over ${days.length} days',
        subDomain: 'getActivityHealthData',
      );
      return HealthImportResult.imported(imported);
    } catch (error, stackTrace) {
      _logger.error(
        LogDomain.health,
        error,
        stackTrace: stackTrace,
        subDomain: 'getActivityHealthData',
      );
      return HealthImportResult.failed(error);
    }
  }

  num sumNumericHealthValues(List<HealthDataPoint> dataPoints) =>
      health_daily_steps.sumNumericHealthValues(dataPoints);

  /// Authorizes [types] and everything in their permission families.
  ///
  /// [userInitiated] distinguishes a tap on the Health Import page from a
  /// dashboard's background import: only the former may re-raise a system sheet
  /// the user has already answered this session. See [HealthPermissionGate].
  Future<HealthAuthorization> authorizeHealth(
    List<HealthDataType> types, {
    required bool userInitiated,
  }) async {
    if (isDesktop) {
      return HealthAuthorization.denied;
    }
    return permissionGate.ensure(types, userInitiated: userInitiated);
  }

  /// The storage-type strings `addActivityEntries` writes under.
  static const activityStorageTypes = <String>[
    'cumulative_step_count',
    'cumulative_flights_climbed',
    'cumulative_distance',
  ];

  /// Whether any sample has ever been stored under one of [storageTypes].
  ///
  /// The discriminator behind [HealthImportStatus.noDataOrAccess]: an empty
  /// read means "no samples" or "not allowed", and iOS will not say which — but
  /// a category that has never produced a single sample is far more likely to
  /// be one Lotti cannot read than one the user has never recorded *and* has a
  /// dashboard for.
  Future<bool> _hasStoredHistory(List<String> storageTypes) async {
    for (final storageType in storageTypes) {
      if (await _db.latestQuantitativeByType(storageType) != null) {
        return true;
      }
    }
    return false;
  }

  /// Imports every sample of [types] in the range as discrete quantitative
  /// entries.
  ///
  /// Serialized against every other health request — see [_serialized].
  Future<HealthImportResult> fetchHealthData({
    required List<HealthDataType> types,
    required DateTime dateFrom,
    required DateTime dateTo,
    bool userInitiated = true,
  }) => _serialized(
    () => _fetchHealthData(
      types: types,
      dateFrom: dateFrom,
      dateTo: dateTo,
      userInitiated: userInitiated,
    ),
  );

  Future<HealthImportResult> _fetchHealthData({
    required List<HealthDataType> types,
    required DateTime dateFrom,
    required DateTime dateTo,
    required bool userInitiated,
  }) async {
    if (isDesktop) {
      return const HealthImportResult.unsupportedPlatform();
    }

    try {
      // Inside the `try` with everything else: `requestAuthorization` throws on
      // a bad type/permission pairing, and `HealthService` rethrows a failed
      // configure handshake. Letting either escape would break this method's
      // contract of returning an outcome rather than throwing — and the caller
      // that trusts it hardest is the settings page, whose row would be left
      // spinning with no way to retry.
      final authorization = await authorizeHealth(
        types,
        userInitiated: userInitiated,
      );

      if (authorization == HealthAuthorization.denied) {
        _logger.log(
          LogDomain.health,
          'authorization denied for ${types.length} type(s)',
          subDomain: 'fetchHealthData',
          level: InsightLevel.warn,
        );
        return const HealthImportResult.permissionDenied();
      }

      await _platformReady;
      final now = clock.now();
      final dateToOrNow = dateTo.isAfter(now) ? now : dateTo;
      final dataPoints = await health.getHealthDataFromTypes(
        types: types,
        startTime: dateFrom,
        endTime: dateToOrNow,
      );

      // An empty read is either "no samples in this range" or "you are not
      // allowed to see them", and on iOS there is no API that tells them apart.
      // Reporting it as a plain success — a green tick reading "No new
      // samples" — is what made a switched-off permission look like an
      // up-to-date import. When nothing was read *and* nothing was ever stored
      // for these types, say so, so the page can point at access.
      if (dataPoints.isEmpty &&
          authorization != HealthAuthorization.granted &&
          !await _hasStoredHistory(
            types.map((type) => type.toString()).toList(),
          )) {
        _logger.log(
          LogDomain.health,
          'no samples for ${types.length} type(s) and none ever stored — '
          'read access may be off',
          subDomain: 'fetchHealthData',
          level: InsightLevel.warn,
        );
        return const HealthImportResult.noDataOrAccess();
      }

      var imported = 0;

      for (final dataPoint in dataPoints.reversed) {
        final dataType = dataPoint.type.toString();

        if (dataPoint.value is NumericHealthValue) {
          final value = dataPoint.value as NumericHealthValue;
          final discreteQuantity = DiscreteQuantityData(
            dateFrom: dataPoint.dateFrom,
            dateTo: dataPoint.dateTo,
            value: value.numericValue,
            dataType: dataType,
            unit: dataPoint.unit.toString(),
            deviceType: deviceType,
            platformType: platform,
            sourceId: dataPoint.sourceId,
            sourceName: dataPoint.sourceName,
          );
          // `createQuantitativeEntry` logs and returns null rather than
          // throwing, so an unchecked count would report samples the database
          // rejected. Count what was actually stored.
          final stored = await persistenceLogic.createQuantitativeEntry(
            discreteQuantity,
          );
          if (stored != null) {
            imported++;
          }

          if (sleepStagesDuplicatedAsAsleep.contains(dataType)) {
            await persistenceLogic.createQuantitativeEntry(
              discreteQuantity.copyWith(
                dataType: 'HealthDataType.SLEEP_ASLEEP',
              ),
            );
          }
        }
      }

      _logger.log(
        LogDomain.health,
        'imported $imported of ${dataPoints.length} sample(s) for '
        '${types.length} type(s)',
        subDomain: 'fetchHealthData',
      );
      return HealthImportResult.imported(imported);
    } catch (error, stackTrace) {
      _logger.error(
        LogDomain.health,
        error,
        stackTrace: stackTrace,
        subDomain: 'fetchHealthData',
      );
      return HealthImportResult.failed(error);
    }
  }

  /// Storage-type strings that a dashboard type expands into before the health
  /// store is queried.
  ///
  /// `BLOOD_PRESSURE` is a composite chart over two real HealthKit types, and
  /// `BODY_MASS_INDEX` names the "Weight vs. Body Mass Index" card, which plots
  /// the *weight* series (see `DashboardHealthBmiChart`) — so it resolves to
  /// weight rather than to BMI samples.
  ///
  /// `SLEEP_ASLEEP` is the subtle one, and the reason the "Asleep" chart used
  /// to fall further behind the longer you left it. HealthKit stores all sleep
  /// under one category type and the plugin's iOS reader selects a stage by
  /// filtering on the sample's category value — `SLEEP_ASLEEP` matches only
  /// `asleepUnspecified`, which an Apple Watch on iOS 16+ never writes. Asking
  /// for `SLEEP_ASLEEP` alone therefore reads nothing, while the rows that
  /// actually feed that series are the staged samples, copied under the generic
  /// type as they are imported (see [sleepStagesDuplicatedAsAsleep]). The chart
  /// only ever gained data when a *stage* card happened to be fetched, or from
  /// a manual import in Settings — which requests the whole family at once.
  ///
  /// Expanding here rather than at the call site keeps that coupling in one
  /// place, and costs no extra authorization: [expandToPermissionFamilies]
  /// already widens any sleep type to the whole sleep family.
  static const compositeStorageTypes = <String, List<String>>{
    'BLOOD_PRESSURE': [
      'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
      'HealthDataType.BLOOD_PRESSURE_DIASTOLIC',
    ],
    'BODY_MASS_INDEX': ['HealthDataType.WEIGHT'],
    // SLEEP_ASLEEP stays first: the delta window is computed from
    // `actualTypes.first`, and it is the generic series being caught up.
    'HealthDataType.SLEEP_ASLEEP': [
      'HealthDataType.SLEEP_ASLEEP',
      'HealthDataType.SLEEP_LIGHT',
      'HealthDataType.SLEEP_DEEP',
      'HealthDataType.SLEEP_REM',
    ],
  };

  /// Resolves storage-type strings (`HealthDataType.STEPS`, or a bare enum name)
  /// to plugin enum values, dropping any that the plugin no longer knows.
  List<HealthDataType> resolveHealthDataTypes(List<String> storageTypes) {
    final healthDataTypes = <HealthDataType>[];

    for (final storageType in storageTypes) {
      final subType = storageType.replaceAll('HealthDataType.', '');
      final healthDataType = EnumToString.fromString(
        HealthDataType.values,
        subType,
      );

      if (healthDataType != null) {
        healthDataTypes.add(healthDataType);
      }
    }

    return healthDataTypes;
  }

  Future<HealthImportResult> _fetchHealthDataDelta(String type) async {
    if (isDesktop) {
      return const HealthImportResult.unsupportedPlatform();
    }

    final actualTypes = compositeStorageTypes[type] ?? [type];

    final latest = await _db.latestQuantitativeByType(actualTypes.first);
    final now = clock.now();

    final dateFrom =
        latest?.meta.dateFrom ?? now.subtract(defaultFetchDuration);

    if (type.contains('cumulative')) {
      // See [cumulativeDeltaLookBackDays].
      return _getActivityHealthData(
        dateFrom: latest == null
            ? dateFrom
            : dateFrom.dateOnly.addCalendarDays(-cumulativeDeltaLookBackDays),
        dateTo: now,
        // Nobody asked for this — a chart scheduled it on open. Re-raising an
        // authorization sheet the user has already answered would put a modal
        // in front of a dashboard they were only looking at.
        userInitiated: false,
      );
    }

    final healthDataTypes = resolveHealthDataTypes(actualTypes);

    if (healthDataTypes.isEmpty) {
      // A dashboard is configured for a type the plugin no longer defines.
      // Silently doing nothing here is what made such dashboards look like a
      // broken import rather than a stale configuration.
      _logger.error(
        LogDomain.health,
        StateError('no health data type matches "$type"'),
        subDomain: 'fetchHealthDataDelta',
      );
      return const HealthImportResult.noMatchingTypes();
    }

    return _fetchHealthData(
      types: healthDataTypes,
      dateFrom: dateFrom,
      dateTo: now,
      userInitiated: false,
    );
  }

  /// Drains [queue], importing one type at a time.
  ///
  /// Each type is isolated: a type that throws is logged and the drain moves
  /// on, and [running] is cleared in a `finally`. Before that, an error
  /// anywhere in the drain left [running] permanently `true` — the queue kept
  /// accepting types that nothing would ever process again, so every health
  /// import for the rest of the session silently did nothing.
  Future<void> _start() async {
    try {
      while (queue.isNotEmpty) {
        final type = queue.removeFirst();
        try {
          await _serialized(() => _fetchHealthDataDelta(type));
        } catch (error, stackTrace) {
          _logger.error(
            LogDomain.health,
            error,
            stackTrace: stackTrace,
            subDomain: 'fetchHealthDataDelta',
          );
        }
      }
    } finally {
      running = false;
    }
  }

  /// Queues a background, incremental import of one dashboard health type.
  ///
  /// Returns as soon as the type is queued — dashboards must not wait on the
  /// health store to paint. Cumulative (activity) types are re-fetched at most
  /// every ten minutes, because their per-day totals change continuously while
  /// discrete samples do not.
  Future<void> fetchHealthDataDelta(String type) async {
    final now = clock.now();
    final lastFetch = lastFetched[type] ?? DateTime(0);

    if (now.difference(lastFetch) < const Duration(minutes: 10) &&
        type.contains('cumulative')) {
      return;
    }

    queue.add(type);
    lastFetched[type] = now;
    if (!running) {
      running = true;
      unawaited(_start());
    }
  }

  /// Imports workouts in the range as workout entries.
  ///
  /// Serialized against every other health request — see [_serialized].
  Future<HealthImportResult> getWorkoutsHealthData({
    required DateTime dateFrom,
    required DateTime dateTo,
    bool userInitiated = true,
  }) => _serialized(
    () => _getWorkoutsHealthData(
      dateFrom: dateFrom,
      dateTo: dateTo,
      userInitiated: userInitiated,
    ),
  );

  Future<HealthImportResult> _getWorkoutsHealthData({
    required DateTime dateFrom,
    required DateTime dateTo,
    required bool userInitiated,
  }) async {
    if (isDesktop) {
      return const HealthImportResult.unsupportedPlatform();
    }

    try {
      final now = clock.now();
      final dateToOrNow = dateTo.isAfter(now) ? now : dateTo;

      await _requestPermissions();
      final authorization = await authorizeHealth(
        workoutTypes,
        userInitiated: userInitiated,
      );

      if (authorization == HealthAuthorization.denied) {
        _logger.log(
          LogDomain.health,
          'authorization denied for workouts',
          subDomain: 'getWorkoutsHealthData',
          level: InsightLevel.warn,
        );
        return const HealthImportResult.permissionDenied();
      }

      final dataPoints = await health.getHealthDataFromTypes(
        types: workoutTypes,
        startTime: dateFrom,
        endTime: dateToOrNow,
      );

      if (dataPoints.isEmpty &&
          authorization != HealthAuthorization.granted &&
          await _db.latestWorkout() == null) {
        _logger.log(
          LogDomain.health,
          'no workouts in range and none ever stored — read access may be off',
          subDomain: 'getWorkoutsHealthData',
          level: InsightLevel.warn,
        );
        return const HealthImportResult.noDataOrAccess();
      }

      var imported = 0;

      for (final dataPoint in dataPoints.reversed) {
        final value = dataPoint.value;

        if (value is WorkoutHealthValue) {
          final workoutData = WorkoutData(
            dateFrom: dataPoint.dateFrom,
            dateTo: dataPoint.dateTo,
            distance: value.totalDistance,
            energy: value.totalEnergyBurned,
            source: dataPoint.sourceId,
            workoutType: value.workoutActivityType.name,
            id: dataPoint.uuid,
          );

          final stored = await persistenceLogic.createWorkoutEntry(workoutData);
          if (stored != null) {
            imported++;
          }
        }
      }

      _logger.log(
        LogDomain.health,
        'imported $imported of ${dataPoints.length} workout(s)',
        subDomain: 'getWorkoutsHealthData',
      );
      return HealthImportResult.imported(imported);
    } catch (error, stackTrace) {
      _logger.error(
        LogDomain.health,
        error,
        stackTrace: stackTrace,
        subDomain: 'getWorkoutsHealthData',
      );
      return HealthImportResult.failed(error);
    }
  }

  /// Imports workouts recorded since the newest stored one.
  ///
  /// [workoutImportRunning] guards against overlapping runs and is cleared in a
  /// `finally`: leaving it set on failure used to deadlock every later workout
  /// import for the rest of the session.
  Future<HealthImportResult> getWorkoutsHealthDataDelta() async {
    if (isDesktop) {
      return const HealthImportResult.unsupportedPlatform();
    }
    if (workoutImportRunning) {
      return const HealthImportResult.imported(0);
    }

    workoutImportRunning = true;

    try {
      final latest = await _db.latestWorkout();
      final now = clock.now();

      return await getWorkoutsHealthData(
        dateFrom: latest?.data.dateFrom ?? now.subtract(defaultFetchDuration),
        dateTo: now,
        // Scheduled by a chart, not asked for by the user — see
        // `_fetchHealthDataDelta`.
        userInitiated: false,
      );
    } catch (error, stackTrace) {
      _logger.error(
        LogDomain.health,
        error,
        stackTrace: stackTrace,
        subDomain: 'getWorkoutsHealthDataDelta',
      );
      return HealthImportResult.failed(error);
    } finally {
      workoutImportRunning = false;
    }
  }
}
