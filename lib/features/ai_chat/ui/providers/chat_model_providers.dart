import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';

/// Eligible chat models (category-agnostic).
///
/// Criteria:
/// - Model supports function calling
/// - Model supports text input modality
///
/// The provider does not inspect "reasoning" capability; it is exposed by
/// `hasReasoningModelForCategoryProvider` below for UX decisions.
final AutoDisposeFutureProviderFamily<List<AiConfigModel>, String>
    eligibleChatModelsForCategoryProvider =
    FutureProvider.autoDispose.family<List<AiConfigModel>, String>(
  (ref, categoryId) async {
    final aiRepo = ref.read(aiConfigRepositoryProvider);

    final models = await aiRepo.getConfigsByType(AiConfigType.model);

    // Filter by capabilities only (function calling + text input)
    final eligible = models.whereType<AiConfigModel>().where((m) {
      final supportsText = m.inputModalities.contains(Modality.text);
      return m.supportsFunctionCalling && supportsText;
    }).toList();

    // Sort by provider then name for stable UX
    // Fetch providers to get names
    final providers =
        await aiRepo.getConfigsByType(AiConfigType.inferenceProvider);
    final providerById = {
      for (final p in providers.whereType<AiConfigInferenceProvider>()) p.id: p
    };

    eligible.sort((a, b) {
      final pa = providerById[a.inferenceProviderId]?.name ?? '';
      final pb = providerById[b.inferenceProviderId]?.name ?? '';
      final byProvider = pa.compareTo(pb);
      if (byProvider != 0) return byProvider;
      return a.name.compareTo(b.name);
    });

    return eligible;
  },
);

/// Whether at least one reasoning-capable eligible model exists for a category.
final AutoDisposeFutureProviderFamily<bool, String>
    hasReasoningModelForCategoryProvider =
    FutureProvider.autoDispose.family<bool, String>(
  (ref, categoryId) async {
    final models = await ref
        .watch(eligibleChatModelsForCategoryProvider(categoryId).future);
    return models.any((m) => m.isReasoningModel);
  },
);
