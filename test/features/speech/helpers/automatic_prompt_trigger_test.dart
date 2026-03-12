import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/ai/helpers/prompt_capability_filter.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/speech/helpers/automatic_prompt_trigger.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class MockPromptCapabilityFilter extends Mock
    implements PromptCapabilityFilter {}

void main() {
  late MockLoggingService mockLoggingService;
  late MockCategoryRepository mockCategoryRepository;
  late MockAiConfigRepository mockAiConfigRepository;
  late MockPromptCapabilityFilter mockPromptCapabilityFilter;
  late ProviderContainer container;

  // Helper to create a test category with all required fields
  CategoryDefinition createTestCategory({
    required String id,
    required String name,
    Map<AiResponseType, List<String>>? automaticPrompts,
  }) {
    return CategoryDefinition(
      id: id,
      name: name,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      vectorClock: null,
      color: '#FF0000',
      private: false,
      active: true,
      favorite: false,
      automaticPrompts: automaticPrompts,
    );
  }

  setUp(() {
    mockLoggingService = MockLoggingService();
    mockCategoryRepository = MockCategoryRepository();
    mockAiConfigRepository = MockAiConfigRepository();
    mockPromptCapabilityFilter = MockPromptCapabilityFilter();

    // Register mocks with GetIt
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    getIt.registerSingleton<LoggingService>(mockLoggingService);

    // Setup default mock behavior for logging
    when(
      () => mockLoggingService.captureEvent(
        any<String>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenReturn(null);

    when(
      () => mockLoggingService.captureException(
        any<dynamic>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
      ),
    ).thenAnswer((_) async {});

    // Setup default mock behavior for prompt capability filter
    // By default, return the first prompt from any list (simulating all prompts are available)
    when(
      () => mockPromptCapabilityFilter.getFirstAvailablePrompt(any()),
    ).thenAnswer((invocation) async {
      final promptIds = invocation.positionalArguments[0] as List<String>;
      if (promptIds.isEmpty) return null;
      final firstPromptId = promptIds.first;

      // Return a mock AiConfigPrompt for the first prompt
      return AiConfigPrompt(
        id: firstPromptId,
        name: 'Test Prompt',
        defaultModelId: 'test-model',
        modelIds: [],
        systemMessage: 'Test system message',
        userMessage: 'Test user message',
        requiredInputData: [],
        useReasoning: false,
        createdAt: DateTime(2024, 3, 15),
        aiResponseType: AiResponseType.audioTranscription,
      );
    });

    // Create container with overridden providers
    container = ProviderContainer(
      overrides: [
        categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
        aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepository),
        promptCapabilityFilterProvider.overrideWithValue(
          mockPromptCapabilityFilter,
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
  });

  group('AutomaticPromptTrigger', () {
    test('should not trigger when category has no automatic prompts', () async {
      // Arrange
      const categoryId = 'test-category';
      const entryId = 'test-entry';

      final category = createTestCategory(
        id: categoryId,
        name: 'Test Category',
      );

      when(
        () => mockCategoryRepository.getCategoryById(categoryId),
      ).thenAnswer((_) async => category);

      final trigger = container.read(automaticPromptTriggerProvider);

      final state = AudioRecorderState(
        status: AudioRecorderStatus.stopped,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: false,
      );

      // Act
      await trigger.triggerAutomaticPrompts(
        entryId,
        categoryId,
        state,
        isLinkedToTask: false,
      );

      // Assert
      verify(
        () => mockCategoryRepository.getCategoryById(categoryId),
      ).called(1);
      // Should not log any triggering events
      verifyNever(
        () => mockLoggingService.captureEvent(
          any<String>(that: contains('Triggering')),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      );
    });

    test('should not trigger when category is null', () async {
      // Arrange
      const categoryId = 'non-existent';
      const entryId = 'test-entry';

      when(
        () => mockCategoryRepository.getCategoryById(categoryId),
      ).thenAnswer((_) async => null);

      final trigger = container.read(automaticPromptTriggerProvider);

      final state = AudioRecorderState(
        status: AudioRecorderStatus.stopped,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: false,
      );

      // Act
      await trigger.triggerAutomaticPrompts(
        entryId,
        categoryId,
        state,
        isLinkedToTask: false,
      );

      // Assert
      verify(
        () => mockCategoryRepository.getCategoryById(categoryId),
      ).called(1);
      verifyNever(
        () => mockLoggingService.captureEvent(
          any<String>(that: contains('Triggering')),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      );
    });

    test('should handle exceptions gracefully', () async {
      // Arrange
      const categoryId = 'test-category';
      const entryId = 'test-entry';

      when(
        () => mockCategoryRepository.getCategoryById(categoryId),
      ).thenThrow(Exception('Database error'));

      final trigger = container.read(automaticPromptTriggerProvider);

      final state = AudioRecorderState(
        status: AudioRecorderStatus.stopped,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: false,
      );

      // Act - should not throw
      await trigger.triggerAutomaticPrompts(
        entryId,
        categoryId,
        state,
        isLinkedToTask: false,
      );

      // Assert
      verify(
        () => mockLoggingService.captureException(
          any<dynamic>(),
          domain: 'automatic_prompt_trigger',
          subDomain: 'triggerAutomaticPrompts',
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).called(1);
    });

    test(
      'should not trigger transcription when user explicitly disables it',
      () async {
        // Arrange
        const categoryId = 'test-category';
        const entryId = 'test-entry';
        const promptId = 'transcription-prompt';

        final category = createTestCategory(
          id: categoryId,
          name: 'Test Category',
          automaticPrompts: {
            AiResponseType.audioTranscription: [promptId],
          },
        );

        when(
          () => mockCategoryRepository.getCategoryById(categoryId),
        ).thenAnswer((_) async => category);

        final trigger = container.read(automaticPromptTriggerProvider);

        final state = AudioRecorderState(
          status: AudioRecorderStatus.stopped,
          enableSpeechRecognition: false, // User explicitly disabled
          vu: 0,
          dBFS: -60,
          progress: Duration.zero,
          showIndicator: false,
          modalVisible: false,
        );

        // Act
        await trigger.triggerAutomaticPrompts(
          entryId,
          categoryId,
          state,
          isLinkedToTask: false,
        );

        // Assert
        verify(
          () => mockCategoryRepository.getCategoryById(categoryId),
        ).called(1);
        // Should not log triggering event
        verifyNever(
          () => mockLoggingService.captureEvent(
            any<String>(that: contains('Triggering audio transcription')),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        );
      },
    );

    test('should handle empty prompt lists', () async {
      // Arrange
      const categoryId = 'test-category';
      const entryId = 'test-entry';

      final category = createTestCategory(
        id: categoryId,
        name: 'Test Category',
        automaticPrompts: {
          AiResponseType.audioTranscription: [], // Empty list
        },
      );

      when(
        () => mockCategoryRepository.getCategoryById(categoryId),
      ).thenAnswer((_) async => category);

      final trigger = container.read(automaticPromptTriggerProvider);

      final state = AudioRecorderState(
        status: AudioRecorderStatus.stopped,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: false,
      );

      // Act
      await trigger.triggerAutomaticPrompts(
        entryId,
        categoryId,
        state,
        isLinkedToTask: true,
        linkedTaskId: 'task-id',
      );

      // Assert
      verify(
        () => mockCategoryRepository.getCategoryById(categoryId),
      ).called(1);
      // Should not trigger anything for empty lists
      verifyNever(
        () => mockLoggingService.captureEvent(
          any<String>(that: contains('Triggering')),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      );
    });

    group('User preference overrides', () {
      test(
        'should trigger transcription when user preference is true',
        () async {
          // Arrange
          const categoryId = 'test-category';
          const entryId = 'test-entry';
          const promptId = 'transcription-prompt';

          final category = createTestCategory(
            id: categoryId,
            name: 'Test Category',
            automaticPrompts: {
              AiResponseType.audioTranscription: [promptId],
            },
          );

          when(
            () => mockCategoryRepository.getCategoryById(categoryId),
          ).thenAnswer((_) async => category);

          var inferenceTriggered = false;

          final testContainer = ProviderContainer(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(
                mockCategoryRepository,
              ),
              promptCapabilityFilterProvider.overrideWithValue(
                mockPromptCapabilityFilter,
              ),
              triggerNewInferenceProvider((
                entityId: entryId,
                promptId: promptId,
                linkedEntityId: null,
              )).overrideWith((ref) async {
                inferenceTriggered = true;
              }),
            ],
          );

          final trigger = testContainer.read(automaticPromptTriggerProvider);

          final state = AudioRecorderState(
            status: AudioRecorderStatus.stopped,
            enableSpeechRecognition:
                true, // User explicitly wants transcription
            vu: 0,
            dBFS: -60,
            progress: Duration.zero,
            showIndicator: false,
            modalVisible: false,
          );

          // Act
          await trigger.triggerAutomaticPrompts(
            entryId,
            categoryId,
            state,
            isLinkedToTask: false,
          );

          // Assert
          expect(inferenceTriggered, isTrue);

          verify(
            () => mockLoggingService.captureEvent(
              'Triggering audio transcription (user preference: true)',
              domain: 'automatic_prompt_trigger',
              subDomain: 'triggerAutomaticPrompts',
            ),
          ).called(1);

          testContainer.dispose();
        },
      );
    });

    group('Transcription triggering', () {
      test(
        'should trigger transcription when category has it configured',
        () async {
          // Arrange
          const categoryId = 'test-category';
          const entryId = 'test-entry';
          const promptId = 'transcription-prompt';

          final category = createTestCategory(
            id: categoryId,
            name: 'Test Category',
            automaticPrompts: {
              AiResponseType.audioTranscription: [promptId],
            },
          );

          when(
            () => mockCategoryRepository.getCategoryById(categoryId),
          ).thenAnswer((_) async => category);

          var inferenceTriggered = false;
          String? capturedEntityId;
          String? capturedPromptId;

          // Override the triggerNewInferenceProvider for this specific test
          final testContainer = ProviderContainer(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(
                mockCategoryRepository,
              ),
              promptCapabilityFilterProvider.overrideWithValue(
                mockPromptCapabilityFilter,
              ),
              triggerNewInferenceProvider((
                entityId: entryId,
                promptId: promptId,
                linkedEntityId: null,
              )).overrideWith((ref) async {
                inferenceTriggered = true;
                capturedEntityId = entryId;
                capturedPromptId = promptId;
              }),
            ],
          );

          final trigger = testContainer.read(automaticPromptTriggerProvider);

          final state = AudioRecorderState(
            status: AudioRecorderStatus.stopped,
            vu: 0,
            dBFS: -60,
            progress: Duration.zero,
            showIndicator: false,
            modalVisible: false,
          );

          // Act
          await trigger.triggerAutomaticPrompts(
            entryId,
            categoryId,
            state,
            isLinkedToTask: false,
          );

          // Assert
          expect(inferenceTriggered, isTrue);
          expect(capturedEntityId, equals(entryId));
          expect(capturedPromptId, equals(promptId));

          // Also verify logging
          verify(
            () => mockLoggingService.captureEvent(
              'Triggering audio transcription (user preference: null)',
              domain: 'automatic_prompt_trigger',
              subDomain: 'triggerAutomaticPrompts',
            ),
          ).called(1);

          // Clean up
          testContainer.dispose();
        },
      );
    });

    // Platform filtering scenarios
    group('Platform filtering fallback scenarios', () {
      test('logs unavailability when prompt filtered', () async {
        const categoryId = 'test-category';
        const entryId = 'test-entry';

        final category = createTestCategory(
          id: categoryId,
          name: 'Test Category',
          automaticPrompts: {
            AiResponseType.audioTranscription: ['transcription-prompt'],
          },
        );

        when(
          () => mockCategoryRepository.getCategoryById(categoryId),
        ).thenAnswer((_) async => category);

        // Simulate mobile filtering - return null for transcription prompt
        when(
          () => mockPromptCapabilityFilter.getFirstAvailablePrompt(any()),
        ).thenAnswer((_) async => null);

        final trigger = container.read(automaticPromptTriggerProvider);

        final state = AudioRecorderState(
          status: AudioRecorderStatus.stopped,
          enableSpeechRecognition: true,
          vu: 0,
          dBFS: -60,
          progress: Duration.zero,
          showIndicator: false,
          modalVisible: false,
        );

        await trigger.triggerAutomaticPrompts(
          entryId,
          categoryId,
          state,
          isLinkedToTask: false,
        );

        // Verify unavailability was logged
        verify(
          () => mockLoggingService.captureEvent(
            'No available audio transcription prompts for current platform',
            domain: 'automatic_prompt_trigger',
            subDomain: 'triggerAutomaticPrompts',
          ),
        ).called(1);
      });

      test('completes transcription when no subsequent prompts configured', () {
        fakeAsync((async) {
          const categoryId = 'test-category';
          const entryId = 'test-entry';
          const taskId = 'test-task';
          const transcriptionPromptId = 'transcription-prompt-id';

          final category = createTestCategory(
            id: categoryId,
            name: 'Test Category',
            automaticPrompts: {
              AiResponseType.audioTranscription: [transcriptionPromptId],
            },
          );

          when(
            () => mockCategoryRepository.getCategoryById(categoryId),
          ).thenAnswer((_) async => category);

          when(
            () => mockPromptCapabilityFilter.getFirstAvailablePrompt(any()),
          ).thenAnswer((_) async {
            return AiConfigPrompt(
              id: transcriptionPromptId,
              name: 'Transcription',
              defaultModelId: 'test-model',
              modelIds: const [],
              systemMessage: 'Test',
              userMessage: 'Test',
              requiredInputData: const [],
              useReasoning: false,
              createdAt: DateTime(2024, 3, 15),
              aiResponseType: AiResponseType.audioTranscription,
            );
          });

          var transcriptionCompleted = false;
          final testContainer = ProviderContainer(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(
                mockCategoryRepository,
              ),
              promptCapabilityFilterProvider.overrideWithValue(
                mockPromptCapabilityFilter,
              ),
              triggerNewInferenceProvider((
                entityId: entryId,
                promptId: transcriptionPromptId,
                linkedEntityId: taskId,
              )).overrideWith((ref) async {
                transcriptionCompleted = true;
              }),
            ],
          );

          final trigger = testContainer.read(automaticPromptTriggerProvider);

          final state = AudioRecorderState(
            status: AudioRecorderStatus.stopped,
            enableSpeechRecognition: true,
            vu: 0,
            dBFS: -60,
            progress: Duration.zero,
            showIndicator: false,
            modalVisible: false,
          );

          unawaited(
            trigger.triggerAutomaticPrompts(
              entryId,
              categoryId,
              state,
              isLinkedToTask: true,
              linkedTaskId: taskId,
            ),
          );
          async.flushMicrotasks();

          // Should have completed transcription
          expect(transcriptionCompleted, isTrue);

          testContainer.dispose();
        });
      });
    });
  });
}
