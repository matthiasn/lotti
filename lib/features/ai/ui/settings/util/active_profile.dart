import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/widgets/v2/ai_settings_cards.dart';

/// Picks the inference profile that best represents the "active
/// profile for this provider". Heuristic:
/// 1. If any default-marked profile has at least one of its slots
///    pointing at a model owned by [providerModels], that's the
///    winner.
/// 2. Otherwise, the first profile whose slots reference one of
///    [providerModels].
/// 3. Returns null if no profile touches any of the provider's
///    models — keeps the active-profile section from showing a
///    misleading "active" tile for a provider that isn't actually
///    wired into any profile yet.
///
/// Single-provider variant used by the provider detail page's
/// "Active profile" section. The list view consumes the
/// [activeProfileIdsForProviders] aggregation built on top of this.
AiConfigInferenceProfile? pickActiveProfileForProvider({
  required List<AiConfigInferenceProfile> profiles,
  required List<AiConfigModel> providerModels,
}) {
  if (providerModels.isEmpty || profiles.isEmpty) return null;
  final providerModelIds = providerModels.map((m) => m.providerModelId).toSet();

  bool touchesProvider(AiConfigInferenceProfile p) {
    final slots = <String?>[
      p.thinkingModelId,
      p.thinkingHighEndModelId,
      p.imageRecognitionModelId,
      p.transcriptionModelId,
      p.imageGenerationModelId,
    ];
    return slots.any(
      (slot) => slot != null && providerModelIds.contains(slot),
    );
  }

  for (final p in profiles) {
    if (p.isDefault && touchesProvider(p)) return p;
  }
  for (final p in profiles) {
    if (touchesProvider(p)) return p;
  }
  return null;
}

/// Returns the set of profile ids that are the "active profile" for at
/// least one *configured* provider. Powers the Profiles tab's Active
/// badge: a profile is badged iff some configured provider would treat
/// it as its active profile on the provider detail page.
///
/// "Configured" delegates to [AiProviderCard.statusFor] returning
/// `connected` — same definition the provider card's status pill uses,
/// so the badge and the pill can never disagree.
Set<String> activeProfileIdsForProviders({
  required List<AiConfigInferenceProvider> providers,
  required List<AiConfigModel> models,
  required List<AiConfigInferenceProfile> profiles,
}) {
  if (providers.isEmpty || profiles.isEmpty) return const <String>{};
  final modelsByProviderId = <String, List<AiConfigModel>>{};
  for (final model in models) {
    modelsByProviderId
        .putIfAbsent(model.inferenceProviderId, () => <AiConfigModel>[])
        .add(model);
  }
  final activeIds = <String>{};
  for (final provider in providers) {
    final providerModels =
        modelsByProviderId[provider.id] ?? const <AiConfigModel>[];
    if (!_isProviderConfigured(provider, providerModels)) continue;
    final winner = pickActiveProfileForProvider(
      profiles: profiles,
      providerModels: providerModels,
    );
    if (winner != null) activeIds.add(winner.id);
  }
  return activeIds;
}

/// Delegates to [AiProviderCard.statusFor] so the badge uses the exact
/// same "connected" definition the provider card's status pill does —
/// single source of truth, no parallel implementation to drift.
bool _isProviderConfigured(
  AiConfigInferenceProvider provider,
  List<AiConfigModel> providerModels,
) {
  return AiProviderCard.statusFor(
        provider: provider,
        modelCount: providerModels.length,
      ) ==
      AiProviderCardStatus.connected;
}
