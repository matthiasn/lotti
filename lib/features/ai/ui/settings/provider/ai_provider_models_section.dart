import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/provider/ai_provider_detail_widgets.dart';
import 'package:lotti/features/ai/ui/settings/util/profile_usage.dart';
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

/// "Profiles using this provider" section of the provider detail page.
///
/// Lists every inference [profiles] entry with a model slot pointing at one of
/// this provider's [models], as tappable [AiProfileCard]s, so the user can see
/// what depends on the provider before removing it. Tapping forwards to
/// [onProfileTap].
///
/// The cards render without the in-use badge: referencing a provider's model
/// is not the same as something routing inference through the profile, and the
/// Profiles tab is where that question is answered.
class ProfilesUsingProviderSection extends StatelessWidget {
  const ProfilesUsingProviderSection({
    required this.profiles,
    required this.providerType,
    required this.models,
    required this.onProfileTap,
    super.key,
  });

  final List<AiConfigInferenceProfile> profiles;
  final InferenceProviderType providerType;
  final List<AiConfigModel> models;
  final ValueChanged<AiConfigInferenceProfile> onProfileTap;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final tokens = context.designTokens;
    final modelsBySlotId = modelByProfileSlotId(models);
    return Section(
      title: messages.aiProviderDetailProfilesUsingTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final profile in profiles) ...[
            if (profile != profiles.first)
              SizedBox(height: tokens.spacing.step3),
            AiProfileCard(
              profile: profile,
              isInUse: false,
              providerTypeFor: () => providerType,
              modelLookup: (id) => modelsBySlotId[id]?.name,
              onTap: () => onProfileTap(profile),
            ),
          ],
        ],
      ),
    );
  }
}
