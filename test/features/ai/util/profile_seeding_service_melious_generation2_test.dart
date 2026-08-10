import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:mocktail/mocktail.dart';

import '../test_utils.dart';

/// Generation 2 of the bundled `Melious.ai` profile: GLM 5.2 thinking,
/// Kimi K3 high-end thinking *and* image recognition, Whisper Large v3
/// transcription. Image generation stays on Flux 2 Klein 9B.
///
/// These tests drive `upgradeExisting()` — the public entry point — rather
/// than the private migration, so they also cover the wiring into the upgrade
/// chain and the slot-id resolution that runs after it.
void main() {
  const meliousProviderId = 'melious-provider';

  late MockAiConfigRepository mockRepo;
  late ProfileSeedingService service;

  /// Melious-owned rows for every model the migration reads. Row ids are
  /// deliberately distinct from provider model ids, because a real install
  /// stores UUID row ids and the profile slots resolve to *those*.
  List<AiConfigModel> meliousModelRows({
    bool includeKimiK3 = true,
    bool includeWhisperLargeV3 = true,
    bool includeVoxtral = true,
    String providerId = meliousProviderId,
  }) {
    return [
      AiTestDataFactory.createTestModel(
        id: 'row-glm-52',
        providerModelId: meliousGlm52ModelId,
        inferenceProviderId: providerId,
      ),
      AiTestDataFactory.createTestModel(
        id: 'row-qwen',
        providerModelId: meliousQwen35122BA10BModelId,
        inferenceProviderId: providerId,
      ),
      AiTestDataFactory.createTestModel(
        id: 'row-mistral',
        providerModelId: meliousMistralSmall4119BInstructModelId,
        inferenceProviderId: providerId,
      ),
      // Backfill creates every curated Melious model, and the migrations
      // refuse to record a permanent decision while any row their shape check
      // reads is missing — so the fixture carries the legacy sources too.
      AiTestDataFactory.createTestModel(
        id: 'row-deepseek-pro',
        providerModelId: meliousDeepseekV4ProModelId,
        inferenceProviderId: providerId,
      ),
      AiTestDataFactory.createTestModel(
        id: 'row-whisper-turbo',
        providerModelId: meliousWhisperLargeV3TurboModelId,
        inferenceProviderId: providerId,
      ),
      if (includeVoxtral)
        AiTestDataFactory.createTestModel(
          id: 'row-voxtral',
          providerModelId: meliousVoxtralSmall24B2507ModelId,
          inferenceProviderId: providerId,
        ),
      AiTestDataFactory.createTestModel(
        id: 'row-flux',
        providerModelId: meliousFlux2Klein9BModelId,
        inferenceProviderId: providerId,
      ),
      if (includeKimiK3)
        AiTestDataFactory.createTestModel(
          id: 'row-kimi-k3',
          providerModelId: meliousKimiK3ModelId,
          inferenceProviderId: providerId,
        ),
      if (includeWhisperLargeV3)
        AiTestDataFactory.createTestModel(
          id: 'row-whisper-v3',
          providerModelId: meliousWhisperLargeV3ModelId,
          inferenceProviderId: providerId,
        ),
    ];
  }

  /// The exact generation-1 seed shape, with slots already resolved to row ids
  /// the way a real upgraded install stores them.
  AiConfigInferenceProfile generation1Profile({
    String name = 'Melious.ai',
    String? description,
    String? pinnedHostId,
    bool isDefault = true,
    bool desktopOnly = false,
    int seedGeneration = meliousProfileSeedGeneration1,
    String thinkingModelId = 'row-qwen',
    String? thinkingHighEndModelId = 'row-glm-52',
    String? imageRecognitionModelId = 'row-mistral',
    String? transcriptionModelId = 'row-voxtral',
    String? imageGenerationModelId = 'row-flux',
    String id = profileMeliousId,
  }) {
    return AiConfig.inferenceProfile(
          id: id,
          name: name,
          description: description,
          thinkingModelId: thinkingModelId,
          thinkingHighEndModelId: thinkingHighEndModelId,
          imageRecognitionModelId: imageRecognitionModelId,
          transcriptionModelId: transcriptionModelId,
          imageGenerationModelId: imageGenerationModelId,
          isDefault: isDefault,
          desktopOnly: desktopOnly,
          pinnedHostId: pinnedHostId,
          seedGeneration: seedGeneration,
          createdAt: DateTime(2026),
        )
        as AiConfigInferenceProfile;
  }

  void stubProfiles(List<AiConfig> profiles) {
    when(
      () => mockRepo.getConfigsByType(AiConfigType.inferenceProfile),
    ).thenAnswer((_) async => profiles);
  }

  void stubModels(List<AiConfig> models) {
    when(
      () => mockRepo.getConfigsByType(AiConfigType.model),
    ).thenAnswer((_) async => models);
  }

  /// The single profile written back by `upgradeExisting()`, or null when the
  /// pass decided nothing changed.
  AiConfigInferenceProfile? savedProfile(List<AiConfig> saved) {
    final profiles = saved.whereType<AiConfigInferenceProfile>().toList();
    return profiles.isEmpty ? null : profiles.last;
  }

  late List<AiConfig> saved;

  setUpAll(() {
    registerFallbackValue(
      AiConfig.inferenceProfile(
        id: 'fallback',
        name: 'Fallback',
        thinkingModelId: 'fallback-model',
        createdAt: DateTime(2024),
      ),
    );
  });

  setUp(() {
    mockRepo = MockAiConfigRepository();
    service = ProfileSeedingService(aiConfigRepository: mockRepo);
    saved = [];

    when(() => mockRepo.getConfigById(any())).thenAnswer((_) async => null);
    stubModels(meliousModelRows());
    stubProfiles(const []);
    when(
      () => mockRepo.getConfigsByType(AiConfigType.inferenceProvider),
    ).thenAnswer(
      (_) async => [
        AiTestDataFactory.createTestProvider(
          id: meliousProviderId,
          type: InferenceProviderType.melious,
        ),
      ],
    );
    when(() => mockRepo.saveConfig(any())).thenAnswer((invocation) async {
      saved.add(invocation.positionalArguments.first as AiConfig);
    });
  });

  group('generation-2 migration moves an untouched generation-1 profile', () {
    test(
      'rewires thinking, high-end, vision and transcription slots',
      () async {
        stubProfiles([generation1Profile()]);

        await service.upgradeExisting();

        final profile = savedProfile(saved);
        expect(profile, isNotNull);
        expect(
          profile!.thinkingModelId,
          'row-glm-52',
          reason: 'thinking moves from Qwen3.5 122B A10B to GLM 5.2',
        );
        expect(
          profile.thinkingHighEndModelId,
          'row-kimi-k3',
          reason: 'high-end thinking moves from GLM 5.2 to Kimi K3',
        );
        expect(
          profile.imageRecognitionModelId,
          'row-kimi-k3',
          reason: 'vision moves from Mistral Small 4 119B Instruct to Kimi K3',
        );
        expect(
          profile.transcriptionModelId,
          'row-whisper-v3',
          reason: 'transcription moves from Voxtral Small 24B to Whisper v3',
        );
      },
    );

    test('leaves image generation on Flux 2 Klein 9B', () async {
      stubProfiles([generation1Profile()]);

      await service.upgradeExisting();

      expect(savedProfile(saved)!.imageGenerationModelId, 'row-flux');
    });

    test('stamps generation 2 so the migration never runs twice', () async {
      stubProfiles([generation1Profile()]);

      await service.upgradeExisting();

      expect(
        savedProfile(saved)!.seedGeneration,
        meliousProfileSeedGeneration2,
      );
    });

    test('preserves the name, flags and skill assignments', () async {
      stubProfiles([generation1Profile()]);

      await service.upgradeExisting();

      final profile = savedProfile(saved)!;
      expect(profile.name, 'Melious.ai');
      expect(profile.isDefault, isTrue);
      expect(profile.desktopOnly, isFalse);
      expect(profile.pinnedHostId, isNull);
    });

    test('resolves slots against provider-native ids too', () async {
      // A profile whose slots were never rewritten to row ids — the shape a
      // pre-resolution install still carries.
      stubProfiles([
        generation1Profile(
          thinkingModelId: meliousQwen35122BA10BModelId,
          thinkingHighEndModelId: meliousGlm52ModelId,
          imageRecognitionModelId: meliousMistralSmall4119BInstructModelId,
          transcriptionModelId: meliousVoxtralSmall24B2507ModelId,
          imageGenerationModelId: meliousFlux2Klein9BModelId,
        ),
      ]);

      await service.upgradeExisting();

      final profile = savedProfile(saved)!;
      expect(profile.thinkingModelId, 'row-glm-52');
      expect(profile.thinkingHighEndModelId, 'row-kimi-k3');
      expect(profile.imageRecognitionModelId, 'row-kimi-k3');
      expect(profile.transcriptionModelId, 'row-whisper-v3');
      expect(profile.seedGeneration, meliousProfileSeedGeneration2);
    });
  });

  group('generation-2 migration leaves a user-edited profile alone', () {
    /// Each case is a single deviation from the generation-1 seed. All of them
    /// must keep every model slot exactly where the user left it, while still
    /// stamping generation 2 so the profile is not reconsidered every launch.
    final userEdits = <String, AiConfigInferenceProfile Function()>{
      'renamed': () => generation1Profile(name: 'My Melious'),
      'described': () => generation1Profile(description: 'my notes'),
      'pinned to a host': () => generation1Profile(pinnedHostId: 'host-1'),
      'marked desktop only': () => generation1Profile(desktopOnly: true),
      'no longer a default': () => generation1Profile(isDefault: false),
      'hand-picked thinking model': () =>
          generation1Profile(thinkingModelId: 'row-mistral'),
      'hand-picked high-end model': () =>
          generation1Profile(thinkingHighEndModelId: 'row-qwen'),
      'hand-picked vision model': () =>
          generation1Profile(imageRecognitionModelId: 'row-glm-52'),
      'hand-picked transcription model': () =>
          generation1Profile(transcriptionModelId: 'row-whisper-v3'),
      'hand-picked image generation model': () =>
          generation1Profile(imageGenerationModelId: 'row-glm-52'),
      'cleared its transcription slot': () =>
          generation1Profile(transcriptionModelId: null),
      'cleared its high-end slot': () =>
          generation1Profile(thinkingHighEndModelId: null),
    };

    for (final entry in userEdits.entries) {
      final description = entry.key;
      final buildProfile = entry.value;
      test('a profile the user $description keeps every slot', () async {
        final original = buildProfile();
        stubProfiles([original]);

        await service.upgradeExisting();

        final profile = savedProfile(saved);
        // Either written back with only the generation stamp, or not written
        // at all — never with a migrated slot.
        final effective = profile ?? original;
        expect(effective.thinkingModelId, original.thinkingModelId);
        expect(
          effective.thinkingHighEndModelId,
          original.thinkingHighEndModelId,
        );
        expect(
          effective.imageRecognitionModelId,
          original.imageRecognitionModelId,
        );
        expect(effective.transcriptionModelId, original.transcriptionModelId);
        expect(
          effective.imageGenerationModelId,
          original.imageGenerationModelId,
        );
        expect(effective.name, original.name);
      });
    }

    test(
      'stamps generation 2 so an edited profile is not reconsidered',
      () async {
        stubProfiles([generation1Profile(name: 'My Melious')]);

        await service.upgradeExisting();

        expect(
          savedProfile(saved)!.seedGeneration,
          meliousProfileSeedGeneration2,
        );
      },
    );
  });

  // A deleted model row is invisible to `upgradeExisting()` but present to
  // `backfillNewModels()`, which therefore never recreates it. The shape
  // predicates match slots by row lookup, so a deleted *source* row makes an
  // untouched slot look rewired — and the stamp that follows is permanent.
  group('a deleted source row is not mistaken for a user edit', () {
    test(
      'a generation-1 profile is not stamped when its Qwen row is deleted',
      () async {
        // Every generation-2 target is present; only the generation-1 source
        // the shape check reads is gone.
        stubModels(
          meliousModelRows().where((m) => m.id != 'row-qwen').toList(),
        );
        stubProfiles([generation1Profile()]);

        await service.upgradeExisting();

        expect(
          savedProfile(saved)?.seedGeneration ?? meliousProfileSeedGeneration1,
          meliousProfileSeedGeneration1,
          reason:
              'stamping here would permanently freeze the profile on the '
              'generation-1 models once the row came back',
        );
      },
    );

    test('and it migrates normally once that row is restored', () async {
      stubModels(meliousModelRows().where((m) => m.id != 'row-qwen').toList());
      stubProfiles([generation1Profile()]);
      await service.upgradeExisting();

      saved.clear();
      stubModels(meliousModelRows());
      stubProfiles([generation1Profile()]);
      await service.upgradeExisting();

      final profile = savedProfile(saved)!;
      expect(profile.thinkingModelId, 'row-glm-52');
      expect(profile.thinkingHighEndModelId, 'row-kimi-k3');
      expect(profile.imageRecognitionModelId, 'row-kimi-k3');
      expect(profile.seedGeneration, meliousProfileSeedGeneration2);
    });

    // The dangling-slot repair heals to the *current* template. Running it on
    // a profile that has not migrated yet writes a generation-2 value into a
    // generation-0 shape, which the migrations then read as a user edit.
    test(
      'a generation-0 profile with a dangling slot is not healed to the '
      'current template mid-migration',
      () async {
        stubModels(
          meliousModelRows().where((m) => m.id != 'row-deepseek-pro').toList(),
        );
        stubProfiles([
          generation1Profile(
            seedGeneration: 0,
            thinkingModelId: 'row-mistral',
            // Points at the now-deleted DeepSeek row.
            thinkingHighEndModelId: 'row-deepseek-pro',
            // ignore: avoid_redundant_argument_values
            imageRecognitionModelId: 'row-mistral',
            transcriptionModelId: 'row-whisper-v3',
          ),
        ]);

        await service.upgradeExisting();

        final profile = savedProfile(saved);
        expect(
          profile?.thinkingHighEndModelId ?? 'row-deepseek-pro',
          isNot('row-kimi-k3'),
          reason:
              'healing a pending profile to the generation-2 template makes '
              'the migration read it as user-edited and strands the rest',
        );
        expect(
          profile?.seedGeneration ?? 0,
          lessThan(meliousProfileSeedGeneration2),
          reason: 'the decision must wait for the missing row',
        );
      },
    );

    test(
      'that generation-0 profile completes fully once the row is restored',
      () async {
        stubModels(
          meliousModelRows().where((m) => m.id != 'row-deepseek-pro').toList(),
        );
        final legacy = generation1Profile(
          seedGeneration: 0,
          thinkingModelId: 'row-mistral',
          thinkingHighEndModelId: 'row-deepseek-pro',
          // ignore: avoid_redundant_argument_values
          imageRecognitionModelId: 'row-mistral',
          transcriptionModelId: 'row-whisper-v3',
        );
        stubProfiles([legacy]);
        await service.upgradeExisting();
        final afterFirstPass = savedProfile(saved) ?? legacy;

        saved.clear();
        stubModels(meliousModelRows());
        stubProfiles([afterFirstPass]);
        await service.upgradeExisting();

        final profile = savedProfile(saved)!;
        expect(profile.thinkingModelId, 'row-glm-52');
        expect(profile.thinkingHighEndModelId, 'row-kimi-k3');
        expect(profile.imageRecognitionModelId, 'row-kimi-k3');
        expect(profile.transcriptionModelId, 'row-whisper-v3');
        expect(profile.seedGeneration, meliousProfileSeedGeneration2);
      },
    );
  });

  group('generation-2 migration defers when the catalog cannot satisfy it', () {
    test('does not move any slot while the Kimi K3 row is missing', () async {
      stubModels(meliousModelRows(includeKimiK3: false));
      stubProfiles([generation1Profile()]);

      await service.upgradeExisting();

      // Nothing may move — a partial move would leave a shape the next pass
      // reads as a user edit, stranding the remaining slots forever.
      final profile = savedProfile(saved);
      expect(profile?.thinkingModelId ?? 'row-qwen', 'row-qwen');
      expect(profile?.thinkingHighEndModelId ?? 'row-glm-52', 'row-glm-52');
      expect(profile?.imageRecognitionModelId ?? 'row-mistral', 'row-mistral');
      expect(profile?.transcriptionModelId ?? 'row-voxtral', 'row-voxtral');
    });

    test(
      'does not stamp the generation while a target row is missing',
      () async {
        stubModels(meliousModelRows(includeKimiK3: false));
        stubProfiles([generation1Profile()]);

        await service.upgradeExisting();

        expect(
          savedProfile(saved)?.seedGeneration ?? meliousProfileSeedGeneration1,
          meliousProfileSeedGeneration1,
          reason: 'a deferred migration must remain pending for the next pass',
        );
      },
    );

    test(
      'does not move any slot while the Whisper v3 row is missing',
      () async {
        stubModels(meliousModelRows(includeWhisperLargeV3: false));
        stubProfiles([generation1Profile()]);

        await service.upgradeExisting();

        final profile = savedProfile(saved);
        expect(profile?.transcriptionModelId ?? 'row-voxtral', 'row-voxtral');
        expect(profile?.thinkingModelId ?? 'row-qwen', 'row-qwen');
      },
    );

    test('completes on a later pass once the rows arrive', () async {
      stubModels(meliousModelRows(includeKimiK3: false));
      stubProfiles([generation1Profile()]);
      await service.upgradeExisting();

      // Second pass: the backfill has since created the Kimi K3 row.
      saved.clear();
      stubModels(meliousModelRows());
      stubProfiles([generation1Profile()]);
      await service.upgradeExisting();

      final profile = savedProfile(saved)!;
      expect(profile.thinkingModelId, 'row-glm-52');
      expect(profile.thinkingHighEndModelId, 'row-kimi-k3');
      expect(profile.imageRecognitionModelId, 'row-kimi-k3');
      expect(profile.transcriptionModelId, 'row-whisper-v3');
      expect(profile.seedGeneration, meliousProfileSeedGeneration2);
    });

    test('ignores a matching row owned by a non-Melious provider', () async {
      // A foreign provider that happens to serve `kimi-k3` must not satisfy
      // the migration: the profile routes through Melious.
      stubModels([
        ...meliousModelRows(includeKimiK3: false),
        AiTestDataFactory.createTestModel(
          id: 'row-foreign-kimi',
          providerModelId: meliousKimiK3ModelId,
          inferenceProviderId: 'some-openai-provider',
        ),
      ]);
      stubProfiles([generation1Profile()]);

      await service.upgradeExisting();

      final profile = savedProfile(saved);
      expect(profile?.thinkingHighEndModelId ?? 'row-glm-52', 'row-glm-52');
      expect(profile?.imageRecognitionModelId ?? 'row-mistral', 'row-mistral');
    });
  });

  group('generation-2 migration guards', () {
    test('never touches a profile that already reached generation 2', () async {
      stubProfiles([
        generation1Profile(seedGeneration: meliousProfileSeedGeneration2),
      ]);

      await service.upgradeExisting();

      verifyNever(() => mockRepo.saveConfig(any()));
    });

    test('never touches a non-Melious profile with the same shape', () async {
      stubProfiles([
        generation1Profile(id: profileMistralEuId, name: 'Mistral (EU)'),
      ]);

      await service.upgradeExisting();

      final profile = savedProfile(saved);
      expect(profile?.thinkingModelId ?? 'row-qwen', 'row-qwen');
      expect(profile?.thinkingHighEndModelId ?? 'row-glm-52', 'row-glm-52');
    });
  });

  group('generation chaining', () {
    // Regression guard. The generation-1 pass defers *without* stamping when
    // one of its own targets is missing, having already moved the slots it
    // could. Generation 2 used to run on that half-moved shape, fail its
    // exact-shape check, and stamp itself over a profile that had reached
    // neither generation — permanently, because the stamp is never undone.
    //
    // A deleted model row is enough to get there: deletion is a tombstone, so
    // `backfillNewModels` reads the row as present and never recreates it,
    // while this pass reads without `includeDeleted` and cannot see it.
    test(
      'a generation-0 profile whose generation-1 target is missing is left '
      'pending rather than stamped',
      () async {
        stubModels([
          // Voxtral — a generation-1 target — has been deleted by the user.
          ...meliousModelRows(includeVoxtral: false),
          AiTestDataFactory.createTestModel(
            id: 'row-deepseek-pro',
            providerModelId: meliousDeepseekV4ProModelId,
            inferenceProviderId: meliousProviderId,
          ),
        ]);
        stubProfiles([
          generation1Profile(
            seedGeneration: 0,
            thinkingModelId: 'row-mistral',
            thinkingHighEndModelId: 'row-deepseek-pro',
            // ignore: avoid_redundant_argument_values
            imageRecognitionModelId: 'row-mistral',
            transcriptionModelId: 'row-whisper-v3',
          ),
        ]);

        await service.upgradeExisting();

        final profile = savedProfile(saved);
        expect(
          profile?.seedGeneration ?? 0,
          lessThan(meliousProfileSeedGeneration2),
          reason:
              'stamping generation 2 here would freeze the profile forever on '
              'models it was supposed to move off',
        );
      },
    );

    test(
      'that pending profile completes both generations once the row returns',
      () async {
        stubModels(meliousModelRows(includeVoxtral: false));
        final stranded = generation1Profile(
          seedGeneration: 0,
          thinkingModelId: 'row-mistral',
          thinkingHighEndModelId: 'row-deepseek-pro',
          // ignore: avoid_redundant_argument_values
          imageRecognitionModelId: 'row-mistral',
          transcriptionModelId: 'row-whisper-v3',
        );
        stubProfiles([stranded]);
        await service.upgradeExisting();

        // Whatever the deferred pass left behind is what the next pass reads.
        final afterFirstPass = savedProfile(saved) ?? stranded;

        // The user restores the Voxtral row; the next pass must complete.
        saved.clear();
        stubModels(meliousModelRows());
        stubProfiles([afterFirstPass]);
        await service.upgradeExisting();

        final profile = savedProfile(saved)!;
        expect(profile.thinkingModelId, 'row-glm-52');
        expect(profile.thinkingHighEndModelId, 'row-kimi-k3');
        expect(profile.imageRecognitionModelId, 'row-kimi-k3');
        expect(profile.transcriptionModelId, 'row-whisper-v3');
        expect(profile.seedGeneration, meliousProfileSeedGeneration2);
      },
    );

    test(
      'a generation-0 profile chains through both generations in one pass',
      () async {
        // The pre-generation-1 shape: Mistral thinking, DeepSeek high-end,
        // Mistral vision, Whisper transcription, Flux 2 dev image generation.
        stubModels(meliousModelRows());
        stubProfiles([
          generation1Profile(
            seedGeneration: 0,
            thinkingModelId: 'row-mistral',
            thinkingHighEndModelId: 'row-deepseek-pro',
            // Spelled out so the whole generation-0 shape reads at a glance.
            // ignore: avoid_redundant_argument_values
            imageRecognitionModelId: 'row-mistral',
            transcriptionModelId: 'row-whisper-v3',
          ),
        ]);

        await service.upgradeExisting();

        final profile = savedProfile(saved)!;
        expect(
          profile.thinkingModelId,
          'row-glm-52',
          reason:
              'generation 0 -> 1 moves to Qwen, then 1 -> 2 moves to GLM 5.2',
        );
        expect(profile.thinkingHighEndModelId, 'row-kimi-k3');
        expect(profile.imageRecognitionModelId, 'row-kimi-k3');
        expect(profile.transcriptionModelId, 'row-whisper-v3');
        expect(profile.seedGeneration, meliousProfileSeedGeneration2);
      },
    );

    test(
      'a generation-0 profile the user edited is stamped straight to '
      'generation 2 with every slot intact',
      () async {
        stubProfiles([
          generation1Profile(
            seedGeneration: 0,
            name: 'My Melious',
            thinkingModelId: 'row-mistral',
          ),
        ]);

        await service.upgradeExisting();

        // Both migrations must recognise it as edited and decline to move it,
        // while still stamping it forward so neither reconsiders it again.
        final profile = savedProfile(saved)!;
        expect(profile.name, 'My Melious');
        expect(profile.thinkingModelId, 'row-mistral');
        expect(profile.thinkingHighEndModelId, 'row-glm-52');
        expect(profile.imageRecognitionModelId, 'row-mistral');
        expect(profile.transcriptionModelId, 'row-voxtral');
        expect(profile.seedGeneration, meliousProfileSeedGeneration2);
      },
    );
  });
}
