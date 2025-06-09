import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

/// A reusable error state widget for configuration lists
///
/// Displays error information with an optional retry button.
/// Designed to provide a consistent error UI across the AI settings module.
///
/// The widget shows:
/// - An error icon
/// - A title explaining that an error occurred
/// - The error message
/// - An optional retry button if a callback is provided
///
/// Example:
/// ```dart
/// ConfigErrorState(
///   error: 'Network connection failed',
///   onRetry: () => refetchData(),
/// )
/// ```
class ConfigErrorState extends StatelessWidget {
  const ConfigErrorState({
    required this.error,
    this.onRetry,
    super.key,
  });

  /// The error object or message to display
  final Object error;

  /// Optional callback for retry functionality
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildErrorIcon(context),
          const SizedBox(height: 16),
          _buildTitle(context),
          const SizedBox(height: 8),
          _buildErrorMessage(context),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            _buildRetryButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorIcon(BuildContext context) {
    return Icon(
      Icons.error_outline,
      size: 64,
      color: context.colorScheme.error,
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Text(
      'Error loading configurations',
      style: context.textTheme.titleMedium?.copyWith(
        color: context.colorScheme.error,
      ),
    );
  }

  Widget _buildErrorMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        error.toString(),
        style: context.textTheme.bodyMedium,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildRetryButton() {
    return FilledButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: const Text('Retry'),
    );
  }
}
