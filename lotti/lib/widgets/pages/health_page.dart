import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/health_cubit.dart';
import 'package:lotti/blocs/journal/health_state.dart';
import 'package:lotti/widgets/misc/buttons.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

class HealthPage extends StatefulWidget {
  const HealthPage({Key? key}) : super(key: key);

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  DateTime _dateFrom = DateTime.now().subtract(const Duration(days: 7));
  DateTime _dateTo = DateTime.now().add(const Duration(days: 1));

  @override
  void initState() {
    super.initState();
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
              Button('Import Activity Data', onPressed: () {
                context.read<HealthCubit>().getActivityHealthData(
                    dateFrom: _dateFrom, dateTo: _dateTo);
              }),
              Button('Import Sleep Data', onPressed: () {
                context.read<HealthCubit>().fetchHealthData(
                      dateFrom: _dateFrom,
                      dateTo: _dateTo,
                      types: sleepTypes,
                    );
              }),
              Button('Import Heart Rate Data', onPressed: () {
                context.read<HealthCubit>().fetchHealthData(
                      dateFrom: _dateFrom,
                      dateTo: _dateTo,
                      types: heartRateTypes,
                    );
              }),
              Button('Import Blood Pressure Data', onPressed: () {
                context.read<HealthCubit>().fetchHealthData(
                      dateFrom: _dateFrom,
                      dateTo: _dateTo,
                      types: bpTypes,
                    );
              }),
              Button('Import Body Measurement Data', onPressed: () {
                context.read<HealthCubit>().fetchHealthData(
                      dateFrom: _dateFrom,
                      dateTo: _dateTo,
                      types: bodyMeasurementTypes,
                    );
              }),
              Button('Import Workout Data', onPressed: () {
                context.read<HealthCubit>().fetchHealthData(
                      dateFrom: _dateFrom,
                      dateTo: _dateTo,
                      types: workoutTypes,
                    );
              }),
            ],
          ),
        ),
      );
    });
  }
}
