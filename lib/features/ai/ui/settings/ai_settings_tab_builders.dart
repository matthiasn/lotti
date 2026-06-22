part of 'ai_settings_page.dart';

/// Per-tab body builders for [_AiSettingsPageState] — the provider
/// grid, model list, profile grid, the shared responsive card list,
/// and the empty-tab sliver.
extension _AiSettingsTabBuilders on _AiSettingsPageState {
  Widget _buildProvidersGrid(
    List<AiConfigInferenceProvider> providers,
    List<AiConfigModel> models,
  ) {
    final tokens = context.designTokens;
    final modelsByProvider = <String, int>{};
    for (final m in models) {
      modelsByProvider[m.inferenceProviderId] =
          (modelsByProvider[m.inferenceProviderId] ?? 0) + 1;
    }
    final filtered = _filterService.filterProviders(providers, _filterState);
    if (filtered.isEmpty) {
      return _emptyTabSliver(context.messages.aiSettingsNoProvidersConfigured);
    }

    AiProviderCard buildCard(AiConfigInferenceProvider provider) {
      final modelCount = modelsByProvider[provider.id] ?? 0;
      final status = AiProviderCard.statusFor(
        provider: provider,
        modelCount: modelCount,
      );
      return AiProviderCard(
        provider: provider,
        modelCount: modelCount,
        status: status,
        onTap: () => _handleConfigTap(provider),
        menuActions: _buildCardMenu(provider),
        onFix: status == AiProviderCardStatus.invalidKey
            ? () => _handleFixProvider(provider)
            : null,
      );
    }

    return _buildCardList<AiConfigInferenceProvider>(
      tokens: tokens,
      items: filtered,
      buildCard: buildCard,
    );
  }

  // ---------------------------------------------------------------
  // Models tab — single-column list
  // ---------------------------------------------------------------

  Widget _buildModelsList(
    List<AiConfigModel> models,
    List<AiConfigInferenceProvider> providers,
  ) {
    final filtered = _filterService.filterModels(models, _filterState);
    if (filtered.isEmpty) {
      return _emptyTabSliver(context.messages.aiSettingsNoModelsConfigured);
    }
    final tokens = context.designTokens;
    final providerTypeById = <String, InferenceProviderType>{
      for (final p in providers) p.id: p.inferenceProviderType,
    };
    return SliverPadding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step5,
        vertical: tokens.spacing.step3,
      ),
      sliver: SliverList.separated(
        itemCount: filtered.length,
        separatorBuilder: (_, _) => SizedBox(height: tokens.spacing.step3),
        itemBuilder: (context, index) {
          final model = filtered[index];
          // Pass through the resolved type when we have one. If the
          // owning provider hasn't loaded yet or was deleted, leave it
          // null and let the card render neutral chrome instead of
          // misbranding a model as Gemini.
          final providerType = providerTypeById[model.inferenceProviderId];
          return Consumer(
            builder: (context, ref, _) {
              final progress = providerType == InferenceProviderType.mlxAudio
                  ? ref.watch(
                      mlxAudioModelProgressProvider(model.providerModelId),
                    )
                  : null;
              return AiModelCard(
                model: model,
                providerType: providerType,
                onTap: () => _handleConfigTap(model),
                menuActions: _buildCardMenu(model),
                modelDownloadProgress: progress,
                onInstallModel: providerType == InferenceProviderType.mlxAudio
                    ? () => _handleInstallMlxAudioModel(model)
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------
  // Profiles tab — responsive list (1 col mobile, 2 col desktop)
  // ---------------------------------------------------------------

  Widget _buildProfilesGrid(
    List<AiConfigInferenceProfile> profiles,
    List<AiConfigModel> models,
    List<AiConfigInferenceProvider> providers,
  ) {
    final query = _filterState.searchQuery;
    final filtered = query.isEmpty
        ? profiles
        : profiles.where((p) => p.name.toLowerCase().contains(query)).toList();
    if (filtered.isEmpty) {
      return _emptyTabSliver(
        query.isNotEmpty
            ? context.messages.multiSelectNoItemsFound
            : context.messages.inferenceProfilesEmpty,
      );
    }
    final tokens = context.designTokens;
    final providerTypeByProviderId = <String, InferenceProviderType>{
      for (final p in providers) p.id: p.inferenceProviderType,
    };
    final modelsBySlotId = modelByProfileSlotId(models);
    // A profile earns the Active badge iff it's the winning candidate
    // for at least one configured provider — same rule the detail
    // page uses for its "Active profile" section.
    final activeProfileIds = activeProfileIdsForProviders(
      providers: providers,
      models: models,
      profiles: profiles,
    );

    AiProfileCard buildCard(AiConfigInferenceProfile profile) {
      return AiProfileCard(
        profile: profile,
        isActive: activeProfileIds.contains(profile.id),
        providerTypeFor: () => _providerTypeForProfile(
          profile,
          modelsBySlotId,
          providerTypeByProviderId,
        ),
        modelLookup: (id) => modelsBySlotId[id]?.name,
        onTap: () => _handleConfigTap(profile),
        menuActions: _buildCardMenu(profile),
      );
    }

    return _buildCardList<AiConfigInferenceProfile>(
      tokens: tokens,
      items: filtered,
      buildCard: buildCard,
    );
  }

  /// Renders [items] as a vertical list of cards. Above the responsive
  /// breakpoint each row pairs two cards in a Row; below the breakpoint
  /// each row carries one card at full width. Cards size to their
  /// intrinsic content — no fixed aspect ratio, so taglines and the
  /// status row never clip on mobile (the v2-rewrite SliverGrid was
  /// flagging RenderFlex overflows at the smallest viewport widths).
  Widget _buildCardList<T>({
    required DsTokens tokens,
    required List<T> items,
    required Widget Function(T) buildCard,
  }) {
    return SliverPadding(
      padding: EdgeInsets.all(tokens.spacing.step5),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final columns =
              constraints.crossAxisExtent >= aiSettingsGridColumnBreakpoint
              ? 2
              : 1;
          if (columns == 1) {
            return SliverList.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  SizedBox(height: tokens.spacing.step4),
              itemBuilder: (context, index) => buildCard(items[index]),
            );
          }
          // Desktop: pair items into rows of two. Odd last items get
          // a half-width placeholder so the grid stays aligned.
          final rowCount = (items.length + 1) ~/ 2;
          return SliverList.separated(
            itemCount: rowCount,
            separatorBuilder: (_, _) => SizedBox(height: tokens.spacing.step4),
            itemBuilder: (context, rowIndex) {
              final leftIndex = rowIndex * 2;
              final rightIndex = leftIndex + 1;
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: buildCard(items[leftIndex])),
                    SizedBox(width: tokens.spacing.step4),
                    Expanded(
                      child: rightIndex < items.length
                          ? buildCard(items[rightIndex])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Best-guess provider type for a profile card. The profile schema
  /// doesn't carry a provider id — it just references model rows. Walk
  /// the five skill slots in priority order
  /// (thinking → thinking-high-end → image recognition → transcription
  /// → image generation) and pick the first model whose owning provider
  /// we can resolve. Returns null when none of the slots resolve — the
  /// card paints neutral chrome in that case rather than impersonating
  /// Gemini.
  InferenceProviderType? _providerTypeForProfile(
    AiConfigInferenceProfile profile,
    Map<String, AiConfigModel> modelsBySlotId,
    Map<String, InferenceProviderType> providerTypeByProviderId,
  ) {
    final candidates = <String?>[
      profile.thinkingModelId,
      profile.thinkingHighEndModelId,
      profile.imageRecognitionModelId,
      profile.transcriptionModelId,
      profile.imageGenerationModelId,
    ];
    for (final candidate in candidates) {
      if (candidate == null) continue;
      final model = modelsBySlotId[candidate];
      if (model == null) continue;
      final type = providerTypeByProviderId[model.inferenceProviderId];
      if (type != null) return type;
    }
    return null;
  }

  Widget _emptyTabSliver(String message) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(context.designTokens.spacing.step5),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: context.designTokens.typography.styles.body.bodySmall
                .copyWith(
                  color: context.designTokens.colors.text.mediumEmphasis,
                ),
          ),
        ),
      ),
    );
  }
}
