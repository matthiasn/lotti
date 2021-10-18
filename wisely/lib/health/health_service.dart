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

  Future<File> _localFile(String fileName) async {
    final docDir = await getApplicationDocumentsDirectory();
    String filePath = join(docDir.path, fileName);
    print('>>> filePath: $filePath');
    return File(filePath);
  }

  Future<File> writeJson(String fileName) async {
    final file = await _localFile(fileName);
    String jsonString = jsonEncode(_healthDataList);
    return file.writeAsString(jsonString);
  }

  List<HealthDataType> stepsTypes = [
    HealthDataType.STEPS,
  ];

  List<HealthDataType> movementTypes = [
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.FLIGHTS_CLIMBED,
  ];

  List<HealthDataType> workoutTypes = [
    HealthDataType.EXERCISE_TIME,
    HealthDataType.WORKOUT,
  ];

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
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
  ];

  List<HealthDataType> bodyMeasurementTypes = [
    HealthDataType.WEIGHT,
    HealthDataType.BODY_FAT_PERCENTAGE,
  ];

  List<HealthDataType> energyTypes = [
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.BASAL_ENERGY_BURNED,
  ];

  Future fetchData({
    required List<HealthDataType> types,
    required String filename,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    HealthFactory health = HealthFactory();

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

      await writeJson(filename);

      print("Steps: $steps");
    } else {
      print("Authorization not granted");
    }
  }
}
