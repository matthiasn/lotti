import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_card_action_menu.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_settings_cards.dart';
import 'package:lotti/features/ai/util/mlx_audio_channel.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Single-row card for the redesigned Models tab.
///
/// Shows the provider-tinted icon tile, the model name + monospace
/// `providerModelId`, and a wrapping row of capability chips (reasoning /
/// modality labels). For [InferenceProviderType.mlxAudio] models it also
/// renders a download-status badge and an install / open-progress action.
/// Tapping the card runs [onTap]; the trailing `⋯` exposes [menuActions]
/// (hidden when empty). See the ASCII layout sketch at the foot of
/// `ai_provider_card.dart`.
class AiModelCard extends StatelessWidget {
  const AiModelCard({
    required this.model,
    required this.providerType,
    required this.onTap,
    this.menuActions = const [],
    this.modelDownloadProgress,
    this.onInstallModel,
    super.key,
  });

  final AiConfigModel model;

  /// Type of the inference provider that owns this model. Drives the
  /// leading icon color so a glance at the row says which provider
  /// the model belongs to without re-reading the id. Nullable because
  /// a row may render before its owning provider has resolved (or
  /// after the provider has been deleted) — the card renders neutral
  /// chrome in that case instead of impersonating Gemini.
  final InferenceProviderType? providerType;

  final VoidCallback onTap;
  final List<AiCardMenuAction> menuActions;
  final MlxAudioModelDownloadProgress? modelDownloadProgress;
  final VoidCallback? onInstallModel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final visual = aiProviderVisual(
      type: providerType,
      tokens: tokens,
      messages: messages,
    );
    final radius = BorderRadius.circular(tokens.radii.l);

    return Material(
      color: tokens.colors.background.level02,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        hoverColor: tokens.colors.surface.hover,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.step4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AiProviderIconTile(
                accent: visual.accent,
                surface: visual.surface,
                providerType: providerType,
                size: tokens.spacing.step7,
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                // Stack the model name, the mono provider-model id, and
                // the capability chips vertically — previously the name
                // and id sat inline on the first row which truncated
                // both on mobile widths. Vertical stack lets long names
                // and ids wrap to multiple lines instead of clipping.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.name,
                      style: tokens.typography.styles.subtitle.subtitle2
                          .copyWith(
                            color: tokens.colors.text.highEmphasis,
                            fontWeight: tokens.typography.weight.semiBold,
                          ),
                      softWrap: true,
                    ),
                    SizedBox(height: tokens.spacing.step1),
                    Text(
                      model.providerModelId,
                      style: monoMetaStyle(tokens, tokens.colors),
                      softWrap: true,
                    ),
                    SizedBox(height: tokens.spacing.step2),
                    _CapabilityChipRow(
                      labels: modelCapabilityLabels(
                        messages: messages,
                        isReasoning: model.isReasoningModel,
                        inputModalities: model.inputModalities,
                        outputModalities: model.outputModalities,
                      ),
                    ),
                    if (providerType == InferenceProviderType.mlxAudio) ...[
                      SizedBox(height: tokens.spacing.step2),
                      _ModelDownloadStatus(
                        progress: modelDownloadProgress,
                        onInstallModel: onInstallModel,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              AiCardActionMenuButton(actions: menuActions),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelDownloadStatus extends StatelessWidget {
  const _ModelDownloadStatus({
    required this.progress,
    required this.onInstallModel,
  });

  final MlxAudioModelDownloadProgress? progress;
  final VoidCallback? onInstallModel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final status = progress?.status;
    final percentComplete = progress?.percentComplete;
    final (label, tone) = switch (status) {
      MlxAudioModelStatus.installed => (
        messages.aiModelDownloadStatusInstalled,
        DesignSystemBadgeTone.success,
      ),
      MlxAudioModelStatus.downloading => (
        percentComplete == null
            ? messages.aiModelDownloadStatusDownloadingIndeterminate
            : messages.aiModelDownloadStatusDownloading(percentComplete),
        DesignSystemBadgeTone.primary,
      ),
      MlxAudioModelStatus.failed => (
        messages.aiModelDownloadStatusFailed,
        DesignSystemBadgeTone.warning,
      ),
      MlxAudioModelStatus.notInstalled => (
        messages.aiModelDownloadStatusNotInstalled,
        DesignSystemBadgeTone.secondary,
      ),
      MlxAudioModelStatus.unsupported => (
        messages.aiModelDownloadStatusUnsupported,
        DesignSystemBadgeTone.secondary,
      ),
      null => (
        messages.aiModelDownloadStatusChecking,
        DesignSystemBadgeTone.secondary,
      ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: DesignSystemBadge.outlined(label: label, tone: tone),
        ),
        if (_shouldShowProgressAction && onInstallModel != null) ...[
          SizedBox(width: tokens.spacing.step2),
          IconButton(
            icon: Icon(
              status == MlxAudioModelStatus.downloading
                  ? Icons.open_in_new_rounded
                  : Icons.download_rounded,
            ),
            tooltip: status == MlxAudioModelStatus.downloading
                ? messages.aiModelDownloadOpenProgressTooltip
                : messages.aiModelDownloadInstallTooltip,
            visualDensity: VisualDensity.compact,
            onPressed: onInstallModel,
          ),
        ],
      ],
    );
  }

  bool get _shouldShowProgressAction {
    return progress?.status == MlxAudioModelStatus.downloading ||
        (progress?.canInstall ?? false);
  }
}

class _CapabilityChipRow extends StatelessWidget {
  const _CapabilityChipRow({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    final tokens = context.designTokens;
    return Wrap(
      spacing: tokens.spacing.step2,
      runSpacing: tokens.spacing.step2,
      children: [
        for (final label in labels)
          DesignSystemBadge.filled(
            label: label,
            tone: DesignSystemBadgeTone.secondary,
          ),
      ],
    );
  }
}

/// 2-column grid card for the redesigned Profiles tab.
///
/// Layout from `/Desktop/ai-settings-images/D1 _ Tabs _ populated _ Profiles.png`:
///
/// ```text
/// ┌──────────────────────────────────────────────┐
/// │ [icon]  Profile Name  ACTIVE             ⋯  │
/// │         tagline                              │
/// │                                              │
/// │ ⇆ Transcription      →  Gemini 3 Flash      │
/// │ 🖼 Image recognition → Gemini 3 Flash       │
/// │ 🧠 Thinking          →  Gemini 3 Pro        │
/// │ 🎨 Image generation  →  Nano Banana Pro     │
/// └──────────────────────────────────────────────┘
/// ```
