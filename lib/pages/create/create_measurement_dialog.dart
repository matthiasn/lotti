import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/form_utils.dart';
import 'package:lotti/widgets/create/suggest_measurement.dart';
import 'package:lotti/widgets/date_time/datetime_field.dart';

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
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final _formKey = GlobalKey<FormBuilderState>();
  bool dirty = false;
  DateTime measurementTime = DateTime.now();

  final hotkeyCmdS = HotKey(
    key: LogicalKeyboardKey.keyS,
    modifiers: [HotKeyModifier.meta],
    scope: HotKeyScope.inapp,
  );

  Future<void> saveMeasurement({
    required MeasurableDataType measurableDataType,
    required DateTime measurementTime,
    num? value,
  }) async {
    _formKey.currentState!.save();
    if (validate()) {
      final formData = _formKey.currentState?.value;

      setState(() {
        dirty = false;
      });

      final measurement = MeasurementData(
        dataTypeId: measurableDataType.id,
        dateTo: measurementTime,
        dateFrom: measurementTime,
        value: value ?? nf.parse('${formData!['value']}'.replaceAll(',', '.')),
      );
      Navigator.pop(context, 'Saved');

      await persistenceLogic.createMeasurementEntry(
        data: measurement,
        comment: formData!['comment'] as String,
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
    final dataType = getIt<EntitiesCacheService>().getDataTypeById(
      widget.measurableId,
    );

    if (dataType == null) {
      return const SizedBox.shrink();
    }

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      contentPadding: const EdgeInsets.only(
        left: 30,
        top: 20,
        right: 10,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        side: BorderSide(
          color: (context.textTheme.titleLarge?.color ?? Colors.black)
              .withOpacity(0.5),
        ),
      ),
      actionsAlignment: MainAxisAlignment.end,
      actionsPadding: const EdgeInsets.only(
        left: 30,
        right: 20,
        bottom: 20,
      ),
      actions: [
        if (!dirty)
          MeasurementSuggestions(
            measurableDataType: dataType,
            saveMeasurement: saveMeasurement,
            measurementTime: measurementTime,
          ),
        if (dirty && validate())
          TextButton(
            key: const Key('measurement_save'),
            onPressed: () => saveMeasurement(
              measurableDataType: dataType,
              measurementTime: measurementTime,
            ),
            child: Text(
              context.messages.addMeasurementSaveButton,
              style: saveButtonStyle(
                Theme.of(context),
              ),
            ),
          )
        else
          const SizedBox.shrink(),
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
                ),
                IconButton(
                  padding: const EdgeInsets.all(10),
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context, 'Close'),
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
                        fontWeight: FontWeight.w300,
                        fontSize: fontSizeSmall,
                      ),
                    ),
                  inputSpacer,
                  DateTimeField(
                    dateTime: measurementTime,
                    labelText: context.messages.addMeasurementDateLabel,
                    setDateTime: (picked) {
                      setState(() {
                        measurementTime = picked;
                      });
                    },
                  ),
                  inputSpacer,
                  FormBuilderTextField(
                    initialValue: '',
                    key: const Key('measurement_value_field'),
                    decoration: createDialogInputDecoration(
                      labelText: '${dataType.displayName} '
                          '${dataType.unitName.isNotEmpty ? '[${dataType.unitName}] ' : ''}',
                      themeData: Theme.of(context),
                    ),
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
                      labelText: context.messages.addMeasurementCommentLabel,
                      themeData: Theme.of(context),
                    ),
                    keyboardAppearance: Theme.of(context).brightness,
                    name: 'comment',
                  ),
                  inputSpacer,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
