import 'package:auto_route/auto_route.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/charts/dashboard_measurables_chart.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:lotti/widgets/form_builder/cupertino_datepicker.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';

class CreateMeasurementPage extends StatefulWidget {
  const CreateMeasurementPage({
    Key? key,
    this.linkedId,
    this.selectedId,
  }) : super(key: key);

  final String? linkedId;
  final String? selectedId;

  @override
  State<CreateMeasurementPage> createState() => _CreateMeasurementPageState();
}

class _CreateMeasurementPageState extends State<CreateMeasurementPage> {
  final JournalDb _db = getIt<JournalDb>();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final _formKey = GlobalKey<FormBuilderState>();

  MeasurableDataType? selected;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return StreamBuilder<List<MeasurableDataType>>(
      stream: _db.watchMeasurableDataTypes(),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<MeasurableDataType>> snapshot,
      ) {
        List<MeasurableDataType> items = snapshot.data ?? [];

        if (items.length == 1) {
          selected = items.first;
        }

        for (MeasurableDataType dataType in items) {
          if (dataType.id == widget.selectedId) {
            selected = dataType;
          }
        }

        void onSave() async {
          _formKey.currentState!.save();
          if (_formKey.currentState!.validate()) {
            final formData = _formKey.currentState?.value;
            if (selected == null) {
              return;
            }
            MeasurementData measurement = MeasurementData(
              dataTypeId: selected!.id,
              dateTo: formData!['date'],
              dateFrom: formData['date'],
              value: nf.parse('${formData['value']}'.replaceAll(',', '.')),
            );
            persistenceLogic.createMeasurementEntry(
              data: measurement,
              linkedId: widget.linkedId,
            );
            context.router.pop();
          }
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: AppColors.headerBgColor,
                  width: MediaQuery.of(context).size.width,
                  padding: const EdgeInsets.all(32.0),
                  child: FormBuilder(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      children: <Widget>[
                        if (items.isEmpty)
                          Row(
                            children: [
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () {
                                    pushNamedRoute(
                                        '/settings/create_measurable');
                                  },
                                  child: SizedBox(
                                    width:
                                        MediaQuery.of(context).size.width - 100,
                                    child: AutoSizeText(
                                      localizations.addMeasurementNoneDefined,
                                      style: titleStyle.copyWith(
                                        decoration: TextDecoration.underline,
                                        color: AppColors.tagColor,
                                      ),
                                      wrapWords: false,
                                      maxLines: 3,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (items.isNotEmpty)
                          Column(
                            children: [
                              Text(
                                selected?.displayName ??
                                    localizations.addMeasurementTitle,
                                style: TextStyle(
                                  color: AppColors.entryTextColor,
                                  fontFamily: 'Oswald',
                                  fontSize: 24,
                                ),
                              ),
                              if (selected?.description != null)
                                Text(
                                  selected!.description,
                                  style: TextStyle(
                                    color: AppColors.entryTextColor,
                                    fontFamily: 'Oswald',
                                    fontWeight: FontWeight.w300,
                                    fontSize: 14,
                                  ),
                                ),
                              if (selected == null)
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
                                      [FormBuilderValidators.required()]),
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
                                    labelText: '${selected?.displayName} '
                                        '${'${selected?.unitName}'.isNotEmpty ? '[${selected?.unitName}] ' : ''}',
                                    labelStyle: labelStyle,
                                  ),
                                  keyboardAppearance: Brightness.dark,
                                  style: inputStyle,
                                  name: 'value',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                ),
                              TextButton(
                                onPressed: onSave,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24.0),
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
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (selected != null)
                DashboardMeasurablesChart(
                  measurableDataTypeId: selected!.id,
                  rangeStart: getRangeStart(context: context),
                  rangeEnd: getRangeEnd(),
                ),
            ],
          ),
        );
      },
    );
  }
}

class CreateMeasurementWithLinkedPage extends StatelessWidget {
  const CreateMeasurementWithLinkedPage({
    Key? key,
    @PathParam() this.linkedId,
  }) : super(key: key);

  final String? linkedId;

  @override
  Widget build(BuildContext context) {
    return CreateMeasurementPage(
      linkedId: linkedId,
    );
  }
}

class CreateMeasurementWithTypePage extends StatelessWidget {
  const CreateMeasurementWithTypePage({
    Key? key,
    @PathParam() this.selectedId,
  }) : super(key: key);

  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    return CreateMeasurementPage(
      selectedId: selectedId,
    );
  }
}
