import 'package:flutter/material.dart';

/// A reusable widget for displaying error states
///
/// Supports two display modes:
/// - Full: Shows icon, title, and error details in a decorated container
/// - Inline: Shows a compact error message bar
class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({
    required this.error,
    super.key,
    this.title,
    this.mode = ErrorDisplayMode.full,
  });

  final String error;
  final String? title;
  final ErrorDisplayMode mode;

  @override
  Widget build(BuildContext context) {
    if (mode == ErrorDisplayMode.inline) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          error,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color:
            Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            title ?? 'Error',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

enum ErrorDisplayMode {
  full,
  inline,
}
