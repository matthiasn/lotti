import 'package:flutter/cupertino.dart';
import 'package:intersperse/intersperse.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/widgets/date_time/datetime_field.dart';
import 'package:lotti/widgets/misc/buttons.dart';

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

  @override
  Widget build(BuildContext context) {
    return SliverBoxAdapterPage(
      title: context.messages.settingsHealthImportTitle,
      showBackButton: true,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            DateTimeField(
              dateTime: _dateFrom,
              labelText: context.messages.settingsHealthImportFromDate,
              setDateTime: (DateTime value) {
                setState(() {
                  _dateFrom = value;
                });
              },
              mode: CupertinoDatePickerMode.date,
            ),
            const SizedBox(height: 20),
            DateTimeField(
              dateTime: _dateTo,
              labelText: context.messages.settingsHealthImportToDate,
              setDateTime: (DateTime value) {
                setState(() {
                  _dateTo = value;
                });
              },
              mode: CupertinoDatePickerMode.date,
            ),
            const SizedBox(height: 20),
            ...<Widget>[
              RoundedButton(
                'Import Activity Data',
                onPressed: () {
                  _healthImport.getActivityHealthData(
                    dateFrom: _dateFrom,
                    dateTo: _dateTo,
                  );
                },
              ),
              RoundedButton(
                'Import Sleep Data',
                onPressed: () {
                  _healthImport.fetchHealthData(
                    dateFrom: _dateFrom,
                    dateTo: _dateTo,
                    types: sleepTypes,
                  );
                },
              ),
              RoundedButton(
                'Import Heart Rate Data',
                onPressed: () {
                  _healthImport.fetchHealthData(
                    dateFrom: _dateFrom,
                    dateTo: _dateTo,
                    types: heartRateTypes,
                  );
                },
              ),
              RoundedButton(
                'Import Blood Pressure Data',
                onPressed: () {
                  _healthImport.fetchHealthData(
                    dateFrom: _dateFrom,
                    dateTo: _dateTo,
                    types: bpTypes,
                  );
                },
              ),
              RoundedButton(
                'Import Body Measurement Data',
                onPressed: () {
                  _healthImport.fetchHealthData(
                    dateFrom: _dateFrom,
                    dateTo: _dateTo,
                    types: bodyMeasurementTypes,
                  );
                },
              ),
              RoundedButton(
                'Import Workout Data',
                onPressed: () {
                  _healthImport.getWorkoutsHealthData(
                    dateFrom: _dateFrom,
                    dateTo: _dateTo,
                  );
                },
              ),
            ].intersperse(const SizedBox(height: 5)),
          ],
        ),
      ),
    );
  }
}
