import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/prompt_form_state.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/prompt_form_controller.dart';
import 'package:mocktail/mocktail.dart';

// Mocks
class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class MockAiConfigPrompt extends Mock implements AiConfigPrompt {}

// Fallback class for AiConfigPrompt if needed for deeper interactions,
// but for `any()` a simple instance from the mock is usually enough.
class FakeAiConfigPrompt extends Fake implements AiConfigPrompt {}

void main() {
  late ProviderContainer container;
  late MockAiConfigRepository mockAiConfigRepository;

  setUpAll(() {
    // Register fallback for AiConfigPrompt (or AiConfig if it was the direct type)
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

  group('PromptFormController', () {
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

    test('build loads existing config when configId is provided', () async {
      when(() => mockAiConfigRepository.getConfigById(testConfigId))
          .thenAnswer((_) async => testConfig);

      final controller = container.read(
        promptFormControllerProvider(configId: testConfigId).notifier,
      );

      // Allow the future in the build method to complete
      await container
          .read(promptFormControllerProvider(configId: testConfigId).future);

      expect(controller.nameController.text, testConfig.name);
      expect(controller.systemMessageController.text, testConfig.systemMessage);
      expect(controller.userMessageController.text, testConfig.userMessage);
      expect(controller.descriptionController.text, testConfig.description);

      final state = container
          .read(promptFormControllerProvider(configId: testConfigId))
          .value;
      expect(state, isNotNull);
      expect(state!.id, testConfig.id);
      expect(state.name.value, testConfig.name);
      expect(state.systemMessage.value, testConfig.systemMessage);
      expect(state.userMessage.value, testConfig.userMessage);
      expect(state.description.value, testConfig.description);
      expect(state.category.value, testConfig.category);
      expect(state.comment.value, testConfig.comment);
      expect(state.defaultModelId, testConfig.defaultModelId);
      expect(state.modelIds, testConfig.modelIds);
      expect(state.useReasoning, testConfig.useReasoning);
      expect(state.requiredInputData, testConfig.requiredInputData);
      expect(state.defaultVariables, testConfig.defaultVariables);
    });

    test('build initializes with default state when configId is null',
        () async {
      final controller = container.read(
        promptFormControllerProvider(configId: null).notifier,
      );
      // Allow the future in the build method to complete
      await container.read(promptFormControllerProvider(configId: null).future);

      expect(controller.nameController.text, '');
      expect(controller.systemMessageController.text, '');
      expect(controller.userMessageController.text, '');
      expect(controller.descriptionController.text, '');

      final state =
          container.read(promptFormControllerProvider(configId: null)).value;
      expect(state, isNotNull);
      expect(state!.id, isNull);
      expect(state.name.value, '');
      expect(state.systemMessage.value, '');
      expect(state.userMessage.value, '');
      expect(state.description.value, '');
    });

    test('nameChanged updates state and controller', () async {
      // Initialize with null configId to ensure clean state for this test
      await container.read(promptFormControllerProvider(configId: null).future);
      final controller =
          container.read(promptFormControllerProvider(configId: null).notifier);

      const newName = 'New Name';
      controller.nameChanged(newName);

      expect(controller.nameController.text, newName);
      final state =
          container.read(promptFormControllerProvider(configId: null)).value;
      expect(state!.name.value, newName);
    });

    test('systemMessageChanged updates state and controller', () async {
      await container.read(promptFormControllerProvider(configId: null).future);
      final controller =
          container.read(promptFormControllerProvider(configId: null).notifier);
      const newMessage = 'New System Message';
      controller.systemMessageChanged(newMessage);

      expect(controller.systemMessageController.text, newMessage);
      final state =
          container.read(promptFormControllerProvider(configId: null)).value;
      expect(state!.systemMessage.value, newMessage);
    });

    test('userMessageChanged updates state and controller', () async {
      await container.read(promptFormControllerProvider(configId: null).future);
      final controller =
          container.read(promptFormControllerProvider(configId: null).notifier);
      const newMessage = 'New User Message';
      controller.userMessageChanged(newMessage);

      expect(controller.userMessageController.text, newMessage);
      final state =
          container.read(promptFormControllerProvider(configId: null)).value;
      expect(state!.userMessage.value, newMessage);
    });

    test('descriptionChanged updates state and controller', () async {
      await container.read(promptFormControllerProvider(configId: null).future);
      final controller =
          container.read(promptFormControllerProvider(configId: null).notifier);
      const newDescription = 'New Description';
      controller.descriptionChanged(newDescription);

      expect(controller.descriptionController.text, newDescription);
      final state =
          container.read(promptFormControllerProvider(configId: null)).value;
      expect(state!.description.value, newDescription);
    });

    test('defaultModelIdChanged updates state', () async {
      await container.read(promptFormControllerProvider(configId: null).future);
      final controller =
          container.read(promptFormControllerProvider(configId: null).notifier);
      const newModelId = 'gpt-4';
      controller.defaultModelIdChanged(newModelId);

      final state =
          container.read(promptFormControllerProvider(configId: null)).value;
      expect(state!.defaultModelId, newModelId);
    });

    test('useReasoningChanged updates state', () async {
      await container.read(promptFormControllerProvider(configId: null).future);
      final controller = container
          .read(promptFormControllerProvider(configId: null).notifier)
        ..useReasoningChanged(true);
      var state =
          container.read(promptFormControllerProvider(configId: null)).value;
      expect(state!.useReasoning, true);

      controller.useReasoningChanged(false);
      state =
          container.read(promptFormControllerProvider(configId: null)).value;
      expect(state!.useReasoning, false);
    });

    test('requiredInputDataChanged updates state', () async {
      await container.read(promptFormControllerProvider(configId: null).future);
      final controller =
          container.read(promptFormControllerProvider(configId: null).notifier);
      final newInputData = [InputDataType.images, InputDataType.task];
      controller.requiredInputDataChanged(newInputData);

      final state =
          container.read(promptFormControllerProvider(configId: null)).value;
      expect(state!.requiredInputData, newInputData);
    });

    test('modelIdsChanged updates state and defaultModelId correctly',
        () async {
      // Initial state with a default model
      when(
        () => mockAiConfigRepository.getConfigById(testConfigId),
      ).thenAnswer(
        (_) async => testConfig,
      ); // testConfig has defaultModelId: 'model1', modelIds: ['model1', 'model2']
      await container
          .read(promptFormControllerProvider(configId: testConfigId).future);
      container
          .read(promptFormControllerProvider(configId: testConfigId).notifier)
          // Case 1: New list is empty
          .modelIdsChanged([]);
      var state = container
          .read(promptFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.modelIds, isEmpty);
      expect(state.defaultModelId, isEmpty);

      // Reset to initial state for next case by re-reading the provider
      container.dispose();
      container = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepository),
        ],
      );
      when(() => mockAiConfigRepository.getConfigById(testConfigId))
          .thenAnswer((_) async => testConfig);
      await container
          .read(promptFormControllerProvider(configId: testConfigId).future);
      container
          .read(promptFormControllerProvider(configId: testConfigId).notifier)
          // Case 2: Current default model ID is not in the new list
          .modelIdsChanged(['model3', 'model4']);
      state = container
          .read(promptFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.modelIds, ['model3', 'model4']);
      expect(
        state.defaultModelId,
        'model3',
      ); // Should be the first in the new list

      // Reset again
      container.dispose();
      container = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepository),
        ],
      );
      when(() => mockAiConfigRepository.getConfigById(testConfigId))
          .thenAnswer((_) async => testConfig);
      await container
          .read(promptFormControllerProvider(configId: testConfigId).future);
      container
          .read(promptFormControllerProvider(configId: testConfigId).notifier)
          // Case 3: Default model ID is still valid
          .modelIdsChanged(['model1', 'model3']);
      state = container
          .read(promptFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.modelIds, ['model1', 'model3']);
      expect(state.defaultModelId, 'model1'); // Should remain 'model1'
    });

    test('defaultVariablesChanged updates state', () async {
      await container.read(promptFormControllerProvider(configId: null).future);
      final controller =
          container.read(promptFormControllerProvider(configId: null).notifier);
      const newVars = {'var2': 'val2', 'var3': 'val3'};
      controller.defaultVariablesChanged(newVars);
      final state =
          container.read(promptFormControllerProvider(configId: null)).value;
      expect(state!.defaultVariables, newVars);
    });

    test('addConfig calls repository saveConfig', () async {
      await container.read(promptFormControllerProvider(configId: null).future);
      final controller =
          container.read(promptFormControllerProvider(configId: null).notifier);
      final newConfig =
          MockAiConfigPrompt(); // Use a mock or a simple AiConfig instance
      when(() => mockAiConfigRepository.saveConfig(newConfig))
          .thenAnswer((_) async {});

      await controller.addConfig(newConfig);

      verify(() => mockAiConfigRepository.saveConfig(newConfig)).called(1);
    });

    test(
        'updateConfig calls repository saveConfig with updated timestamps and id',
        () async {
      // Initialize with an existing config
      when(() => mockAiConfigRepository.getConfigById(testConfigId))
          .thenAnswer((_) async => testConfig);
      await container
          .read(promptFormControllerProvider(configId: testConfigId).future);
      final controller = container
          .read(promptFormControllerProvider(configId: testConfigId).notifier);

      final updatedConfigData = testConfig.copyWith(name: 'Updated Name');
      when(() => mockAiConfigRepository.saveConfig(any()))
          .thenAnswer((_) async {});

      await controller.updateConfig(updatedConfigData);

      final captured =
          verify(() => mockAiConfigRepository.saveConfig(captureAny()))
              .captured;
      expect(captured.length, 1);
      final savedConfig = captured.first as AiConfigPrompt;
      expect(savedConfig.id, testConfigId); // Ensure original ID is used
      expect(savedConfig.name, 'Updated Name');
      expect(savedConfig.createdAt, testConfig.createdAt); // Original createdAt
      expect(savedConfig.updatedAt, isNotNull);
      expect(testConfig.updatedAt, isNotNull);
      expect(
        savedConfig.updatedAt!.isAfter(testConfig.updatedAt!),
        isTrue,
      ); // Updated 'updatedAt'
    });

    test('updateConfig uses new id if original config id is null', () async {
      // Initialize with no configId
      // Ensure build is complete before interacting with controller
      await container.read(promptFormControllerProvider(configId: null).future);
      final controller =
          container.read(promptFormControllerProvider(configId: null).notifier);

      // Use a concrete instance of AiConfigPrompt for newConfig
      final fixedCreatedAt =
          DateTime.now().subtract(const Duration(seconds: 5));
      final newConfig = AiConfigPrompt(
        id: 'new-id-on-update',
        name: 'New Name',
        systemMessage: 'New System',
        userMessage: 'New User',
        defaultModelId: 'model1',
        modelIds: ['model1'],
        createdAt:
            fixedCreatedAt, // ensure createdAt is definitely before updatedAt
        useReasoning: false,
        requiredInputData: [],
        aiResponseType: AiResponseType.taskSummary,
      );

      // Stub the saveConfig method
      when(() => mockAiConfigRepository.saveConfig(any()))
          .thenAnswer((_) async {});

      // Allow a small delay to ensure DateTime.now() in controller is after fixedCreatedAt
      // This is a bit of a test smell, but DateTime.now() precision can be an issue.
      // A better fix might involve injecting a Clock if this becomes flaky.
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await controller.updateConfig(newConfig);

      final captured =
          verify(() => mockAiConfigRepository.saveConfig(captureAny()))
              .captured;
      expect(captured.length, 1);
      final savedConfig = captured.first as AiConfigPrompt;
      expect(savedConfig.id, 'new-id-on-update');
      expect(
        savedConfig.name,
        newConfig.name,
      ); // check other fields if necessary
      expect(savedConfig.createdAt, fixedCreatedAt);
      expect(savedConfig.updatedAt, isNotNull);
      // Ensure createdAt is not null before calling isAfter
      expect(savedConfig.updatedAt!.isAfter(savedConfig.createdAt), isTrue);
    });

    test('deleteConfig calls repository deleteConfig', () async {
      await container.read(promptFormControllerProvider(configId: null).future);
      final controller =
          container.read(promptFormControllerProvider(configId: null).notifier);
      const idToDelete = 'config-to-delete';
      when(() => mockAiConfigRepository.deleteConfig(idToDelete))
          .thenAnswer((_) async {});

      await controller.deleteConfig(idToDelete);

      verify(() => mockAiConfigRepository.deleteConfig(idToDelete)).called(1);
    });

    test('reset clears controllers and resets state', () async {
      // Setup initial state by loading a config
      when(() => mockAiConfigRepository.getConfigById(testConfigId))
          .thenAnswer((_) async => testConfig);
      await container
          .read(promptFormControllerProvider(configId: testConfigId).future);
      final controller = container
          .read(promptFormControllerProvider(configId: testConfigId).notifier);

      // Verify controllers have text
      expect(controller.nameController.text, testConfig.name);
      expect(controller.systemMessageController.text, testConfig.systemMessage);
      // ... other controllers ...

      controller.reset();

      expect(controller.nameController.text, isEmpty);
      expect(controller.systemMessageController.text, isEmpty);
      expect(controller.userMessageController.text, isEmpty);
      expect(controller.descriptionController.text, isEmpty);

      final state = container
          .read(promptFormControllerProvider(configId: testConfigId))
          .value;
      // Check if state is reset to default PromptFormState
      // This assumes PromptFormState() creates a state with empty/default values.
      final defaultState = PromptFormState();
      expect(state!.name.value, defaultState.name.value);
      expect(state.systemMessage.value, defaultState.systemMessage.value);
      // ... compare other relevant fields to their defaults in PromptFormState ...
      expect(state.id, defaultState.id);
      expect(state.modelIds, defaultState.modelIds);
      expect(state.defaultModelId, defaultState.defaultModelId);
    });
  });
}
