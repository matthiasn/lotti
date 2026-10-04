part of 'profile_seeding_service.dart';

// The pure builders behind [ProfileSeedingService]: the seeded profiles, skills and their defaults.

AiConfigInferenceProfile _withMigratedLegacyLocalPowerSeed(
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

AiConfigInferenceProfile _withUpgradedOmlxWhisperTranscription(
  AiConfigInferenceProfile profile,
  List<AiConfigModel> models,
) {
  final expectedModelId = switch (profile.id) {
    profileLocalPowerId => omlxRecommendedMultimodalModelId,
    profileLocalGemmaOmlxId => omlxGemma426BA4BItQatMlx4BitModelId,
    _ => null,
  };

  if (expectedModelId == null ||
      !_isUntouchedOmlxProfileMissingTranscription(
        profile,
        expectedModelId,
        models,
      )) {
    return profile;
  }

  final upgraded = profile.copyWith(
    transcriptionModelId: omlxWhisperLargeV3TurboModelId,
  );

  final sanitizedAssignments = _defaultSkillAssignments
      .where((assignment) {
        final skill = findBuiltInSkill(assignment.skillId);
        if (skill == null) {
          return true;
        }

        return ProfileSeedingService.hasSlotForSkillType(
          upgraded,
          skill.skillType,
          models,
        );
      })
      .toList(growable: false);

  return upgraded.copyWith(skillAssignments: sanitizedAssignments);
}

AiConfigInferenceProfile _withUpgradedMeliousFluxImageGeneration(
  AiConfigInferenceProfile profile,
  List<AiConfigModel> models,
) {
  if (!_isUntouchedMeliousProfileEligibleForImageGenerationUpgrade(
    profile,
    models,
  )) {
    return profile;
  }

  return profile.copyWith(
    imageGenerationModelId: meliousFlux2Klein9BModelId,
  );
}

AiConfigInferenceProfile _withUpgradedMeliousWhisperTranscription(
  AiConfigInferenceProfile profile,
  List<AiConfigModel> models,
) {
  if (!_isUntouchedMeliousProfileEligibleForWhisperDefaultUpgrade(
    profile,
    models,
  )) {
    return profile;
  }

  return profile.copyWith(
    transcriptionModelId: meliousWhisperLargeV3ModelId,
  );
}

/// Heals model slots on seeded default profiles that point at model rows
/// which no longer exist.
///
/// Deleting a provider cascade-deletes its model rows
/// ([AiConfigRepository.deleteInferenceProviderWithModels]), but seeded
/// profiles keep referencing the dead row IDs — leaving every consumer of
/// the profile (task structuring, transcription, agent wakes) unable to
/// resolve a provider, even after the user reconnects the same provider
/// type. Each dangling slot — a non-null value matching no live row ID or
/// `providerModelId`, and not a provider-native ID from the known-models
/// catalog (those are merely *pending* and resolve at runtime once their
/// provider exists) — is reset to the seed template's provider-native
/// default, which [_withResolvedModelConfigIds] then maps back to a live
/// row once backfill/FTUE/prepopulation has recreated it. Slots that still
/// resolve are never touched, so user-authored choices survive; only
/// demonstrably broken pointers are healed.
AiConfigInferenceProfile _withRepairedDanglingDefaultSlots(
  AiConfigInferenceProfile profile,
  AiConfigInferenceProfile template,
  List<AiConfigModel> models,
) {
  bool stillResolves(String current) =>
      _slotResolvesToModelRow(current, models) ||
      _isKnownProviderNativeModelId(current);

  String? heal(String? current, String? seedDefault) =>
      current == null || stillResolves(current) ? current : seedDefault;

  return profile.copyWith(
    // The thinking slot is required on both sides, so it heals without
    // the null passthrough the optional slots need.
    thinkingModelId: stillResolves(profile.thinkingModelId)
        ? profile.thinkingModelId
        : template.thinkingModelId,
    thinkingHighEndModelId: heal(
      profile.thinkingHighEndModelId,
      template.thinkingHighEndModelId,
    ),
    imageRecognitionModelId: heal(
      profile.imageRecognitionModelId,
      template.imageRecognitionModelId,
    ),
    transcriptionModelId: heal(
      profile.transcriptionModelId,
      template.transcriptionModelId,
    ),
    imageGenerationModelId: heal(
      profile.imageGenerationModelId,
      template.imageGenerationModelId,
    ),
  );
}

/// Moves an untouched Melious default profile to the current seed targets:
/// Qwen in the thinking slot (was Mistral Small 4), GLM 5.2 in the high-end
/// thinking slot (was DeepSeek V4 Pro), and Voxtral Small in the transcription
/// slot (was Whisper Large v3 / Turbo). Mistral remains in the vision slot
/// because the curated Qwen endpoint is text-only. Runs after the
/// Whisper/Flux migrations so legacy profiles chain through every default
/// generation; each slot only moves when its replacement model row exists.
AiConfigInferenceProfile _withUpgradedMeliousDefaults(
  AiConfigInferenceProfile profile,
  List<AiConfigModel> models,
) {
  if (profile.id != profileMeliousId ||
      profile.seedGeneration >= meliousProfileSeedGeneration1) {
    return profile;
  }
  if (!_isUntouchedMeliousDefaultProfile(profile, models)) {
    // Same rule as generation 2: a slot that cannot be matched because its
    // row is missing is not evidence of a user edit, and this stamp is
    // permanent. Defer the decision rather than freeze the wrong one.
    if (!_meliousLegacyShapeSourcesResolve(models)) return profile;
    return profile.copyWith(seedGeneration: meliousProfileSeedGeneration1);
  }

  final currentTargetsAvailable = [
    meliousQwen35122BA10BModelId,
    meliousGlm52ModelId,
    meliousVoxtralSmall24B2507ModelId,
    meliousFlux2Klein9BModelId,
  ].every((modelId) => _slotResolvesToModelRow(modelId, models));

  var upgraded = profile;
  if (_slotMatchesProviderModelId(
        profile.thinkingModelId,
        meliousMistralSmall4119BInstructModelId,
        models,
      ) &&
      _slotResolvesToModelRow(meliousQwen35122BA10BModelId, models)) {
    upgraded = upgraded.copyWith(
      thinkingModelId: meliousQwen35122BA10BModelId,
    );
  }
  if (_slotMatchesProviderModelId(
        profile.thinkingHighEndModelId,
        meliousDeepseekV4ProModelId,
        models,
      ) &&
      _slotResolvesToModelRow(meliousGlm52ModelId, models)) {
    upgraded = upgraded.copyWith(thinkingHighEndModelId: meliousGlm52ModelId);
  }
  if (_meliousTranscriptionSlotMatchesWhisperDefaultOrNull(
        profile.transcriptionModelId,
        models,
      ) &&
      _slotResolvesToModelRow(meliousVoxtralSmall24B2507ModelId, models)) {
    upgraded = upgraded.copyWith(
      transcriptionModelId: meliousVoxtralSmall24B2507ModelId,
    );
  }
  return currentTargetsAvailable
      ? upgraded.copyWith(seedGeneration: meliousProfileSeedGeneration1)
      : upgraded;
}

/// Moves an untouched generation-1 Melious profile to the generation-2 seed
/// targets: GLM 5.2 in the thinking slot (was Qwen3.5 122B A10B), Kimi K3 in
/// both the high-end thinking slot (was GLM 5.2) and the image-recognition
/// slot (was Mistral Small 4 119B Instruct), and Whisper Large v3 in the
/// transcription slot (was Voxtral Small 24B). Image generation already
/// points at Flux 2 Klein 9B and does not move.
///
/// Runs after [_withUpgradedMeliousDefaults] so a profile stranded at
/// generation 0 chains through generation 1 and lands here in the same pass.
/// It requires generation 1 to have actually *completed*, though: that pass
/// defers without stamping when its own targets are missing, and may have
/// moved some slots already. Acting on that half-moved shape would fail the
/// exact-shape check below and stamp generation 2 over a profile that never
/// reached either generation — terminally, since the stamp is never undone.
/// A user who deleted one Melious model row is enough to reach that state:
/// model deletion is a tombstone, so the backfill will not recreate the row
/// and this pass cannot see it.
///
/// Deliberately **atomic**: the move happens only once every generation-2
/// target resolves to a Melious-owned model row, and is otherwise deferred
/// whole. Moving slots one at a time as their rows appeared would leave the
/// profile in a shape that is neither generation 1 nor generation 2, and the
/// next pass — which recognises only the exact generation-1 shape — would
/// read that as a user edit and stamp it forward with the remaining slots
/// never migrated.
AiConfigInferenceProfile _withUpgradedMeliousGeneration2Defaults(
  AiConfigInferenceProfile profile,
  List<AiConfigModel> models,
) {
  if (profile.id != profileMeliousId ||
      profile.seedGeneration < meliousProfileSeedGeneration1 ||
      profile.seedGeneration >= meliousProfileSeedGeneration2) {
    return profile;
  }
  if (!_isUntouchedMeliousGeneration1Profile(profile, models)) {
    // "Not the generation-1 shape" has two very different causes: the user
    // rewired a slot, or a source row is temporarily missing so the slot
    // cannot be matched at all. Only the first is a decision worth
    // recording, and the stamp is permanent — so when the evidence is
    // incomplete, decide nothing and look again next pass.
    if (!_meliousGeneration1ShapeSourcesResolve(models)) return profile;
    return profile.copyWith(seedGeneration: meliousProfileSeedGeneration2);
  }

  final targetsAvailable = [
    meliousGlm52ModelId,
    meliousKimiK3ModelId,
    meliousWhisperLargeV3ModelId,
    meliousFlux2Klein9BModelId,
  ].every((modelId) => _slotResolvesToModelRow(modelId, models));
  if (!targetsAvailable) return profile;

  return profile.copyWith(
    thinkingModelId: meliousGlm52ModelId,
    thinkingHighEndModelId: meliousKimiK3ModelId,
    imageRecognitionModelId: meliousKimiK3ModelId,
    transcriptionModelId: meliousWhisperLargeV3ModelId,
    seedGeneration: meliousProfileSeedGeneration2,
  );
}

/// Whether every model row the Melious seed-shape checks read is present.
///
/// The shape predicates match a slot by looking its row up in [models], so a
/// deleted row makes an untouched slot look rewired. Deletion is a tombstone
/// — `backfillNewModels()` reads the row as present and never recreates it,
/// while this pass reads without `includeDeleted` and cannot see it — so the
/// two disagree by design, and a migration must not mistake that
/// disagreement for a user's choice.
///
/// Each generation guards on exactly the rows *its own* predicate consults,
/// not on the whole catalog and not on each other's: deleting a model that
/// generation's shape never mentions — MiniMax, or Whisper Turbo for a
/// generation-1 profile — is no reason to stall its migration. Legacy
/// provider-native values such as the old Flux 2 dev id are matched as plain
/// strings and need no row, so they are absent from both lists.
bool _meliousLegacyShapeSourcesResolve(List<AiConfigModel> models) {
  return const [
    meliousQwen35122BA10BModelId,
    meliousGlm52ModelId,
    meliousMistralSmall4119BInstructModelId,
    meliousDeepseekV4ProModelId,
    meliousVoxtralSmall24B2507ModelId,
    meliousWhisperLargeV3ModelId,
    meliousWhisperLargeV3TurboModelId,
    meliousFlux2Klein9BModelId,
  ].every((modelId) => _slotResolvesToModelRow(modelId, models));
}

/// The generation-1 counterpart of [_meliousLegacyShapeSourcesResolve].
bool _meliousGeneration1ShapeSourcesResolve(
  List<AiConfigModel> models,
) {
  return const [
    meliousQwen35122BA10BModelId,
    meliousGlm52ModelId,
    meliousMistralSmall4119BInstructModelId,
    meliousVoxtralSmall24B2507ModelId,
    meliousFlux2Klein9BModelId,
  ].every((modelId) => _slotResolvesToModelRow(modelId, models));
}

/// Whether [profile] still carries exactly the generation-1 Melious seed —
/// every slot on its generation-1 default and no user-authored metadata
/// (name, description, flags, pinned host) changed.
///
/// Deliberately exact rather than "default or legacy": anything that is not
/// precisely the generation-1 shape is a user choice, and the generation-2
/// migration must leave it alone.
bool _isUntouchedMeliousGeneration1Profile(
  AiConfigInferenceProfile profile,
  List<AiConfigModel> models,
) {
  return profile.id == profileMeliousId &&
      profile.seedGeneration < meliousProfileSeedGeneration2 &&
      profile.name == 'Melious.ai' &&
      profile.description == null &&
      profile.chatModelId == null &&
      _slotMatchesProviderModelId(
        profile.thinkingModelId,
        meliousQwen35122BA10BModelId,
        models,
      ) &&
      _slotMatchesProviderModelId(
        profile.thinkingHighEndModelId,
        meliousGlm52ModelId,
        models,
      ) &&
      _slotMatchesProviderModelId(
        profile.imageRecognitionModelId,
        meliousMistralSmall4119BInstructModelId,
        models,
      ) &&
      _slotMatchesProviderModelId(
        profile.transcriptionModelId,
        meliousVoxtralSmall24B2507ModelId,
        models,
      ) &&
      _slotMatchesProviderModelId(
        profile.imageGenerationModelId,
        meliousFlux2Klein9BModelId,
        models,
      ) &&
      profile.isDefault &&
      !profile.desktopOnly &&
      profile.pinnedHostId == null;
}

/// Whether [profile] still carries only pre-generation-1 seeded Melious
/// defaults — every slot matches a known legacy default and no user-authored
/// metadata (name, description, flags, pinned host) has been changed.
///
/// Guards on generation 1 specifically, not on the moving current
/// generation: a profile that already reached generation 1 is the
/// generation-2 migration's business, and the legacy Whisper and Flux
/// upgrades gated on this predicate must not reconsider it.
bool _isUntouchedMeliousDefaultProfile(
  AiConfigInferenceProfile profile,
  List<AiConfigModel> models,
) {
  return profile.id == profileMeliousId &&
      profile.seedGeneration < meliousProfileSeedGeneration1 &&
      profile.name == 'Melious.ai' &&
      profile.description == null &&
      profile.chatModelId == null &&
      _meliousThinkingSlotMatchesDefaultOrLegacy(
        profile.thinkingModelId,
        models,
      ) &&
      (_slotMatchesProviderModelId(
            profile.thinkingHighEndModelId,
            meliousDeepseekV4ProModelId,
            models,
          ) ||
          _slotMatchesProviderModelId(
            profile.thinkingHighEndModelId,
            meliousGlm52ModelId,
            models,
          )) &&
      _slotMatchesProviderModelId(
        profile.imageRecognitionModelId,
        meliousMistralSmall4119BInstructModelId,
        models,
      ) &&
      (_meliousTranscriptionSlotMatchesWhisperDefaultOrNull(
            profile.transcriptionModelId,
            models,
          ) ||
          _slotMatchesProviderModelId(
            profile.transcriptionModelId,
            meliousVoxtralSmall24B2507ModelId,
            models,
          )) &&
      _meliousImageGenerationSlotMatchesDefaultOrLegacy(
        profile.imageGenerationModelId,
        models,
      ) &&
      profile.isDefault &&
      !profile.desktopOnly &&
      profile.pinnedHostId == null;
}

bool _meliousThinkingSlotMatchesDefaultOrLegacy(
  String? slotValue,
  List<AiConfigModel> models,
) {
  return _slotMatchesProviderModelId(
        slotValue,
        meliousQwen35122BA10BModelId,
        models,
      ) ||
      _slotMatchesProviderModelId(
        slotValue,
        meliousMistralSmall4119BInstructModelId,
        models,
      );
}

/// Whether the transcription slot is unset or still points at one of the
/// previous Whisper defaults — the states eligible for the Voxtral upgrade.
bool _meliousTranscriptionSlotMatchesWhisperDefaultOrNull(
  String? slotValue,
  List<AiConfigModel> models,
) {
  return slotValue == null ||
      _meliousTranscriptionSlotMatchesDefaultOrLegacy(slotValue, models);
}

bool _isUntouchedMeliousProfileEligibleForWhisperDefaultUpgrade(
  AiConfigInferenceProfile profile,
  List<AiConfigModel> models,
) {
  return _isUntouchedMeliousDefaultProfile(profile, models) &&
      _meliousTranscriptionSlotNeedsUpgrade(
        profile.transcriptionModelId,
        models,
      ) &&
      _slotResolvesToModelRow(meliousWhisperLargeV3ModelId, models);
}

bool _isUntouchedMeliousProfileEligibleForImageGenerationUpgrade(
  AiConfigInferenceProfile profile,
  List<AiConfigModel> models,
) {
  return _isUntouchedMeliousDefaultProfile(profile, models) &&
      _meliousImageGenerationSlotNeedsUpgrade(
        profile.imageGenerationModelId,
        models,
      ) &&
      _slotResolvesToModelRow(meliousFlux2Klein9BModelId, models);
}

bool _meliousTranscriptionSlotNeedsUpgrade(
  String? slotValue,
  List<AiConfigModel> models,
) {
  return slotValue == null ||
      _slotMatchesProviderModelId(
        slotValue,
        meliousWhisperLargeV3TurboModelId,
        models,
      );
}

bool _meliousTranscriptionSlotMatchesDefaultOrLegacy(
  String? slotValue,
  List<AiConfigModel> models,
) {
  return _slotMatchesProviderModelId(
        slotValue,
        meliousWhisperLargeV3ModelId,
        models,
      ) ||
      _slotMatchesProviderModelId(
        slotValue,
        meliousWhisperLargeV3TurboModelId,
        models,
      );
}

bool _meliousImageGenerationSlotMatchesDefaultOrLegacy(
  String? slotValue,
  List<AiConfigModel> models,
) {
  return _meliousImageGenerationSlotNeedsUpgrade(slotValue, models) ||
      _slotMatchesProviderModelId(
        slotValue,
        meliousFlux2Klein9BModelId,
        models,
      );
}

bool _meliousImageGenerationSlotNeedsUpgrade(
  String? slotValue,
  List<AiConfigModel> models,
) {
  return slotValue == null ||
      _slotMatchesProviderModelId(
        slotValue,
        _legacyMeliousFlux2DevModelId,
        models,
      );
}

bool _isUntouchedOmlxProfileMissingTranscription(
  AiConfigInferenceProfile profile,
  String expectedModelId,
  List<AiConfigModel> models,
) {
  return profile.description == null &&
      profile.chatModelId == null &&
      profile.thinkingHighEndModelId == null &&
      _slotMatchesProviderModelId(
        profile.thinkingModelId,
        expectedModelId,
        models,
      ) &&
      _slotMatchesProviderModelId(
        profile.imageRecognitionModelId,
        expectedModelId,
        models,
      ) &&
      profile.transcriptionModelId == null &&
      profile.imageGenerationModelId == null &&
      !profile.isDefault &&
      profile.desktopOnly &&
      profile.skillAssignments.isEmpty &&
      profile.pinnedHostId == null;
}

bool _isUntouchedLegacyLocalPowerSeed(
  AiConfigInferenceProfile profile,
  List<AiConfigModel> models,
) {
  return profile.id == profileLocalPowerId &&
      profile.name == _legacyLocalPowerName &&
      profile.description == null &&
      profile.chatModelId == null &&
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

bool _slotMatchesProviderModelId(
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

/// Whether [profile] is still an untouched default seed that no usable
/// provider can serve — the only state
/// [ProfileSeedingService.removeOrphanedDefaultSeeds] is
/// allowed to delete.
///
/// A slot value found in [usableModelSlotValues] means the profile can
/// still serve requests (e.g. the user rewired it to another provider),
/// so the cleanup pass must keep it.
bool _isRemovableOrphanedSeed(
  AiConfigInferenceProfile profile,
  AiConfigInferenceProfile template, {
  required Set<String> usableModelSlotValues,
}) {
  final nameUntouched =
      profile.name == template.name ||
      (profile.id == profileLocalPowerId &&
          profile.name == _legacyLocalPowerName);
  if (!nameUntouched ||
      profile.description != null ||
      profile.chatModelId != null ||
      profile.pinnedHostId != null ||
      profile.isDefault != template.isDefault ||
      profile.desktopOnly != template.desktopOnly) {
    return false;
  }

  final slots = [
    profile.thinkingModelId,
    profile.thinkingHighEndModelId,
    profile.imageRecognitionModelId,
    profile.transcriptionModelId,
    profile.imageGenerationModelId,
  ];
  return !slots.any(
    (slot) => slot != null && usableModelSlotValues.contains(slot),
  );
}

AiConfigInferenceProfile _withResolvedModelConfigIds(
  AiConfigInferenceProfile profile,
  List<AiConfigModel> models, {
  Set<String>? preferredProviderIds,
}) {
  return profile.copyWith(
    thinkingModelId: _resolveModelSlot(
      profile.thinkingModelId,
      models,
      preferredProviderIds: preferredProviderIds,
    ),
    chatModelId: _resolveOptionalModelSlot(
      profile.chatModelId,
      models,
      preferredProviderIds: preferredProviderIds,
    ),
    thinkingHighEndModelId: _resolveOptionalModelSlot(
      profile.thinkingHighEndModelId,
      models,
      preferredProviderIds: preferredProviderIds,
    ),
    imageRecognitionModelId: _resolveOptionalModelSlot(
      profile.imageRecognitionModelId,
      models,
      preferredProviderIds: preferredProviderIds,
    ),
    transcriptionModelId: _resolveOptionalModelSlot(
      profile.transcriptionModelId,
      models,
      preferredProviderIds: preferredProviderIds,
    ),
    imageGenerationModelId: _resolveOptionalModelSlot(
      profile.imageGenerationModelId,
      models,
      preferredProviderIds: preferredProviderIds,
    ),
  );
}

String? _resolveOptionalModelSlot(
  String? slotValue,
  List<AiConfigModel> models, {
  Set<String>? preferredProviderIds,
}) {
  if (slotValue == null) return null;
  return _resolveModelSlot(
    slotValue,
    models,
    preferredProviderIds: preferredProviderIds,
  );
}

String _resolveModelSlot(
  String slotValue,
  List<AiConfigModel> models, {
  Set<String>? preferredProviderIds,
}) {
  if (models.any((model) => model.id == slotValue)) return slotValue;

  final matches = models
      .where(
        (model) =>
            model.providerModelId == slotValue &&
            (preferredProviderIds == null ||
                preferredProviderIds.contains(model.inferenceProviderId)),
      )
      .toList(growable: false);
  if (matches.length == 1) return matches.single.id;
  return slotValue;
}

/// True when [slotValue] matches a configured model row by exact
/// `AiConfigModel.id` or by legacy `providerModelId`. Ambiguous legacy
/// values (2+ rows) still count — the runtime resolver walks every
/// candidate — but values with no matching row at all do not.
bool _slotResolvesToModelRow(
  String? slotValue,
  List<AiConfigModel> models,
) {
  if (slotValue == null) return false;
  return models.any(
    (model) => model.id == slotValue || model.providerModelId == slotValue,
  );
}

Set<String>? _providerIdsForProfile(
  String profileId,
  List<AiConfigInferenceProvider> providers,
) {
  final providerType = ProfileSeedingService.providerTypeByProfileId[profileId];
  if (providerType == null) return null;
  return {
    for (final provider in providers)
      if (provider.inferenceProviderType == providerType) provider.id,
  };
}

/// Whether [slotValue] is a provider-native model ID from the bundled
/// known-models catalog — a value runtime resolution can still satisfy once
/// a provider of the owning type exists, and therefore not dangling.
bool _isKnownProviderNativeModelId(String slotValue) {
  return knownModelsByProvider.values.any(
    (models) => models.any((model) => model.providerModelId == slotValue),
  );
}
