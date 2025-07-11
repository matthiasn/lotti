import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/settings/prompt_form_controller.dart';
import 'package:mocktail/mocktail.dart';

// Mocks
class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class FakeAiConfigPrompt extends Fake implements AiConfigPrompt {}

void main() {
  late ProviderContainer container;
  late MockAiConfigRepository mockAiConfigRepository;

  setUpAll(() {
    registerFallbackValue(FakeAiConfigPrompt());
  });

  setUp(() {
    mockAiConfigRepository = MockAiConfigRepository();
    container = ProviderContainer(
      overrides: [
        aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('PromptFormController - Dirty State Tracking', () {
    const testConfigId = 'test-config-id';
    final testConfig = AiConfigPrompt(
      id: testConfigId,
      name: 'Test Name',
      systemMessage: 'Test System Message',
      userMessage: 'Test User Message',
      description: 'Test Description',
      category: 'Test Category',
      comment: 'Test Comment',
      defaultModelId: 'model1',
      modelIds: ['model1', 'model2'],
      useReasoning: true,
      requiredInputData: [InputDataType.task],
      defaultVariables: {'var1': 'val1'},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      aiResponseType: AiResponseType.taskSummary,
    );

    test(
        'form should start with clean (non-dirty) state when loading existing config',
        () async {
      when(() => mockAiConfigRepository.getConfigById(testConfigId))
          .thenAnswer((_) async => testConfig);

      await container
          .read(promptFormControllerProvider(configId: testConfigId).future);

      final state = container
          .read(promptFormControllerProvider(configId: testConfigId))
          .value;

      expect(state, isNotNull);
      expect(state!.isDirty, isFalse,
          reason: 'Form should not be dirty when initially loaded');
    });

    test('changing modelIds should make form dirty', () async {
      when(() => mockAiConfigRepository.getConfigById(testConfigId))
          .thenAnswer((_) async => testConfig);

      await container
          .read(promptFormControllerProvider(configId: testConfigId).future);

      final controller = container
          .read(promptFormControllerProvider(configId: testConfigId).notifier);

      // Initially clean
      var state = container
          .read(promptFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isFalse);

      // Change modelIds
      controller.modelIdsChanged(['model1', 'model2', 'model3']);

      // Should be dirty now
      state = container
          .read(promptFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isTrue,
          reason: 'Form should be dirty after changing modelIds');
    });

    test('changing defaultModelId should make form dirty', () async {
      when(() => mockAiConfigRepository.getConfigById(testConfigId))
          .thenAnswer((_) async => testConfig);

      await container
          .read(promptFormControllerProvider(configId: testConfigId).future);

      final controller = container
          .read(promptFormControllerProvider(configId: testConfigId).notifier);

      // Initially clean
      var state = container
          .read(promptFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isFalse);

      // Change defaultModelId
      controller.defaultModelIdChanged('model2');

      // Should be dirty now
      state = container
          .read(promptFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isTrue,
          reason: 'Form should be dirty after changing defaultModelId');
    });

    test('changing useReasoning should make form dirty', () async {
      when(() => mockAiConfigRepository.getConfigById(testConfigId))
          .thenAnswer((_) async => testConfig);

      await container
          .read(promptFormControllerProvider(configId: testConfigId).future);

      final controller = container
          .read(promptFormControllerProvider(configId: testConfigId).notifier);

      // Initially clean
      var state = container
          .read(promptFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isFalse);

      // Change useReasoning
      controller.useReasoningChanged(false); // testConfig has true

      // Should be dirty now
      state = container
          .read(promptFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isTrue,
          reason: 'Form should be dirty after changing useReasoning');
    });

    test('changing requiredInputData should make form dirty', () async {
      when(() => mockAiConfigRepository.getConfigById(testConfigId))
          .thenAnswer((_) async => testConfig);

      await container
          .read(promptFormControllerProvider(configId: testConfigId).future);

      final controller = container
          .read(promptFormControllerProvider(configId: testConfigId).notifier);

      // Initially clean
      var state = container
          .read(promptFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isFalse);

      // Change requiredInputData
      controller
          .requiredInputDataChanged([InputDataType.task, InputDataType.images]);

      // Should be dirty now
      state = container
          .read(promptFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isTrue,
          reason: 'Form should be dirty after changing requiredInputData');
    });

    test('changing text fields should make form dirty', () async {
      when(() => mockAiConfigRepository.getConfigById(testConfigId))
          .thenAnswer((_) async => testConfig);

      await container
          .read(promptFormControllerProvider(configId: testConfigId).future);

      final controller = container
          .read(promptFormControllerProvider(configId: testConfigId).notifier);

      // Test name field
      var state = container
          .read(promptFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isFalse);

      controller.nameChanged('Modified Name');
      state = container
          .read(promptFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isTrue,
          reason: 'Form should be dirty after changing name');

      // Reset for next test
      container.dispose();
      container = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepository),
        ],
      );
      await container
          .read(promptFormControllerProvider(configId: testConfigId).future);

      // Test description field
      container
          .read(promptFormControllerProvider(configId: testConfigId).notifier)
          .descriptionChanged('Modified Description');
      state = container
          .read(promptFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isTrue,
          reason: 'Form should be dirty after changing description');
    });

    test('changing aiResponseType should make form dirty', () async {
      when(() => mockAiConfigRepository.getConfigById(testConfigId))
          .thenAnswer((_) async => testConfig);

      await container
          .read(promptFormControllerProvider(configId: testConfigId).future);

      final controller = container
          .read(promptFormControllerProvider(configId: testConfigId).notifier);

      // Initially clean
      var state = container
          .read(promptFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isFalse);

      // Change aiResponseType
      controller.aiResponseTypeChanged(AiResponseType.actionItemSuggestions);

      // Should be dirty now
      state = container
          .read(promptFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isTrue,
          reason: 'Form should be dirty after changing aiResponseType');
    });

    test('setting same value should not make form dirty', () async {
      when(() => mockAiConfigRepository.getConfigById(testConfigId))
          .thenAnswer((_) async => testConfig);

      await container
          .read(promptFormControllerProvider(configId: testConfigId).future);

      final controller = container
          .read(promptFormControllerProvider(configId: testConfigId).notifier);

      // Initially clean
      var state = container
          .read(promptFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isFalse);

      // Set same useReasoning value
      controller.useReasoningChanged(true); // testConfig already has true

      // Should still be clean
      state = container
          .read(promptFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isFalse,
          reason: 'Form should not be dirty when setting same value');
    });
  });
}
