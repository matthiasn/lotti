import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_error.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/features/ai/ui/widgets/ai_error_display.dart';
import 'package:lotti/features/ai/util/ai_error_utils.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

/// Progress view for unified AI inference
class UnifiedAiProgressContent extends ConsumerStatefulWidget {
  const UnifiedAiProgressContent({
    required this.entityId,
    required this.promptId,
    super.key,
  });

  final String entityId;
  final String promptId;

  @override
  ConsumerState<UnifiedAiProgressContent> createState() =>
      _UnifiedAiProgressContentState();
}

class _UnifiedAiProgressContentState
    extends ConsumerState<UnifiedAiProgressContent> {
  static final _modelNotInstalledRegex = RegExp(
    'model "([^"]+)" is not installed',
    caseSensitive: false,
  );

  void _handleRetry() {
    // Invalidate the provider to trigger retry
    ref.invalidate(
      unifiedAiControllerProvider(
        entityId: widget.entityId,
        promptId: widget.promptId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final promptConfigAsync = ref.watch(
      aiConfigByIdProvider(widget.promptId),
    );

    return promptConfigAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Error loading prompt: $error',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
      data: (config) {
        if (config == null || config is! AiConfigPrompt) {
          return const Center(child: Text('Invalid prompt configuration'));
        }

        final promptConfig = config;
        final state = ref.watch(
          unifiedAiControllerProvider(
            entityId: widget.entityId,
            promptId: widget.promptId,
          ),
        );

        final inferenceStatus = ref.watch(
          inferenceStatusControllerProvider(
            id: widget.entityId,
            aiResponseType: promptConfig.aiResponseType,
          ),
        );

        final isError = inferenceStatus == InferenceStatus.error;
        final isRunning = inferenceStatus == InferenceStatus.running;

        // Show progress indicator if running
        if (isRunning) {
          // Show only the animation, no text
          return Center(
            child: AiRunningAnimationWrapper(
              entryId: widget.entityId,
              height: 50,
              responseTypes: {promptConfig.aiResponseType},
            ),
          );
        }

        // If there's an error, show error modal (no _hideError check)
        if (isError) {
          try {
            final inferenceError = AiErrorUtils.categorizeError(state);

            // Debug logging
            developer.log(
              'Error detected: "${inferenceError.message}"',
              name: 'UnifiedAiProgressContent',
            );

            // Check for model not installed error
            String? modelNameToInstall;

            // First, try the reliable typed exception
            if (inferenceError.originalError is ModelNotInstalledException) {
              final modelNotInstalledError =
                  inferenceError.originalError as ModelNotInstalledException;
              modelNameToInstall = modelNotInstalledError.modelName;
            }
            // Fallback to string matching if the typed exception isn't present
            else if (inferenceError.message.isNotEmpty) {
              // The message format is expected to be: 'Model "modelName" is not installed. Please install it first.'
              // A case-insensitive regex is used for robustness.
              final modelNameMatch =
                  _modelNotInstalledRegex.firstMatch(inferenceError.message);
              // Only proceed if we could successfully extract the model name.
              modelNameToInstall = modelNameMatch?.group(1);
            }

            if (modelNameToInstall != null) {
              // Pass a callback to re-trigger inference and re-show progress modal sheet after install
              return OllamaModelInstallDialog(
                modelName: modelNameToInstall,
                onModelInstalled: () async {
                  try {
                    // Check if widget is still mounted before proceeding
                    if (!mounted) return;

                    // Invalidate the provider to re-trigger inference
                    ref.invalidate(
                      unifiedAiControllerProvider(
                        entityId: widget.entityId,
                        promptId: widget.promptId,
                      ),
                    );

                    // Re-show the progress modal sheet so the user sees the waveform indicator in the correct context
                    final prompt = await ref.read(
                      aiConfigByIdProvider(widget.promptId).future,
                    );

                    // Double-check mounted state after async operation
                    if (!mounted || !context.mounted) return;

                    if (prompt is AiConfigPrompt) {
                      await ModalUtils.showSingleSliverPageModal<void>(
                        context: context,
                        builder: (ctx) => UnifiedAiProgressUtils.progressPage(
                          context: ctx,
                          prompt: prompt,
                          entityId: widget.entityId,
                          onTapBack: () => Navigator.of(ctx).pop(),
                        ),
                      );
                    }
                  } catch (e, stack) {
                    developer.log(
                      'Error in onModelInstalled callback: $e',
                      name: 'UnifiedAiProgressContent',
                      error: e,
                      stackTrace: stack,
                    );
                    // Don't re-throw - this is a callback error that shouldn't crash the app
                  }
                },
              );
            }

            return AiErrorDisplay(
              error: inferenceError,
              onRetry: _handleRetry,
            );
          } catch (e, stack) {
            developer.log(
              'Exception in AiErrorUtils.categorizeError: $e',
              name: 'UnifiedAiProgressContent',
              error: e,
              stackTrace: stack,
            );
            // Show a generic error UI to the user
            return AiErrorDisplay(
              error: InferenceError(
                message:
                    'An unexpected error occurred while processing the AI response.',
                type: InferenceErrorType.unknown,
                originalError: e,
              ),
              onRetry: _handleRetry,
            );
          }
        }

        // Default: show the state (result or idle)
        final textStyle = monospaceTextStyleSmall.copyWith(
          fontWeight: FontWeight.w300,
        );
        return Padding(
          padding: const EdgeInsets.only(
            top: 10,
            bottom: 55,
            left: 20,
            right: 20,
          ),
          child: Container(
            constraints: const BoxConstraints(minWidth: 600),
            padding: const EdgeInsets.only(top: 20),
            child: Text(
              state,
              style: textStyle,
            ),
          ),
        );
      },
    );
  }
}

class UnifiedAiProgressUtils {
  static SliverWoltModalSheetPage progressPage({
    required BuildContext context,
    required AiConfigPrompt prompt,
    required String entityId,
    VoidCallback? onTapBack,
    ScrollController? scrollController,
  }) {
    return ModalUtils.sliverModalSheetPage(
      context: context,
      title: prompt.name,
      onTapBack: onTapBack,
      scrollController: scrollController,
      stickyActionBar: Align(
        alignment: Alignment.bottomCenter,
        child: AiRunningAnimationWrapper(
          entryId: entityId,
          height: 50,
          responseTypes: {prompt.aiResponseType},
        ),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: UnifiedAiProgressContent(
            entityId: entityId,
            promptId: prompt.id,
          ),
        ),
      ],
    );
  }
}

class OllamaModelInstallDialog extends ConsumerStatefulWidget {
  const OllamaModelInstallDialog({
    required this.modelName,
    this.onModelInstalled,
    super.key,
  });

  final String modelName;
  final VoidCallback? onModelInstalled;

  @override
  ConsumerState<OllamaModelInstallDialog> createState() =>
      OllamaModelInstallDialogState();
}

class OllamaModelInstallDialogState
    extends ConsumerState<OllamaModelInstallDialog> {
  bool _isInstalling = false;
  String _status = '';
  double _progress = 0;
  String? _error;

  Future<void> _installModel() async {
    setState(() {
      _isInstalling = true;
      _error = null;
    });

    try {
      // Get the provider configuration to find the Ollama base URL
      final providers = await ref.read(aiConfigByTypeControllerProvider(
              configType: AiConfigType.inferenceProvider)
          .future);
      final ollamaProvider = providers
          .whereType<AiConfigInferenceProvider>()
          .where((AiConfigInferenceProvider p) =>
              p.inferenceProviderType == InferenceProviderType.ollama)
          .firstOrNull;

      if (ollamaProvider == null) {
        throw Exception(
            'Ollama provider not found. Please configure Ollama in settings.');
      }

      final cloudRepo = ref.read(cloudInferenceRepositoryProvider);

      // Start the installation stream
      await for (final progress
          in cloudRepo.installModel(widget.modelName, ollamaProvider.baseUrl)) {
        setState(() {
          _status = progress.status;
          _progress = progress.progress;
        });
      }

      // Installation completed successfully
      if (mounted) {
        Navigator.of(context).pop();
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Model "${widget.modelName}" installed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Call the callback if provided
        widget.onModelInstalled?.call();
      }
    } catch (e) {
      developer.log(
        'Model installation error: $e',
        name: '_OllamaModelInstallDialogState',
      );

      // The repository provides user-friendly error messages.
      // We can use them directly instead of parsing the error string.
      var errorMessage = e.toString();
      // The repository provides user-friendly error messages.
      // We can use them directly instead of parsing the error string.
      if (e is Exception) {
        errorMessage = errorMessage.replaceFirst('Exception: ', '');
      }

      setState(() {
        _error = errorMessage;
        _isInstalling = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final command = 'ollama pull ${widget.modelName}';

    developer.log(
      'Building OllamaModelInstallDialog for model: ${widget.modelName}',
      name: '_OllamaModelInstallDialogState',
    );

    return AlertDialog(
      title: const Text('Model Not Installed'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('The model "${widget.modelName}" is not installed.'),
          const SizedBox(height: 12),
          if (!_isInstalling) ...[
            const Text('To install it, run this command in your terminal:'),
            const SizedBox(height: 8),
            SelectableText(command,
                style: const TextStyle(fontFamily: 'monospace')),
            const SizedBox(height: 16),
            const Text('Would you like to install it now from Lotti?'),
          ] else ...[
            const Text('Installing model...'),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _progress,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 8),
            Text(_status, style: Theme.of(context).textTheme.bodySmall),
            if (_progress > 0) ...[
              const SizedBox(height: 4),
              Text('${(_progress * 100).toStringAsFixed(1)}%'),
            ],
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              'Error: $_error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        if (!_isInstalling) ...[
          LottiTertiaryButton(
            onPressed: () => Navigator.of(context).pop(),
            label: context.messages.cancelButton,
          ),
          ElevatedButton(
            onPressed: _installModel,
            child: const Text('Install'),
          ),
        ] else ...[
          if (_error != null)
            ElevatedButton(
              onPressed: _installModel,
              child: const Text('Retry'),
            ),
        ],
      ],
    );
  }
}
