import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_visual.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'provider_prompt_setup_service.g.dart';

/// Provider for [ProviderPromptSetupService].
@riverpod
ProviderPromptSetupService providerPromptSetupService(Ref ref) {
  return const ProviderPromptSetupService();
}

/// Service that handles automatic FTUE (First Time User Experience) setup
/// after creating inference providers.
///
/// The FTUE flow creates:
/// 1. Models (provider-specific known model configurations)
/// 2. A test category for quick experimentation
///
/// Prompts are no longer created during FTUE — all AI capabilities are
/// handled by the skill-based automation system via inference profiles.
class ProviderPromptSetupService {
  const ProviderPromptSetupService();
}

// =============================================================================
// FTUE (First Time User Experience) Setup
// =============================================================================

/// Common shape for every per-provider FTUE result.
///
/// Declared `sealed` so callers (`runFtueSetupForType`,
/// `AiProviderSetupResultData.from`) get exhaustive switch coverage when
/// a new provider is wired in — the analyzer will flag any missing arm.
sealed class AiFtueResult {
  const AiFtueResult({
    required this.modelsCreated,
    required this.modelsVerified,
    required this.categoryCreated,
    this.categoryReused = false,
    this.categoryName,
    this.errors = const [],
  });

  final int modelsCreated;
  final int modelsVerified;
  final bool categoryCreated;
  final bool categoryReused;
  final String? categoryName;
  final List<String> errors;

  int get totalModels => modelsCreated + modelsVerified;
}

/// Internal model-creation tally used by every per-provider setup helper.
/// Replaces the previous typed `_<X>FtueModelResult` classes — none of the
/// per-role fields were ever read outside the loop.
typedef _FtueModelTally = ({
  List<AiConfigModel> created,
  List<AiConfigModel> verified,
});

/// Result of the Gemini FTUE setup process.
class GeminiFtueResult extends AiFtueResult {
  const GeminiFtueResult({
    required super.modelsCreated,
    required super.modelsVerified,
    required super.categoryCreated,
    super.categoryReused,
    super.categoryName,
    super.errors,
  });
}

/// Extension to add Gemini FTUE functionality to ProviderPromptSetupService.
extension GeminiFtueSetup on ProviderPromptSetupService {
  /// Performs comprehensive FTUE setup for Gemini providers.
  ///
  /// This creates:
  /// 1. Three models (Flash, Pro, Nano Banana Pro) if they don't exist
  /// 2. A test category with auto-selection configured
  ///
  /// Any `providerModelId` in [excludedProviderModelIds] is skipped — it
  /// is neither created nor verified. The caller (the preview modal)
  /// uses this to honor user-unticked rows without a post-hoc delete.
  Future<GeminiFtueResult?> performGeminiFtueSetup({
    required BuildContext context,
    required WidgetRef ref,
    required AiConfigInferenceProvider provider,
    Set<String> excludedProviderModelIds = const {},
  }) async {
    if (provider.inferenceProviderType != InferenceProviderType.gemini) {
      return null;
    }

    final repository = ref.read(aiConfigRepositoryProvider);
    final categoryRepository = ref.read(categoryRepositoryProvider);

    final knownModels = getFtueKnownModels();
    // coverage:ignore-start
    // Defensive: `getFtueKnownModels()` only returns null if the
    // canonical `geminiModels` const table is missing the FTUE model
    // ids — unreachable in production, kept as a hard guard so a stale
    // checkout fails loudly instead of seeding a broken config.
    if (knownModels == null) {
      return GeminiFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        categoryCreated: false,
        errors: [
          context.messages.aiSetupResultKnownModelsMissing(
            aiProviderDisplayName(
              type: InferenceProviderType.gemini,
              messages: context.messages,
            ),
          ),
        ],
      );
    }
    // coverage:ignore-end

    final modelResult = await _ensureModelsExist(
      repository: repository,
      providerId: provider.id,
      modelConfigs: [
        (known: knownModels.flash, id: ftueFlashModelId),
        (known: knownModels.pro, id: ftueProModelId),
        (known: knownModels.image, id: ftueImageModelId),
      ],
      excludedProviderModelIds: excludedProviderModelIds,
    );

    final (category, categoryWasCreated) = await _createOrReuseCategory(
      categoryRepository: categoryRepository,
      categoryName: ftueGeminiCategoryName,
      categoryColor: ftueGeminiCategoryColor,
      defaultProfileId: profileGeminiFlashId,
      defaultTemplateId: lauraTemplateId,
    );

    return GeminiFtueResult(
      modelsCreated: modelResult.created.length,
      modelsVerified: modelResult.verified.length,
      categoryCreated: categoryWasCreated,
      categoryReused: !categoryWasCreated && category != null,
      categoryName: category?.name,
    );
  }
}

/// Shared model-row reconciler used by every per-provider FTUE helper.
///
/// For each preset (known, providerModelId) entry:
/// - if the user unticked the row, skip it entirely (no save, no count);
/// - if a row already exists for the provider with that providerModelId,
///   mark it `verified`;
/// - otherwise create a fresh row, save it, and mark it `created`.
Future<_FtueModelTally> _ensureModelsExist({
  required AiConfigRepository repository,
  required String providerId,
  required List<({KnownModel known, String id})> modelConfigs,
  Set<String> excludedProviderModelIds = const {},
}) async {
  final allModels = await repository.getConfigsByType(AiConfigType.model);
  final providerModels = allModels
      .whereType<AiConfigModel>()
      .where((m) => m.inferenceProviderId == providerId)
      .toList(growable: false);

  final created = <AiConfigModel>[];
  final verified = <AiConfigModel>[];
  const uuid = Uuid();

  for (final config in modelConfigs) {
    if (excludedProviderModelIds.contains(config.id)) {
      continue;
    }

    final existing = providerModels.firstWhereOrNull(
      (m) => m.providerModelId == config.id,
    );

    if (existing != null) {
      verified.add(existing);
    } else {
      final model = config.known.toAiConfigModel(
        id: uuid.v4(),
        inferenceProviderId: providerId,
      );
      await repository.saveConfig(model);
      created.add(model);
    }
  }

  return (created: created, verified: verified);
}

/// Shared "create or reuse the FTUE test category" helper. Looks up an
/// existing (non-deleted) category by exact name; otherwise creates a
/// fresh one with the given color and the optional default profile +
/// agent template bindings.
Future<(CategoryDefinition?, bool)> _createOrReuseCategory({
  required CategoryRepository categoryRepository,
  required String categoryName,
  required String categoryColor,
  String? defaultProfileId,
  String? defaultTemplateId,
}) async {
  final allCategories = await categoryRepository.getAllCategories();
  final existingCategory = allCategories
      .where((c) => c.name == categoryName && c.deletedAt == null)
      .firstOrNull;

  if (existingCategory != null) {
    return (existingCategory, false);
  }

  final category = await categoryRepository.createCategory(
    name: categoryName,
    color: categoryColor,
    defaultProfileId: defaultProfileId,
    defaultTemplateId: defaultTemplateId,
  );

  return (category, true);
}

// =============================================================================
// OpenAI FTUE (First Time User Experience) Setup
// =============================================================================

/// Result of the OpenAI FTUE setup process.
class OpenAiFtueResult extends AiFtueResult {
  const OpenAiFtueResult({
    required super.modelsCreated,
    required super.modelsVerified,
    required super.categoryCreated,
    super.categoryReused,
    super.categoryName,
    super.errors,
  });
}

/// Extension to add OpenAI FTUE functionality to ProviderPromptSetupService.
extension OpenAiFtueSetup on ProviderPromptSetupService {
  /// Performs comprehensive FTUE setup for OpenAI providers.
  ///
  /// This creates:
  /// 1. Four models (Flash/GPT-5 Nano, Reasoning/GPT-5.2, Audio/GPT-4o
  ///    Transcribe, Image/GPT Image 1.5)
  /// 2. A test category with auto-selection configured
  Future<OpenAiFtueResult?> performOpenAiFtueSetup({
    required BuildContext context,
    required WidgetRef ref,
    required AiConfigInferenceProvider provider,
    Set<String> excludedProviderModelIds = const {},
  }) async {
    if (provider.inferenceProviderType != InferenceProviderType.openAi) {
      return null;
    }

    final repository = ref.read(aiConfigRepositoryProvider);
    final categoryRepository = ref.read(categoryRepositoryProvider);

    final knownModels = getOpenAiFtueKnownModels();
    // coverage:ignore-start
    // Defensive guard against a stale const lookup table — see the
    // matching note on the Gemini helper above.
    if (knownModels == null) {
      return OpenAiFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        categoryCreated: false,
        errors: [
          context.messages.aiSetupResultKnownModelsMissing(
            aiProviderDisplayName(
              type: InferenceProviderType.openAi,
              messages: context.messages,
            ),
          ),
        ],
      );
    }
    // coverage:ignore-end

    final modelResult = await _ensureModelsExist(
      repository: repository,
      providerId: provider.id,
      modelConfigs: [
        (known: knownModels.flash, id: ftueOpenAiFlashModelId),
        (known: knownModels.reasoning, id: ftueOpenAiReasoningModelId),
        (known: knownModels.audio, id: ftueOpenAiAudioModelId),
        (known: knownModels.image, id: ftueOpenAiImageModelId),
      ],
      excludedProviderModelIds: excludedProviderModelIds,
    );

    final (category, categoryWasCreated) = await _createOrReuseCategory(
      categoryRepository: categoryRepository,
      categoryName: ftueOpenAiCategoryName,
      categoryColor: ftueOpenAiCategoryColor,
    );

    return OpenAiFtueResult(
      modelsCreated: modelResult.created.length,
      modelsVerified: modelResult.verified.length,
      categoryCreated: categoryWasCreated,
      categoryReused: !categoryWasCreated && category != null,
      categoryName: category?.name,
    );
  }
}

// =============================================================================
// Mistral FTUE (First Time User Experience) Setup
// =============================================================================

/// Result of the Mistral FTUE setup process.
class MistralFtueResult extends AiFtueResult {
  const MistralFtueResult({
    required super.modelsCreated,
    required super.modelsVerified,
    required super.categoryCreated,
    super.categoryReused,
    super.categoryName,
    super.errors,
  });
}

/// Extension to add Mistral FTUE functionality to ProviderPromptSetupService.
extension MistralFtueSetup on ProviderPromptSetupService {
  /// Performs comprehensive FTUE setup for Mistral providers.
  ///
  /// This creates:
  /// 1. Three models (Fast/Mistral Small, Reasoning/Magistral Medium,
  ///    Audio/Voxtral Mini)
  /// 2. A test category with auto-selection configured
  Future<MistralFtueResult?> performMistralFtueSetup({
    required BuildContext context,
    required WidgetRef ref,
    required AiConfigInferenceProvider provider,
    Set<String> excludedProviderModelIds = const {},
  }) async {
    if (provider.inferenceProviderType != InferenceProviderType.mistral) {
      return null;
    }

    final repository = ref.read(aiConfigRepositoryProvider);
    final categoryRepository = ref.read(categoryRepositoryProvider);

    final knownModels = getMistralFtueKnownModels();
    // coverage:ignore-start
    // Defensive guard against a stale const lookup table — see the
    // matching note on the Gemini helper above.
    if (knownModels == null) {
      return MistralFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        categoryCreated: false,
        errors: [
          context.messages.aiSetupResultKnownModelsMissing(
            aiProviderDisplayName(
              type: InferenceProviderType.mistral,
              messages: context.messages,
            ),
          ),
        ],
      );
    }
    // coverage:ignore-end

    final modelResult = await _ensureModelsExist(
      repository: repository,
      providerId: provider.id,
      modelConfigs: [
        (known: knownModels.flash, id: ftueMistralFlashModelId),
        (known: knownModels.reasoning, id: ftueMistralReasoningModelId),
        (known: knownModels.audio, id: ftueMistralAudioModelId),
      ],
      excludedProviderModelIds: excludedProviderModelIds,
    );

    final (category, categoryWasCreated) = await _createOrReuseCategory(
      categoryRepository: categoryRepository,
      categoryName: ftueMistralCategoryName,
      categoryColor: ftueMistralCategoryColor,
    );

    return MistralFtueResult(
      modelsCreated: modelResult.created.length,
      modelsVerified: modelResult.verified.length,
      categoryCreated: categoryWasCreated,
      categoryReused: !categoryWasCreated && category != null,
      categoryName: category?.name,
    );
  }
}

// =============================================================================
// Alibaba FTUE (First Time User Experience) Setup
// =============================================================================

/// Result of the Alibaba FTUE setup process.
class AlibabaFtueResult extends AiFtueResult {
  const AlibabaFtueResult({
    required super.modelsCreated,
    required super.modelsVerified,
    required super.categoryCreated,
    super.categoryReused,
    super.categoryName,
    super.errors,
  });
}

/// Extension to add Alibaba FTUE functionality to ProviderPromptSetupService.
extension AlibabaFtueSetup on ProviderPromptSetupService {
  /// Performs comprehensive FTUE setup for Alibaba providers.
  ///
  /// This creates:
  /// 1. Five models (Flash/Qwen Flash, Reasoning/Qwen 3.5 Plus,
  ///    Audio/Qwen3 Omni Flash, Vision/Qwen3 VL Flash, Image/Wan 2.6)
  /// 2. A test category bound to the seeded Chinese AI Profile
  ///
  /// The Chinese AI Profile (inference profile) is automatically created
  /// by ProfileSeedingService on app startup and links to these models.
  Future<AlibabaFtueResult?> performAlibabaFtueSetup({
    required BuildContext context,
    required WidgetRef ref,
    required AiConfigInferenceProvider provider,
    Set<String> excludedProviderModelIds = const {},
  }) async {
    if (provider.inferenceProviderType != InferenceProviderType.alibaba) {
      return null;
    }

    final repository = ref.read(aiConfigRepositoryProvider);
    final categoryRepository = ref.read(categoryRepositoryProvider);

    final knownModels = getAlibabaFtueKnownModels();
    // coverage:ignore-start
    // Defensive guard against a stale const lookup table — see the
    // matching note on the Gemini helper above.
    if (knownModels == null) {
      return AlibabaFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        categoryCreated: false,
        errors: [
          context.messages.aiSetupResultKnownModelsMissing(
            aiProviderDisplayName(
              type: InferenceProviderType.alibaba,
              messages: context.messages,
            ),
          ),
        ],
      );
    }
    // coverage:ignore-end

    final modelResult = await _ensureModelsExist(
      repository: repository,
      providerId: provider.id,
      modelConfigs: [
        (known: knownModels.flash, id: ftueAlibabaFlashModelId),
        (known: knownModels.reasoning, id: ftueAlibabaReasoningModelId),
        (known: knownModels.audio, id: ftueAlibabaAudioModelId),
        (known: knownModels.vision, id: ftueAlibabaVisionModelId),
        (known: knownModels.image, id: ftueAlibabaImageModelId),
      ],
      excludedProviderModelIds: excludedProviderModelIds,
    );

    final (category, categoryWasCreated) = await _createOrReuseCategory(
      categoryRepository: categoryRepository,
      categoryName: ftueAlibabaCategoryName,
      categoryColor: ftueAlibabaCategoryColor,
      defaultProfileId: profileAlibabaId,
    );

    return AlibabaFtueResult(
      modelsCreated: modelResult.created.length,
      modelsVerified: modelResult.verified.length,
      categoryCreated: categoryWasCreated,
      categoryReused: !categoryWasCreated && category != null,
      categoryName: category?.name,
    );
  }
}

// =============================================================================
// Anthropic FTUE (First Time User Experience) Setup
// =============================================================================

/// Result of the Anthropic FTUE setup process.
class AnthropicFtueResult extends AiFtueResult {
  const AnthropicFtueResult({
    required super.modelsCreated,
    required super.modelsVerified,
    required super.categoryCreated,
    super.categoryReused,
    super.categoryName,
    super.errors,
  });
}

/// Extension to add Anthropic FTUE functionality to ProviderPromptSetupService.
extension AnthropicFtueSetup on ProviderPromptSetupService {
  /// Performs comprehensive FTUE setup for Anthropic providers.
  ///
  /// Creates a reasoning model (Claude Sonnet 4) and a fast model
  /// (Claude Haiku 3.5) along with the shared FTUE test category.
  /// Anthropic ships no native transcription or image-generation models,
  /// so those skill slots remain unbound on the seeded profile.
  Future<AnthropicFtueResult?> performAnthropicFtueSetup({
    required BuildContext context,
    required WidgetRef ref,
    required AiConfigInferenceProvider provider,
    Set<String> excludedProviderModelIds = const {},
  }) async {
    if (provider.inferenceProviderType != InferenceProviderType.anthropic) {
      return null;
    }

    final repository = ref.read(aiConfigRepositoryProvider);
    final categoryRepository = ref.read(categoryRepositoryProvider);

    final knownModels = getAnthropicFtueKnownModels();
    // coverage:ignore-start
    // Defensive guard against a stale const lookup table — see the
    // matching note on the Gemini helper above.
    if (knownModels == null) {
      return AnthropicFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        categoryCreated: false,
        errors: [
          context.messages.aiSetupResultKnownModelsMissing(
            aiProviderDisplayName(
              type: InferenceProviderType.anthropic,
              messages: context.messages,
            ),
          ),
        ],
      );
    }
    // coverage:ignore-end

    final modelResult = await _ensureModelsExist(
      repository: repository,
      providerId: provider.id,
      modelConfigs: [
        (known: knownModels.reasoning, id: ftueAnthropicReasoningModelId),
        (known: knownModels.flash, id: ftueAnthropicFlashModelId),
      ],
      excludedProviderModelIds: excludedProviderModelIds,
    );

    final (category, categoryWasCreated) = await _createOrReuseCategory(
      categoryRepository: categoryRepository,
      categoryName: ftueAnthropicCategoryName,
      categoryColor: ftueAnthropicCategoryColor,
      defaultProfileId: profileAnthropicId,
    );

    return AnthropicFtueResult(
      modelsCreated: modelResult.created.length,
      modelsVerified: modelResult.verified.length,
      categoryCreated: categoryWasCreated,
      categoryReused: !categoryWasCreated && category != null,
      categoryName: category?.name,
    );
  }
}

// =============================================================================
// Ollama FTUE (First Time User Experience) Setup
// =============================================================================

/// Result of the Ollama FTUE setup process.
///
/// Unlike the cloud providers, Ollama serves whatever models the user has
/// pulled locally — there is no canonical set we can pre-create. PR-1 only
/// installs the test category and the seeded `Local (Ollama)` profile; the
/// new connect modal (PR-2) will hit `/api/tags` to enumerate the user's
/// installed models and create rows for the ones they pick.
class OllamaFtueResult extends AiFtueResult {
  const OllamaFtueResult({
    required super.categoryCreated,
    super.categoryReused,
    super.categoryName,
    super.errors,
  }) : super(modelsCreated: 0, modelsVerified: 0);
}

/// Extension to add Ollama FTUE functionality to ProviderPromptSetupService.
extension OllamaFtueSetup on ProviderPromptSetupService {
  /// Performs FTUE setup for Ollama providers.
  ///
  /// Creates the shared FTUE test category bound to the seeded
  /// `Local (Ollama)` profile. No models are created at this stage —
  /// users pull whatever they want locally and the connect modal (PR-2)
  /// will enumerate them via `/api/tags`.
  ///
  /// The [excludedProviderModelIds] parameter is unused (Ollama has no
  /// preset to exclude from) but kept for signature symmetry with the
  /// other per-provider helpers — `runFtueSetupForType` dispatches by
  /// type and passes the same set to every arm.
  Future<OllamaFtueResult?> performOllamaFtueSetup({
    required BuildContext context,
    required WidgetRef ref,
    required AiConfigInferenceProvider provider,
    Set<String> excludedProviderModelIds = const {},
  }) async {
    if (provider.inferenceProviderType != InferenceProviderType.ollama) {
      return null;
    }

    final categoryRepository = ref.read(categoryRepositoryProvider);

    final (category, categoryWasCreated) = await _createOrReuseCategory(
      categoryRepository: categoryRepository,
      categoryName: ftueOllamaCategoryName,
      categoryColor: ftueOllamaCategoryColor,
      defaultProfileId: profileLocalId,
    );

    return OllamaFtueResult(
      categoryCreated: categoryWasCreated,
      categoryReused: !categoryWasCreated && category != null,
      categoryName: category?.name,
    );
  }
}
