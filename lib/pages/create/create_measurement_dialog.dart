import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/theme.dart';
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
    final formData = _formKey.currentState?.value;

    // When value is provided directly (from suggestion chips), bypass validation
    // Otherwise validate the form input
    if (value == null && !validate()) {
      return;
    }

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
      comment: (formData?['comment'] as String?) ?? '',
      private: measurableDataType.private ?? false,
    );
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

    return FormBuilder(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      onChanged: () {
        setState(() {
          dirty = true;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Description (if available)
          if (dataType.description.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      dataType.description,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Value input field
          _ValueInputField(dataType: dataType),

          const SizedBox(height: 16),

          // Date & Time field
          DateTimeField(
            dateTime: measurementTime,
            labelText: context.messages.addMeasurementDateLabel,
            setDateTime: (picked) {
              setState(() {
                measurementTime = picked;
              });
            },
          ),

          const SizedBox(height: 16),

          // Comment field
          FormBuilderTextField(
            initialValue: '',
            key: const Key('measurement_comment_field'),
            decoration: inputDecoration(
              labelText: context.messages.addMeasurementCommentLabel,
              themeData: Theme.of(context),
            ),
            keyboardAppearance: Theme.of(context).brightness,
            name: 'comment',
            maxLines: 2,
          ),

          const SizedBox(height: 24),

          // Action area with animated transition
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: !dirty
                ? MeasurementSuggestions(
                    key: const ValueKey('suggestions'),
                    measurableDataType: dataType,
                    saveMeasurement: saveMeasurement,
                    measurementTime: measurementTime,
                  )
                : (_formKey.currentState?.isValid ?? false)
                    ? SizedBox(
                        key: const ValueKey('save'),
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          key: const Key('measurement_save'),
                          onPressed: () => saveMeasurement(
                            measurableDataType: dataType,
                            measurementTime: measurementTime,
                          ),
                          icon: const Icon(Icons.check_rounded),
                          label:
                              Text(context.messages.addMeasurementSaveButton),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('empty')),
          ),
        ],
      ),
    );
  }
}

/// Value input field with unit suffix
class _ValueInputField extends StatelessWidget {
  const _ValueInputField({required this.dataType});

  final MeasurableDataType dataType;

  @override
  Widget build(BuildContext context) {
    final hasUnit = dataType.unitName.isNotEmpty;

    return FormBuilderTextField(
      initialValue: '',
      key: const Key('measurement_value_field'),
      name: 'value',
      autofocus: true,
      style: context.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: context.colorScheme.onSurface,
      ),
      decoration: inputDecoration(
        labelText: dataType.displayName,
        themeData: Theme.of(context),
      ).copyWith(
        hintText: '0',
        hintStyle: context.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
        ),
        suffixIcon: hasUnit
            ? Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  widthFactor: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      dataType.unitName,
                      style: context.textTheme.labelMedium?.copyWith(
                        color: context.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      validator: FormBuilderValidators.compose([
        FormBuilderValidators.required(),
        (value) {
          if (value == null || value.isEmpty) return null;
          final normalized = value.replaceAll(',', '.');
          if (num.tryParse(normalized) == null) {
            return FormBuilderValidators.numeric<String>().call(value);
          }
          return null;
        },
      ]),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?[\d.,]*$')),
      ],
    );
  }
}
