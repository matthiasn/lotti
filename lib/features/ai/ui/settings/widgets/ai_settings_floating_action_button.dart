import 'package:flutter/material.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// A context-aware floating action button for the AI Settings page
///
/// This FAB changes its icon and label based on the currently active tab,
/// providing quick access to create new configurations.
///
/// Features:
/// - Dynamic icon and label based on active tab
/// - Gradient icon container for visual appeal
/// - Extended FAB with both icon and text
/// - Consistent styling across all tabs
///
/// Tab-specific configurations:
/// - Providers: Add link icon with "Add Provider" label
/// - Models: Auto awesome icon with "Add Model" label
/// - Prompts: Edit note icon with "Add Prompt" label
///
/// Example:
/// ```dart
/// AiSettingsFloatingActionButton(
///   activeTab: AiSettingsTab.models,
///   onPressed: _handleAddTap,
/// )
/// ```
class AiSettingsFloatingActionButton extends StatelessWidget {
  const AiSettingsFloatingActionButton({
    required this.activeTab,
    required this.onPressed,
    super.key,
  });

  /// The currently active tab
  final AiSettingsTab activeTab;

  /// Callback when the FAB is pressed
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = _getIconAndLabel(context);

    return Container(
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
    );
  }

  /// Returns the appropriate icon and label for the active tab
  (IconData, String) _getIconAndLabel(BuildContext context) {
    return switch (activeTab) {
      AiSettingsTab.providers => (
          Icons.add_link_rounded,
          context.messages.aiSettingsAddProviderButton
        ),
      AiSettingsTab.models => (
          Icons.auto_awesome_rounded,
          context.messages.aiSettingsAddModelButton
        ),
      AiSettingsTab.prompts => (
          Icons.edit_note_rounded,
          context.messages.aiSettingsAddPromptButton
        ),
    };
  }

  Widget _buildIconContainer(BuildContext context, IconData icon) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.colorScheme.onPrimaryContainer.withValues(alpha: 0.2),
            context.colorScheme.onPrimaryContainer.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 20,
        color: context.colorScheme.onPrimaryContainer,
      ),
    );
  }

  Widget _buildLabel(BuildContext context, String label) {
    return Text(
      label,
      style: context.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: context.colorScheme.onPrimaryContainer,
      ),
    );
  }
}
