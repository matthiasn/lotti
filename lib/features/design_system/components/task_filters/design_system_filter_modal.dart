import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

enum DesignSystemFilterPresentation {
  desktop,
  mobile,
}

typedef DesignSystemFilterFieldHandler =
    Future<DesignSystemTaskFilterState?> Function(
      BuildContext context,
      DesignSystemTaskFilterState draftState,
      DesignSystemTaskFilterSection section,
    );

Future<void> showDesignSystemFilterModal({
  required BuildContext context,
  required DesignSystemTaskFilterState initialState,
  required ValueChanged<DesignSystemTaskFilterState> onApplied,
  required DesignSystemFilterPresentation presentation,
  DesignSystemFilterFieldHandler? onFieldPressed,
}) {
  final showDragHandle = presentation == DesignSystemFilterPresentation.mobile;

  Widget buildSheet(
    BuildContext sheetContext,
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
      onFieldPressed: onFieldPressed == null
          ? null
          : (section) async {
              final nextState = await onFieldPressed(
                sheetContext,
                draftState,
                section,
              );
              if (!sheetContext.mounted || nextState == null) {
                return;
              }

              updateDraft(nextState.copyWith(showDragHandle: showDragHandle));
            },
    );
  }

  return switch (presentation) {
    DesignSystemFilterPresentation.desktop => showDialog<void>(
      context: context,
      builder: (_) {
        var draftState = initialState.copyWith(showDragHandle: false);
        return StatefulBuilder(
          builder: (dialogContext, setState) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(24),
            child: buildSheet(
              dialogContext,
              draftState,
              (next) => setState(() => draftState = next),
            ),
          ),
        );
      },
    ),
    DesignSystemFilterPresentation.mobile => ModalUtils.showBottomSheet<void>(
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
              draftState,
              (next) => setState(() => draftState = next),
            ),
          ),
        );
      },
    ),
  };
}
