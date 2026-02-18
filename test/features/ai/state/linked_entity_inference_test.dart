import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class MockUnifiedAiInferenceRepository extends Mock
    implements UnifiedAiInferenceRepository {}

void main() {
  late MockUnifiedAiInferenceRepository mockRepository;
  late MockLoggingService mockLoggingService;
  late AiConfigPrompt asrPromptConfig;
  late AiConfigPrompt taskSummaryPromptConfig;

  setUpAll(() {
    registerFallbackValue(InferenceStatus.idle);
    registerFallbackValue(StackTrace.current);
    registerFallbackValue(FakeAiConfigPrompt());
  });

  setUp(() {
    mockRepository = MockUnifiedAiInferenceRepository();
    mockLoggingService = MockLoggingService();

    // Set up GetIt
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    getIt.registerSingleton<LoggingService>(mockLoggingService);

    // Mock logging methods
    when(
      () => mockLoggingService.captureEvent(
        any<dynamic>(),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);

    when(
      () => mockLoggingService.captureException(
        any<dynamic>(),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
        stackTrace: any<dynamic>(named: 'stackTrace'),
      ),
    ).thenReturn(null);

    // Set up test prompt configs
    final now = DateTime(2024, 3, 15);
    asrPromptConfig = AiConfig.prompt(
      id: 'asr-prompt',
      name: 'Audio Transcription',
      systemMessage: 'Transcribe audio',
      userMessage: 'Please transcribe this audio',
      defaultModelId: 'whisper-1',
      modelIds: ['whisper-1'],
      createdAt: now,
      useReasoning: false,
      requiredInputData: [InputDataType.audioFiles],
      aiResponseType: AiResponseType.audioTranscription,
      description: 'Transcribes audio to text',
    ) as AiConfigPrompt;

    taskSummaryPromptConfig = AiConfig.prompt(
      id: 'task-summary-prompt',
      name: 'Task Summary',
      systemMessage: 'Summarize task',
      userMessage: 'Please summarize this task',
      defaultModelId: 'gpt-4',
      modelIds: ['gpt-4'],
      createdAt: now,
      useReasoning: false,
      requiredInputData: [InputDataType.task],
      aiResponseType: AiResponseType.taskSummary,
      description: 'Generates task summaries',
    ) as AiConfigPrompt;
  });

  tearDown(() {
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
  });

  group('LinkedEntityId Functionality Tests', () {
    test('linkedEntityId is passed through the inference chain', () {
      fakeAsync((async) {
        // Arrange
        const audioEntryId = 'audio-123';
        const linkedTaskId = 'task-456';
        const asrPromptId = 'asr-prompt';

        final container = ProviderContainer(
          overrides: [
            unifiedAiInferenceRepositoryProvider
                .overrideWithValue(mockRepository),
            aiConfigByIdProvider(asrPromptId).overrideWith(
              (ref) => Future.value(asrPromptConfig),
            ),
          ],
        );

        var capturedEntityId = '';
        var capturedLinkedEntityId = '';
        var inferenceStatusUpdates = 0;

        when(
          () => mockRepository.runInference(
            entityId: any(named: 'entityId'),
            promptConfig: any(named: 'promptConfig'),
            onProgress: any(named: 'onProgress'),
            onStatusChange: any(named: 'onStatusChange'),
            useConversationApproach: any(named: 'useConversationApproach'),
            linkedEntityId: any(named: 'linkedEntityId'),
          ),
        ).thenAnswer((invocation) async {
          capturedEntityId = invocation.namedArguments[#entityId] as String;
          capturedLinkedEntityId =
              (invocation.namedArguments[#linkedEntityId] as String?) ?? '';
          final onStatusChange = invocation.namedArguments[#onStatusChange]
              as void Function(InferenceStatus);

          onStatusChange(InferenceStatus.running);
          onStatusChange(InferenceStatus.idle);
        });

        // Track status updates for linked entity
        container.listen(
          inferenceStatusControllerProvider(
            id: linkedTaskId,
            aiResponseType: AiResponseType.audioTranscription,
          ),
          (previous, next) {
            inferenceStatusUpdates++;
          },
        );

        // Act
        var finished = false;
        container
            .read(
              triggerNewInferenceProvider((
                entityId: audioEntryId,
                promptId: asrPromptId,
                linkedEntityId: linkedTaskId,
              )).future,
            )
            .then((_) => finished = true);

        async.flushMicrotasks();

        // Assert
        expect(finished, isTrue);
        expect(capturedEntityId,
            audioEntryId); // Main entity is used for inference
        expect(capturedLinkedEntityId, linkedTaskId);
        expect(inferenceStatusUpdates,
            greaterThan(0)); // Linked entity received updates

        // Verify logging includes linkedEntityId
        verify(
          () => mockLoggingService.captureEvent(
            any<String>(
              that: contains(
                'Starting unified AI inference for $audioEntryId (prompt: $asrPromptId, linked: $linkedTaskId',
              ),
            ),
            domain: 'UnifiedAiController',
            subDomain: 'runInference',
          ),
        ).called(1);

        container.dispose();
      });
    });

    test('status updates propagate to both main and linked entities', () {
      fakeAsync((async) {
        // Arrange
        const audioEntryId = 'audio-123';
        const linkedTaskId = 'task-456';
        const asrPromptId = 'asr-prompt';

        final container = ProviderContainer(
          overrides: [
            unifiedAiInferenceRepositoryProvider
                .overrideWithValue(mockRepository),
            aiConfigByIdProvider(asrPromptId).overrideWith(
              (ref) => Future.value(asrPromptConfig),
            ),
          ],
        );

        final mainEntityStatuses = <InferenceStatus>[];
        final linkedEntityStatuses = <InferenceStatus>[];

        // Track status changes
        container
          ..listen(
            inferenceStatusControllerProvider(
              id: audioEntryId,
              aiResponseType: AiResponseType.audioTranscription,
            ),
            (previous, next) {
              mainEntityStatuses.add(next);
            },
            fireImmediately: true,
          )
          ..listen(
            inferenceStatusControllerProvider(
              id: linkedTaskId,
              aiResponseType: AiResponseType.audioTranscription,
            ),
            (previous, next) {
              linkedEntityStatuses.add(next);
            },
            fireImmediately: true,
          );

        when(
          () => mockRepository.runInference(
            entityId: any(named: 'entityId'),
            promptConfig: any(named: 'promptConfig'),
            onProgress: any(named: 'onProgress'),
            onStatusChange: any(named: 'onStatusChange'),
            useConversationApproach: any(named: 'useConversationApproach'),
            linkedEntityId: any(named: 'linkedEntityId'),
          ),
        ).thenAnswer((invocation) async {
          final onStatusChange = invocation.namedArguments[#onStatusChange]
              as void Function(InferenceStatus);

          // Simulate the full lifecycle
          onStatusChange(InferenceStatus.running);
          onStatusChange(InferenceStatus.idle);
        });

        // Act: run the provider and drive fake time deterministically
        var finished = false;
        container
            .read(
              triggerNewInferenceProvider((
                entityId: audioEntryId,
                promptId: asrPromptId,
                linkedEntityId: linkedTaskId,
              )).future,
            )
            .then((_) => finished = true);

        async
          ..flushMicrotasks()
          ..elapse(const Duration(milliseconds: 1))
          ..flushMicrotasks();

        // Assert - both entities should have the same status sequence
        expect(mainEntityStatuses, contains(InferenceStatus.running));
        expect(mainEntityStatuses, contains(InferenceStatus.idle));
        expect(linkedEntityStatuses, contains(InferenceStatus.running));
        expect(linkedEntityStatuses, contains(InferenceStatus.idle));

        // The sequences should be identical (after initial state)
        final mainSequence = mainEntityStatuses.skip(1).toList();
        final linkedSequence = linkedEntityStatuses.skip(1).toList();
        expect(mainSequence, equals(linkedSequence));

        container.dispose();
        expect(finished, isTrue);
      });
    });

    test('error status propagates to linked entity on failure', () {
      fakeAsync((async) {
        // Arrange
        const audioEntryId = 'audio-123';
        const linkedTaskId = 'task-456';
        const asrPromptId = 'asr-prompt';

        final container = ProviderContainer(
          overrides: [
            unifiedAiInferenceRepositoryProvider
                .overrideWithValue(mockRepository),
            aiConfigByIdProvider(asrPromptId).overrideWith(
              (ref) => Future.value(asrPromptConfig),
            ),
          ],
        );

        var mainEntityErrorStatus = false;
        var linkedEntityErrorStatus = false;

        // Track error status
        container
          ..listen(
            inferenceStatusControllerProvider(
              id: audioEntryId,
              aiResponseType: AiResponseType.audioTranscription,
            ),
            (previous, next) {
              if (next == InferenceStatus.error) {
                mainEntityErrorStatus = true;
              }
            },
          )
          ..listen(
            inferenceStatusControllerProvider(
              id: linkedTaskId,
              aiResponseType: AiResponseType.audioTranscription,
            ),
            (previous, next) {
              if (next == InferenceStatus.error) {
                linkedEntityErrorStatus = true;
              }
            },
          );

        when(
          () => mockRepository.runInference(
            entityId: any(named: 'entityId'),
            promptConfig: any(named: 'promptConfig'),
            onProgress: any(named: 'onProgress'),
            onStatusChange: any(named: 'onStatusChange'),
            useConversationApproach: any(named: 'useConversationApproach'),
            linkedEntityId: any(named: 'linkedEntityId'),
          ),
        ).thenThrow(Exception('Network error'));

        // Act
        container.read(
          triggerNewInferenceProvider((
            entityId: audioEntryId,
            promptId: asrPromptId,
            linkedEntityId: linkedTaskId,
          )).future,
        );

        async.flushMicrotasks();

        // Assert
        expect(mainEntityErrorStatus, true);
        expect(linkedEntityErrorStatus, true);

        container.dispose();
      });
    });
  });

  group('Sequential Inference Execution Tests', () {
    test('ASR completes before task summary begins', () {
      fakeAsync((async) {
        // Arrange
        const audioEntryId = 'audio-123';
        const taskId = 'task-456';
        const asrPromptId = 'asr-prompt';
        const taskSummaryPromptId = 'task-summary-prompt';

        final container = ProviderContainer(
          overrides: [
            unifiedAiInferenceRepositoryProvider
                .overrideWithValue(mockRepository),
            aiConfigByIdProvider(asrPromptId).overrideWith(
              (ref) => Future.value(asrPromptConfig),
            ),
            aiConfigByIdProvider(taskSummaryPromptId).overrideWith(
              (ref) => Future.value(taskSummaryPromptConfig),
            ),
          ],
        );

        final executionOrder = <String>[];

        when(
          () => mockRepository.runInference(
            entityId: any(named: 'entityId'),
            promptConfig: any(named: 'promptConfig'),
            onProgress: any(named: 'onProgress'),
            onStatusChange: any(named: 'onStatusChange'),
            useConversationApproach: any(named: 'useConversationApproach'),
            linkedEntityId: any(named: 'linkedEntityId'),
          ),
        ).thenAnswer((invocation) async {
          final promptConfig =
              invocation.namedArguments[#promptConfig] as AiConfigPrompt;
          final onProgress =
              invocation.namedArguments[#onProgress] as void Function(String);
          final onStatusChange = invocation.namedArguments[#onStatusChange]
              as void Function(InferenceStatus);

          if (promptConfig.aiResponseType ==
              AiResponseType.audioTranscription) {
            executionOrder.add('ASR_START');
            onStatusChange(InferenceStatus.running);
            onProgress('Transcribing audio...');
            onProgress('Transcription complete: "Hello world"');
            onStatusChange(InferenceStatus.idle);
            executionOrder.add('ASR_COMPLETE');
          } else if (promptConfig.aiResponseType ==
              AiResponseType.taskSummary) {
            executionOrder.add('TASK_SUMMARY_START');
            onStatusChange(InferenceStatus.running);
            onProgress('Generating task summary...');
            onProgress('Summary: Task updated with transcription');
            onStatusChange(InferenceStatus.idle);
            executionOrder.add('TASK_SUMMARY_COMPLETE');
          }
        });

        // Act - simulate the sequential flow
        // First, trigger ASR with linked task ID
        container.read(
          triggerNewInferenceProvider((
            entityId: audioEntryId,
            promptId: asrPromptId,
            linkedEntityId: taskId,
          )).future,
        );

        async.flushMicrotasks();

        // Then trigger task summary
        container.read(
          triggerNewInferenceProvider((
            entityId: taskId,
            promptId: taskSummaryPromptId,
            linkedEntityId: null,
          )).future,
        );

        async.flushMicrotasks();

        // Assert - verify sequential execution
        expect(executionOrder, [
          'ASR_START',
          'ASR_COMPLETE',
          'TASK_SUMMARY_START',
          'TASK_SUMMARY_COMPLETE',
        ]);

        // Verify that ASR was called before task summary
        final asrStartIndex = executionOrder.indexOf('ASR_START');
        final asrCompleteIndex = executionOrder.indexOf('ASR_COMPLETE');
        final taskSummaryStartIndex =
            executionOrder.indexOf('TASK_SUMMARY_START');

        expect(asrStartIndex, lessThan(asrCompleteIndex));
        expect(asrCompleteIndex, lessThan(taskSummaryStartIndex));

        container.dispose();
      });
    });

    test('task summary waits for ASR to complete before starting', () {
      fakeAsync((async) {
        // Arrange
        const audioEntryId = 'audio-123';
        const taskId = 'task-456';
        const asrPromptId = 'asr-prompt';
        const taskSummaryPromptId = 'task-summary-prompt';

        final container = ProviderContainer(
          overrides: [
            unifiedAiInferenceRepositoryProvider
                .overrideWithValue(mockRepository),
            aiConfigByIdProvider(asrPromptId).overrideWith(
              (ref) => Future.value(asrPromptConfig),
            ),
            aiConfigByIdProvider(taskSummaryPromptId).overrideWith(
              (ref) => Future.value(taskSummaryPromptConfig),
            ),
          ],
        );

        final executionOrder = <String>[];

        when(
          () => mockRepository.runInference(
            entityId: any(named: 'entityId'),
            promptConfig: any(named: 'promptConfig'),
            onProgress: any(named: 'onProgress'),
            onStatusChange: any(named: 'onStatusChange'),
            useConversationApproach: any(named: 'useConversationApproach'),
            linkedEntityId: any(named: 'linkedEntityId'),
          ),
        ).thenAnswer((invocation) async {
          final promptConfig =
              invocation.namedArguments[#promptConfig] as AiConfigPrompt;
          final onStatusChange = invocation.namedArguments[#onStatusChange]
              as void Function(InferenceStatus);

          if (promptConfig.aiResponseType ==
              AiResponseType.audioTranscription) {
            executionOrder.add('ASR_START');
            onStatusChange(InferenceStatus.running);
            onStatusChange(InferenceStatus.idle);
            executionOrder.add('ASR_END');
          } else if (promptConfig.aiResponseType ==
              AiResponseType.taskSummary) {
            executionOrder.add('TASK_SUMMARY_START');
            onStatusChange(InferenceStatus.running);
            onStatusChange(InferenceStatus.idle);
            executionOrder.add('TASK_SUMMARY_END');
          }
        });

        // Act
        // Start ASR
        var asrDone = false;
        container
            .read(
              triggerNewInferenceProvider((
                entityId: audioEntryId,
                promptId: asrPromptId,
                linkedEntityId: taskId,
              )).future,
            )
            .then((_) => asrDone = true);

        async.flushMicrotasks();
        expect(asrDone, isTrue);

        // Then start task summary
        var taskSummaryDone = false;
        container
            .read(
              triggerNewInferenceProvider((
                entityId: taskId,
                promptId: taskSummaryPromptId,
                linkedEntityId: null,
              )).future,
            )
            .then((_) => taskSummaryDone = true);

        async.flushMicrotasks();
        expect(taskSummaryDone, isTrue);

        // Assert - task summary should start after ASR ends
        expect(executionOrder, [
          'ASR_START',
          'ASR_END',
          'TASK_SUMMARY_START',
          'TASK_SUMMARY_END',
        ]);

        // Verify ordering
        final asrEndIndex = executionOrder.indexOf('ASR_END');
        final taskSummaryStartIndex =
            executionOrder.indexOf('TASK_SUMMARY_START');
        expect(
          asrEndIndex,
          lessThan(taskSummaryStartIndex),
          reason: 'Task summary should start after ASR completes',
        );

        container.dispose();
      });
    });

    test('linked entity shows both ASR and task summary animations', () {
      fakeAsync((async) {
        // Arrange
        const audioEntryId = 'audio-123';
        const taskId = 'task-456';
        const asrPromptId = 'asr-prompt';
        const taskSummaryPromptId = 'task-summary-prompt';

        final container = ProviderContainer(
          overrides: [
            unifiedAiInferenceRepositoryProvider
                .overrideWithValue(mockRepository),
            aiConfigByIdProvider(asrPromptId).overrideWith(
              (ref) => Future.value(asrPromptConfig),
            ),
            aiConfigByIdProvider(taskSummaryPromptId).overrideWith(
              (ref) => Future.value(taskSummaryPromptConfig),
            ),
          ],
        );

        final taskEntityStatuses = <Map<String, dynamic>>[];

        // Track status changes for the task entity for both response types
        container
          ..listen(
            inferenceStatusControllerProvider(
              id: taskId,
              aiResponseType: AiResponseType.audioTranscription,
            ),
            (previous, next) {
              taskEntityStatuses.add({
                'type': 'ASR',
                'status': next,
              });
            },
          )
          ..listen(
            inferenceStatusControllerProvider(
              id: taskId,
              aiResponseType: AiResponseType.taskSummary,
            ),
            (previous, next) {
              taskEntityStatuses.add({
                'type': 'TaskSummary',
                'status': next,
              });
            },
          );

        when(
          () => mockRepository.runInference(
            entityId: any(named: 'entityId'),
            promptConfig: any(named: 'promptConfig'),
            onProgress: any(named: 'onProgress'),
            onStatusChange: any(named: 'onStatusChange'),
            useConversationApproach: any(named: 'useConversationApproach'),
            linkedEntityId: any(named: 'linkedEntityId'),
          ),
        ).thenAnswer((invocation) async {
          final promptConfig =
              invocation.namedArguments[#promptConfig] as AiConfigPrompt;
          final onStatusChange = invocation.namedArguments[#onStatusChange]
              as void Function(InferenceStatus);

          if (promptConfig.aiResponseType ==
              AiResponseType.audioTranscription) {
            onStatusChange(InferenceStatus.running);
            onStatusChange(InferenceStatus.idle);
          } else if (promptConfig.aiResponseType ==
              AiResponseType.taskSummary) {
            onStatusChange(InferenceStatus.running);
            onStatusChange(InferenceStatus.idle);
          }
        });

        // Act
        // Trigger ASR with linked task
        container.read(
          triggerNewInferenceProvider((
            entityId: audioEntryId,
            promptId: asrPromptId,
            linkedEntityId: taskId,
          )).future,
        );

        async.flushMicrotasks();

        // Trigger task summary
        container.read(
          triggerNewInferenceProvider((
            entityId: taskId,
            promptId: taskSummaryPromptId,
            linkedEntityId: null,
          )).future,
        );

        async.flushMicrotasks();

        // Assert - task entity should have received status updates for both
        // types
        final asrStatuses = taskEntityStatuses
            .where((s) => s['type'] == 'ASR')
            .map((s) => s['status'])
            .toList();
        final taskSummaryStatuses = taskEntityStatuses
            .where((s) => s['type'] == 'TaskSummary')
            .map((s) => s['status'])
            .toList();

        // Should have ASR status updates
        expect(asrStatuses, contains(InferenceStatus.running));
        expect(asrStatuses, contains(InferenceStatus.idle));

        // Should have task summary status updates
        expect(taskSummaryStatuses, contains(InferenceStatus.running));
        expect(taskSummaryStatuses, contains(InferenceStatus.idle));

        container.dispose();
      });
    });
  });
}
