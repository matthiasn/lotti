import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/latest_summary_controller.dart';
import 'package:lotti/features/ai/state/task_summary_auto_refresh_controller.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggingService extends Mock implements LoggingService {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockJournalRepository extends Mock implements JournalRepository {}

class MockJournalDb extends Mock implements JournalDb {}

class MockInferenceStatusController extends InferenceStatusController {
  MockInferenceStatusController(this._status);

  final InferenceStatus _status;

  @override
  InferenceStatus build({
    required String id,
    required AiResponseType aiResponseType,
  }) =>
      _status;
}

class MockLatestSummaryController extends LatestSummaryController {
  MockLatestSummaryController(this._response);

  final AiResponseEntry? _response;

  @override
  Future<AiResponseEntry?> build({
    required String id,
    required AiResponseType aiResponseType,
  }) async =>
      _response;
}

void main() {
  late MockLoggingService mockLoggingService;
  late MockUpdateNotifications mockUpdateNotifications;
  late MockJournalRepository mockJournalRepository;
  late MockJournalDb mockJournalDb;
  late StreamController<Set<String>> updateStreamController;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(StackTrace.current);
  });

  setUp(() {
    mockLoggingService = MockLoggingService();
    mockUpdateNotifications = MockUpdateNotifications();
    mockJournalRepository = MockJournalRepository();
    mockJournalDb = MockJournalDb();
    updateStreamController = StreamController<Set<String>>.broadcast();

    // Register mocks in GetIt
    getIt
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<JournalDb>(mockJournalDb);

    // Setup mock behaviors
    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => updateStreamController.stream);

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
    ).thenAnswer((_) {});

    container = ProviderContainer(
      overrides: [
        journalRepositoryProvider.overrideWithValue(mockJournalRepository),
      ],
    );
  });

  tearDown(() {
    updateStreamController.close();
    container.dispose();
    getIt.reset();
  });

  group('TaskSummaryAutoRefreshController', () {
    const testTaskId = 'test-task-1';
    const testPromptId = 'prompt-1';
    late AiResponseEntry testAiResponse;

    setUp(() {
      testAiResponse = AiResponseEntry(
        meta: Metadata(
          id: 'ai-response-1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: const AiResponseData(
          model: 'gpt-4',
          systemMessage: 'System message',
          prompt: 'User prompt',
          thoughts: 'Thinking...',
          response: 'Test task summary',
          promptId: testPromptId,
          type: AiResponseType.taskSummary,
          temperature: 0.7,
        ),
      );
    });

    test('should trigger task summary refresh when checklist item is toggled',
        () async {
      // Setup mocks
      const checklistItemId = 'checklist-item-1';
      final checklistItem = ChecklistItem(
        meta: Metadata(
          id: checklistItemId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: const ChecklistItemData(
          title: 'Test item',
          isChecked: true,
          linkedChecklists: [],
        ),
      );

      when(() => mockJournalDb.journalEntityById(checklistItemId))
          .thenAnswer((_) async => checklistItem);

      // Create a completer to track when inference is triggered
      final inferenceCompleter = Completer<void>();

      // Override the triggerNewInferenceProvider to capture calls
      container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          latestSummaryControllerProvider(
            id: testTaskId,
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(() => MockLatestSummaryController(testAiResponse)),
          inferenceStatusControllerProvider(
            id: testTaskId,
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(
              () => MockInferenceStatusController(InferenceStatus.idle)),
          triggerNewInferenceProvider(
            entityId: testTaskId,
            promptId: testPromptId,
          ).overrideWith((ref) async {
            inferenceCompleter.complete();
          }),
        ],
      )

        // Create the controller and keep it alive
        ..listen(
          taskSummaryAutoRefreshControllerProvider(taskId: testTaskId),
          (_, __) {},
        );

      // Allow controller to initialize
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Simulate a checklist item update notification
      // This includes both the task ID and the checklist item ID
      updateStreamController.add({testTaskId, checklistItemId});

      // Wait for the debounce timer (500ms) plus some buffer
      await Future<void>.delayed(const Duration(milliseconds: 700));

      // Verify that inference was triggered
      expect(inferenceCompleter.isCompleted, isTrue);
    });

    test(
        'should not skip when aiResponseNotification is bundled with relevant IDs',
        () async {
      // Setup mocks
      const checklistItemId = 'checklist-item-bundled';
      final checklistItem = ChecklistItem(
        meta: Metadata(
          id: checklistItemId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: const ChecklistItemData(
          title: 'Bundled item',
          isChecked: true,
          linkedChecklists: [],
        ),
      );
      when(() => mockJournalDb.journalEntityById(checklistItemId))
          .thenAnswer((_) async => checklistItem);

      final inferenceCompleter = Completer<void>();

      container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          latestSummaryControllerProvider(
            id: testTaskId,
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(() => MockLatestSummaryController(testAiResponse)),
          inferenceStatusControllerProvider(
            id: testTaskId,
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(
              () => MockInferenceStatusController(InferenceStatus.idle)),
          triggerNewInferenceProvider(
            entityId: testTaskId,
            promptId: testPromptId,
          ).overrideWith((ref) async {
            inferenceCompleter.complete();
          }),
        ],
      )..listen(
          taskSummaryAutoRefreshControllerProvider(taskId: testTaskId),
          (_, __) {},
        );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Emit a bundled notification including aiResponseNotification
      updateStreamController
          .add({aiResponseNotification, testTaskId, checklistItemId});

      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(inferenceCompleter.isCompleted, isTrue);
    });

    test('should debounce multiple rapid updates', () async {
      // Setup mocks
      const checklistItemId = 'checklist-item-1';
      final checklistItem = ChecklistItem(
        meta: Metadata(
          id: checklistItemId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: const ChecklistItemData(
          title: 'Test item',
          isChecked: true,
          linkedChecklists: [],
        ),
      );

      when(() => mockJournalDb.journalEntityById(checklistItemId))
          .thenAnswer((_) async => checklistItem);

      // Track inference calls
      var inferenceCallCount = 0;

      // Override the triggerNewInferenceProvider to count calls
      container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          latestSummaryControllerProvider(
            id: testTaskId,
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(() => MockLatestSummaryController(testAiResponse)),
          inferenceStatusControllerProvider(
            id: testTaskId,
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(
              () => MockInferenceStatusController(InferenceStatus.idle)),
          triggerNewInferenceProvider(
            entityId: testTaskId,
            promptId: testPromptId,
          ).overrideWith((ref) async {
            inferenceCallCount++;
          }),
        ],
      )

        // Create the controller and keep it alive
        ..listen(
          taskSummaryAutoRefreshControllerProvider(taskId: testTaskId),
          (_, __) {},
        );

      // Allow controller to initialize
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Simulate multiple rapid checklist item updates
      for (var i = 0; i < 5; i++) {
        updateStreamController.add({testTaskId, checklistItemId});
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      // Wait for the debounce timer to complete
      await Future<void>.delayed(const Duration(milliseconds: 700));

      // Verify that inference was only triggered once
      expect(inferenceCallCount, equals(1));
    });

    test(
        'should not trigger immediate refresh when inference is already running',
        () async {
      // Setup mocks
      const checklistItemId = 'checklist-item-1';
      final checklistItem = ChecklistItem(
        meta: Metadata(
          id: checklistItemId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: const ChecklistItemData(
          title: 'Test item',
          isChecked: true,
          linkedChecklists: [],
        ),
      );

      when(() => mockJournalDb.journalEntityById(checklistItemId))
          .thenAnswer((_) async => checklistItem);

      // Track inference calls
      var inferenceCallCount = 0;

      // Override providers
      container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          latestSummaryControllerProvider(
            id: testTaskId,
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(() => MockLatestSummaryController(testAiResponse)),
          // Mock the inference status controller to always return running
          inferenceStatusControllerProvider(
            id: testTaskId,
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(
              () => MockInferenceStatusController(InferenceStatus.running)),
          triggerNewInferenceProvider(
            entityId: testTaskId,
            promptId: testPromptId,
          ).overrideWith((ref) async {
            inferenceCallCount++;
          }),
        ],
      )

        // Create the controller and keep it alive
        ..listen(
          taskSummaryAutoRefreshControllerProvider(taskId: testTaskId),
          (_, __) {},
        );

      // Allow controller to initialize
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Simulate a checklist item update notification
      updateStreamController.add({testTaskId, checklistItemId});

      // Wait for the debounce timer
      await Future<void>.delayed(const Duration(milliseconds: 700));

      // Verify that inference was not triggered
      expect(inferenceCallCount, equals(0));
    });

    test('should not trigger refresh when no AI response exists', () async {
      // Setup mocks
      const checklistItemId = 'checklist-item-1';
      final checklistItem = ChecklistItem(
        meta: Metadata(
          id: checklistItemId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: const ChecklistItemData(
          title: 'Test item',
          isChecked: true,
          linkedChecklists: [],
        ),
      );

      when(() => mockJournalDb.journalEntityById(checklistItemId))
          .thenAnswer((_) async => checklistItem);

      // Track inference calls
      var inferenceCallCount = 0;

      // Override the triggerNewInferenceProvider to count calls
      container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          latestSummaryControllerProvider(
            id: testTaskId,
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(() => MockLatestSummaryController(null)),
          triggerNewInferenceProvider(
            entityId: testTaskId,
            promptId: testPromptId,
          ).overrideWith((ref) async {
            inferenceCallCount++;
          }),
        ],
      )

        // Create the controller and keep it alive
        ..listen(
          taskSummaryAutoRefreshControllerProvider(taskId: testTaskId),
          (_, __) {},
        );

      // Allow controller to initialize
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Simulate a checklist item update notification
      updateStreamController.add({testTaskId, checklistItemId});

      // Wait for the debounce timer
      await Future<void>.delayed(const Duration(milliseconds: 700));

      // Verify that inference was not triggered
      expect(inferenceCallCount, equals(0));
    });

    test('should trigger refresh when checklist is updated (item removed)',
        () async {
      // This simulates what actually happens when a checklist item is deleted:
      // 1. The item is marked as deleted
      // 2. The checklist's unlinkItem is called, updating the checklist
      // 3. The checklist update notification includes the checklist ID and task ID

      // Setup mocks
      const checklistId = 'checklist-1';

      final checklist = Checklist(
        meta: Metadata(
          id: checklistId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: const ChecklistData(
          title: 'Test checklist',
          linkedChecklistItems: [], // Item was removed
          linkedTasks: [testTaskId],
        ),
      );

      when(() => mockJournalDb.journalEntityById(checklistId))
          .thenAnswer((_) async => checklist);

      // Create a completer to track when inference is triggered
      final inferenceCompleter = Completer<void>();

      // Override the triggerNewInferenceProvider to capture calls
      container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          latestSummaryControllerProvider(
            id: testTaskId,
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(() => MockLatestSummaryController(testAiResponse)),
          inferenceStatusControllerProvider(
            id: testTaskId,
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(
              () => MockInferenceStatusController(InferenceStatus.idle)),
          triggerNewInferenceProvider(
            entityId: testTaskId,
            promptId: testPromptId,
          ).overrideWith((ref) async {
            inferenceCompleter.complete();
          }),
        ],
      )

        // Create the controller and keep it alive
        ..listen(
          taskSummaryAutoRefreshControllerProvider(taskId: testTaskId),
          (_, __) {},
        );

      // Allow controller to initialize
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Simulate a checklist update notification
      // When a checklist is updated, its affectedIds include the checklist ID and all linked task IDs
      updateStreamController.add({checklistId, testTaskId});

      // Wait for the debounce timer (500ms) plus some buffer
      await Future<void>.delayed(const Duration(milliseconds: 700));

      // Verify that inference was triggered
      expect(inferenceCompleter.isCompleted, isTrue);
    });

    test(
        'should trigger refresh when checklist item is deleted (fallback logic)',
        () async {
      // This tests the fallback logic for when a checklist item notification
      // doesn't include the task ID (shouldn't happen with our fix, but good to test)

      // Setup mocks
      const checklistItemId = 'checklist-item-1';
      const checklistId = 'checklist-1';

      final checklistItem = ChecklistItem(
        meta: Metadata(
          id: checklistItemId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          deletedAt: DateTime.now(), // Mark as deleted
        ),
        data: const ChecklistItemData(
          title: 'Test item',
          isChecked: true,
          linkedChecklists: [checklistId],
        ),
      );

      final checklist = Checklist(
        meta: Metadata(
          id: checklistId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: const ChecklistData(
          title: 'Test checklist',
          linkedChecklistItems: [checklistItemId],
          linkedTasks: [testTaskId],
        ),
      );

      when(() => mockJournalDb.journalEntityById(checklistItemId))
          .thenAnswer((_) async => checklistItem);
      when(() => mockJournalDb.journalEntityById(checklistId))
          .thenAnswer((_) async => checklist);

      // Create a completer to track when inference is triggered
      final inferenceCompleter = Completer<void>();

      // Override the triggerNewInferenceProvider to capture calls
      container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          latestSummaryControllerProvider(
            id: testTaskId,
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(() => MockLatestSummaryController(testAiResponse)),
          inferenceStatusControllerProvider(
            id: testTaskId,
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(
              () => MockInferenceStatusController(InferenceStatus.idle)),
          triggerNewInferenceProvider(
            entityId: testTaskId,
            promptId: testPromptId,
          ).overrideWith((ref) async {
            inferenceCompleter.complete();
          }),
        ],
      )

        // Create the controller and keep it alive
        ..listen(
          taskSummaryAutoRefreshControllerProvider(taskId: testTaskId),
          (_, __) {},
        );

      // Allow controller to initialize
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Simulate a checklist item notification without task ID
      // This tests the fallback logic that checks linked checklists
      updateStreamController.add({checklistItemId});

      // Wait for the debounce timer (500ms) plus some buffer
      await Future<void>.delayed(const Duration(milliseconds: 700));

      // Verify that inference was triggered
      expect(inferenceCompleter.isCompleted, isTrue);
    });

    test(
        'should trigger refresh on actual deletion flow (item + checklist update)',
        () async {
      // This test simulates the complete deletion flow:
      // 1. Checklist item is deleted (marked as deleted in DB)
      // 2. Checklist is updated to remove the item from linkedChecklistItems
      // Both notifications might arrive, but we should only trigger once due to debouncing

      const checklistItemId = 'checklist-item-1';
      const checklistId = 'checklist-1';

      final deletedChecklistItem = ChecklistItem(
        meta: Metadata(
          id: checklistItemId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          deletedAt: DateTime.now(), // Marked as deleted
        ),
        data: const ChecklistItemData(
          title: 'Deleted item',
          isChecked: true,
          linkedChecklists: [checklistId],
        ),
      );

      final updatedChecklist = Checklist(
        meta: Metadata(
          id: checklistId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: const ChecklistData(
          title: 'Test checklist',
          linkedChecklistItems: [], // Item removed from list
          linkedTasks: [testTaskId],
        ),
      );

      when(() => mockJournalDb.journalEntityById(checklistItemId))
          .thenAnswer((_) async => deletedChecklistItem);
      when(() => mockJournalDb.journalEntityById(checklistId))
          .thenAnswer((_) async => updatedChecklist);

      // Track inference calls
      var inferenceCallCount = 0;

      // Override providers
      container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          latestSummaryControllerProvider(
            id: testTaskId,
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(() => MockLatestSummaryController(testAiResponse)),
          inferenceStatusControllerProvider(
            id: testTaskId,
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(
              () => MockInferenceStatusController(InferenceStatus.idle)),
          triggerNewInferenceProvider(
            entityId: testTaskId,
            promptId: testPromptId,
          ).overrideWith((ref) async {
            inferenceCallCount++;
          }),
        ],
      )

        // Create the controller and keep it alive
        ..listen(
          taskSummaryAutoRefreshControllerProvider(taskId: testTaskId),
          (_, __) {},
        );

      // Allow controller to initialize
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Simulate both notifications that might occur during deletion
      // First the item deletion
      updateStreamController.add({checklistItemId});

      // Then the checklist update (might happen quickly after)
      await Future<void>.delayed(const Duration(milliseconds: 100));
      updateStreamController.add({checklistId, testTaskId});

      // Wait for the debounce timer
      await Future<void>.delayed(const Duration(milliseconds: 700));

      // Verify that inference was only triggered once due to debouncing
      expect(inferenceCallCount, equals(1));
    });

    test('should ignore updates for other tasks', () async {
      // Setup mocks for other entities
      when(() => mockJournalDb.journalEntityById('other-task-1'))
          .thenAnswer((_) async => null);
      when(() => mockJournalDb.journalEntityById('other-task-2'))
          .thenAnswer((_) async => null);

      // Track inference calls
      var inferenceCallCount = 0;

      // Override the triggerNewInferenceProvider to count calls
      container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          latestSummaryControllerProvider(
            id: testTaskId,
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(() => MockLatestSummaryController(testAiResponse)),
          triggerNewInferenceProvider(
            entityId: testTaskId,
            promptId: testPromptId,
          ).overrideWith((ref) async {
            inferenceCallCount++;
          }),
        ],
      )

        // Create the controller and keep it alive
        ..listen(
          taskSummaryAutoRefreshControllerProvider(taskId: testTaskId),
          (_, __) {},
        );

      // Allow controller to initialize
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Simulate updates for other tasks
      updateStreamController.add({'other-task-1', 'other-task-2'});

      // Wait for the debounce timer
      await Future<void>.delayed(const Duration(milliseconds: 700));

      // Verify that inference was not triggered
      expect(inferenceCallCount, equals(0));
    });

    test(
        'should handle errors in stream listener without breaking subscription',
        () async {
      // Setup mock to throw an error initially
      when(() => mockJournalDb.journalEntityById(any()))
          .thenThrow(Exception('Database error'));

      // Track inference calls to verify controller still works after error
      var inferenceCallCount = 0;

      // Setup a valid checklist item for post-error testing
      const checklistItemId = 'checklist-item-1';
      final checklistItem = ChecklistItem(
        meta: Metadata(
          id: checklistItemId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: const ChecklistItemData(
          title: 'Test item',
          isChecked: true,
          linkedChecklists: [],
        ),
      );

      // Override providers
      container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          latestSummaryControllerProvider(
            id: testTaskId,
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(() => MockLatestSummaryController(testAiResponse)),
          inferenceStatusControllerProvider(
            id: testTaskId,
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(
              () => MockInferenceStatusController(InferenceStatus.idle)),
          triggerNewInferenceProvider(
            entityId: testTaskId,
            promptId: testPromptId,
          ).overrideWith((ref) async {
            inferenceCallCount++;
          }),
        ],
      )
        // Create the controller and keep it alive
        ..listen(
          taskSummaryAutoRefreshControllerProvider(taskId: testTaskId),
          (_, __) {},
        );

      // Allow controller to initialize
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Send an update that will cause an error
      updateStreamController.add({'error-entity-id'});

      // Wait a bit for error to be processed
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify error was logged
      verify(
        () => mockLoggingService.captureException(
          any<dynamic>(),
          domain: 'AI',
          subDomain: 'TaskSummaryAutoRefresh',
          stackTrace: any<dynamic>(named: 'stackTrace'),
        ),
      ).called(1);

      // Reset mock to return valid data for specific entities
      // Note: More specific mocks must come after general ones
      when(() => mockJournalDb.journalEntityById(any()))
          .thenAnswer((_) async => null);
      when(() => mockJournalDb.journalEntityById(checklistItemId))
          .thenAnswer((_) async => checklistItem);

      // Send a valid update that should trigger refresh
      updateStreamController.add({testTaskId, checklistItemId});

      // Wait for debounce timer and processing
      await Future<void>.delayed(const Duration(milliseconds: 700));

      // Verify that controller recovered and triggered inference after error
      expect(inferenceCallCount, equals(1),
          reason: 'Controller should recover from errors and trigger refresh');
    });

    test('should skip updates when only AI response notification is present',
        () async {
      // This test verifies that updates containing only AI response notification are skipped

      // Track inference calls
      var inferenceCallCount = 0;

      // Override providers
      container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          latestSummaryControllerProvider(
            id: testTaskId,
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(() => MockLatestSummaryController(testAiResponse)),
          inferenceStatusControllerProvider(
            id: testTaskId,
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(
              () => MockInferenceStatusController(InferenceStatus.idle)),
          triggerNewInferenceProvider(
            entityId: testTaskId,
            promptId: testPromptId,
          ).overrideWith((ref) async {
            inferenceCallCount++;
          }),
        ],
      )
        // Create the controller and keep it alive
        ..listen(
          taskSummaryAutoRefreshControllerProvider(taskId: testTaskId),
          (_, __) {},
        );

      // Allow controller to initialize
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Send update with only AI response notification
      updateStreamController.add({aiResponseNotification});

      // Wait for processing and debounce
      await Future<void>.delayed(const Duration(milliseconds: 700));

      // Should NOT trigger inference when only AI response notification is present
      expect(inferenceCallCount, equals(0));
    });

    test('should set pending refresh and retry when inference is running',
        () async {
      // This test verifies that when inference is already running,
      // a pending refresh is set and retried after the current inference completes

      // Setup mocks
      const checklistItemId = 'checklist-item-1';
      final checklistItem = ChecklistItem(
        meta: Metadata(
          id: checklistItemId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: const ChecklistItemData(
          title: 'Test item',
          isChecked: true,
          linkedChecklists: [],
        ),
      );

      when(() => mockJournalDb.journalEntityById(checklistItemId))
          .thenAnswer((_) async => checklistItem);

      // Track inference calls
      var inferenceCallCount = 0;
      var currentStatus = InferenceStatus.idle;

      // Override providers
      container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          latestSummaryControllerProvider(
            id: testTaskId,
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(() => MockLatestSummaryController(testAiResponse)),
          inferenceStatusControllerProvider(
            id: testTaskId,
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(() {
            // Return a controller that reports the current status
            return MockInferenceStatusController(currentStatus);
          }),
          triggerNewInferenceProvider(
            entityId: testTaskId,
            promptId: testPromptId,
          ).overrideWith((ref) async {
            inferenceCallCount++;
            // Simulate inference running for a bit
            currentStatus = InferenceStatus.running;
            await Future<void>.delayed(const Duration(milliseconds: 300));
            currentStatus = InferenceStatus.idle;
          }),
        ],
      )
        // Create the controller and keep it alive
        ..listen(
          taskSummaryAutoRefreshControllerProvider(taskId: testTaskId),
          (_, __) {},
        );

      // Allow controller to initialize
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Send first update
      updateStreamController.add({testTaskId, checklistItemId});

      // Wait for debounce and first inference to start
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // First inference should be running now
      expect(inferenceCallCount, equals(1));

      // Send another update while inference is running
      // This should set pending refresh
      updateStreamController.add({testTaskId, checklistItemId});

      // Wait for the first inference to complete and pending refresh to trigger
      await Future<void>.delayed(const Duration(milliseconds: 1000));

      // Should have triggered a second inference due to pending refresh
      expect(inferenceCallCount, equals(2));
    });

    test('should re-schedule with debounce when pending refresh exists',
        () async {
      // This test verifies the improved pending refresh logic

      // Setup mocks
      const checklistItemId = 'checklist-item-1';
      final checklistItem = ChecklistItem(
        meta: Metadata(
          id: checklistItemId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: const ChecklistItemData(
          title: 'Test item',
          isChecked: true,
          linkedChecklists: [],
        ),
      );

      when(() => mockJournalDb.journalEntityById(checklistItemId))
          .thenAnswer((_) async => checklistItem);

      // Track inference calls with timestamps
      final inferenceTimes = <DateTime>[];

      // Create a custom inference status controller that simulates a long-running inference
      var isFirstCall = true;

      container = ProviderContainer(
        overrides: [
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          latestSummaryControllerProvider(
            id: testTaskId,
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(() => MockLatestSummaryController(testAiResponse)),
          inferenceStatusControllerProvider(
            id: testTaskId,
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(
              () => MockInferenceStatusController(InferenceStatus.idle)),
          triggerNewInferenceProvider(
            entityId: testTaskId,
            promptId: testPromptId,
          ).overrideWith((ref) async {
            inferenceTimes.add(DateTime.now());

            // Simulate a long-running inference on first call
            if (isFirstCall) {
              isFirstCall = false;
              await Future<void>.delayed(const Duration(milliseconds: 300));
            }
          }),
        ],
      )
        // Create the controller and keep it alive
        ..listen(
          taskSummaryAutoRefreshControllerProvider(taskId: testTaskId),
          (_, __) {},
        );

      // Allow controller to initialize
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Send first update
      updateStreamController.add({testTaskId, checklistItemId});

      // Wait for debounce (500ms) and start of first inference
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // Send multiple updates while first inference is running
      // These should trigger pending refresh
      for (var i = 0; i < 3; i++) {
        updateStreamController.add({testTaskId, checklistItemId});
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }

      // Wait for first inference to complete and second to trigger
      await Future<void>.delayed(const Duration(milliseconds: 1000));

      // Should have exactly 2 inference calls
      expect(inferenceTimes.length, equals(2));

      // Verify the second inference was properly debounced (at least 500ms after the first completed)
      if (inferenceTimes.length >= 2) {
        final timeBetweenInferences =
            inferenceTimes[1].difference(inferenceTimes[0]);
        expect(timeBetweenInferences.inMilliseconds, greaterThanOrEqualTo(500));
      }
    });
  });
}
