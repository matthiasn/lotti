part of 'ai_provider_detail_page.dart';

class _ModelsSection extends StatelessWidget {
  const _ModelsSection({
    required this.provider,
    required this.models,
    required this.onAddModel,
    required this.onModelTap,
  });

  final AiConfigInferenceProvider provider;
  final List<AiConfigModel> models;
  final VoidCallback onAddModel;
  final ValueChanged<AiConfigModel> onModelTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return _Section(
      title: messages.aiProviderDetailModelsTitle(models.length),
      trailing: DesignSystemButton(
        label: messages.aiProviderDetailAddModelButton,
        variant: DesignSystemButtonVariant.secondary,
        leadingIcon: Icons.add_rounded,
        onPressed: onAddModel,
      ),
      child: models.isEmpty
          ? _EmptySectionCard(
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

class _ActiveProfileSection extends StatelessWidget {
  const _ActiveProfileSection({
    required this.profile,
    required this.providerType,
    required this.models,
    required this.onProfileTap,
  });

  final AiConfigInferenceProfile profile;
  final InferenceProviderType providerType;
  final List<AiConfigModel> models;
  final ValueChanged<AiConfigInferenceProfile> onProfileTap;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final modelNamesById = <String, String>{
      for (final m in models) m.providerModelId: m.name,
    };
    return _Section(
      title: messages.aiProviderDetailActiveProfileTitle,
      child: AiProfileCard(
        profile: profile,
        // The section only renders when [pickActiveProfileForProvider]
        // has already chosen this profile for this provider, so the
        // Active badge always applies here.
        isActive: true,
        providerTypeFor: () => providerType,
        modelLookup: (id) => modelNamesById[id],
        onTap: () => onProfileTap(profile),
      ),
    );
  }
}
