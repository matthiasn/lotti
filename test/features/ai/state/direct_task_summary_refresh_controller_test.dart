import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/direct_task_summary_refresh_controller.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/latest_summary_controller.dart';
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

class MockLatestSummaryController extends LatestSummaryController {
  MockLatestSummaryController(this._response);

  final AiResponseEntry? _response;

  @override
  Future<AiResponseEntry?> build({
    required String id,
    required AiResponseType aiResponseType,
  }) async {
    return _response;
  }

  @override
  void listen() {
    // Mock implementation - don't listen to actual updates
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
    test('should debounce multiple refresh requests', () async {
      final controller = container.read(
        directTaskSummaryRefreshControllerProvider.notifier,
      );

      var inferenceCallCount = 0;

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
          (previous, next) {
            inferenceCallCount++;
          },
        );

      // Setup mock response for latest AI response
      when(() => mockJournalRepository.getLinkedEntities(
            linkedTo: 'test-task-1',
          )).thenAnswer((_) async => []);

      // Make multiple rapid requests
      await controller.requestTaskSummaryRefresh('test-task-1');
      await controller.requestTaskSummaryRefresh('test-task-1');
      await controller.requestTaskSummaryRefresh('test-task-1');

      // Wait for debounce
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // Should only trigger once due to debouncing
      expect(inferenceCallCount, 1);
    });

    test('should handle multiple tasks independently', () async {
      final controller = container.read(
        directTaskSummaryRefreshControllerProvider.notifier,
      );

      final task1Calls = <String>[];
      final task2Calls = <String>[];

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
          (previous, next) {
            task1Calls.add('triggered');
          },
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
          (previous, next) {
            task2Calls.add('triggered');
          },
        );

      // Setup mock responses
      when(() => mockJournalRepository.getLinkedEntities(linkedTo: 'task-1'))
          .thenAnswer((_) async => []);
      when(() => mockJournalRepository.getLinkedEntities(linkedTo: 'task-2'))
          .thenAnswer((_) async => []);

      // Request refreshes
      await controller.requestTaskSummaryRefresh('task-1');
      await controller.requestTaskSummaryRefresh('task-2');

      // Wait for debounce
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // Both should be triggered independently
      expect(task1Calls.length, 1);
      expect(task2Calls.length, 1);
    });

    test('should skip refresh if inference is already running', () async {
      var triggerCalled = false;
      var getLinkedCalled = false;

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
          // Override the trigger provider to track calls
          triggerNewInferenceProvider(
            entityId: 'test-task-running',
            promptId: 'auto-task-summary',
          ).overrideWith((ref) async {
            triggerCalled = true;
          }),
        ],
      );

      // Mock getLinkedEntities
      when(() => mockJournalRepository.getLinkedEntities(
          linkedTo: 'test-task-running')).thenAnswer((_) async {
        getLinkedCalled = true;
        return [];
      });

      final controller = testContainer.read(
        directTaskSummaryRefreshControllerProvider.notifier,
      );

      // Request refresh
      await controller.requestTaskSummaryRefresh('test-task-running');

      // Wait for debounce to complete
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // When inference is already running:
      // - Should NOT trigger new inference
      // - Should NOT get linked entities (because it returns early)
      expect(triggerCalled, false);
      expect(getLinkedCalled, false);

      testContainer.dispose();
    });

    test('should handle pending refreshes correctly', () async {
      final controller = container.read(
        directTaskSummaryRefreshControllerProvider.notifier,
      );

      final callTimes = <DateTime>[];
      var isRunning = false;

      // Setup mock that simulates a longer running inference
      container
        ..listen(
          inferenceStatusControllerProvider(
            id: 'test-task',
            aiResponseType: AiResponseType.taskSummary,
          ),
          (previous, next) {},
          fireImmediately: true,
        )
        ..listen(
          triggerNewInferenceProvider(
            entityId: 'test-task',
            promptId: 'auto-task-summary',
          ),
          (previous, next) {
            if (!isRunning) {
              callTimes.add(DateTime.now());
              isRunning = true;
              // Simulate inference taking time
              Future<void>.delayed(const Duration(milliseconds: 300), () {
                isRunning = false;
              });
            }
          },
        );

      when(() => mockJournalRepository.getLinkedEntities(linkedTo: 'test-task'))
          .thenAnswer((_) async => []);

      // First request
      await controller.requestTaskSummaryRefresh('test-task');

      // Wait for first to start
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // Second request while first is "running"
      await controller.requestTaskSummaryRefresh('test-task');

      // Wait for everything to complete
      await Future<void>.delayed(const Duration(milliseconds: 1000));

      // Should have been called at least once
      expect(callTimes.length, greaterThanOrEqualTo(1));
    });

    test('should handle errors gracefully', () async {
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
      await expectLater(
        controller.requestTaskSummaryRefresh('error-task'),
        completes,
      );

      // Wait for debounce
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // Verify error was logged
      verify(
        () => mockLoggingService.captureException(
          any<dynamic>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).called(greaterThanOrEqualTo(1));
    });

    test('should cancel timers on dispose', () async {
      // Create a new container for this test
      final testContainer = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
        ],
      );

      final controller = testContainer.read(
        directTaskSummaryRefreshControllerProvider.notifier,
      );

      var inferenceCallCount = 0;

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
          (previous, next) {
            inferenceCallCount++;
          },
        );

      // Request a refresh
      await controller.requestTaskSummaryRefresh('dispose-test');

      // Dispose immediately (before debounce completes)
      testContainer.dispose();

      // Wait for what would have been the debounce period
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // Should not have triggered due to disposal
      expect(inferenceCallCount, 0);
    });

    test('should get latest AI response with correct prompt ID', () async {
      final controller = container.read(
        directTaskSummaryRefreshControllerProvider.notifier,
      );

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
          promptId: 'auto-task-summary',
        ),
      );

      when(() => mockJournalRepository.getLinkedEntities(
            linkedTo: 'test-task-with-response',
          )).thenAnswer((_) async => [testResponse]);

      container.listen(
        inferenceStatusControllerProvider(
          id: 'test-task-with-response',
          aiResponseType: AiResponseType.taskSummary,
        ),
        (previous, next) {},
        fireImmediately: true,
      );

      var triggerCalled = false;
      container.listen(
        triggerNewInferenceProvider(
          entityId: 'test-task-with-response',
          promptId: 'auto-task-summary',
        ),
        (previous, next) {
          triggerCalled = true;
        },
      );

      await controller.requestTaskSummaryRefresh('test-task-with-response');

      // Wait for debounce
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // Should have triggered with the correct prompt ID
      expect(triggerCalled, true);
    });

    test('should handle listener when inference is already running', () async {
      final testContainer = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          inferenceStatusControllerProvider(
            id: 'test-task-listener',
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(
            () => MockInferenceStatusController(InferenceStatus.running),
          ),
        ],
      );

      final controller = testContainer.read(
        directTaskSummaryRefreshControllerProvider.notifier,
      );

      // Request refresh while inference is running - should set up listener
      await expectLater(
        controller.requestTaskSummaryRefresh('test-task-listener'),
        completes,
      );

      testContainer.dispose();
    });

    test('should clean up listeners on dispose', () async {
      // Create a test-specific container
      final testContainer = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          inferenceStatusControllerProvider(
            id: 'test-cleanup',
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(
            () => MockInferenceStatusController(InferenceStatus.running),
          ),
        ],
      );

      final controller = testContainer.read(
        directTaskSummaryRefreshControllerProvider.notifier,
      );

      // Request refresh to set up listener
      await controller.requestTaskSummaryRefresh('test-cleanup');

      // Dispose the container (which should clean up listeners)
      testContainer.dispose();

      // Test passes if no exceptions are thrown during cleanup
    });

    test('should handle listener cleanup for multiple tasks', () async {
      final testContainer = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          inferenceStatusControllerProvider(
            id: 'task-1',
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(
            () => MockInferenceStatusController(InferenceStatus.running),
          ),
          inferenceStatusControllerProvider(
            id: 'task-2',
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(
            () => MockInferenceStatusController(InferenceStatus.running),
          ),
          inferenceStatusControllerProvider(
            id: 'task-3',
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(
            () => MockInferenceStatusController(InferenceStatus.running),
          ),
        ],
      );

      final controller = testContainer.read(
        directTaskSummaryRefreshControllerProvider.notifier,
      );

      // Request refresh for multiple tasks
      await controller.requestTaskSummaryRefresh('task-1');
      await controller.requestTaskSummaryRefresh('task-2');
      await controller.requestTaskSummaryRefresh('task-3');

      // Dispose should clean up all listeners
      testContainer.dispose();
    });

    test('should not set up duplicate listeners for same task', () async {
      final testContainer = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          inferenceStatusControllerProvider(
            id: 'duplicate-test',
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(
            () => MockInferenceStatusController(InferenceStatus.running),
          ),
        ],
      );

      final controller = testContainer.read(
        directTaskSummaryRefreshControllerProvider.notifier,
      );

      // Request refresh multiple times while running
      await controller.requestTaskSummaryRefresh('duplicate-test');
      await controller.requestTaskSummaryRefresh('duplicate-test');
      await controller.requestTaskSummaryRefresh('duplicate-test');

      // Test passes if no exceptions are thrown (duplicate listeners would cause issues)
      testContainer.dispose();
    });

    test('should successfully trigger refresh with valid promptId', () async {
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

      // Create a test container with overrides
      final testContainer = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          // Override latestSummaryControllerProvider to return the test response
          latestSummaryControllerProvider(
            id: 'valid-prompt-test',
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(() => MockLatestSummaryController(testResponse)),
          // Override trigger to track calls
          triggerNewInferenceProvider(
            entityId: 'valid-prompt-test',
            promptId: 'valid-prompt-id',
          ).overrideWith((ref) async {
            // This will be called if the correct promptId is used
            return;
          }),
        ],
      );

      final controller = testContainer.read(
        directTaskSummaryRefreshControllerProvider.notifier,
      );

      var triggerCalled = false;

      // Listen to the trigger provider to see if it gets called
      testContainer.listen(
        triggerNewInferenceProvider(
          entityId: 'valid-prompt-test',
          promptId: 'valid-prompt-id',
        ),
        (previous, next) {
          triggerCalled = true;
        },
      );

      await controller.requestTaskSummaryRefresh('valid-prompt-test');

      // Wait for debounce
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // Should have triggered with the correct prompt ID
      expect(triggerCalled, true);

      testContainer.dispose();
    });
  });
}
