import 'package:flutter/material.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

/// A context-aware floating action button for the AI Settings page.
///
/// The glyph is a single additive `+` on every tab — the three former
/// per-tab glyphs (`add_link` / `auto_awesome` / `tune`) didn't read as
/// "add" and weren't a learnable family. The per-tab meaning survives in
/// the accessibility label (provider / model / profile), which still
/// changes with the active tab. Visual treatment is the design-system
/// circular FAB used everywhere else in Settings + the Tasks tab; the
/// previously-visible inline label is no longer rendered, but the
/// per-tab text survives as the [DesignSystemFloatingActionButton.semanticLabel]
/// (so screen readers and hover tooltips still announce the right
/// action).
class AiSettingsFloatingActionButton extends StatelessWidget {
  const AiSettingsFloatingActionButton({
    required this.activeTab,
    required this.onPressed,
    super.key,
  });

  /// The currently active tab.
  final AiSettingsTab activeTab;

  /// Callback when the FAB is pressed (for add action).
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = _getIconAndLabel(context);

    return DesignSystemBottomNavigationFabPadding(
      child: DesignSystemFloatingActionButton(
        icon: icon,
        semanticLabel: label,
        onPressed: onPressed,
      ),
    );
  }

  /// Returns the additive glyph (constant across tabs) and the
  /// tab-specific accessibility label.
  (IconData, String) _getIconAndLabel(BuildContext context) {
    const icon = Icons.add_rounded;
    return switch (activeTab) {
      AiSettingsTab.providers => (
        icon,
        context.messages.aiSettingsAddProviderButton,
      ),
      AiSettingsTab.models => (icon, context.messages.aiSettingsAddModelButton),
      AiSettingsTab.profiles => (
        icon,
        context.messages.aiSettingsAddProfileButton,
      ),
    };
  }
}
