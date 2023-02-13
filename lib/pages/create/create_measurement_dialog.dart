import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:intl/intl.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/form_utils.dart';
import 'package:lotti/widgets/create/suggest_measurement.dart';
import 'package:lotti/widgets/form_builder/cupertino_datepicker.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';

class MeasurementDialog extends StatefulWidget {
  const MeasurementDialog({
    required this.measurableId,
    super.key,
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

  final hotkeyCmdS = HotKey(
    KeyCode.keyS,
    modifiers: [KeyModifier.meta],
    scope: HotKeyScope.inapp,
  );

  final beamBack = dashboardsBeamerDelegate.beamBack;

  Future<void> saveMeasurement({
    required MeasurableDataType measurableDataType,
    num? value,
  }) async {
    _formKey.currentState!.save();
    if (validate()) {
      final formData = _formKey.currentState?.value;

      setState(() {
        dirty = false;
      });

      beamBack();

      final measurement = MeasurementData(
        dataTypeId: measurableDataType.id,
        dateTo: formData!['date'] as DateTime,
        dateFrom: formData['date'] as DateTime,
        value: value ?? nf.parse('${formData['value']}'.replaceAll(',', '.')),
      );

      await persistenceLogic.createMeasurementEntry(
        data: measurement,
        comment: formData['comment'] as String,
        private: measurableDataType.private ?? false,
      );
    }
  }

  @override
  void initState() {
    super.initState();
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

    return StreamBuilder<MeasurableDataType?>(
      stream: _db.watchMeasurableDataTypeById(widget.measurableId),
      builder: (
        BuildContext context,
        AsyncSnapshot<MeasurableDataType?> snapshot,
      ) {
        if (snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final dataType = snapshot.data!;

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
            SizedBox(
              height: 25,
              child: dirty && validate()
                  ? TextButton(
                      key: const Key('measurement_save'),
                      onPressed: () => saveMeasurement(
                        measurableDataType: dataType,
                      ),
                      child: Text(
                        localizations.addMeasurementSaveButton,
                        style: saveButtonStyle(),
                      ),
                    )
                  : const SizedBox.shrink(),
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
                      dataType.displayName,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: fontSizeMedium,
                      ),
                    ),
                    IconButton(
                      padding: const EdgeInsets.all(10),
                      icon: SvgPicture.asset('assets/icons/close.svg'),
                      onPressed: beamBack,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (dataType.description.isNotEmpty)
                        Text(
                          dataType.description,
                          style: const TextStyle(
                            color: Colors.black38,
                            fontWeight: FontWeight.w300,
                            fontSize: fontSizeMedium,
                          ),
                        ),
                      inputSpacer,
                      FormBuilderCupertinoDateTimePicker(
                        name: 'date',
                        alwaysUse24HourFormat: true,
                        format: DateFormat(
                          "MMMM d, yyyy 'at' HH:mm",
                        ),
                        style: newInputStyle().copyWith(color: Colors.black),
                        decoration: createDialogInputDecoration(
                          labelText: localizations.addMeasurementDateLabel,
                        ),
                        initialValue: DateTime.now(),
                        theme: datePickerTheme(),
                      ),
                      inputSpacer,
                      FormBuilderTextField(
                        initialValue: '',
                        key: const Key('measurement_value_field'),
                        decoration: createDialogInputDecoration(
                          labelText: '${dataType.displayName} '
                              '${dataType.unitName.isNotEmpty ? '[${dataType.unitName}] ' : ''}',
                        ),
                        keyboardAppearance: keyboardAppearance(),
                        style: newInputStyle().copyWith(color: Colors.black),
                        validator: numericValidator(),
                        name: 'value',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      inputSpacer,
                      FormBuilderTextField(
                        initialValue: '',
                        key: const Key('measurement_comment_field'),
                        decoration: createDialogInputDecoration(
                          labelText: localizations.addMeasurementCommentLabel,
                        ),
                        keyboardAppearance: keyboardAppearance(),
                        style: newInputStyle().copyWith(color: Colors.black),
                        name: 'comment',
                      ),
                      inputSpacer,
                      MeasurementSuggestions(
                        measurableDataType: dataType,
                        saveMeasurement: saveMeasurement,
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
