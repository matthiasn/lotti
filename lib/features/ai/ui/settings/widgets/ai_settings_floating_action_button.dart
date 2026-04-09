import 'package:flutter/material.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

/// A context-aware floating action button for the AI Settings page
///
/// This FAB changes its icon and label based on the currently active tab,
/// providing quick access to create new configurations.
class AiSettingsFloatingActionButton extends StatelessWidget {
  const AiSettingsFloatingActionButton({
    required this.activeTab,
    required this.onPressed,
    super.key,
  });

  /// The currently active tab
  final AiSettingsTab activeTab;

  /// Callback when the FAB is pressed (for add action)
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = _getIconAndLabel(context);

    return DesignSystemBottomNavigationFabPadding(
      child: Container(
        margin: const EdgeInsets.only(right: 20, bottom: 20),
        child: FloatingActionButton.extended(
          onPressed: onPressed,
          icon: _buildIconContainer(context, icon),
          label: _buildLabel(context, label),
          backgroundColor: context.colorScheme.primaryContainer,
          foregroundColor: context.colorScheme.onPrimaryContainer,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  /// Returns the appropriate icon and label for the active tab
  (IconData, String) _getIconAndLabel(BuildContext context) {
    return switch (activeTab) {
      AiSettingsTab.providers => (
        Icons.add_link_rounded,
        context.messages.aiSettingsAddProviderButton,
      ),
      AiSettingsTab.models => (
        Icons.auto_awesome_rounded,
        context.messages.aiSettingsAddModelButton,
      ),
      AiSettingsTab.profiles => (
        Icons.tune_rounded,
        context.messages.aiSettingsAddProfileButton,
      ),
    };
  }

  Widget _buildIconContainer(BuildContext context, IconData icon) {
    final containerColor = context.colorScheme.onPrimaryContainer;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            containerColor.withValues(alpha: 0.2),
            containerColor.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 20,
        color: containerColor,
      ),
    );
  }

  Widget _buildLabel(BuildContext context, String label) {
    final textColor = context.colorScheme.onPrimaryContainer;

    return Text(
      label,
      style: context.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: textColor,
      ),
    );
  }
}
