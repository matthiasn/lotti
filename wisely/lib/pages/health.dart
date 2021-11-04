import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:wisely/blocs/journal/health_cubit.dart';
import 'package:wisely/blocs/journal/health_state.dart';
import 'package:wisely/health/health_service.dart';
import 'package:wisely/widgets/buttons.dart';

class HealthPage extends StatefulWidget {
  const HealthPage({Key? key}) : super(key: key);

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  late HealthService healthService;
  DateTime _dateFrom = DateTime.now().subtract(const Duration(days: 7));
  DateTime _dateTo = DateTime.now().add(const Duration(days: 1));

  @override
  void initState() {
    super.initState();
    healthService = HealthService();
  }

  void _onSelectionChanged(DateRangePickerSelectionChangedArgs args) {
    setState(() {
      if (args.value is PickerDateRange) {
        _dateFrom = args.value.startDate;
        _dateTo = (args.value.endDate ?? args.value.startDate);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HealthCubit, HealthState>(
        builder: (BuildContext context, HealthState state) {
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
                  _dateFrom,
                  _dateTo,
                ),
              ),
              Button(
                label: 'Import Activity Data',
                onPressed: () {
                  HealthService().getActivityHealthData(
                    filename: 'activity.json',
                    dateFrom: _dateFrom,
                    dateTo: _dateTo,
                  );
                  context.read<HealthCubit>().getActivityHealthData(
                      dateFrom: _dateFrom, dateTo: _dateTo);
                },
              ),
              Button(
                label: 'Import Sleep Data',
                onPressed: () => HealthService().fetchData(
                  types: healthService.sleepTypes,
                  filename: 'sleep.json',
                  dateFrom: _dateFrom,
                  dateTo: _dateTo,
                ),
              ),
              Button(
                onPressed: () => HealthService().fetchData(
                  types: healthService.heartRateTypes,
                  filename: 'heart.json',
                  dateFrom: _dateFrom,
                  dateTo: _dateTo,
                ),
                label: 'Import Heart Rate Data',
              ),
              Button(
                onPressed: () => HealthService().fetchData(
                  types: healthService.bpTypes,
                  filename: 'bp.json',
                  dateFrom: _dateFrom,
                  dateTo: _dateTo,
                ),
                label: 'Import Blood Pressure Data',
              ),
              Button(
                onPressed: () => HealthService().fetchData(
                  types: healthService.bodyMeasurementTypes,
                  filename: 'body.json',
                  dateFrom: _dateFrom,
                  dateTo: _dateTo,
                ),
                label: 'Import Body Measurement Data',
              ),
              Button(
                onPressed: () => HealthService().fetchData(
                  types: healthService.energyTypes,
                  filename: 'energy.json',
                  dateFrom: _dateFrom,
                  dateTo: _dateTo,
                ),
                label: 'Import Energy Burned Data',
              ),
              Button(
                onPressed: () => HealthService().fetchData(
                  types: healthService.movementTypes,
                  filename: 'movement.json',
                  dateFrom: _dateFrom,
                  dateTo: _dateTo,
                ),
                label: 'Import Stairs, Distance',
              ),
              Button(
                onPressed: () => HealthService().fetchData(
                  types: healthService.workoutTypes,
                  filename: 'workouts.json',
                  dateFrom: _dateFrom,
                  dateTo: _dateTo,
                ),
                label: 'Import Workout Data',
              ),
            ],
          ),
        ),
      );
    });
  }
}
