import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_modal.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';

enum TaskShowcaseFilterPresentation {
  desktop,
  mobile,
}

Future<void> showTaskShowcaseFilterModal({
  required BuildContext context,
  required DesignSystemTaskFilterState initialState,
  required ValueChanged<DesignSystemTaskFilterState> onApplied,
  required TaskShowcaseFilterPresentation presentation,
}) {
  return showDesignSystemFilterModal(
    context: context,
    initialState: initialState,
    onApplied: onApplied,
    presentation: switch (presentation) {
      TaskShowcaseFilterPresentation.desktop =>
        DesignSystemFilterPresentation.desktop,
      TaskShowcaseFilterPresentation.mobile =>
        DesignSystemFilterPresentation.mobile,
    },
  );
}
