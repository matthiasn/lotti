import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_model_form_state.dart';

void main() {
  group('InferenceModelFormState Tests', () {
    group('Input Validation Classes', () {
      test('ModelName validation', () {
        const validName = ModelName.dirty('Valid Model Name');
        const shortName = ModelName.dirty('Ab');
        const emptyName = ModelName.dirty();
        const exactlyThree = ModelName.dirty('ABC');

        expect(validName.isValid, isTrue);
        expect(validName.error, isNull);

        expect(shortName.isValid, isFalse);
        expect(shortName.error, ModelFormError.tooShort);

        expect(emptyName.isValid, isFalse);
        expect(emptyName.error, ModelFormError.tooShort);

        expect(exactlyThree.isValid, isTrue);
        expect(exactlyThree.error, isNull);
      });

      test('ProviderModelId validation', () {
        const validId = ProviderModelId.dirty('gpt-4o');
        const shortId = ProviderModelId.dirty('gp');
        const emptyId = ProviderModelId.dirty();
        const exactlyThree = ProviderModelId.dirty('gpt');

        expect(validId.isValid, isTrue);
        expect(validId.error, isNull);

        expect(shortId.isValid, isFalse);
        expect(shortId.error, ModelFormError.tooShort);

        expect(emptyId.isValid, isFalse);
        expect(emptyId.error, ModelFormError.tooShort);

        expect(exactlyThree.isValid, isTrue);
        expect(exactlyThree.error, isNull);
      });

      test('ModelDescription validation', () {
        const description = ModelDescription.dirty('Some description');
        final longDescription =
            ModelDescription.dirty('A very long description ' * 50);
        const emptyDescription = ModelDescription.dirty();

        expect(description.isValid, isTrue);
        expect(description.error, isNull);

        expect(longDescription.isValid, isTrue);
        expect(longDescription.error, isNull);

        expect(emptyDescription.isValid, isTrue); // Optional field
        expect(emptyDescription.error, isNull);
      });

      test('MaxCompletionTokens validation', () {
        const validTokens = MaxCompletionTokens.dirty('1000');
        const largeTokens = MaxCompletionTokens.dirty('999999');
        const emptyTokens = MaxCompletionTokens.dirty();
        const invalidTokens = MaxCompletionTokens.dirty('abc');
        const negativeTokens = MaxCompletionTokens.dirty('-100');
        const zeroTokens = MaxCompletionTokens.dirty('0');
        const decimalTokens = MaxCompletionTokens.dirty('100.5');

        expect(validTokens.isValid, isTrue);
        expect(validTokens.error, isNull);

        expect(largeTokens.isValid, isTrue);
        expect(largeTokens.error, isNull);

        expect(emptyTokens.isValid, isTrue); // Optional field
        expect(emptyTokens.error, isNull);

        expect(invalidTokens.isValid, isFalse);
        expect(invalidTokens.error, ModelFormError.invalidNumber);

        expect(negativeTokens.isValid, isFalse);
        expect(negativeTokens.error, ModelFormError.invalidNumber);

        expect(zeroTokens.isValid, isFalse);
        expect(zeroTokens.error, ModelFormError.invalidNumber);

        expect(decimalTokens.isValid, isFalse);
        expect(decimalTokens.error, ModelFormError.invalidNumber);
      });

      test('Pure vs Dirty states', () {
        const pureName = ModelName.pure('Test');
        const dirtyName = ModelName.dirty('Test');

        expect(pureName.isPure, isTrue);
        expect(dirtyName.isPure, isFalse);
      });
    });

    group('InferenceModelFormState', () {
      test('Default constructor creates valid state', () {
        final state = InferenceModelFormState();

        expect(state.id, isNull);
        expect(state.name.value, isEmpty);
        expect(state.providerModelId.value, isEmpty);
        expect(state.description.value, isEmpty);
        expect(state.maxCompletionTokens.value, isEmpty);
        expect(state.inferenceProviderId, isEmpty);
        expect(state.inputModalities, equals([Modality.text]));
        expect(state.outputModalities, equals([Modality.text]));
        expect(state.isReasoningModel, isFalse);
        expect(state.isValid,
            isFalse); // Invalid because required fields are empty
      });

      test('Constructor with all parameters', () {
        final state = InferenceModelFormState(
          id: 'test-id',
          name: const ModelName.dirty('Test Model'),
          providerModelId: const ProviderModelId.dirty('test-model-id'),
          description: const ModelDescription.dirty('Test description'),
          maxCompletionTokens: const MaxCompletionTokens.dirty('2000'),
          inferenceProviderId: 'provider-id',
          inputModalities: [Modality.text, Modality.image],
          outputModalities: [Modality.text],
          isReasoningModel: true,
        );

        expect(state.id, equals('test-id'));
        expect(state.name.value, equals('Test Model'));
        expect(state.providerModelId.value, equals('test-model-id'));
        expect(state.description.value, equals('Test description'));
        expect(state.maxCompletionTokens.value, equals('2000'));
        expect(state.inferenceProviderId, equals('provider-id'));
        expect(state.inputModalities, equals([Modality.text, Modality.image]));
        expect(state.outputModalities, equals([Modality.text]));
        expect(state.isReasoningModel, isTrue);
      });

      test('copyWith maintains existing values when not specified', () {
        final original = InferenceModelFormState(
          id: 'test-id',
          name: const ModelName.dirty('Original Name'),
          providerModelId: const ProviderModelId.dirty('original-id'),
          inferenceProviderId: 'provider-id',
          isReasoningModel: true,
        );

        final copied = original.copyWith();

        expect(copied.id, equals(original.id));
        expect(copied.name, equals(original.name));
        expect(copied.providerModelId, equals(original.providerModelId));
        expect(
            copied.inferenceProviderId, equals(original.inferenceProviderId));
        expect(copied.isReasoningModel, equals(original.isReasoningModel));
      });

      test('copyWith updates specified values', () {
        final original = InferenceModelFormState();

        final updated = original.copyWith(
          id: 'new-id',
          name: const ModelName.dirty('Updated Name'),
          providerModelId: const ProviderModelId.dirty('updated-id'),
          description: const ModelDescription.dirty('New description'),
          maxCompletionTokens: const MaxCompletionTokens.dirty('3000'),
          inferenceProviderId: 'new-provider',
          inputModalities: [Modality.text, Modality.audio],
          outputModalities: [Modality.text, Modality.image],
          isReasoningModel: true,
        );

        expect(updated.id, equals('new-id'));
        expect(updated.name.value, equals('Updated Name'));
        expect(updated.providerModelId.value, equals('updated-id'));
        expect(updated.description.value, equals('New description'));
        expect(updated.maxCompletionTokens.value, equals('3000'));
        expect(updated.inferenceProviderId, equals('new-provider'));
        expect(
            updated.inputModalities, equals([Modality.text, Modality.audio]));
        expect(
            updated.outputModalities, equals([Modality.text, Modality.image]));
        expect(updated.isReasoningModel, isTrue);
      });

      test('FormzMixin validation works correctly', () {
        // Invalid state - missing required fields
        final invalidState = InferenceModelFormState();
        expect(invalidState.isValid, isFalse);

        // Valid state - all required fields provided
        final validState = InferenceModelFormState(
          name: const ModelName.dirty('Valid Model'),
          providerModelId: const ProviderModelId.dirty('valid-model-id'),
          inferenceProviderId: 'provider-id',
        );
        expect(validState.isValid, isTrue);

        // Invalid state - one required field too short
        final partiallyInvalidState = InferenceModelFormState(
          name: const ModelName.dirty('Va'), // Too short
          providerModelId: const ProviderModelId.dirty('valid-model-id'),
          inferenceProviderId: 'provider-id',
        );
        expect(partiallyInvalidState.isValid, isFalse);
      });

      test('inputs getter returns all form inputs', () {
        final state = InferenceModelFormState(
          name: const ModelName.dirty('Test'),
          providerModelId: const ProviderModelId.dirty('test-id'),
          description: const ModelDescription.dirty('Description'),
          maxCompletionTokens: const MaxCompletionTokens.dirty('1000'),
        );

        final inputs = state.inputs;

        expect(inputs.length, equals(4));
        expect(inputs[0], equals(state.name));
        expect(inputs[1], equals(state.providerModelId));
        expect(inputs[2], equals(state.description));
        expect(inputs[3], equals(state.maxCompletionTokens));
      });

      group('toAiConfig conversion', () {
        test('creates new AiConfig with generated UUID when id is null', () {
          final state = InferenceModelFormState(
            name: const ModelName.dirty('Test Model'),
            providerModelId: const ProviderModelId.dirty('test-model-id'),
            description: const ModelDescription.dirty('Test description'),
            maxCompletionTokens: const MaxCompletionTokens.dirty('2000'),
            inferenceProviderId: 'provider-id',
            inputModalities: [Modality.text, Modality.image],
            outputModalities: [Modality.text],
            isReasoningModel: true,
          );

          final config = state.toAiConfig();

          expect(config, isA<AiConfigModel>());
          final modelConfig = config as AiConfigModel;
          expect(modelConfig.id, isNotEmpty); // UUID generated
          expect(modelConfig.name, equals('Test Model'));
          expect(modelConfig.providerModelId, equals('test-model-id'));
          expect(modelConfig.description, equals('Test description'));
          expect(modelConfig.inferenceProviderId, equals('provider-id'));
          expect(modelConfig.inputModalities,
              equals([Modality.text, Modality.image]));
          expect(modelConfig.outputModalities, equals([Modality.text]));
          expect(modelConfig.isReasoningModel, isTrue);
          expect(modelConfig.maxCompletionTokens, equals(2000));
          expect(modelConfig.createdAt, isA<DateTime>());
        });

        test('uses existing id when provided', () {
          final state = InferenceModelFormState(
            id: 'existing-id',
            name: const ModelName.dirty('Test Model'),
            providerModelId: const ProviderModelId.dirty('test-model-id'),
            inferenceProviderId: 'provider-id',
          );

          final config = state.toAiConfig();

          expect(config, isA<AiConfigModel>());
          final modelConfig = config as AiConfigModel;
          expect(modelConfig.id, equals('existing-id'));
        });

        test('handles empty maxCompletionTokens correctly', () {
          final state = InferenceModelFormState(
            name: const ModelName.dirty('Test Model'),
            providerModelId: const ProviderModelId.dirty('test-model-id'),
            inferenceProviderId: 'provider-id',
            maxCompletionTokens: const MaxCompletionTokens.dirty(),
          );

          final config = state.toAiConfig();

          expect(config, isA<AiConfigModel>());
          final modelConfig = config as AiConfigModel;
          expect(modelConfig.maxCompletionTokens, isNull);
        });

        test('parses valid maxCompletionTokens correctly', () {
          final state = InferenceModelFormState(
            name: const ModelName.dirty('Test Model'),
            providerModelId: const ProviderModelId.dirty('test-model-id'),
            inferenceProviderId: 'provider-id',
            maxCompletionTokens: const MaxCompletionTokens.dirty('5000'),
          );

          final config = state.toAiConfig();

          expect(config, isA<AiConfigModel>());
          final modelConfig = config as AiConfigModel;
          expect(modelConfig.maxCompletionTokens, equals(5000));
        });

        test('all modality combinations work correctly', () {
          final testCases = [
            ([Modality.text], [Modality.text]),
            ([Modality.text, Modality.image], [Modality.text]),
            ([Modality.text, Modality.audio], [Modality.text]),
            (
              [Modality.text, Modality.image, Modality.audio],
              [Modality.text, Modality.image]
            ),
          ];

          for (final testCase in testCases) {
            final state = InferenceModelFormState(
              name: const ModelName.dirty('Test Model'),
              providerModelId: const ProviderModelId.dirty('test-model-id'),
              inferenceProviderId: 'provider-id',
              inputModalities: testCase.$1,
              outputModalities: testCase.$2,
            );

            final config = state.toAiConfig();

            expect(config, isA<AiConfigModel>());
            final modelConfig = config as AiConfigModel;
            expect(modelConfig.inputModalities, equals(testCase.$1));
            expect(modelConfig.outputModalities, equals(testCase.$2));
          }
        });
      });
    });
  });
}
