import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:wisely/health/health_service.dart';
import 'package:wisely/widgets/buttons.dart';

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
            Button(
              label: 'Import Sleep Data',
              onPressed: () => HealthService().fetchData(
                types: healthService.sleepTypes,
                filename: 'sleep.json',
                startDate: _startDate,
                endDate: _endDate,
              ),
            ),
            Button(
              onPressed: () => HealthService().fetchData(
                types: healthService.heartRateTypes,
                filename: 'heart.json',
                startDate: _startDate,
                endDate: _endDate,
              ),
              label: 'Import Heart Rate Data',
            ),
            Button(
              onPressed: () => HealthService().fetchData(
                types: healthService.bpTypes,
                filename: 'bp.json',
                startDate: _startDate,
                endDate: _endDate,
              ),
              label: 'Import Blood Pressure Data',
            ),
            Button(
              onPressed: () => HealthService().fetchData(
                types: healthService.bodyMeasurementTypes,
                filename: 'body.json',
                startDate: _startDate,
                endDate: _endDate,
              ),
              label: 'Import Body Measurement Data',
            ),
            Button(
              onPressed: () => HealthService().fetchData(
                types: healthService.energyTypes,
                filename: 'energy.json',
                startDate: _startDate,
                endDate: _endDate,
              ),
              label: 'Import Energy Burned Data',
            ),
            Button(
              onPressed: () => HealthService().fetchData(
                types: healthService.stepsTypes,
                filename: 'steps.json',
                startDate: _startDate,
                endDate: _endDate,
              ),
              label: 'Import Steps',
            ),
            Button(
              onPressed: () => HealthService().fetchData(
                types: healthService.movementTypes,
                filename: 'movement.json',
                startDate: _startDate,
                endDate: _endDate,
              ),
              label: 'Import Stairs, Distance',
            ),
            Button(
              onPressed: () => HealthService().fetchData(
                types: healthService.workoutTypes,
                filename: 'workouts.json',
                startDate: _startDate,
                endDate: _endDate,
              ),
              label: 'Import Workout Data',
            ),
          ],
        ),
      ),
    );
  }
}
