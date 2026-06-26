import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

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
      final providers = await ref.read(
        aiConfigByTypeControllerProvider(AiConfigType.inferenceProvider).future,
      );
      final ollamaProvider = providers
          .whereType<AiConfigInferenceProvider>()
          .where(
            (AiConfigInferenceProvider p) =>
                p.inferenceProviderType == InferenceProviderType.ollama,
          )
          .firstOrNull;

      if (ollamaProvider == null) {
        throw Exception(
          'Ollama provider not found. Please configure Ollama in settings.',
        );
      }

      final cloudRepo = ref.read(cloudInferenceRepositoryProvider);

      // Start the installation stream
      await for (final progress in cloudRepo.installModel(
        widget.modelName,
        ollamaProvider.baseUrl,
      )) {
        setState(() {
          _status = progress.status;
          _progress = progress.progress;
        });
      }

      if (mounted) {
        // Show the toast via the parent messenger *before* popping — the
        // dialog's context is detached once pop runs.
        context.showToast(
          tone: DesignSystemToastTone.success,
          title: context.messages.aiOllamaModelInstalledSuccessfully(
            widget.modelName,
          ),
        );
        Navigator.of(context).pop();
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
            SelectableText(
              command,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
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
          DesignSystemButton(
            label: context.messages.cancelButton,
            onPressed: () => Navigator.of(context).pop(),
            variant: DesignSystemButtonVariant.tertiary,
            size: DesignSystemButtonSize.large,
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
