import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_modal.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_selection_modal.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';

Future<void> showTaskShowcaseFilterModal({
  required BuildContext context,
  required DesignSystemTaskFilterState initialState,
  required ValueChanged<DesignSystemTaskFilterState> onApplied,
}) {
  return showDesignSystemFilterModal(
    context: context,
    initialState: initialState,
    onApplied: onApplied,
    onFieldPressed: (sheetContext, draftState, section) {
      return showDesignSystemTaskFilterFieldSelectionModal(
        context: sheetContext,
        draftState: draftState,
        section: section,
      );
    },
  );
}
