// ignore_for_file: avoid_dynamic_calls

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/misc/buttons.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

const spaceBetweenButtons = 10.0;

class HealthImportPage extends StatefulWidget {
  const HealthImportPage({super.key});

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
        _dateFrom = args.value.startDate as DateTime;
        _dateTo = (args.value.endDate ?? args.value.startDate) as DateTime;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: colorConfig().negspace,
      appBar: TitleAppBar(
        title: localizations.settingsHealthImportTitle,
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SfDateRangePicker(
              backgroundColor: Colors.transparent,
              onSelectionChanged: _onSelectionChanged,
              enableMultiView: true,
              selectionMode: DateRangePickerSelectionMode.range,
              initialSelectedRange: PickerDateRange(
                _dateFrom,
                _dateTo,
              ),
            ),
            const SizedBox(height: 20),
            Button2(
              'Import Activity Data',
              onPressed: () {
                _healthImport.getActivityHealthData(
                  dateFrom: _dateFrom,
                  dateTo: _dateTo,
                );
              },
            ),
            const SizedBox(height: spaceBetweenButtons),
            Button2(
              'Import Sleep Data',
              onPressed: () {
                _healthImport.fetchHealthData(
                  dateFrom: _dateFrom,
                  dateTo: _dateTo,
                  types: sleepTypes,
                );
              },
            ),
            const SizedBox(height: spaceBetweenButtons),
            Button2(
              'Import Heart Rate Data',
              onPressed: () {
                _healthImport.fetchHealthData(
                  dateFrom: _dateFrom,
                  dateTo: _dateTo,
                  types: heartRateTypes,
                );
              },
            ),
            const SizedBox(height: spaceBetweenButtons),
            Button2(
              'Import Blood Pressure Data',
              onPressed: () {
                _healthImport.fetchHealthData(
                  dateFrom: _dateFrom,
                  dateTo: _dateTo,
                  types: bpTypes,
                );
              },
            ),
            const SizedBox(height: spaceBetweenButtons),
            Button2(
              'Import Body Measurement Data',
              onPressed: () {
                _healthImport.fetchHealthData(
                  dateFrom: _dateFrom,
                  dateTo: _dateTo,
                  types: bodyMeasurementTypes,
                );
              },
            ),
            const SizedBox(height: spaceBetweenButtons),
            Button2(
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
      ),
    );
  }
}
