import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

typedef DesignSystemFilterFieldHandler =
    Future<DesignSystemTaskFilterState?> Function(
      BuildContext context,
      DesignSystemTaskFilterState draftState,
      DesignSystemTaskFilterSection section,
    );

/// Shows the design system task filter modal using Wolt modal sheet.
///
/// On mobile the modal appears as a bottom sheet; on desktop as a centered
/// dialog — determined automatically by [ModalUtils.modalTypeBuilder].
///
/// The action bar (Clear All + Apply) is rendered as a sticky action bar that
/// remains visible while the filter sections scroll. State is shared between
/// the scrollable content and the sticky action bar via a [ValueNotifier].
///
/// When [onSavePressed] is supplied, an additional Save affordance is rendered
/// next to Apply. Tapping it opens an inline name popup; the entered name is
/// passed to [onSavePressed]. The button is disabled when [canSave] is false
/// (typically because the filter has no clauses to save).
Future<void> showDesignSystemFilterModal({
  required BuildContext context,
  required DesignSystemTaskFilterState initialState,
  required ValueChanged<DesignSystemTaskFilterState> onApplied,
  DesignSystemFilterFieldHandler? onFieldPressed,
  Widget Function(Widget)? modalDecorator,
  ValueChanged<String>? onSavePressed,
  bool canSave = false,
  String? initialSaveName,
}) async {
  final stateNotifier = ValueNotifier(initialState);

  try {
    await ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.tasksFilterTitle,
      useRootNavigator: true,
      modalDecorator: modalDecorator,
      padding: const EdgeInsets.only(left: 20, top: 8, right: 20, bottom: 20),
      stickyActionBarBuilder: (modalContext) {
        return ValueListenableBuilder<DesignSystemTaskFilterState>(
          valueListenable: stateNotifier,
          builder: (ctx, state, _) {
            return DesignSystemTaskFilterActionBar(
              state: state,
              onChanged: (next) => stateNotifier.value = next,
              onApplyPressed: (next) {
                onApplied(next);
                Navigator.of(ctx).pop();
              },
              onClearAllPressed: (next) => stateNotifier.value = next,
              onSavePressed: onSavePressed,
              canSave: canSave,
              initialSaveName: initialSaveName,
            );
          },
        );
      },
      builder: (modalContext) {
        return ValueListenableBuilder<DesignSystemTaskFilterState>(
          valueListenable: stateNotifier,
          builder: (ctx, draftState, _) {
            final spacing = ctx.designTokens.spacing;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DesignSystemTaskFilterSheet(
                  state: draftState,
                  onChanged: (next) => stateNotifier.value = next,
                  onFieldPressed: onFieldPressed == null
                      ? null
                      : (section) async {
                          final nextState = await onFieldPressed(
                            ctx,
                            stateNotifier.value,
                            section,
                          );
                          if (!ctx.mounted || nextState == null) return;
                          stateNotifier.value = nextState;
                        },
                ),
                SizedBox(height: spacing.step10),
              ],
            );
          },
        );
      },
    );
  } finally {
    stateNotifier.dispose();
  }
}
