import 'dart:developer' as developer;

import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
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
    final details = await resolveDetailed(
      agentConfig: agentConfig,
      template: template,
      version: version,
    );
    return details.profile;
  }

  /// Resolves both the effective profile and the configuration tier that won.
  ///
  /// Typed setups are authoritative and never fall through to unrelated
  /// template/legacy defaults. Null [AgentConfig.inferenceSetup] preserves the
  /// historic chain for synced agents created by older clients.
  Future<ResolvedAgentSetup> resolveDetailed({
    required AgentConfig agentConfig,
    required AgentTemplateEntity template,
    required AgentTemplateVersionEntity version,
  }) async {
    final setup = agentConfig.inferenceSetup;
    if (setup != null) {
      return _resolveTypedSetup(setup);
    }
    return _resolveLegacySetup(
      agentConfig: agentConfig,
      template: template,
      version: version,
    );
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
    String profileId, {
    ResolvedInferenceProvider? thinkingOverride,
  }) async {
    final config = await _fetchProfile(profileId);
    if (config == null) return null;
    return _buildResolvedProfile(config, thinkingOverride: thinkingOverride);
  }

  Future<ResolvedAgentSetup> _resolveTypedSetup(
    AgentInferenceSetup setup,
  ) async {
    if (setup.mode == AgentInferenceSetupMode.disabled) {
      return ResolvedAgentSetup(
        status: AgentSetupResolutionStatus.disabled,
        setupOrigin: setup.origin,
      );
    }

    final overrideId = setup.thinkingModelOverrideId;
    final override = overrideId == null
        ? null
        : await resolveInferenceProviderForModelConfigId(
            modelConfigId: overrideId,
            aiConfigRepository: _aiConfigRepository,
            logTag: _logTag,
          );
    final baseProfile = setup.baseProfileId == null
        ? null
        : await _resolveFromProfile(
            setup.baseProfileId!,
            thinkingOverride: override,
          );

    if (override != null) {
      final profile =
          baseProfile?.withThinkingRoute(
            model: override.model,
            provider: override.provider,
          ) ??
          ResolvedProfile(
            thinkingModelId: override.model.providerModelId,
            thinkingProvider: override.provider,
            thinkingModel: override.model,
          );
      return _resolvedDetails(
        profile: profile,
        source: AgentSetupResolutionSource.directModel,
        setupOrigin: setup.origin,
        brokenSelectionId: setup.baseProfileId != null && baseProfile == null
            ? setup.baseProfileId
            : null,
      );
    }

    if (baseProfile != null) {
      return _resolvedDetails(
        profile: baseProfile,
        source: AgentSetupResolutionSource.baseProfile,
        setupOrigin: setup.origin,
        brokenSelectionId: overrideId,
      );
    }

    return ResolvedAgentSetup(
      status: AgentSetupResolutionStatus.broken,
      setupOrigin: setup.origin,
      brokenSelectionId: overrideId ?? setup.baseProfileId,
    );
  }

  Future<ResolvedAgentSetup> _resolveLegacySetup({
    required AgentConfig agentConfig,
    required AgentTemplateEntity template,
    required AgentTemplateVersionEntity version,
  }) async {
    final (profileId, source) = agentConfig.profileId != null
        ? (
            agentConfig.profileId!,
            AgentSetupResolutionSource.legacyAgentProfile,
          )
        : version.profileId != null
        ? (
            version.profileId!,
            AgentSetupResolutionSource.legacyVersionProfile,
          )
        : template.profileId != null
        ? (
            template.profileId!,
            AgentSetupResolutionSource.legacyTemplateProfile,
          )
        : (null, null);

    if (profileId != null && source != null) {
      final profile = await _resolveFromProfile(profileId);
      if (profile != null) {
        return _resolvedDetails(profile: profile, source: source);
      }
    }

    final legacy = await _resolveFromModelId(
      version.modelId ?? template.modelId,
    );
    if (legacy != null) {
      return _resolvedDetails(
        profile: legacy,
        source: AgentSetupResolutionSource.legacyModel,
        brokenSelectionId: profileId,
      );
    }

    return ResolvedAgentSetup(
      status: AgentSetupResolutionStatus.legacyUnknown,
      source: AgentSetupResolutionSource.legacyModel,
      brokenSelectionId: profileId ?? version.modelId ?? template.modelId,
    );
  }

  ResolvedAgentSetup _resolvedDetails({
    required ResolvedProfile profile,
    required AgentSetupResolutionSource source,
    AgentInferenceSetupOrigin? setupOrigin,
    String? brokenSelectionId,
  }) {
    return ResolvedAgentSetup(
      status: AgentSetupResolutionStatus.resolved,
      profile: profile,
      source: source,
      setupOrigin: setupOrigin,
      brokenSelectionId: brokenSelectionId,
      routeFingerprint: InferenceRouteFingerprint.fromProfile(profile),
    );
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
    AiConfigInferenceProfile config, {
    ResolvedInferenceProvider? thinkingOverride,
  }) async {
    // Resolve thinking slot (fatal if missing).
    final thinkingSlot =
        thinkingOverride ??
        await resolveInferenceProviderForProfileSlot(
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
