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

        for (final model in gemma3nModels) {
          expect(
            model.maxCompletionTokens,
            isNull,
            reason:
                'Gemma3n model ${model.name} should not have maxCompletionTokens defined',
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

    group('knownModelsByProvider', () {
      test('should contain all provider types', () {
        expect(
          knownModelsByProvider.keys.toSet(),
          containsAll([
            InferenceProviderType.gemini,
            InferenceProviderType.gemma3n,
            InferenceProviderType.nebiusAiStudio,
            InferenceProviderType.ollama,
            InferenceProviderType.openAi,
            InferenceProviderType.genericOpenAi,
            InferenceProviderType.anthropic,
            InferenceProviderType.openRouter,
            InferenceProviderType.whisper,
            InferenceProviderType.voxtral,
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

      test('Voxtral Small should have correct model ID', () {
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
          expect(model.description, contains('30 minutes'),
              reason:
                  '${model.name} description should mention audio duration');
          expect(model.description, contains('9 languages'),
              reason:
                  '${model.name} description should mention language support');
        }
      });
    });

    group('Gemma3n Models', () {
      test('should have audio input capability', () {
        for (final model in gemma3nModels) {
          expect(model.inputModalities, contains(Modality.audio),
              reason: '${model.name} should accept audio input');
        }
      });
    });
  });
}
