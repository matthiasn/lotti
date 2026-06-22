import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/util/active_profile.dart';

import '../../../test_utils.dart';

void main() {
  group('modelByProfileSlotId', () {
    test('resolves canonical model row ids and unique provider model ids', () {
      final model = AiTestDataFactory.createTestModel(
        id: 'model-row-id',
        name: 'Mistral Small',
        providerModelId: 'mistral-small-provider-id',
      );

      final bySlotId = modelByProfileSlotId([model]);

      expect(bySlotId['model-row-id'], same(model));
      expect(bySlotId['mistral-small-provider-id'], same(model));
    });

    test('does not resolve ambiguous provider-native model ids', () {
      final first = AiTestDataFactory.createTestModel(
        id: 'first-row-id',
        providerModelId: 'shared-provider-model-id',
        inferenceProviderId: 'provider-1',
      );
      final second = AiTestDataFactory.createTestModel(
        id: 'second-row-id',
        providerModelId: 'shared-provider-model-id',
        inferenceProviderId: 'provider-2',
      );

      final bySlotId = modelByProfileSlotId([first, second]);

      expect(bySlotId['first-row-id'], same(first));
      expect(bySlotId['second-row-id'], same(second));
      expect(bySlotId['shared-provider-model-id'], isNull);
    });
  });

  group('pickActiveProfileForProvider', () {
    test('returns null when there are no provider models', () {
      final profile = AiTestDataFactory.createTestProfile(
        id: 'p1',
        thinkingModelId: 'gpt-5',
      );
      expect(
        pickActiveProfileForProvider(
          profiles: [profile],
          providerModels: const [],
        ),
        isNull,
      );
    });

    test('returns null when the profile list is empty', () {
      final model = AiTestDataFactory.createTestModel(
        id: 'm1',
        providerModelId: 'gpt-5',
        inferenceProviderId: 'prov-openai',
      );
      expect(
        pickActiveProfileForProvider(
          profiles: const [],
          providerModels: [model],
        ),
        isNull,
      );
    });

    test('returns null when no profile slot references a provider model', () {
      // Provider has a model the user installed, but every profile's
      // slots point at models from a different provider — no winner.
      final providerModel = AiTestDataFactory.createTestModel(
        id: 'm-claude',
        providerModelId: 'claude-sonnet',
        inferenceProviderId: 'prov-anthropic',
      );
      final geminiProfile = AiTestDataFactory.createTestProfile(
        id: 'p-gemini',
        thinkingModelId: 'gemini-flash',
        isDefault: true,
      );
      expect(
        pickActiveProfileForProvider(
          profiles: [geminiProfile],
          providerModels: [providerModel],
        ),
        isNull,
      );
    });

    test('prefers a default-marked profile when it touches the provider', () {
      // Two profiles both touch the provider's model. The default one
      // wins regardless of list order — guards the documented
      // heuristic from a "first-touching wins" regression.
      final providerModel = AiTestDataFactory.createTestModel(
        id: 'm1',
        providerModelId: 'gpt-5',
        inferenceProviderId: 'prov-openai',
      );
      final nonDefault = AiTestDataFactory.createTestProfile(
        id: 'p-nondefault',
        thinkingModelId: 'gpt-5',
      );
      final defaultProfile = AiTestDataFactory.createTestProfile(
        id: 'p-default',
        thinkingModelId: 'gpt-5',
        isDefault: true,
      );
      // Non-default listed first to make sure ordering doesn't decide
      // the outcome — the default still has to win.
      final winner = pickActiveProfileForProvider(
        profiles: [nonDefault, defaultProfile],
        providerModels: [providerModel],
      );
      expect(winner?.id, 'p-default');
    });

    test(
      'falls back to the first non-default profile when no default touches',
      () {
        final providerModel = AiTestDataFactory.createTestModel(
          id: 'm1',
          providerModelId: 'gpt-5',
          inferenceProviderId: 'prov-openai',
        );
        final defaultElsewhere = AiTestDataFactory.createTestProfile(
          id: 'p-default-elsewhere',
          thinkingModelId: 'gemini-flash',
          isDefault: true,
        );
        final firstNonDefault = AiTestDataFactory.createTestProfile(
          id: 'p-first',
          thinkingModelId: 'gpt-5',
        );
        final secondNonDefault = AiTestDataFactory.createTestProfile(
          id: 'p-second',
          thinkingModelId: 'gpt-5',
        );
        final winner = pickActiveProfileForProvider(
          profiles: [defaultElsewhere, firstNonDefault, secondNonDefault],
          providerModels: [providerModel],
        );
        expect(winner?.id, 'p-first');
      },
    );

    test(
      'matches a slot other than thinkingModelId — every non-thinking slot '
      'is checked symmetrically',
      () {
        // Parametrised over each non-thinking slot. The factory's
        // required thinkingModelId is pointed at something unrelated
        // so the match has to come from the slot under test.
        final cases = <String, AiConfigInferenceProfile>{
          'transcriptionModelId': AiTestDataFactory.createTestProfile(
            id: 'p-transcribe',
            thinkingModelId: 'unrelated',
            transcriptionModelId: 'target-model',
          ),
          'imageRecognitionModelId': AiTestDataFactory.createTestProfile(
            id: 'p-vision',
            thinkingModelId: 'unrelated',
            imageRecognitionModelId: 'target-model',
          ),
          'imageGenerationModelId': AiTestDataFactory.createTestProfile(
            id: 'p-imagegen',
            thinkingModelId: 'unrelated',
            imageGenerationModelId: 'target-model',
          ),
        };
        final model = AiTestDataFactory.createTestModel(
          providerModelId: 'target-model',
        );
        for (final entry in cases.entries) {
          final winner = pickActiveProfileForProvider(
            profiles: [entry.value],
            providerModels: [model],
          );
          expect(
            winner?.id,
            entry.value.id,
            reason: 'slot ${entry.key} should count as touching',
          );
        }
      },
    );
  });

  group('activeProfileIdsForProviders', () {
    test('returns empty set when there are no providers', () {
      final profile = AiTestDataFactory.createTestProfile(
        id: 'p1',
        thinkingModelId: 'gpt-5',
        isDefault: true,
      );
      expect(
        activeProfileIdsForProviders(
          providers: const [],
          models: const [],
          profiles: [profile],
        ),
        isEmpty,
        reason:
            'No configured providers → no Active badges. This is the '
            'whole point of the wiring change.',
      );
    });

    test(
      'a default profile that touches no configured provider does NOT earn '
      'the badge — fixes the legacy "christmas-tree" symptom where every '
      'seeded `isDefault: true` profile lit up regardless of setup state',
      () {
        // User has only Gemini set up. Seeded OpenAI / Claude / Alibaba /
        // Ollama profiles are all `isDefault: true` but their slots
        // reference models that don't belong to any configured provider,
        // so none of them should be flagged active.
        final geminiProvider = AiTestDataFactory.createTestProvider(
          id: 'prov-gemini',
          type: InferenceProviderType.gemini,
        );
        final geminiModel = AiTestDataFactory.createTestModel(
          id: 'm-gemini',
          providerModelId: 'gemini-flash',
          inferenceProviderId: 'prov-gemini',
        );
        final geminiProfile = AiTestDataFactory.createTestProfile(
          id: 'p-gemini',
          thinkingModelId: 'gemini-flash',
          isDefault: true,
        );
        final openAiProfile = AiTestDataFactory.createTestProfile(
          id: 'p-openai',
          thinkingModelId: 'gpt-5',
          isDefault: true,
        );
        final claudeProfile = AiTestDataFactory.createTestProfile(
          id: 'p-claude',
          thinkingModelId: 'claude-sonnet',
          isDefault: true,
        );
        final ollamaProfile = AiTestDataFactory.createTestProfile(
          id: 'p-ollama',
          thinkingModelId: 'qwen3.5:9b',
          isDefault: true,
        );
        final activeIds = activeProfileIdsForProviders(
          providers: [geminiProvider],
          models: [geminiModel],
          profiles: [
            geminiProfile,
            openAiProfile,
            claudeProfile,
            ollamaProfile,
          ],
        );
        expect(activeIds, equals({'p-gemini'}));
      },
    );

    test(
      'a configured provider with no models contributes no winner — drafts '
      'and unseeded providers stay quiet instead of guessing',
      () {
        final draftProvider = AiTestDataFactory.createTestProvider(
          id: 'prov-anthropic-draft',
          apiKey: '',
        );
        final claudeProfile = AiTestDataFactory.createTestProfile(
          id: 'p-claude',
          thinkingModelId: 'claude-sonnet',
          isDefault: true,
        );
        expect(
          activeProfileIdsForProviders(
            providers: [draftProvider],
            models: const [],
            profiles: [claudeProfile],
          ),
          isEmpty,
        );
      },
    );

    test(
      'unions winners across multiple configured providers — one badge per '
      'provider, ids deduplicated when the same profile wins twice',
      () {
        // User has Gemini + OpenAI + Anthropic configured. Each has its
        // own winning profile → three ids. The OpenAI provider also
        // owns a model that the Gemini-winner profile happens to
        // touch — but because the picker returns a single winner per
        // provider, that doesn't double-add anything.
        final gemini = AiTestDataFactory.createTestProvider(
          id: 'prov-gemini',
          type: InferenceProviderType.gemini,
        );
        final openai = AiTestDataFactory.createTestProvider(
          id: 'prov-openai',
          type: InferenceProviderType.openAi,
        );
        final anthropic = AiTestDataFactory.createTestProvider(
          id: 'prov-anthropic',
        );
        final geminiModel = AiTestDataFactory.createTestModel(
          id: 'm-gemini',
          providerModelId: 'gemini-flash',
          inferenceProviderId: 'prov-gemini',
        );
        final openaiModel = AiTestDataFactory.createTestModel(
          id: 'm-openai',
          providerModelId: 'gpt-5',
          inferenceProviderId: 'prov-openai',
        );
        final claudeModel = AiTestDataFactory.createTestModel(
          id: 'm-claude',
          providerModelId: 'claude-sonnet',
          inferenceProviderId: 'prov-anthropic',
        );
        final geminiProfile = AiTestDataFactory.createTestProfile(
          id: 'p-gemini',
          thinkingModelId: 'gemini-flash',
          isDefault: true,
        );
        final openaiProfile = AiTestDataFactory.createTestProfile(
          id: 'p-openai',
          thinkingModelId: 'gpt-5',
          isDefault: true,
        );
        final claudeProfile = AiTestDataFactory.createTestProfile(
          id: 'p-claude',
          thinkingModelId: 'claude-sonnet',
          isDefault: true,
        );
        final activeIds = activeProfileIdsForProviders(
          providers: [gemini, openai, anthropic],
          models: [geminiModel, openaiModel, claudeModel],
          profiles: [geminiProfile, openaiProfile, claudeProfile],
        );
        expect(activeIds, equals({'p-gemini', 'p-openai', 'p-claude'}));
      },
    );

    test(
      'a cross-provider profile (slots referencing models from two '
      'providers) is reported once, not twice — set semantics',
      () {
        // Mixed profile: thinking → Gemini, transcription → OpenAI.
        // Each provider returns the same winner, so the resulting set
        // contains a single id.
        final gemini = AiTestDataFactory.createTestProvider(
          id: 'prov-gemini',
          type: InferenceProviderType.gemini,
        );
        final openai = AiTestDataFactory.createTestProvider(
          id: 'prov-openai',
          type: InferenceProviderType.openAi,
        );
        final geminiModel = AiTestDataFactory.createTestModel(
          id: 'm-gemini',
          providerModelId: 'gemini-flash',
          inferenceProviderId: 'prov-gemini',
        );
        final openaiModel = AiTestDataFactory.createTestModel(
          id: 'm-openai-audio',
          providerModelId: 'gpt-4o-transcribe',
          inferenceProviderId: 'prov-openai',
        );
        final crossProfile = AiTestDataFactory.createTestProfile(
          id: 'p-mixed',
          thinkingModelId: 'gemini-flash',
          transcriptionModelId: 'gpt-4o-transcribe',
          isDefault: true,
        );
        final activeIds = activeProfileIdsForProviders(
          providers: [gemini, openai],
          models: [geminiModel, openaiModel],
          profiles: [crossProfile],
        );
        expect(activeIds, equals({'p-mixed'}));
      },
    );
  });

  group('activeProfileIdsForProviders — configured-only gate', () {
    // These cases guard the parallel between the picker and
    // `AiProviderCardStatus.statusFor`: if the provider card's status
    // pill would read "Invalid key" or "Offline", its profile must
    // not earn the Active badge — same definition, two surfaces.

    test(
      'cloud provider in DRAFT state (empty apiKey) does NOT badge even '
      'when its models exist — guards against a stale draft row whose '
      'backfilled model rows accidentally lit up its profile',
      () {
        // Cloud provider with an empty API key, yet `models` somehow
        // contains rows owned by it (the model-prepopulation backfill
        // can leave models behind after an API key is cleared).
        final draftOpenAi = AiTestDataFactory.createTestProvider(
          id: 'prov-openai-draft',
          type: InferenceProviderType.openAi,
          apiKey: '',
        );
        final openaiModel = AiTestDataFactory.createTestModel(
          id: 'm-openai',
          providerModelId: 'gpt-5',
          inferenceProviderId: 'prov-openai-draft',
        );
        final openaiProfile = AiTestDataFactory.createTestProfile(
          id: 'p-openai',
          thinkingModelId: 'gpt-5',
          isDefault: true,
        );
        expect(
          activeProfileIdsForProviders(
            providers: [draftOpenAi],
            models: [openaiModel],
            profiles: [openaiProfile],
          ),
          isEmpty,
          reason:
              'A draft provider card reads "Invalid key" — its '
              'profile must not earn the green Active badge.',
        );
      },
    );

    test(
      'Ollama with an empty baseUrl does NOT badge even when models exist '
      '— matches the provider card showing "Offline" in that state',
      () {
        final ollamaProvider = AiTestDataFactory.createTestProvider(
          id: 'prov-ollama',
          type: InferenceProviderType.ollama,
          apiKey: '',
          baseUrl: '',
        );
        final ollamaModel = AiTestDataFactory.createTestModel(
          id: 'm-ollama',
          providerModelId: 'qwen3.5:9b',
          inferenceProviderId: 'prov-ollama',
        );
        final ollamaProfile = AiTestDataFactory.createTestProfile(
          id: 'p-ollama',
          thinkingModelId: 'qwen3.5:9b',
          isDefault: true,
        );
        expect(
          activeProfileIdsForProviders(
            providers: [ollamaProvider],
            models: [ollamaModel],
            profiles: [ollamaProfile],
          ),
          isEmpty,
        );
      },
    );

    test(
      'Ollama with a baseUrl but no model rows does NOT badge — matches '
      'the provider card showing "Offline · Make sure Ollama is running"',
      () {
        final ollamaProvider = AiTestDataFactory.createTestProvider(
          id: 'prov-ollama',
          type: InferenceProviderType.ollama,
          apiKey: '',
          baseUrl: 'http://localhost:11434',
        );
        final ollamaProfile = AiTestDataFactory.createTestProfile(
          id: 'p-ollama',
          thinkingModelId: 'qwen3.5:9b',
          isDefault: true,
        );
        expect(
          activeProfileIdsForProviders(
            providers: [ollamaProvider],
            models: const [],
            profiles: [ollamaProfile],
          ),
          isEmpty,
        );
      },
    );

    test(
      'Ollama with both a baseUrl AND at least one model row DOES badge '
      '— consistent with the provider card showing "Connected · N models"',
      () {
        final ollamaProvider = AiTestDataFactory.createTestProvider(
          id: 'prov-ollama',
          type: InferenceProviderType.ollama,
          apiKey: '',
          baseUrl: 'http://localhost:11434',
        );
        final ollamaModel = AiTestDataFactory.createTestModel(
          id: 'm-ollama',
          providerModelId: 'qwen3.5:9b',
          inferenceProviderId: 'prov-ollama',
        );
        final ollamaProfile = AiTestDataFactory.createTestProfile(
          id: 'p-ollama',
          thinkingModelId: 'qwen3.5:9b',
          isDefault: true,
        );
        expect(
          activeProfileIdsForProviders(
            providers: [ollamaProvider],
            models: [ollamaModel],
            profiles: [ollamaProfile],
          ),
          equals({'p-ollama'}),
          reason:
              'When the provider card says "Connected", the matching '
              'profile must earn the Active badge — same definition, two '
              'surfaces.',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Glados properties over generated profile/model mixes.
  // ---------------------------------------------------------------------------
  group('pickActiveProfileForProvider — properties', () {
    glados.Glados(
      glados.any.list(glados.IntAnys(glados.any).intInRange(0, 1 << 10)),
      // ignore: avoid_redundant_argument_values
      glados.ExploreConfig(numRuns: 100),
    ).test('winner is from the input list, touches a provider model, and '
        'prefers defaults', (seeds) {
      // One provider model id; each seed shapes a profile: bit0 = slot
      // touches the provider model, bit1 = isDefault.
      const ownedId = 'owned-model';
      final providerModels = [
        AiTestDataFactory.createTestModel(
          id: 'm-owned',
          providerModelId: ownedId,
          inferenceProviderId: 'prov-1',
        ),
      ];
      final profiles = [
        for (final (i, seed) in seeds.indexed)
          AiTestDataFactory.createTestProfile(
            id: 'p$i',
            thinkingModelId: seed.isEven ? ownedId : 'foreign-$i',
            isDefault: seed & 2 != 0,
          ),
      ];

      final winner = pickActiveProfileForProvider(
        profiles: profiles,
        providerModels: providerModels,
      );

      final touching = profiles
          .where((p) => p.thinkingModelId == ownedId)
          .toList();
      if (touching.isEmpty) {
        expect(winner, isNull, reason: '$seeds');
      } else {
        // Winner belongs to the input list and touches the provider model.
        expect(profiles, contains(winner));
        expect(winner!.thinkingModelId, ownedId);
        // A default-marked toucher always beats a non-default one.
        final defaults = touching.where((p) => p.isDefault);
        if (defaults.isNotEmpty) {
          expect(winner.isDefault, isTrue, reason: '$seeds');
        } else {
          expect(winner, same(touching.first), reason: '$seeds');
        }
      }
    }, tags: 'glados');
  });

  group('activeProfileIdsForProviders — properties', () {
    glados.Glados(
      glados.any.list(glados.IntAnys(glados.any).intInRange(0, 1 << 10)),
      // ignore: avoid_redundant_argument_values
      glados.ExploreConfig(numRuns: 100),
    ).test('result is always a subset of the input profile ids', (seeds) {
      const ownedId = 'owned-model';
      final provider = AiTestDataFactory.createTestProvider(id: 'prov-1');
      final models = [
        AiTestDataFactory.createTestModel(
          id: 'm-owned',
          providerModelId: ownedId,
          inferenceProviderId: 'prov-1',
        ),
      ];
      final profiles = [
        for (final (i, seed) in seeds.indexed)
          AiTestDataFactory.createTestProfile(
            id: 'p$i',
            thinkingModelId: seed.isEven ? ownedId : 'foreign-$i',
            isDefault: seed & 2 != 0,
          ),
      ];

      final ids = activeProfileIdsForProviders(
        providers: [provider],
        models: models,
        profiles: profiles,
      );

      expect(
        ids.difference(profiles.map((p) => p.id).toSet()),
        isEmpty,
        reason: '$seeds',
      );
      // At most one active profile per single provider.
      expect(ids.length, lessThanOrEqualTo(1));
    }, tags: 'glados');
  });
}
