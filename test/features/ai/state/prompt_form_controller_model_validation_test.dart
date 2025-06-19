import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/settings/prompt_form_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class FakeAiConfigPrompt extends Fake implements AiConfigPrompt {}

void main() {
  group('PromptFormController Model Validation', () {
    late MockAiConfigRepository mockRepository;
    late ProviderContainer container;

    setUpAll(() {
      registerFallbackValue(FakeAiConfigPrompt());
    });

    setUp(() {
      mockRepository = MockAiConfigRepository();
    });

    tearDown(() {
      container.dispose();
    });

    test('filters out non-existing models when loading prompt configuration',
        () async {
      // Create test data
      const promptId = 'prompt-1';
      const existingModelId = 'model-1';
      const deletedModelId = 'model-2';
      const anotherExistingModelId = 'model-3';

      final testPrompt = AiConfigPrompt(
        id: promptId,
        name: 'Test Prompt',
        systemMessage: 'System message',
        userMessage: 'User message',
        defaultModelId: deletedModelId, // Default is the deleted model
        modelIds: [existingModelId, deletedModelId, anotherExistingModelId],
        createdAt: DateTime.now(),
        useReasoning: false,
        requiredInputData: [],
        aiResponseType: AiResponseType.taskSummary,
      );

      final existingModel = AiConfigModel(
        id: existingModelId,
        name: 'Existing Model 1',
        providerModelId: 'provider-model-1',
        inferenceProviderId: 'provider-1',
        createdAt: DateTime.now(),
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
      );

      final anotherExistingModel = AiConfigModel(
        id: anotherExistingModelId,
        name: 'Existing Model 3',
        providerModelId: 'provider-model-3',
        inferenceProviderId: 'provider-1',
        createdAt: DateTime.now(),
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
      );

      // Setup mocks
      when(() => mockRepository.getConfigById(promptId))
          .thenAnswer((_) async => testPrompt);
      when(() => mockRepository.getConfigById(existingModelId))
          .thenAnswer((_) async => existingModel);
      when(() => mockRepository.getConfigById(deletedModelId))
          .thenAnswer((_) async => null); // Model doesn't exist
      when(() => mockRepository.getConfigById(anotherExistingModelId))
          .thenAnswer((_) async => anotherExistingModel);

      // Create container with mocked repository
      container = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );

      // Wait for the controller to build
      final state = await container.read(
        promptFormControllerProvider(configId: promptId).future,
      );

      // Verify that the deleted model was filtered out
      expect(state!.modelIds, [existingModelId, anotherExistingModelId]);
      expect(state.modelIds.contains(deletedModelId), false);

      // Verify that the default model was updated to the first existing model
      expect(state.defaultModelId, existingModelId);
    });

    test('handles case where all models are deleted', () async {
      // Create test data
      const promptId = 'prompt-1';
      const deletedModelId1 = 'model-1';
      const deletedModelId2 = 'model-2';

      final testPrompt = AiConfigPrompt(
        id: promptId,
        name: 'Test Prompt',
        systemMessage: 'System message',
        userMessage: 'User message',
        defaultModelId: deletedModelId1,
        modelIds: [deletedModelId1, deletedModelId2],
        createdAt: DateTime.now(),
        useReasoning: false,
        requiredInputData: [],
        aiResponseType: AiResponseType.taskSummary,
      );

      // Setup mocks - all models return null (deleted)
      when(() => mockRepository.getConfigById(promptId))
          .thenAnswer((_) async => testPrompt);
      when(() => mockRepository.getConfigById(deletedModelId1))
          .thenAnswer((_) async => null);
      when(() => mockRepository.getConfigById(deletedModelId2))
          .thenAnswer((_) async => null);

      // Create container with mocked repository
      container = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );

      // Wait for the controller to build
      final state = await container.read(
        promptFormControllerProvider(configId: promptId).future,
      );

      // Verify that all models were filtered out
      expect(state!.modelIds, isEmpty);
      expect(state.defaultModelId, '');
    });

    test('validates models when updating configuration', () async {
      // Create test data
      const promptId = 'prompt-1';
      const existingModelId = 'model-1';
      const deletedModelId = 'model-2';

      final existingPrompt = AiConfigPrompt(
        id: promptId,
        name: 'Original Prompt',
        systemMessage: 'Original system',
        userMessage: 'Original user',
        defaultModelId: existingModelId,
        modelIds: [existingModelId],
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        useReasoning: false,
        requiredInputData: [],
        aiResponseType: AiResponseType.taskSummary,
      );

      final updatedPrompt = AiConfigPrompt(
        id: promptId,
        name: 'Updated Prompt',
        systemMessage: 'Updated system',
        userMessage: 'Updated user',
        defaultModelId: deletedModelId,
        modelIds: [existingModelId, deletedModelId],
        createdAt: existingPrompt.createdAt,
        useReasoning: false,
        requiredInputData: [],
        aiResponseType: AiResponseType.taskSummary,
      );

      final existingModel = AiConfigModel(
        id: existingModelId,
        name: 'Existing Model',
        providerModelId: 'provider-model-1',
        inferenceProviderId: 'provider-1',
        createdAt: DateTime.now(),
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
      );

      // Setup mocks
      when(() => mockRepository.getConfigById(promptId))
          .thenAnswer((_) async => existingPrompt);
      when(() => mockRepository.getConfigById(existingModelId))
          .thenAnswer((_) async => existingModel);
      when(() => mockRepository.getConfigById(deletedModelId))
          .thenAnswer((_) async => null);
      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});

      // Create container with mocked repository
      container = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );

      // Test the controller
      final controller = container.read(
        promptFormControllerProvider(configId: promptId).notifier,
      );

      // Wait for the controller to build
      await container.read(
        promptFormControllerProvider(configId: promptId).future,
      );

      // Update the configuration
      await controller.updateConfig(updatedPrompt);

      // Verify that saveConfig was called with the filtered model list
      final capturedConfig = verify(
        () => mockRepository.saveConfig(captureAny()),
      ).captured.single as AiConfigPrompt;

      expect(capturedConfig.modelIds, [existingModelId]);
      expect(capturedConfig.defaultModelId, existingModelId);
      expect(capturedConfig.name, 'Updated Prompt');
      expect(capturedConfig.systemMessage, 'Updated system');
      expect(capturedConfig.userMessage, 'Updated user');
    });
  });
}
