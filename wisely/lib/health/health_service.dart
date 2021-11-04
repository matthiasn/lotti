import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_health_fit/flutter_health_fit.dart';
import 'package:health/health.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wisely/classes/health.dart';

class HealthService {
  List<HealthDataPoint> _healthDataList = [];

  HealthService() {
    //fetchData();
  }

  Future<File> _localFile(String fileName) async {
    final docDir = await getApplicationDocumentsDirectory();
    String filePath = join(docDir.path, fileName);
    debugPrint('>>> filePath: $filePath');
    return File(filePath);
  }

  Future<File> writeJson(String fileName) async {
    final file = await _localFile(fileName);
    String jsonString = jsonEncode(_healthDataList);
    return file.writeAsString(jsonString);
  }

  Future fetchData({
    required List<HealthDataType> types,
    required String filename,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    HealthFactory health = HealthFactory();

    // you MUST request access to the data types before reading them
    bool accessWasGranted = await health.requestAuthorization(types);

    if (accessWasGranted) {
      try {
        // fetch new data
        List<HealthDataPoint> healthData =
            await health.getHealthDataFromTypes(dateFrom, dateTo, types);

        // save all the new data points
        _healthDataList.addAll(healthData);
      } catch (e) {
        debugPrint('Caught exception in getHealthDataFromTypes: $e');
      }

      // filter out duplicates
      _healthDataList = HealthFactory.removeDuplicates(_healthDataList);

      await writeJson(filename);
    } else {
      debugPrint('Authorization not granted');
    }
  }

  Future getActivityHealthData({
    required String filename,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    final flutterHealthFit = FlutterHealthFit();
    final bool isAuthorized = await FlutterHealthFit().authorize(true);
    final bool isAnyAuth = await flutterHealthFit.isAnyPermissionAuthorized();
    debugPrint(
        'flutterHealthFit isAuthorized: $isAuthorized, isAnyAuth: $isAnyAuth');

    String? deviceType;
    String platform = Platform.isIOS
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

    List<HealthData> cumulativeQuantities = [];

    void addEntries(Map<DateTime, int> data, String type) {
      for (MapEntry<DateTime, int> dailyStepsEntry in data.entries) {
        DateTime dateFrom = dailyStepsEntry.key;
        DateTime dateTo = dateFrom.add(const Duration(days: 1));
        CumulativeQuantity stepsForDay = CumulativeQuantity(
          dateFrom: dateFrom,
          dateTo: dateTo,
          value: dailyStepsEntry.value,
          dataType: type,
          unit: 'count',
          deviceType: deviceType,
          platformType: platform,
        );
        cumulativeQuantities.add(stepsForDay);
      }
    }

    final Map<DateTime, int> stepCounts = await FlutterHealthFit()
        .getStepsBySegment(dateFrom.millisecondsSinceEpoch,
            dateTo.millisecondsSinceEpoch, 1, TimeUnit.days);
    addEntries(stepCounts, 'cumulative_step_count');

    final Map<DateTime, int> flights = await FlutterHealthFit()
        .getFlightsBySegment(dateFrom.millisecondsSinceEpoch,
            dateTo.millisecondsSinceEpoch, 1, TimeUnit.days);
    addEntries(flights, 'cumulative_flights_climbed');

    final file = await _localFile(filename);
    String jsonString = jsonEncode(cumulativeQuantities);
    return file.writeAsString(jsonString);
  }
}
