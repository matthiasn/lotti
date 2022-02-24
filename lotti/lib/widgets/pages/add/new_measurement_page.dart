import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/charts/dashboard_barchart.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:lotti/widgets/form_builder/cupertino_datepicker.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';

class NewMeasurementPage extends StatefulWidget {
  const NewMeasurementPage({
    Key? key,
    this.linked,
  }) : super(key: key);

  final JournalEntity? linked;

  @override
  State<NewMeasurementPage> createState() => _NewMeasurementPageState();
}

class _NewMeasurementPageState extends State<NewMeasurementPage> {
  final JournalDb _db = getIt<JournalDb>();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final _formKey = GlobalKey<FormBuilderState>();
  late final Stream<List<MeasurableDataType>> stream =
      _db.watchMeasurableDataTypes();

  @override
  void initState() {
    super.initState();
  }

  MeasurableDataType? selected;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MeasurableDataType>>(
      stream: stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<MeasurableDataType>> snapshot,
      ) {
        List<MeasurableDataType> items = snapshot.data ?? [];
        List<MeasurableDataType> favoriteItems =
            items.where((m) => fromNullableBool(m.favorite)).toList();

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'New Measurement',
              style: TextStyle(
                color: AppColors.entryTextColor,
                fontFamily: 'Oswald',
              ),
            ),
            backgroundColor: AppColors.headerBgColor,
            foregroundColor: AppColors.appBarFgColor,
            actions: <Widget>[
              TextButton(
                onPressed: () async {
                  _formKey.currentState!.save();
                  if (_formKey.currentState!.validate()) {
                    final formData = _formKey.currentState?.value;
                    MeasurementData measurement = MeasurementData(
                      dataType: formData!['type'] as MeasurableDataType,
                      dateTo: formData['date'],
                      dateFrom: formData['date'],
                      value:
                          nf.parse('${formData['value']}'.replaceAll(',', '.')),
                    );
                    persistenceLogic.createMeasurementEntry(
                      data: measurement,
                      linked: widget.linked,
                    );
                    Navigator.pop(context);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    'Save',
                    style: TextStyle(
                      fontSize: 20,
                      fontFamily: 'Oswald',
                      fontWeight: FontWeight.bold,
                      color: AppColors.appBarFgColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.bodyBgColor,
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: AppColors.headerBgColor,
                    padding: const EdgeInsets.all(32.0),
                    child: FormBuilder(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        children: <Widget>[
                          FormBuilderDropdown(
                            dropdownColor: AppColors.headerBgColor,
                            name: 'type',
                            decoration: InputDecoration(
                              labelText: 'Type',
                              labelStyle: labelStyle,
                            ),
                            hint: Text(
                              'Select Measurement Type',
                              style: inputStyle,
                            ),
                            onChanged: (MeasurableDataType? value) {
                              setState(() {
                                selected = value;
                              });
                            },
                            validator: FormBuilderValidators.compose(
                                [FormBuilderValidators.required(context)]),
                            items: items
                                .map((MeasurableDataType item) =>
                                    DropdownMenuItem(
                                      value: item,
                                      child: Text(
                                        item.displayName,
                                        style: inputStyle,
                                      ),
                                    ))
                                .toList(),
                          ),
                          if (selected != null)
                            FormBuilderCupertinoDateTimePicker(
                              name: 'date',
                              alwaysUse24HourFormat: true,
                              format:
                                  DateFormat('EEEE, MMMM d, yyyy \'at\' HH:mm'),
                              inputType: CupertinoDateTimePickerInputType.both,
                              style: inputStyle,
                              decoration: InputDecoration(
                                labelText: 'Measurement taken',
                                labelStyle: labelStyle,
                              ),
                              initialValue: DateTime.now(),
                              theme: DatePickerTheme(
                                headerColor: AppColors.headerBgColor,
                                backgroundColor: AppColors.bodyBgColor,
                                itemStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                                doneStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          if (selected != null)
                            FormBuilderTextField(
                              initialValue: '',
                              decoration: InputDecoration(
                                labelText: selected!.description,
                                labelStyle: labelStyle,
                              ),
                              style: inputStyle,
                              name: 'value',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (selected != null)
                  DashboardBarChart(
                    measurableDataTypeId: selected!.id,
                    rangeStart: DateTime.now().subtract(defaultChartDuration),
                    rangeEnd: DateTime.now(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
