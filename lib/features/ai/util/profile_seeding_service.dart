import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/ai/skill_assignment.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:meta/meta.dart';

part 'profile_seeding_service_mistral_skill_assignments_part.dart';
part 'profile_seeding_service_internals.dart';
part 'profile_seeding_service_builders.dart';

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
    required this._domainLogger,
  }) : _repo = aiConfigRepository;

  final AiConfigRepository _repo;

  /// Receives the counts of seeded, upgraded and removed profiles.
  final DomainLogger _domainLogger;

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
    profileMeliousFlashId: InferenceProviderType.melious,
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
      // Deleted rows count as present: `deletedAt` is what tells a deletion
      // apart from a row that was never seeded, so asking for them here is
      // what makes the user's deletion stick across launches and devices.
      final existing = await _repo.getConfigById(
        template.id,
        includeDeleted: true,
      );
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
      _domainLogger.log(
        LogDomain.ai,
        'Profiles: seeded $seededCount',
        subDomain: _logTag,
      );
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
      // Not a user deletion: this pass removes seeds whose provider became
      // unusable and deliberately re-seeds them if the provider returns, so it
      // must leave no `deletedAt` behind.
      // fromSync: true keeps the removal local. Whether a provider is usable
      // is a per-device fact, so propagating this delete would strip the
      // profile from a peer that can still serve it. Without a version stamp
      // the device also forgets the version it held, so a peer's next copy
      // of the profile applies again (ADR 0094).
      await _repo.hardDeleteConfig(config.id, fromSync: true);
      removedCount++;
    }

    if (removedCount > 0) {
      _domainLogger.log(
        LogDomain.ai,
        'Profiles: removed $removedCount orphaned default seeds',
        subDomain: _logTag,
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
  /// high-end, and Voxtral transcription defaults (generation 1), then moves
  /// untouched generation-1 Melious profiles to GLM 5.2 thinking, Kimi K3
  /// high-end and vision, and Whisper Large v3 transcription (generation 2).
  /// Default skill assignments are deliberately not backfilled.
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
      // The repair heals a dangling slot to the *current* template's value,
      // which is only the right answer once the profile has reached the
      // current generation. Healing a Melious profile that is still mid-
      // migration writes a generation-2 value into a generation-0 or -1
      // shape, and the migrations — which recognise exact shapes — then read
      // that as a user edit and strand the remaining legacy slots. The
      // pending migration supersedes the repair, so skip it and let the next
      // pass heal once the generation matches the template.
      final meliousMigrationPending =
          config.id == profileMeliousId &&
          config.seedGeneration < meliousProfileSeedGeneration;
      if (template != null && config.isDefault && !meliousMigrationPending) {
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
      upgraded = _withUpgradedMeliousGeneration2Defaults(
        upgraded,
        meliousModels,
      );
      upgraded = _withResolvedModelConfigIds(
        upgraded,
        models,
        preferredProviderIds: upgraded.id == profileMeliousId
            ? meliousProviderIds
            : null,
      );

      // NOTE: default skill assignments are deliberately NOT backfilled here.
      // The guard used to be `skillAssignments.isEmpty`, so clearing every
      // assignment — the obvious way to say "stop doing things automatically"
      // — was exactly what triggered restoring them with `automate: true` on
      // the next launch. Seeding a profile at creation is the only place
      // automation defaults are written.

      if (upgraded == config) continue;
      await _repo.saveConfig(upgraded);
      upgradedCount++;
    }

    if (upgradedCount > 0) {
      _domainLogger.log(
        LogDomain.ai,
        'Upgraded $upgradedCount inference profiles',
        subDomain: _logTag,
      );
    }
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
      // slot falls back to it at resolution time). Audio summarization runs
      // on the same slot, deliberately: it publishes through a pinned tool
      // call, and the thinking slot is the one the profile form constrains
      // to tool-capable models.
      SkillType.promptGeneration => _slotResolvesToModelRow(
        profile.thinkingModelId,
        models,
      ),
      SkillType.audioSummary => _slotResolvesToModelRow(
        profile.thinkingModelId,
        models,
      ),
      SkillType.imagePromptGeneration => _slotResolvesToModelRow(
        profile.thinkingModelId,
        models,
      ),
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
      id: profileMeliousId,
      name: 'Melious.ai',
      thinkingModelId: meliousGlm52ModelId,
      thinkingHighEndModelId: meliousKimiK3ModelId,
      imageRecognitionModelId: meliousKimiK3ModelId,
      transcriptionModelId: meliousWhisperLargeV3ModelId,
      imageGenerationModelId: meliousFlux2Klein9BModelId,
      skillAssignments: _defaultSkillAssignments,
      isDefault: true,
      seedGeneration: meliousProfileSeedGeneration,
      createdAt: DateTime(2026),
    ),
    // The same Melious stack with the cheap, fast thinking model in front.
    //
    // Measured against `Melious.ai`'s GLM 5.2 on the task-agent suite: same
    // pass rate over three identical runs (17/17 every time, where GLM and
    // Qwen each dropped a case to run-to-run noise), roughly a third of the
    // latency, and an order of magnitude less billed credit per wake. The
    // agent scenarios cannot tell the models apart on quality, so cost and
    // latency are what is left to choose on, and this is the cheap end.
    //
    // Thinking only. DeepSeek V4 Flash is text-in, text-out, so vision stays
    // on Kimi K3 and the high-end slot keeps it too — a cheaper default is
    // worth having precisely because the expensive model is still one slot
    // away when a task needs it.
    AiConfigInferenceProfile(
      id: profileMeliousFlashId,
      name: 'Melious.ai (Flash)',
      description:
          'Fast, low-cost Melious profile: DeepSeek V4 Flash for everyday '
          'thinking, Kimi K3 for high-end reasoning and vision.',
      thinkingModelId: meliousDeepseekV4FlashModelId,
      thinkingHighEndModelId: meliousKimiK3ModelId,
      imageRecognitionModelId: meliousKimiK3ModelId,
      transcriptionModelId: meliousWhisperLargeV3ModelId,
      imageGenerationModelId: meliousFlux2Klein9BModelId,
      skillAssignments: _defaultSkillAssignments,
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
