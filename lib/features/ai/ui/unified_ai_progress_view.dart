import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/features/ai/ui/widgets/ai_error_display.dart';
import 'package:lotti/features/ai/util/ai_error_utils.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/modals.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

/// Progress view for unified AI inference
class UnifiedAiProgressContent extends ConsumerWidget {
  const UnifiedAiProgressContent({
    required this.entityId,
    required this.promptId,
    super.key,
  });

  final String entityId;
  final String promptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // First get the prompt config
    final promptConfigAsync = ref.watch(
      aiConfigByIdProvider(promptId),
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
            entityId: entityId,
            promptId: promptId,
          ),
        );

        final inferenceStatus = ref.watch(
          inferenceStatusControllerProvider(
            id: entityId,
            aiResponseType: promptConfig.aiResponseType,
          ),
        );

        final isError = inferenceStatus == InferenceStatus.error;

        // If there's an error, try to parse it as an InferenceError
        if (isError) {
          try {
            // Try to create an InferenceError from the state string
            final inferenceError = AiErrorUtils.categorizeError(state);

            // Debug logging
            developer.log(
              'Error detected: "${inferenceError.message}"',
              name: 'UnifiedAiProgressContent',
            );

            // Special handling for Ollama model not installed
            // Check if the error message contains the specific pattern for model not installed
            developer.log(
              'Checking conditions: isEmpty=${inferenceError.message.isEmpty}, contains "not installed"=${inferenceError.message.toLowerCase().contains("not installed")}, contains "model"=${inferenceError.message.toLowerCase().contains("model")}',
              name: 'UnifiedAiProgressContent',
            );

            // Check if this is a ModelNotInstalledException (most reliable)
            if (inferenceError.originalError is ModelNotInstalledException) {
              final modelNotInstalledError = inferenceError.originalError as ModelNotInstalledException;
              final modelName = modelNotInstalledError.modelName;

              developer.log(
                'Model not installed detected via typed exception: $modelName',
                name: 'UnifiedAiProgressContent',
              );

              developer.log(
                'Creating OllamaModelInstallDialog for model: $modelName',
                name: 'UnifiedAiProgressContent',
              );

              return OllamaModelInstallDialog(modelName: modelName);
            }

            // Fallback: Check if this is a model not found error via string matching
            if (inferenceError.message.isNotEmpty &&
                inferenceError.message
                    .toLowerCase()
                    .contains('not installed') &&
                inferenceError.message.toLowerCase().contains('model')) {
              // Extract model name from the error message
              // The message format is: 'Model "modelName" is not installed. Please install it first.'
              final modelNameMatch = RegExp('Model "([^"]+)" is not installed')
                  .firstMatch(inferenceError.message);
              final modelName = modelNameMatch?.group(1) ?? 'the model';

              developer.log(
                'Model not installed detected via string matching: $modelName',
                name: 'UnifiedAiProgressContent',
              );

              developer.log(
                'Creating OllamaModelInstallDialog for model: $modelName',
                name: 'UnifiedAiProgressContent',
              );

              return OllamaModelInstallDialog(modelName: modelName);
            }

            return AiErrorDisplay(
              error: inferenceError,
              onRetry: () {
                // Retry the inference
                ref.invalidate(
                  unifiedAiControllerProvider(
                    entityId: entityId,
                    promptId: promptId,
                  ),
                );
              },
            );
          } catch (e) {
            // If we can't parse it as InferenceError, try direct string matching
            developer.log(
              'Failed to parse error with AiErrorUtils, trying direct matching: $e',
              name: 'UnifiedAiProgressContent',
            );
          }

          // Direct string matching for ModelNotInstalledException (always try this as fallback)
          // The state might contain the full exception with stack trace, so we need to be more flexible
          if (state.toLowerCase().contains('not installed') &&
              state.toLowerCase().contains('model')) {
            // Try to extract the model name from the full error message
            final modelNameMatch =
                RegExp('Model "([^"]+)" is not installed').firstMatch(state);
            final modelName = modelNameMatch?.group(1) ?? 'the model';

            developer.log(
              'Model not installed detected via direct matching: $modelName',
              name: 'UnifiedAiProgressContent',
            );

            developer.log(
              'Creating OllamaModelInstallDialog for model: $modelName (direct matching)',
              name: 'UnifiedAiProgressContent',
            );

            return OllamaModelInstallDialog(modelName: modelName);
          }

          // If we still can't detect it, show the raw error
          developer.log(
            'Could not detect model not installed error, showing raw error',
            name: 'UnifiedAiProgressContent',
          );
        }

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
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 600),
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
  const UnifiedAiProgressUtils();

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
        )),
      ],
    );
  }
}

class OllamaModelInstallDialog extends ConsumerStatefulWidget {
  const OllamaModelInstallDialog({required this.modelName, super.key});

  final String modelName;

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
      }
    } catch (e) {
      developer.log(
        'Model installation error: $e',
        name: '_OllamaModelInstallDialogState',
      );
      setState(() {
        _error =
            'Installation failed. Please check your Ollama installation and try again.';
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
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
