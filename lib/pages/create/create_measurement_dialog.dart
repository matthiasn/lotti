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

          // Value input card
          _ValueInputCard(dataType: dataType),

          const SizedBox(height: 20),

          // Date & Time section
          _SectionHeader(
            icon: Icons.schedule_rounded,
            label: context.messages.addMeasurementDateLabel,
          ),
          const SizedBox(height: 8),
          DateTimeField(
            dateTime: measurementTime,
            labelText: context.messages.addMeasurementDateLabel,
            setDateTime: (picked) {
              setState(() {
                measurementTime = picked;
              });
            },
          ),

          const SizedBox(height: 20),

          // Comment section
          _SectionHeader(
            icon: Icons.notes_rounded,
            label: context.messages.addMeasurementCommentLabel,
          ),
          const SizedBox(height: 8),
          FormBuilderTextField(
            initialValue: '',
            key: const Key('measurement_comment_field'),
            decoration: InputDecoration(
              hintText: context.messages.addMeasurementCommentLabel,
              hintStyle: context.textTheme.bodyMedium?.copyWith(
                color:
                    context.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: context.colorScheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: context.colorScheme.primary,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
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
                : validate()
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

/// Section header with icon and label
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: context.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: context.textTheme.labelMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Enhanced value input card with unit badge
class _ValueInputCard extends StatelessWidget {
  const _ValueInputCard({required this.dataType});

  final MeasurableDataType dataType;

  @override
  Widget build(BuildContext context) {
    final hasUnit = dataType.unitName.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Display name and unit badge row
          Row(
            children: [
              Text(
                dataType.displayName,
                style: context.textTheme.labelMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              if (hasUnit) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    dataType.unitName,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Large value input
          FormBuilderTextField(
            initialValue: '',
            key: const Key('measurement_value_field'),
            name: 'value',
            autofocus: true,
            style: context.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: context.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color:
                    context.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
            ],
          ),
        ],
      ),
    );
  }
}
