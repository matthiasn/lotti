import 'dart:developer' as developer;

import 'package:lotti/features/ai/constants/provider_config.dart';
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
const profileMeliousId = 'profile-melious-001';
const profileAlibabaId = 'profile-alibaba-001';
const profileAnthropicId = 'profile-anthropic-001';
const profileLocalId = 'profile-local-001';
const profileLocalPowerId = 'profile-local-power-001';
const profileLocalGemmaOmlxId = 'profile-local-gemma-omlx-001';
const profileLocalGemmaId = 'profile-local-gemma-001';
const profileLocalGemmaPowerId = 'profile-local-gemma-power-001';

/// Current bundled-default generation for the Melious inference profile.
const meliousProfileSeedGeneration = 1;

const _logTag = 'ProfileSeedingService';
const _localPowerName = 'Local Power (oMLX)';
const _legacyLocalPowerName = 'Local Power (Ollama)';
const _legacyLocalPowerThinkingModelId = 'qwen3.6:35b-a3b-coding-nvfp4';
const _legacyLocalPowerImageModelId = 'qwen3.5:27b';
const _legacyMeliousFlux2DevModelId = 'black-forest-labs/flux-2-dev';

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
///
/// Seeding is gated per provider type: a default profile is only created once
/// a *usable* provider of its type exists (see [providerTypeByProfileId] and
/// [AiConfigInferenceProviderUsability.isUsable]). Fresh installs therefore
/// start with zero profiles, and each provider setup surfaces exactly its own
/// profile(s) instead of the full bundled catalog.
class ProfileSeedingService {
  const ProfileSeedingService({
    required AiConfigRepository aiConfigRepository,
  }) : _repo = aiConfigRepository;

  final AiConfigRepository _repo;

  /// The provider type whose setup makes each default profile functional.
  ///
  /// [seedDefaults] only seeds a profile when a usable provider of its mapped
  /// type exists, and [removeOrphanedDefaultSeeds] removes untouched seeds
  /// whose mapped type has no usable provider left. Every entry in
  /// [defaultProfiles] must have a mapping here (enforced by test).
  static const providerTypeByProfileId = <String, InferenceProviderType>{
    profileGeminiFlashId: InferenceProviderType.gemini,
    profileGeminiProId: InferenceProviderType.gemini,
    profileOpenAiId: InferenceProviderType.openAi,
    profileMistralEuId: InferenceProviderType.mistral,
    profileMeliousId: InferenceProviderType.melious,
    profileAlibabaId: InferenceProviderType.alibaba,
    profileAnthropicId: InferenceProviderType.anthropic,
    profileLocalId: InferenceProviderType.ollama,
    profileLocalPowerId: InferenceProviderType.omlx,
    profileLocalGemmaOmlxId: InferenceProviderType.omlx,
    profileLocalGemmaId: InferenceProviderType.ollama,
    profileLocalGemmaPowerId: InferenceProviderType.ollama,
  };

  /// Seeds the default profiles whose provider type has a usable provider.
  /// Safe to call multiple times.
  ///
  /// Only creates profiles that do not already exist by ID. Existing
  /// profiles — even if their model IDs or flags differ from the seed
  /// targets in code — are left untouched. This preserves user edits to
  /// the bundled defaults (e.g. swapping the Ollama profile's thinking
  /// model) across app restarts.
  ///
  /// Profiles whose provider type has no usable provider row (per
  /// [AiConfigInferenceProviderUsability.isUsable]) are skipped entirely, so
  /// the profile picker never fills up with entries that cannot serve a
  /// single request. Runs at startup and again right after a provider is
  /// created, updated, or finishes FTUE setup, so completing a provider
  /// setup surfaces its profile immediately.
  Future<void> seedDefaults() async {
    var seededCount = 0;
    final models = await _fetchModelRows();
    final usableProviders = (await _fetchProviderRows())
        .where((provider) => provider.isUsable)
        .toList(growable: false);
    final usableTypes = {
      for (final provider in usableProviders) provider.inferenceProviderType,
    };

    for (final template in defaultProfiles) {
      if (!usableTypes.contains(providerTypeByProfileId[template.id])) {
        continue;
      }
      final existing = await _repo.getConfigById(template.id);
      if (existing != null) continue;
      final profile = _withResolvedModelConfigIds(
        template,
        models,
        preferredProviderIds: _providerIdsForProfile(
          template.id,
          usableProviders,
        ),
      );
      await _repo.saveConfig(profile);
      seededCount++;
    }

    if (seededCount > 0) {
      developer.log('Profiles: seeded $seededCount', name: _logTag);
    }
  }

  /// Removes seeded default profiles that cannot serve any request because
  /// no usable provider of their mapped type exists (anymore).
  ///
  /// This is the retroactive counterpart to the [seedDefaults] gate: installs
  /// that seeded the full catalog before the gate existed — or that deleted a
  /// provider after its profile was seeded — shed the dead entries here.
  ///
  /// Deliberately conservative: a profile is only removed when it is still
  /// recognizable as an untouched seed (template name — or the known legacy
  /// Local Power name — no description, no pinned host, template flags) AND
  /// none of its model slots resolve to a model row owned by a usable
  /// provider. Anything the user renamed, described, pinned, or rewired to a
  /// working provider survives. Skill assignments are not inspected: they are
  /// inert while no slot can resolve a provider, and re-seeding restores the
  /// defaults if the provider returns.
  ///
  /// Runs at startup only (after [upgradeExisting]), so a mid-session
  /// provider deletion with undo cannot race the cleanup.
  Future<void> removeOrphanedDefaultSeeds() async {
    final providers = await _fetchProviderRows();
    final usableProviders = providers
        .where((provider) => provider.isUsable)
        .toList(growable: false);
    final usableTypes = {
      for (final provider in usableProviders) provider.inferenceProviderType,
    };
    final usableProviderIds = {
      for (final provider in usableProviders) provider.id,
    };
    final models = await _fetchModelRows();
    // Every value a profile slot could carry — row ID or legacy
    // `providerModelId` — for models owned by a usable provider, so the
    // per-slot check below is a set lookup instead of a scan over all rows.
    final usableModelSlotValues = <String>{
      for (final model in models)
        if (usableProviderIds.contains(model.inferenceProviderId)) ...[
          model.id,
          model.providerModelId,
        ],
    };
    final templatesById = {
      for (final template in defaultProfiles) template.id: template,
    };
    final configs = await _repo.getConfigsByType(AiConfigType.inferenceProfile);

    var removedCount = 0;
    for (final config in configs.whereType<AiConfigInferenceProfile>()) {
      final template = templatesById[config.id];
      if (template == null) continue;
      if (usableTypes.contains(providerTypeByProfileId[config.id])) continue;
      if (!_isRemovableOrphanedSeed(
        config,
        template,
        usableModelSlotValues: usableModelSlotValues,
      )) {
        continue;
      }
      await _repo.deleteConfig(config.id);
      removedCount++;
    }

    if (removedCount > 0) {
      developer.log(
        'Profiles: removed $removedCount orphaned default seeds',
        name: _logTag,
      );
    }
  }

  /// Upgrades existing profiles without overwriting user-authored choices.
  ///
  /// This heals dangling model slots on default profiles (rows deleted with
  /// their provider), migrates legacy provider-native profile slot values to
  /// `AiConfigModel.id` when the match is unambiguous, migrates the untouched
  /// old Local Power seed from Ollama to oMLX, migrates untouched Melious image
  /// generation and transcription to the Flux 2 Klein 9B and Whisper Large v3
  /// defaults, moves untouched Melious profiles to Qwen thinking, GLM 5.2
  /// high-end, and Voxtral transcription defaults, then backfills default
  /// skill assignments only for default profiles whose assignments are empty.
  ///
  /// Runs at startup (after the model backfill) and again after a provider is
  /// created or re-verified mid-session (`runFtueSetupForType`, provider
  /// save), so a reconnected provider heals its profile immediately instead
  /// of on the next launch.
  Future<void> upgradeExisting() async {
    var upgradedCount = 0;
    final models = await _fetchModelRows();
    final providers = await _fetchProviderRows();
    final meliousProviderIds = {
      for (final provider in providers)
        if (provider.inferenceProviderType == InferenceProviderType.melious)
          provider.id,
    };
    final meliousModels = models
        .where(
          (model) => meliousProviderIds.contains(model.inferenceProviderId),
        )
        .toList(growable: false);
    final templatesById = {
      for (final template in defaultProfiles) template.id: template,
    };
    final configs = await _repo.getConfigsByType(AiConfigType.inferenceProfile);

    for (final config in configs.whereType<AiConfigInferenceProfile>()) {
      final template = templatesById[config.id];
      var upgraded = _withMigratedLegacyLocalPowerSeed(config, models);
      if (template != null && config.isDefault) {
        upgraded = _withRepairedDanglingDefaultSlots(
          upgraded,
          template,
          models,
        );
      }
      upgraded = _withUpgradedOmlxWhisperTranscription(upgraded, models);
      upgraded = _withUpgradedMeliousWhisperTranscription(
        upgraded,
        meliousModels,
      );
      upgraded = _withUpgradedMeliousFluxImageGeneration(
        upgraded,
        meliousModels,
      );
      upgraded = _withUpgradedMeliousDefaults(upgraded, meliousModels);
      upgraded = _withResolvedModelConfigIds(
        upgraded,
        models,
        preferredProviderIds: upgraded.id == profileMeliousId
            ? meliousProviderIds
            : null,
      );

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

  static AiConfigInferenceProfile _withUpgradedOmlxWhisperTranscription(
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

          return hasSlotForSkillType(upgraded, skill.skillType, models);
        })
        .toList(growable: false);

    return upgraded.copyWith(skillAssignments: sanitizedAssignments);
  }

  static AiConfigInferenceProfile _withUpgradedMeliousFluxImageGeneration(
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

  static AiConfigInferenceProfile _withUpgradedMeliousWhisperTranscription(
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
  static AiConfigInferenceProfile _withRepairedDanglingDefaultSlots(
    AiConfigInferenceProfile profile,
    AiConfigInferenceProfile template,
    List<AiConfigModel> models,
  ) {
    String? heal(String? current, String? seedDefault) {
      if (current == null) return null;
      if (_slotResolvesToModelRow(current, models)) return current;
      if (_isKnownProviderNativeModelId(current)) return current;
      return seedDefault;
    }

    return profile.copyWith(
      thinkingModelId:
          heal(profile.thinkingModelId, template.thinkingModelId) ??
          template.thinkingModelId,
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
  static AiConfigInferenceProfile _withUpgradedMeliousDefaults(
    AiConfigInferenceProfile profile,
    List<AiConfigModel> models,
  ) {
    if (profile.id != profileMeliousId ||
        profile.seedGeneration >= meliousProfileSeedGeneration) {
      return profile;
    }
    if (!_isUntouchedMeliousDefaultProfile(profile, models)) {
      return profile.copyWith(seedGeneration: meliousProfileSeedGeneration);
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
        ? upgraded.copyWith(seedGeneration: meliousProfileSeedGeneration)
        : upgraded;
  }

  /// Whether [profile] still carries only seeded Melious defaults — every
  /// slot matches a known default generation and no user-authored metadata
  /// (name, description, flags, pinned host) has been changed.
  static bool _isUntouchedMeliousDefaultProfile(
    AiConfigInferenceProfile profile,
    List<AiConfigModel> models,
  ) {
    return profile.id == profileMeliousId &&
        profile.seedGeneration < meliousProfileSeedGeneration &&
        profile.name == 'Melious.ai' &&
        profile.description == null &&
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

  static bool _meliousThinkingSlotMatchesDefaultOrLegacy(
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
  static bool _meliousTranscriptionSlotMatchesWhisperDefaultOrNull(
    String? slotValue,
    List<AiConfigModel> models,
  ) {
    return slotValue == null ||
        _meliousTranscriptionSlotMatchesDefaultOrLegacy(slotValue, models);
  }

  static bool _isUntouchedMeliousProfileEligibleForWhisperDefaultUpgrade(
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

  static bool _isUntouchedMeliousProfileEligibleForImageGenerationUpgrade(
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

  static bool _meliousTranscriptionSlotNeedsUpgrade(
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

  static bool _meliousTranscriptionSlotMatchesDefaultOrLegacy(
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

  static bool _meliousImageGenerationSlotMatchesDefaultOrLegacy(
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

  static bool _meliousImageGenerationSlotNeedsUpgrade(
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

  static bool _isUntouchedOmlxProfileMissingTranscription(
    AiConfigInferenceProfile profile,
    String expectedModelId,
    List<AiConfigModel> models,
  ) {
    return profile.description == null &&
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

  Future<List<AiConfigInferenceProvider>> _fetchProviderRows() async {
    final configs = await _repo.getConfigsByType(
      AiConfigType.inferenceProvider,
    );
    return configs.whereType<AiConfigInferenceProvider>().toList(
      growable: false,
    );
  }

  /// Whether [profile] is still an untouched default seed that no usable
  /// provider can serve — the only state [removeOrphanedDefaultSeeds] is
  /// allowed to delete.
  ///
  /// A slot value found in [usableModelSlotValues] means the profile can
  /// still serve requests (e.g. the user rewired it to another provider),
  /// so the cleanup pass must keep it.
  static bool _isRemovableOrphanedSeed(
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

  static AiConfigInferenceProfile _withResolvedModelConfigIds(
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

  static String? _resolveOptionalModelSlot(
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

  static String _resolveModelSlot(
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

  static Set<String>? _providerIdsForProfile(
    String profileId,
    List<AiConfigInferenceProvider> providers,
  ) {
    final providerType = providerTypeByProfileId[profileId];
    if (providerType == null) return null;
    return {
      for (final provider in providers)
        if (provider.inferenceProviderType == providerType) provider.id,
    };
  }

  /// Whether [slotValue] is a provider-native model ID from the bundled
  /// known-models catalog — a value runtime resolution can still satisfy once
  /// a provider of the owning type exists, and therefore not dangling.
  static bool _isKnownProviderNativeModelId(String slotValue) {
    return knownModelsByProvider.values.any(
      (models) => models.any((model) => model.providerModelId == slotValue),
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
      id: profileMeliousId,
      name: 'Melious.ai',
      thinkingModelId: meliousQwen35122BA10BModelId,
      thinkingHighEndModelId: meliousGlm52ModelId,
      imageRecognitionModelId: meliousMistralSmall4119BInstructModelId,
      transcriptionModelId: meliousVoxtralSmall24B2507ModelId,
      imageGenerationModelId: meliousFlux2Klein9BModelId,
      skillAssignments: _defaultSkillAssignments,
      isDefault: true,
      seedGeneration: meliousProfileSeedGeneration,
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
      transcriptionModelId: omlxWhisperLargeV3TurboModelId,
      skillAssignments: _defaultSkillAssignments,
      desktopOnly: true,
      createdAt: DateTime(2026),
    ),
    AiConfigInferenceProfile(
      id: profileLocalGemmaOmlxId,
      name: 'Local Gemma 4 (oMLX)',
      thinkingModelId: omlxGemma426BA4BItQatMlx4BitModelId,
      imageRecognitionModelId: omlxGemma426BA4BItQatMlx4BitModelId,
      transcriptionModelId: omlxWhisperLargeV3TurboModelId,
      skillAssignments: _defaultSkillAssignments,
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
