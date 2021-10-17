import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:wisely/health/health_service.dart';

class HealthPage extends StatefulWidget {
  const HealthPage({Key? key}) : super(key: key);

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  late HealthService healthService;

  @override
  void initState() {
    super.initState();
    healthService = HealthService();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            OutlinedButton(
              onPressed: () => healthService.fetchData(
                types: healthService.sleepTypes,
                filename: 'sleep.json',
                startDate: DateTime(2021, 07, 01, 0, 0, 0),
                endDate: DateTime(2025, 01, 01, 23, 59, 59),
              ),
              child: const Text(
                'Import Sleep Data',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: () => healthService.fetchData(
                types: healthService.heartTypes,
                filename: 'heart.json',
                startDate: DateTime(2021, 07, 01, 0, 0, 0),
                endDate: DateTime(2025, 01, 01, 23, 59, 59),
              ),
              child: const Text(
                'Import Heart Data',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: () => healthService.fetchData(
                types: healthService.bodyMeasurementTypes,
                filename: 'body.json',
                startDate: DateTime(2021, 07, 01, 0, 0, 0),
                endDate: DateTime(2025, 01, 01, 23, 59, 59),
              ),
              child: const Text(
                'Import Body Measurement Data',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: () => healthService.fetchData(
                types: healthService.movementTypes,
                filename: 'movement.json',
                startDate: DateTime(2021, 07, 01, 0, 0, 0),
                endDate: DateTime(2025, 01, 01, 23, 59, 59),
              ),
              child: const Text(
                'Import Steps, Stairs, Distance',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: () => healthService.fetchData(
                types: healthService.workoutTypes,
                filename: 'workouts.json',
                startDate: DateTime(2021, 07, 01, 0, 0, 0),
                endDate: DateTime(2025, 01, 01, 23, 59, 59),
              ),
              child: const Text(
                'Import Workout Data',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
