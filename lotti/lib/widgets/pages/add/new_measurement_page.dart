import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:intl/intl.dart';
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/blocs/journal/persistence_state.dart';
import 'package:lotti/classes/measurables.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/form_builder/cupertino_datepicker.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';

class NewMeasurementPage extends StatefulWidget {
  const NewMeasurementPage({Key? key}) : super(key: key);

  @override
  State<NewMeasurementPage> createState() => _NewMeasurementPageState();
}

class _NewMeasurementPageState extends State<NewMeasurementPage> {
  final JournalDb _db = getIt<JournalDb>();
  final _formKey = GlobalKey<FormBuilderState>();

  late final Stream<List<MeasurableDataType>> stream =
      _db.watchMeasurableDataTypes();

  @override
  void initState() {
    super.initState();
  }

  String description = '';

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PersistenceCubit, PersistenceState>(
        builder: (context, PersistenceState state) {
      return StreamBuilder<List<MeasurableDataType>>(
        stream: stream,
        builder: (
          BuildContext context,
          AsyncSnapshot<List<MeasurableDataType>> snapshot,
        ) {
          List<MeasurableDataType> items = snapshot.data ?? [];

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
                        value: nf
                            .parse('${formData['value']}'.replaceAll(',', '.')),
                      );
                      context
                          .read<PersistenceCubit>()
                          .createMeasurementEntry(data: measurement);
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
                                  description = value?.description ?? '';
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
                            if (description.isNotEmpty)
                              FormBuilderCupertinoDateTimePicker(
                                name: 'date',
                                alwaysUse24HourFormat: true,
                                format: DateFormat(
                                    'EEEE, MMMM d, yyyy \'at\' HH:mm'),
                                inputType:
                                    CupertinoDateTimePickerInputType.both,
                                style: inputStyle,
                                decoration: InputDecoration(
                                  labelText: 'Measurement taken',
                                  labelStyle: labelStyle,
                                ),
                                initialValue: DateTime.now(),
                              ),
                            if (description.isNotEmpty)
                              FormBuilderTextField(
                                initialValue: '',
                                decoration: InputDecoration(
                                  labelText: description,
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
                ],
              ),
            ),
          );
        },
      );
    });
  }
}
