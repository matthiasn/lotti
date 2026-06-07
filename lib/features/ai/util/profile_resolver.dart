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
    required this._aiConfigRepository,
  });

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

  /// Resolves a [ResolvedProfile] directly from a [profileId].
  ///
  /// Unlike [resolve], this does not use the agent/template/version chain and
  /// has no legacy `modelId` fallback. Returns `null` if the profile cannot be
  /// found or the thinking slot cannot be resolved.
  Future<ResolvedProfile?> resolveByProfileId(String profileId) async {
    final config = await _fetchProfile(profileId);
    if (config == null) return null;
    return _buildResolvedProfile(config);
  }

  Future<ResolvedProfile?> _resolveFromProfile(
    String profileId,
    AgentTemplateEntity template,
    AgentTemplateVersionEntity version,
  ) async {
    final config = await _fetchProfile(profileId);
    if (config == null) {
      // Fallback to legacy path when profile not found (e.g., sync race).
      return _resolveFromModelId(version.modelId ?? template.modelId);
    }
    return _buildResolvedProfile(config);
  }

  /// Fetches and type-checks a profile config by [profileId].
  ///
  /// Returns `null` if the config is not found or is not an inference profile.
  Future<AiConfigInferenceProfile?> _fetchProfile(String profileId) async {
    final config = await _aiConfigRepository.getConfigById(profileId);
    if (config is! AiConfigInferenceProfile) {
      developer.log(
        'Profile $profileId not found or wrong type',
        name: _logTag,
      );
      return null;
    }
    return config;
  }

  Future<ResolvedProfile?> _buildResolvedProfile(
    AiConfigInferenceProfile config,
  ) async {
    // Resolve thinking slot (fatal if missing).
    final thinkingSlot = await resolveInferenceProviderForProfileSlot(
      modelId: config.thinkingModelId,
      aiConfigRepository: _aiConfigRepository,
      logTag: _logTag,
    );
    if (thinkingSlot == null) {
      developer.log(
        'Cannot resolve thinking model ${config.thinkingModelId} '
        'for profile ${config.id}',
        name: _logTag,
      );
      return null;
    }

    // Resolve optional slots (non-fatal).
    final thinkingHighEndSlot = config.thinkingHighEndModelId != null
        ? await resolveInferenceProviderForProfileSlot(
            modelId: config.thinkingHighEndModelId!,
            aiConfigRepository: _aiConfigRepository,
            logTag: _logTag,
          )
        : null;

    final imageRecognitionSlot = config.imageRecognitionModelId != null
        ? await resolveInferenceProviderForProfileSlot(
            modelId: config.imageRecognitionModelId!,
            aiConfigRepository: _aiConfigRepository,
            logTag: _logTag,
          )
        : null;

    final transcriptionSlot = config.transcriptionModelId != null
        ? await resolveInferenceProviderForProfileSlot(
            modelId: config.transcriptionModelId!,
            aiConfigRepository: _aiConfigRepository,
            logTag: _logTag,
          )
        : null;

    final imageGenerationSlot = config.imageGenerationModelId != null
        ? await resolveInferenceProviderForProfileSlot(
            modelId: config.imageGenerationModelId!,
            aiConfigRepository: _aiConfigRepository,
            logTag: _logTag,
          )
        : null;

    return ResolvedProfile(
      thinkingModelId: thinkingSlot.model.providerModelId,
      thinkingProvider: thinkingSlot.provider,
      thinkingModel: thinkingSlot.model,
      thinkingHighEndModelId: thinkingHighEndSlot?.model.providerModelId,
      thinkingHighEndProvider: thinkingHighEndSlot?.provider,
      thinkingHighEndModel: thinkingHighEndSlot?.model,
      imageRecognitionModelId: imageRecognitionSlot?.model.providerModelId,
      imageRecognitionProvider: imageRecognitionSlot?.provider,
      imageRecognitionModel: imageRecognitionSlot?.model,
      transcriptionModelId: transcriptionSlot?.model.providerModelId,
      transcriptionProvider: transcriptionSlot?.provider,
      transcriptionModel: transcriptionSlot?.model,
      imageGenerationModelId: imageGenerationSlot?.model.providerModelId,
      imageGenerationProvider: imageGenerationSlot?.provider,
      imageGenerationModel: imageGenerationSlot?.model,
      skillAssignments: config.skillAssignments,
    );
  }

  Future<ResolvedProfile?> _resolveFromModelId(String modelId) async {
    final slot = await resolveInferenceProviderWithModel(
      modelId: modelId,
      aiConfigRepository: _aiConfigRepository,
      logTag: _logTag,
    );
    if (slot == null) {
      developer.log(
        'Cannot resolve legacy model $modelId',
        name: _logTag,
      );
      return null;
    }

    return ResolvedProfile(
      thinkingModelId: modelId,
      thinkingProvider: slot.provider,
      thinkingModel: slot.model,
    );
  }
}
