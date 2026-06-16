import 'dart:developer' as developer;

import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:meta/meta.dart';

/// Well-known IDs for default inference profiles (idempotent seeding).
const profileGeminiFlashId = 'profile-gemini-flash-001';
const profileGeminiProId = 'profile-gemini-pro-001';
const profileOpenAiId = 'profile-openai-001';
const profileMistralEuId = 'profile-mistral-eu-001';
const profileAlibabaId = 'profile-alibaba-001';
const profileAnthropicId = 'profile-anthropic-001';
const profileLocalId = 'profile-local-001';
const profileLocalPowerId = 'profile-local-power-001';
const profileLocalGemmaId = 'profile-local-gemma-001';
const profileLocalGemmaPowerId = 'profile-local-gemma-power-001';

const _logTag = 'ProfileSeedingService';
const _localPowerName = 'Local Power (oMLX)';
const _legacyLocalPowerName = 'Local Power (Ollama)';
const _legacyLocalPowerThinkingModelId = 'qwen3.6:35b-a3b-coding-nvfp4';
const _legacyLocalPowerImageModelId = 'qwen3.5:27b';

/// Default skill assignments for profiles with transcription + image
/// recognition model slots. Uses `skillTranscribeContextId` which has
/// `contextPolicy: fullTask` for richer context-aware transcription.
const _defaultSkillAssignments = [
  SkillAssignment(skillId: skillTranscribeContextId, automate: true),
  SkillAssignment(skillId: skillImageAnalysisContextId, automate: true),
];

/// Skill assignments for Mistral (EU) — uses the basic transcription skill
/// which has `contextPolicy: dictionaryOnly`, suitable for Voxtral's
/// more limited context window.
const _mistralSkillAssignments = [
  SkillAssignment(skillId: skillTranscribeId, automate: true),
  SkillAssignment(skillId: skillImageAnalysisContextId, automate: true),
];

/// Seeds default inference profiles into the AI config database.
///
/// Strictly seed-on-create: each profile is checked by ID and only written
/// when missing. Existing profiles are not overwritten during seeding; targeted
/// upgrade migrations live in [upgradeExisting] and preserve user-authored
/// model slots, flags, names, and skill assignments.
class ProfileSeedingService {
  const ProfileSeedingService({
    required AiConfigRepository aiConfigRepository,
  }) : _repo = aiConfigRepository;

  final AiConfigRepository _repo;

  /// Seeds all default profiles. Safe to call multiple times.
  ///
  /// Only creates profiles that do not already exist by ID. Existing
  /// profiles — even if their model IDs or flags differ from the seed
  /// targets in code — are left untouched. This preserves user edits to
  /// the bundled defaults (e.g. swapping the Ollama profile's thinking
  /// model) across app restarts.
  Future<void> seedDefaults() async {
    var seededCount = 0;
    final models = await _fetchModelRows();

    for (final template in defaultProfiles) {
      final existing = await _repo.getConfigById(template.id);
      if (existing != null) continue;
      final profile = _withResolvedModelConfigIds(template, models);
      await _repo.saveConfig(profile);
      seededCount++;
    }

    if (seededCount > 0) {
      developer.log('Profiles: seeded $seededCount', name: _logTag);
    }
  }

  /// Upgrades existing profiles without overwriting user-authored choices.
  ///
  /// This migrates legacy provider-native profile slot values to
  /// `AiConfigModel.id` when the match is unambiguous, migrates the untouched
  /// old Local Power seed from Ollama to oMLX, then backfills default skill
  /// assignments only for default profiles whose assignments are empty.
  Future<void> upgradeExisting() async {
    var upgradedCount = 0;
    final models = await _fetchModelRows();
    final templatesById = {
      for (final template in defaultProfiles) template.id: template,
    };
    final configs = await _repo.getConfigsByType(AiConfigType.inferenceProfile);

    for (final config in configs.whereType<AiConfigInferenceProfile>()) {
      var upgraded = _withMigratedLegacyLocalPowerSeed(config, models);
      upgraded = _withResolvedModelConfigIds(upgraded, models);
      final template = templatesById[config.id];

      // Only backfill default skill assignments for default profiles with
      // empty assignments. Non-empty assignment lists and non-default profiles
      // are user-authored and must be preserved.
      if (template != null &&
          config.isDefault &&
          config.skillAssignments.isEmpty &&
          template.skillAssignments.isNotEmpty) {
        final sanitized = template.skillAssignments.where((a) {
          final skill = findBuiltInSkill(a.skillId);
          if (skill == null) return true; // keep unknown skills as-is
          return hasSlotForSkillType(upgraded, skill.skillType, models);
        }).toList();

        if (sanitized.isNotEmpty) {
          upgraded = upgraded.copyWith(skillAssignments: sanitized);
        }
      }

      if (upgraded == config) continue;
      await _repo.saveConfig(upgraded);
      upgradedCount++;
    }

    if (upgradedCount > 0) {
      developer.log(
        'Upgraded $upgradedCount inference profiles',
        name: _logTag,
      );
    }
  }

  static AiConfigInferenceProfile _withMigratedLegacyLocalPowerSeed(
    AiConfigInferenceProfile profile,
    List<AiConfigModel> models,
  ) {
    if (!_isUntouchedLegacyLocalPowerSeed(profile, models)) return profile;

    return profile.copyWith(
      name: _localPowerName,
      thinkingModelId: omlxRecommendedMultimodalModelId,
      imageRecognitionModelId: omlxRecommendedMultimodalModelId,
    );
  }

  static bool _isUntouchedLegacyLocalPowerSeed(
    AiConfigInferenceProfile profile,
    List<AiConfigModel> models,
  ) {
    return profile.id == profileLocalPowerId &&
        profile.name == _legacyLocalPowerName &&
        profile.description == null &&
        profile.thinkingHighEndModelId == null &&
        _slotMatchesProviderModelId(
          profile.thinkingModelId,
          _legacyLocalPowerThinkingModelId,
          models,
        ) &&
        _slotMatchesProviderModelId(
          profile.imageRecognitionModelId,
          _legacyLocalPowerImageModelId,
          models,
        ) &&
        profile.transcriptionModelId == null &&
        profile.imageGenerationModelId == null &&
        !profile.isDefault &&
        profile.desktopOnly &&
        profile.skillAssignments.isEmpty &&
        profile.pinnedHostId == null;
  }

  static bool _slotMatchesProviderModelId(
    String? slotValue,
    String providerModelId,
    List<AiConfigModel> models,
  ) {
    if (slotValue == providerModelId) return true;
    return models.any(
      (model) =>
          model.id == slotValue && model.providerModelId == providerModelId,
    );
  }

  Future<List<AiConfigModel>> _fetchModelRows() async {
    final configs = await _repo.getConfigsByType(AiConfigType.model);
    return configs.whereType<AiConfigModel>().toList(growable: false);
  }

  static AiConfigInferenceProfile _withResolvedModelConfigIds(
    AiConfigInferenceProfile profile,
    List<AiConfigModel> models,
  ) {
    return profile.copyWith(
      thinkingModelId: _resolveModelSlot(profile.thinkingModelId, models),
      thinkingHighEndModelId: _resolveOptionalModelSlot(
        profile.thinkingHighEndModelId,
        models,
      ),
      imageRecognitionModelId: _resolveOptionalModelSlot(
        profile.imageRecognitionModelId,
        models,
      ),
      transcriptionModelId: _resolveOptionalModelSlot(
        profile.transcriptionModelId,
        models,
      ),
      imageGenerationModelId: _resolveOptionalModelSlot(
        profile.imageGenerationModelId,
        models,
      ),
    );
  }

  static String? _resolveOptionalModelSlot(
    String? slotValue,
    List<AiConfigModel> models,
  ) {
    if (slotValue == null) return null;
    return _resolveModelSlot(slotValue, models);
  }

  static String _resolveModelSlot(
    String slotValue,
    List<AiConfigModel> models,
  ) {
    if (models.any((model) => model.id == slotValue)) return slotValue;

    final matches = models
        .where((model) => model.providerModelId == slotValue)
        .toList(growable: false);
    if (matches.length == 1) return matches.single.id;
    return slotValue;
  }

  /// Returns true when the profile's slot for [skillType] points at a real
  /// configured model row — by `AiConfigModel.id` or legacy
  /// `providerModelId`. A non-null slot value alone is not enough:
  /// `_withResolvedModelConfigIds` leaves unknown values untouched, and
  /// re-enabling a default skill on a slot with no backing model row would
  /// auto-enable broken automation.
  ///
  /// Visible for testing: the bundled default templates only carry
  /// transcription and image-analysis assignments, so the remaining switch
  /// arms are exercised directly.
  @visibleForTesting
  static bool hasSlotForSkillType(
    AiConfigInferenceProfile profile,
    SkillType skillType,
    List<AiConfigModel> models,
  ) {
    return switch (skillType) {
      SkillType.transcription => _slotResolvesToModelRow(
        profile.transcriptionModelId,
        models,
      ),
      SkillType.imageAnalysis => _slotResolvesToModelRow(
        profile.imageRecognitionModelId,
        models,
      ),
      SkillType.imageGeneration => _slotResolvesToModelRow(
        profile.imageGenerationModelId,
        models,
      ),
      // Prompt-generation skills run on the thinking slot (the high-end
      // slot falls back to it at resolution time).
      SkillType.promptGeneration => _slotResolvesToModelRow(
        profile.thinkingModelId,
        models,
      ),
      SkillType.imagePromptGeneration => _slotResolvesToModelRow(
        profile.thinkingModelId,
        models,
      ),
    };
  }

  /// True when [slotValue] matches a configured model row by exact
  /// `AiConfigModel.id` or by legacy `providerModelId`. Ambiguous legacy
  /// values (2+ rows) still count — the runtime resolver walks every
  /// candidate — but values with no matching row at all do not.
  static bool _slotResolvesToModelRow(
    String? slotValue,
    List<AiConfigModel> models,
  ) {
    if (slotValue == null) return false;
    return models.any(
      (model) => model.id == slotValue || model.providerModelId == slotValue,
    );
  }

  /// The default profile definitions.
  ///
  /// Exposed as a static list for testability.
  static final defaultProfiles = <AiConfigInferenceProfile>[
    AiConfigInferenceProfile(
      id: profileGeminiFlashId,
      name: 'Gemini Flash',
      thinkingModelId: 'models/gemini-3-flash-preview',
      imageRecognitionModelId: 'models/gemini-3-flash-preview',
      transcriptionModelId: 'models/gemini-3-flash-preview',
      imageGenerationModelId: 'models/gemini-3-pro-image-preview',
      skillAssignments: _defaultSkillAssignments,
      isDefault: true,
      createdAt: DateTime(2026),
    ),
    AiConfigInferenceProfile(
      id: profileGeminiProId,
      name: 'Gemini Pro',
      thinkingModelId: 'models/gemini-3.1-pro-preview',
      imageRecognitionModelId: 'models/gemini-3.1-pro-preview',
      transcriptionModelId: 'models/gemini-3.1-pro-preview',
      imageGenerationModelId: 'models/gemini-3-pro-image-preview',
      skillAssignments: _defaultSkillAssignments,
      isDefault: true,
      createdAt: DateTime(2026),
    ),
    AiConfigInferenceProfile(
      id: profileOpenAiId,
      name: 'OpenAI',
      thinkingModelId: 'gpt-5.2',
      imageRecognitionModelId: 'gpt-5-nano',
      transcriptionModelId: 'gpt-4o-transcribe',
      imageGenerationModelId: 'gpt-image-1.5',
      skillAssignments: _defaultSkillAssignments,
      isDefault: true,
      createdAt: DateTime(2026),
    ),
    AiConfigInferenceProfile(
      id: profileMistralEuId,
      name: 'Mistral (EU)',
      thinkingModelId: 'mistral-medium-latest',
      imageRecognitionModelId: 'mistral-medium-latest',
      transcriptionModelId: 'voxtral-mini-latest',
      skillAssignments: _mistralSkillAssignments,
      isDefault: true,
      createdAt: DateTime(2026),
    ),
    AiConfigInferenceProfile(
      id: profileAlibabaId,
      name: 'Chinese AI Profile',
      thinkingModelId: 'qwen3.5-plus',
      imageRecognitionModelId: 'qwen3-vl-flash',
      transcriptionModelId: 'qwen3-omni-flash',
      imageGenerationModelId: 'wan2.6-image',
      skillAssignments: _defaultSkillAssignments,
      isDefault: true,
      createdAt: DateTime(2026),
    ),
    AiConfigInferenceProfile(
      id: profileAnthropicId,
      name: 'Anthropic Claude',
      thinkingModelId: 'claude-sonnet-4-20250514',
      imageRecognitionModelId: 'claude-sonnet-4-20250514',
      // Anthropic ships no native transcription or image-generation models;
      // those slots stay unbound and the user can wire them to another
      // provider's model from the inference-profile editor.
      skillAssignments: [
        const SkillAssignment(
          skillId: skillImageAnalysisContextId,
          automate: true,
        ),
      ],
      isDefault: true,
      createdAt: DateTime(2026),
    ),
    AiConfigInferenceProfile(
      id: profileLocalId,
      name: 'Local (Ollama)',
      thinkingModelId: 'qwen3.5:9b',
      imageRecognitionModelId: 'qwen3.5:9b',
      skillAssignments: [
        // Ollama has no transcription model, only image analysis.
        const SkillAssignment(
          skillId: skillImageAnalysisContextId,
          automate: true,
        ),
      ],
      isDefault: true,
      desktopOnly: true,
      createdAt: DateTime(2026),
    ),
    AiConfigInferenceProfile(
      id: profileLocalPowerId,
      name: _localPowerName,
      thinkingModelId: omlxRecommendedMultimodalModelId,
      imageRecognitionModelId: omlxRecommendedMultimodalModelId,
      desktopOnly: true,
      createdAt: DateTime(2026),
    ),
    AiConfigInferenceProfile(
      id: profileLocalGemmaId,
      name: 'Local Gemma 4 (Ollama)',
      thinkingModelId: 'gemma4:26b',
      imageRecognitionModelId: 'gemma4:26b',
      skillAssignments: [
        const SkillAssignment(
          skillId: skillImageAnalysisContextId,
          automate: true,
        ),
      ],
      isDefault: true,
      desktopOnly: true,
      createdAt: DateTime(2026),
    ),
    AiConfigInferenceProfile(
      id: profileLocalGemmaPowerId,
      name: 'Local Gemma 4 Power (Ollama)',
      thinkingModelId: 'gemma4:31b',
      imageRecognitionModelId: 'gemma4:31b',
      desktopOnly: true,
      createdAt: DateTime(2026),
    ),
  ];
}
