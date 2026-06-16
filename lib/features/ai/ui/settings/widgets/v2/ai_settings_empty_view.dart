import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// FTUE re-entry banner shown at the top of the AI Settings page when
/// there are zero providers configured.
///
/// Layout from `/Desktop/ai-settings-images/D1 _ Tabs _ empty state _FTUE re-entry banner _ provider quick-add_.png`:
///
/// ```text
/// ┌────────────────────────────────────────────────────────────┐
/// │ [✨]  Add your first AI provider           [ Start setup → ] │
/// │      Takes about a minute. Lotti will set up models …      │
/// └────────────────────────────────────────────────────────────┘
/// ```
///
/// Standalone widget — the page is responsible for positioning it
/// between the page header and the tab row.
class AiSettingsFtueBanner extends StatelessWidget {
  const AiSettingsFtueBanner({required this.onStartSetup, super.key});

  final VoidCallback onStartSetup;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final accent = tokens.colors.interactive.enabled;
    return Container(
      padding: EdgeInsets.all(tokens.spacing.step4),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
      ),
      child: Row(
        children: [
          Container(
            width: tokens.spacing.step8,
            height: tokens.spacing.step8,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(tokens.radii.s),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: tokens.spacing.step5,
              color: accent,
            ),
          ),
          SizedBox(width: tokens.spacing.step4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  messages.aiSettingsFtueBannerTitle,
                  style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                    color: tokens.colors.text.highEmphasis,
                    fontWeight: tokens.typography.weight.semiBold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: tokens.spacing.step1),
                Text(
                  messages.aiSettingsFtueBannerDescription,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: tokens.spacing.step4),
          DesignSystemButton(
            label: messages.aiSettingsFtueBannerStartButton,
            onPressed: onStartSetup,
          ),
        ],
      ),
    );
  }
}

/// Single wrapper card shown in the AI Settings page body when there
/// are zero providers configured.
///
/// Layout from `/Desktop/ai-settings-images/D1 _ Tabs _ empty state _FTUE re-entry banner _ provider quick-add_.png`:
///
/// ```text
/// ┌──────────────────────────────────────────────────────────────┐
/// │                       No providers yet                        │
/// │      Add one to unlock transcription, image recognition,      │
/// │            image generation, and semantic search.             │
/// │                                                               │
/// │ [Gemini] [OpenAI] [Anthropic] [Alibaba] [mlxAudio] [Ollama] │
/// └──────────────────────────────────────────────────────────────┘
/// ```
///
/// One row of five compact provider chips inside a single wrapper —
/// NOT a grid of large tiles. Each chip taps into
/// `InferenceProviderEditPage(preselectedType: ...)` so the user lands
/// on the connect form with one tap. Mistral is reachable from the
/// page-level "+ Add provider" button.
class AiSettingsNoProvidersCard extends StatelessWidget {
  const AiSettingsNoProvidersCard({
    required this.onProviderChipTap,
    super.key,
  });

  final void Function(InferenceProviderType type) onProviderChipTap;

  static const _chipProviders = <InferenceProviderType>[
    InferenceProviderType.gemini,
    InferenceProviderType.openAi,
    InferenceProviderType.anthropic,
    InferenceProviderType.alibaba,
    InferenceProviderType.mlxAudio,
    InferenceProviderType.ollama,
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step5,
        vertical: tokens.spacing.step7,
      ),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            messages.aiSettingsEmptyTitle,
            style: tokens.typography.styles.subtitle.subtitle1.copyWith(
              color: tokens.colors.text.highEmphasis,
              fontWeight: tokens.typography.weight.semiBold,
            ),
          ),
          SizedBox(height: tokens.spacing.step2),
          Text(
            messages.aiSettingsEmptyDescription,
            textAlign: TextAlign.center,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step5),
          // Wrap so the five chips fold to a second row on tight
          // viewports rather than overflowing. On the desktop pane
          // they fit on one line at the design's measured widths.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: tokens.spacing.step3,
            runSpacing: tokens.spacing.step3,
            children: [
              for (final type in _chipProviders)
                _ProviderChip(
                  type: type,
                  onTap: () => onProviderChipTap(type),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact provider chip: small colored icon square + provider name,
/// inline. Used by the empty state's "No providers yet" card.
class _ProviderChip extends StatelessWidget {
  const _ProviderChip({required this.type, required this.onTap});

  final InferenceProviderType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final visual = aiProviderVisual(
      type: type,
      tokens: tokens,
      messages: messages,
    );
    final radius = BorderRadius.circular(tokens.radii.s);
    return Material(
      color: tokens.colors.background.level03,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step3,
            vertical: tokens.spacing.step2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: tokens.spacing.step5,
                height: tokens.spacing.step5,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: visual.surface,
                  borderRadius: BorderRadius.circular(tokens.radii.xs),
                ),
                child: Icon(
                  aiProviderIcon(type),
                  size: tokens.spacing.step4,
                  color: visual.accent,
                ),
              ),
              SizedBox(width: tokens.spacing.step2),
              Text(
                visual.displayName,
                style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
