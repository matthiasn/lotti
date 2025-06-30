import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:health/health.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/health_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/platform.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthImport {
  HealthImport({
    required this.persistenceLogic,
    required JournalDb db,
    required this.health,
    required this.deviceInfo,
  }) : _db = db {
    getPlatform();
  }
  final PersistenceLogic persistenceLogic;
  final JournalDb _db;
  final HealthService health;
  final DeviceInfoPlugin deviceInfo;

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
    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceType = iosInfo.utsname.machine;
    }
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceType = androidInfo.model;
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
    final now = DateTime.now();
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

      final steps = await health.getTotalStepsInInterval(dateFrom, dateTo);
      stepsByDay[dateFrom] = steps ?? 0;

      final flightsClimbedDataPoints = await health.getHealthDataFromTypes(
        types: [HealthDataType.FLIGHTS_CLIMBED],
        startTime: dateFrom,
        endTime: dateTo,
      );

      final distanceDataPoints = await health.getHealthDataFromTypes(
        types: [HealthDataType.DISTANCE_WALKING_RUNNING],
        startTime: dateFrom,
        endTime: dateTo,
      );

      flightsByDay[dateFrom] = sumNumericHealthValues(flightsClimbedDataPoints);
      distanceByDay[dateFrom] = sumNumericHealthValues(distanceDataPoints);
    }
  }

  Future<void> addActivityEntries(
    Map<DateTime, num> data,
    String type,
    String unit,
  ) async {
    final now = DateTime.now();
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

  Future<void> getActivityHealthData({
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    if (isDesktop) {
      return;
    }

    await Permission.activityRecognition.request();
    await Permission.location.request();
    final accessWasGranted = await authorizeHealth(activityTypes) ?? false;

    if (!accessWasGranted) {
      return;
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

    await addActivityEntries(stepsByDay, 'cumulative_step_count', 'count');
    await addActivityEntries(
        flightsByDay, 'cumulative_flights_climbed', 'count');
    await addActivityEntries(distanceByDay, 'cumulative_distance', 'meters');
  }

  num sumNumericHealthValues(List<HealthDataPoint> dataPoints) {
    return dataPoints
        .map((HealthDataPoint e) => e.value)
        .whereType<NumericHealthValue>()
        .map((NumericHealthValue e) => e.numericValue)
        .sum;
  }

  Future<bool?> authorizeHealth(List<HealthDataType> types) async {
    if (isDesktop) {
      return false;
    }
    final allowed = health.requestAuthorization(types);
    return allowed;
  }

  Future<void> fetchHealthData({
    required List<HealthDataType> types,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    if (isDesktop) {
      return;
    }

    final accessWasGranted = await authorizeHealth(types) ?? false;

    if (accessWasGranted) {
      try {
        final now = DateTime.now();
        final dateToOrNow = dateTo.isAfter(now) ? now : dateTo;
        final dataPoints = await health.getHealthDataFromTypes(
          types: types,
          startTime: dateFrom,
          endTime: dateToOrNow,
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
            );
            await persistenceLogic.createQuantitativeEntry(discreteQuantity);

            // Also save more specific sleep types as generic time asleep
            // for comparability with data from prior to iOS 16 in combination
            // with watchOS 9
            if ({
              'HealthDataType.SLEEP_ASLEEP_CORE',
              'HealthDataType.SLEEP_DEEP',
              'HealthDataType.SLEEP_REM',
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
        getIt<LoggingService>().captureException(
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
      final accessWasGranted = await authorizeHealth(healthDataTypes) ?? false;
      if (accessWasGranted && healthDataTypes.isNotEmpty) {
        await fetchHealthData(
          types: healthDataTypes,
          dateFrom: dateFrom,
          dateTo: now,
        );
      }
    }
  }

  Future<void> _start() async {
    while (queue.isNotEmpty) {
      await _fetchHealthDataDelta(queue.removeFirst());
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

    await Permission.activityRecognition.request();
    await Permission.location.request();
    const types = [HealthDataType.WORKOUT];
    final accessWasGranted = await authorizeHealth(types);

    if (accessWasGranted != true) {
      return;
    }

    final dataPoints = await health.getHealthDataFromTypes(
      types: types,
      startTime: dateFrom,
      endTime: dateToOrNow,
    );

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

        await persistenceLogic.createWorkoutEntry(workoutData);
      }
    }
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
  HealthDataType.SLEEP_LIGHT,
  HealthDataType.SLEEP_DEEP,
  HealthDataType.SLEEP_REM,
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
