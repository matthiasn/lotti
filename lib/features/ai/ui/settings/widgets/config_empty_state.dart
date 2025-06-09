import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

/// A reusable empty state widget for configuration lists
///
/// Displays a visually appealing empty state with an icon, message,
/// and helpful hint about adding new configurations.
///
/// This widget is designed to be used within sliver contexts and
/// provides consistent empty state UI across the AI settings module.
///
/// Example:
/// ```dart
/// ConfigEmptyState(
///   message: 'No AI providers configured',
///   icon: Icons.hub,
/// )
/// ```
class ConfigEmptyState extends StatelessWidget {
  const ConfigEmptyState({
    required this.message,
    required this.icon,
    super.key,
  });

  /// The message to display explaining the empty state
  final String message;

  /// The icon to display in the empty state
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildIconContainer(context),
          const SizedBox(height: 20),
          _buildMessage(context),
          const SizedBox(height: 8),
          _buildHintText(context),
        ],
      ),
    );
  }

  Widget _buildIconContainer(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.colorScheme.primaryContainer.withValues(alpha: 0.15),
            context.colorScheme.primaryContainer.withValues(alpha: 0.25),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Icon(
        icon,
        size: 40,
        color: context.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildMessage(BuildContext context) {
    return Text(
      message,
      style: context.textTheme.titleMedium?.copyWith(
        color: context.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildHintText(BuildContext context) {
    return Text(
      'Tap the + button to add one',
      style: context.textTheme.bodyMedium?.copyWith(
        color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
      ),
    );
  }
}
