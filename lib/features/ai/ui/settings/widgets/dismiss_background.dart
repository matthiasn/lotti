import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

/// A stylish delete background widget for dismissible list items
///
/// Displays a gradient background with a delete icon and text when
/// swiping to delete a configuration item.
///
/// Features:
/// - Gradient background transitioning from light to dark error colors
/// - Centered delete icon with subtle container
/// - "Delete" text label
/// - Drop shadow for depth
///
/// This widget is designed to be used as the background parameter
/// of a Dismissible widget.
///
/// Example:
/// ```dart
/// Dismissible(
///   key: ValueKey(item.id),
///   background: const DismissBackground(),
///   child: MyListItem(),
/// )
/// ```
class DismissBackground extends StatelessWidget {
  const DismissBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            context.colorScheme.errorContainer.withValues(alpha: 0.1),
            context.colorScheme.error.withValues(alpha: 0.9),
            context.colorScheme.error,
          ],
          stops: const [0.0, 0.7, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: context.colorScheme.error.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildDeleteIndicator(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteIndicator(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.colorScheme.onError.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.delete_forever_rounded,
            color: context.colorScheme.onError,
            size: 24,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Delete',
          style: context.textTheme.labelMedium?.copyWith(
            color: context.colorScheme.onError,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
