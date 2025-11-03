import 'dart:async';

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

class MockUnifiedAiInferenceRepository extends Mock
    implements UnifiedAiInferenceRepository {}

class MockLoggingService extends Mock implements LoggingService {}

class FakeAiConfigPrompt extends Fake implements AiConfigPrompt {}

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
    final now = DateTime.now();
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
    test('linkedEntityId is passed through the inference chain', () async {
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
      var inferenceStatusUpdates = 0;

      when(
        () => mockRepository.runInference(
          entityId: any(named: 'entityId'),
          promptConfig: any(named: 'promptConfig'),
          onProgress: any(named: 'onProgress'),
          onStatusChange: any(named: 'onStatusChange'),
          useConversationApproach: any(named: 'useConversationApproach'),
        ),
      ).thenAnswer((invocation) async {
        capturedEntityId = invocation.namedArguments[#entityId] as String;
        final onStatusChange = invocation.namedArguments[#onStatusChange]
            as void Function(InferenceStatus);

        onStatusChange(InferenceStatus.running);
        await Future<void>.delayed(const Duration(milliseconds: 10));
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
      await container.read(
        triggerNewInferenceProvider(
          entityId: audioEntryId,
          promptId: asrPromptId,
          linkedEntityId: linkedTaskId,
        ).future,
      );

      // Assert
      expect(
          capturedEntityId, audioEntryId); // Main entity is used for inference
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

    test('status updates propagate to both main and linked entities', () async {
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
        ),
      ).thenAnswer((invocation) async {
        final onStatusChange = invocation.namedArguments[#onStatusChange]
            as void Function(InferenceStatus);

        // Simulate the full lifecycle
        onStatusChange(InferenceStatus.running);
        onStatusChange(InferenceStatus.idle);
      });

      // Act
      await container.read(
        triggerNewInferenceProvider(
          entityId: audioEntryId,
          promptId: asrPromptId,
          linkedEntityId: linkedTaskId,
        ).future,
      );
      // Wait deterministically until both entities observed idle
      final done = Completer<void>();
      final timer = Timer.periodic(const Duration(milliseconds: 1), (t) {
        if (mainEntityStatuses.contains(InferenceStatus.idle) &&
            linkedEntityStatuses.contains(InferenceStatus.idle)) {
          t.cancel();
          if (!done.isCompleted) done.complete();
        }
      });
      try {
        await done.future.timeout(const Duration(seconds: 1));
      } on TimeoutException {
        fail('Timed out waiting for both entities to reach idle status');
      } finally {
        timer.cancel();
      }

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
    });

    test('error status propagates to linked entity on failure', () async {
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
        ),
      ).thenThrow(Exception('Network error'));

      // Act
      await container.read(
        triggerNewInferenceProvider(
          entityId: audioEntryId,
          promptId: asrPromptId,
          linkedEntityId: linkedTaskId,
        ).future,
      );

      await Future<void>(() {});

      // Assert
      expect(mainEntityErrorStatus, true);
      expect(linkedEntityErrorStatus, true);

      container.dispose();
    });
  });

  group('Sequential Inference Execution Tests', () {
    test('ASR completes before task summary begins', () async {
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
      final asrCompleter = Completer<void>();

      when(
        () => mockRepository.runInference(
          entityId: any(named: 'entityId'),
          promptConfig: any(named: 'promptConfig'),
          onProgress: any(named: 'onProgress'),
          onStatusChange: any(named: 'onStatusChange'),
          useConversationApproach: any(named: 'useConversationApproach'),
        ),
      ).thenAnswer((invocation) async {
        final promptConfig =
            invocation.namedArguments[#promptConfig] as AiConfigPrompt;
        final onProgress =
            invocation.namedArguments[#onProgress] as void Function(String);
        final onStatusChange = invocation.namedArguments[#onStatusChange]
            as void Function(InferenceStatus);

        if (promptConfig.aiResponseType == AiResponseType.audioTranscription) {
          executionOrder.add('ASR_START');
          onStatusChange(InferenceStatus.running);
          onProgress('Transcribing audio...');
          await Future<void>(() {});
          onProgress('Transcription complete: "Hello world"');
          onStatusChange(InferenceStatus.idle);
          executionOrder.add('ASR_COMPLETE');
          asrCompleter.complete();
        } else if (promptConfig.aiResponseType == AiResponseType.taskSummary) {
          executionOrder.add('TASK_SUMMARY_START');
          onStatusChange(InferenceStatus.running);
          onProgress('Generating task summary...');
          await Future<void>.delayed(const Duration(milliseconds: 50));
          onProgress('Summary: Task updated with transcription');
          onStatusChange(InferenceStatus.idle);
          executionOrder.add('TASK_SUMMARY_COMPLETE');
        }
      });

      // Act - simulate the sequential flow
      // First, trigger ASR with linked task ID
      await container.read(
        triggerNewInferenceProvider(
          entityId: audioEntryId,
          promptId: asrPromptId,
          linkedEntityId: taskId,
        ).future,
      );

      // Wait for ASR to complete
      await asrCompleter.future;

      // Then trigger task summary
      await container.read(
        triggerNewInferenceProvider(
          entityId: taskId,
          promptId: taskSummaryPromptId,
        ).future,
      );

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

    test('task summary waits for ASR to complete before starting', () async {
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

      final timestamps = <String, DateTime>{};
      final asrCompleter = Completer<void>();

      when(
        () => mockRepository.runInference(
          entityId: any(named: 'entityId'),
          promptConfig: any(named: 'promptConfig'),
          onProgress: any(named: 'onProgress'),
          onStatusChange: any(named: 'onStatusChange'),
          useConversationApproach: any(named: 'useConversationApproach'),
        ),
      ).thenAnswer((invocation) async {
        final promptConfig =
            invocation.namedArguments[#promptConfig] as AiConfigPrompt;
        final onStatusChange = invocation.namedArguments[#onStatusChange]
            as void Function(InferenceStatus);

        if (promptConfig.aiResponseType == AiResponseType.audioTranscription) {
          timestamps['ASR_START'] = DateTime.now();
          onStatusChange(InferenceStatus.running);
          // Simulate longer ASR processing
          await Future<void>.delayed(const Duration(milliseconds: 100));
          onStatusChange(InferenceStatus.idle);
          timestamps['ASR_END'] = DateTime.now();
          asrCompleter.complete();
        } else if (promptConfig.aiResponseType == AiResponseType.taskSummary) {
          timestamps['TASK_SUMMARY_START'] = DateTime.now();
          onStatusChange(InferenceStatus.running);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          onStatusChange(InferenceStatus.idle);
          timestamps['TASK_SUMMARY_END'] = DateTime.now();
        }
      });

      // Act
      // Start ASR
      final asrFuture = container.read(
        triggerNewInferenceProvider(
          entityId: audioEntryId,
          promptId: asrPromptId,
          linkedEntityId: taskId,
        ).future,
      );

      // Wait for ASR to complete
      await asrFuture;
      await asrCompleter.future;

      // Then start task summary
      await container.read(
        triggerNewInferenceProvider(
          entityId: taskId,
          promptId: taskSummaryPromptId,
        ).future,
      );

      // Assert - task summary should start after ASR ends
      expect(timestamps['ASR_START'], isNotNull);
      expect(timestamps['ASR_END'], isNotNull);
      expect(timestamps['TASK_SUMMARY_START'], isNotNull);
      expect(timestamps['TASK_SUMMARY_END'], isNotNull);

      // Task summary should start after ASR ends
      expect(
        timestamps['TASK_SUMMARY_START']!.isAfter(timestamps['ASR_END']!),
        true,
        reason: 'Task summary should start after ASR completes',
      );

      container.dispose();
    });

    test('linked entity shows both ASR and task summary animations', () async {
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
      final asrCompleter = Completer<void>();

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
              'time': DateTime.now(),
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
              'time': DateTime.now(),
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
        ),
      ).thenAnswer((invocation) async {
        final promptConfig =
            invocation.namedArguments[#promptConfig] as AiConfigPrompt;
        final onStatusChange = invocation.namedArguments[#onStatusChange]
            as void Function(InferenceStatus);

        if (promptConfig.aiResponseType == AiResponseType.audioTranscription) {
          onStatusChange(InferenceStatus.running);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          onStatusChange(InferenceStatus.idle);
          asrCompleter.complete();
        } else if (promptConfig.aiResponseType == AiResponseType.taskSummary) {
          onStatusChange(InferenceStatus.running);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          onStatusChange(InferenceStatus.idle);
        }
      });

      // Act
      // Trigger ASR with linked task
      await container.read(
        triggerNewInferenceProvider(
          entityId: audioEntryId,
          promptId: asrPromptId,
          linkedEntityId: taskId,
        ).future,
      );

      await asrCompleter.future;

      // Trigger task summary
      await container.read(
        triggerNewInferenceProvider(
          entityId: taskId,
          promptId: taskSummaryPromptId,
        ).future,
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Assert - task entity should have received status updates for both types
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
}
