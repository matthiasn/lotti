import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/inference_error.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// A widget that displays AI inference errors in a user-friendly way
class AiErrorDisplay extends StatelessWidget {
  const AiErrorDisplay({
    required this.error,
    this.onRetry,
    super.key,
  });

  final InferenceError error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colorScheme.errorContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Error icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colorScheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getErrorIcon(),
              color: context.colorScheme.error,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),

          // Error title
          Text(
            error.type.getTitle(context),
            style: context.textTheme.titleMedium?.copyWith(
              color: context.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          // Error message
          Text(
            error.message,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurface.withValues(alpha: 0.8),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          // Suggestions based on error type
          if (_getSuggestions().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.messages.aiInferenceErrorSuggestionsTitle,
                    style: context.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._getSuggestions().map((suggestion) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• ',
                              style: context.textTheme.bodySmall,
                            ),
                            Expanded(
                              child: Text(
                                suggestion,
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: context.colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],

          // Retry button
          if (onRetry != null && _canRetry()) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.messages.aiInferenceErrorRetryButton),
              style: FilledButton.styleFrom(
                backgroundColor: context.colorScheme.primary,
                foregroundColor: context.colorScheme.onPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getErrorIcon() {
    switch (error.type) {
      case InferenceErrorType.networkConnection:
        return Icons.wifi_off_rounded;
      case InferenceErrorType.timeout:
        return Icons.schedule_rounded;
      case InferenceErrorType.authentication:
        return Icons.lock_outline_rounded;
      case InferenceErrorType.rateLimit:
        return Icons.speed_rounded;
      case InferenceErrorType.invalidRequest:
        return Icons.error_outline_rounded;
      case InferenceErrorType.serverError:
        return Icons.cloud_off_rounded;
      case InferenceErrorType.unknown:
        return Icons.help_outline_rounded;
    }
  }

  List<String> _getSuggestions() {
    switch (error.type) {
      case InferenceErrorType.networkConnection:
        return [
          'Check your internet connection',
          'Verify the server URL is correct',
          'Ensure the service is accessible from your network',
          'Try using a different network',
        ];
      case InferenceErrorType.timeout:
        return [
          'Try again with a shorter prompt',
          'Check if the service is responding',
          'Consider using a different model',
        ];
      case InferenceErrorType.authentication:
        return [
          'Verify your API key is correct',
          'Check if the API key has expired',
          'Ensure the API key has proper permissions',
        ];
      case InferenceErrorType.rateLimit:
        return [
          'Wait a few minutes before trying again',
          'Consider upgrading your API plan',
          'Reduce the frequency of requests',
        ];
      case InferenceErrorType.invalidRequest:
        return [
          'Check your model configuration',
          'Verify the selected model is available',
          'Review the prompt parameters',
        ];
      case InferenceErrorType.serverError:
        return [
          'Wait a few minutes and try again',
          'Check the service status page',
          'Contact support if the issue persists',
        ];
      case InferenceErrorType.unknown:
        return [
          'Check the error details',
          'Try again with different settings',
          'Contact support if the issue persists',
        ];
    }
  }

  bool _canRetry() {
    // Allow retry for most error types except authentication
    return error.type != InferenceErrorType.authentication &&
        error.type != InferenceErrorType.invalidRequest;
  }
}
