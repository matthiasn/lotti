import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/provider/ai_provider_detail_widgets.dart';
import 'package:lotti/features/ai/ui/settings/util/active_profile.dart';
import 'package:lotti/features/ai/ui/settings/widgets/mlx_audio_model_download_dialog.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_settings_cards.dart';
import 'package:lotti/features/ai/util/mlx_audio_model_progress_store.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Models section of the provider detail page.
///
/// Lists the provider's configured [models] (with MLX-audio download status
/// where applicable), an "Add model" affordance ([onAddModel]), and forwards
/// row taps to [onModelTap] to open the model edit page.
class ModelsSection extends StatelessWidget {
  const ModelsSection({
    required this.provider,
    required this.models,
    required this.onAddModel,
    required this.onModelTap,
    super.key,
  });

  final AiConfigInferenceProvider provider;
  final List<AiConfigModel> models;
  final VoidCallback onAddModel;
  final ValueChanged<AiConfigModel> onModelTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Section(
      title: messages.aiProviderDetailModelsTitle(models.length),
      trailing: DesignSystemButton(
        label: messages.aiProviderDetailAddModelButton,
        variant: DesignSystemButtonVariant.secondary,
        leadingIcon: Icons.add_rounded,
        onPressed: onAddModel,
      ),
      child: models.isEmpty
          ? EmptySectionCard(
              message: messages.aiProviderDetailNoModelsMessage,
            )
          : Column(
              children: [
                for (var i = 0; i < models.length; i++) ...[
                  if (i > 0) SizedBox(height: tokens.spacing.step3),
                  Consumer(
                    builder: (context, ref, _) {
                      final model = models[i];
                      final progress =
                          provider.inferenceProviderType ==
                              InferenceProviderType.mlxAudio
                          ? ref.watch(
                              mlxAudioModelProgressProvider(
                                model.providerModelId,
                              ),
                            )
                          : null;
                      return AiModelCard(
                        model: model,
                        providerType: provider.inferenceProviderType,
                        onTap: () => onModelTap(model),
                        modelDownloadProgress: progress,
                        onInstallModel:
                            provider.inferenceProviderType ==
                                InferenceProviderType.mlxAudio
                            ? () => MlxAudioModelDownloadDialog.show(
                                context: context,
                                model: model,
                              )
                            : null,
                      );
                    },
                  ),
                ],
              ],
            ),
    );
  }
}

/// "Active profile" section of the provider detail page.
///
/// Renders the inference [profile] that currently relies on this provider's
/// [models] as a tappable [AiProfileCard], so the user can jump from a provider
/// to the profile wired to it. Tapping forwards to [onProfileTap].
class ActiveProfileSection extends StatelessWidget {
  const ActiveProfileSection({
    required this.profile,
    required this.providerType,
    required this.models,
    required this.onProfileTap,
    super.key,
  });

  final AiConfigInferenceProfile profile;
  final InferenceProviderType providerType;
  final List<AiConfigModel> models;
  final ValueChanged<AiConfigInferenceProfile> onProfileTap;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final modelsBySlotId = modelByProfileSlotId(models);
    return Section(
      title: messages.aiProviderDetailActiveProfileTitle,
      child: AiProfileCard(
        profile: profile,
        // The section only renders when [pickActiveProfileForProvider]
        // has already chosen this profile for this provider, so the
        // Active badge always applies here.
        isActive: true,
        providerTypeFor: () => providerType,
        modelLookup: (id) => modelsBySlotId[id]?.name,
        onTap: () => onProfileTap(profile),
      ),
    );
  }
}
