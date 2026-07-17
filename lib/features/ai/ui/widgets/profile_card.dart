import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// A card widget displaying an inference profile's name and model slots.
///
/// Used both in the AI Settings profiles tab and the standalone
/// inference profile management page.
class ProfileCard extends StatelessWidget {
  const ProfileCard({
    required this.profile,
    required this.onTap,
    super.key,
  });

  /// The inference profile to display.
  final AiConfigInferenceProfile profile;

  /// Called when the card is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.m);

    return Card(
      elevation: 0,
      color: tokens.colors.background.level02,
      shape: RoundedRectangleBorder(borderRadius: radius),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      profile.name,
                      style: tokens.typography.styles.subtitle.subtitle2
                          .copyWith(
                            color: tokens.colors.text.highEmphasis,
                            fontWeight: tokens.typography.weight.semiBold,
                          ),
                    ),
                  ),
                  if (profile.desktopOnly) ...[
                    SizedBox(width: tokens.spacing.step2),
                    DesignSystemBadge.outlined(
                      label: context.messages.inferenceProfileDesktopOnly,
                      tone: DesignSystemBadgeTone.secondary,
                    ),
                  ],
                  if (profile.isDefault)
                    Padding(
                      padding: EdgeInsets.only(left: tokens.spacing.step3),
                      child: Icon(
                        Icons.lock_outline,
                        size: tokens.spacing.step5,
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                ],
              ),
              SizedBox(height: tokens.spacing.step3),
              ProfileSlotRow(
                label: context.messages.inferenceProfileThinking,
                modelId: profile.thinkingModelId,
              ),
              if (profile.imageRecognitionModelId != null)
                ProfileSlotRow(
                  label: context.messages.inferenceProfileImageRecognition,
                  modelId: profile.imageRecognitionModelId!,
                ),
              if (profile.transcriptionModelId != null)
                ProfileSlotRow(
                  label: context.messages.inferenceProfileTranscription,
                  modelId: profile.transcriptionModelId!,
                ),
              if (profile.imageGenerationModelId != null)
                ProfileSlotRow(
                  label: context.messages.inferenceProfileImageGeneration,
                  modelId: profile.imageGenerationModelId!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row displaying a model slot label and its model ID.
class ProfileSlotRow extends StatelessWidget {
  const ProfileSlotRow({required this.label, required this.modelId, super.key});

  /// The slot label (e.g. "Thinking").
  final String label;

  /// The provider model ID string.
  final String modelId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: tokens.spacing.step13,
            child: Text(
              label,
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Text(
              modelId,
              style: monoMetaStyle(
                tokens,
                tokens.colors,
                base: tokens.typography.styles.body.bodySmall,
                color: tokens.colors.text.highEmphasis,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
