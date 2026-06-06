import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Info-blue pill marking an agenda item / day block as bound to a task
/// (`prototype/shared.jsx → LinkBadge`, handoff v2 item 3). Shows the
/// linked task's name; tapping opens the task.
class LinkBadge extends StatelessWidget {
  const LinkBadge({required this.label, this.onTap, super.key});

  /// Linked task name.
  final String label;

  /// Opens the linked task.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final info = tokens.colors.alert.info.defaultColor;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: DsPill(
        variant: DsPillVariant.tinted,
        color: info,
        label: label,
        leading: Icon(
          Icons.link_rounded,
          size: tokens.typography.size.caption,
          color: info,
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Neutral "Time block" tag for agenda items / day blocks with no
/// backing task (`prototype/shared.jsx → StandaloneTag`).
class StandaloneTag extends StatelessWidget {
  const StandaloneTag({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DsPill(
      variant: DsPillVariant.filled,
      label: context.messages.dailyOsNextStandaloneTag,
      labelColor: tokens.colors.text.lowEmphasis,
      leading: Icon(
        Icons.schedule_rounded,
        size: tokens.typography.size.caption,
        color: tokens.colors.text.lowEmphasis,
      ),
    );
  }
}
