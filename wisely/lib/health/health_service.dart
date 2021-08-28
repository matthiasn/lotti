import 'dart:async';

import 'package:health/health.dart';

class HealthService {
  List<HealthDataPoint> _healthDataList = [];

  HealthService() {
    fetchData();
  }

  Future fetchData() async {
    // get everything from midnight until now
    DateTime startDate = DateTime(2021, 07, 01, 0, 0, 0);
    DateTime endDate = DateTime(2025, 01, 01, 23, 59, 59);

    HealthFactory health = HealthFactory();

    // define the types to get
    List<HealthDataType> types = [
      HealthDataType.STEPS,
      HealthDataType.WEIGHT,
      HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
      HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
      HealthDataType.DISTANCE_WALKING_RUNNING,
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
        print("Data point: $x");
        steps += x.value.round();
      });

      print("Steps: $steps");
    } else {
      print("Authorization not granted");
    }
  }
}
