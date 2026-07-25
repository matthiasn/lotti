import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/ai/model/ai_config.dart';

/// Builds the model resolver used by profile slots.
///
/// New profile slots store [AiConfigModel.id]. Older/backfilled rows may still
/// carry [AiConfigModel.providerModelId] instead. The provider-native fallback
/// is only included when it is unique in [models], so an ambiguous provider id
/// cannot resolve to an arbitrary row.
Map<String, AiConfigModel> modelByProfileSlotId(
  Iterable<AiConfigModel> models,
) {
  final bySlotId = <String, AiConfigModel>{};
  final byProviderModelId = <String, List<AiConfigModel>>{};

  for (final model in models) {
    bySlotId[model.id] = model;
    (byProviderModelId[model.providerModelId] ??= <AiConfigModel>[]).add(
      model,
    );
  }

  for (final entry in byProviderModelId.entries) {
    if (entry.value.length == 1) {
      bySlotId.putIfAbsent(entry.key, () => entry.value.single);
    }
  }

  return bySlotId;
}

/// The profile ids something actually routes inference through.
///
/// This is deliberately reference-based rather than inferred: a profile is in
/// use because a category or an agent *points at it*, not because one of its
/// model slots happens to belong to a configured provider. The previous
/// provider-slot heuristic badged whichever profile a provider touched first —
/// preferring the never-user-settable `isDefault` flag — which meant a freshly
/// seeded profile appeared "active" the moment a provider was connected, with
/// no user action able to grant or revoke it, while the profile every category
/// actually used could go unbadged.
///
/// Sources:
/// - [categories] via `CategoryDefinition.defaultProfileId`
/// - [agents] via `AgentInferenceSetup.baseProfileId`, and the legacy
///   `AgentConfig.profileId` chain for agents created before typed setups
///
/// Tasks are intentionally not scanned. `TaskData.profileId` is copied from
/// the owning category when the task is created, so a task reference is a
/// snapshot of a category reference already counted here — and scanning every
/// task to render a settings badge would trade a real query cost for a
/// duplicate signal. An agent-level override is the case that genuinely
/// diverges, and that is covered.
Set<String> profileIdsInUse({
  required List<CategoryDefinition> categories,
  required List<AgentIdentityEntity> agents,
}) {
  final inUse = <String>{};

  for (final category in categories) {
    final profileId = category.defaultProfileId;
    if (profileId != null && profileId.isNotEmpty) inUse.add(profileId);
  }

  for (final agent in agents) {
    final setup = agent.config.inferenceSetup;
    if (setup != null) {
      // A disabled setup runs no inference, so whatever profile it still
      // carries is not in use.
      if (setup.mode == AgentInferenceSetupMode.disabled) continue;
      final baseProfileId = setup.baseProfileId;
      if (baseProfileId != null && baseProfileId.isNotEmpty) {
        inUse.add(baseProfileId);
      }
      continue;
    }
    // Null setup preserves the legacy resolution chain, where the agent's own
    // profileId is authoritative.
    final legacyProfileId = agent.config.profileId;
    if (legacyProfileId != null && legacyProfileId.isNotEmpty) {
      inUse.add(legacyProfileId);
    }
  }

  return inUse;
}

/// The profiles whose model slots reference a model owned by [providerModels].
///
/// Answers "which profiles would break if I deleted this provider?" for the
/// provider detail page — a different question from [profileIdsInUse], and the
/// only one the provider page can answer from its own data. Returns every
/// match in [profiles] order rather than picking an arbitrary winner.
List<AiConfigInferenceProfile> profilesUsingProviderModels({
  required List<AiConfigInferenceProfile> profiles,
  required List<AiConfigModel> providerModels,
}) {
  if (providerModels.isEmpty || profiles.isEmpty) {
    return const <AiConfigInferenceProfile>[];
  }
  final slotIds = modelByProfileSlotId(providerModels).keys.toSet();

  return profiles
      .where(
        (profile) =>
            slotIds.contains(profile.thinkingModelId) ||
            slotIds.contains(profile.thinkingHighEndModelId) ||
            slotIds.contains(profile.imageRecognitionModelId) ||
            slotIds.contains(profile.transcriptionModelId) ||
            slotIds.contains(profile.imageGenerationModelId),
      )
      .toList(growable: false);
}
