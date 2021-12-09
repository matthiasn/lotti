import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lotti/classes/measurables.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';
import 'package:lotti/theme.dart';

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

  @override
  Widget build(BuildContext context) {
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
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  _formKey.currentState!.save();
                  if (_formKey.currentState!.validate()) {
                    final formData = _formKey.currentState?.value;
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    'Save',
                    style: TextStyle(
                      fontSize: 20,
                      fontFamily: 'Oswald',
                      fontWeight: FontWeight.bold,
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
                            name: 'gender',
                            decoration: const InputDecoration(
                              labelText: 'Type',
                            ),
                            // initialValue: 'Male',
                            allowClear: true,
                            hint: const Text('Select Measuremnt Type'),
                            validator: FormBuilderValidators.compose(
                                [FormBuilderValidators.required(context)]),
                            items: items
                                .map((MeasurableDataType item) =>
                                    DropdownMenuItem(
                                      value: item,
                                      child: Text(item.displayName),
                                    ))
                                .toList(),
                          ),
                          const FormTextField(
                            initialValue: '',
                            labelText: 'Value',
                            name: 'value',
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
  }
}

class FormTextField extends StatelessWidget {
  const FormTextField({
    Key? key,
    required this.initialValue,
    required this.name,
    required this.labelText,
  }) : super(key: key);

  final String initialValue;
  final String name;
  final String labelText;

  @override
  Widget build(BuildContext context) {
    return FormBuilderTextField(
      name: name,
      minLines: 1,
      maxLines: 3,
      initialValue: initialValue,
      validator: FormBuilderValidators.required(context),
      style: TextStyle(
        color: AppColors.entryTextColor,
        height: 1.6,
        fontFamily: 'Lato',
        fontSize: 20,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: AppColors.entryTextColor, fontSize: 16),
      ),
    );
  }
}
