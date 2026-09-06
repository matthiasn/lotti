import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/provider/ai_provider_detail_widgets.dart';
import 'package:lotti/features/ai/ui/settings/util/profile_usage.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_settings_cards.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Models section of the provider detail page.
///
/// Lists the provider's configured [models], an "Add model" affordance
/// ([onAddModel]), and forwards
/// row taps to [onModelTap] to open the model edit page. Each row also carries
/// a trash action forwarding to [onDeleteModel], so a model can be removed
/// right here instead of hunting it down on the Models tab — the page is
/// expected to confirm before deleting.
class ModelsSection extends StatelessWidget {
  const ModelsSection({
    required this.provider,
    required this.models,
    required this.onAddModel,
    required this.onModelTap,
    required this.onDeleteModel,
    super.key,
  });

  final AiConfigInferenceProvider provider;
  final List<AiConfigModel> models;
  final VoidCallback onAddModel;
  final ValueChanged<AiConfigModel> onModelTap;
  final ValueChanged<AiConfigModel> onDeleteModel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Section(
      title: provider.inferenceProviderType == InferenceProviderType.sherpa
          ? messages.sherpaInstalledModelsTitle
          : messages.aiProviderDetailModelsTitle(models.length),
      trailing: provider.inferenceProviderType == InferenceProviderType.sherpa
          ? null
          : DesignSystemButton(
              label: messages.aiProviderDetailAddModelButton,
              variant: DesignSystemButtonVariant.secondary,
              leadingIcon: LottiIcons.add,
              onPressed: onAddModel,
            ),
      child: models.isEmpty
          ? EmptySectionCard(
              message:
                  provider.inferenceProviderType == InferenceProviderType.sherpa
                  ? messages.sherpaModelNotInstalled
                  : messages.aiProviderDetailNoModelsMessage,
            )
          : Column(
              children: [
                for (var i = 0; i < models.length; i++) ...[
                  if (i > 0) SizedBox(height: tokens.spacing.step3),
                  AiModelCard(
                    model: models[i],
                    providerType: provider.inferenceProviderType,
                    onTap: () => onModelTap(models[i]),
                    onDelete:
                        provider.inferenceProviderType ==
                            InferenceProviderType.sherpa
                        ? null
                        : () => onDeleteModel(models[i]),
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
