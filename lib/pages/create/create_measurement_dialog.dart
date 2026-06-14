import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/create/suggest_measurement.dart';
import 'package:lotti/widgets/date_time/datetime_field.dart';

/// Bottom-sheet body for logging a measurement value.
///
/// Organised around a single hero — the value — which is a label-less,
/// centered big-digit well (the modal title already names the measurable) with
/// the unit rendered as an adjacent pill so the number and unit read as one
/// measurement ("750 ml"). Directly beneath it sit persistent one-tap
/// quick-value chips (the fast path for a returning logger). The observed-at
/// row (defaulting to now) and an optional comment follow in quieter chrome,
/// and the bottom holds a fixed, always-visible Save button that is disabled
/// until the entered value is a valid number.
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
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _valueFocus = FocusNode();
  final FocusNode _commentFocus = FocusNode();

  DateTime measurementTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Rebuild as the value changes so the Save button's enabled state tracks
    // validity live.
    _valueController.addListener(_onValueChanged);
  }

  @override
  void dispose() {
    _valueController
      ..removeListener(_onValueChanged)
      ..dispose();
    _commentController.dispose();
    _valueFocus.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  void _onValueChanged() => setState(() {});

  num? _parse(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return num.tryParse(normalized);
  }

  bool get _isValid => _parse(_valueController.text) != null;

  Future<void> _save(MeasurableDataType dataType, {num? value}) async {
    final resolved = value ?? _parse(_valueController.text);
    if (resolved == null) return;

    final measurement = MeasurementData(
      dataTypeId: dataType.id,
      dateTo: measurementTime,
      dateFrom: measurementTime,
      value: resolved,
    );
    Navigator.pop(context, 'Saved');

    await persistenceLogic.createMeasurementEntry(
      data: measurement,
      comment: _commentController.text,
      private: dataType.private ?? false,
    );
  }

  Future<void> _pickDateTime() {
    return showDateTimePickerModal(
      context,
      dateTime: measurementTime,
      labelText: context.messages.addMeasurementDateLabel,
      setDateTime: (picked) => setState(() => measurementTime = picked),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataType = getIt<EntitiesCacheService>().getDataTypeById(
      widget.measurableId,
    );

    if (dataType == null) {
      return const SizedBox.shrink();
    }

    final tokens = context.designTokens;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ValueHeroField(
          controller: _valueController,
          focusNode: _valueFocus,
          unit: dataType.unitName,
          onSubmitted: () => _save(dataType),
        ),
        MeasurementSuggestions(
          measurableDataType: dataType,
          onSelect: (value) => _save(dataType, value: value),
        ),
        SizedBox(height: tokens.spacing.sectionGap),
        _LabeledField(
          label: context.messages.addMeasurementDateLabel,
          child: _ObservedAtField(
            key: const Key('measurement_observed_at'),
            dateTime: measurementTime,
            onTap: _pickDateTime,
          ),
        ),
        SizedBox(height: tokens.spacing.step5),
        _LabeledField(
          label: context.messages.addMeasurementCommentLabel,
          child: _FieldShell(
            focusNode: _commentFocus,
            child: TextField(
              key: const Key('measurement_comment_field'),
              controller: _commentController,
              focusNode: _commentFocus,
              minLines: 1,
              maxLines: 3,
              cursorColor: tokens.colors.interactive.enabled,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
              decoration: _bareInputDecoration(
                hintText: context.messages.measurementCommentHint,
                hintStyle: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: tokens.spacing.sectionGap),
        Align(
          child: DesignSystemButton(
            key: const Key('measurement_save'),
            label: context.messages.addMeasurementSaveButton,
            size: DesignSystemButtonSize.large,
            leadingIcon: Icons.check_rounded,
            onPressed: _isValid ? () => unawaited(_save(dataType)) : null,
          ),
        ),
      ],
    );
  }
}

/// An [InputDecoration] with every border state nulled so the field draws no
/// box of its own — the surrounding [_FieldShell] owns the border and focus
/// ring. Nulling all six border slots (not just `border`) is required because
/// the app's `inputDecorationTheme` defines an outline border that would
/// otherwise bleed through `InputDecoration.collapsed` as a second box.
InputDecoration _bareInputDecoration({String? hintText, TextStyle? hintStyle}) {
  return InputDecoration(
    isDense: true,
    isCollapsed: true,
    filled: false,
    contentPadding: EdgeInsets.zero,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    hintText: hintText,
    hintStyle: hintStyle,
  );
}

/// Restricts input to a single optional leading minus, the digits, and at most
/// one decimal separator (`.` or `,`) — so malformed numbers like `1..2` can
/// never be entered and silently disable Save.
class _DecimalTextInputFormatter extends TextInputFormatter {
  const _DecimalTextInputFormatter();

  static final RegExp _pattern = RegExp(r'^-?\d*[.,]?\d*$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return _pattern.hasMatch(newValue.text) ? newValue : oldValue;
  }
}

/// A field with a design-system label above the [child] box.
class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: tokens.typography.styles.subtitle.subtitle2.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step2),
        child,
      ],
    );
  }
}

/// Design-system field surface: a rounded box whose hairline ramps from a
/// faint idle border to `interactive.enabled` (teal, 2px) on focus and
/// `text.mediumEmphasis` on hover — matching `DesignSystemTextInput`.
class _FieldShell extends StatefulWidget {
  const _FieldShell({
    required this.focusNode,
    required this.child,
    this.padding,
  });

  final FocusNode focusNode;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  State<_FieldShell> createState() => _FieldShellState();
}

class _FieldShellState extends State<_FieldShell> {
  bool _focused = false;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() =>
      setState(() => _focused = widget.focusNode.hasFocus);

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final Color borderColor;
    if (_focused) {
      borderColor = tokens.colors.interactive.enabled;
    } else if (_hovered) {
      borderColor = tokens.colors.text.mediumEmphasis;
    } else {
      borderColor = tokens.colors.text.highEmphasis.withValues(alpha: 0.12);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.radii.m),
          border: Border.all(color: borderColor, width: _focused ? 2 : 1),
        ),
        child: Padding(
          padding:
              widget.padding ??
              EdgeInsets.symmetric(
                horizontal: tokens.spacing.step4,
                vertical: tokens.spacing.step4,
              ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// The hero value input: a centered big-digit field with the unit rendered as
/// an adjacent tinted pill so the number and unit read as one measurement.
class _ValueHeroField extends StatelessWidget {
  const _ValueHeroField({
    required this.controller,
    required this.focusNode,
    required this.unit,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String unit;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final valueStyle = tokens.typography.styles.heading.heading1.copyWith(
      color: tokens.colors.text.highEmphasis,
    );

    return _FieldShell(
      focusNode: focusNode,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step5,
        vertical: tokens.spacing.step5,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: IntrinsicWidth(
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: tokens.spacing.step8),
                child: TextField(
                  key: const Key('measurement_value_field'),
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: valueStyle,
                  cursorColor: tokens.colors.interactive.enabled,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onSubmitted(),
                  inputFormatters: const [_DecimalTextInputFormatter()],
                  decoration: _bareInputDecoration(
                    hintText: context.messages.measurementValueHint,
                    hintStyle: valueStyle.copyWith(
                      color: tokens.colors.text.lowEmphasis,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (unit.isNotEmpty) ...[
            SizedBox(width: tokens.spacing.step2),
            Text(
              unit,
              style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A tappable, clearly-editable summary of the observed-at timestamp. Carries a
/// trailing edit-calendar glyph so it never reads as a locked, read-only value,
/// and opens the shared date/time picker on tap.
class _ObservedAtField extends StatelessWidget {
  const _ObservedAtField({
    required this.dateTime,
    required this.onTap,
    super.key,
  });

  final DateTime dateTime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.m);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: tokens.colors.text.highEmphasis.withValues(alpha: 0.12),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step4,
              vertical: tokens.spacing.step4,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    dfShorter.format(dateTime),
                    style: tokens.typography.styles.body.bodyMedium.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                ),
                Icon(
                  Icons.edit_calendar_outlined,
                  size: tokens.spacing.step6,
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
