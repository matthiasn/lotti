import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/form_builder/cupertino_datepicker.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';

class CreateMeasurementModal extends StatefulWidget {
  const CreateMeasurementModal({
    super.key,
    this.selectedId,
  });

  final String? selectedId;

  @override
  State<CreateMeasurementModal> createState() => _CreateMeasurementModalState();
}

class _CreateMeasurementModalState extends State<CreateMeasurementModal> {
  final JournalDb _db = getIt<JournalDb>();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final _formKey = GlobalKey<FormBuilderState>();
  bool dirty = false;

  MeasurableDataType? selected;

  final hotkeyCmdS = HotKey(
    KeyCode.keyS,
    modifiers: [KeyModifier.meta],
    scope: HotKeyScope.inapp,
  );

  @override
  void initState() {
    super.initState();

    // TODO: bring back
    // hotKeyManager.register(
    //   hotkeyCmdS,
    //   keyDownHandler: (hotKey) => saveMeasurement(),
    // );
  }

  @override
  void dispose() {
    super.dispose();
    hotKeyManager.unregister(hotkeyCmdS);
  }

  bool validate() {
    if (_formKey.currentState != null) {
      return _formKey.currentState!.validate();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    void maybePop() => Navigator.of(context).maybePop();

    Future<void> saveMeasurement() async {
      _formKey.currentState!.save();
      if (validate()) {
        final formData = _formKey.currentState?.value;
        if (selected == null) {
          return;
        }
        final measurement = MeasurementData(
          dataTypeId: selected!.id,
          dateTo: formData!['date'] as DateTime,
          dateFrom: formData['date'] as DateTime,
          value: nf.parse('${formData['value']}'.replaceAll(',', '.')),
        );
        await persistenceLogic.createMeasurementEntry(data: measurement);
        setState(() {
          dirty = false;
        });

        maybePop();
      }
    }

    return StreamBuilder<List<MeasurableDataType>>(
      stream: _db.watchMeasurableDataTypes(),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<MeasurableDataType>> snapshot,
      ) {
        final items = snapshot.data ?? [];

        if (items.length == 1) {
          selected = items.first;
        }

        for (final dataType in items) {
          if (dataType.id == widget.selectedId) {
            selected = dataType;
          }
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: colorConfig().headerBgColor,
              width: MediaQuery.of(context).size.width,
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 8,
              ),
              child: FormBuilder(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                onChanged: () {
                  setState(() {
                    dirty = true;
                  });
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            selected?.displayName ?? '',
                            style: TextStyle(
                              color: colorConfig().entryTextColor,
                              fontFamily: 'Oswald',
                              fontSize: 24,
                            ),
                          ),
                        ),
                        // TODO: fix or remove
                        // IconButton(
                        //   icon: const Icon(Icons.settings_outlined),
                        //   color: colorConfig().entryTextColor,
                        //   onPressed: () {
                        //     navigateNamedRoute(
                        //       '/settings/measurables/${selected?.id}',
                        //     );
                        //   },
                        // ),
                      ],
                    ),
                    if ('${selected?.description}'.isNotEmpty)
                      Text(
                        '${selected?.description}',
                        style: TextStyle(
                          color: colorConfig().entryTextColor,
                          fontFamily: 'Oswald',
                          fontWeight: FontWeight.w300,
                          fontSize: 14,
                        ),
                      ),
                    if (selected == null)
                      FormBuilderDropdown<MeasurableDataType>(
                        dropdownColor: colorConfig().headerBgColor,
                        name: 'type',
                        decoration: InputDecoration(
                          labelText: 'Type',
                          labelStyle: labelStyle(),
                          hintStyle: inputStyle(),
                          hintText: 'Select Measurement Type',
                        ),
                        onChanged: (MeasurableDataType? value) {
                          setState(() {
                            selected = value;
                          });
                        },
                        validator: FormBuilderValidators.compose(
                          [FormBuilderValidators.required()],
                        ),
                        items: items
                            .map(
                              (MeasurableDataType item) => DropdownMenuItem(
                                value: item,
                                child: Text(
                                  item.displayName,
                                  style: inputStyle(),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    if (selected != null)
                      FormBuilderCupertinoDateTimePicker(
                        name: 'date',
                        alwaysUse24HourFormat: true,
                        format: DateFormat(
                          "EEEE, MMMM d, yyyy 'at' HH:mm",
                        ),
                        style: inputStyle(),
                        decoration: InputDecoration(
                          labelText: 'Measurement taken',
                          labelStyle: labelStyle(),
                        ),
                        initialValue: DateTime.now(),
                        theme: DatePickerTheme(
                          headerColor: colorConfig().headerBgColor,
                          backgroundColor: colorConfig().bodyBgColor,
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
                        key: const Key('measurement_value_field'),
                        decoration: InputDecoration(
                          labelText: '${selected?.displayName} '
                              '${'${selected?.unitName}'.isNotEmpty ? '[${selected?.unitName}] ' : ''}',
                          labelStyle: labelStyle(),
                        ),
                        keyboardAppearance: Brightness.dark,
                        style: inputStyle(),
                        autofocus: true,
                        validator: FormBuilderValidators.required(),
                        name: 'value',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Visibility(
                          maintainSize: true,
                          maintainAnimation: true,
                          maintainState: true,
                          visible: dirty && validate(),
                          child: TextButton(
                            key: const Key('measurement_save'),
                            onPressed: saveMeasurement,
                            child: Text(
                              localizations.addMeasurementSaveButton,
                              style: saveButtonStyle(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
