import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/speech/sherpa_installed_models_provider.dart';
import 'package:lotti/features/ai/speech/sherpa_model_repository.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/services/sync_node_profile_broadcaster.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Explicit device-local downloads, separate from synced model configurations.
class SherpaModelsSection extends StatelessWidget {
  const SherpaModelsSection({required this.providerId, super.key});

  final String providerId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.messages.sherpaProviderDescription),
        for (final model in sherpaModels)
          Padding(
            padding: EdgeInsets.only(top: tokens.spacing.step4),
            child: _ModelDownload(model: model, providerId: providerId),
          ),
      ],
    );
  }
}

class _ModelDownload extends ConsumerStatefulWidget {
  const _ModelDownload({required this.model, required this.providerId});

  final SherpaModel model;
  final String providerId;

  @override
  ConsumerState<_ModelDownload> createState() => _ModelDownloadState();
}

class _ModelDownloadState extends ConsumerState<_ModelDownload> {
  late Future<bool> _installed;
  double? _progress;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _installed = ref
        .read(sherpaModelRepositoryProvider)
        .isInstalled(widget.model.id);
  }

  Future<void> _download() async {
    if (_progress != null) return;
    final models = ref.read(sherpaModelRepositoryProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    final configs = ref.read(aiConfigRepositoryProvider);
    setState(() {
      _progress = 0;
      _failed = false;
    });
    try {
      await models.install(
        widget.model.id,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      await _modelsChanged(container);
      // A synced row may already exist. Re-create only a missing/deleted row,
      // so downloading does not rewrite its profile references or user edits.
      final existing = await configs.getConfigsByType(AiConfigType.model);
      if (!existing.whereType<AiConfigModel>().any(
        (model) =>
            model.inferenceProviderId == widget.providerId &&
            model.providerModelId == widget.model.id,
      )) {
        final known = sherpaSpeechModels.firstWhere(
          (model) => model.providerModelId == widget.model.id,
        );
        await configs.saveConfig(
          known.toAiConfigModel(
            id: generateModelId(
              widget.providerId,
              widget.model.id,
            ),
            inferenceProviderId: widget.providerId,
          ),
        );
      }
      if (mounted) {
        setState(() {
          _installed = Future.value(true);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  Future<void> _modelsChanged(ProviderContainer container) async {
    try {
      container.invalidate(sherpaInstalledModelIdsProvider);
      await getIt<SyncNodeProfileBroadcaster>().broadcastIfChanged();
    } catch (error, stackTrace) {
      // A sync failure does not undo a successful local file operation.
      developer.log(
        'Failed to advertise updated speech capability',
        name: 'SherpaModelsSection',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _remove() async {
    final models = ref.read(sherpaModelRepositoryProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() {
      _progress = 0;
      _failed = false;
    });
    try {
      await models.remove(widget.model.id);
      await _modelsChanged(container);
      if (mounted) {
        setState(() {
          _installed = Future.value(false);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return FutureBuilder<bool>(
      future: _installed,
      builder: (context, snapshot) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.model.name,
            style: tokens.typography.styles.subtitle.subtitle2,
          ),
          SizedBox(height: tokens.spacing.step3),
          if (_progress != null)
            LinearProgressIndicator(value: _progress)
          else if (snapshot.connectionState == ConnectionState.waiting)
            const LinearProgressIndicator()
          else if (snapshot.data ?? false)
            Wrap(
              spacing: tokens.spacing.step3,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(messages.sherpaModelInstalled),
                DesignSystemButton(
                  label: messages.sherpaDeleteModel,
                  onPressed: _remove,
                ),
              ],
            )
          else
            DesignSystemButton(
              label: messages.sherpaDownloadModel(
                (widget.model.bytes / 1000000).ceil().toString(),
              ),
              onPressed: _download,
            ),
          if (_failed || snapshot.hasError)
            Text(
              messages.sherpaModelError,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.alert.error.ink,
              ),
            ),
        ],
      ),
    );
  }
}
