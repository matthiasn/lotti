import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/util/known_models.dart';

void main() {
  group('KnownModel', () {
    group('maxCompletionTokens', () {
      test('should be filled when defined in known models', () {
        // Test Anthropic models which have maxCompletionTokens defined
        for (final model in anthropicModels) {
          expect(
            model.maxCompletionTokens,
            isNotNull,
            reason:
                'Anthropic model ${model.name} should have maxCompletionTokens defined',
          );
          expect(
            model.maxCompletionTokens,
            equals(2000),
            reason:
                'Anthropic model ${model.name} should have maxCompletionTokens set to 2000',
          );
        }

        // Test that other providers don't have maxCompletionTokens set
        for (final model in geminiModels) {
          expect(
            model.maxCompletionTokens,
            isNull,
            reason:
                'Gemini model ${model.name} should not have maxCompletionTokens defined',
          );
        }

        for (final model in nebiusModels) {
          expect(
            model.maxCompletionTokens,
            isNull,
            reason:
                'Nebius model ${model.name} should not have maxCompletionTokens defined',
          );
        }

        for (final model in ollamaModels) {
          expect(
            model.maxCompletionTokens,
            isNull,
            reason:
                'Ollama model ${model.name} should not have maxCompletionTokens defined',
          );
        }

        for (final model in openaiModels) {
          expect(
            model.maxCompletionTokens,
            isNull,
            reason:
                'OpenAI model ${model.name} should not have maxCompletionTokens defined',
          );
        }

        for (final model in openRouterModels) {
          expect(
            model.maxCompletionTokens,
            isNull,
            reason:
                'OpenRouter model ${model.name} should not have maxCompletionTokens defined',
          );
        }

        for (final model in genericOpenAiModels) {
          expect(
            model.maxCompletionTokens,
            isNull,
            reason:
                'Generic OpenAI model ${model.name} should not have maxCompletionTokens defined',
          );
        }

        for (final model in whisperModels) {
          expect(
            model.maxCompletionTokens,
            isNull,
            reason:
                'Whisper model ${model.name} should not have maxCompletionTokens defined',
          );
        }

        for (final model in voxtralModels) {
          expect(
            model.maxCompletionTokens,
            isNull,
            reason:
                'Voxtral model ${model.name} should not have maxCompletionTokens defined',
          );
        }

        for (final model in alibabaModels) {
          expect(
            model.maxCompletionTokens,
            isNull,
            reason:
                'Alibaba model ${model.name} should not have maxCompletionTokens defined',
          );
        }
      });

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
      });

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
            aiConfig.providerModelId, equals(anthropicModel.providerModelId));
        expect(aiConfig.inferenceProviderId, equals(testProviderId));
        expect(
            aiConfig.inputModalities, equals(anthropicModel.inputModalities));
        expect(
            aiConfig.outputModalities, equals(anthropicModel.outputModalities));
        expect(
            aiConfig.isReasoningModel, equals(anthropicModel.isReasoningModel));
        expect(aiConfig.description, equals(anthropicModel.description));
        expect(aiConfig.maxCompletionTokens,
            equals(anthropicModel.maxCompletionTokens));
        expect(aiConfig.createdAt, isA<DateTime>());
      });
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
    });

    group('Image Generation Model (Nano Banana Pro)', () {
      test('should have image generation model in geminiModels', () {
        final imageGenModel = geminiModels.where(
          (m) => m.outputModalities.contains(Modality.image),
        );

        expect(imageGenModel, isNotEmpty,
            reason: 'Should have at least one image generation model');

        final model = imageGenModel.first;
        expect(model.providerModelId, contains('image'));
        expect(model.inputModalities, contains(Modality.text));
        expect(model.outputModalities, contains(Modality.image));
        expect(model.isReasoningModel, isFalse);
      });

      test('image generation model should have valid configuration', () {
        final imageGenModel = geminiModels.firstWhere(
          (m) => m.outputModalities.contains(Modality.image),
        );

        expect(imageGenModel.name, isNotEmpty);
        expect(imageGenModel.description, isNotEmpty);
        expect(imageGenModel.providerModelId, isNotEmpty);
      });
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
        expect(models.reasoning.providerModelId,
            equals(ftueOpenAiReasoningModelId));
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

    group('knownModelsByProvider', () {
      test('should contain all provider types', () {
        expect(
          knownModelsByProvider.keys.toSet(),
          containsAll([
            InferenceProviderType.alibaba,
            InferenceProviderType.gemini,
            InferenceProviderType.nebiusAiStudio,
            InferenceProviderType.ollama,
            InferenceProviderType.openAi,
            InferenceProviderType.genericOpenAi,
            InferenceProviderType.anthropic,
            InferenceProviderType.openRouter,
            InferenceProviderType.whisper,
            InferenceProviderType.voxtral,
            InferenceProviderType.mistral,
          ]),
        );
      });

      test('all models should have valid configurations', () {
        for (final entry in knownModelsByProvider.entries) {
          final providerType = entry.key;
          final models = entry.value;

          for (final model in models) {
            // Verify required fields are not empty
            expect(model.providerModelId, isNotEmpty,
                reason:
                    'Model in $providerType should have non-empty providerModelId');
            expect(model.name, isNotEmpty,
                reason: 'Model in $providerType should have non-empty name');
            expect(model.description, isNotEmpty,
                reason:
                    'Model in $providerType should have non-empty description');

            // Verify modalities are not empty
            expect(model.inputModalities, isNotEmpty,
                reason:
                    'Model ${model.name} should have at least one input modality');
            expect(model.outputModalities, isNotEmpty,
                reason:
                    'Model ${model.name} should have at least one output modality');

            // Verify maxCompletionTokens is positive if defined
            if (model.maxCompletionTokens != null) {
              expect(model.maxCompletionTokens! > 0, isTrue,
                  reason:
                      'Model ${model.name} should have positive maxCompletionTokens if defined');
            }
          }
        }
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
          expect(model.inputModalities, contains(Modality.audio),
              reason: '${model.name} should accept audio input');
          expect(model.outputModalities, contains(Modality.text),
              reason: '${model.name} should output text');
          expect(model.isReasoningModel, isFalse,
              reason: '${model.name} should not be a reasoning model');
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
          expect(model.description, contains('30 min'),
              reason:
                  '${model.name} description should mention audio duration');
          expect(model.description, contains('languages'),
              reason:
                  '${model.name} description should mention language support');
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
        expect(flashModel.inputModalities, contains(Modality.image),
            reason: 'Mistral Small should accept image input');
        expect(flashModel.isReasoningModel, isFalse);
      });

      test('Magistral Medium should be a reasoning model', () {
        final reasoningModel = mistralModels.firstWhere(
          (m) => m.providerModelId == ftueMistralReasoningModelId,
        );
        expect(reasoningModel.isReasoningModel, isTrue,
            reason: 'Magistral Medium should be a reasoning model');
      });

      test('Voxtral Mini Transcribe should have audio input', () {
        final audioModel = mistralModels.firstWhere(
          (m) => m.providerModelId == ftueMistralAudioModelId,
        );
        expect(audioModel.inputModalities, contains(Modality.audio),
            reason: 'Voxtral Mini Transcribe should accept audio input');
        expect(audioModel.outputModalities, contains(Modality.text));
      });

      test('all Mistral models should have valid configurations', () {
        for (final model in mistralModels) {
          expect(model.providerModelId, isNotEmpty,
              reason:
                  'Model ${model.name} should have non-empty providerModelId');
          expect(model.name, isNotEmpty,
              reason: 'Model should have non-empty name');
          expect(model.description, isNotEmpty,
              reason: 'Model ${model.name} should have non-empty description');
          expect(model.inputModalities, isNotEmpty,
              reason:
                  'Model ${model.name} should have at least one input modality');
          expect(model.outputModalities, isNotEmpty,
              reason:
                  'Model ${model.name} should have at least one output modality');
        }
      });
    });

    group('Alibaba Models', () {
      test('should have text, vision, and reasoning models', () {
        expect(alibabaModels.length, equals(8));

        final textModels = alibabaModels.where(
          (m) =>
              m.inputModalities.contains(Modality.text) &&
              !m.inputModalities.contains(Modality.image),
        );
        final visionModels = alibabaModels.where(
          (m) => m.inputModalities.contains(Modality.image),
        );
        final reasoningModels = alibabaModels.where(
          (m) => m.isReasoningModel,
        );

        expect(textModels, isNotEmpty, reason: 'Should have text-only models');
        expect(visionModels, isNotEmpty, reason: 'Should have vision models');
        expect(reasoningModels, isNotEmpty,
            reason: 'Should have reasoning models');
      });

      test('Qwen3 Max should be a reasoning model', () {
        final maxModel = alibabaModels.firstWhere(
          (m) => m.providerModelId == 'qwen3-max',
        );
        expect(maxModel.isReasoningModel, isTrue);
        expect(maxModel.supportsFunctionCalling, isTrue);
      });

      test('QwQ Plus should be a reasoning model', () {
        final qwqModel = alibabaModels.firstWhere(
          (m) => m.providerModelId == 'qwq-plus',
        );
        expect(qwqModel.isReasoningModel, isTrue);
      });

      test('vision models should accept image input', () {
        final vlModels = alibabaModels.where(
          (m) => m.providerModelId.contains('vl'),
        );
        expect(vlModels.length, equals(2));

        for (final model in vlModels) {
          expect(model.inputModalities, contains(Modality.image),
              reason: '${model.name} should accept image input');
          expect(model.outputModalities, contains(Modality.text),
              reason: '${model.name} should output text');
        }
      });

      test('all Alibaba models should have valid configurations', () {
        for (final model in alibabaModels) {
          expect(model.providerModelId, isNotEmpty,
              reason:
                  'Model ${model.name} should have non-empty providerModelId');
          expect(model.name, isNotEmpty,
              reason: 'Model should have non-empty name');
          expect(model.description, isNotEmpty,
              reason: 'Model ${model.name} should have non-empty description');
          expect(model.inputModalities, isNotEmpty,
              reason:
                  'Model ${model.name} should have at least one input modality');
          expect(model.outputModalities, isNotEmpty,
              reason:
                  'Model ${model.name} should have at least one output modality');
        }
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
        expect(models.flash.inputModalities, contains(Modality.image),
            reason: 'Flash model should have vision');

        // Verify reasoning model (Magistral Medium)
        expect(models.reasoning.providerModelId,
            equals(ftueMistralReasoningModelId));
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
  });
}
