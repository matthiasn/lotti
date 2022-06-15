import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_health_fit/flutter_health_fit.dart';
import 'package:flutter_health_fit/workout_sample.dart';
import 'package:health/health.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/utils/platform.dart';

class HealthImport {
  HealthImport() : super() {
    getPlatform();
  }
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final JournalDb _db = getIt<JournalDb>();
  final HealthFactory _healthFactory = HealthFactory();
  Duration defaultFetchDuration = const Duration(days: 90);

  late final String platform;
  String? deviceType;

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

  Future<void> getActivityHealthData({
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    final now = DateTime.now();

    final loggingDb = getIt<LoggingDb>();
    final transaction =
        loggingDb.startTransaction('getActivityHealthData()', 'task');
    final accessGranted = await authorizeHealth(activityTypes);

    if (!accessGranted) {
      return;
    }

    Future<void> addEntries(Map<DateTime, num> data, String type) async {
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
          unit: 'count',
          deviceType: deviceType,
          platformType: platform,
        );
        await persistenceLogic.createQuantitativeEntry(activityForDay);
      }
    }

    final stepsByDay = <DateTime, num>{};
    final flightsByDay = <DateTime, num>{};
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

        flightsByDay[dateFrom] = flightsClimbed ?? 0;
        stepsByDay[dateFrom] = steps ?? 0;
      }
    }

    await addEntries(stepsByDay, 'cumulative_step_count');
    await addEntries(flightsByDay, 'cumulative_flights_climbed');
    await transaction.finish();
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
    final loggingDb = getIt<LoggingDb>();
    final transaction = loggingDb.startTransaction('fetchHealthData()', 'task');
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
          final discreteQuantity = DiscreteQuantityData(
            dateFrom: dataPoint.dateFrom,
            dateTo: dataPoint.dateTo,
            value: dataPoint.value,
            dataType: dataPoint.type.toString(),
            unit: dataPoint.unit.toString(),
            deviceType: deviceType,
            platformType: platform,
            sourceId: dataPoint.sourceId,
            sourceName: dataPoint.sourceName,
            deviceId: dataPoint.deviceId,
          );
          await persistenceLogic.createQuantitativeEntry(discreteQuantity);
        }
      } catch (e) {
        debugPrint('Caught exception in fetchHealthData: $e');
      }
    }
    await transaction.finish();
  }

  Future<void> fetchHealthDataDelta(String type) async {
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

  Future<void> getWorkoutsHealthData({
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    final now = DateTime.now();
    final dateToOrNow = dateTo.isAfter(now) ? now : dateTo;
    final loggingDb = getIt<LoggingDb>();
    final transaction =
        loggingDb.startTransaction('getActivityHealthData()', 'task');
    debugPrint('getWorkoutsHealthData $dateFrom - $dateTo');

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

    await transaction.finish();
  }

  Future<void> getWorkoutsHealthDataDelta() async {
    final latest = await _db.latestWorkout();
    final now = DateTime.now();

    await getWorkoutsHealthData(
      dateFrom: latest?.data.dateFrom ?? now.subtract(defaultFetchDuration),
      dateTo: now,
    );
  }
}

List<HealthDataType> sleepTypes = [
  HealthDataType.SLEEP_IN_BED,
  HealthDataType.SLEEP_ASLEEP,
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

List<HealthDataType> workoutTypes = [
  HealthDataType.EXERCISE_TIME,
  HealthDataType.WORKOUT,
];

List<HealthDataType> activityTypes = [
  HealthDataType.STEPS,
  HealthDataType.FLIGHTS_CLIMBED,
];
