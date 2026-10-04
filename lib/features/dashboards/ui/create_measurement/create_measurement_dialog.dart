import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/ui/create_measurement/suggest_measurement.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_date_picker_modal.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/time_pickers/design_system_picker_wheels.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/widgets/modal/full_height_wolt_dialog_type.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

part 'create_measurement_dialog_measurement_editor_page_state_part.dart';
part 'create_measurement_dialog_observed_at_field_part.dart';

class _MeasurementCaptureDraft {
  _MeasurementCaptureDraft({
    required this.dataType,
    required DateTime initialDateTime,
    required this.routeClock,
  }) : measurementDateTime = ValueNotifier(initialDateTime),
       pickerDateTime = ValueNotifier(initialDateTime);

  final MeasurableDataType dataType;
  final Clock routeClock;
  final TextEditingController valueController = TextEditingController();
  final TextEditingController commentController = TextEditingController();
  final FocusNode valueFocusNode = FocusNode(
    debugLabel: 'measurement-value',
  );
  final FocusNode commentFocusNode = FocusNode(
    debugLabel: 'measurement-comment',
  );
  final FocusNode observedAtFocusNode = FocusNode(
    debugLabel: 'measurement-observed-at',
  );
  final ValueNotifier<DateTime> measurementDateTime;
  final ValueNotifier<DateTime> pickerDateTime;

  /// The choice picked so far on a choice measurable; always null on a
  /// numeric one.
  final ValueNotifier<String?> selectedChoiceId = ValueNotifier(null);
  final ValueNotifier<int> pageIndexNotifier = ValueNotifier(0);
  final ValueNotifier<_MeasurementSaveState> saveState = ValueNotifier(
    (isSaving: false, error: null),
  );

  bool _autofocusValue = true;
  bool _restoreObservedAtFocus = false;
  bool _disposed = false;

  bool takeValueAutofocus() {
    final autofocus = _autofocusValue;
    _autofocusValue = false;
    return autofocus;
  }

  bool takeObservedAtFocusRestore() {
    final restore = _restoreObservedAtFocus;
    _restoreObservedAtFocus = false;
    return restore;
  }

  num? parseValue([String? raw]) {
    final normalized = (raw ?? valueController.text).trim().replaceAll(
      ',',
      '.',
    );
    if (normalized.isEmpty) return null;
    return num.tryParse(normalized);
  }

  bool get isChoice => dataType.isChoice;

  bool get _hasValue =>
      isChoice ? selectedChoiceId.value != null : parseValue() != null;

  bool get canSave => _hasValue && !saveState.value.isSaving && !_disposed;

  DateTime now() => routeClock.now();

  void beginPickerChanges() {
    FocusManager.instance.primaryFocus?.unfocus();
    pickerDateTime.value = measurementDateTime.value;
    pageIndexNotifier.value = 1;
  }

  void commitPickerChanges() {
    measurementDateTime.value = pickerDateTime.value;
    _returnToEditor();
  }

  void discardPickerChanges() {
    pickerDateTime.value = measurementDateTime.value;
    _returnToEditor();
  }

  void _returnToEditor() {
    _restoreObservedAtFocus = true;
    pageIndexNotifier.value = 0;
  }

  /// Persists the draft. A numeric measurable saves [value] or the typed
  /// value; a choice measurable saves the selected choice as one occurrence
  /// (`value: 1`, see [MeasurementData.choiceId]).
  Future<void> save(BuildContext modalContext, {num? value}) async {
    if (saveState.value.isSaving || _disposed) return;
    final MeasurementData Function(DateTime observedAt) buildData;
    if (isChoice) {
      final choiceId = selectedChoiceId.value;
      if (choiceId == null) return;
      buildData = (observedAt) => MeasurementData(
        dataTypeId: dataType.id,
        dateTo: observedAt,
        dateFrom: observedAt,
        value: 1,
        choiceId: choiceId,
      );
    } else {
      final resolved = value ?? parseValue();
      if (resolved == null) return;
      buildData = (observedAt) => MeasurementData(
        dataTypeId: dataType.id,
        dateTo: observedAt,
        dateFrom: observedAt,
        value: resolved,
      );
    }

    final errorMessage = modalContext.messages.measurementSaveError;
    saveState.value = (isSaving: true, error: null);
    final data = buildData(measurementDateTime.value);
    try {
      final savedEntry = await getIt<PersistenceLogic>().createMeasurementEntry(
        data: data,
        comment: commentController.text,
        private: dataType.private ?? false,
      );
      if (savedEntry == null) {
        _showSaveError(errorMessage);
        return;
      }
      if (modalContext.mounted) {
        Navigator.of(modalContext).pop(data);
      }
    } catch (error, stackTrace) {
      DevLogger.error(
        name: 'MeasurementCaptureModal',
        message: 'Failed to save measurement',
        error: error,
        stackTrace: stackTrace,
      );
      _showSaveError(errorMessage);
    }
  }

  void _showSaveError(String message) {
    if (!_disposed) {
      saveState.value = (isSaving: false, error: message);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    valueController.dispose();
    commentController.dispose();
    valueFocusNode.dispose();
    commentFocusNode.dispose();
    observedAtFocusNode.dispose();
    measurementDateTime.dispose();
    pickerDateTime.dispose();
    selectedChoiceId.dispose();
    pageIndexNotifier.dispose();
    saveState.dispose();
  }
}
