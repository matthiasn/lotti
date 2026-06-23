import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// One row of the `⋯` overflow menu that lives in the top-right of every v2 AI
/// Settings card (Provider, Model, Profile). Cards used to expose a bare
/// `onMenuTap` callback that the page never wired up — so the icon looked
/// actionable but did nothing different from a card tap. This data class
/// replaces that pattern so each surface can declare an explicit list of menu
/// rows.
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

/// Compact `⋯` overflow trigger used by the v2 cards.
///
/// A thin adapter over the design system's [DesignSystemContextMenuButton]
/// (trigger + popover + dismissal) and [DesignSystemContextMenu] (the styled
/// rows), so all three cards share one menu component instead of a bespoke
/// `PopupMenuButton` wrapper. Renders nothing when [actions] is empty. [tooltip]
/// defaults to the generic, surface-neutral "More actions" so the same trigger
/// reads correctly on provider, model and profile cards.
class AiCardActionMenuButton extends StatelessWidget {
  const AiCardActionMenuButton({
    required this.actions,
    this.tooltip,
    super.key,
  });

  final List<AiCardMenuAction> actions;

  /// Overrides the trigger tooltip; defaults to `aiCardMenuTooltip`.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    final tokens = context.designTokens;
    final messages = context.messages;
    return DesignSystemContextMenuButton(
      tooltip: tooltip ?? messages.aiCardMenuTooltip,
      iconColor: tokens.colors.text.lowEmphasis,
      items: [
        for (final action in actions)
          DesignSystemContextMenuItem(
            label: action.label,
            icon: action.icon,
            isDestructive: action.isDestructive,
            onTap: action.onSelected,
          ),
      ],
    );
  }
}
