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
}) {
  return AiConfig.model(
        id: id,
        name: id,
        providerModelId: id,
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

  setUp(() {
    repo = MockAiConfigRepository();
    when(() => repo.getConfigById(any())).thenAnswer((_) async => null);
  });

  /// Stubs the repo so `modelId` resolves to a model that points at a provider
  /// of type [providerType].
  void stubModelWithProvider({
    required String modelId,
    required InferenceProviderType providerType,
    String? providerId,
  }) {
    final pid = providerId ?? 'provider-for-$modelId';
    when(
      () => repo.getConfigById(modelId),
    ).thenAnswer(
      (_) async => _model(id: modelId, inferenceProviderId: pid),
    );
    when(
      () => repo.getConfigById(pid),
    ).thenAnswer((_) async => _provider(id: pid, type: providerType));
  }

  group('profileIsLocal — happy path (all populated slots local)', () {
    test('thinking slot only, local provider → true', () async {
      stubModelWithProvider(
        modelId: 'thinking-model',
        providerType: InferenceProviderType.ollama,
      );

      expect(await profileIsLocal(_profile(), repo), isTrue);
    });

    test('every slot populated with mixed local providers → true', () async {
      stubModelWithProvider(
        modelId: 'thinking-model',
        providerType: InferenceProviderType.ollama,
      );
      stubModelWithProvider(
        modelId: 'thinking-pro',
        providerType: InferenceProviderType.ollama,
      );
      stubModelWithProvider(
        modelId: 'vision',
        providerType: InferenceProviderType.mlxAudio,
      );
      stubModelWithProvider(
        modelId: 'asr',
        providerType: InferenceProviderType.mlxAudio,
      );
      stubModelWithProvider(
        modelId: 'image-gen',
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
        modelId: 'thinking-model',
        providerType: InferenceProviderType.voxtral,
      );
      stubModelWithProvider(
        modelId: 'asr',
        providerType: InferenceProviderType.whisper,
      );

      final profile = _profile(transcriptionModelId: 'asr');
      expect(await profileIsLocal(profile, repo), isTrue);
    });
  });

  group('profileIsLocal — cloud provider in any slot → false', () {
    test('thinking slot cloud → false', () async {
      stubModelWithProvider(
        modelId: 'thinking-model',
        providerType: InferenceProviderType.gemini,
      );

      expect(await profileIsLocal(_profile(), repo), isFalse);
    });

    test(
      'transcription slot cloud → false even if thinking is local',
      () async {
        stubModelWithProvider(
          modelId: 'thinking-model',
          providerType: InferenceProviderType.ollama,
        );
        stubModelWithProvider(
          modelId: 'asr',
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
        when(() => scopedRepo.getConfigById('thinking-model')).thenAnswer(
          (_) async => _model(id: 'thinking-model', inferenceProviderId: 'p'),
        );
        when(
          () => scopedRepo.getConfigById('p'),
        ).thenAnswer((_) async => _provider(id: 'p', type: type));

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
        when(() => repo.getConfigById('thinking-model')).thenAnswer(
          (_) async => _model(
            id: 'thinking-model',
            inferenceProviderId: 'missing-provider',
          ),
        );
        // missing-provider intentionally not stubbed (returns null).

        expect(await profileIsLocal(_profile(), repo), isFalse);
      },
    );

    test(
      'optional slot references unresolved model → false (does NOT count as '
      'vacuously local — this is the bug the reviewer flagged)',
      () async {
        stubModelWithProvider(
          modelId: 'thinking-model',
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
          modelId: 'thinking-model',
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
      'model id resolves to a profile config (wrong type) → false',
      () async {
        when(() => repo.getConfigById('thinking-model')).thenAnswer(
          (_) async => _profile(),
        );

        expect(await profileIsLocal(_profile(), repo), isFalse);
      },
    );

    test(
      'provider id resolves to a model config (wrong type) → false',
      () async {
        when(() => repo.getConfigById('thinking-model')).thenAnswer(
          (_) async => _model(
            id: 'thinking-model',
            inferenceProviderId: 'wrong-shape',
          ),
        );
        when(() => repo.getConfigById('wrong-shape')).thenAnswer(
          (_) async => _model(
            id: 'wrong-shape',
            inferenceProviderId: 'irrelevant',
          ),
        );

        expect(await profileIsLocal(_profile(), repo), isFalse);
      },
    );
  });
}
