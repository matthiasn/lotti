import 'dart:async';

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

/// Save handler for the filter modal. Receives the trimmed name the user
/// committed in the Save popup along with the modal's current draft state,
/// so the consumer can persist the in-modal edits — not the previously
/// applied filter — to the saved-filter sidebar.
///
/// May return a [Future]; the modal layer awaits it so persistence failures
/// keep the modal open instead of silently dismissing.
typedef DesignSystemFilterSaveHandler =
    FutureOr<void> Function(String name, DesignSystemTaskFilterState state);

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
/// next to Apply. Committing the inline name popup applies the current draft
/// state via [onApplied], awaits [onSavePressed] with the committed name and
/// that same draft, and closes the modal on success — so Save is "apply +
/// save + close" in one action and the saved filter always reflects what's
/// currently visible in the modal. If [onSavePressed] throws, the modal
/// stays open so the user can retry. The button is disabled when [canSave]
/// is false (typically because the filter has no clauses to save).
Future<void> showDesignSystemFilterModal({
  required BuildContext context,
  required DesignSystemTaskFilterState initialState,
  required ValueChanged<DesignSystemTaskFilterState> onApplied,
  DesignSystemFilterFieldHandler? onFieldPressed,
  Widget Function(Widget)? modalDecorator,
  DesignSystemFilterSaveHandler? onSavePressed,
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
              // Save = apply + save + close. The action bar still hands us
              // just the committed name; the modal layer captures the
              // current draft state, applies it, awaits persistence, and
              // only pops on success — a thrown handler keeps the modal
              // open so the user can retry.
              onSavePressed: onSavePressed == null
                  ? null
                  : (name) {
                      unawaited(
                        _handleSavePressed(
                          ctx,
                          name: name,
                          stateNotifier: stateNotifier,
                          onApplied: onApplied,
                          onSavePressed: onSavePressed,
                        ),
                      );
                    },
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
                // Clearance for the floating glass footer at the bottom of
                // the modal. The footer is ~96 tall (padT 16 + button 56 +
                // padB 24); `step10` (64) leaves the last filter section
                // visibly crowded against the divider. `step12` (96)
                // matches the footer height so the last item sits flush
                // above the divider when fully scrolled, with a clear
                // breathing-room gap when not scrolled.
                SizedBox(height: spacing.step12),
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

/// Drives the Save flow off-thread: applies the draft, awaits the consumer's
/// persistence handler, and pops the modal only when persistence succeeds.
/// On failure the modal is left open so the user can retry; the error is
/// rethrown by [onSavePressed] callers when they want telemetry.
Future<void> _handleSavePressed(
  BuildContext context, {
  required String name,
  required ValueNotifier<DesignSystemTaskFilterState> stateNotifier,
  required ValueChanged<DesignSystemTaskFilterState> onApplied,
  required DesignSystemFilterSaveHandler onSavePressed,
}) async {
  final draft = stateNotifier.value;
  onApplied(draft);
  try {
    await onSavePressed(name, draft);
  } catch (_) {
    // Persistence failed — leave the modal open. The consumer is
    // responsible for surfacing the error (logging, toast, etc.).
    return;
  }
  if (!context.mounted) return;
  Navigator.of(context).pop();
}
