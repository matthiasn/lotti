import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/svg.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:intl/intl.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/form_builder/cupertino_datepicker.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';

class MeasurementDialog extends StatefulWidget {
  const MeasurementDialog({
    super.key,
    required this.measurableId,
  });

  final String measurableId;

  @override
  State<MeasurementDialog> createState() => _MeasurementDialogState();
}

class _MeasurementDialogState extends State<MeasurementDialog> {
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

  final beamBack = dashboardsBeamerDelegate.beamBack;

  Future<void> saveMeasurement() async {
    _formKey.currentState!.save();
    if (validate()) {
      final formData = _formKey.currentState?.value;
      if (selected == null) {
        return;
      }

      final dataType =
          await _db.watchMeasurableDataTypeById(selected!.id).first;

      final measurement = MeasurementData(
        dataTypeId: selected!.id,
        dateTo: formData!['date'] as DateTime,
        dateFrom: formData['date'] as DateTime,
        value: nf.parse('${formData['value']}'.replaceAll(',', '.')),
      );

      await persistenceLogic.createMeasurementEntry(
        data: measurement,
        comment: formData['comment'] as String,
        private: dataType?.private ?? false,
      );

      setState(() {
        dirty = false;
      });

      beamBack();
    }
  }

  @override
  void initState() {
    super.initState();

    hotKeyManager.register(
      hotkeyCmdS,
      keyDownHandler: (hotKey) => saveMeasurement(),
    );
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
          if (dataType.id == widget.measurableId) {
            selected = dataType;
          }
        }

        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          contentPadding: const EdgeInsets.only(
            left: 30,
            top: 20,
            right: 10,
            bottom: 20,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(50)),
          ),
          backgroundColor: styleConfig().primaryColorLight,
          actionsAlignment: MainAxisAlignment.end,
          actionsPadding: const EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: 20,
          ),
          actions: [
            if (dirty && validate())
              TextButton(
                key: const Key('measurement_save'),
                onPressed: saveMeasurement,
                child: Text(
                  localizations.addMeasurementSaveButton,
                  style: saveButtonStyle(),
                ),
              ),
          ],
          content: FormBuilder(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onChanged: () {
              setState(() {
                dirty = true;
              });
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      selected?.displayName ?? '',
                      style: const TextStyle(
                        color: Colors.black,
                        fontFamily: mainFont,
                        fontSize: 20,
                      ),
                    ),
                    IconButton(
                      padding: const EdgeInsets.all(10),
                      icon: SvgPicture.asset('assets/icons/close.svg'),
                      hoverColor: Colors.transparent,
                      onPressed: dashboardsBeamerDelegate.beamBack,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // if ('${selected?.description}'.isNotEmpty)
                      //   Text(
                      //     '${selected?.description}',
                      //     style: TextStyle(
                      //       color: colorConfig().primaryTextColor,
                      //       fontFamily: mainFont,
                      //       fontWeight: FontWeight.w300,
                      //       fontSize: 14,
                      //     ),
                      //   ),
                      const SizedBox(height: 10),
                      FormBuilderCupertinoDateTimePicker(
                        name: 'date',
                        alwaysUse24HourFormat: true,
                        format: DateFormat(
                          "MMMM d, yyyy 'at' HH:mm",
                        ),
                        style: newInputStyle().copyWith(color: Colors.black),
                        decoration:
                            InputDecoration(fillColor: styleConfig().negspace),
                        initialValue: DateTime.now(),
                        theme: datePickerTheme(),
                      ),
                      FormBuilderTextField(
                        initialValue: '',
                        key: const Key('measurement_value_field'),
                        decoration: InputDecoration(
                          labelText: '${selected?.displayName} '
                              '${'${selected?.unitName}'.isNotEmpty ? '[${selected?.unitName}] ' : ''}',
                          labelStyle:
                              newLabelStyle().copyWith(color: Colors.black),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                        ),
                        keyboardAppearance: Brightness.light,
                        style: newInputStyle().copyWith(color: Colors.black),
                        autofocus: true,
                        validator: FormBuilderValidators.numeric(),
                        name: 'value',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      FormBuilderTextField(
                        initialValue: '',
                        key: const Key('measurement_comment_field'),
                        decoration: InputDecoration(
                          labelText: localizations.addMeasurementCommentLabel,
                          labelStyle:
                              newLabelStyle().copyWith(color: Colors.black),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                        ),
                        keyboardAppearance: Brightness.light,
                        style: newInputStyle().copyWith(color: Colors.black),
                        name: 'comment',
                      ),
                    ],
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
