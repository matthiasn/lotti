import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/util/mlx_audio_channel.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Lets the user pick which MLX Audio speech-to-text model to install first.
class MlxAudioModelInstallChoiceDialog extends StatefulWidget {
  const MlxAudioModelInstallChoiceDialog({
    required this.models,
    required this.recommendedModelId,
    super.key,
  });

  final List<AiConfigModel> models;
  final String recommendedModelId;

  static Future<AiConfigModel?> show({
    required BuildContext context,
    required List<AiConfigModel> models,
    required String recommendedModelId,
  }) {
    return ModalUtils.showSinglePageModal<AiConfigModel>(
      context: context,
      title: context.messages.aiModelInstallChoiceTitle,
      builder: (_) => MlxAudioModelInstallChoiceDialog(
        models: models,
        recommendedModelId: recommendedModelId,
      ),
    );
  }

  @override
  State<MlxAudioModelInstallChoiceDialog> createState() =>
      _MlxAudioModelInstallChoiceDialogState();
}

class _MlxAudioModelInstallChoiceDialogState
    extends State<MlxAudioModelInstallChoiceDialog> {
  late List<AiConfigModel> _orderedModels;
  late Map<String, AiConfigModel> _modelsById;
  String? _selectedModelId;

  @override
  void initState() {
    super.initState();
    _rebuildIndexes();
    _selectedModelId = _initialModelId;
  }

  @override
  void didUpdateWidget(covariant MlxAudioModelInstallChoiceDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.models, oldWidget.models) ||
        widget.recommendedModelId != oldWidget.recommendedModelId) {
      _rebuildIndexes();
      if (_selectedModelId == null ||
          !_modelsById.containsKey(_selectedModelId)) {
        _selectedModelId = _initialModelId;
      }
    }
  }

  void _rebuildIndexes() {
    final recommended = <AiConfigModel>[];
    final others = <AiConfigModel>[];
    final byId = <String, AiConfigModel>{};

    for (final model in widget.models) {
      byId[model.providerModelId] = model;
      if (model.providerModelId == widget.recommendedModelId) {
        recommended.add(model);
      } else {
        others.add(model);
      }
    }

    _orderedModels = [...recommended, ...others];
    _modelsById = byId;
  }

  String? get _initialModelId {
    if (widget.models.isEmpty) return null;
    if (_modelsById.containsKey(widget.recommendedModelId)) {
      return widget.recommendedModelId;
    }
    return widget.models.first.providerModelId;
  }

  AiConfigModel? get _selectedModel {
    final selectedModelId = _selectedModelId;
    if (selectedModelId == null) return null;
    return _modelsById[selectedModelId];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final models = _orderedModels;
    final lastModelId = models.isEmpty ? null : models.last.providerModelId;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          messages.aiModelInstallChoiceDescription,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step4),
        RadioGroup<String>(
          groupValue: _selectedModelId,
          onChanged: (value) => setState(() => _selectedModelId = value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final model in models) ...[
                RadioListTile<String>(
                  value: model.providerModelId,
                  contentPadding: EdgeInsets.zero,
                  title: _MlxAudioModelChoiceTitle(
                    model: model,
                    recommendedModelId: widget.recommendedModelId,
                  ),
                  subtitle: model.description == null
                      ? null
                      : Text(
                          model.description!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.typography.styles.others.caption
                              .copyWith(
                                color: tokens.colors.text.mediumEmphasis,
                              ),
                        ),
                ),
                if (model.providerModelId != lastModelId)
                  SizedBox(height: tokens.spacing.step2),
              ],
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.step5),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            DesignSystemButton(
              label: messages.aiModelInstallChoiceCancelButton,
              variant: DesignSystemButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            SizedBox(width: tokens.spacing.step3),
            DesignSystemButton(
              label: messages.aiModelInstallChoiceInstallButton,
              onPressed: _selectedModel == null
                  ? null
                  : () => Navigator.of(context).pop(_selectedModel),
            ),
          ],
        ),
      ],
    );
  }
}

class _MlxAudioModelChoiceTitle extends StatelessWidget {
  const _MlxAudioModelChoiceTitle({
    required this.model,
    required this.recommendedModelId,
  });

  final AiConfigModel model;
  final String recommendedModelId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isRecommended = model.providerModelId == recommendedModelId;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: tokens.spacing.step2,
      runSpacing: tokens.spacing.step1,
      children: [
        Text(
          model.name,
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: tokens.colors.text.highEmphasis,
            fontWeight: tokens.typography.weight.semiBold,
          ),
        ),
        if (isRecommended)
          DesignSystemBadge.outlined(
            label: context.messages.aiModelInstallChoiceRecommended,
            tone: DesignSystemBadgeTone.success,
          ),
      ],
    );
  }
}

/// Starts and tracks an MLX Audio model download.
///
/// The download itself is owned by Swift so Hugging Face progress comes from
/// the same cache path that inference later uses. This dialog only starts the
/// native task and reflects the shared [mlxAudioModelProgressProvider] stream.
class MlxAudioModelDownloadDialog extends ConsumerStatefulWidget {
  const MlxAudioModelDownloadDialog({required this.model, super.key});

  final AiConfigModel model;

  static Future<void> show({
    required BuildContext context,
    required AiConfigModel model,
  }) {
    return ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.aiModelDownloadDialogTitle(model.name),
      builder: (_) => MlxAudioModelDownloadDialog(model: model),
    );
  }

  @override
  ConsumerState<MlxAudioModelDownloadDialog> createState() =>
      _MlxAudioModelDownloadDialogState();
}

class _MlxAudioModelDownloadDialogState
    extends ConsumerState<MlxAudioModelDownloadDialog> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startDownload());
  }

  Future<void> _startDownload() async {
    if (_started || !mounted) return;
    _started = true;
    final current = ref.read(
      mlxAudioModelProgressProvider(widget.model.providerModelId),
    );
    if (current?.status == MlxAudioModelStatus.downloading ||
        current?.status == MlxAudioModelStatus.installed) {
      return;
    }
    try {
      await ref
          .read(mlxAudioModelProgressStoreProvider.notifier)
          .installModel(widget.model.providerModelId);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'mlx_audio_model_download_dialog',
          context: ErrorDescription(
            'while starting MLX Audio model download',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final progress = ref.watch(
      mlxAudioModelProgressProvider(widget.model.providerModelId),
    );
    final progressValue = _progressIndicatorValue(progress);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          messages.aiModelDownloadDialogDescription(widget.model.name),
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step5),
        LinearProgressIndicator(
          value: progressValue,
        ),
        SizedBox(height: tokens.spacing.step3),
        Text(
          _statusLabel(context, progress),
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step5),
        Align(
          alignment: Alignment.centerRight,
          child: DesignSystemButton(
            label: messages.aiModelDownloadCloseButton,
            variant: DesignSystemButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  String _statusLabel(
    BuildContext context,
    MlxAudioModelDownloadProgress? progress,
  ) {
    final messages = context.messages;
    if (progress == null) return messages.aiModelDownloadStatusChecking;
    if (progress.status == MlxAudioModelStatus.downloading) {
      final percentComplete = progress.percentComplete;
      if (percentComplete == null) {
        return messages.aiModelDownloadStatusDownloadingIndeterminate;
      }
      return messages.aiModelDownloadStatusDownloading(percentComplete);
    }

    return switch (progress.status) {
      MlxAudioModelStatus.installed => messages.aiModelDownloadStatusInstalled,
      MlxAudioModelStatus.notInstalled =>
        messages.aiModelDownloadStatusNotInstalled,
      MlxAudioModelStatus.downloading =>
        messages.aiModelDownloadStatusDownloadingIndeterminate,
      MlxAudioModelStatus.failed =>
        progress.message ?? messages.aiModelDownloadStatusFailed,
      MlxAudioModelStatus.unsupported =>
        messages.aiModelDownloadStatusUnsupported,
    };
  }

  double? _progressIndicatorValue(MlxAudioModelDownloadProgress? progress) {
    if (progress == null) return null;

    return switch (progress.status) {
      MlxAudioModelStatus.downloading => progress.normalizedProgress,
      MlxAudioModelStatus.installed => 1,
      MlxAudioModelStatus.notInstalled ||
      MlxAudioModelStatus.failed ||
      MlxAudioModelStatus.unsupported => 0,
    };
  }
}
