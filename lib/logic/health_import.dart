import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter_health_fit/flutter_health_fit.dart';
import 'package:flutter_health_fit/workout_sample.dart';
import 'package:health/health.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence/persistence_logic.dart';
import 'package:lotti/utils/platform.dart';

class HealthImport {
  HealthImport() : super() {
    getPlatform();
  }
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final JournalDb _db = getIt<JournalDb>();
  final HealthFactory _healthFactory = HealthFactory();
  Duration defaultFetchDuration = const Duration(days: 90);

  final queue = Queue<String>();
  bool running = false;
  bool workoutImportRunning = false;

  late final String platform;
  String? deviceType;
  Map<String, DateTime> lastFetched = {};

  Future<void> getPlatform() async {
    platform = Platform.isIOS
        ? 'IOS'
        : Platform.isAndroid
            ? 'ANDROID'
            : '';
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceType = iosInfo.utsname.machine;
    }
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceType = androidInfo.model;
    }
  }

  Future<void> _getActivityHealthData({
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    if (isDesktop) {
      return;
    }

    final now = DateTime.now();
    final accessGranted = await authorizeHealth(activityTypes);

    if (!accessGranted) {
      return;
    }

    Future<void> addEntries(
      Map<DateTime, num> data,
      String type,
      String unit,
    ) async {
      final entries = List<MapEntry<DateTime, num>>.from(data.entries)
        ..sort((a, b) => a.key.compareTo(b.key));

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
        await persistenceLogic.createQuantitativeEntry(activityForDay);
      }
    }

    final stepsByDay = <DateTime, num>{};
    final flightsByDay = <DateTime, num>{};
    final distanceByDay = <DateTime, num>{};
    final range = dateTo.difference(dateFrom);

    final days = List<DateTime>.generate(range.inDays + 1, (days) {
      final day = dateFrom.add(Duration(days: days));
      return DateTime(
        day.year,
        day.month,
        day.day,
      );
    });

    for (final dateFrom in days) {
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

        final steps =
            await _healthFactory.getTotalStepsInInterval(dateFrom, dateTo);

        final flightsClimbed = await _healthFactory
            .getTotalFlightsClimbedInInterval(dateFrom, dateTo);
        final distance =
            await _healthFactory.getTotalDistanceInInterval(dateFrom, dateTo);

        flightsByDay[dateFrom] = flightsClimbed ?? 0;
        stepsByDay[dateFrom] = steps ?? 0;
        distanceByDay[dateFrom] = distance ?? 0;
      }
    }

    await addEntries(stepsByDay, 'cumulative_step_count', 'count');
    await addEntries(flightsByDay, 'cumulative_flights_climbed', 'count');
    await addEntries(distanceByDay, 'cumulative_distance', 'meters');
  }

  Future<void> getActivityHealthData({
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    await _db.transaction<void>(() async {
      await _getActivityHealthData(
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
    });
  }

  Future<bool> authorizeHealth(List<HealthDataType> types) async {
    if (isDesktop) {
      return false;
    }

    return _healthFactory.requestAuthorization(types);
  }

  Future<void> fetchHealthData({
    required List<HealthDataType> types,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    if (isDesktop) {
      return;
    }

    final accessWasGranted = await authorizeHealth(types);

    if (accessWasGranted) {
      try {
        final now = DateTime.now();
        final dateToOrNow = dateTo.isAfter(now) ? now : dateTo;
        final dataPoints = await _healthFactory.getHealthDataFromTypes(
          dateFrom,
          dateToOrNow,
          types,
        );

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
              deviceId: dataPoint.deviceId,
            );
            await persistenceLogic.createQuantitativeEntry(discreteQuantity);

            // Also save more specific sleep types as generic time asleep
            // for comparability with data from prior to iOS 16 in combination
            // with watchOS 9
            if ({
              'HealthDataType.SLEEP_ASLEEP_CORE',
              'HealthDataType.SLEEP_ASLEEP_DEEP',
              'HealthDataType.SLEEP_ASLEEP_REM',
              'HealthDataType.SLEEP_ASLEEP_UNSPECIFIED',
            }.contains(dataType)) {
              await persistenceLogic.createQuantitativeEntry(
                discreteQuantity.copyWith(
                  dataType: 'HealthDataType.SLEEP_ASLEEP',
                ),
              );
            }
          }
        }
      } catch (e) {
        getIt<LoggingDb>().captureException(
          e,
          domain: 'HEALTH_IMPORT',
          subDomain: 'fetchHealthData',
        );
      }
    }
  }

  Future<void> _fetchHealthDataDelta(String type) async {
    if (isDesktop) {
      return;
    }

    running = true;
    var actualTypes = [type];

    if (type == 'BLOOD_PRESSURE') {
      actualTypes = [
        'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
        'HealthDataType.BLOOD_PRESSURE_DIASTOLIC',
      ];
    } else if (type == 'BODY_MASS_INDEX') {
      actualTypes = ['HealthDataType.WEIGHT'];
    }

    final latest = await _db.latestQuantitativeByType(actualTypes.first);
    final now = DateTime.now();

    final dateFrom =
        latest?.meta.dateFrom ?? now.subtract(defaultFetchDuration);

    final healthDataTypes = <HealthDataType>[];

    for (final type in actualTypes) {
      final subType = type.replaceAll('HealthDataType.', '');
      final healthDataType =
          EnumToString.fromString(HealthDataType.values, subType);

      if (healthDataType != null) {
        healthDataTypes.add(healthDataType);
      }
    }

    if (type.contains('cumulative')) {
      await getActivityHealthData(
        dateFrom: dateFrom,
        dateTo: now,
      );
    } else {
      final accessWasGranted = await authorizeHealth(healthDataTypes);
      if (accessWasGranted && healthDataTypes.isNotEmpty) {
        await fetchHealthData(
          types: healthDataTypes,
          dateFrom: dateFrom,
          dateTo: now,
        );
      }
    }
  }

  Future<void> _fetchHealthDataDeltaTx(String type) async {
    await _db.transaction<void>(() async {
      await _fetchHealthDataDelta(type);
    });
  }

  Future<void> _start() async {
    while (queue.isNotEmpty) {
      await _fetchHealthDataDeltaTx(queue.removeFirst());
    }

    running = false;
  }

  Future<void> fetchHealthDataDelta(String type) async {
    final now = DateTime.now();
    final lastFetch = lastFetched[type] ?? DateTime(0);

    if (now.difference(lastFetch) < const Duration(minutes: 10) &&
        type.contains('cumulative')) {
      return;
    }

    queue.add(type);
    lastFetched[type] = now;
    if (!running) {
      unawaited(_start());
    }
  }

  Future<void> getWorkoutsHealthData({
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    if (isDesktop) {
      return;
    }

    final now = DateTime.now();
    final dateToOrNow = dateTo.isAfter(now) ? now : dateTo;

    await FlutterHealthFit().authorize();

    final workouts = await FlutterHealthFit().getWorkoutsBySegment(
      dateFrom.millisecondsSinceEpoch,
      dateToOrNow.millisecondsSinceEpoch,
    );

    workouts?.forEach((WorkoutSample workoutSample) async {
      final workoutData = WorkoutData(
        dateFrom: workoutSample.start,
        dateTo: workoutSample.end,
        distance: workoutSample.distance,
        energy: workoutSample.energy,
        source: workoutSample.source,
        workoutType: workoutSample.type.name,
        id: workoutSample.id,
      );
      await persistenceLogic.createWorkoutEntry(workoutData);
    });
  }

  Future<void> getWorkoutsHealthDataDelta() async {
    if (isDesktop || workoutImportRunning) {
      return;
    }

    workoutImportRunning = true;

    final latest = await _db.latestWorkout();
    final now = DateTime.now();

    await getWorkoutsHealthData(
      dateFrom: latest?.data.dateFrom ?? now.subtract(defaultFetchDuration),
      dateTo: now,
    );

    workoutImportRunning = false;
  }
}

List<HealthDataType> sleepTypes = [
  HealthDataType.SLEEP_IN_BED,
  HealthDataType.SLEEP_ASLEEP,
  HealthDataType.SLEEP_ASLEEP_CORE,
  HealthDataType.SLEEP_ASLEEP_DEEP,
  HealthDataType.SLEEP_ASLEEP_REM,
  HealthDataType.SLEEP_ASLEEP_UNSPECIFIED,
  HealthDataType.SLEEP_AWAKE,
];

List<HealthDataType> bpTypes = [
  HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
  HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
];

List<HealthDataType> heartRateTypes = [
  HealthDataType.RESTING_HEART_RATE,
  HealthDataType.WALKING_HEART_RATE,
  HealthDataType.HEART_RATE_VARIABILITY_SDNN,
];

List<HealthDataType> bodyMeasurementTypes = [
  HealthDataType.WEIGHT,
  HealthDataType.BODY_FAT_PERCENTAGE,
  HealthDataType.BODY_MASS_INDEX,
  HealthDataType.HEIGHT,
];

List<HealthDataType> activityTypes = [
  HealthDataType.STEPS,
  HealthDataType.FLIGHTS_CLIMBED,
  HealthDataType.DISTANCE_WALKING_RUNNING,
];
