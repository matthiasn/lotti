import 'package:flutter/material.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/widgets/misc/buttons.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

class HealthImportPage extends StatefulWidget {
  const HealthImportPage({Key? key}) : super(key: key);

  @override
  State<HealthImportPage> createState() => _HealthImportPageState();
}

class _HealthImportPageState extends State<HealthImportPage> {
  final HealthImport _healthImport = getIt<HealthImport>();

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
    return SingleChildScrollView(
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
            'Import Activity Data',
            onPressed: () {
              _healthImport.getActivityHealthData(
                  dateFrom: _dateFrom, dateTo: _dateTo);
            },
          ),
          Button(
            'Import Sleep Data',
            onPressed: () {
              _healthImport.fetchHealthData(
                dateFrom: _dateFrom,
                dateTo: _dateTo,
                types: sleepTypes,
              );
            },
          ),
          Button(
            'Import Heart Rate Data',
            onPressed: () {
              _healthImport.fetchHealthData(
                dateFrom: _dateFrom,
                dateTo: _dateTo,
                types: heartRateTypes,
              );
            },
          ),
          Button(
            'Import Blood Pressure Data',
            onPressed: () {
              _healthImport.fetchHealthData(
                dateFrom: _dateFrom,
                dateTo: _dateTo,
                types: bpTypes,
              );
            },
          ),
          Button(
            'Import Body Measurement Data',
            onPressed: () {
              _healthImport.fetchHealthData(
                dateFrom: _dateFrom,
                dateTo: _dateTo,
                types: bodyMeasurementTypes,
              );
            },
          ),
          Button(
            'Import Workout Data',
            onPressed: () {
              _healthImport.getWorkoutsHealthData(
                dateFrom: _dateFrom,
                dateTo: _dateTo,
              );
            },
          ),
        ],
      ),
    );
  }
}
