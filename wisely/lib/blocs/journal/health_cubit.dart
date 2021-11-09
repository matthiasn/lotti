import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_health_fit/flutter_health_fit.dart';
import 'package:health/health.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:wisely/blocs/journal/health_state.dart';
import 'package:wisely/blocs/journal/persistence_cubit.dart';
import 'package:wisely/classes/health.dart';

class HealthCubit extends Cubit<HealthState> {
  late final PersistenceCubit _persistenceCubit;
  String? deviceType;
  late final String platform;

  HealthCubit({
    required PersistenceCubit persistenceCubit,
  }) : super(HealthState()) {
    _persistenceCubit = persistenceCubit;
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
    final transaction =
        Sentry.startTransaction('getActivityHealthData()', 'task');
    final flutterHealthFit = FlutterHealthFit();
    final bool isAuthorized = await FlutterHealthFit().authorize(true);
    final bool isAnyAuth = await flutterHealthFit.isAnyPermissionAuthorized();
    debugPrint(
        'flutterHealthFit isAuthorized: $isAuthorized, isAnyAuth: $isAnyAuth');

    void addEntries(Map<DateTime, int> data, String type) {
      List<CumulativeQuantityData> cumulativeQuantities = [];

      for (MapEntry<DateTime, int> dailyStepsEntry in data.entries) {
        DateTime dateFrom = dailyStepsEntry.key;
        DateTime dateTo = dateFrom.add(const Duration(days: 1));
        CumulativeQuantityData activityForDay = CumulativeQuantityData(
          dateFrom: dateFrom,
          dateTo: dateTo,
          value: dailyStepsEntry.value,
          dataType: type,
          unit: 'count',
          deviceType: deviceType,
          platformType: platform,
        );
        cumulativeQuantities.add(activityForDay);
      }
      _persistenceCubit.createQuantitativeEntries(cumulativeQuantities);
    }

    final Map<DateTime, int> stepCounts = await FlutterHealthFit()
        .getStepsBySegment(dateFrom.millisecondsSinceEpoch,
            dateTo.millisecondsSinceEpoch, 1, TimeUnit.days);
    addEntries(stepCounts, 'cumulative_step_count');

    final Map<DateTime, int> flights = await FlutterHealthFit()
        .getFlightsBySegment(dateFrom.millisecondsSinceEpoch,
            dateTo.millisecondsSinceEpoch, 1, TimeUnit.days);
    addEntries(flights, 'cumulative_flights_climbed');
    await transaction.finish();
  }

  Future fetchHealthData({
    required List<HealthDataType> types,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    final transaction = Sentry.startTransaction('fetchHealthData()', 'task');
    HealthFactory health = HealthFactory();
    bool accessWasGranted = await health.requestAuthorization(types);

    if (accessWasGranted) {
      try {
        List<HealthDataPoint> dataPoints =
            await health.getHealthDataFromTypes(dateFrom, dateTo, types);
        List<DiscreteQuantityData> discreteQuantities = [];

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
          discreteQuantities.add(discreteQuantity);
        }
        _persistenceCubit.createQuantitativeEntries(discreteQuantities);
      } catch (e) {
        debugPrint('Caught exception in fetchHealthData: $e');
      }
    } else {
      debugPrint('Authorization not granted');
    }
    await transaction.finish();
  }
}
