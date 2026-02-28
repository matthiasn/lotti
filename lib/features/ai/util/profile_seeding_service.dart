import 'dart:developer' as developer;

import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';

/// Well-known IDs for default inference profiles (idempotent seeding).
const profileGeminiFlashId = 'profile-gemini-flash-001';
const profileGeminiProId = 'profile-gemini-pro-001';
const profileOpenAiId = 'profile-openai-001';
const profileMistralEuId = 'profile-mistral-eu-001';
const profileAlibabaId = 'profile-alibaba-001';
const profileLocalId = 'profile-local-001';

const _logTag = 'ProfileSeedingService';

/// Seeds default inference profiles into the AI config database.
///
/// Follows the same idempotent pattern as `AgentTemplateService.seedDefaults()`:
/// checks each profile by ID and skips if it already exists.
class ProfileSeedingService {
  const ProfileSeedingService({
    required AiConfigRepository aiConfigRepository,
  }) : _repo = aiConfigRepository;

  final AiConfigRepository _repo;

  /// Seeds all default profiles. Safe to call multiple times.
  Future<void> seedDefaults() async {
    var seededCount = 0;

    for (final profile in _defaultProfiles) {
      final existing = await _repo.getConfigById(profile.id);
      if (existing != null) continue;

      await _repo.saveConfig(profile);
      seededCount++;
    }

    if (seededCount > 0) {
      developer.log(
        'Seeded $seededCount default inference profiles',
        name: _logTag,
      );
    } else {
      developer.log(
        'Default inference profiles already seeded, skipping',
        name: _logTag,
      );
    }
  }

  static final _defaultProfiles = <AiConfigInferenceProfile>[
    AiConfigInferenceProfile(
      id: profileGeminiFlashId,
      name: 'Gemini Flash',
      thinkingModelId: 'models/gemini-3-flash-preview',
      imageRecognitionModelId: 'models/gemini-3-flash-preview',
      transcriptionModelId: 'models/gemini-3-flash-preview',
      imageGenerationModelId: 'models/gemini-3-pro-image-preview',
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
      isDefault: true,
      createdAt: DateTime(2026),
    ),
    AiConfigInferenceProfile(
      id: profileMistralEuId,
      name: 'Mistral (EU)',
      thinkingModelId: 'magistral-medium-2509',
      imageRecognitionModelId: 'mistral-small-2501',
      transcriptionModelId: 'voxtral-mini-latest',
      isDefault: true,
      createdAt: DateTime(2026),
    ),
    AiConfigInferenceProfile(
      id: profileAlibabaId,
      name: 'Alibaba',
      thinkingModelId: 'qwen3-max',
      imageRecognitionModelId: 'qwen3-vl-flash',
      transcriptionModelId: 'qwen3-omni-flash',
      imageGenerationModelId: 'wan2.6-image',
      isDefault: true,
      createdAt: DateTime(2026),
    ),
    AiConfigInferenceProfile(
      id: profileLocalId,
      name: 'Local (Ollama)',
      thinkingModelId: 'qwen3:8b',
      imageRecognitionModelId: 'gemma3:4b',
      isDefault: true,
      desktopOnly: true,
      createdAt: DateTime(2026),
    ),
  ];
}
