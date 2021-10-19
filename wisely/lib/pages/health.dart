import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:wisely/health/health_service.dart';

class HealthPage extends StatefulWidget {
  const HealthPage({Key? key}) : super(key: key);

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  late HealthService healthService;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));

  @override
  void initState() {
    super.initState();
    healthService = HealthService();
  }

  void _onSelectionChanged(DateRangePickerSelectionChangedArgs args) {
    setState(() {
      if (args.value is PickerDateRange) {
        _startDate = args.value.startDate;
        _endDate = (args.value.endDate ?? args.value.startDate)
            .add(const Duration(days: 1));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SfDateRangePicker(
              backgroundColor: Colors.white,
              onSelectionChanged: _onSelectionChanged,
              enableMultiView: true,
              selectionMode: DateRangePickerSelectionMode.range,
              initialSelectedRange: PickerDateRange(
                _startDate,
                _endDate,
              ),
            ),
            OutlinedButton(
              onPressed: () => HealthService().fetchData(
                types: healthService.sleepTypes,
                filename: 'sleep.json',
                startDate: _startDate,
                endDate: _endDate,
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
              onPressed: () => HealthService().fetchData(
                types: healthService.heartRateTypes,
                filename: 'heart.json',
                startDate: _startDate,
                endDate: _endDate,
              ),
              child: const Text(
                'Import Heart Rate Data',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: () => HealthService().fetchData(
                types: healthService.bpTypes,
                filename: 'bp.json',
                startDate: _startDate,
                endDate: _endDate,
              ),
              child: const Text(
                'Import Blood Pressure Data',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: () => HealthService().fetchData(
                types: healthService.bodyMeasurementTypes,
                filename: 'body.json',
                startDate: _startDate,
                endDate: _endDate,
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
              onPressed: () => HealthService().fetchData(
                types: healthService.energyTypes,
                filename: 'energy.json',
                startDate: _startDate,
                endDate: _endDate,
              ),
              child: const Text(
                'Import Energy Burned Data',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: () => HealthService().fetchData(
                types: healthService.stepsTypes,
                filename: 'steps.json',
                startDate: _startDate,
                endDate: _endDate,
              ),
              child: const Text(
                'Import Steps',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: () => HealthService().fetchData(
                types: healthService.movementTypes,
                filename: 'movement.json',
                startDate: _startDate,
                endDate: _endDate,
              ),
              child: const Text(
                'Import Stairs, Distance',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: () => HealthService().fetchData(
                types: healthService.workoutTypes,
                filename: 'workouts.json',
                startDate: _startDate,
                endDate: _endDate,
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
