import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/helpers/profile_locality.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

AiConfigInferenceProfile _profile({
  String id = 'profile-1',
  String thinkingModelId = 'thinking-model',
  String? thinkingHighEndModelId,
  String? imageRecognitionModelId,
  String? transcriptionModelId,
  String? imageGenerationModelId,
}) {
  return AiConfig.inferenceProfile(
        id: id,
        name: 'Test',
        createdAt: DateTime.utc(2026, 3, 15),
        thinkingModelId: thinkingModelId,
        thinkingHighEndModelId: thinkingHighEndModelId,
        imageRecognitionModelId: imageRecognitionModelId,
        transcriptionModelId: transcriptionModelId,
        imageGenerationModelId: imageGenerationModelId,
      )
      as AiConfigInferenceProfile;
}

AiConfigModel _model({
  required String id,
  required String inferenceProviderId,
  String? providerModelId,
}) {
  // Profile slots store `providerModelId`, not the row's primary key
  // (see `ai_config.dart` docstring on `inferenceProfile`). Default the
  // factory to the matching shape used by production seeders.
  return AiConfig.model(
        id: id,
        name: id,
        providerModelId: providerModelId ?? id,
        inferenceProviderId: inferenceProviderId,
        createdAt: DateTime.utc(2026, 3, 15),
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
      )
      as AiConfigModel;
}

AiConfigInferenceProvider _provider({
  required String id,
  required InferenceProviderType type,
}) {
  return AiConfig.inferenceProvider(
        id: id,
        baseUrl: '',
        apiKey: '',
        name: type.name,
        inferenceProviderType: type,
        createdAt: DateTime.utc(2026, 3, 15),
      )
      as AiConfigInferenceProvider;
}

void main() {
  late MockAiConfigRepository repo;

  /// Models registered for the current test, keyed by `providerModelId` so
  /// `getConfigsByType(AiConfigType.model)` returns a consistent snapshot
  /// (production lookup is by `providerModelId`, not row primary key).
  final stubbedModels = <String, AiConfigModel>{};

  /// Providers registered alongside the models, keyed by provider id.
  /// `profileIsLocal` batch-fetches the inference-provider list, so we stub
  /// the typed call here and let `stubModelWithProvider` populate this map.
  final stubbedProviders = <String, AiConfigInferenceProvider>{};

  setUp(() {
    repo = MockAiConfigRepository();
    stubbedModels.clear();
    stubbedProviders.clear();
    when(() => repo.getConfigById(any())).thenAnswer((_) async => null);
    when(
      () => repo.getConfigsByType(AiConfigType.model),
    ).thenAnswer((_) async => stubbedModels.values.toList());
    when(
      () => repo.getConfigsByType(AiConfigType.inferenceProvider),
    ).thenAnswer((_) async => stubbedProviders.values.toList());
  });

  /// Stubs the repo so the profile slot string `providerModelId` resolves to
  /// a model row pointing at a provider of [providerType]. Mirrors how
  /// production seeders set up the (model, provider) pair.
  void stubModelWithProvider({
    required String providerModelId,
    required InferenceProviderType providerType,
    String? providerId,
  }) {
    final pid = providerId ?? 'provider-for-$providerModelId';
    final modelRowId = 'model-row-for-$providerModelId';
    final model = _model(
      id: modelRowId,
      providerModelId: providerModelId,
      inferenceProviderId: pid,
    );
    stubbedModels[providerModelId] = model;
    stubbedProviders[pid] = _provider(id: pid, type: providerType);
    when(
      () => repo.getConfigById(pid),
    ).thenAnswer((_) async => stubbedProviders[pid]);
  }

  group('profileIsLocal — happy path (all populated slots local)', () {
    test('thinking slot only, local provider → true', () async {
      stubModelWithProvider(
        providerModelId: 'thinking-model',
        providerType: InferenceProviderType.ollama,
      );

      expect(await profileIsLocal(_profile(), repo), isTrue);
    });

    test('every slot populated with mixed local providers → true', () async {
      stubModelWithProvider(
        providerModelId: 'thinking-model',
        providerType: InferenceProviderType.ollama,
      );
      stubModelWithProvider(
        providerModelId: 'thinking-pro',
        providerType: InferenceProviderType.ollama,
      );
      stubModelWithProvider(
        providerModelId: 'vision',
        providerType: InferenceProviderType.mlxAudio,
      );
      stubModelWithProvider(
        providerModelId: 'asr',
        providerType: InferenceProviderType.mlxAudio,
      );
      stubModelWithProvider(
        providerModelId: 'image-gen',
        providerType: InferenceProviderType.whisper,
      );

      final profile = _profile(
        thinkingHighEndModelId: 'thinking-pro',
        imageRecognitionModelId: 'vision',
        transcriptionModelId: 'asr',
        imageGenerationModelId: 'image-gen',
      );

      expect(await profileIsLocal(profile, repo), isTrue);
    });

    test('voxtral and whisper count as local', () async {
      stubModelWithProvider(
        providerModelId: 'thinking-model',
        providerType: InferenceProviderType.voxtral,
      );
      stubModelWithProvider(
        providerModelId: 'asr',
        providerType: InferenceProviderType.whisper,
      );

      final profile = _profile(transcriptionModelId: 'asr');
      expect(await profileIsLocal(profile, repo), isTrue);
    });
  });

  group('profileIsLocal — cloud provider in any slot → false', () {
    test('thinking slot cloud → false', () async {
      stubModelWithProvider(
        providerModelId: 'thinking-model',
        providerType: InferenceProviderType.gemini,
      );

      expect(await profileIsLocal(_profile(), repo), isFalse);
    });

    test(
      'transcription slot cloud → false even if thinking is local',
      () async {
        stubModelWithProvider(
          providerModelId: 'thinking-model',
          providerType: InferenceProviderType.ollama,
        );
        stubModelWithProvider(
          providerModelId: 'asr',
          providerType: InferenceProviderType.openAi,
        );

        final profile = _profile(transcriptionModelId: 'asr');
        expect(await profileIsLocal(profile, repo), isFalse);
      },
    );

    test('every cloud provider in turn flips the result false', () async {
      const cloudTypes = [
        InferenceProviderType.gemini,
        InferenceProviderType.openAi,
        InferenceProviderType.anthropic,
        InferenceProviderType.mistral,
        InferenceProviderType.openRouter,
        InferenceProviderType.nebiusAiStudio,
        InferenceProviderType.genericOpenAi,
        InferenceProviderType.alibaba,
      ];

      for (final type in cloudTypes) {
        final scopedRepo = MockAiConfigRepository();
        when(
          () => scopedRepo.getConfigById(any()),
        ).thenAnswer((_) async => null);
        when(() => scopedRepo.getConfigsByType(AiConfigType.model)).thenAnswer(
          (_) async => [
            _model(
              id: 'model-row',
              providerModelId: 'thinking-model',
              inferenceProviderId: 'p',
            ),
          ],
        );
        when(
          () => scopedRepo.getConfigsByType(AiConfigType.inferenceProvider),
        ).thenAnswer((_) async => [_provider(id: 'p', type: type)]);

        expect(
          await profileIsLocal(_profile(), scopedRepo),
          isFalse,
          reason: 'cloud type $type must flip isLocal to false',
        );
      }
    });
  });

  group('profileIsLocal — fail closed on unresolved references', () {
    test(
      'referenced model id with no model config → false '
      '(prevents masking deleted cloud configuration)',
      () async {
        // Repo returns null for the thinking model — typical of a profile that
        // referenced a model whose config was later deleted.
        expect(await profileIsLocal(_profile(), repo), isFalse);
      },
    );

    test(
      'model resolves but provider config is missing → false',
      () async {
        when(() => repo.getConfigsByType(AiConfigType.model)).thenAnswer(
          (_) async => [
            _model(
              id: 'model-row',
              providerModelId: 'thinking-model',
              inferenceProviderId: 'missing-provider',
            ),
          ],
        );
        // missing-provider intentionally absent from the typed
        // inference-provider snapshot — providersById lookup returns null,
        // and the guard trips.

        expect(await profileIsLocal(_profile(), repo), isFalse);
      },
    );

    test(
      'optional slot references unresolved model → false (does NOT count as '
      'vacuously local — this is the bug the reviewer flagged)',
      () async {
        stubModelWithProvider(
          providerModelId: 'thinking-model',
          providerType: InferenceProviderType.ollama,
        );
        // transcriptionModelId is set but its model config is missing.

        final profile = _profile(transcriptionModelId: 'gone');
        expect(await profileIsLocal(profile, repo), isFalse);
      },
    );

    test(
      'unset optional slot does not require any lookup (vacuously local)',
      () async {
        stubModelWithProvider(
          providerModelId: 'thinking-model',
          providerType: InferenceProviderType.ollama,
        );

        // transcriptionModelId is null — never referenced, never looked up.
        final profile = _profile();
        expect(await profileIsLocal(profile, repo), isTrue);

        verifyNever(() => repo.getConfigById('transcription-model'));
      },
    );
  });

  group('profileIsLocal — wrong config type at id', () {
    test(
      'no AiConfigModel row matches the slot value → false '
      '(fail-closed when the profile references a model that was deleted '
      'or never seeded)',
      () async {
        // getConfigsByType returns only non-model rows for the slot value,
        // so the providerModelId lookup yields null and the guard trips.
        when(() => repo.getConfigsByType(AiConfigType.model)).thenAnswer(
          (_) async => const <AiConfig>[],
        );

        expect(await profileIsLocal(_profile(), repo), isFalse);
      },
    );

    test(
      'provider id resolves to a non-provider config (wrong type) → false',
      () async {
        when(() => repo.getConfigsByType(AiConfigType.model)).thenAnswer(
          (_) async => [
            _model(
              id: 'model-row',
              providerModelId: 'thinking-model',
              inferenceProviderId: 'wrong-shape',
            ),
          ],
        );
        // The typed provider snapshot only carries non-provider rows for
        // 'wrong-shape', so the `.whereType<AiConfigInferenceProvider>()`
        // filter drops it and providersById['wrong-shape'] is null.
        when(
          () => repo.getConfigsByType(AiConfigType.inferenceProvider),
        ).thenAnswer(
          (_) async => [
            _model(
              id: 'wrong-shape',
              providerModelId: 'wrong-shape',
              inferenceProviderId: 'irrelevant',
            ),
          ],
        );

        expect(await profileIsLocal(_profile(), repo), isFalse);
      },
    );
  });
}
