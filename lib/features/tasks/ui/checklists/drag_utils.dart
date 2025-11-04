import 'package:flutter/material.dart';

/// Creates a styled container for dragged items in checklists.
///
/// Provides a consistent visual appearance for items being dragged,
/// with a colored border and solid background.
Widget buildDragDecorator(BuildContext context, Widget child) {
  final theme = Theme.of(context);
  return Container(
    decoration: BoxDecoration(
      color: theme.colorScheme.surface,
      border: Border.all(
        color: theme.colorScheme.primary,
        width: 2,
      ),
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
}
