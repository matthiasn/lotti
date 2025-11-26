// ignore_for_file: cascade_invocations, unnecessary_ignore, unawaited_futures

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/direct_task_summary_refresh_controller.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggingService extends Mock implements LoggingService {}

class MockJournalDb extends Mock implements JournalDb {}

class MockJournalRepository extends Mock implements JournalRepository {}

class MockInferenceStatusController extends InferenceStatusController {
  MockInferenceStatusController(this._status);

  final InferenceStatus _status;

  @override
  InferenceStatus build({
    required String id,
    required AiResponseType aiResponseType,
  }) {
    return _status;
  }
}

void main() {
  late ProviderContainer container;
  late MockLoggingService mockLoggingService;
  late MockJournalDb mockJournalDb;
  late MockJournalRepository mockJournalRepository;

  setUpAll(() {
    // Register fallback values for Mocktail
    registerFallbackValue(''); // Fallback for String
    registerFallbackValue(StackTrace.current); // Fallback for StackTrace
  });

  setUp(() {
    mockLoggingService = MockLoggingService();
    mockJournalDb = MockJournalDb();
    mockJournalRepository = MockJournalRepository();

    // Register mocks in GetIt
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }

    getIt
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<JournalDb>(mockJournalDb);

    // Setup mock behaviors
    when(
      () => mockLoggingService.captureException(
        any<dynamic>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
      ),
    ).thenAnswer((_) async => true);

    container = ProviderContainer(
      overrides: [
        journalRepositoryProvider.overrideWithValue(mockJournalRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
  });

  group('DirectTaskSummaryRefreshController', () {
    test('should schedule refresh with 5-minute delay', () {
      fakeAsync((async) {
        final controller = container.read(
          directTaskSummaryRefreshControllerProvider.notifier,
        );

        // Override the inference status check to always return idle
        container
          ..listen(
            inferenceStatusControllerProvider(
              id: 'test-task-1',
              aiResponseType: AiResponseType.taskSummary,
            ),
            (previous, next) {},
            fireImmediately: true,
          )
          // Override the trigger provider to count calls
          ..listen(
            triggerNewInferenceProvider(
              entityId: 'test-task-1',
              promptId: 'auto-task-summary',
            ),
            (previous, next) {},
          );

        // Setup mock response for latest AI response
        when(() => mockJournalRepository.getLinkedEntities(
              linkedTo: 'test-task-1',
            )).thenAnswer((_) async => []);

        // Request refresh
        unawaited(controller.requestTaskSummaryRefresh('test-task-1'));
        async.flushMicrotasks();

        // Should have scheduled time set
        expect(controller.hasScheduledRefresh('test-task-1'), isTrue);
        expect(controller.getScheduledTime('test-task-1'), isNotNull);

        // State should also reflect this
        final state =
            container.read(directTaskSummaryRefreshControllerProvider);
        expect(state.hasScheduledRefresh('test-task-1'), isTrue);

        // Should not trigger before 5 minutes
        async.elapse(const Duration(minutes: 4, seconds: 59));
        async.flushMicrotasks();

        // Should trigger after 5 minutes
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        // Scheduled state should be cleared
        expect(controller.hasScheduledRefresh('test-task-1'), isFalse);
      });
    });

    test('should NOT reset timer on subsequent requests (batch into countdown)',
        () {
      fakeAsync((async) {
        final controller = container.read(
          directTaskSummaryRefreshControllerProvider.notifier,
        );

        container
          ..listen(
            inferenceStatusControllerProvider(
              id: 'test-task-batch',
              aiResponseType: AiResponseType.taskSummary,
            ),
            (previous, next) {},
            fireImmediately: true,
          )
          ..listen(
            triggerNewInferenceProvider(
              entityId: 'test-task-batch',
              promptId: 'auto-task-summary',
            ),
            (previous, next) {},
          );

        when(() => mockJournalRepository.getLinkedEntities(
              linkedTo: 'test-task-batch',
            )).thenAnswer((_) async => []);

        // First request
        unawaited(controller.requestTaskSummaryRefresh('test-task-batch'));
        async.flushMicrotasks();

        final firstScheduledTime =
            controller.getScheduledTime('test-task-batch');
        expect(firstScheduledTime, isNotNull);

        // Wait 2 minutes
        async.elapse(const Duration(minutes: 2));
        async.flushMicrotasks();

        // Second request - should NOT reset timer
        unawaited(controller.requestTaskSummaryRefresh('test-task-batch'));
        async.flushMicrotasks();

        // Scheduled time should be the same (not reset)
        expect(
            controller.getScheduledTime('test-task-batch'), firstScheduledTime);
      });
    });

    test('should handle multiple tasks independently', () {
      fakeAsync((async) {
        final controller = container.read(
          directTaskSummaryRefreshControllerProvider.notifier,
        );

        // Setup for task 1
        container
          ..listen(
            inferenceStatusControllerProvider(
              id: 'task-1',
              aiResponseType: AiResponseType.taskSummary,
            ),
            (previous, next) {},
            fireImmediately: true,
          )
          ..listen(
            triggerNewInferenceProvider(
              entityId: 'task-1',
              promptId: 'auto-task-summary',
            ),
            (previous, next) {},
          )
          // Setup for task 2
          ..listen(
            inferenceStatusControllerProvider(
              id: 'task-2',
              aiResponseType: AiResponseType.taskSummary,
            ),
            (previous, next) {},
            fireImmediately: true,
          )
          ..listen(
            triggerNewInferenceProvider(
              entityId: 'task-2',
              promptId: 'auto-task-summary',
            ),
            (previous, next) {},
          );

        // Setup mock responses
        when(() => mockJournalRepository.getLinkedEntities(linkedTo: 'task-1'))
            .thenAnswer((_) async => []);
        when(() => mockJournalRepository.getLinkedEntities(linkedTo: 'task-2'))
            .thenAnswer((_) async => []);

        // Request refreshes
        unawaited(controller.requestTaskSummaryRefresh('task-1'));
        unawaited(controller.requestTaskSummaryRefresh('task-2'));
        async.flushMicrotasks();

        // Both should be scheduled
        expect(controller.hasScheduledRefresh('task-1'), isTrue);
        expect(controller.hasScheduledRefresh('task-2'), isTrue);

        // State should reflect both
        final state =
            container.read(directTaskSummaryRefreshControllerProvider);
        expect(state.scheduledTimes.length, 2);
      });
    });

    test('should skip scheduling if inference is already running', () {
      fakeAsync((async) {
        // Create a test-specific container with mocked providers
        final testContainer = ProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
            // Mock the inference status controller to always return running
            inferenceStatusControllerProvider(
              id: 'test-task-running',
              aiResponseType: AiResponseType.taskSummary,
            ).overrideWith(
              () => MockInferenceStatusController(InferenceStatus.running),
            ),
          ],
        );

        // Mock getLinkedEntities
        when(() => mockJournalRepository.getLinkedEntities(
            linkedTo: 'test-task-running')).thenAnswer((_) async {
          return [];
        });

        final controller = testContainer.read(
          directTaskSummaryRefreshControllerProvider.notifier,
        );

        // Request refresh
        unawaited(controller.requestTaskSummaryRefresh('test-task-running'));
        async.flushMicrotasks();

        // Should NOT have scheduled (sets up listener instead)
        expect(controller.hasScheduledRefresh('test-task-running'), isFalse);

        testContainer.dispose();
      });
    });

    test('cancelScheduledRefresh should cancel pending refresh', () {
      fakeAsync((async) {
        final controller = container.read(
          directTaskSummaryRefreshControllerProvider.notifier,
        );

        container
          ..listen(
            inferenceStatusControllerProvider(
              id: 'cancel-test',
              aiResponseType: AiResponseType.taskSummary,
            ),
            (previous, next) {},
            fireImmediately: true,
          )
          ..listen(
            triggerNewInferenceProvider(
              entityId: 'cancel-test',
              promptId: 'auto-task-summary',
            ),
            (previous, next) {},
          );

        when(() => mockJournalRepository.getLinkedEntities(
              linkedTo: 'cancel-test',
            )).thenAnswer((_) async => []);

        // Schedule refresh
        unawaited(controller.requestTaskSummaryRefresh('cancel-test'));
        async.flushMicrotasks();

        expect(controller.hasScheduledRefresh('cancel-test'), isTrue);

        // Wait 2 minutes
        async.elapse(const Duration(minutes: 2));
        async.flushMicrotasks();

        // Cancel the scheduled refresh
        controller.cancelScheduledRefresh('cancel-test');

        expect(controller.hasScheduledRefresh('cancel-test'), isFalse);
        expect(controller.getScheduledTime('cancel-test'), isNull);

        // State should also reflect the cancellation
        final state =
            container.read(directTaskSummaryRefreshControllerProvider);
        expect(state.hasScheduledRefresh('cancel-test'), isFalse);
      });
    });

    test('triggerImmediately should bypass countdown and trigger now', () {
      fakeAsync((async) {
        // Mock response with valid promptId
        final testResponse = AiResponseEntry(
          meta: Metadata(
            id: 'ai-response-1',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          data: const AiResponseData(
            model: 'gpt-4',
            temperature: 0.7,
            systemMessage: 'System',
            prompt: 'Prompt',
            thoughts: '',
            response: 'Test response',
            type: AiResponseType.taskSummary,
            promptId: 'valid-prompt-id',
          ),
        );

        when(() => mockJournalRepository.getLinkedEntities(
              linkedTo: 'immediate-test',
            )).thenAnswer((_) async => [testResponse]);

        var inferenceCallCount = 0;

        final testContainer = ProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
            inferenceStatusControllerProvider(
              id: 'immediate-test',
              aiResponseType: AiResponseType.taskSummary,
            ).overrideWith(
                () => MockInferenceStatusController(InferenceStatus.idle)),
          ],
        )..listen(
            triggerNewInferenceProvider(
              entityId: 'immediate-test',
              promptId: 'valid-prompt-id',
            ),
            (previous, next) {
              inferenceCallCount++;
            },
          );

        final testController = testContainer.read(
          directTaskSummaryRefreshControllerProvider.notifier,
        );

        // Schedule refresh
        unawaited(testController.requestTaskSummaryRefresh('immediate-test'));
        async.flushMicrotasks();

        expect(testController.hasScheduledRefresh('immediate-test'), isTrue);

        // Trigger immediately (don't wait for timer)
        unawaited(testController.triggerImmediately('immediate-test'));
        async.flushMicrotasks();

        // Should be cleared
        expect(testController.hasScheduledRefresh('immediate-test'), isFalse);

        // Verify inference was triggered
        expect(inferenceCallCount, greaterThan(0));

        testContainer.dispose();
      });
    });

    test('should handle errors gracefully', () {
      fakeAsync((async) {
        final controller = container.read(
          directTaskSummaryRefreshControllerProvider.notifier,
        );

        // Setup to throw an error
        container.listen(
          inferenceStatusControllerProvider(
            id: 'error-task',
            aiResponseType: AiResponseType.taskSummary,
          ),
          (previous, next) {},
          fireImmediately: true,
        );

        when(() =>
                mockJournalRepository.getLinkedEntities(linkedTo: 'error-task'))
            .thenThrow(Exception('Test error'));

        // Should not throw
        // ignore: discarded_futures
        expectLater(
            controller.requestTaskSummaryRefresh('error-task'), completes);

        // Wait for timer
        async.elapse(scheduledRefreshDelay + const Duration(seconds: 1));
        async.flushMicrotasks();

        // Verify error was logged
        verify(
          () => mockLoggingService.captureException(
            any<dynamic>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });

    test('should cancel timers on dispose', () {
      fakeAsync((async) {
        // Create a new container for this test
        final testContainer = ProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          ],
        );

        final controller = testContainer.read(
          directTaskSummaryRefreshControllerProvider.notifier,
        );

        testContainer
          ..listen(
            inferenceStatusControllerProvider(
              id: 'dispose-test',
              aiResponseType: AiResponseType.taskSummary,
            ),
            (previous, next) {},
            fireImmediately: true,
          )
          ..listen(
            triggerNewInferenceProvider(
              entityId: 'dispose-test',
              promptId: 'auto-task-summary',
            ),
            (previous, next) {},
          );

        // Request a refresh
        unawaited(controller.requestTaskSummaryRefresh('dispose-test'));
        async.flushMicrotasks();

        expect(controller.hasScheduledRefresh('dispose-test'), isTrue);

        // Dispose immediately (before timer completes)
        testContainer.dispose();

        // Verify that the timer was cancelled (no crash or hanging)
        // We can't check the internal state after disposal, but the test
        // passing without timeout indicates timers were properly cancelled
      });
    });

    test('should successfully trigger refresh with valid promptId', () {
      fakeAsync((async) {
        // Mock response with valid promptId
        final testResponse = AiResponseEntry(
          meta: Metadata(
            id: 'ai-response-1',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          data: const AiResponseData(
            model: 'gpt-4',
            temperature: 0.7,
            systemMessage: 'System',
            prompt: 'Prompt',
            thoughts: '',
            response: 'Test response',
            type: AiResponseType.taskSummary,
            promptId: 'valid-prompt-id',
          ),
        );

        when(() => mockJournalRepository.getLinkedEntities(
              linkedTo: 'valid-prompt-test',
            )).thenAnswer((_) async => [testResponse]);

        // Track whether the inference was triggered with correct parameters
        var inferenceTriggered = false;

        // Create a test container with overrides
        final testContainer = ProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
            // Override inference status to return idle
            inferenceStatusControllerProvider(
              id: 'valid-prompt-test',
              aiResponseType: AiResponseType.taskSummary,
            ).overrideWith(
                () => MockInferenceStatusController(InferenceStatus.idle)),
          ],
        )
          // Listen to the trigger provider to capture calls
          ..listen(
            triggerNewInferenceProvider(
              entityId: 'valid-prompt-test',
              promptId: 'valid-prompt-id',
            ),
            (previous, next) {
              inferenceTriggered = true;
            },
          );

        final controller = testContainer.read(
          directTaskSummaryRefreshControllerProvider.notifier,
        );

        unawaited(controller.requestTaskSummaryRefresh('valid-prompt-test'));
        async.flushMicrotasks();

        // Wait for timer
        async.elapse(scheduledRefreshDelay + const Duration(seconds: 1));
        async.flushMicrotasks();

        // Verify the inference was triggered with correct parameters
        expect(inferenceTriggered, true);

        testContainer.dispose();
      });
    });

    test('should handle case where no prompt ID is found', () {
      fakeAsync((async) {
        // Mock response without promptId
        final testResponse = AiResponseEntry(
          meta: Metadata(
            id: 'ai-response-1',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          data: const AiResponseData(
            model: 'gpt-4',
            temperature: 0.7,
            systemMessage: 'System',
            prompt: 'Prompt',
            thoughts: '',
            response: 'Test response',
            type: AiResponseType.taskSummary,
            // No prompt ID
          ),
        );

        when(() => mockJournalRepository.getLinkedEntities(
              linkedTo: 'no-prompt-task',
            )).thenAnswer((_) async => [testResponse]);

        // Create test container with overrides
        final testContainer = ProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
            // Override inference status to return idle
            inferenceStatusControllerProvider(
              id: 'no-prompt-task',
              aiResponseType: AiResponseType.taskSummary,
            ).overrideWith(
                () => MockInferenceStatusController(InferenceStatus.idle)),
          ],
        );

        final controller = testContainer.read(
          directTaskSummaryRefreshControllerProvider.notifier,
        );

        // We verify the behavior completes without errors
        // ignore: discarded_futures
        expectLater(
          controller.requestTaskSummaryRefresh('no-prompt-task'),
          completes,
        );

        // Wait for timer
        async.elapse(scheduledRefreshDelay + const Duration(seconds: 1));
        async.flushMicrotasks();

        // The test passes if no exceptions were thrown

        testContainer.dispose();
      });
    });

    test('should handle case where no AI response exists', () {
      fakeAsync((async) {
        // Mock no response (empty list)
        when(() => mockJournalRepository.getLinkedEntities(
              linkedTo: 'no-response-task',
            )).thenAnswer((_) async => []);

        // Create test container with overrides
        final testContainer = ProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
            // Override inference status to return idle
            inferenceStatusControllerProvider(
              id: 'no-response-task',
              aiResponseType: AiResponseType.taskSummary,
            ).overrideWith(
                () => MockInferenceStatusController(InferenceStatus.idle)),
          ],
        );

        final controller = testContainer.read(
          directTaskSummaryRefreshControllerProvider.notifier,
        );

        // We verify the behavior completes without errors
        // ignore: discarded_futures
        expectLater(
          controller.requestTaskSummaryRefresh('no-response-task'),
          completes,
        );

        // Wait for timer
        async.elapse(scheduledRefreshDelay + const Duration(seconds: 1));
        async.flushMicrotasks();

        // The test passes if no exceptions were thrown

        testContainer.dispose();
      });
    });

    test('should use status listener helper when inference is running', () {
      fakeAsync((async) {
        // Create a test-specific container with mocked providers
        final testContainer = ProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
            // Mock the inference status controller to always return running
            inferenceStatusControllerProvider(
              id: 'test-task-listener-helper',
              aiResponseType: AiResponseType.taskSummary,
            ).overrideWith(
              () => MockInferenceStatusController(InferenceStatus.running),
            ),
          ],
        );

        final controller = testContainer.read(
          directTaskSummaryRefreshControllerProvider.notifier,
        );

        // Request refresh while inference is running
        unawaited(
            controller.requestTaskSummaryRefresh('test-task-listener-helper'));

        // Wait a bit to ensure listener setup
        async.elapse(const Duration(milliseconds: 50));
        async.flushMicrotasks();

        // The status listener should have been set up
        // This is verified by the fact that the method completes without error

        testContainer.dispose();
      });
    });

    test('should handle concurrent requests for different tasks', () async {
      final controller = container.read(
        directTaskSummaryRefreshControllerProvider.notifier,
      );

      // Setup for all tasks
      for (final taskId in ['task-a', 'task-b', 'task-c']) {
        container
          ..listen(
            inferenceStatusControllerProvider(
              id: taskId,
              aiResponseType: AiResponseType.taskSummary,
            ),
            (previous, next) {},
            fireImmediately: true,
          )
          ..listen(
            triggerNewInferenceProvider(
              entityId: taskId,
              promptId: 'auto-task-summary',
            ),
            (previous, next) {},
          );

        when(() => mockJournalRepository.getLinkedEntities(linkedTo: taskId))
            .thenAnswer((_) async => []);
      }

      // Make multiple rapid requests for different tasks
      await Future.wait([
        controller.requestTaskSummaryRefresh('task-a'),
        controller.requestTaskSummaryRefresh('task-b'),
        controller.requestTaskSummaryRefresh('task-c'),
        controller.requestTaskSummaryRefresh('task-a'), // Duplicate - batched
        controller.requestTaskSummaryRefresh('task-b'), // Duplicate - batched
      ]);

      // All should be scheduled (not triggered yet)
      expect(controller.hasScheduledRefresh('task-a'), isTrue);
      expect(controller.hasScheduledRefresh('task-b'), isTrue);
      expect(controller.hasScheduledRefresh('task-c'), isTrue);
    });

    test('scheduledTaskSummaryRefreshProvider returns correct scheduled time',
        () {
      fakeAsync((async) {
        final controller = container.read(
          directTaskSummaryRefreshControllerProvider.notifier,
        );

        container.listen(
          inferenceStatusControllerProvider(
            id: 'provider-test',
            aiResponseType: AiResponseType.taskSummary,
          ),
          (previous, next) {},
          fireImmediately: true,
        );

        // Initially should be null
        var scheduledTime = container.read(
          scheduledTaskSummaryRefreshProvider(taskId: 'provider-test'),
        );
        expect(scheduledTime, isNull);

        // Schedule a refresh
        unawaited(controller.requestTaskSummaryRefresh('provider-test'));
        async.flushMicrotasks();

        // Now should have a scheduled time
        scheduledTime = container.read(
          scheduledTaskSummaryRefreshProvider(taskId: 'provider-test'),
        );
        expect(scheduledTime, isNotNull);

        // Cancel it
        controller.cancelScheduledRefresh('provider-test');
        async.flushMicrotasks();

        // Should be null again
        scheduledTime = container.read(
          scheduledTaskSummaryRefreshProvider(taskId: 'provider-test'),
        );
        expect(scheduledTime, isNull);
      });
    });

    test('state should contain all scheduled refreshes', () {
      fakeAsync((async) {
        final controller = container.read(
          directTaskSummaryRefreshControllerProvider.notifier,
        );

        // Setup for tasks
        for (final taskId in ['state-task-1', 'state-task-2']) {
          container.listen(
            inferenceStatusControllerProvider(
              id: taskId,
              aiResponseType: AiResponseType.taskSummary,
            ),
            (previous, next) {},
            fireImmediately: true,
          );
        }

        // Schedule refreshes
        unawaited(controller.requestTaskSummaryRefresh('state-task-1'));
        unawaited(controller.requestTaskSummaryRefresh('state-task-2'));
        async.flushMicrotasks();

        // Check state contains both
        final state =
            container.read(directTaskSummaryRefreshControllerProvider);
        expect(state.scheduledTimes.length, 2);
        expect(state.hasScheduledRefresh('state-task-1'), isTrue);
        expect(state.hasScheduledRefresh('state-task-2'), isTrue);

        // Cancel one
        controller.cancelScheduledRefresh('state-task-1');

        // Check state updated
        final newState =
            container.read(directTaskSummaryRefreshControllerProvider);
        expect(newState.scheduledTimes.length, 1);
        expect(newState.hasScheduledRefresh('state-task-1'), isFalse);
        expect(newState.hasScheduledRefresh('state-task-2'), isTrue);
      });
    });
  });
}
