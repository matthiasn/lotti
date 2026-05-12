import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Single row of the `⋯` overflow menu that lives in the top-right of
/// every v2 AI Settings card (Provider, Model, Profile). Cards used to
/// expose a bare `onMenuTap` callback that the page never wired up —
/// so the icon looked actionable but did nothing different from a
/// card tap. This data class replaces that pattern so each surface
/// can declare an explicit list of menu rows.
class AiCardMenuAction {
  const AiCardMenuAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onSelected;

  /// Destructive rows render in the alert / error color and sit at the
  /// bottom of the menu. Used for Delete / Remove actions.
  final bool isDestructive;
}

/// Compact `⋯` overflow trigger used by the v2 cards. Wraps Material's
/// [PopupMenuButton] in fixed-size chrome so the cards can't drift
/// on hit-target size, icon weight, or padding.
class AiCardActionMenuButton extends StatelessWidget {
  const AiCardActionMenuButton({required this.actions, super.key});

  final List<AiCardMenuAction> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    final tokens = context.designTokens;
    final messages = context.messages;
    return SizedBox(
      width: tokens.spacing.step7,
      height: tokens.spacing.step7,
      child: PopupMenuButton<int>(
        tooltip: messages.aiProviderCardMenuTooltip,
        padding: EdgeInsets.zero,
        iconSize: 18,
        icon: Icon(
          Icons.more_horiz_rounded,
          color: tokens.colors.text.lowEmphasis,
        ),
        position: PopupMenuPosition.under,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radii.m),
        ),
        onSelected: (index) => actions[index].onSelected(),
        itemBuilder: (context) {
          return [
            for (var i = 0; i < actions.length; i++)
              PopupMenuItem<int>(
                value: i,
                child: _MenuRow(action: actions[i]),
              ),
          ];
        },
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.action});

  final AiCardMenuAction action;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = action.isDestructive
        ? tokens.colors.alert.error.defaultColor
        : tokens.colors.text.highEmphasis;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(action.icon, size: 18, color: color),
        SizedBox(width: tokens.spacing.step3),
        Text(
          action.label,
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: color,
            fontWeight: action.isDestructive
                ? tokens.typography.weight.semiBold
                : tokens.typography.weight.regular,
          ),
        ),
      ],
    );
  }
}
