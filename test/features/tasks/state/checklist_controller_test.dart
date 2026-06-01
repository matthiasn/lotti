import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

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
  late MockDomainLogger mockDomainLogger;
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
    registerFallbackValue(
      const ChecklistItemData(
        title: '',
        isChecked: false,
        linkedChecklists: [],
      ),
    );
  });

  setUp(() {
    mockDb = MockJournalDb();
    mockUpdateNotifications = MockUpdateNotifications();
    mockJournalRepository = MockJournalRepository();
    mockPersistenceLogic = MockPersistenceLogic();
    mockDomainLogger = MockDomainLogger();
    updateStreamController = StreamController<Set<String>>.broadcast();

    // Register getIt dependencies
    registerMock<JournalDb>(mockDb);
    registerMock<UpdateNotifications>(mockUpdateNotifications);
    registerMock<PersistenceLogic>(mockPersistenceLogic);
    registerMock<DomainLogger>(mockDomainLogger);

    // Setup stubs
    when(
      () => mockDb.journalEntityById('checklist-1'),
    ).thenAnswer((_) async => testChecklist);
    when(
      () => mockDb.journalEntityById('task-1'),
    ).thenAnswer((_) async => testTask);
    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => updateStreamController.stream);
    when(
      () => mockJournalRepository.deleteJournalEntity(any()),
    ).thenAnswer((_) async => true);
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
    unregisterMock<DomainLogger>();
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
          checklistControllerProvider((
            id: 'checklist-1',
            taskId: 'task-1',
          )).notifier,
        );

        // Delete the checklist
        final result = await notifier.delete();

        expect(result, isTrue);

        // Verify deleteJournalEntity was called
        verify(
          () => mockJournalRepository.deleteJournalEntity('checklist-1'),
        ).called(1);

        // Verify the task was updated with the checklist ID removed
        final capturedTaskData =
            verify(
                  () => mockPersistenceLogic.updateTask(
                    journalEntityId: 'task-1',
                    taskData: captureAny(named: 'taskData'),
                    entryText: any(named: 'entryText'),
                  ),
                ).captured.single
                as TaskData;

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
          checklistControllerProvider((
            id: 'checklist-1',
            taskId: null,
          )).notifier,
        );

        // Delete the checklist
        final result = await notifier.delete();

        expect(result, isTrue);

        // Verify deleteJournalEntity was called
        verify(
          () => mockJournalRepository.deleteJournalEntity('checklist-1'),
        ).called(1);

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

        when(
          () => mockDb.journalEntityById('task-2'),
        ).thenAnswer((_) async => taskWithoutChecklist);

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
          checklistControllerProvider((
            id: 'checklist-1',
            taskId: 'task-2',
          )).notifier,
        );

        // Delete the checklist
        final result = await notifier.delete();

        expect(result, isTrue);

        // Verify deleteJournalEntity was called
        verify(
          () => mockJournalRepository.deleteJournalEntity('checklist-1'),
        ).called(1);

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

        when(
          () => mockDb.journalEntityById('task-3'),
        ).thenAnswer((_) async => taskWithNullIds);

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
          checklistControllerProvider((
            id: 'checklist-1',
            taskId: 'task-3',
          )).notifier,
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

      test(
        'returns false and does not update task when deletion fails',
        () async {
          // Make deleteJournalEntity return false
          when(
            () => mockJournalRepository.deleteJournalEntity(any()),
          ).thenAnswer((_) async => false);

          final container = ProviderContainer(
            overrides: [
              journalRepositoryProvider.overrideWithValue(
                mockJournalRepository,
              ),
            ],
          );
          addTearDown(container.dispose);

          container.read(
            checklistControllerProvider((id: 'checklist-1', taskId: 'task-1')),
          );

          final notifier = container.read(
            checklistControllerProvider((
              id: 'checklist-1',
              taskId: 'task-1',
            )).notifier,
          );

          // Delete the checklist - should fail
          final result = await notifier.delete();

          expect(result, isFalse);

          // Verify deleteJournalEntity was called
          verify(
            () => mockJournalRepository.deleteJournalEntity('checklist-1'),
          ).called(1);

          // Verify updateTask was NOT called (deletion failed, early return)
          verifyNever(
            () => mockPersistenceLogic.updateTask(
              journalEntityId: any(named: 'journalEntityId'),
              taskData: any(named: 'taskData'),
              entryText: any(named: 'entryText'),
            ),
          );
        },
      );
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

        when(
          () => mockDb.journalEntityById('checklist-1'),
        ).thenAnswer((_) async => checklistWith3Items);

        final container = ProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
            checklistRepositoryProvider.overrideWithValue(
              mockChecklistRepository,
            ),
          ],
        );
        addTearDown(container.dispose);

        // Wait for initial state
        await container.read(
          checklistControllerProvider((
            id: 'checklist-1',
            taskId: 'task-1',
          )).future,
        );

        final notifier = container.read(
          checklistControllerProvider((
            id: 'checklist-1',
            taskId: 'task-1',
          )).notifier,
        );

        // Drop item-1 at targetIndex 2 (before item-3)
        // Since item-1 is removed first, actual insertion is at index 1
        await notifier.dropChecklistItem(
          {'checklistItemId': 'item-1', 'checklistId': 'checklist-1'},
          targetIndex: 2,
        );

        // Verify updateChecklist was called with reordered items
        final captured =
            verify(
                  () => mockChecklistRepository.updateChecklist(
                    checklistId: 'checklist-1',
                    data: captureAny(named: 'data'),
                  ),
                ).captured.single
                as ChecklistData;

        // Original: [item-1, item-2, item-3]
        // Remove item-1: [item-2, item-3]
        // targetIndex=2 > oldIndex=0, so newIndex = 2 - 1 = 1
        // Insert at 1: [item-2, item-1, item-3]
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

        when(
          () => mockDb.journalEntityById('checklist-1'),
        ).thenAnswer((_) async => checklistWith3Items);

        final container = ProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
            checklistRepositoryProvider.overrideWithValue(
              mockChecklistRepository,
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(
          checklistControllerProvider((
            id: 'checklist-1',
            taskId: 'task-1',
          )).future,
        );

        final notifier = container.read(
          checklistControllerProvider((
            id: 'checklist-1',
            taskId: 'task-1',
          )).notifier,
        );

        // Move item-1 after item-2
        await notifier.dropChecklistItem(
          {'checklistItemId': 'item-1', 'checklistId': 'checklist-1'},
          targetItemId: 'item-2',
        );

        final captured =
            verify(
                  () => mockChecklistRepository.updateChecklist(
                    checklistId: 'checklist-1',
                    data: captureAny(named: 'data'),
                  ),
                ).captured.single
                as ChecklistData;

        // item-1 moved after item-2
        // Original: [item-1, item-2, item-3]
        // After: [item-2, item-1, item-3]
        expect(captured.linkedChecklistItems, ['item-2', 'item-1', 'item-3']);
      });

      test('does nothing when item not in checklist', () async {
        final container = ProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
            checklistRepositoryProvider.overrideWithValue(
              mockChecklistRepository,
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(
          checklistControllerProvider((
            id: 'checklist-1',
            taskId: 'task-1',
          )).future,
        );

        final notifier = container.read(
          checklistControllerProvider((
            id: 'checklist-1',
            taskId: 'task-1',
          )).notifier,
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

      test(
        'appends to end when no position specified for same checklist',
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

          when(
            () => mockDb.journalEntityById('checklist-1'),
          ).thenAnswer((_) async => checklistWith3Items);

          final container = ProviderContainer(
            overrides: [
              journalRepositoryProvider.overrideWithValue(
                mockJournalRepository,
              ),
              checklistRepositoryProvider.overrideWithValue(
                mockChecklistRepository,
              ),
            ],
          );
          addTearDown(container.dispose);

          await container.read(
            checklistControllerProvider((
              id: 'checklist-1',
              taskId: 'task-1',
            )).future,
          );

          final notifier = container.read(
            checklistControllerProvider((
              id: 'checklist-1',
              taskId: 'task-1',
            )).notifier,
          );

          // Reorder item-1 with no target position
          await notifier.dropChecklistItem(
            {'checklistItemId': 'item-1', 'checklistId': 'checklist-1'},
          );

          final captured =
              verify(
                    () => mockChecklistRepository.updateChecklist(
                      checklistId: 'checklist-1',
                      data: captureAny(named: 'data'),
                    ),
                  ).captured.single
                  as ChecklistData;

          // item-1 moved to end
          expect(captured.linkedChecklistItems, ['item-2', 'item-3', 'item-1']);
        },
      );
    });

    group('dropChecklistItem - cross-checklist move', () {
      late MockChecklistRepository mockChecklistRepository;

      setUp(() {
        mockChecklistRepository = MockChecklistRepository();
        when(
          () => mockChecklistRepository.updateChecklist(
            checklistId: any(named: 'checklistId'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => true);
        when(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: any(named: 'checklistItemId'),
            data: any(named: 'data'),
            taskId: any(named: 'taskId'),
          ),
        ).thenAnswer((_) async => true);
      });

      Checklist makeChecklist(String id, List<String> items) => Checklist(
        meta: Metadata(
          id: id,
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025),
        ),
        data: ChecklistData(
          title: id,
          linkedChecklistItems: items,
          linkedTasks: const ['task-1'],
        ),
      );

      ChecklistItem makeItem(String id, String fromChecklistId) =>
          ChecklistItem(
            meta: Metadata(
              id: id,
              createdAt: DateTime(2025),
              updatedAt: DateTime(2025),
              dateFrom: DateTime(2025),
              dateTo: DateTime(2025),
            ),
            data: ChecklistItemData(
              title: id,
              isChecked: false,
              linkedChecklists: [fromChecklistId],
            ),
          );

      Future<ProviderContainer> bootstrap({
        required Checklist source,
        required Checklist target,
        required ChecklistItem droppedItem,
      }) async {
        when(() => mockDb.journalEntityById(source.id)).thenAnswer(
          (_) async => source,
        );
        when(() => mockDb.journalEntityById(target.id)).thenAnswer(
          (_) async => target,
        );
        when(() => mockDb.journalEntityById(droppedItem.id)).thenAnswer(
          (_) async => droppedItem,
        );

        final container = ProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(
              mockJournalRepository,
            ),
            checklistRepositoryProvider.overrideWithValue(
              mockChecklistRepository,
            ),
          ],
        );
        addTearDown(container.dispose);

        // Warm up both checklist controllers and the dropped item controller
        // so they all hold state — production renders each row, which
        // materialises the item controller before drop.
        await container.read(
          checklistControllerProvider((
            id: source.id,
            taskId: 'task-1',
          )).future,
        );
        await container.read(
          checklistControllerProvider((
            id: target.id,
            taskId: 'task-1',
          )).future,
        );
        await container.read(
          checklistItemControllerProvider((
            id: droppedItem.id,
            taskId: 'task-1',
          )).future,
        );

        return container;
      }

      ChecklistController targetNotifier(
        ProviderContainer container,
        String targetId,
      ) => container.read(
        checklistControllerProvider((
          id: targetId,
          taskId: 'task-1',
        )).notifier,
      );

      ChecklistData captureUpdate(String checklistId) =>
          verify(
                () => mockChecklistRepository.updateChecklist(
                  checklistId: checklistId,
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as ChecklistData;

      test('links item to target checklist and unlinks from source', () async {
        final container = await bootstrap(
          source: makeChecklist('source-cl', const ['item-1']),
          target: makeChecklist('target-cl', const []),
          droppedItem: makeItem('item-1', 'source-cl'),
        );

        await targetNotifier(container, 'target-cl').dropChecklistItem(
          {'checklistItemId': 'item-1', 'checklistId': 'source-cl'},
        );

        // Item's linkedChecklists must now point at the target, not the
        // dropped item's own id (regression: previously passed the item id
        // as `linkedChecklistId`, corrupting the back-link).
        final capturedItemData =
            verify(
                  () => mockChecklistRepository.updateChecklistItem(
                    checklistItemId: 'item-1',
                    data: captureAny(named: 'data'),
                    taskId: 'task-1',
                  ),
                ).captured.single
                as ChecklistItemData;
        expect(capturedItemData.linkedChecklists, ['target-cl']);

        expect(captureUpdate('target-cl').linkedChecklistItems, ['item-1']);
        expect(
          captureUpdate('source-cl').linkedChecklistItems,
          isNot(contains('item-1')),
        );
      });

      test('inserts at targetIndex when dropping on a row', () async {
        final container = await bootstrap(
          source: makeChecklist('source-cl', const ['dragged']),
          target: makeChecklist('target-cl', const ['a', 'b', 'c']),
          droppedItem: makeItem('dragged', 'source-cl'),
        );

        // Dropping on the row at index 1 ('b') means "insert before b".
        await targetNotifier(container, 'target-cl').dropChecklistItem(
          {'checklistItemId': 'dragged', 'checklistId': 'source-cl'},
          targetIndex: 1,
        );

        expect(
          captureUpdate('target-cl').linkedChecklistItems,
          ['a', 'dragged', 'b', 'c'],
        );
      });

      test('inserts after targetItemId when only id is provided', () async {
        final container = await bootstrap(
          source: makeChecklist('source-cl', const ['dragged']),
          target: makeChecklist('target-cl', const ['a', 'b', 'c']),
          droppedItem: makeItem('dragged', 'source-cl'),
        );

        await targetNotifier(container, 'target-cl').dropChecklistItem(
          {'checklistItemId': 'dragged', 'checklistId': 'source-cl'},
          targetItemId: 'b',
        );

        expect(
          captureUpdate('target-cl').linkedChecklistItems,
          ['a', 'b', 'dragged', 'c'],
        );
      });

      test('appends to end when no positioning info is provided', () async {
        final container = await bootstrap(
          source: makeChecklist('source-cl', const ['dragged']),
          target: makeChecklist('target-cl', const ['a', 'b']),
          droppedItem: makeItem('dragged', 'source-cl'),
        );

        await targetNotifier(container, 'target-cl').dropChecklistItem(
          {'checklistItemId': 'dragged', 'checklistId': 'source-cl'},
        );

        expect(
          captureUpdate('target-cl').linkedChecklistItems,
          ['a', 'b', 'dragged'],
        );
      });
    });

    group('_listen / update notifications', () {
      test(
        'refreshes state when a subscribed ID appears in update stream',
        () async {
          final container = ProviderContainer(
            overrides: [
              journalRepositoryProvider.overrideWithValue(
                mockJournalRepository,
              ),
            ],
          );
          addTearDown(container.dispose);

          // Initial build
          await container.read(
            checklistControllerProvider((
              id: 'checklist-1',
              taskId: 'task-1',
            )).future,
          );

          // Now update the checklist that the db returns
          final updatedChecklist = testChecklist.copyWith(
            data: const ChecklistData(
              title: 'Updated Title',
              linkedChecklistItems: ['item-1', 'item-2', 'item-3'],
              linkedTasks: ['task-1'],
            ),
          );
          when(
            () => mockDb.journalEntityById('checklist-1'),
          ).thenAnswer((_) async => updatedChecklist);

          // Fire a notification for the checklist ID
          updateStreamController.add({'checklist-1'});

          // Pump async events
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);

          final state = container.read(
            checklistControllerProvider((
              id: 'checklist-1',
              taskId: 'task-1',
            )),
          );
          expect(state.value?.data.title, 'Updated Title');
          expect(
            state.value?.data.linkedChecklistItems,
            ['item-1', 'item-2', 'item-3'],
          );
        },
      );

      test('ignores notifications for unrelated IDs', () async {
        final container = ProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          ],
        );
        addTearDown(container.dispose);

        await container.read(
          checklistControllerProvider((
            id: 'checklist-1',
            taskId: 'task-1',
          )).future,
        );

        var fetchCount = 0;
        when(
          () => mockDb.journalEntityById('checklist-1'),
        ).thenAnswer((_) async {
          fetchCount++;
          return testChecklist;
        });

        // Notification for a completely unrelated ID
        updateStreamController.add({'unrelated-id'});
        await Future<void>.delayed(Duration.zero);

        // No additional fetch should have happened
        expect(fetchCount, isZero);
      });
    });

    group('updateTitle', () {
      test('updates checklist title via updateChecklist', () async {
        final mockChecklistRepository = MockChecklistRepository();
        when(
          () => mockChecklistRepository.updateChecklist(
            checklistId: any(named: 'checklistId'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => true);

        final container = ProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
            checklistRepositoryProvider.overrideWithValue(
              mockChecklistRepository,
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(
          checklistControllerProvider((
            id: 'checklist-1',
            taskId: 'task-1',
          )).future,
        );

        final notifier = container.read(
          checklistControllerProvider((
            id: 'checklist-1',
            taskId: 'task-1',
          )).notifier,
        );

        await notifier.updateTitle('New Title');

        final captured =
            verify(
                  () => mockChecklistRepository.updateChecklist(
                    checklistId: 'checklist-1',
                    data: captureAny(named: 'data'),
                  ),
                ).captured.single
                as ChecklistData;

        expect(captured.title, 'New Title');

        final state = container.read(
          checklistControllerProvider((
            id: 'checklist-1',
            taskId: 'task-1',
          )),
        );
        expect(state.value?.data.title, 'New Title');
      });

      test('uses empty string when title is null', () async {
        final mockChecklistRepository = MockChecklistRepository();
        when(
          () => mockChecklistRepository.updateChecklist(
            checklistId: any(named: 'checklistId'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => true);

        final container = ProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
            checklistRepositoryProvider.overrideWithValue(
              mockChecklistRepository,
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(
          checklistControllerProvider((
            id: 'checklist-1',
            taskId: 'task-1',
          )).future,
        );

        final notifier = container.read(
          checklistControllerProvider((
            id: 'checklist-1',
            taskId: 'task-1',
          )).notifier,
        );

        await notifier.updateTitle(null);

        final captured =
            verify(
                  () => mockChecklistRepository.updateChecklist(
                    checklistId: 'checklist-1',
                    data: captureAny(named: 'data'),
                  ),
                ).captured.single
                as ChecklistData;

        expect(captured.title, '');
      });
    });

    group('delete - error path', () {
      test('logs error when exception thrown during task update', () async {
        when(
          () => mockPersistenceLogic.updateTask(
            journalEntityId: any(named: 'journalEntityId'),
            taskData: any(named: 'taskData'),
            entryText: any(named: 'entryText'),
          ),
        ).thenThrow(Exception('update failed'));

        final container = ProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          ],
        );
        addTearDown(container.dispose);

        await container.read(
          checklistControllerProvider((
            id: 'checklist-1',
            taskId: 'task-1',
          )).future,
        );

        final notifier = container.read(
          checklistControllerProvider((
            id: 'checklist-1',
            taskId: 'task-1',
          )).notifier,
        );

        // Deletion should still return true even though the task update threw
        final result = await notifier.delete();
        expect(result, isTrue);

        verify(
          () => mockDomainLogger.error(
            LogDomain.tasks,
            any(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'delete',
          ),
        ).called(1);
      });
    });

    group('relinkItem', () {
      test('adds an item that is not yet in the list', () async {
        final mockChecklistRepository = MockChecklistRepository();
        when(
          () => mockChecklistRepository.updateChecklist(
            checklistId: any(named: 'checklistId'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => true);

        final container = ProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
            checklistRepositoryProvider.overrideWithValue(
              mockChecklistRepository,
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(
          checklistControllerProvider((
            id: 'checklist-1',
            taskId: 'task-1',
          )).future,
        );

        final notifier = container.read(
          checklistControllerProvider((
            id: 'checklist-1',
            taskId: 'task-1',
          )).notifier,
        );

        await notifier.relinkItem('item-new');

        final captured =
            verify(
                  () => mockChecklistRepository.updateChecklist(
                    checklistId: 'checklist-1',
                    data: captureAny(named: 'data'),
                  ),
                ).captured.single
                as ChecklistData;

        expect(captured.linkedChecklistItems, ['item-1', 'item-2', 'item-new']);
      });

      test(
        'does not duplicate an item that already exists in the list',
        () async {
          final mockChecklistRepository = MockChecklistRepository();
          when(
            () => mockChecklistRepository.updateChecklist(
              checklistId: any(named: 'checklistId'),
              data: any(named: 'data'),
            ),
          ).thenAnswer((_) async => true);

          final container = ProviderContainer(
            overrides: [
              journalRepositoryProvider.overrideWithValue(
                mockJournalRepository,
              ),
              checklistRepositoryProvider.overrideWithValue(
                mockChecklistRepository,
              ),
            ],
          );
          addTearDown(container.dispose);

          await container.read(
            checklistControllerProvider((
              id: 'checklist-1',
              taskId: 'task-1',
            )).future,
          );

          final notifier = container.read(
            checklistControllerProvider((
              id: 'checklist-1',
              taskId: 'task-1',
            )).notifier,
          );

          // item-1 already present in testChecklist
          await notifier.relinkItem('item-1');

          // The persisted list must not contain item-1 twice.
          final captured =
              verify(
                    () => mockChecklistRepository.updateChecklist(
                      checklistId: any(named: 'checklistId'),
                      data: captureAny(named: 'data'),
                    ),
                  ).captured.last
                  as ChecklistData;
          expect(
            captured.linkedChecklistItems.where((id) => id == 'item-1').length,
            1,
          );

          final state = container.read(
            checklistControllerProvider((
              id: 'checklist-1',
              taskId: 'task-1',
            )),
          );
          // Items unchanged
          expect(
            state.value?.data.linkedChecklistItems,
            ['item-1', 'item-2'],
          );
        },
      );
    });

    group('createChecklistItem', () {
      late MockChecklistRepository mockChecklistRepository;

      ChecklistItem makeCreatedItem(String itemId) => ChecklistItem(
        meta: Metadata(
          id: itemId,
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025),
        ),
        data: const ChecklistItemData(
          title: 'New Item',
          isChecked: false,
          linkedChecklists: ['checklist-1'],
        ),
      );

      setUp(() {
        mockChecklistRepository = MockChecklistRepository();
        when(
          () => mockChecklistRepository.updateChecklist(
            checklistId: any(named: 'checklistId'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => true);
      });

      test('creates item, updates state, and returns new item id', () async {
        when(
          () => mockChecklistRepository.createChecklistItem(
            title: any(named: 'title'),
            isChecked: any(named: 'isChecked'),
            checklistId: any(named: 'checklistId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => makeCreatedItem('new-item-1'));

        final container = ProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
            checklistRepositoryProvider.overrideWithValue(
              mockChecklistRepository,
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(
          checklistControllerProvider((
            id: 'checklist-1',
            taskId: 'task-1',
          )).future,
        );

        final notifier = container.read(
          checklistControllerProvider((
            id: 'checklist-1',
            taskId: 'task-1',
          )).notifier,
        );

        final createdId = await notifier.createChecklistItem(
          'New Item',
          isChecked: false,
          categoryId: null,
        );

        expect(createdId, 'new-item-1');

        final state = container.read(
          checklistControllerProvider((
            id: 'checklist-1',
            taskId: 'task-1',
          )),
        );
        expect(
          state.value?.data.linkedChecklistItems,
          contains('new-item-1'),
        );

        // updateChecklist must be called with the new item appended
        final captured =
            verify(
                  () => mockChecklistRepository.updateChecklist(
                    checklistId: 'checklist-1',
                    data: captureAny(named: 'data'),
                  ),
                ).captured.single
                as ChecklistData;
        expect(captured.linkedChecklistItems, contains('new-item-1'));
      });

      test(
        'returns null when repository createChecklistItem returns null',
        () async {
          when(
            () => mockChecklistRepository.createChecklistItem(
              title: any(named: 'title'),
              isChecked: any(named: 'isChecked'),
              checklistId: any(named: 'checklistId'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer((_) async => null);

          final container = ProviderContainer(
            overrides: [
              journalRepositoryProvider.overrideWithValue(
                mockJournalRepository,
              ),
              checklistRepositoryProvider.overrideWithValue(
                mockChecklistRepository,
              ),
            ],
          );
          addTearDown(container.dispose);

          await container.read(
            checklistControllerProvider((
              id: 'checklist-1',
              taskId: 'task-1',
            )).future,
          );

          final notifier = container.read(
            checklistControllerProvider((
              id: 'checklist-1',
              taskId: 'task-1',
            )).notifier,
          );

          final createdId = await notifier.createChecklistItem(
            'New Item',
            isChecked: true,
            categoryId: 'cat-1',
          );

          expect(createdId, isNull);

          // updateChecklist must NOT be called when creation fails
          verifyNever(
            () => mockChecklistRepository.updateChecklist(
              checklistId: any(named: 'checklistId'),
              data: any(named: 'data'),
            ),
          );
        },
      );

      test('returns null when title is null', () async {
        final container = ProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
            checklistRepositoryProvider.overrideWithValue(
              mockChecklistRepository,
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(
          checklistControllerProvider((
            id: 'checklist-1',
            taskId: 'task-1',
          )).future,
        );

        final notifier = container.read(
          checklistControllerProvider((
            id: 'checklist-1',
            taskId: 'task-1',
          )).notifier,
        );

        final createdId = await notifier.createChecklistItem(
          null,
          isChecked: false,
          categoryId: null,
        );

        expect(createdId, isNull);
        verifyNever(
          () => mockChecklistRepository.createChecklistItem(
            title: any(named: 'title'),
            isChecked: any(named: 'isChecked'),
            checklistId: any(named: 'checklistId'),
            categoryId: any(named: 'categoryId'),
          ),
        );
      });
    });

    group('dropChecklistNewItem', () {
      late MockChecklistRepository mockChecklistRepository;

      ChecklistItem makeCreatedItem(String itemId) => ChecklistItem(
        meta: Metadata(
          id: itemId,
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025),
        ),
        data: const ChecklistItemData(
          title: 'Dropped Item',
          isChecked: false,
          linkedChecklists: ['checklist-1'],
        ),
      );

      setUp(() {
        mockChecklistRepository = MockChecklistRepository();
        when(
          () => mockChecklistRepository.updateChecklist(
            checklistId: any(named: 'checklistId'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => true);
      });

      test('creates new item and adds it to checklist linked items', () async {
        when(
          () => mockChecklistRepository.createChecklistItem(
            title: any(named: 'title'),
            isChecked: any(named: 'isChecked'),
            checklistId: any(named: 'checklistId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => makeCreatedItem('dropped-item-1'));

        final container = ProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
            checklistRepositoryProvider.overrideWithValue(
              mockChecklistRepository,
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(
          checklistControllerProvider((
            id: 'checklist-1',
            taskId: 'task-1',
          )).future,
        );

        final notifier = container.read(
          checklistControllerProvider((
            id: 'checklist-1',
            taskId: 'task-1',
          )).notifier,
        );

        await notifier.dropChecklistNewItem(
          {'checklistItemTitle': 'Dropped Item', 'checklistItemStatus': false},
          categoryId: 'cat-1',
        );

        final state = container.read(
          checklistControllerProvider((
            id: 'checklist-1',
            taskId: 'task-1',
          )),
        );
        expect(
          state.value?.data.linkedChecklistItems,
          contains('dropped-item-1'),
        );
      });

      test(
        'does nothing when localData map has no checklistItemTitle',
        () async {
          final container = ProviderContainer(
            overrides: [
              journalRepositoryProvider.overrideWithValue(
                mockJournalRepository,
              ),
              checklistRepositoryProvider.overrideWithValue(
                mockChecklistRepository,
              ),
            ],
          );
          addTearDown(container.dispose);

          await container.read(
            checklistControllerProvider((
              id: 'checklist-1',
              taskId: 'task-1',
            )).future,
          );

          final notifier = container.read(
            checklistControllerProvider((
              id: 'checklist-1',
              taskId: 'task-1',
            )).notifier,
          );

          // Map without checklistItemTitle key
          await notifier.dropChecklistNewItem({'someOtherKey': 'value'});

          verifyNever(
            () => mockChecklistRepository.createChecklistItem(
              title: any(named: 'title'),
              isChecked: any(named: 'isChecked'),
              checklistId: any(named: 'checklistId'),
              categoryId: any(named: 'categoryId'),
            ),
          );
        },
      );

      test('does nothing when item creation returns null', () async {
        when(
          () => mockChecklistRepository.createChecklistItem(
            title: any(named: 'title'),
            isChecked: any(named: 'isChecked'),
            checklistId: any(named: 'checklistId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);

        final container = ProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
            checklistRepositoryProvider.overrideWithValue(
              mockChecklistRepository,
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(
          checklistControllerProvider((
            id: 'checklist-1',
            taskId: 'task-1',
          )).future,
        );

        final notifier = container.read(
          checklistControllerProvider((
            id: 'checklist-1',
            taskId: 'task-1',
          )).notifier,
        );

        await notifier.dropChecklistNewItem(
          {'checklistItemTitle': 'Dropped Item'},
        );

        // updateChecklist must not be called when creation fails
        verifyNever(
          () => mockChecklistRepository.updateChecklist(
            checklistId: any(named: 'checklistId'),
            data: any(named: 'data'),
          ),
        );
      });

      test(
        'dropChecklistItem delegates to dropChecklistNewItem for new items',
        () async {
          when(
            () => mockChecklistRepository.createChecklistItem(
              title: any(named: 'title'),
              isChecked: any(named: 'isChecked'),
              checklistId: any(named: 'checklistId'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer((_) async => makeCreatedItem('new-via-drop'));

          final container = ProviderContainer(
            overrides: [
              journalRepositoryProvider.overrideWithValue(
                mockJournalRepository,
              ),
              checklistRepositoryProvider.overrideWithValue(
                mockChecklistRepository,
              ),
            ],
          );
          addTearDown(container.dispose);

          await container.read(
            checklistControllerProvider((
              id: 'checklist-1',
              taskId: 'task-1',
            )).future,
          );

          final notifier = container.read(
            checklistControllerProvider((
              id: 'checklist-1',
              taskId: 'task-1',
            )).notifier,
          );

          // dropChecklistItem routes to dropChecklistNewItem when
          // 'checklistItemTitle' is present in localData
          await notifier.dropChecklistItem(
            {
              'checklistItemTitle': 'Dropped via route',
              'checklistItemStatus': true,
            },
            categoryId: 'cat-1',
          );

          final state = container.read(
            checklistControllerProvider((
              id: 'checklist-1',
              taskId: 'task-1',
            )),
          );
          expect(
            state.value?.data.linkedChecklistItems,
            contains('new-via-drop'),
          );
        },
      );
    });

    group('ChecklistCompletionController', () {
      late MockChecklistRepository mockChecklistRepository;

      ChecklistItem makeItem({
        required String id,
        required bool isChecked,
        bool isArchived = false,
        bool isDeleted = false,
      }) {
        final meta = Metadata(
          id: id,
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025),
          deletedAt: isDeleted ? DateTime(2025) : null,
        );
        return ChecklistItem(
          meta: meta,
          data: ChecklistItemData(
            title: id,
            isChecked: isChecked,
            linkedChecklists: const ['checklist-comp'],
            isArchived: isArchived,
          ),
        );
      }

      setUp(() {
        mockChecklistRepository = MockChecklistRepository();
        when(
          () => mockChecklistRepository.updateChecklist(
            checklistId: any(named: 'checklistId'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => true);
        when(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: any(named: 'checklistItemId'),
            data: any(named: 'data'),
            taskId: any(named: 'taskId'),
          ),
        ).thenAnswer((_) async => true);
      });

      /// Helper: build a [ProviderContainer] with the checklist and item
      /// controllers all warmed up so that [_computeState] sees resolved values.
      Future<ProviderContainer> buildCompletionContainer({
        required Checklist checklist,
        required List<String> itemIds,
      }) async {
        final container = ProviderContainer(
          overrides: [
            journalRepositoryProvider.overrideWithValue(mockJournalRepository),
            checklistRepositoryProvider.overrideWithValue(
              mockChecklistRepository,
            ),
          ],
        );
        addTearDown(container.dispose);

        // Warm up the checklist controller first so its state is resolved.
        await container.read(
          checklistControllerProvider((
            id: checklist.meta.id,
            taskId: null,
          )).future,
        );

        // Warm up every item controller so _computeState finds resolved values.
        for (final itemId in itemIds) {
          await container.read(
            checklistItemControllerProvider((
              id: itemId,
              taskId: null,
            )).future,
          );
        }

        return container;
      }

      test('computes correct completion counts from checklist items', () async {
        final checklist = Checklist(
          meta: Metadata(
            id: 'checklist-comp',
            createdAt: DateTime(2025),
            updatedAt: DateTime(2025),
            dateFrom: DateTime(2025),
            dateTo: DateTime(2025),
          ),
          data: const ChecklistData(
            title: 'Completion Test',
            linkedChecklistItems: ['item-a', 'item-b', 'item-c'],
            linkedTasks: [],
          ),
        );

        when(
          () => mockDb.journalEntityById('checklist-comp'),
        ).thenAnswer((_) async => checklist);
        when(
          () => mockDb.journalEntityById('item-a'),
        ).thenAnswer((_) async => makeItem(id: 'item-a', isChecked: true));
        when(
          () => mockDb.journalEntityById('item-b'),
        ).thenAnswer((_) async => makeItem(id: 'item-b', isChecked: false));
        when(
          () => mockDb.journalEntityById('item-c'),
        ).thenAnswer((_) async => makeItem(id: 'item-c', isChecked: true));

        final container = await buildCompletionContainer(
          checklist: checklist,
          itemIds: const ['item-a', 'item-b', 'item-c'],
        );

        final result = await container.read(
          checklistCompletionControllerProvider((
            id: 'checklist-comp',
            taskId: null,
          )).future,
        );

        expect(result.totalCount, 3);
        expect(result.completedCount, 2);
      });

      test('excludes archived and deleted items from counts', () async {
        final checklist = Checklist(
          meta: Metadata(
            id: 'checklist-comp',
            createdAt: DateTime(2025),
            updatedAt: DateTime(2025),
            dateFrom: DateTime(2025),
            dateTo: DateTime(2025),
          ),
          data: const ChecklistData(
            title: 'Filter Test',
            linkedChecklistItems: ['item-a', 'item-b', 'item-c'],
            linkedTasks: [],
          ),
        );

        when(
          () => mockDb.journalEntityById('checklist-comp'),
        ).thenAnswer((_) async => checklist);
        when(
          () => mockDb.journalEntityById('item-a'),
        ).thenAnswer((_) async => makeItem(id: 'item-a', isChecked: true));
        // item-b is archived
        when(
          () => mockDb.journalEntityById('item-b'),
        ).thenAnswer(
          (_) async =>
              makeItem(id: 'item-b', isChecked: true, isArchived: true),
        );
        // item-c is deleted
        when(
          () => mockDb.journalEntityById('item-c'),
        ).thenAnswer(
          (_) async => makeItem(id: 'item-c', isChecked: true, isDeleted: true),
        );

        final container = await buildCompletionContainer(
          checklist: checklist,
          itemIds: const ['item-a', 'item-b', 'item-c'],
        );

        final result = await container.read(
          checklistCompletionControllerProvider((
            id: 'checklist-comp',
            taskId: null,
          )).future,
        );

        // Only item-a is active and counted
        expect(result.totalCount, 1);
        expect(result.completedCount, 1);
      });

      test('returns zeros when checklist has no items', () async {
        final emptyChecklist = Checklist(
          meta: Metadata(
            id: 'checklist-comp',
            createdAt: DateTime(2025),
            updatedAt: DateTime(2025),
            dateFrom: DateTime(2025),
            dateTo: DateTime(2025),
          ),
          data: const ChecklistData(
            title: 'Empty',
            linkedChecklistItems: [],
            linkedTasks: [],
          ),
        );

        when(
          () => mockDb.journalEntityById('checklist-comp'),
        ).thenAnswer((_) async => emptyChecklist);

        final container = await buildCompletionContainer(
          checklist: emptyChecklist,
          itemIds: const [],
        );

        final result = await container.read(
          checklistCompletionControllerProvider((
            id: 'checklist-comp',
            taskId: null,
          )).future,
        );

        expect(result.totalCount, 0);
        expect(result.completedCount, 0);
      });
    });
  });
}
