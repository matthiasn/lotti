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
        Navigator.of(context).pop();
      },
      onClearAllPressed: (nextState) {
        updateDraft(nextState.copyWith(showDragHandle: showDragHandle));
      },
    );
  }

  return switch (presentation) {
    TaskShowcaseFilterPresentation.desktop => showDialog<void>(
      context: context,
      builder: (context) {
        var draftState = initialState.copyWith(showDragHandle: false);
        return StatefulBuilder(
          builder: (context, setState) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(24),
            child: buildSheet(
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
      builder: (context) {
        var draftState = initialState.copyWith(showDragHandle: true);
        return StatefulBuilder(
          builder: (context, setState) => SafeArea(
            top: false,
            child: buildSheet(
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
