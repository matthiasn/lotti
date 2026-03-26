import 'package:flutter/material.dart';
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
  final showDragHandle = presentation == TaskShowcaseFilterPresentation.mobile;

  Widget buildSheet(
    BuildContext sheetContext,
    StateSetter setState,
    DesignSystemTaskFilterState draftState,
    void Function(DesignSystemTaskFilterState) updateDraft,
  ) {
    return DesignSystemTaskFilterSheet(
      state: draftState,
      onChanged: (nextState) {
        updateDraft(nextState.copyWith(showDragHandle: showDragHandle));
      },
      onApplyPressed: (nextState) {
        onApplied(nextState.copyWith(showDragHandle: showDragHandle));
        Navigator.of(sheetContext).pop();
      },
      onClearAllPressed: (nextState) {
        updateDraft(nextState.copyWith(showDragHandle: showDragHandle));
      },
    );
  }

  return switch (presentation) {
    TaskShowcaseFilterPresentation.desktop => showDialog<void>(
      context: context,
      builder: (_) {
        var draftState = initialState.copyWith(showDragHandle: false);
        return StatefulBuilder(
          builder: (dialogContext, setState) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(24),
            child: buildSheet(
              dialogContext,
              setState,
              draftState,
              (next) => setState(() => draftState = next),
            ),
          ),
        );
      },
    ),
    TaskShowcaseFilterPresentation.mobile => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        var draftState = initialState.copyWith(showDragHandle: true);
        return StatefulBuilder(
          builder: (sheetContext, setState) => SafeArea(
            top: false,
            child: buildSheet(
              sheetContext,
              setState,
              draftState,
              (next) => setState(() => draftState = next),
            ),
          ),
        );
      },
    ),
  };
}
