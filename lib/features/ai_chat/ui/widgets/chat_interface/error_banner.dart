import 'package:flutter/material.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Dismissible error banner shown above the input area with retry and close
/// actions, wired to the session controller's retry/clear-error handlers.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({
    required this.error,
    required this.onRetry,
    required this.onDismiss,
    super.key,
  });

  final String error;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              container: true,
              liveRegion: true,
              label: error,
              child: ExcludeSemantics(
                child: Text(
                  error,
                  style: TextStyle(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              context.messages.aiInferenceErrorRetryButton,
              style: TextStyle(
                color: theme.colorScheme.error,
              ),
            ),
          ),
          Semantics(
            button: true,
            label: MaterialLocalizations.of(context).closeButtonTooltip,
            onTap: onDismiss,
            child: ExcludeSemantics(
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                icon: const Icon(Icons.close),
                onPressed: onDismiss,
                iconSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
