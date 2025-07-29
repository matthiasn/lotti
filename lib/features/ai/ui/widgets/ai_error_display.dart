import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/inference_error.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/lotti_primary_button.dart';
import 'package:lotti/widgets/lotti_secondary_button.dart';

/// A widget that displays AI inference errors in a user-friendly way
class AiErrorDisplay extends StatefulWidget {
  const AiErrorDisplay({
    required this.error,
    this.onRetry,
    super.key,
  });

  final InferenceError error;
  final VoidCallback? onRetry;

  @override
  State<AiErrorDisplay> createState() => _AiErrorDisplayState();
}

class _AiErrorDisplayState extends State<AiErrorDisplay> {
  @override
  Widget build(BuildContext context) {
    // Use modal surface background for the outer container
    return Container(
      margin: const EdgeInsets.all(AppTheme.errorModalMargin),
      padding: const EdgeInsets.all(AppTheme.errorModalPadding),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.errorModalBorderRadius),
      ),
      child: Center(
        child: Card(
          color: context.colorScheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppTheme.errorModalBorderRadius),
            side: BorderSide(
              color: context.colorScheme.error.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.errorModalPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Error icon
                Container(
                  padding: const EdgeInsets.all(AppTheme.errorModalIconPadding),
                  decoration: BoxDecoration(
                    color: context.colorScheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(
                        AppTheme.errorModalIconBorderRadius),
                  ),
                  child: Icon(
                    _getErrorIcon(),
                    color: context.colorScheme.error,
                    size: AppTheme.errorModalIconSize,
                  ),
                ),
                const SizedBox(height: AppTheme.errorModalSpacingLarge),
                // Error title
                Text(
                  widget.error.type.getTitle(context),
                  style: context.textTheme.titleMedium?.copyWith(
                    color: context.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.errorModalSpacingSmall),
                // Error message - selectable for copying
                SelectableText(
                  widget.error.message,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurface.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                // Suggestions based on error type
                if (_getSuggestions().isNotEmpty) ...[
                  const SizedBox(height: AppTheme.errorModalSpacingLarge),
                  Container(
                    padding: const EdgeInsets.all(
                        AppTheme.errorModalSuggestionPadding),
                    decoration: BoxDecoration(
                      color: context.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(
                          AppTheme.errorModalSuggestionBorderRadius),
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
                        const SizedBox(height: AppTheme.errorModalSpacingSmall),
                        ..._getSuggestions().map((suggestion) => Padding(
                              padding: const EdgeInsets.only(
                                  bottom: AppTheme.errorModalSuggestionSpacing),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '• ',
                                    style: context.textTheme.bodySmall,
                                  ),
                                  Expanded(
                                    child: SelectableText(
                                      suggestion,
                                      style:
                                          context.textTheme.bodySmall?.copyWith(
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
                if (widget.onRetry != null && _canRetry()) ...[
                  const SizedBox(height: AppTheme.errorModalSpacingButton),
                  LottiPrimaryButton(
                    onPressed: widget.onRetry,
                    icon: Icons.refresh_rounded,
                    label: context.messages.aiInferenceErrorRetryButton,
                  ),
                ],
                // View Log button
                const SizedBox(
                    height: AppTheme.errorModalSpacingButtonSecondary),
                LottiSecondaryButton(
                  label: context.messages.aiInferenceErrorViewLogButton,
                  icon: Icons.article_outlined,
                  onPressed: () {
                    beamToNamed('/settings/advanced/logging');
                  },
                  fullWidth: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getErrorIcon() {
    switch (widget.error.type) {
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
    final error = widget.error;
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
        if (error.message.contains('not found') &&
            error.message.contains('model')) {
          final modelMatch =
              RegExp(r'model\s*"([^"]+)"').firstMatch(error.message);
          final modelName = modelMatch?.group(1) ?? 'the model';
          if (error.message.contains('pulling')) {
            return [
              'Run: ollama pull $modelName',
              'Make sure Ollama is running',
              'Check if the model name is correct',
              'Visit ollama.ai/library for available models',
            ];
          } else {
            return [
              'Model "$modelName" is not available',
              'Check if the model name is correct',
              'Verify the model is installed/accessible',
              'Try selecting a different model',
            ];
          }
        }
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
    return widget.error.type != InferenceErrorType.authentication &&
        widget.error.type != InferenceErrorType.invalidRequest;
  }
}
