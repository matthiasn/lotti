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
/// - Selection mode support with delete functionality
///
/// Tab-specific configurations:
/// - Providers: Add link icon with "Add Provider" label
/// - Models: Auto awesome icon with "Add Model" label
/// - Prompts: Edit note icon with "Add Prompt" label
/// - Selection mode: Delete icon with count label
///
/// Example:
/// ```dart
/// AiSettingsFloatingActionButton(
///   activeTab: AiSettingsTab.models,
///   onPressed: _handleAddTap,
///   selectionMode: false,
///   selectedCount: 0,
///   onDeletePressed: _handleDeleteTap,
/// )
/// ```
class AiSettingsFloatingActionButton extends StatelessWidget {
  const AiSettingsFloatingActionButton({
    required this.activeTab,
    required this.onPressed,
    this.selectionMode = false,
    this.selectedCount = 0,
    this.onDeletePressed,
    super.key,
  });

  /// The currently active tab
  final AiSettingsTab activeTab;

  /// Callback when the FAB is pressed (for add action)
  final VoidCallback onPressed;

  /// Whether selection mode is active
  final bool selectionMode;

  /// Number of selected items
  final int selectedCount;

  /// Callback when delete is pressed (for selection mode)
  final VoidCallback? onDeletePressed;

  @override
  Widget build(BuildContext context) {
    // Show delete FAB when in selection mode with items selected
    if (selectionMode && selectedCount > 0) {
      return _buildDeleteFab(context);
    }

    // Show normal add FAB
    return _buildAddFab(context);
  }

  Widget _buildAddFab(BuildContext context) {
    final (icon, label) = _getIconAndLabel(context);

    return Container(
      margin: const EdgeInsets.only(right: 20, bottom: 20),
      child: FloatingActionButton.extended(
        onPressed: onPressed,
        icon: _buildIconContainer(context, icon, isDelete: false),
        label: _buildLabel(context, label, isDelete: false),
        backgroundColor: context.colorScheme.primaryContainer,
        foregroundColor: context.colorScheme.onPrimaryContainer,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildDeleteFab(BuildContext context) {
    final label = context.messages.aiSettingsDeleteSelectedLabel(selectedCount);

    return Container(
      margin: const EdgeInsets.only(right: 20, bottom: 20),
      child: FloatingActionButton.extended(
        onPressed: onDeletePressed,
        icon:
            _buildIconContainer(context, Icons.delete_rounded, isDelete: true),
        label: _buildLabel(context, label, isDelete: true),
        backgroundColor: context.colorScheme.errorContainer,
        foregroundColor: context.colorScheme.onErrorContainer,
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

  Widget _buildIconContainer(
    BuildContext context,
    IconData icon, {
    required bool isDelete,
  }) {
    final containerColor = isDelete
        ? context.colorScheme.onErrorContainer
        : context.colorScheme.onPrimaryContainer;

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

  Widget _buildLabel(
    BuildContext context,
    String label, {
    required bool isDelete,
  }) {
    final textColor = isDelete
        ? context.colorScheme.onErrorContainer
        : context.colorScheme.onPrimaryContainer;

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
