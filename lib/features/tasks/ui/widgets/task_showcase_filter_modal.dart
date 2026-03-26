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
  return switch (presentation) {
    TaskShowcaseFilterPresentation.desktop => showDialog<void>(
      context: context,
      builder: (context) {
        var draftState = initialState.copyWith(showDragHandle: false);
        return StatefulBuilder(
          builder: (context, setState) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(24),
            child: DesignSystemTaskFilterSheet(
              state: draftState,
              onChanged: (nextState) {
                setState(
                  () => draftState = nextState.copyWith(showDragHandle: false),
                );
              },
              onApplyPressed: (nextState) {
                onApplied(nextState.copyWith(showDragHandle: false));
                Navigator.of(context).pop();
              },
              onClearAllPressed: (nextState) {
                setState(
                  () => draftState = nextState.copyWith(showDragHandle: false),
                );
              },
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
            child: DesignSystemTaskFilterSheet(
              state: draftState,
              onChanged: (nextState) {
                setState(
                  () => draftState = nextState.copyWith(showDragHandle: true),
                );
              },
              onApplyPressed: (nextState) {
                onApplied(nextState.copyWith(showDragHandle: true));
                Navigator.of(context).pop();
              },
              onClearAllPressed: (nextState) {
                setState(
                  () => draftState = nextState.copyWith(showDragHandle: true),
                );
              },
            ),
          ),
        );
      },
    ),
  };
}
