import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/gemma3n_inference_repository.dart';
import 'package:lotti/features/ai/repository/ollama_inference_repository.dart';
import 'package:lotti/features/ai/state/active_inference_controller.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/ai/ui/animation/ai_running_animation.dart';
import 'package:lotti/features/ai/ui/gemma_model_install_dialog.dart';
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
    this.showExisting = false,
    super.key,
  });

  final String entityId;
  final String promptId;
  final bool showExisting;

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
    // Trigger a new inference run
    ref.read(
      triggerNewInferenceProvider(
        entityId: widget.entityId,
        promptId: widget.promptId,
      ).future,
    );
  }

  bool _hasTriggeredInference = false;
  StreamSubscription<String>? _progressSubscription;
  String _streamProgress = '';

  @override
  void initState() {
    super.initState();
    // Only trigger inference if not showing existing
    if (!widget.showExisting) {
      // Trigger inference after first frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_hasTriggeredInference) {
          _hasTriggeredInference = true;
          ref.read(
            triggerNewInferenceProvider(
              entityId: widget.entityId,
              promptId: widget.promptId,
            ).future,
          );
        }
      });
    } else {
      // If showing existing, subscribe to the progress stream
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _subscribeToExistingInference();
      });
    }
  }

  Future<void> _subscribeToExistingInference() async {
    // Get the prompt config to find the right response type
    final config = await ref.read(
      aiConfigByIdProvider(widget.promptId).future,
    );

    if (config != null && config is AiConfigPrompt) {
      final activeInference = ref.read(
        activeInferenceControllerProvider(
          entityId: widget.entityId,
          aiResponseType: config.aiResponseType,
        ),
      );

      if (activeInference != null) {
        // Subscribe to the progress stream
        _progressSubscription =
            activeInference.progressStream.listen((progress) {
          if (mounted) {
            setState(() {
              _streamProgress = progress;
            });
          }
        });

        // Set initial progress
        setState(() {
          _streamProgress = activeInference.progressText;
        });
      }
    }
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }

  /// Helper method for handling model installation completion
  /// Triggers new inference and shows progress modal
  Future<void> _handleModelInstalled(String providerType) async {
    try {
      // Check if widget is still mounted before proceeding
      if (!mounted) return;

      // Trigger a new inference run
      await ref.read(
        triggerNewInferenceProvider(
          entityId: widget.entityId,
          promptId: widget.promptId,
        ).future,
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
        'Error in $providerType onModelInstalled callback: $e',
        name: 'UnifiedAiProgressContent',
        error: e,
        stackTrace: stack,
      );
      // Don't re-throw - this is a callback error that shouldn't crash the app
    }
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

        // Use stream progress if showing existing, otherwise use controller state
        final controllerState = widget.showExisting
            ? null
            : ref.watch(
                unifiedAiControllerProvider(
                  entityId: widget.entityId,
                  promptId: widget.promptId,
                ),
              );

        final state = widget.showExisting
            ? _streamProgress
            : controllerState?.message ?? '';

        final inferenceStatus = ref.watch(
          inferenceStatusControllerProvider(
            id: widget.entityId,
            aiResponseType: promptConfig.aiResponseType,
          ),
        );

        final isError = inferenceStatus == InferenceStatus.error;
        final isRunning = inferenceStatus == InferenceStatus.running;

        // Show progress indicator if running
        if (isRunning && state.isEmpty) {
          // Show only the animation when no progress text yet
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
          // Debug logging
          developer.log(
            'Error detected, showExisting: ${widget.showExisting}, controllerState: $controllerState, error: ${controllerState?.error}, type: ${controllerState?.error.runtimeType}',
            name: 'UnifiedAiProgressContent',
          );

          // Check for model not installed error directly from controller state
          // For showExisting mode, we need to get the controller state explicitly
          final actualControllerState = widget.showExisting
              ? ref.read(
                  unifiedAiControllerProvider(
                    entityId: widget.entityId,
                    promptId: widget.promptId,
                  ),
                )
              : controllerState;

          developer.log(
            'actualControllerState: $actualControllerState, error: ${actualControllerState?.error}, type: ${actualControllerState?.error.runtimeType}',
            name: 'UnifiedAiProgressContent',
          );

          // Check for model installation errors (both Ollama and Gemma)
          final error = actualControllerState?.error;
          if (error is ModelNotInstalledException ||
              error is ModelNotAvailableException) {
            final modelName = error is ModelNotInstalledException
                ? error.modelName
                : (error as ModelNotAvailableException?)?.modelName ??
                    'unknown';

            developer.log(
              '${error.runtimeType} detected for model: $modelName',
              name: 'UnifiedAiProgressContent',
            );

            // Determine if it's a Gemma model by checking provider configuration
            // Use FutureBuilder to handle async provider lookup
            return FutureBuilder<List<AiConfig>>(
              future: ref.read(aiConfigByTypeControllerProvider(
                      configType: AiConfigType.inferenceProvider)
                  .future),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final providers = snapshot.data!;
                final gemmaProvider = providers
                    .whereType<AiConfigInferenceProvider>()
                    .where((AiConfigInferenceProvider p) =>
                        p.inferenceProviderType ==
                        InferenceProviderType.gemma3n)
                    .firstOrNull;

                final isGemmaModel = gemmaProvider != null;

                if (isGemmaModel) {
                  developer.log(
                    'Showing GemmaModelInstallDialog for model: $modelName',
                    name: 'UnifiedAiProgressContent',
                  );

                  return GemmaModelInstallDialog(
                    modelName: modelName,
                    onModelInstalled: () => _handleModelInstalled('Gemma'),
                  );
                } else {
                  // It's an Ollama model
                  developer.log(
                    'Showing OllamaModelInstallDialog for model: $modelName',
                    name: 'UnifiedAiProgressContent',
                  );

                  return OllamaModelInstallDialog(
                    modelName: modelName,
                    onModelInstalled: () => _handleModelInstalled('Ollama'),
                  );
                }
              },
            );
          }

          // Now categorize for other error types
          final inferenceError = actualControllerState?.error != null
              ? AiErrorUtils.categorizeError(actualControllerState!.error)
              : AiErrorUtils.categorizeError(state);

          // Fallback to string matching if the typed exception isn't present (backward compatibility)
          if (inferenceError.message.isNotEmpty) {
            // The message format is expected to be: 'Model "modelName" is not installed. Please install it first.'
            // A case-insensitive regex is used for robustness.
            final modelNameMatch =
                _modelNotInstalledRegex.firstMatch(inferenceError.message);

            // Only proceed if we could successfully extract the model name.
            final modelNameToInstall = modelNameMatch?.group(1);

            if (modelNameToInstall != null) {
              // Pass a callback to re-trigger inference and re-show progress modal sheet after install
              return OllamaModelInstallDialog(
                modelName: modelNameToInstall,
                onModelInstalled: () async {
                  try {
                    // Check if widget is still mounted before proceeding
                    if (!mounted) return;

                    // Trigger a new inference run
                    await ref.read(
                      triggerNewInferenceProvider(
                        entityId: widget.entityId,
                        promptId: widget.promptId,
                      ).future,
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
          }

          // Default error display
          return AiErrorDisplay(
            error: inferenceError,
            onRetry: _handleRetry,
          );
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
    bool showExisting = false,
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
            showExisting: showExisting,
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
