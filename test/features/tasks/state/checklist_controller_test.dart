import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockJournalRepository extends Mock implements JournalRepository {}

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

class MockLoggingService extends Mock implements LoggingService {}

class MockChecklistRepository extends Mock implements ChecklistRepository {}

// Helper to register a mock instance in getIt
void registerMock<T extends Object>(T instance) {
  if (getIt.isRegistered<T>()) {
    getIt.unregister<T>();
  }
  getIt.registerSingleton<T>(instance);
}

// Helper to unregister a type from getIt
void unregisterMock<T extends Object>() {
  if (getIt.isRegistered<T>()) {
    getIt.unregister<T>();
  }
}

void main() {
  late MockJournalDb mockDb;
  late MockUpdateNotifications mockUpdateNotifications;
  late MockJournalRepository mockJournalRepository;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockLoggingService mockLoggingService;
  late StreamController<Set<String>> updateStreamController;

  final testChecklist = Checklist(
    meta: Metadata(
      id: 'checklist-1',
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
      dateFrom: DateTime(2025),
      dateTo: DateTime(2025),
    ),
    data: const ChecklistData(
      title: 'Test Checklist',
      linkedChecklistItems: ['item-1', 'item-2'],
      linkedTasks: ['task-1'],
    ),
  );

  final testTask = Task(
    meta: Metadata(
      id: 'task-1',
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
      dateFrom: DateTime(2025),
      dateTo: DateTime(2025),
    ),
    data: TaskData(
      title: 'Test Task',
      status: TaskStatus.open(
        id: 'status-1',
        createdAt: DateTime(2025),
        utcOffset: 0,
      ),
      dateFrom: DateTime(2025),
      dateTo: DateTime(2025),
      statusHistory: const [],
      checklistIds: ['checklist-1', 'checklist-2'],
    ),
  );

  setUpAll(() {
    registerFallbackValue(testTask.data);
    registerFallbackValue(
      const ChecklistData(
        title: '',
        linkedChecklistItems: [],
        linkedTasks: [],
      ),
    );
  });

  setUp(() {
    mockDb = MockJournalDb();
    mockUpdateNotifications = MockUpdateNotifications();
    mockJournalRepository = MockJournalRepository();
    mockPersistenceLogic = MockPersistenceLogic();
    mockLoggingService = MockLoggingService();
    updateStreamController = StreamController<Set<String>>.broadcast();

    // Register getIt dependencies
    registerMock<JournalDb>(mockDb);
    registerMock<UpdateNotifications>(mockUpdateNotifications);
    registerMock<PersistenceLogic>(mockPersistenceLogic);
    registerMock<LoggingService>(mockLoggingService);

    // Setup stubs
    when(() => mockDb.journalEntityById('checklist-1'))
        .thenAnswer((_) async => testChecklist);
    when(() => mockDb.journalEntityById('task-1'))
        .thenAnswer((_) async => testTask);
    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => updateStreamController.stream);
    when(() => mockJournalRepository.deleteJournalEntity(any()))
        .thenAnswer((_) async => true);
    when(
      () => mockPersistenceLogic.updateTask(
        journalEntityId: any(named: 'journalEntityId'),
        taskData: any(named: 'taskData'),
        entryText: any(named: 'entryText'),
      ),
    ).thenAnswer((_) async => true);
  });

  tearDown(() async {
    await updateStreamController.close();
    unregisterMock<JournalDb>();
    unregisterMock<UpdateNotifications>();
    unregisterMock<PersistenceLogic>();
    unregisterMock<LoggingService>();
  });

  group('ChecklistController', () {
    group('delete', () {
      test('removes checklist ID from parent task checklistIds', () async {
        final container = ProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          ],
        );
        addTearDown(container.dispose);

        // Read the controller to trigger build
        container.read(
          checklistControllerProvider((id: 'checklist-1', taskId: 'task-1')),
        );

        final notifier = container.read(
          checklistControllerProvider((id: 'checklist-1', taskId: 'task-1'))
              .notifier,
        );

        // Delete the checklist
        final result = await notifier.delete();

        expect(result, isTrue);

        // Verify deleteJournalEntity was called
        verify(() => mockJournalRepository.deleteJournalEntity('checklist-1'))
            .called(1);

        // Verify the task was updated with the checklist ID removed
        final capturedTaskData = verify(
          () => mockPersistenceLogic.updateTask(
            journalEntityId: 'task-1',
            taskData: captureAny(named: 'taskData'),
            entryText: any(named: 'entryText'),
          ),
        ).captured.single as TaskData;

        // The checklist-1 should be removed, only checklist-2 remains
        expect(capturedTaskData.checklistIds, equals(['checklist-2']));
      });

      test('does not update task when taskId is null', () async {
        final container = ProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          ],
        );
        addTearDown(container.dispose);

        // Read controller with null taskId
        container.read(
          checklistControllerProvider((id: 'checklist-1', taskId: null)),
        );

        final notifier = container.read(
          checklistControllerProvider((id: 'checklist-1', taskId: null))
              .notifier,
        );

        // Delete the checklist
        final result = await notifier.delete();

        expect(result, isTrue);

        // Verify deleteJournalEntity was called
        verify(() => mockJournalRepository.deleteJournalEntity('checklist-1'))
            .called(1);

        // Verify updateTask was NOT called (no taskId)
        verifyNever(
          () => mockPersistenceLogic.updateTask(
            journalEntityId: any(named: 'journalEntityId'),
            taskData: any(named: 'taskData'),
            entryText: any(named: 'entryText'),
          ),
        );
      });

      test('does not update task when checklist ID not in task', () async {
        // Task that doesn't have the checklist ID
        final taskWithoutChecklist = Task(
          meta: Metadata(
            id: 'task-2',
            createdAt: DateTime(2025),
            updatedAt: DateTime(2025),
            dateFrom: DateTime(2025),
            dateTo: DateTime(2025),
          ),
          data: TaskData(
            title: 'Other Task',
            status: TaskStatus.open(
              id: 'status-2',
              createdAt: DateTime(2025),
              utcOffset: 0,
            ),
            dateFrom: DateTime(2025),
            dateTo: DateTime(2025),
            statusHistory: const [],
            checklistIds: ['other-checklist'],
          ),
        );

        when(() => mockDb.journalEntityById('task-2'))
            .thenAnswer((_) async => taskWithoutChecklist);

        final container = ProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          ],
        );
        addTearDown(container.dispose);

        container.read(
          checklistControllerProvider((id: 'checklist-1', taskId: 'task-2')),
        );

        final notifier = container.read(
          checklistControllerProvider((id: 'checklist-1', taskId: 'task-2'))
              .notifier,
        );

        // Delete the checklist
        final result = await notifier.delete();

        expect(result, isTrue);

        // Verify deleteJournalEntity was called
        verify(() => mockJournalRepository.deleteJournalEntity('checklist-1'))
            .called(1);

        // Verify updateTask was NOT called (no change needed)
        verifyNever(
          () => mockPersistenceLogic.updateTask(
            journalEntityId: any(named: 'journalEntityId'),
            taskData: any(named: 'taskData'),
            entryText: any(named: 'entryText'),
          ),
        );
      });

      test('handles task with null checklistIds', () async {
        // Task with null checklistIds
        final taskWithNullIds = Task(
          meta: Metadata(
            id: 'task-3',
            createdAt: DateTime(2025),
            updatedAt: DateTime(2025),
            dateFrom: DateTime(2025),
            dateTo: DateTime(2025),
          ),
          data: TaskData(
            title: 'Task with null IDs',
            status: TaskStatus.open(
              id: 'status-3',
              createdAt: DateTime(2025),
              utcOffset: 0,
            ),
            dateFrom: DateTime(2025),
            dateTo: DateTime(2025),
            statusHistory: const [],
            // checklistIds is null by default
          ),
        );

        when(() => mockDb.journalEntityById('task-3'))
            .thenAnswer((_) async => taskWithNullIds);

        final container = ProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          ],
        );
        addTearDown(container.dispose);

        container.read(
          checklistControllerProvider((id: 'checklist-1', taskId: 'task-3')),
        );

        final notifier = container.read(
          checklistControllerProvider((id: 'checklist-1', taskId: 'task-3'))
              .notifier,
        );

        // Delete the checklist - should not throw
        final result = await notifier.delete();

        expect(result, isTrue);

        // Verify updateTask was NOT called (empty list, no change)
        verifyNever(
          () => mockPersistenceLogic.updateTask(
            journalEntityId: any(named: 'journalEntityId'),
            taskData: any(named: 'taskData'),
            entryText: any(named: 'entryText'),
          ),
        );
      });

      test('returns false and does not update task when deletion fails',
          () async {
        // Make deleteJournalEntity return false
        when(() => mockJournalRepository.deleteJournalEntity(any()))
            .thenAnswer((_) async => false);

        final container = ProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          ],
        );
        addTearDown(container.dispose);

        container.read(
          checklistControllerProvider((id: 'checklist-1', taskId: 'task-1')),
        );

        final notifier = container.read(
          checklistControllerProvider((id: 'checklist-1', taskId: 'task-1'))
              .notifier,
        );

        // Delete the checklist - should fail
        final result = await notifier.delete();

        expect(result, isFalse);

        // Verify deleteJournalEntity was called
        verify(() => mockJournalRepository.deleteJournalEntity('checklist-1'))
            .called(1);

        // Verify updateTask was NOT called (deletion failed, early return)
        verifyNever(
          () => mockPersistenceLogic.updateTask(
            journalEntityId: any(named: 'journalEntityId'),
            taskData: any(named: 'taskData'),
            entryText: any(named: 'entryText'),
          ),
        );
      });
    });

    group('dropChecklistItem - same checklist reordering', () {
      late MockChecklistRepository mockChecklistRepository;

      setUp(() {
        mockChecklistRepository = MockChecklistRepository();
        when(
          () => mockChecklistRepository.updateChecklist(
            checklistId: any(named: 'checklistId'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => true);
      });

      test('reorders item to target index position', () async {
        // Checklist with 3 items
        final checklistWith3Items = Checklist(
          meta: Metadata(
            id: 'checklist-1',
            createdAt: DateTime(2025),
            updatedAt: DateTime(2025),
            dateFrom: DateTime(2025),
            dateTo: DateTime(2025),
          ),
          data: const ChecklistData(
            title: 'Test Checklist',
            linkedChecklistItems: ['item-1', 'item-2', 'item-3'],
            linkedTasks: ['task-1'],
          ),
        );

        when(() => mockDb.journalEntityById('checklist-1'))
            .thenAnswer((_) async => checklistWith3Items);

        final container = ProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
            checklistRepositoryProvider
                .overrideWithValue(mockChecklistRepository),
          ],
        );
        addTearDown(container.dispose);

        // Wait for initial state
        await container.read(
          checklistControllerProvider((id: 'checklist-1', taskId: 'task-1'))
              .future,
        );

        final notifier = container.read(
          checklistControllerProvider((id: 'checklist-1', taskId: 'task-1'))
              .notifier,
        );

        // Drop item-1 at index 2 (move from first to last)
        await notifier.dropChecklistItem(
          {'checklistItemId': 'item-1', 'checklistId': 'checklist-1'},
          targetIndex: 2,
        );

        // Verify updateChecklist was called with reordered items
        final captured = verify(
          () => mockChecklistRepository.updateChecklist(
            checklistId: 'checklist-1',
            data: captureAny(named: 'data'),
          ),
        ).captured.single as ChecklistData;

        // item-1 moved from index 0 to index 2
        // Original: [item-1, item-2, item-3]
        // After moving item-1 to index 2: [item-2, item-1, item-3]
        expect(captured.linkedChecklistItems, ['item-2', 'item-1', 'item-3']);
      });

      test('reorders item using targetItemId (insert after)', () async {
        final checklistWith3Items = Checklist(
          meta: Metadata(
            id: 'checklist-1',
            createdAt: DateTime(2025),
            updatedAt: DateTime(2025),
            dateFrom: DateTime(2025),
            dateTo: DateTime(2025),
          ),
          data: const ChecklistData(
            title: 'Test Checklist',
            linkedChecklistItems: ['item-1', 'item-2', 'item-3'],
            linkedTasks: ['task-1'],
          ),
        );

        when(() => mockDb.journalEntityById('checklist-1'))
            .thenAnswer((_) async => checklistWith3Items);

        final container = ProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
            checklistRepositoryProvider
                .overrideWithValue(mockChecklistRepository),
          ],
        );
        addTearDown(container.dispose);

        await container.read(
          checklistControllerProvider((id: 'checklist-1', taskId: 'task-1'))
              .future,
        );

        final notifier = container.read(
          checklistControllerProvider((id: 'checklist-1', taskId: 'task-1'))
              .notifier,
        );

        // Move item-1 after item-2
        await notifier.dropChecklistItem(
          {'checklistItemId': 'item-1', 'checklistId': 'checklist-1'},
          targetItemId: 'item-2',
        );

        final captured = verify(
          () => mockChecklistRepository.updateChecklist(
            checklistId: 'checklist-1',
            data: captureAny(named: 'data'),
          ),
        ).captured.single as ChecklistData;

        // item-1 moved after item-2
        // Original: [item-1, item-2, item-3]
        // After: [item-2, item-1, item-3]
        expect(captured.linkedChecklistItems, ['item-2', 'item-1', 'item-3']);
      });

      test('does nothing when item not in checklist', () async {
        final container = ProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
            checklistRepositoryProvider
                .overrideWithValue(mockChecklistRepository),
          ],
        );
        addTearDown(container.dispose);

        await container.read(
          checklistControllerProvider((id: 'checklist-1', taskId: 'task-1'))
              .future,
        );

        final notifier = container.read(
          checklistControllerProvider((id: 'checklist-1', taskId: 'task-1'))
              .notifier,
        );

        // Try to reorder non-existent item
        await notifier.dropChecklistItem(
          {'checklistItemId': 'non-existent', 'checklistId': 'checklist-1'},
          targetIndex: 0,
        );

        // Verify updateChecklist was NOT called
        verifyNever(
          () => mockChecklistRepository.updateChecklist(
            checklistId: any(named: 'checklistId'),
            data: any(named: 'data'),
          ),
        );
      });

      test('appends to end when no position specified for same checklist',
          () async {
        final checklistWith3Items = Checklist(
          meta: Metadata(
            id: 'checklist-1',
            createdAt: DateTime(2025),
            updatedAt: DateTime(2025),
            dateFrom: DateTime(2025),
            dateTo: DateTime(2025),
          ),
          data: const ChecklistData(
            title: 'Test Checklist',
            linkedChecklistItems: ['item-1', 'item-2', 'item-3'],
            linkedTasks: ['task-1'],
          ),
        );

        when(() => mockDb.journalEntityById('checklist-1'))
            .thenAnswer((_) async => checklistWith3Items);

        final container = ProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
            checklistRepositoryProvider
                .overrideWithValue(mockChecklistRepository),
          ],
        );
        addTearDown(container.dispose);

        await container.read(
          checklistControllerProvider((id: 'checklist-1', taskId: 'task-1'))
              .future,
        );

        final notifier = container.read(
          checklistControllerProvider((id: 'checklist-1', taskId: 'task-1'))
              .notifier,
        );

        // Reorder item-1 with no target position
        await notifier.dropChecklistItem(
          {'checklistItemId': 'item-1', 'checklistId': 'checklist-1'},
        );

        final captured = verify(
          () => mockChecklistRepository.updateChecklist(
            checklistId: 'checklist-1',
            data: captureAny(named: 'data'),
          ),
        ).captured.single as ChecklistData;

        // item-1 moved to end
        expect(captured.linkedChecklistItems, ['item-2', 'item-3', 'item-1']);
      });
    });
  });
}
