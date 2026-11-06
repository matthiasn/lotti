import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/callouts/design_system_inline_callout.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The task card's "I couldn't do what you asked": the agent's wake
/// completed, the user's request did not, and the agent said so with
/// `flag_unmet_request`.
///
/// A warning-toned callout — something is off, the way a 500 says so —
/// carrying the agent's one-sentence [reason], with the two answers the
/// reader has: look at the observations the agent filed about it, or clear
/// the flag. It stands until cleared; a later wake that completes does not
/// clear it, because wakes completing is exactly what hid the problem.
///
/// [reason] is the agent's own words, in the task's language: data, not
/// copy. A blank reason drops the line and keeps the title.
class UnmetRequestCallout extends StatelessWidget {
  const UnmetRequestCallout({
    required this.reason,
    required this.onShowObservations,
    required this.onClear,
    super.key,
  });

  final String? reason;

  /// Opens the agent internals on the observations tab.
  final VoidCallback onShowObservations;

  /// Clears the flag.
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final trimmedReason = reason?.trim() ?? '';
    return DesignSystemInlineCallout(
      icon: LottiIcons.warning,
      title: messages.aiCardUnmetRequestTitle,
      text: trimmedReason.isEmpty
          ? messages.aiCardUnmetRequestNoReason
          : trimmedReason,
      // It arrives to report a failure: announce it once, whole.
      announce: true,
      actions: [
        DesignSystemButton(
          key: const ValueKey('unmet-request-clear'),
          label: messages.clearButton,
          // A dismissal: it must not out-shout the way forward beside it.
          variant: DesignSystemButtonVariant.quiet,
          tapTargetSize: MaterialTapTargetSize.padded,
          onPressed: onClear,
        ),
        DesignSystemButton(
          key: const ValueKey('unmet-request-observations'),
          label: messages.aiCardUnmetRequestShowObservations,
          variant: DesignSystemButtonVariant.tertiary,
          tapTargetSize: MaterialTapTargetSize.padded,
          onPressed: onShowObservations,
        ),
      ],
    );
  }
}
