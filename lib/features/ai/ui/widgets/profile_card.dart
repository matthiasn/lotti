import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

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
    return Card(
      elevation: 0,
      color: context.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      profile.name,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (profile.desktopOnly)
                    Chip(
                      label: Text(
                        context.messages.inferenceProfileDesktopOnly,
                        style: context.textTheme.labelSmall,
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  if (profile.isDefault)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.lock_outline,
                        size: 16,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              modelId,
              style: context.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
