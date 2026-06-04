import 'dart:developer' as developer;

import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/consts.dart';

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
/// when missing. Existing profiles are never overwritten — user edits to
/// model slots, flags, names, and skill assignments survive across restarts
/// and app upgrades.
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

    for (final profile in defaultProfiles) {
      final existing = await _repo.getConfigById(profile.id);
      if (existing != null) continue;
      await _repo.saveConfig(profile);
      seededCount++;
    }

    if (seededCount > 0) {
      developer.log('Profiles: seeded $seededCount', name: _logTag);
    }
  }

  /// Upgrades existing default profiles that have empty `skillAssignments`.
  ///
  /// This is a one-time backfill on app upgrade that enables automation for
  /// default profiles. Only touches profiles with `isDefault: true` and
  /// empty `skillAssignments`.
  Future<void> upgradeExisting() async {
    var upgradedCount = 0;

    for (final template in defaultProfiles) {
      final existing = await _repo.getConfigById(template.id);
      if (existing == null) continue;

      // Only upgrade default profiles with empty skill assignments.
      if (existing is! AiConfigInferenceProfile) continue;
      if (!existing.isDefault) continue;
      if (existing.skillAssignments.isNotEmpty) continue;

      // Apply the template's skill assignments, but only for slots that
      // are still configured on the existing profile.
      if (template.skillAssignments.isEmpty) continue;

      final sanitized = template.skillAssignments.where((a) {
        final skill = findBuiltInSkill(a.skillId);
        if (skill == null) return true; // keep unknown skills as-is
        return _hasSlotForSkillType(existing, skill.skillType);
      }).toList();

      if (sanitized.isEmpty) continue;

      final upgraded = existing.copyWith(
        skillAssignments: sanitized,
      );
      await _repo.saveConfig(upgraded);
      upgradedCount++;
    }

    if (upgradedCount > 0) {
      developer.log(
        'Upgraded $upgradedCount default profiles with skill assignments',
        name: _logTag,
      );
    }
  }

  /// Returns true when the profile has the model slot required by [skillType].
  static bool _hasSlotForSkillType(
    AiConfigInferenceProfile profile,
    SkillType skillType,
  ) {
    return switch (skillType) {
      SkillType.transcription => profile.transcriptionModelId != null,
      SkillType.imageAnalysis => profile.imageRecognitionModelId != null,
      SkillType.imageGeneration => profile.imageGenerationModelId != null,
      SkillType.promptGeneration => true, // uses thinking model
      SkillType.imagePromptGeneration => true, // uses thinking model
    };
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
      name: 'Local Power (Ollama)',
      thinkingModelId: 'qwen3.6:35b-a3b-coding-nvfp4',
      imageRecognitionModelId: 'qwen3.5:27b',
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
