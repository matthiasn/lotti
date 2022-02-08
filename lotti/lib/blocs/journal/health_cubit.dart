import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_health_fit/flutter_health_fit.dart';
import 'package:health/health.dart';
import 'package:lotti/blocs/journal/health_state.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/database/insights_db.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/main.dart';

class HealthCubit extends Cubit<HealthState> {
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  late final String platform;
  String? deviceType;

  HealthCubit() : super(HealthState()) {
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

  Future getActivityHealthData(
      {required DateTime dateFrom, required DateTime dateTo}) async {
    DateTime now = DateTime.now();
    DateTime dateToOrNow = dateTo.isAfter(now) ? now : dateTo;

    final InsightsDb _insightsDb = getIt<InsightsDb>();
    final transaction =
        _insightsDb.startTransaction('getActivityHealthData()', 'task');

    final flutterHealthFit = FlutterHealthFit();
    final bool isAuthorized = await FlutterHealthFit().authorize(true);
    final bool isAnyAuth = await flutterHealthFit.isAnyPermissionAuthorized();
    debugPrint(
        'flutterHealthFit isAuthorized: $isAuthorized, isAnyAuth: $isAnyAuth');

    Future<void> addEntries(Map<DateTime, int> data, String type) async {
      for (MapEntry<DateTime, int> dailyStepsEntry in data.entries) {
        DateTime dateFrom = dailyStepsEntry.key;
        DateTime dateTo = dateFrom
            .add(const Duration(days: 1))
            .subtract(const Duration(milliseconds: 1));
        DateTime dateToOrNow = dateTo.isAfter(now) ? now : dateTo;
        CumulativeQuantityData activityForDay = CumulativeQuantityData(
          dateFrom: dateFrom,
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

    final Map<DateTime, int> stepCounts = await FlutterHealthFit()
        .getStepsBySegment(dateFrom.millisecondsSinceEpoch,
            dateToOrNow.millisecondsSinceEpoch, 1, TimeUnit.days);
    addEntries(stepCounts, 'cumulative_step_count');

    final Map<DateTime, int> flights = await FlutterHealthFit()
        .getFlightsBySegment(dateFrom.millisecondsSinceEpoch,
            dateToOrNow.millisecondsSinceEpoch, 1, TimeUnit.days);
    addEntries(flights, 'cumulative_flights_climbed');
    await transaction.finish();
  }

  Future fetchHealthData({
    required List<HealthDataType> types,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    final InsightsDb _insightsDb = getIt<InsightsDb>();

    final transaction =
        _insightsDb.startTransaction('fetchHealthData()', 'task');
    HealthFactory health = HealthFactory();
    bool accessWasGranted = await health.requestAuthorization(types);

    if (accessWasGranted) {
      try {
        DateTime now = DateTime.now();
        DateTime dateToOrNow = dateTo.isAfter(now) ? now : dateTo;
        List<HealthDataPoint> dataPoints =
            await health.getHealthDataFromTypes(dateFrom, dateToOrNow, types);

        for (HealthDataPoint dataPoint in dataPoints) {
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
}
