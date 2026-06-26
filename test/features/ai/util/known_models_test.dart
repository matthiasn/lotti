import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/util/known_models.dart';

enum _GeneratedKnownModelIdPart {
  lower,
  upper,
  slash,
  colon,
  dash,
  dot,
  mixed,
}

enum _GeneratedKnownModelModalities {
  empty,
  text,
  audio,
  image,
  textImage,
  audioText,
  duplicateImage,
}

enum _GeneratedKnownModelTokens { absent, small, large }

enum _GeneratedMlxQwenAsrIdShape {
  canonicalSmall,
  canonical17B4Bit,
  canonical17B8Bit,
  uppercasePrefix,
  missingMlxPrefix,
  nonQwenMlx,
  qwenTts,
}

String _generatedKnownModelIdPartText(_GeneratedKnownModelIdPart part) {
  return switch (part) {
    _GeneratedKnownModelIdPart.lower => 'alpha',
    _GeneratedKnownModelIdPart.upper => 'BETA',
    _GeneratedKnownModelIdPart.slash => 'model/test',
    _GeneratedKnownModelIdPart.colon => 'name:123',
    _GeneratedKnownModelIdPart.dash => 'with-dash',
    _GeneratedKnownModelIdPart.dot => 'with.dot',
    _GeneratedKnownModelIdPart.mixed => 'MiXeD-Case.42',
  };
}

List<Modality> _generatedKnownModelModalities(
  _GeneratedKnownModelModalities modalities,
) {
  return switch (modalities) {
    _GeneratedKnownModelModalities.empty => const [],
    _GeneratedKnownModelModalities.text => const [Modality.text],
    _GeneratedKnownModelModalities.audio => const [Modality.audio],
    _GeneratedKnownModelModalities.image => const [Modality.image],
    _GeneratedKnownModelModalities.textImage => const [
      Modality.text,
      Modality.image,
    ],
    _GeneratedKnownModelModalities.audioText => const [
      Modality.audio,
      Modality.text,
    ],
    _GeneratedKnownModelModalities.duplicateImage => const [
      Modality.image,
      Modality.image,
    ],
  };
}

int? _generatedKnownModelMaxTokens(_GeneratedKnownModelTokens tokens) {
  return switch (tokens) {
    _GeneratedKnownModelTokens.absent => null,
    _GeneratedKnownModelTokens.small => 128,
    _GeneratedKnownModelTokens.large => 8192,
  };
}

String _generatedMlxQwenAsrId(_GeneratedMlxQwenAsrIdShape shape) {
  return switch (shape) {
    _GeneratedMlxQwenAsrIdShape.canonicalSmall => mlxAudioQwenAsrModelId,
    _GeneratedMlxQwenAsrIdShape.canonical17B4Bit =>
      mlxAudioQwenAsr17B4BitModelId,
    _GeneratedMlxQwenAsrIdShape.canonical17B8Bit =>
      mlxAudioQwenAsr17B8BitModelId,
    _GeneratedMlxQwenAsrIdShape.uppercasePrefix =>
      'MLX-COMMUNITY/QWEN3-ASR-1.7B-8BIT',
    _GeneratedMlxQwenAsrIdShape.missingMlxPrefix => 'Qwen/Qwen3-ASR-1.7B',
    _GeneratedMlxQwenAsrIdShape.nonQwenMlx => mlxAudioParakeetModelId,
    _GeneratedMlxQwenAsrIdShape.qwenTts => mlxAudioDefaultTtsModelId,
  };
}

class _GeneratedKnownModelIdScenario {
  const _GeneratedKnownModelIdScenario({
    required this.providerPart,
    required this.modelPart,
  });

  final _GeneratedKnownModelIdPart providerPart;
  final _GeneratedKnownModelIdPart modelPart;

  String get providerId => _generatedKnownModelIdPartText(providerPart);

  String get providerModelId => _generatedKnownModelIdPartText(modelPart);

  String get expectedId => '${providerId}_$providerModelId'
      .replaceAll(RegExp(r'[/:\-.]'), '_')
      .toLowerCase();

  @override
  String toString() {
    return '_GeneratedKnownModelIdScenario('
        'providerPart: $providerPart, modelPart: $modelPart)';
  }
}

class _GeneratedKnownModelConversionScenario {
  const _GeneratedKnownModelConversionScenario({
    required this.providerPart,
    required this.modelPart,
    required this.inputModalitiesKind,
    required this.outputModalitiesKind,
    required this.isReasoningModel,
    required this.supportsFunctionCalling,
    required this.maxTokensKind,
  });

  final _GeneratedKnownModelIdPart providerPart;
  final _GeneratedKnownModelIdPart modelPart;
  final _GeneratedKnownModelModalities inputModalitiesKind;
  final _GeneratedKnownModelModalities outputModalitiesKind;
  final bool isReasoningModel;
  final bool supportsFunctionCalling;
  final _GeneratedKnownModelTokens maxTokensKind;

  String get modelId => _generatedKnownModelIdPartText(modelPart);

  String get providerId => _generatedKnownModelIdPartText(providerPart);

  List<Modality> get inputModalities =>
      _generatedKnownModelModalities(inputModalitiesKind);

  List<Modality> get outputModalities =>
      _generatedKnownModelModalities(outputModalitiesKind);

  int? get maxCompletionTokens => _generatedKnownModelMaxTokens(maxTokensKind);

  KnownModel get knownModel => KnownModel(
    providerModelId: modelId,
    name: 'Generated $modelId',
    inputModalities: inputModalities,
    outputModalities: outputModalities,
    isReasoningModel: isReasoningModel,
    supportsFunctionCalling: supportsFunctionCalling,
    description: 'Generated description for $modelId',
    maxCompletionTokens: maxCompletionTokens,
  );

  @override
  String toString() {
    return '_GeneratedKnownModelConversionScenario('
        'providerPart: $providerPart, modelPart: $modelPart, '
        'inputModalitiesKind: $inputModalitiesKind, '
        'outputModalitiesKind: $outputModalitiesKind, '
        'isReasoningModel: $isReasoningModel, '
        'supportsFunctionCalling: $supportsFunctionCalling, '
        'maxTokensKind: $maxTokensKind)';
  }
}

extension _AnyGeneratedKnownModelScenario on glados.Any {
  glados.Generator<_GeneratedKnownModelIdPart> get knownModelIdPart =>
      glados.AnyUtils(this).choose(_GeneratedKnownModelIdPart.values);

  glados.Generator<_GeneratedKnownModelModalities> get knownModelModalities =>
      glados.AnyUtils(this).choose(_GeneratedKnownModelModalities.values);

  glados.Generator<_GeneratedKnownModelTokens> get knownModelTokens =>
      glados.AnyUtils(this).choose(_GeneratedKnownModelTokens.values);

  glados.Generator<List<Modality>> get modalitySubset =>
      glados.CombinableAny(this).combine3(
        glados.any.bool,
        glados.any.bool,
        glados.any.bool,
        (bool text, bool audio, bool image) => [
          if (text) Modality.text,
          if (audio) Modality.audio,
          if (image) Modality.image,
        ],
      );

  glados.Generator<_GeneratedMlxQwenAsrIdShape> get mlxQwenAsrIdShape =>
      glados.AnyUtils(this).choose(_GeneratedMlxQwenAsrIdShape.values);

  glados.Generator<_GeneratedKnownModelIdScenario> get knownModelIdScenario =>
      glados.CombinableAny(this).combine2(
        knownModelIdPart,
        knownModelIdPart,
        (
          _GeneratedKnownModelIdPart providerPart,
          _GeneratedKnownModelIdPart modelPart,
        ) => _GeneratedKnownModelIdScenario(
          providerPart: providerPart,
          modelPart: modelPart,
        ),
      );

  glados.Generator<_GeneratedKnownModelConversionScenario>
  get knownModelConversionScenario => glados.CombinableAny(this).combine7(
    knownModelIdPart,
    knownModelIdPart,
    knownModelModalities,
    knownModelModalities,
    glados.any.bool,
    glados.any.bool,
    knownModelTokens,
    (
      _GeneratedKnownModelIdPart providerPart,
      _GeneratedKnownModelIdPart modelPart,
      _GeneratedKnownModelModalities inputModalitiesKind,
      _GeneratedKnownModelModalities outputModalitiesKind,
      bool isReasoningModel,
      bool supportsFunctionCalling,
      _GeneratedKnownModelTokens maxTokensKind,
    ) => _GeneratedKnownModelConversionScenario(
      providerPart: providerPart,
      modelPart: modelPart,
      inputModalitiesKind: inputModalitiesKind,
      outputModalitiesKind: outputModalitiesKind,
      isReasoningModel: isReasoningModel,
      supportsFunctionCalling: supportsFunctionCalling,
      maxTokensKind: maxTokensKind,
    ),
  );
}

void main() {
  group('KnownModel', () {
    group('maxCompletionTokens', () {
      // Anthropic models pin maxCompletionTokens to 2000; every other provider
      // leaves it null. Split per-provider so a regression names the offender.
      test('Anthropic models pin maxCompletionTokens to 2000', () {
        for (final model in anthropicModels) {
          expect(
            model.maxCompletionTokens,
            equals(2000),
            reason:
                'Anthropic model ${model.name} should have maxCompletionTokens set to 2000',
          );
        }
      });

      final providersWithoutMaxTokens = <String, List<KnownModel>>{
        'Gemini': geminiModels,
        'Nebius': nebiusModels,
        'oMLX': omlxModels,
        'Ollama': ollamaModels,
        'OpenAI': openaiModels,
        'OpenRouter': openRouterModels,
        'Whisper': whisperModels,
        'Voxtral': voxtralModels,
        'Alibaba': alibabaModels,
        'Melious': meliousModels,
      };

      for (final entry in providersWithoutMaxTokens.entries) {
        test('${entry.key} models leave maxCompletionTokens null', () {
          for (final model in entry.value) {
            expect(
              model.maxCompletionTokens,
              isNull,
              reason:
                  '${entry.key} model ${model.name} should not have maxCompletionTokens defined',
            );
          }
        });
      }

      test(
        'should transfer maxCompletionTokens to AiConfigModel when converting',
        () {
          const testId = 'test-id';
          const testProviderId = 'test-provider-id';

          // Test model with maxCompletionTokens
          const modelWithTokens = KnownModel(
            providerModelId: 'test-model-with-tokens',
            name: 'Test Model With Tokens',
            inputModalities: [Modality.text],
            outputModalities: [Modality.text],
            isReasoningModel: false,
            description: 'Test model with max completion tokens',
            maxCompletionTokens: 5000,
          );

          final aiConfigWithTokens = modelWithTokens.toAiConfigModel(
            id: testId,
            inferenceProviderId: testProviderId,
          );

          expect(aiConfigWithTokens.maxCompletionTokens, equals(5000));

          // Test model without maxCompletionTokens
          const modelWithoutTokens = KnownModel(
            providerModelId: 'test-model-without-tokens',
            name: 'Test Model Without Tokens',
            inputModalities: [Modality.text],
            outputModalities: [Modality.text],
            isReasoningModel: false,
            description: 'Test model without max completion tokens',
          );

          final aiConfigWithoutTokens = modelWithoutTokens.toAiConfigModel(
            id: testId,
            inferenceProviderId: testProviderId,
          );

          expect(aiConfigWithoutTokens.maxCompletionTokens, isNull);
        },
      );

      test(
        'should properly transfer all fields including maxCompletionTokens in toAiConfigModel',
        () {
          const testId = 'test-id';
          const testProviderId = 'test-provider-id';

          // Take a real Anthropic model as example
          final anthropicModel = anthropicModels.first;
          final aiConfig = anthropicModel.toAiConfigModel(
            id: testId,
            inferenceProviderId: testProviderId,
          );

          // Verify all fields are transferred correctly
          expect(aiConfig.id, equals(testId));
          expect(aiConfig.name, equals(anthropicModel.name));
          expect(
            aiConfig.providerModelId,
            equals(anthropicModel.providerModelId),
          );
          expect(aiConfig.inferenceProviderId, equals(testProviderId));
          expect(
            aiConfig.inputModalities,
            equals(anthropicModel.inputModalities),
          );
          expect(
            aiConfig.outputModalities,
            equals(anthropicModel.outputModalities),
          );
          expect(
            aiConfig.isReasoningModel,
            equals(anthropicModel.isReasoningModel),
          );
          expect(aiConfig.description, equals(anthropicModel.description));
          expect(
            aiConfig.maxCompletionTokens,
            equals(anthropicModel.maxCompletionTokens),
          );
          expect(aiConfig.createdAt, isA<DateTime>());
        },
      );
    });

    group('generateModelId', () {
      test('should generate valid IDs', () {
        expect(
          generateModelId('provider1', 'model/test-name:123'),
          equals('provider1_model_test_name_123'),
        );

        expect(
          generateModelId('Provider-2', 'model.test.name'),
          equals('provider_2_model_test_name'),
        );
      });

      glados.Glados(
        glados.any.knownModelIdScenario,
        glados.ExploreConfig(numRuns: 160),
      ).test('normalizes generated provider and model IDs', (scenario) {
        final id = generateModelId(
          scenario.providerId,
          scenario.providerModelId,
        );

        expect(id, scenario.expectedId, reason: '$scenario');
        expect(id, isNot(contains(RegExp(r'[/:\-.]'))));
        expect(id, id.toLowerCase());
      }, tags: 'glados');
    });

    group('toAiConfigModel', () {
      glados.Glados(
        glados.any.knownModelConversionScenario,
        glados.ExploreConfig(numRuns: 160),
      ).test('preserves generated known model fields', (scenario) {
        final model = scenario.knownModel;
        final aiConfig = model.toAiConfigModel(
          id: 'generated-config-id',
          inferenceProviderId: scenario.providerId,
        );

        expect(aiConfig.id, 'generated-config-id');
        expect(aiConfig.name, model.name);
        expect(aiConfig.providerModelId, model.providerModelId);
        expect(aiConfig.inferenceProviderId, scenario.providerId);
        expect(aiConfig.inputModalities, model.inputModalities);
        expect(aiConfig.outputModalities, model.outputModalities);
        expect(aiConfig.isReasoningModel, model.isReasoningModel);
        expect(aiConfig.supportsFunctionCalling, model.supportsFunctionCalling);
        expect(aiConfig.description, model.description);
        expect(aiConfig.maxCompletionTokens, model.maxCompletionTokens);
      }, tags: 'glados');
    });

    group('Image Generation Model (Nano Banana Pro)', () {
      test(
        'geminiModels contains a fully-configured image generation model',
        () {
          final imageGenModels = geminiModels.where(
            (m) => m.outputModalities.contains(Modality.image),
          );
          expect(
            imageGenModels,
            isNotEmpty,
            reason: 'Should have at least one image generation model',
          );

          final model = imageGenModels.first;
          expect(model.providerModelId, contains('image'));
          expect(model.inputModalities, contains(Modality.text));
          expect(model.outputModalities, contains(Modality.image));
          expect(model.isReasoningModel, isFalse);
          expect(model.name, isNotEmpty);
          expect(model.description, isNotEmpty);
        },
      );
    });

    group('OpenAI FTUE functions', () {
      test('findOpenAiKnownModel returns model for valid ID', () {
        final model = findOpenAiKnownModel('gpt-5.2');
        expect(model, isNotNull);
        expect(model!.providerModelId, equals('gpt-5.2'));
        expect(model.isReasoningModel, isTrue);
      });

      test('findOpenAiKnownModel returns null for invalid ID', () {
        final model = findOpenAiKnownModel('non-existent-model-id');
        expect(model, isNull);
      });

      test('getOpenAiFtueKnownModels returns all required models', () {
        final models = getOpenAiFtueKnownModels();
        expect(models, isNotNull);

        // Verify flash model (GPT-5 Nano)
        expect(models!.flash.providerModelId, equals(ftueOpenAiFlashModelId));
        expect(models.flash.name, contains('GPT-5 Nano'));

        // Verify reasoning model (GPT-5.2)
        expect(
          models.reasoning.providerModelId,
          equals(ftueOpenAiReasoningModelId),
        );
        expect(models.reasoning.isReasoningModel, isTrue);

        // Verify audio model
        expect(models.audio.providerModelId, equals(ftueOpenAiAudioModelId));
        expect(models.audio.inputModalities, contains(Modality.audio));

        // Verify image model
        expect(models.image.providerModelId, equals(ftueOpenAiImageModelId));
        expect(models.image.outputModalities, contains(Modality.image));
      });

      test('FTUE model constants are valid OpenAI model IDs', () {
        expect(findOpenAiKnownModel(ftueOpenAiReasoningModelId), isNotNull);
        expect(findOpenAiKnownModel(ftueOpenAiFlashModelId), isNotNull);
        expect(findOpenAiKnownModel(ftueOpenAiAudioModelId), isNotNull);
        expect(findOpenAiKnownModel(ftueOpenAiImageModelId), isNotNull);
      });
    });

    group('Melious known models', () {
      test('curated defaults include thinking, vision, and Whisper models', () {
        final ids = meliousModels.map((model) => model.providerModelId).toSet();

        expect(
          ids,
          containsAll({
            meliousDeepseekV4ProModelId,
            meliousGemma426bA4bModelId,
            meliousMinimaxM27ModelId,
            meliousMistralSmall4119BInstructModelId,
            meliousDeepseekV4FlashModelId,
            meliousFlux2Klein9BModelId,
            meliousWhisperLargeV3ModelId,
            meliousWhisperLargeV3TurboModelId,
          }),
        );
      });

      test('Flux default is a text-to-image model', () {
        final flux = findMeliousKnownModel(meliousFlux2Klein9BModelId);

        expect(flux, isNotNull);
        expect(flux!.inputModalities, contains(Modality.text));
        expect(flux.outputModalities, contains(Modality.image));
        expect(flux.isReasoningModel, isFalse);
        expect(flux.name, contains('Flux 2 Klein 9B'));
      });

      test('Whisper defaults are audio-to-text transcription models', () {
        final whisper = findMeliousKnownModel(meliousWhisperLargeV3ModelId);
        final turbo = findMeliousKnownModel(
          meliousWhisperLargeV3TurboModelId,
        );

        for (final model in [whisper, turbo]) {
          expect(model, isNotNull);
          expect(model!.inputModalities, contains(Modality.audio));
          expect(model.outputModalities, contains(Modality.text));
          expect(model.isReasoningModel, isFalse);
        }
      });

      test('getMeliousFtueKnownModels returns profile defaults', () {
        final models = getMeliousFtueKnownModels();

        expect(models, isNotNull);
        expect(
          models!.thinking.providerModelId,
          meliousMistralSmall4119BInstructModelId,
        );
        expect(
          models.advancedThinking.providerModelId,
          meliousDeepseekV4ProModelId,
        );
        expect(
          models.imageGeneration.providerModelId,
          meliousFlux2Klein9BModelId,
        );
        expect(
          models.whisper.providerModelId,
          meliousWhisperLargeV3ModelId,
        );
        expect(
          models.whisperTurbo.providerModelId,
          meliousWhisperLargeV3TurboModelId,
        );
      });
    });

    group('knownModelsByProvider', () {
      test('should contain all provider types', () {
        // `genericOpenAi` is intentionally absent: it represents an
        // arbitrary OpenAI-compatible endpoint where Lotti cannot
        // assume a fixed model catalog. Melious is present with a curated
        // default subset while the settings UI can still explore its live
        // catalog dynamically via /models.
        // Every concrete provider with a curated model list belongs here.
        expect(
          knownModelsByProvider.keys.toSet(),
          containsAll([
            InferenceProviderType.alibaba,
            InferenceProviderType.gemini,
            InferenceProviderType.melious,
            InferenceProviderType.nebiusAiStudio,
            InferenceProviderType.omlx,
            InferenceProviderType.ollama,
            InferenceProviderType.openAi,
            InferenceProviderType.anthropic,
            InferenceProviderType.openRouter,
            InferenceProviderType.whisper,
            InferenceProviderType.voxtral,
            InferenceProviderType.mistral,
            InferenceProviderType.mlxAudio,
          ]),
        );
      });

      test('all models should have valid configurations', () {
        for (final entry in knownModelsByProvider.entries) {
          final providerType = entry.key;
          final models = entry.value;

          for (final model in models) {
            // Verify required fields are not empty
            expect(
              model.providerModelId,
              isNotEmpty,
              reason:
                  'Model in $providerType should have non-empty providerModelId',
            );
            expect(
              model.name,
              isNotEmpty,
              reason: 'Model in $providerType should have non-empty name',
            );
            expect(
              model.description,
              isNotEmpty,
              reason:
                  'Model in $providerType should have non-empty description',
            );

            // Verify modalities are not empty
            expect(
              model.inputModalities,
              isNotEmpty,
              reason:
                  'Model ${model.name} should have at least one input modality',
            );
            expect(
              model.outputModalities,
              isNotEmpty,
              reason:
                  'Model ${model.name} should have at least one output modality',
            );

            // Verify maxCompletionTokens is positive if defined
            if (model.maxCompletionTokens != null) {
              expect(
                model.maxCompletionTokens! > 0,
                isTrue,
                reason:
                    'Model ${model.name} should have positive maxCompletionTokens if defined',
              );
            }
          }
        }
      });
    });

    group('MLX Audio Models', () {
      test('recommends Qwen3 ASR 1.7B 8-bit for first install choice', () {
        expect(
          mlxAudioRecommendedSttModelId,
          equals(mlxAudioQwenAsr17B8BitModelId),
        );
        expect(
          mlxAudioModels.first.providerModelId,
          mlxAudioQwenAsr17B8BitModelId,
        );
      });

      test('has explicit Voxtral Realtime and Qwen3 ASR 1.7B variants', () {
        final modelIds = mlxAudioModels.map((m) => m.providerModelId).toSet();

        expect(modelIds, contains(mlxAudioVoxtralRealtime4BitModelId));
        expect(modelIds, contains(mlxAudioVoxtralRealtimeFp16ModelId));
        expect(modelIds, contains(mlxAudioQwenAsr17B4BitModelId));
        expect(modelIds, contains(mlxAudioQwenAsr17B8BitModelId));
      });

      test('speech-to-text predicate excludes the TTS model', () {
        final aiModels = mlxAudioModels
            .map(
              (model) => model.toAiConfigModel(
                id: model.providerModelId,
                inferenceProviderId: 'mlx-audio-provider',
              ),
            )
            .toList();

        final sttModelIds = aiModels
            .where(isMlxAudioSpeechToTextModel)
            .map((model) => model.providerModelId)
            .toSet();

        expect(sttModelIds, contains(mlxAudioQwenAsr17B8BitModelId));
        expect(sttModelIds, contains(mlxAudioVoxtralRealtime4BitModelId));
        expect(sttModelIds, isNot(contains(mlxAudioDefaultTtsModelId)));
      });

      glados.Glados(
        glados.any.mlxQwenAsrIdShape,
        glados.ExploreConfig(numRuns: 80),
      ).test('recognizes only MLX Qwen3-ASR realtime-capable IDs', (shape) {
        final modelId = _generatedMlxQwenAsrId(shape);
        final expected = switch (shape) {
          _GeneratedMlxQwenAsrIdShape.canonicalSmall ||
          _GeneratedMlxQwenAsrIdShape.canonical17B4Bit ||
          _GeneratedMlxQwenAsrIdShape.canonical17B8Bit ||
          _GeneratedMlxQwenAsrIdShape.uppercasePrefix => true,
          _GeneratedMlxQwenAsrIdShape.missingMlxPrefix ||
          _GeneratedMlxQwenAsrIdShape.nonQwenMlx ||
          _GeneratedMlxQwenAsrIdShape.qwenTts => false,
        };

        expect(isMlxAudioQwenAsrModelId(modelId), expected);
      }, tags: 'glados');
    });

    group('oMLX Models', () {
      test('recommends the plain Qwen 3.6 35B-A3B 4-bit model', () {
        expect(
          omlxRecommendedMultimodalModelId,
          equals(omlxQwen36A35bA3b4BitModelId),
        );
        expect(
          omlxModels.first.providerModelId,
          omlxQwen36A35bA3b4BitModelId,
        );
      });

      test(
        'catalogs bundled local oMLX reasoning and transcription variants',
        () {
          final modelIds = omlxModels.map((m) => m.providerModelId).toSet();

          expect(modelIds, contains(omlxQwen36A35bA3b4BitModelId));
          expect(modelIds, contains(omlxQwen36A35bA3bUdMlx4BitModelId));
          expect(
            modelIds,
            contains(omlxQwen36A35bA3bTurboQuantMlx4BitModelId),
          );
          expect(modelIds, contains(omlxQwen36A35bA3bMlx8BitModelId));
          expect(modelIds, contains(omlxGemma426BA4BItQatMlx4BitModelId));
          expect(modelIds, contains(omlxWhisperLargeV3ModelId));
          expect(modelIds, contains(omlxWhisperLargeV3MlxModelId));
          expect(modelIds, contains(omlxWhisperLargeV3TurboModelId));

          final reasoningModels = omlxModels.where(
            (m) => !m.inputModalities.contains(Modality.audio),
          );
          for (final model in reasoningModels) {
            expect(model.inputModalities, contains(Modality.text));
            expect(model.inputModalities, contains(Modality.image));
            expect(model.outputModalities, equals([Modality.text]));
            expect(model.isReasoningModel, isTrue);
            expect(model.supportsFunctionCalling, isTrue);
          }

          final transcriptionModels = omlxModels
              .where((m) => m.inputModalities.contains(Modality.audio))
              .toList(growable: false);
          expect(transcriptionModels, hasLength(3));
          expect(
            transcriptionModels.map((m) => m.providerModelId),
            containsAll([
              omlxWhisperLargeV3ModelId,
              omlxWhisperLargeV3MlxModelId,
              omlxWhisperLargeV3TurboModelId,
            ]),
          );
          for (final model in transcriptionModels) {
            expect(model.outputModalities, equals([Modality.text]));
            expect(model.isReasoningModel, isFalse);
            expect(model.supportsFunctionCalling, isFalse);
          }
        },
      );

      test('Gemma 4 26B A4B QAT oMLX is a multimodal reasoning model', () {
        final model = omlxModels.firstWhere(
          (m) => m.providerModelId == omlxGemma426BA4BItQatMlx4BitModelId,
        );

        expect(model.name, contains('Gemma 4'));
        expect(model.inputModalities, contains(Modality.text));
        expect(model.inputModalities, contains(Modality.image));
        expect(model.outputModalities, equals([Modality.text]));
        expect(model.isReasoningModel, isTrue);
        expect(model.supportsFunctionCalling, isTrue);
      });
    });

    glados.Glados2(
      glados.any.modalitySubset,
      glados.any.modalitySubset,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'isMlxAudioSpeechToTextModel holds exactly for audio-in/text-out '
      'modality combinations',
      (inputs, outputs) {
        final model =
            AiConfig.model(
                  id: 'generated-model',
                  name: 'Generated model',
                  providerModelId: 'generated-model',
                  inferenceProviderId: 'mlx-audio-provider',
                  createdAt: DateTime(2024, 3, 15),
                  inputModalities: inputs,
                  outputModalities: outputs,
                  isReasoningModel: false,
                )
                as AiConfigModel;

        expect(
          isMlxAudioSpeechToTextModel(model),
          inputs.contains(Modality.audio) && outputs.contains(Modality.text),
          reason: 'inputs=$inputs outputs=$outputs',
        );
      },
      tags: 'glados',
    );

    group('Ollama Models', () {
      test('Qwen 3.5 9B should be a multimodal reasoning model', () {
        final model = ollamaModels.firstWhere(
          (m) => m.providerModelId == 'qwen3.5:9b',
        );
        expect(model.isReasoningModel, isTrue);
        expect(model.supportsFunctionCalling, isTrue);
        expect(model.inputModalities, contains(Modality.text));
        expect(model.inputModalities, contains(Modality.image));
        expect(model.outputModalities, contains(Modality.text));
      });

      test('Qwen 3.5 27B should be a multimodal reasoning model', () {
        final model = ollamaModels.firstWhere(
          (m) => m.providerModelId == 'qwen3.5:27b',
        );
        expect(model.isReasoningModel, isTrue);
        expect(model.supportsFunctionCalling, isTrue);
        expect(model.inputModalities, contains(Modality.text));
        expect(model.inputModalities, contains(Modality.image));
      });

      test(
        'Qwen 3.6 35B-A3B Coding (NVFP4) is a text-only reasoning model',
        () {
          final model = ollamaModels.firstWhere(
            (m) => m.providerModelId == 'qwen3.6:35b-a3b-coding-nvfp4',
          );
          expect(model.isReasoningModel, isTrue);
          expect(model.supportsFunctionCalling, isTrue);
          expect(model.inputModalities, equals([Modality.text]));
          expect(model.outputModalities, equals([Modality.text]));
        },
      );

      test('Gemma 4 E4B should be a multimodal reasoning model', () {
        final model = ollamaModels.firstWhere(
          (m) => m.providerModelId == 'gemma4:e4b',
        );
        expect(model.isReasoningModel, isTrue);
        expect(model.supportsFunctionCalling, isTrue);
        expect(model.inputModalities, contains(Modality.text));
        expect(model.inputModalities, contains(Modality.image));
        expect(model.outputModalities, contains(Modality.text));
      });

      test('Gemma 4 26B MoE should be a multimodal reasoning model', () {
        final model = ollamaModels.firstWhere(
          (m) => m.providerModelId == 'gemma4:26b',
        );
        expect(model.isReasoningModel, isTrue);
        expect(model.supportsFunctionCalling, isTrue);
        expect(model.inputModalities, contains(Modality.text));
        expect(model.inputModalities, contains(Modality.image));
        expect(model.name, contains('MoE'));
      });

      test('Gemma 4 31B should be a multimodal reasoning model', () {
        final model = ollamaModels.firstWhere(
          (m) => m.providerModelId == 'gemma4:31b',
        );
        expect(model.isReasoningModel, isTrue);
        expect(model.supportsFunctionCalling, isTrue);
        expect(model.inputModalities, contains(Modality.text));
        expect(model.inputModalities, contains(Modality.image));
      });

      test('should not contain removed models', () {
        final modelIds = ollamaModels.map((m) => m.providerModelId).toSet();
        expect(modelIds, isNot(contains('qwen3:8b')));
        expect(modelIds, isNot(contains('deepseek-r1:8b')));
        expect(modelIds, isNot(contains('gpt-oss:20b')));
        expect(modelIds, isNot(contains('gpt-oss:120b')));
        expect(modelIds, isNot(contains('gemma3:12b-it-qat')));
        expect(modelIds, isNot(contains('gemma3:4b')));
        expect(modelIds, isNot(contains('gemma3:12b')));
      });

      test('should still contain embedding model', () {
        final modelIds = ollamaModels.map((m) => m.providerModelId).toSet();
        expect(modelIds, contains('mxbai-embed-large'));
      });

      test('embedding model should not be a reasoning model', () {
        final model = ollamaModels.firstWhere(
          (m) => m.providerModelId == 'mxbai-embed-large',
        );
        expect(model.isReasoningModel, isFalse);
        expect(model.supportsFunctionCalling, isFalse);
      });
    });

    group('Voxtral Models', () {
      test('should have both Mini and Small models', () {
        expect(voxtralModels.length, equals(2));

        final miniModel = voxtralModels.firstWhere(
          (m) => m.providerModelId.contains('Mini'),
        );
        final smallModel = voxtralModels.firstWhere(
          (m) => m.providerModelId.contains('Small'),
        );

        expect(miniModel.name, contains('Mini'));
        expect(smallModel.name, contains('Small'));
      });

      test('Voxtral models should have audio input and text output', () {
        for (final model in voxtralModels) {
          expect(
            model.inputModalities,
            contains(Modality.audio),
            reason: '${model.name} should accept audio input',
          );
          expect(
            model.outputModalities,
            contains(Modality.text),
            reason: '${model.name} should output text',
          );
          expect(
            model.isReasoningModel,
            isFalse,
            reason: '${model.name} should not be a reasoning model',
          );
        }
      });

      test('Voxtral Mini should have correct model ID', () {
        final miniModel = voxtralModels.firstWhere(
          (m) => m.providerModelId.contains('Mini'),
        );
        expect(
          miniModel.providerModelId,
          equals('mistralai/Voxtral-Mini-3B-2507'),
        );
      });

      test('Voxtral Small 24B should have correct model ID', () {
        final smallModel = voxtralModels.firstWhere(
          (m) => m.providerModelId.contains('Small'),
        );
        expect(
          smallModel.providerModelId,
          equals('mistralai/Voxtral-Small-24B-2507'),
        );
      });

      test('Voxtral models should have informative descriptions', () {
        for (final model in voxtralModels) {
          expect(model.description, isNotEmpty);
          expect(
            model.description,
            contains('30 min'),
            reason: '${model.name} description should mention audio duration',
          );
          expect(
            model.description,
            contains('languages'),
            reason: '${model.name} description should mention language support',
          );
        }
      });
    });

    group('Mistral Models', () {
      test('should have Fast, Reasoning, and Audio models', () {
        expect(mistralModels.length, greaterThanOrEqualTo(3));

        final flashModel = mistralModels.firstWhere(
          (m) => m.providerModelId == ftueMistralFlashModelId,
        );
        final reasoningModel = mistralModels.firstWhere(
          (m) => m.providerModelId == ftueMistralReasoningModelId,
        );
        final audioModel = mistralModels.firstWhere(
          (m) => m.providerModelId == ftueMistralAudioModelId,
        );

        expect(flashModel.name, contains('Mistral Small'));
        expect(reasoningModel.name, contains('Magistral'));
        expect(audioModel.name, contains('Voxtral'));
      });

      test('Mistral Small should have vision capabilities', () {
        final flashModel = mistralModels.firstWhere(
          (m) => m.providerModelId == ftueMistralFlashModelId,
        );
        expect(
          flashModel.inputModalities,
          contains(Modality.image),
          reason: 'Mistral Small should accept image input',
        );
        expect(flashModel.isReasoningModel, isFalse);
      });

      test('Magistral Medium should be a reasoning model', () {
        final reasoningModel = mistralModels.firstWhere(
          (m) => m.providerModelId == ftueMistralReasoningModelId,
        );
        expect(
          reasoningModel.isReasoningModel,
          isTrue,
          reason: 'Magistral Medium should be a reasoning model',
        );
      });

      test('Voxtral Mini Transcribe should have audio input', () {
        final audioModel = mistralModels.firstWhere(
          (m) => m.providerModelId == ftueMistralAudioModelId,
        );
        expect(
          audioModel.inputModalities,
          contains(Modality.audio),
          reason: 'Voxtral Mini Transcribe should accept audio input',
        );
        expect(audioModel.outputModalities, contains(Modality.text));
      });

      test('all Mistral models should have valid configurations', () {
        for (final model in mistralModels) {
          expect(
            model.providerModelId,
            isNotEmpty,
            reason: 'Model ${model.name} should have non-empty providerModelId',
          );
          expect(
            model.name,
            isNotEmpty,
            reason: 'Model should have non-empty name',
          );
          expect(
            model.description,
            isNotEmpty,
            reason: 'Model ${model.name} should have non-empty description',
          );
          expect(
            model.inputModalities,
            isNotEmpty,
            reason:
                'Model ${model.name} should have at least one input modality',
          );
          expect(
            model.outputModalities,
            isNotEmpty,
            reason:
                'Model ${model.name} should have at least one output modality',
          );
        }
      });
    });

    group('Alibaba Models', () {
      test('should have text, vision, audio, and reasoning models', () {
        expect(alibabaModels.length, equals(7));

        final textModels = alibabaModels.where(
          (m) =>
              m.inputModalities.contains(Modality.text) &&
              !m.inputModalities.contains(Modality.image) &&
              !m.inputModalities.contains(Modality.audio),
        );
        final visionModels = alibabaModels.where(
          (m) => m.inputModalities.contains(Modality.image),
        );
        final audioModels = alibabaModels.where(
          (m) => m.inputModalities.contains(Modality.audio),
        );
        final reasoningModels = alibabaModels.where(
          (m) => m.isReasoningModel,
        );

        expect(textModels, isNotEmpty, reason: 'Should have text-only models');
        expect(visionModels, isNotEmpty, reason: 'Should have vision models');
        expect(audioModels, isNotEmpty, reason: 'Should have audio models');
        expect(
          reasoningModels,
          isNotEmpty,
          reason: 'Should have reasoning models',
        );
      });

      test('Qwen3 Max should be a reasoning model', () {
        final maxModel = alibabaModels.firstWhere(
          (m) => m.providerModelId == 'qwen3-max',
        );
        expect(maxModel.isReasoningModel, isTrue);
        expect(maxModel.supportsFunctionCalling, isTrue);
      });

      test('vision models should accept image input', () {
        final vlModels = alibabaModels.where(
          (m) => m.providerModelId.contains('vl'),
        );
        expect(vlModels.length, equals(2));

        for (final model in vlModels) {
          expect(
            model.inputModalities,
            contains(Modality.image),
            reason: '${model.name} should accept image input',
          );
          expect(
            model.outputModalities,
            contains(Modality.text),
            reason: '${model.name} should output text',
          );
        }
      });

      test('Qwen3 Omni Flash should accept audio input', () {
        final omniModel = alibabaModels.firstWhere(
          (m) => m.providerModelId == 'qwen3-omni-flash',
        );
        expect(omniModel.inputModalities, contains(Modality.audio));
        expect(omniModel.inputModalities, contains(Modality.text));
        expect(omniModel.outputModalities, contains(Modality.text));
        expect(omniModel.supportsFunctionCalling, isTrue);
      });

      test('all Alibaba models should have valid configurations', () {
        for (final model in alibabaModels) {
          expect(
            model.providerModelId,
            isNotEmpty,
            reason: 'Model ${model.name} should have non-empty providerModelId',
          );
          expect(
            model.name,
            isNotEmpty,
            reason: 'Model should have non-empty name',
          );
          expect(
            model.description,
            isNotEmpty,
            reason: 'Model ${model.name} should have non-empty description',
          );
          expect(
            model.inputModalities,
            isNotEmpty,
            reason:
                'Model ${model.name} should have at least one input modality',
          );
          expect(
            model.outputModalities,
            isNotEmpty,
            reason:
                'Model ${model.name} should have at least one output modality',
          );
        }
      });
    });

    group('Alibaba FTUE functions', () {
      test('findAlibabaKnownModel returns model for valid ID', () {
        final model = findAlibabaKnownModel(ftueAlibabaReasoningModelId);
        expect(model, isNotNull);
        expect(model!.providerModelId, equals(ftueAlibabaReasoningModelId));
        expect(model.isReasoningModel, isTrue);
      });

      test('findAlibabaKnownModel returns null for invalid ID', () {
        final model = findAlibabaKnownModel('non-existent-model-id');
        expect(model, isNull);
      });

      test('getAlibabaFtueKnownModels returns all required models', () {
        final models = getAlibabaFtueKnownModels();
        expect(models, isNotNull);

        // Verify flash model (Qwen Flash)
        expect(
          models!.flash.providerModelId,
          equals(ftueAlibabaFlashModelId),
        );

        // Verify reasoning model (Qwen 3.5 Plus)
        expect(
          models.reasoning.providerModelId,
          equals(ftueAlibabaReasoningModelId),
        );
        expect(models.reasoning.isReasoningModel, isTrue);

        // Verify audio model (Qwen3 Omni Flash)
        expect(
          models.audio.providerModelId,
          equals(ftueAlibabaAudioModelId),
        );
        expect(models.audio.inputModalities, contains(Modality.audio));

        // Verify vision model (Qwen3 VL Flash)
        expect(
          models.vision.providerModelId,
          equals(ftueAlibabaVisionModelId),
        );
        expect(models.vision.inputModalities, contains(Modality.image));

        // Verify image model (Wan 2.6 Image)
        expect(
          models.image.providerModelId,
          equals(ftueAlibabaImageModelId),
        );
        expect(models.image.outputModalities, contains(Modality.image));
      });

      test('FTUE model constants are valid Alibaba model IDs', () {
        expect(findAlibabaKnownModel(ftueAlibabaFlashModelId), isNotNull);
        expect(findAlibabaKnownModel(ftueAlibabaReasoningModelId), isNotNull);
        expect(findAlibabaKnownModel(ftueAlibabaAudioModelId), isNotNull);
        expect(findAlibabaKnownModel(ftueAlibabaVisionModelId), isNotNull);
        expect(findAlibabaKnownModel(ftueAlibabaImageModelId), isNotNull);
      });

      test('FTUE category constants have expected values', () {
        expect(ftueAlibabaCategoryName, 'Test Category Alibaba Enabled');
        expect(ftueAlibabaCategoryColor, '#FF6D00');
      });
    });

    group('Alibaba Image Generation Model (Wan 2.6)', () {
      test('should have image generation model in alibabaModels', () {
        final imageGenModels = alibabaModels.where(
          (m) => m.outputModalities.contains(Modality.image),
        );

        expect(
          imageGenModels,
          isNotEmpty,
          reason: 'Should have at least one image generation model',
        );

        final model = imageGenModels.first;
        expect(model.providerModelId, 'wan2.6-image');
        expect(model.inputModalities, contains(Modality.text));
        expect(model.outputModalities, contains(Modality.image));
        expect(model.isReasoningModel, isFalse);
        expect(model.supportsFunctionCalling, isFalse);
      });

      test('Wan 2.6 Image model has valid configuration', () {
        final model = alibabaModels.firstWhere(
          (m) => m.providerModelId == 'wan2.6-image',
        );

        expect(model.name, isNotEmpty);
        expect(model.description, isNotEmpty);
        expect(model.inputModalities, contains(Modality.text));
        expect(model.inputModalities, contains(Modality.image));
        expect(model.outputModalities, contains(Modality.text));
        expect(model.outputModalities, contains(Modality.image));
      });
    });

    group('Mistral FTUE functions', () {
      test('findMistralKnownModel returns model for valid ID', () {
        final model = findMistralKnownModel(ftueMistralReasoningModelId);
        expect(model, isNotNull);
        expect(model!.providerModelId, equals(ftueMistralReasoningModelId));
        expect(model.isReasoningModel, isTrue);
      });

      test('findMistralKnownModel returns null for invalid ID', () {
        final model = findMistralKnownModel('non-existent-model-id');
        expect(model, isNull);
      });

      test('getMistralFtueKnownModels returns all required models', () {
        final models = getMistralFtueKnownModels();
        expect(models, isNotNull);

        // Verify flash model (Mistral Small)
        expect(models!.flash.providerModelId, equals(ftueMistralFlashModelId));
        expect(
          models.flash.inputModalities,
          contains(Modality.image),
          reason: 'Flash model should have vision',
        );

        // Verify reasoning model (Magistral Medium)
        expect(
          models.reasoning.providerModelId,
          equals(ftueMistralReasoningModelId),
        );
        expect(models.reasoning.isReasoningModel, isTrue);

        // Verify audio model (Voxtral Mini Transcribe)
        expect(models.audio.providerModelId, equals(ftueMistralAudioModelId));
        expect(models.audio.inputModalities, contains(Modality.audio));
      });

      test('FTUE model constants are valid Mistral model IDs', () {
        expect(findMistralKnownModel(ftueMistralFlashModelId), isNotNull);
        expect(findMistralKnownModel(ftueMistralReasoningModelId), isNotNull);
        expect(findMistralKnownModel(ftueMistralAudioModelId), isNotNull);
      });
    });

    group('Anthropic FTUE constants', () {
      test('FTUE model constants resolve to entries in anthropicModels', () {
        expect(
          findAnthropicKnownModel(ftueAnthropicReasoningModelId),
          isNotNull,
        );
        expect(findAnthropicKnownModel(ftueAnthropicFlashModelId), isNotNull);
      });

      test('getAnthropicFtueKnownModels returns both pairings', () {
        final models = getAnthropicFtueKnownModels();
        expect(models, isNotNull);
        expect(
          models!.reasoning.providerModelId,
          equals(ftueAnthropicReasoningModelId),
        );
        expect(models.reasoning.isReasoningModel, isTrue);
        expect(models.flash.providerModelId, equals(ftueAnthropicFlashModelId));
        // Haiku is a fast model — not flagged as reasoning.
        expect(models.flash.isReasoningModel, isFalse);
      });

      test('findAnthropicKnownModel returns null for unknown ids', () {
        expect(findAnthropicKnownModel('not-a-real-claude-id'), isNull);
      });
    });

    group('Ollama + Anthropic FTUE category constants', () {
      test('Anthropic category name + color have expected values', () {
        expect(ftueAnthropicCategoryName, 'Test Category Anthropic Enabled');
        expect(ftueAnthropicCategoryColor, '#D97757');
      });

      test('Ollama category name + color have expected values', () {
        expect(ftueOllamaCategoryName, 'Test Category Ollama Enabled');
        expect(ftueOllamaCategoryColor, '#0F172A');
      });
    });
  });
}
