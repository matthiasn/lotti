import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
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

/// Result of the Gemini FTUE setup process.
class GeminiFtueResult {
  const GeminiFtueResult({
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

/// Extension to add Gemini FTUE functionality to ProviderPromptSetupService.
extension GeminiFtueSetup on ProviderPromptSetupService {
  /// Performs comprehensive FTUE setup for Gemini providers.
  ///
  /// This creates:
  /// 1. Three models (Flash, Pro, Nano Banana Pro) if they don't exist
  /// 2. A test category with auto-selection configured
  ///
  /// Returns [GeminiFtueResult] with details of what was created.
  Future<GeminiFtueResult?> performGeminiFtueSetup({
    required BuildContext context,
    required WidgetRef ref,
    required AiConfigInferenceProvider provider,
  }) async {
    // Only works with Gemini providers
    if (provider.inferenceProviderType != InferenceProviderType.gemini) {
      return null;
    }

    final repository = ref.read(aiConfigRepositoryProvider);
    final categoryRepository = ref.read(categoryRepositoryProvider);

    // Step 1: Create/verify models
    final modelResult = await _ensureFtueModelsExist(
      repository: repository,
      providerId: provider.id,
    );

    if (modelResult == null) {
      return const GeminiFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        categoryCreated: false,
        errors: ['Failed to find required Gemini model configurations'],
      );
    }

    // Step 2: Create or update category
    final (category, categoryWasCreated) = await _createOrReuseFtueCategory(
      categoryRepository: categoryRepository,
    );

    return GeminiFtueResult(
      modelsCreated: modelResult.created.length,
      modelsVerified: modelResult.verified.length,
      categoryCreated: categoryWasCreated,
      categoryReused: !categoryWasCreated && category != null,
      categoryName: category?.name,
    );
  }

  /// Ensures the three FTUE models exist for the given provider.
  Future<_FtueModelResult?> _ensureFtueModelsExist({
    required AiConfigRepository repository,
    required String providerId,
  }) async {
    final knownModels = getFtueKnownModels();
    if (knownModels == null) {
      return null;
    }

    final allModels = await repository.getConfigsByType(AiConfigType.model);
    final providerModels = allModels
        .whereType<AiConfigModel>()
        .where((m) => m.inferenceProviderId == providerId)
        .toList();

    final created = <AiConfigModel>[];
    final verified = <AiConfigModel>[];
    const uuid = Uuid();

    // Process each model type
    final modelConfigs = [
      (known: knownModels.flash, id: ftueFlashModelId),
      (known: knownModels.pro, id: ftueProModelId),
      (known: knownModels.image, id: ftueImageModelId),
    ];

    AiConfigModel? flashModel;
    AiConfigModel? proModel;
    AiConfigModel? imageModel;

    for (final config in modelConfigs) {
      // Check if model with same providerModelId already exists
      final existing = providerModels.firstWhereOrNull(
        (m) => m.providerModelId == config.id,
      );

      AiConfigModel model;
      if (existing != null) {
        verified.add(existing);
        model = existing;
      } else {
        // Create new model
        model = config.known.toAiConfigModel(
          id: uuid.v4(),
          inferenceProviderId: providerId,
        );
        await repository.saveConfig(model);
        created.add(model);
      }

      // Assign to appropriate variable
      if (config.id == ftueFlashModelId) {
        flashModel = model;
      } else if (config.id == ftueProModelId) {
        proModel = model;
      } else if (config.id == ftueImageModelId) {
        imageModel = model;
      }
    }

    if (flashModel == null || proModel == null || imageModel == null) {
      return null;
    }

    return _FtueModelResult(
      flash: flashModel,
      pro: proModel,
      image: imageModel,
      created: created,
      verified: verified,
    );
  }

  /// Creates or reuses the FTUE test category.
  ///
  /// If the category already exists, it is reused as-is.
  /// Returns a tuple of (category, wasCreated) where wasCreated is true if
  /// a new category was created, false if an existing one was reused.
  Future<(CategoryDefinition?, bool)> _createOrReuseFtueCategory({
    required CategoryRepository categoryRepository,
  }) async {
    const categoryName = ftueGeminiCategoryName;

    // Check if category already exists
    final allCategories = await categoryRepository.getAllCategories();
    final existingCategory = allCategories
        .where((c) => c.name == categoryName && c.deletedAt == null)
        .firstOrNull;

    if (existingCategory != null) {
      return (existingCategory, false); // false = reused, not created
    }

    // Create new category
    final category = await categoryRepository.createCategory(
      name: categoryName,
      color: ftueGeminiCategoryColor,
    );

    return (category, true); // true = was created
  }
}

/// Internal result class for model creation.
class _FtueModelResult {
  const _FtueModelResult({
    required this.flash,
    required this.pro,
    required this.image,
    required this.created,
    required this.verified,
  });

  final AiConfigModel flash;
  final AiConfigModel pro;
  final AiConfigModel image;
  final List<AiConfigModel> created;
  final List<AiConfigModel> verified;
}

// =============================================================================
// OpenAI FTUE (First Time User Experience) Setup
// =============================================================================

/// Result of the OpenAI FTUE setup process.
class OpenAiFtueResult {
  const OpenAiFtueResult({
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

/// Extension to add OpenAI FTUE functionality to ProviderPromptSetupService.
extension OpenAiFtueSetup on ProviderPromptSetupService {
  /// Performs comprehensive FTUE setup for OpenAI providers.
  ///
  /// This creates:
  /// 1. Four models (Flash/GPT-5 Nano, Reasoning/GPT-5.2, Audio/GPT-4o
  ///    Transcribe, Image/GPT Image 1.5)
  /// 2. A test category with auto-selection configured
  ///
  /// Returns [OpenAiFtueResult] with details of what was created.
  Future<OpenAiFtueResult?> performOpenAiFtueSetup({
    required BuildContext context,
    required WidgetRef ref,
    required AiConfigInferenceProvider provider,
  }) async {
    // Only works with OpenAI providers
    if (provider.inferenceProviderType != InferenceProviderType.openAi) {
      return null;
    }

    final repository = ref.read(aiConfigRepositoryProvider);
    final categoryRepository = ref.read(categoryRepositoryProvider);

    // Step 1: Create/verify models
    final modelResult = await _ensureOpenAiFtueModelsExist(
      repository: repository,
      providerId: provider.id,
    );

    if (modelResult == null) {
      return const OpenAiFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        categoryCreated: false,
        errors: ['Failed to find required OpenAI model configurations'],
      );
    }

    // Step 2: Create or update category with auto-selection
    final (
      category,
      categoryWasCreated,
    ) = await _createOrReuseOpenAiFtueCategory(
      categoryRepository: categoryRepository,
    );

    return OpenAiFtueResult(
      modelsCreated: modelResult.created.length,
      modelsVerified: modelResult.verified.length,
      categoryCreated: categoryWasCreated,
      categoryReused: !categoryWasCreated && category != null,
      categoryName: category?.name,
    );
  }

  /// Ensures the four FTUE models exist for the given OpenAI provider.
  Future<_OpenAiFtueModelResult?> _ensureOpenAiFtueModelsExist({
    required AiConfigRepository repository,
    required String providerId,
  }) async {
    final knownModels = getOpenAiFtueKnownModels();
    if (knownModels == null) {
      return null;
    }

    final allModels = await repository.getConfigsByType(AiConfigType.model);
    final providerModels = allModels
        .whereType<AiConfigModel>()
        .where((m) => m.inferenceProviderId == providerId)
        .toList();

    final created = <AiConfigModel>[];
    final verified = <AiConfigModel>[];
    const uuid = Uuid();

    // Process each model type
    final modelConfigs = [
      (known: knownModels.flash, id: ftueOpenAiFlashModelId),
      (known: knownModels.reasoning, id: ftueOpenAiReasoningModelId),
      (known: knownModels.audio, id: ftueOpenAiAudioModelId),
      (known: knownModels.image, id: ftueOpenAiImageModelId),
    ];

    AiConfigModel? flashModel;
    AiConfigModel? reasoningModel;
    AiConfigModel? audioModel;
    AiConfigModel? imageModel;

    for (final config in modelConfigs) {
      // Check if model with same providerModelId already exists
      final existing = providerModels.firstWhereOrNull(
        (m) => m.providerModelId == config.id,
      );

      AiConfigModel model;
      if (existing != null) {
        verified.add(existing);
        model = existing;
      } else {
        // Create new model
        model = config.known.toAiConfigModel(
          id: uuid.v4(),
          inferenceProviderId: providerId,
        );
        await repository.saveConfig(model);
        created.add(model);
      }

      // Assign to appropriate variable
      if (config.id == ftueOpenAiFlashModelId) {
        flashModel = model;
      } else if (config.id == ftueOpenAiReasoningModelId) {
        reasoningModel = model;
      } else if (config.id == ftueOpenAiAudioModelId) {
        audioModel = model;
      } else if (config.id == ftueOpenAiImageModelId) {
        imageModel = model;
      }
    }

    if (flashModel == null ||
        reasoningModel == null ||
        audioModel == null ||
        imageModel == null) {
      return null;
    }

    return _OpenAiFtueModelResult(
      flash: flashModel,
      reasoning: reasoningModel,
      audio: audioModel,
      image: imageModel,
      created: created,
      verified: verified,
    );
  }

  /// Creates or reuses the FTUE test category for OpenAI.
  ///
  /// If the category already exists, it is reused as-is.
  /// Returns a tuple of (category, wasCreated).
  Future<(CategoryDefinition?, bool)> _createOrReuseOpenAiFtueCategory({
    required CategoryRepository categoryRepository,
  }) async {
    const categoryName = ftueOpenAiCategoryName;

    // Check if category already exists
    final allCategories = await categoryRepository.getAllCategories();
    final existingCategory = allCategories
        .where((c) => c.name == categoryName && c.deletedAt == null)
        .firstOrNull;

    if (existingCategory != null) {
      return (existingCategory, false);
    }

    // Create new category
    final category = await categoryRepository.createCategory(
      name: categoryName,
      color: ftueOpenAiCategoryColor,
    );

    return (category, true);
  }
}

/// Internal result class for OpenAI model creation.
class _OpenAiFtueModelResult {
  const _OpenAiFtueModelResult({
    required this.flash,
    required this.reasoning,
    required this.audio,
    required this.image,
    required this.created,
    required this.verified,
  });

  final AiConfigModel flash;
  final AiConfigModel reasoning;
  final AiConfigModel audio;
  final AiConfigModel image;
  final List<AiConfigModel> created;
  final List<AiConfigModel> verified;
}

// =============================================================================
// Mistral FTUE (First Time User Experience) Setup
// =============================================================================

/// Result of the Mistral FTUE setup process.
class MistralFtueResult {
  const MistralFtueResult({
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

/// Extension to add Mistral FTUE functionality to ProviderPromptSetupService.
extension MistralFtueSetup on ProviderPromptSetupService {
  /// Performs comprehensive FTUE setup for Mistral providers.
  ///
  /// This creates:
  /// 1. Three models (Fast/Mistral Small, Reasoning/Magistral Medium,
  ///    Audio/Voxtral Mini)
  /// 2. A test category with auto-selection configured
  ///
  /// Returns [MistralFtueResult] with details of what was created.
  Future<MistralFtueResult?> performMistralFtueSetup({
    required BuildContext context,
    required WidgetRef ref,
    required AiConfigInferenceProvider provider,
  }) async {
    // Only works with Mistral providers
    if (provider.inferenceProviderType != InferenceProviderType.mistral) {
      return null;
    }

    final repository = ref.read(aiConfigRepositoryProvider);
    final categoryRepository = ref.read(categoryRepositoryProvider);

    // Step 1: Create/verify models
    final modelResult = await _ensureMistralFtueModelsExist(
      repository: repository,
      providerId: provider.id,
    );

    if (modelResult == null) {
      return const MistralFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        categoryCreated: false,
        errors: ['Failed to find required Mistral model configurations'],
      );
    }

    // Step 2: Create or update category with auto-selection
    final (
      category,
      categoryWasCreated,
    ) = await _createOrReuseMistralFtueCategory(
      categoryRepository: categoryRepository,
    );

    return MistralFtueResult(
      modelsCreated: modelResult.created.length,
      modelsVerified: modelResult.verified.length,
      categoryCreated: categoryWasCreated,
      categoryReused: !categoryWasCreated && category != null,
      categoryName: category?.name,
    );
  }

  /// Ensures the three FTUE models exist for the given Mistral provider.
  Future<_MistralFtueModelResult?> _ensureMistralFtueModelsExist({
    required AiConfigRepository repository,
    required String providerId,
  }) async {
    final knownModels = getMistralFtueKnownModels();
    if (knownModels == null) {
      return null;
    }

    final allModels = await repository.getConfigsByType(AiConfigType.model);
    final providerModels = allModels
        .whereType<AiConfigModel>()
        .where((m) => m.inferenceProviderId == providerId)
        .toList();

    final created = <AiConfigModel>[];
    final verified = <AiConfigModel>[];
    const uuid = Uuid();

    // Process each model type
    final modelConfigs = [
      (known: knownModels.flash, id: ftueMistralFlashModelId),
      (known: knownModels.reasoning, id: ftueMistralReasoningModelId),
      (known: knownModels.audio, id: ftueMistralAudioModelId),
    ];

    AiConfigModel? flashModel;
    AiConfigModel? reasoningModel;
    AiConfigModel? audioModel;

    for (final config in modelConfigs) {
      // Check if model with same providerModelId already exists
      final existing = providerModels.firstWhereOrNull(
        (m) => m.providerModelId == config.id,
      );

      AiConfigModel model;
      if (existing != null) {
        verified.add(existing);
        model = existing;
      } else {
        // Create new model
        model = config.known.toAiConfigModel(
          id: uuid.v4(),
          inferenceProviderId: providerId,
        );
        await repository.saveConfig(model);
        created.add(model);
      }

      // Assign to appropriate variable
      switch (config.id) {
        case ftueMistralFlashModelId:
          flashModel = model;
        case ftueMistralReasoningModelId:
          reasoningModel = model;
        case ftueMistralAudioModelId:
          audioModel = model;
      }
    }

    if (flashModel == null || reasoningModel == null || audioModel == null) {
      return null;
    }

    return _MistralFtueModelResult(
      flash: flashModel,
      reasoning: reasoningModel,
      audio: audioModel,
      created: created,
      verified: verified,
    );
  }

  /// Creates or reuses the FTUE test category for Mistral.
  ///
  /// If the category already exists, it is reused as-is.
  /// Returns a tuple of (category, wasCreated).
  Future<(CategoryDefinition?, bool)> _createOrReuseMistralFtueCategory({
    required CategoryRepository categoryRepository,
  }) async {
    const categoryName = ftueMistralCategoryName;

    // Check if category already exists
    final allCategories = await categoryRepository.getAllCategories();
    final existingCategory = allCategories
        .where((c) => c.name == categoryName && c.deletedAt == null)
        .firstOrNull;

    if (existingCategory != null) {
      return (existingCategory, false);
    }

    // Create new category
    final category = await categoryRepository.createCategory(
      name: categoryName,
      color: ftueMistralCategoryColor,
    );

    return (category, true);
  }
}

/// Internal result class for Mistral model creation.
class _MistralFtueModelResult {
  const _MistralFtueModelResult({
    required this.flash,
    required this.reasoning,
    required this.audio,
    required this.created,
    required this.verified,
  });

  final AiConfigModel flash;
  final AiConfigModel reasoning;
  final AiConfigModel audio;
  final List<AiConfigModel> created;
  final List<AiConfigModel> verified;
}

// =============================================================================
// Alibaba FTUE (First Time User Experience) Setup
// =============================================================================

/// Result of the Alibaba FTUE setup process.
class AlibabaFtueResult {
  const AlibabaFtueResult({
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

/// Extension to add Alibaba FTUE functionality to ProviderPromptSetupService.
extension AlibabaFtueSetup on ProviderPromptSetupService {
  /// Performs comprehensive FTUE setup for Alibaba providers.
  ///
  /// This creates:
  /// 1. Five models (Flash/Qwen Flash, Reasoning/Qwen 3.5 Plus,
  ///    Audio/Qwen3 Omni Flash, Vision/Qwen3 VL Flash, Image/Wan 2.6)
  /// 2. A test category with auto-selection configured
  ///
  /// The Chinese AI Profile (inference profile) is automatically created
  /// by ProfileSeedingService on app startup and links to these models.
  ///
  /// Returns [AlibabaFtueResult] with details of what was created.
  Future<AlibabaFtueResult?> performAlibabaFtueSetup({
    required BuildContext context,
    required WidgetRef ref,
    required AiConfigInferenceProvider provider,
  }) async {
    // Only works with Alibaba providers
    if (provider.inferenceProviderType != InferenceProviderType.alibaba) {
      return null;
    }

    final repository = ref.read(aiConfigRepositoryProvider);
    final categoryRepository = ref.read(categoryRepositoryProvider);

    // Step 1: Create/verify models
    final modelResult = await _ensureAlibabaFtueModelsExist(
      repository: repository,
      providerId: provider.id,
    );

    if (modelResult == null) {
      return const AlibabaFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        categoryCreated: false,
        errors: ['Failed to find required Alibaba model configurations'],
      );
    }

    // Step 2: Create or update category with auto-selection
    final (
      category,
      categoryWasCreated,
    ) = await _createOrReuseAlibabaFtueCategory(
      categoryRepository: categoryRepository,
    );

    return AlibabaFtueResult(
      modelsCreated: modelResult.created.length,
      modelsVerified: modelResult.verified.length,
      categoryCreated: categoryWasCreated,
      categoryReused: !categoryWasCreated && category != null,
      categoryName: category?.name,
    );
  }

  /// Ensures the five FTUE models exist for the given Alibaba provider.
  Future<_AlibabaFtueModelResult?> _ensureAlibabaFtueModelsExist({
    required AiConfigRepository repository,
    required String providerId,
  }) async {
    final knownModels = getAlibabaFtueKnownModels();
    if (knownModels == null) {
      return null;
    }

    final allModels = await repository.getConfigsByType(AiConfigType.model);
    final providerModels = allModels
        .whereType<AiConfigModel>()
        .where((m) => m.inferenceProviderId == providerId)
        .toList();

    final created = <AiConfigModel>[];
    final verified = <AiConfigModel>[];
    const uuid = Uuid();

    // Enum-keyed map ensures the compiler catches missing roles.
    final modelConfigs = {
      _AlibabaModelRole.flash: (
        known: knownModels.flash,
        id: ftueAlibabaFlashModelId,
      ),
      _AlibabaModelRole.reasoning: (
        known: knownModels.reasoning,
        id: ftueAlibabaReasoningModelId,
      ),
      _AlibabaModelRole.audio: (
        known: knownModels.audio,
        id: ftueAlibabaAudioModelId,
      ),
      _AlibabaModelRole.vision: (
        known: knownModels.vision,
        id: ftueAlibabaVisionModelId,
      ),
      _AlibabaModelRole.image: (
        known: knownModels.image,
        id: ftueAlibabaImageModelId,
      ),
    };

    final resolved = <_AlibabaModelRole, AiConfigModel>{};

    for (final entry in modelConfigs.entries) {
      final config = entry.value;

      // Check if model with same providerModelId already exists
      final existing = providerModels.firstWhereOrNull(
        (m) => m.providerModelId == config.id,
      );

      AiConfigModel model;
      if (existing != null) {
        verified.add(existing);
        model = existing;
      } else {
        model = config.known.toAiConfigModel(
          id: uuid.v4(),
          inferenceProviderId: providerId,
        );
        await repository.saveConfig(model);
        created.add(model);
      }

      resolved[entry.key] = model;
    }

    // Verify all roles were resolved
    final flash = resolved[_AlibabaModelRole.flash];
    final reasoning = resolved[_AlibabaModelRole.reasoning];
    final audio = resolved[_AlibabaModelRole.audio];
    final vision = resolved[_AlibabaModelRole.vision];
    final image = resolved[_AlibabaModelRole.image];

    if (flash == null ||
        reasoning == null ||
        audio == null ||
        vision == null ||
        image == null) {
      return null;
    }

    return _AlibabaFtueModelResult(
      flash: flash,
      reasoning: reasoning,
      audio: audio,
      vision: vision,
      image: image,
      created: created,
      verified: verified,
    );
  }

  /// Creates or reuses the FTUE test category for Alibaba.
  ///
  /// If the category already exists, it is reused as-is.
  /// Returns a tuple of (category, wasCreated).
  Future<(CategoryDefinition?, bool)> _createOrReuseAlibabaFtueCategory({
    required CategoryRepository categoryRepository,
  }) async {
    const categoryName = ftueAlibabaCategoryName;

    // Check if category already exists
    final allCategories = await categoryRepository.getAllCategories();
    final existingCategory = allCategories
        .where((c) => c.name == categoryName && c.deletedAt == null)
        .firstOrNull;

    if (existingCategory != null) {
      return (existingCategory, false);
    }

    // Create new category with the Chinese AI Profile assigned
    final category = await categoryRepository.createCategory(
      name: categoryName,
      color: ftueAlibabaCategoryColor,
      defaultProfileId: profileAlibabaId,
    );

    return (category, true);
  }
}

/// Model roles for Alibaba FTUE setup.
///
/// Using an enum instead of raw String keys ensures the compiler catches
/// missing roles when the set of models changes.
enum _AlibabaModelRole { flash, reasoning, audio, vision, image }

/// Internal result class for Alibaba model creation.
class _AlibabaFtueModelResult {
  const _AlibabaFtueModelResult({
    required this.flash,
    required this.reasoning,
    required this.audio,
    required this.vision,
    required this.image,
    required this.created,
    required this.verified,
  });

  final AiConfigModel flash;
  final AiConfigModel reasoning;
  final AiConfigModel audio;
  final AiConfigModel vision;
  final AiConfigModel image;
  final List<AiConfigModel> created;
  final List<AiConfigModel> verified;
}
