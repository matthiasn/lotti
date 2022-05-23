import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/widgets.dart';
// import 'package:flutter_health_fit/flutter_health_fit.dart';
// import 'package:flutter_health_fit/workout_sample.dart';
import 'package:health/health.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';

class HealthImport {
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final JournalDb _db = getIt<JournalDb>();
  final HealthFactory _healthFactory = HealthFactory();
  Duration defaultFetchDuration = const Duration(days: 90);

  late final String platform;
  String? deviceType;

  HealthImport() : super() {
    getPlatform();
  }

  Future<void> getPlatform() async {
    platform = Platform.isIOS
        ? 'IOS'
        : Platform.isAndroid
            ? 'ANDROID'
            : '';
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      deviceType = iosInfo.utsname.machine;
    }
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      deviceType = androidInfo.model;
    }
  }

  Future<void> getActivityHealthData({
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    DateTime now = DateTime.now();

    final LoggingDb loggingDb = getIt<LoggingDb>();
    final transaction =
        loggingDb.startTransaction('getActivityHealthData()', 'task');
    await authorizeHealth(activityTypes);

    Future<void> addEntries(Map<DateTime, num> data, String type) async {
      List<MapEntry<DateTime, num>> entries = List.from(data.entries);
      entries.sort((a, b) => a.key.compareTo(b.key));

      for (MapEntry<DateTime, num> dailyStepsEntry in entries) {
        DateTime dayStart = dailyStepsEntry.key;
        DateTime dayEnd = dayStart
            .add(const Duration(days: 1))
            .subtract(const Duration(milliseconds: 1));
        DateTime dateToOrNow = dayEnd.isAfter(now) ? now : dayEnd;
        CumulativeQuantityData activityForDay = CumulativeQuantityData(
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

    Map<DateTime, num> stepsByDay = {};
    Map<DateTime, num> flightsByDay = {};
    Duration range = dateTo.difference(dateFrom);

    List<DateTime> days = List<DateTime>.generate(range.inDays + 1, (days) {
      DateTime day = dateFrom.add(Duration(days: days));
      return DateTime(
        day.year,
        day.month,
        day.day,
      );
    });

    for (DateTime dateFrom in days) {
      if (dateFrom.isBefore(now)) {
        DateTime dateTo = DateTime(
            dateFrom.year, dateFrom.month, dateFrom.day, 23, 59, 59, 999);

        int? steps =
            await _healthFactory.getTotalStepsInInterval(dateFrom, dateTo);
        int? flightsClimbed = await _healthFactory
            .getTotalFlightsClimbedInInterval(dateFrom, dateTo);

        flightsByDay[dateFrom] = flightsClimbed ?? 0;
        stepsByDay[dateFrom] = steps ?? 0;
      }
    }

    addEntries(stepsByDay, 'cumulative_step_count');
    addEntries(flightsByDay, 'cumulative_flights_climbed');
    await transaction.finish();
  }

  Future<bool> authorizeHealth(List<HealthDataType> types) async {
    return await _healthFactory.requestAuthorization(types);
  }

  Future<void> fetchHealthData({
    required List<HealthDataType> types,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    final LoggingDb loggingDb = getIt<LoggingDb>();
    final transaction = loggingDb.startTransaction('fetchHealthData()', 'task');
    bool accessWasGranted = await authorizeHealth(types);

    if (accessWasGranted) {
      try {
        DateTime now = DateTime.now();
        DateTime dateToOrNow = dateTo.isAfter(now) ? now : dateTo;
        List<HealthDataPoint> dataPoints =
            await _healthFactory.getHealthDataFromTypes(
          dateFrom,
          dateToOrNow,
          types,
        );

        for (HealthDataPoint dataPoint in dataPoints.reversed) {
          DiscreteQuantityData discreteQuantity = DiscreteQuantityData(
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
    } else {
      debugPrint('Authorization not granted');
    }
    await transaction.finish();
  }

  Future<void> fetchHealthDataDelta(String type) async {
    List<String> actualTypes = [type];

    if (type == 'BLOOD_PRESSURE') {
      actualTypes = [
        'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
        'HealthDataType.BLOOD_PRESSURE_DIASTOLIC',
      ];
    } else if (type == 'BODY_MASS_INDEX') {
      actualTypes = ['HealthDataType.WEIGHT'];
    }

    QuantitativeEntry? latest =
        await _db.latestQuantitativeByType(actualTypes.first);
    DateTime now = DateTime.now();

    DateTime dateFrom =
        latest?.meta.dateFrom ?? now.subtract(defaultFetchDuration);

    List<HealthDataType> healthDataTypes = [];

    for (String type in actualTypes) {
      String subType = type.replaceAll('HealthDataType.', '');
      HealthDataType? healthDataType =
          EnumToString.fromString(HealthDataType.values, subType);

      if (healthDataType != null) {
        healthDataTypes.add(healthDataType);
      }
    }

    if (type.contains('cumulative')) {
      getActivityHealthData(
        dateFrom: dateFrom,
        dateTo: now,
      );
    } else {
      bool accessWasGranted = await authorizeHealth(healthDataTypes);
      if (accessWasGranted && healthDataTypes.isNotEmpty) {
        fetchHealthData(
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
    DateTime now = DateTime.now();
    DateTime dateToOrNow = dateTo.isAfter(now) ? now : dateTo;

    final LoggingDb loggingDb = getIt<LoggingDb>();
    final transaction =
        loggingDb.startTransaction('getActivityHealthData()', 'task');
    debugPrint('getWorkoutsHealthData $dateFrom - $dateTo');

    // List<WorkoutSample>? workouts =
    //     await FlutterHealthFit().getWorkoutsBySegment(
    //   dateFrom.millisecondsSinceEpoch,
    //   dateToOrNow.millisecondsSinceEpoch,
    // );
    //
    // workouts?.forEach((WorkoutSample workoutSample) async {
    //   WorkoutData workoutData = WorkoutData(
    //     dateFrom: workoutSample.start,
    //     dateTo: workoutSample.end,
    //     distance: workoutSample.distance,
    //     energy: workoutSample.energy,
    //     source: workoutSample.source,
    //     workoutType: workoutSample.type.name,
    //     id: workoutSample.id,
    //   );
    //   await persistenceLogic.createWorkoutEntry(workoutData);
    // });

    await transaction.finish();
  }

  Future<void> getWorkoutsHealthDataDelta() async {
    WorkoutEntry? latest = await _db.latestWorkout();
    DateTime now = DateTime.now();

    getWorkoutsHealthData(
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
