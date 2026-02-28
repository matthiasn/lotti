import 'dart:developer' as developer;

import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/util/inference_provider_resolver.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';

const _logTag = 'ProfileResolver';

/// Resolves the inference profile for an agent wake.
///
/// Resolution order:
///   1. `agentConfig.profileId` (agent-level override)
///   2. `version.profileId` (version snapshot)
///   3. `template.profileId` (template default)
///   4. Legacy fallback: `version.modelId ?? template.modelId`
///
/// Only the thinking slot is fatal — if it cannot be resolved, `null` is
/// returned and the wake should be aborted. Other slots fail gracefully.
class ProfileResolver {
  const ProfileResolver({
    required AiConfigRepository aiConfigRepository,
  }) : _aiConfigRepository = aiConfigRepository;

  final AiConfigRepository _aiConfigRepository;

  /// Resolve a [ResolvedProfile] for the given agent context.
  ///
  /// Returns `null` if the thinking slot cannot be resolved (missing model or
  /// provider), which should abort the wake.
  Future<ResolvedProfile?> resolve({
    required AgentConfig agentConfig,
    required AgentTemplateEntity template,
    required AgentTemplateVersionEntity version,
  }) async {
    final profileId =
        agentConfig.profileId ?? version.profileId ?? template.profileId;

    if (profileId != null) {
      return _resolveFromProfile(profileId, template, version);
    }

    // Legacy fallback: use modelId directly for thinking slot only.
    return _resolveFromModelId(version.modelId ?? template.modelId);
  }

  Future<ResolvedProfile?> _resolveFromProfile(
    String profileId,
    AgentTemplateEntity template,
    AgentTemplateVersionEntity version,
  ) async {
    final config = await _aiConfigRepository.getConfigById(profileId);

    if (config is! AiConfigInferenceProfile) {
      developer.log(
        'Profile $profileId not found or wrong type, '
        'falling back to legacy modelId',
        name: _logTag,
      );
      // Fallback to legacy path when profile not found (e.g., sync race).
      return _resolveFromModelId(version.modelId ?? template.modelId);
    }

    // Resolve thinking slot (fatal if missing).
    final thinkingProvider = await resolveInferenceProvider(
      modelId: config.thinkingModelId,
      aiConfigRepository: _aiConfigRepository,
      logTag: _logTag,
    );
    if (thinkingProvider == null) {
      developer.log(
        'Cannot resolve thinking model ${config.thinkingModelId} '
        'for profile $profileId',
        name: _logTag,
      );
      return null;
    }

    // Resolve optional slots (non-fatal).
    final imageRecognitionProvider = config.imageRecognitionModelId != null
        ? await resolveInferenceProvider(
            modelId: config.imageRecognitionModelId!,
            aiConfigRepository: _aiConfigRepository,
            logTag: _logTag,
          )
        : null;

    final transcriptionProvider = config.transcriptionModelId != null
        ? await resolveInferenceProvider(
            modelId: config.transcriptionModelId!,
            aiConfigRepository: _aiConfigRepository,
            logTag: _logTag,
          )
        : null;

    final imageGenerationProvider = config.imageGenerationModelId != null
        ? await resolveInferenceProvider(
            modelId: config.imageGenerationModelId!,
            aiConfigRepository: _aiConfigRepository,
            logTag: _logTag,
          )
        : null;

    return ResolvedProfile(
      thinkingModelId: config.thinkingModelId,
      thinkingProvider: thinkingProvider,
      imageRecognitionModelId: config.imageRecognitionModelId,
      imageRecognitionProvider: imageRecognitionProvider,
      transcriptionModelId: config.transcriptionModelId,
      transcriptionProvider: transcriptionProvider,
      imageGenerationModelId: config.imageGenerationModelId,
      imageGenerationProvider: imageGenerationProvider,
    );
  }

  Future<ResolvedProfile?> _resolveFromModelId(String modelId) async {
    final provider = await resolveInferenceProvider(
      modelId: modelId,
      aiConfigRepository: _aiConfigRepository,
      logTag: _logTag,
    );
    if (provider == null) {
      developer.log(
        'Cannot resolve legacy model $modelId',
        name: _logTag,
      );
      return null;
    }

    return ResolvedProfile(
      thinkingModelId: modelId,
      thinkingProvider: provider,
    );
  }
}
