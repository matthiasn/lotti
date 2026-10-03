import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

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
        if (!mounted) return;
        setState(() {
          _error = context.messages.aiOllamaProviderMissing;
          _isInstalling = false;
        });
        return;
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

      // The repository provides user-friendly error messages, so they are
      // shown directly instead of being parsed.
      var errorMessage = e.toString();
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

    final tokens = context.designTokens;
    final colors = tokens.colors;
    final styles = tokens.typography.styles;
    final messages = context.messages;

    return AlertDialog(
      title: Text(messages.aiOllamaModelNotInstalledTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(messages.aiOllamaModelNotInstalledMessage(widget.modelName)),
          SizedBox(height: tokens.spacing.step4),
          if (!_isInstalling) ...[
            Text(messages.aiOllamaInstallCommandHint),
            SizedBox(height: tokens.spacing.step3),
            SelectableText(
              command,
              style: monoMetaStyle(
                tokens,
                colors,
                base: styles.body.bodyMedium,
                color: colors.text.highEmphasis,
              ),
            ),
            SizedBox(height: tokens.spacing.step5),
            Text(messages.aiOllamaInstallQuestion),
          ] else ...[
            Text(messages.aiOllamaInstalling),
            SizedBox(height: tokens.spacing.step4),
            LinearProgressIndicator(
              value: _progress,
              borderRadius: BorderRadius.circular(tokens.radii.s),
            ),
            SizedBox(height: tokens.spacing.step3),
            Text(
              _status,
              style: styles.body.bodySmall.copyWith(
                color: colors.text.mediumEmphasis,
              ),
            ),
            if (_progress > 0) ...[
              SizedBox(height: tokens.spacing.step2),
              Text('${(_progress * 100).toStringAsFixed(1)}%'),
            ],
          ],
          if (_error != null) ...[
            SizedBox(height: tokens.spacing.step4),
            Text(
              messages.aiOllamaInstallFailed(_error!),
              style: styles.body.bodySmall.copyWith(
                color: colors.alert.error.defaultColor,
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (!_isInstalling) ...[
          DesignSystemButton(
            label: messages.cancelButton,
            onPressed: () => Navigator.of(context).pop(),
            variant: DesignSystemButtonVariant.quiet,
            size: DesignSystemButtonSize.large,
          ),
          // After a failure this is the retry: the error shows above it.
          DesignSystemButton(
            label: messages.aiOllamaInstallButton,
            onPressed: _installModel,
            size: DesignSystemButtonSize.large,
          ),
        ],
      ],
    );
  }
}
