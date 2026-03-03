import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/settings/prompt_form_controller.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';

void main() {
  late ProviderContainer container;
  late MockAiConfigRepository mockAiConfigRepository;

  setUpAll(() {
    registerFallbackValue(fallbackAiConfig);
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

  group('PromptFormController - Tracking Functionality', () {
    group('populateFromPreconfiguredPrompt', () {
      test('should populate all fields and enable tracking', () async {
        // Setup
        when(() => mockAiConfigRepository.getConfigById(any()))
            .thenAnswer((_) async => null);

        final controller = container.read(
          promptFormControllerProvider(configId: null).notifier,
        );

        // Wait for controller to initialize
        await container.read(
          promptFormControllerProvider(configId: null).future,
        );

        // Get the checklist updates template
        final template = preconfiguredPrompts['checklist_updates']!;

        // Act
        controller.populateFromPreconfiguredPrompt(template);

        // Assert
        final state = container
            .read(
              promptFormControllerProvider(configId: null),
            )
            .value;

        expect(state, isNotNull);
        expect(state!.name.value, equals(template.name));
        expect(state.systemMessage.value, equals(template.systemMessage));
        expect(state.userMessage.value, equals(template.userMessage));
        expect(state.description.value, equals(template.description));
        expect(state.useReasoning, equals(template.useReasoning));
        expect(state.requiredInputData, equals(template.requiredInputData));
        expect(state.aiResponseType.value, equals(template.aiResponseType));
        expect(state.trackPreconfigured, isTrue);
        expect(state.preconfiguredPromptId, equals('checklist_updates'));

        // Check that text controllers were updated
        expect(controller.nameController.text, equals(template.name));
        expect(
          controller.systemMessageController.text,
          equals(template.systemMessage),
        );
        expect(controller.userMessageController.text,
            equals(template.userMessage));
        expect(controller.descriptionController.text,
            equals(template.description));
      });

      test('should handle template with default variables', () async {
        // Setup
        when(() => mockAiConfigRepository.getConfigById(any()))
            .thenAnswer((_) async => null);

        final controller = container.read(
          promptFormControllerProvider(configId: null).notifier,
        );

        await container.read(
          promptFormControllerProvider(configId: null).future,
        );

        // Create a template with default variables
        const templateWithVars = PreconfiguredPrompt(
          id: 'test_template',
          name: 'Test Template',
          systemMessage: 'System',
          userMessage: 'User',
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.checklistUpdates,
          useReasoning: false,
          description: 'Description',
          defaultVariables: {'key1': 'value1', 'key2': 'value2'},
        );

        // Act
        controller.populateFromPreconfiguredPrompt(templateWithVars);

        // Assert
        final state = container
            .read(
              promptFormControllerProvider(configId: null),
            )
            .value;

        expect(state!.defaultVariables,
            equals({'key1': 'value1', 'key2': 'value2'}));
      });
    });

    group('toggleTrackPreconfigured', () {
      test(
          'should enable tracking and update messages from preconfigured prompt',
          () async {
        // Setup - create a prompt that was created from a template
        const testConfigId = 'test-prompt-id';
        final testConfig = AiConfigPrompt(
          id: testConfigId,
          name: 'Modified Checklist Updates',
          systemMessage: 'Modified system message',
          userMessage: 'Modified user message',
          description: 'Modified description',
          defaultModelId: 'model-1',
          modelIds: ['model-1'],
          createdAt: DateTime(2024, 3, 15),
          useReasoning: false,
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.checklistUpdates,
          preconfiguredPromptId: 'checklist_updates', // But has the ID
        );

        when(() => mockAiConfigRepository.getConfigById(testConfigId))
            .thenAnswer((_) async => testConfig);

        final controller = container.read(
          promptFormControllerProvider(configId: testConfigId).notifier,
        );

        await container.read(
          promptFormControllerProvider(configId: testConfigId).future,
        );

        // Act - enable tracking
        controller.toggleTrackPreconfigured(true);

        // Assert
        final state = container
            .read(
              promptFormControllerProvider(configId: testConfigId),
            )
            .value;

        expect(state!.trackPreconfigured, isTrue);
        expect(state.preconfiguredPromptId, equals('checklist_updates'));

        // Should update messages from the preconfigured prompt
        final template = preconfiguredPrompts['checklist_updates']!;
        expect(state.systemMessage.value, equals(template.systemMessage));
        expect(state.userMessage.value, equals(template.userMessage));

        // Controllers should also be updated
        expect(
          controller.systemMessageController.text,
          equals(template.systemMessage),
        );
        expect(
          controller.userMessageController.text,
          equals(template.userMessage),
        );
      });

      test('should disable tracking but preserve preconfiguredPromptId',
          () async {
        // Setup - create a prompt that is tracking
        const testConfigId = 'test-prompt-id';
        final testConfig = AiConfigPrompt(
          id: testConfigId,
          name: 'Checklist Updates',
          systemMessage: checklistUpdatesPrompt.systemMessage,
          userMessage: checklistUpdatesPrompt.userMessage,
          description: 'Description',
          defaultModelId: 'model-1',
          modelIds: ['model-1'],
          createdAt: DateTime(2024, 3, 15),
          useReasoning: false,
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.checklistUpdates,
          trackPreconfigured: true,
          preconfiguredPromptId: 'checklist_updates',
        );

        when(() => mockAiConfigRepository.getConfigById(testConfigId))
            .thenAnswer((_) async => testConfig);

        final controller = container.read(
          promptFormControllerProvider(configId: testConfigId).notifier,
        );

        await container.read(
          promptFormControllerProvider(configId: testConfigId).future,
        );

        // Act - disable tracking
        controller.toggleTrackPreconfigured(false);

        // Assert
        final state = container
            .read(
              promptFormControllerProvider(configId: testConfigId),
            )
            .value;

        expect(state!.trackPreconfigured, isFalse);
        // preconfiguredPromptId should still be present
        expect(state.preconfiguredPromptId, equals('checklist_updates'));

        // Messages should not change when disabling
        expect(state.systemMessage.value, equals(testConfig.systemMessage));
        expect(state.userMessage.value, equals(testConfig.userMessage));
      });

      test('should handle invalid preconfiguredPromptId gracefully', () async {
        // Setup - create a prompt with invalid ID
        const testConfigId = 'test-prompt-id';
        final testConfig = AiConfigPrompt(
          id: testConfigId,
          name: 'Test Prompt',
          systemMessage: 'System',
          userMessage: 'User',
          description: 'Description',
          defaultModelId: 'model-1',
          modelIds: ['model-1'],
          createdAt: DateTime(2024, 3, 15),
          useReasoning: false,
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.checklistUpdates,
          preconfiguredPromptId: 'invalid_id', // This ID doesn't exist
        );

        when(() => mockAiConfigRepository.getConfigById(testConfigId))
            .thenAnswer((_) async => testConfig);

        final controller = container.read(
          promptFormControllerProvider(configId: testConfigId).notifier,
        );

        await container.read(
          promptFormControllerProvider(configId: testConfigId).future,
        );

        // Act - try to enable tracking
        controller.toggleTrackPreconfigured(true);

        // Assert - should handle gracefully
        final state = container
            .read(
              promptFormControllerProvider(configId: testConfigId),
            )
            .value;

        // Tracking should NOT be enabled since template not found
        expect(state!.trackPreconfigured, isFalse);
        // Messages should remain unchanged since template not found
        expect(state.systemMessage.value, equals('System'));
        expect(state.userMessage.value, equals('User'));
      });

      test('should not affect tracking when preconfiguredPromptId is null',
          () async {
        // Setup - create a prompt without preconfiguredPromptId
        const testConfigId = 'test-prompt-id';
        final testConfig = AiConfigPrompt(
          id: testConfigId,
          name: 'Custom Prompt',
          systemMessage: 'Custom system',
          userMessage: 'Custom user',
          description: 'Description',
          defaultModelId: 'model-1',
          modelIds: ['model-1'],
          createdAt: DateTime(2024, 3, 15),
          useReasoning: false,
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.checklistUpdates,
        );

        when(() => mockAiConfigRepository.getConfigById(testConfigId))
            .thenAnswer((_) async => testConfig);

        final controller = container.read(
          promptFormControllerProvider(configId: testConfigId).notifier,
        );

        await container.read(
          promptFormControllerProvider(configId: testConfigId).future,
        );

        // Act - try to enable tracking
        controller.toggleTrackPreconfigured(true);

        // Assert
        final state = container
            .read(
              promptFormControllerProvider(configId: testConfigId),
            )
            .value;

        // Tracking flag should NOT be updated since preconfiguredPromptId is null
        expect(state!.trackPreconfigured, isFalse);
        // Messages should remain unchanged
        expect(state.systemMessage.value, equals('Custom system'));
        expect(state.userMessage.value, equals('Custom user'));
      });
    });

    group('Form field behavior with tracking', () {
      test('should mark fields as dirty when tracking is disabled', () async {
        // Setup
        const testConfigId = 'test-prompt-id';
        final testConfig = AiConfigPrompt(
          id: testConfigId,
          name: 'Checklist Updates',
          systemMessage: checklistUpdatesPrompt.systemMessage,
          userMessage: checklistUpdatesPrompt.userMessage,
          description: 'Description',
          defaultModelId: 'model-1',
          modelIds: ['model-1'],
          createdAt: DateTime(2024, 3, 15),
          useReasoning: false,
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.checklistUpdates,
          trackPreconfigured: true,
          preconfiguredPromptId: 'checklist_updates',
        );

        when(() => mockAiConfigRepository.getConfigById(testConfigId))
            .thenAnswer((_) async => testConfig);

        final controller = container.read(
          promptFormControllerProvider(configId: testConfigId).notifier,
        );

        await container.read(
          promptFormControllerProvider(configId: testConfigId).future,
        );

        // Disable tracking
        controller
          ..toggleTrackPreconfigured(false)

          // Act - modify fields
          ..systemMessageChanged('New system message')
          ..userMessageChanged('New user message');

        // Assert
        final state = container
            .read(
              promptFormControllerProvider(configId: testConfigId),
            )
            .value;

        expect(state!.systemMessage.isPure, isFalse);
        expect(state.userMessage.isPure, isFalse);
        expect(state.systemMessage.value, equals('New system message'));
        expect(state.userMessage.value, equals('New user message'));
      });
    });

    group('Saving with tracking', () {
      test('should preserve tracking fields when saving', () async {
        // Setup
        when(() => mockAiConfigRepository.getConfigById(any()))
            .thenAnswer((_) async => null);
        when(() => mockAiConfigRepository.saveConfig(any()))
            .thenAnswer((_) async => {});

        final controller = container.read(
          promptFormControllerProvider(configId: null).notifier,
        );

        await container.read(
          promptFormControllerProvider(configId: null).future,
        );

        // Populate from template
        final template = preconfiguredPrompts['checklist_updates']!;
        controller
          ..populateFromPreconfiguredPrompt(template)

          // Set required fields for valid form
          ..defaultModelIdChanged('model-1')
          ..modelIdsChanged(['model-1']);

        // Act - save the config
        final state = container
            .read(
              promptFormControllerProvider(configId: null),
            )
            .value;

        final config = state!.toAiConfig() as AiConfigPrompt;
        await controller.addConfig(config);

        // Assert
        final capturedConfig = verify(
          () => mockAiConfigRepository.saveConfig(captureAny()),
        ).captured.single as AiConfigPrompt;

        expect(capturedConfig.trackPreconfigured, isTrue);
        expect(
            capturedConfig.preconfiguredPromptId, equals('checklist_updates'));
      });

      test('should preserve tracking state when updating existing config',
          () async {
        // Setup
        const testConfigId = 'test-prompt-id';
        final existingConfig = AiConfigPrompt(
          id: testConfigId,
          name: 'Checklist Updates',
          systemMessage: 'System',
          userMessage: 'User',
          description: 'Description',
          defaultModelId: 'model-1',
          modelIds: ['model-1'],
          createdAt: DateTime(2024, 3, 14),
          useReasoning: false,
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.checklistUpdates,
          trackPreconfigured: true,
          preconfiguredPromptId: 'checklist_updates',
        );

        when(() => mockAiConfigRepository.getConfigById(testConfigId))
            .thenAnswer((_) async => existingConfig);
        when(() => mockAiConfigRepository.saveConfig(any()))
            .thenAnswer((_) async => {});

        final controller = container.read(
          promptFormControllerProvider(configId: testConfigId).notifier,
        );

        await container.read(
          promptFormControllerProvider(configId: testConfigId).future,
        );

        // Act - update and save
        controller.nameChanged('Updated Name');
        final state = container
            .read(
              promptFormControllerProvider(configId: testConfigId),
            )
            .value;

        final config = state!.toAiConfig() as AiConfigPrompt;
        await controller.updateConfig(config);

        // Assert
        final capturedConfig = verify(
          () => mockAiConfigRepository.saveConfig(captureAny()),
        ).captured.single as AiConfigPrompt;

        expect(capturedConfig.trackPreconfigured, isTrue);
        expect(
            capturedConfig.preconfiguredPromptId, equals('checklist_updates'));
        expect(capturedConfig.name, equals('Updated Name'));
        expect(capturedConfig.id, equals(testConfigId));
        expect(capturedConfig.createdAt, equals(existingConfig.createdAt));
        expect(capturedConfig.updatedAt, isNotNull);
      });
    });
  });
}
