import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:health/health.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class HealthService {
  List<HealthDataPoint> _healthDataList = [];

  HealthService() {
    //fetchData();
  }

  Future<File> get _localFile async {
    final docDir = await getApplicationDocumentsDirectory();
    String filePath = join(docDir.path, 'health.json');

    print('>>> filePath: $filePath');

    return File(filePath);
  }

  Future<File> writeJson() async {
    final file = await _localFile;

    String jsonString = jsonEncode(_healthDataList);
    return file.writeAsString(jsonString);
  }

  Future fetchData() async {
    DateTime startDate = DateTime(2021, 07, 01, 0, 0, 0);
    DateTime endDate = DateTime(2025, 01, 01, 23, 59, 59);

    HealthFactory health = HealthFactory();

    List<HealthDataType> types = [
      HealthDataType.STEPS,
      HealthDataType.DISTANCE_WALKING_RUNNING,
      HealthDataType.WEIGHT,
      HealthDataType.BODY_FAT_PERCENTAGE,
      HealthDataType.SLEEP_IN_BED,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
      HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
      HealthDataType.HEART_RATE,
      HealthDataType.RESTING_HEART_RATE,
      HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    ];

    // you MUST request access to the data types before reading them
    bool accessWasGranted = await health.requestAuthorization(types);

    int steps = 0;

    if (accessWasGranted) {
      try {
        // fetch new data
        List<HealthDataPoint> healthData =
            await health.getHealthDataFromTypes(startDate, endDate, types);

        // save all the new data points
        _healthDataList.addAll(healthData);
      } catch (e) {
        print("Caught exception in getHealthDataFromTypes: $e");
      }

      // filter out duplicates
      _healthDataList = HealthFactory.removeDuplicates(_healthDataList);

      // print the results
      _healthDataList.forEach((x) {
        //print("Data point: $x");
        if (x.type == HealthDataType.STEPS) {
          steps += x.value.round();
        }
      });

      await writeJson();

      print("Steps: $steps");
    } else {
      print("Authorization not granted");
    }
  }
}
