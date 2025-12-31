import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/settings/prompt_form_controller.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

void main() {
  late ProviderContainer container;
  late MockAiConfigRepository mockRepository;

  setUp(() {
    mockRepository = MockAiConfigRepository();
    getIt.registerSingleton<AiConfigRepository>(mockRepository);
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
    getIt.reset();
  });

  group('PromptFormController Preconfigured Tracking', () {
    test('should copy preconfigured prompt values when switching tracking off',
        () async {
      // Create a prompt config that tracks a preconfigured prompt
      final promptConfig = AiConfigPrompt(
        id: 'test-prompt',
        name: 'Test Prompt',
        systemMessage: 'Old system message',
        userMessage: 'Old user message',
        defaultModelId: 'model1',
        modelIds: ['model1'],
        createdAt: DateTime.now(),
        useReasoning: false,
        requiredInputData: [InputDataType.task],
        aiResponseType: AiResponseType.taskSummary,
        trackPreconfigured: true,
        preconfiguredPromptId: 'task_summary',
      );

      when(() => mockRepository.getConfigById('test-prompt'))
          .thenAnswer((_) async => promptConfig);

      // Build the controller
      final controller = container.read(
        promptFormControllerProvider(configId: 'test-prompt').notifier,
      );
      await container
          .read(promptFormControllerProvider(configId: 'test-prompt').future);

      // Get the preconfigured prompt
      final preconfiguredPrompt = preconfiguredPrompts['task_summary']!;

      // Toggle tracking off
      controller.toggleTrackPreconfigured(false);

      // Verify the controllers have the preconfigured values
      expect(controller.systemMessageController.text,
          equals(preconfiguredPrompt.systemMessage));
      expect(controller.userMessageController.text,
          equals(preconfiguredPrompt.userMessage));

      // Verify the form state has the preconfigured values and tracking is off
      final formState = container
          .read(promptFormControllerProvider(configId: 'test-prompt'))
          .value;
      expect(formState?.trackPreconfigured, isFalse);
      expect(formState?.systemMessage.value,
          equals(preconfiguredPrompt.systemMessage));
      expect(formState?.userMessage.value,
          equals(preconfiguredPrompt.userMessage));
    });

    test('should load preconfigured values when tracking is enabled', () async {
      // Create a prompt config that tracks a preconfigured prompt
      final promptConfig = AiConfigPrompt(
        id: 'test-prompt',
        name: 'Test Prompt',
        systemMessage: 'Old system message',
        userMessage: 'Old user message',
        defaultModelId: 'model1',
        modelIds: ['model1'],
        createdAt: DateTime.now(),
        useReasoning: false,
        requiredInputData: [InputDataType.task],
        aiResponseType: AiResponseType.taskSummary,
        trackPreconfigured: true,
        preconfiguredPromptId: 'task_summary',
      );

      when(() => mockRepository.getConfigById('test-prompt'))
          .thenAnswer((_) async => promptConfig);

      // Build the controller
      final controller = container.read(
        promptFormControllerProvider(configId: 'test-prompt').notifier,
      );
      await container
          .read(promptFormControllerProvider(configId: 'test-prompt').future);

      // Get the preconfigured prompt
      final preconfiguredPrompt = preconfiguredPrompts['task_summary']!;

      // Verify the controllers loaded the preconfigured values
      expect(controller.systemMessageController.text,
          equals(preconfiguredPrompt.systemMessage));
      expect(controller.userMessageController.text,
          equals(preconfiguredPrompt.userMessage));
    });

    test('should update values when re-enabling tracking', () async {
      // Create a prompt config that doesn't track initially
      final promptConfig = AiConfigPrompt(
        id: 'test-prompt',
        name: 'Test Prompt',
        systemMessage: 'Custom system message',
        userMessage: 'Custom user message',
        defaultModelId: 'model1',
        modelIds: ['model1'],
        createdAt: DateTime.now(),
        useReasoning: false,
        requiredInputData: [InputDataType.task],
        aiResponseType: AiResponseType.taskSummary,
        preconfiguredPromptId: 'task_summary',
      );

      when(() => mockRepository.getConfigById('test-prompt'))
          .thenAnswer((_) async => promptConfig);

      // Build the controller
      final controller = container.read(
        promptFormControllerProvider(configId: 'test-prompt').notifier,
      );
      await container
          .read(promptFormControllerProvider(configId: 'test-prompt').future);

      // Initially should have custom values
      expect(controller.systemMessageController.text,
          equals('Custom system message'));
      expect(
          controller.userMessageController.text, equals('Custom user message'));

      // Toggle tracking on
      controller.toggleTrackPreconfigured(true);

      // Get the preconfigured prompt
      final preconfiguredPrompt = preconfiguredPrompts['task_summary']!;

      // Should now have preconfigured values
      expect(controller.systemMessageController.text,
          equals(preconfiguredPrompt.systemMessage));
      expect(controller.userMessageController.text,
          equals(preconfiguredPrompt.userMessage));
    });
  });
}
