import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  final testDate = DateTime(2024, 3, 15, 10, 30);

  late ChecklistRepository repository;
  late MockJournalDb mockJournalDb;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockDomainLogger mockDomainLogger;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(fallbackJournalEntity);
    registerFallbackValue(FakeMetadata());
    registerFallbackValue(FakeTaskData());
    registerFallbackValue(fallbackChecklist);
    registerFallbackValue(fallbackChecklistItem);
  });

  setUp(() async {
    mockJournalDb = MockJournalDb();
    mockPersistenceLogic = MockPersistenceLogic();
    mockDomainLogger = MockDomainLogger();

    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(mockJournalDb)
          ..unregister<DomainLogger>()
          ..registerSingleton<DomainLogger>(mockDomainLogger)
          ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);
      },
    );

    // Error logging is exercised by several failure-path tests; the stub is
    // identical everywhere so it lives here instead of 11 inline copies.
    when(
      () => mockDomainLogger.error(
        any<LogDomain>(),
        any(),
        stackTrace: any(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenAnswer((_) async => true);

    // Create ProviderContainer
    container = ProviderContainer();
    repository = ChecklistRepository();
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestGetIt();
  });

  group('createChecklist', () {
    test('returns null checklist when taskId is null', () async {
      // Act
      final result = await repository.createChecklist(taskId: null);

      // Assert
      expect(result.checklist, isNull);
      expect(result.createdItems, isEmpty);
      verifyNever(() => mockJournalDb.journalEntityById(any()));
    });

    test('returns null checklist when task not found', () async {
      // Arrange
      const taskId = 'non-existent-task-id';
      when(
        () => mockJournalDb.journalEntityById(taskId),
      ).thenAnswer((_) async => null);

      // Act
      final result = await repository.createChecklist(taskId: taskId);

      // Assert
      expect(result.checklist, isNull);
      expect(result.createdItems, isEmpty);
      verify(() => mockJournalDb.journalEntityById(taskId)).called(1);
    });

    test('returns null checklist when entity is not a Task', () async {
      // Arrange
      final entryId = testTextEntry.id;
      when(
        () => mockJournalDb.journalEntityById(entryId),
      ).thenAnswer((_) async => testTextEntry);

      // Act
      final result = await repository.createChecklist(taskId: entryId);

      // Assert
      expect(result.checklist, isNull);
      expect(result.createdItems, isEmpty);
      verify(() => mockJournalDb.journalEntityById(entryId)).called(1);
    });

    test('creates checklist successfully', () async {
      // Arrange
      final taskId = testTask.id;
      final metadata = testTask.meta.copyWith(id: 'new-checklist-id');

      when(
        () => mockJournalDb.journalEntityById(taskId),
      ).thenAnswer((_) async => testTask);
      when(
        () => mockPersistenceLogic.createMetadata(),
      ).thenAnswer((_) async => metadata);
      when(
        () => mockPersistenceLogic.createDbEntity(any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockPersistenceLogic.updateTask(
          journalEntityId: taskId,
          entryText: testTask.entryText,
          taskData: any(named: 'taskData'),
        ),
      ).thenAnswer((_) async => true);

      // Act
      final result = await repository.createChecklist(taskId: taskId);

      // Assert
      expect(result, isNotNull);
      expect(result.checklist, isNotNull);
      expect(result.checklist!.meta.id, equals(metadata.id));
      final checklist = result.checklist! as Checklist;
      expect(checklist.data.title, equals('Todos'));
      expect(checklist.data.linkedTasks, contains(taskId));
      expect(result.createdItems, isEmpty);

      verify(() => mockJournalDb.journalEntityById(taskId)).called(1);
      verify(() => mockPersistenceLogic.createMetadata()).called(1);
      verify(() => mockPersistenceLogic.createDbEntity(any())).called(1);
      verify(
        () => mockPersistenceLogic.updateTask(
          journalEntityId: taskId,
          entryText: testTask.entryText,
          taskData: any(named: 'taskData'),
        ),
      ).called(1);
    });

    test('creates checklist with items successfully', () async {
      // Arrange
      final taskId = testTask.id;
      final metadata = testTask.meta.copyWith(id: 'new-checklist-id');
      final checklistItemMetadata = testTask.meta.copyWith(
        id: 'checklist-item-id',
      );
      final items = [
        const ChecklistItemData(
          title: 'Item 1',
          isChecked: false,
          linkedChecklists: [],
        ),
        const ChecklistItemData(
          title: 'Item 2',
          isChecked: true,
          linkedChecklists: [],
        ),
      ];

      final checklist = Checklist(
        meta: metadata,
        data: ChecklistData(
          title: testTask.data.title,
          linkedChecklistItems: [],
          linkedTasks: [taskId],
        ),
      );

      when(
        () => mockJournalDb.journalEntityById(taskId),
      ).thenAnswer((_) async => testTask);
      when(
        () => mockPersistenceLogic.createMetadata(),
      ).thenAnswer((_) async => metadata);
      when(
        () => mockPersistenceLogic.createDbEntity(any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockPersistenceLogic.updateTask(
          journalEntityId: taskId,
          entryText: testTask.entryText,
          taskData: any(named: 'taskData'),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => mockPersistenceLogic.updateDbEntity(
          any(),
          linkedId: any(named: 'linkedId'),
        ),
      ).thenAnswer((_) async => true);

      // Mock the nested createChecklistItem call
      when(
        () => mockPersistenceLogic.createMetadata(),
      ).thenAnswer((_) async => checklistItemMetadata);

      // Mock the call to updateChecklist
      when(
        () => mockJournalDb.journalEntityById(metadata.id),
      ).thenAnswer((_) async => checklist);

      // Act
      final result = await repository.createChecklist(
        taskId: taskId,
        items: items,
      );

      // Assert
      expect(result.checklist, isNotNull);
      expect(result.createdItems, hasLength(items.length));
      verify(
        () => mockPersistenceLogic.createDbEntity(any()),
      ).called(greaterThan(1));
    });

    test('handles checklist items not being created', () async {
      // Arrange
      final taskId = testTask.id;
      final metadata = testTask.meta.copyWith(id: 'new-checklist-id');
      final items = [
        const ChecklistItemData(
          title: 'Item 1',
          isChecked: false,
          linkedChecklists: [],
        ),
      ];

      final checklist = Checklist(
        meta: metadata,
        data: ChecklistData(
          title: testTask.data.title,
          linkedChecklistItems: [],
          linkedTasks: [taskId],
        ),
      );

      when(
        () => mockJournalDb.journalEntityById(taskId),
      ).thenAnswer((_) async => testTask);

      // First createMetadata call will succeed (for the checklist)
      // But subsequent calls will throw (for checklist items)
      var createMetadataCallCount = 0;
      when(() => mockPersistenceLogic.createMetadata()).thenAnswer((_) {
        createMetadataCallCount++;
        if (createMetadataCallCount == 1) {
          return Future.value(metadata);
        } else {
          throw Exception('Failed to create metadata for item');
        }
      });

      when(
        () => mockPersistenceLogic.createDbEntity(any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockPersistenceLogic.updateTask(
          journalEntityId: taskId,
          entryText: testTask.entryText,
          taskData: any(named: 'taskData'),
        ),
      ).thenAnswer((_) async => true);

      when(
        () => mockJournalDb.journalEntityById(metadata.id),
      ).thenAnswer((_) async => checklist);

      // Act
      final result = await repository.createChecklist(
        taskId: taskId,
        items: items,
      );

      // Assert
      expect(result.checklist, isNotNull);
      // Verify that the exception was caught
      verify(
        () => mockDomainLogger.error(
          LogDomain.persistence,
          any(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'createChecklistEntry',
        ),
      ).called(1);

      // The checklist was still created even though the items failed
      final createdChecklist = result.checklist;
      expect(createdChecklist, isNotNull);
      expect(
        (createdChecklist! as Checklist).data.linkedChecklistItems,
        isEmpty,
      );
      expect(result.createdItems, isEmpty);
    });

    test('handles exceptions gracefully', () async {
      // Arrange
      final taskId = testTask.id;
      final exception = Exception('Test exception');

      when(() => mockJournalDb.journalEntityById(taskId)).thenThrow(exception);

      // Act
      final result = await repository.createChecklist(taskId: taskId);

      // Assert
      expect(result.checklist, isNull);
      expect(result.createdItems, isEmpty);
      verify(
        () => mockDomainLogger.error(
          LogDomain.persistence,
          exception,
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'createChecklistEntry',
        ),
      ).called(1);
    });
  });

  group('createChecklistItem', () {
    test('creates checklist item successfully', () async {
      // Arrange
      const checklistId = 'checklist-id';
      const title = 'Test Item';
      const isChecked = false;
      const categoryId = 'category-id';

      final metadata = Metadata(
        id: 'checklist-item-id',
        createdAt: testDate,
        updatedAt: testDate,
        categoryId: categoryId,
        dateFrom: testDate,
        dateTo: testDate,
      );

      when(
        () => mockPersistenceLogic.createMetadata(),
      ).thenAnswer((_) async => metadata);
      when(
        () => mockPersistenceLogic.createDbEntity(any()),
      ).thenAnswer((_) async => true);

      // Act
      final result = await repository.createChecklistItem(
        checklistId: checklistId,
        title: title,
        isChecked: isChecked,
        categoryId: categoryId,
      );

      // Assert
      expect(result, isNotNull);
      expect(result!.meta.id, equals(metadata.id));
      expect(result.data.title, equals(title));
      expect(result.data.isChecked, equals(isChecked));
      expect(result.data.linkedChecklists, contains(checklistId));

      verify(() => mockPersistenceLogic.createMetadata()).called(1);
      verify(() => mockPersistenceLogic.createDbEntity(any())).called(1);
    });

    test('handles exceptions gracefully', () async {
      // Arrange
      const checklistId = 'checklist-id';
      const title = 'Test Item';
      const isChecked = false;
      const categoryId = 'category-id';

      final exception = Exception('Test exception');

      when(() => mockPersistenceLogic.createMetadata()).thenThrow(exception);

      // Act
      final result = await repository.createChecklistItem(
        checklistId: checklistId,
        title: title,
        isChecked: isChecked,
        categoryId: categoryId,
      );

      // Assert
      expect(result, isNull);
      verify(
        () => mockDomainLogger.error(
          LogDomain.persistence,
          exception,
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'createChecklistEntry',
        ),
      ).called(1);
    });

    test('passes checkedBy and checkedAt to created item', () async {
      const checklistId = 'checklist-id';
      const title = 'Agent Item';
      const categoryId = 'category-id';
      final checkedAt = DateTime(2025, 6, 15);

      final metadata = Metadata(
        id: 'agent-item-id',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
        categoryId: categoryId,
        dateFrom: DateTime(2025),
        dateTo: DateTime(2025),
      );

      when(
        () => mockPersistenceLogic.createMetadata(),
      ).thenAnswer((_) async => metadata);
      when(
        () => mockPersistenceLogic.createDbEntity(any()),
      ).thenAnswer((_) async => true);

      final result = await repository.createChecklistItem(
        checklistId: checklistId,
        title: title,
        isChecked: false,
        categoryId: categoryId,
        checkedBy: ChangeSource.agent,
        checkedAt: checkedAt,
      );

      expect(result, isNotNull);
      expect(result!.data.checkedBy, ChangeSource.agent);
      expect(result.data.checkedAt, checkedAt);

      // Verify the entity persisted has the correct provenance
      final captured =
          verify(
                () => mockPersistenceLogic.createDbEntity(captureAny()),
              ).captured.single
              as ChecklistItem;
      expect(captured.data.checkedBy, ChangeSource.agent);
      expect(captured.data.checkedAt, checkedAt);
    });
  });

  group('updateChecklist', () {
    test('returns false when checklist not found', () async {
      // Arrange
      const checklistId = 'non-existent-checklist-id';
      const data = ChecklistData(
        title: 'Updated Title',
        linkedChecklistItems: [],
        linkedTasks: [],
      );

      when(
        () => mockJournalDb.journalEntityById(checklistId),
      ).thenAnswer((_) async => null);

      // Act
      final result = await repository.updateChecklist(
        checklistId: checklistId,
        data: data,
      );

      // Assert
      expect(result, isFalse);
      verify(() => mockJournalDb.journalEntityById(checklistId)).called(1);
    });

    test('returns true when checklist is updated successfully', () async {
      // Arrange
      const checklistId = 'checklist-id';
      const data = ChecklistData(
        title: 'Updated Title',
        linkedChecklistItems: [],
        linkedTasks: [],
      );

      final checklist = Checklist(
        meta: Metadata(
          id: checklistId,
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
        ),
        data: const ChecklistData(
          title: 'Original Title',
          linkedChecklistItems: [],
          linkedTasks: [],
        ),
      );

      when(
        () => mockJournalDb.journalEntityById(checklistId),
      ).thenAnswer((_) async => checklist);
      when(
        () => mockPersistenceLogic.updateMetadata(any()),
      ).thenAnswer((_) async => checklist.meta);
      when(
        () => mockPersistenceLogic.updateDbEntity(any()),
      ).thenAnswer((_) async => true);

      // Act
      final result = await repository.updateChecklist(
        checklistId: checklistId,
        data: data,
      );

      // Assert
      expect(result, isTrue);
      verify(() => mockJournalDb.journalEntityById(checklistId)).called(1);
      verify(
        () => mockPersistenceLogic.updateMetadata(checklist.meta),
      ).called(1);
      verify(() => mockPersistenceLogic.updateDbEntity(any())).called(1);
    });

    test('handles non-checklist entity', () async {
      // Arrange
      final entryId = testTextEntry.id;
      const data = ChecklistData(
        title: 'Updated Title',
        linkedChecklistItems: [],
        linkedTasks: [],
      );

      when(
        () => mockJournalDb.journalEntityById(entryId),
      ).thenAnswer((_) async => testTextEntry);

      // Act
      final result = await repository.updateChecklist(
        checklistId: entryId,
        data: data,
      );

      // Assert — deliberate API asymmetry: updateChecklist returns false
      // only when the entity is *missing*; a wrong-typed entity logs the
      // error but still returns true (the orElse branch falls through to
      // the unconditional `return true`). Callers treat "found but wrong
      // type" as non-retriable, unlike "not found".
      expect(result, isTrue);
      verify(() => mockJournalDb.journalEntityById(entryId)).called(1);
      verify(
        () => mockDomainLogger.error(
          LogDomain.persistence,
          'not a checklist',
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'updateChecklist',
        ),
      ).called(1);
    });

    test('handles exceptions gracefully', () async {
      // Arrange
      const checklistId = 'checklist-id';
      const data = ChecklistData(
        title: 'Updated Title',
        linkedChecklistItems: [],
        linkedTasks: [],
      );

      final exception = Exception('Test exception');

      when(
        () => mockJournalDb.journalEntityById(checklistId),
      ).thenThrow(exception);

      // Act
      final result = await repository.updateChecklist(
        checklistId: checklistId,
        data: data,
      );

      // Assert
      expect(result, isTrue);
      verify(
        () => mockDomainLogger.error(
          LogDomain.persistence,
          exception,
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'updateChecklist',
        ),
      ).called(1);
    });
  });

  group('updateChecklistItem', () {
    test('returns false when checklist item not found', () async {
      // Arrange
      const checklistItemId = 'non-existent-item-id';
      const data = ChecklistItemData(
        title: 'Updated Item',
        isChecked: true,
        linkedChecklists: [],
      );

      when(
        () => mockJournalDb.journalEntityById(checklistItemId),
      ).thenAnswer((_) async => null);

      // Act
      final result = await repository.updateChecklistItem(
        checklistItemId: checklistItemId,
        data: data,
        taskId: null,
      );

      // Assert
      expect(result, isFalse);
      verify(() => mockJournalDb.journalEntityById(checklistItemId)).called(1);
    });

    test('returns true when checklist item is updated successfully', () async {
      // Arrange
      const checklistItemId = 'checklist-item-id';
      const data = ChecklistItemData(
        title: 'Updated Item',
        isChecked: true,
        linkedChecklists: ['checklist-id'],
      );

      final checklistItem = ChecklistItem(
        meta: Metadata(
          id: checklistItemId,
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
        ),
        data: const ChecklistItemData(
          title: 'Original Item',
          isChecked: false,
          linkedChecklists: ['checklist-id'],
        ),
      );

      when(
        () => mockJournalDb.journalEntityById(checklistItemId),
      ).thenAnswer((_) async => checklistItem);
      when(
        () => mockPersistenceLogic.updateMetadata(any()),
      ).thenAnswer((_) async => checklistItem.meta);
      when(
        () => mockPersistenceLogic.updateDbEntity(
          any(),
          linkedId: any(named: 'linkedId'),
        ),
      ).thenAnswer((_) async => true);

      // Act
      final result = await repository.updateChecklistItem(
        checklistItemId: checklistItemId,
        data: data,
        taskId: 'task-id',
      );

      // Assert
      expect(result, isTrue);
      verify(() => mockJournalDb.journalEntityById(checklistItemId)).called(1);
      verify(
        () => mockPersistenceLogic.updateMetadata(checklistItem.meta),
      ).called(1);
      verify(
        () => mockPersistenceLogic.updateDbEntity(any(), linkedId: 'task-id'),
      ).called(1);
    });

    test('handles non-checklist-item entity', () async {
      // Arrange
      final entryId = testTextEntry.id;
      const data = ChecklistItemData(
        title: 'Updated Item',
        isChecked: true,
        linkedChecklists: [],
      );

      when(
        () => mockJournalDb.journalEntityById(entryId),
      ).thenAnswer((_) async => testTextEntry);

      // Act
      final result = await repository.updateChecklistItem(
        checklistItemId: entryId,
        data: data,
        taskId: null,
      );

      // Assert
      expect(result, isTrue);
      verify(() => mockJournalDb.journalEntityById(entryId)).called(1);
      verify(
        () => mockDomainLogger.error(
          LogDomain.persistence,
          'not a checklist item',
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'updateChecklistItem',
        ),
      ).called(1);
    });

    test('handles exceptions gracefully', () async {
      // Arrange
      const checklistItemId = 'checklist-item-id';
      const data = ChecklistItemData(
        title: 'Updated Item',
        isChecked: true,
        linkedChecklists: [],
      );

      final exception = Exception('Test exception');

      when(
        () => mockJournalDb.journalEntityById(checklistItemId),
      ).thenThrow(exception);

      // Act
      final result = await repository.updateChecklistItem(
        checklistItemId: checklistItemId,
        data: data,
        taskId: null,
      );

      // Assert
      expect(result, isTrue);
      verify(
        () => mockDomainLogger.error(
          LogDomain.persistence,
          exception,
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'updateChecklistItem',
        ),
      ).called(1);
    });
  });

  group('addItemToChecklist', () {
    test(
      'successfully creates item and updates checklist atomically',
      () async {
        // Arrange
        const checklistId = 'checklist-id';
        const title = 'New Item';
        const isChecked = false;
        const categoryId = 'category-id';

        final checklist = Checklist(
          meta: Metadata(
            id: checklistId,
            categoryId: categoryId,
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
            starred: false,
            private: false,
            utcOffset: 0,
            vectorClock: const VectorClock({}),
          ),
          data: const ChecklistData(
            title: 'Test Checklist',
            linkedChecklistItems: ['existing-item-1', 'existing-item-2'],
            linkedTasks: ['task-1'],
          ),
        );

        final newItem = ChecklistItem(
          meta: Metadata(
            id: 'new-item-id',
            categoryId: categoryId,
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
            starred: false,
            private: false,
            utcOffset: 0,
            vectorClock: const VectorClock({}),
          ),
          data: const ChecklistItemData(
            title: title,
            isChecked: isChecked,
            linkedChecklists: [checklistId],
          ),
        );

        when(
          () => mockPersistenceLogic.createMetadata(),
        ).thenAnswer((_) async => newItem.meta);
        when(
          () => mockPersistenceLogic.createDbEntity(any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockJournalDb.journalEntityById(checklistId),
        ).thenAnswer((_) async => checklist);
        when(() => mockPersistenceLogic.updateMetadata(any())).thenAnswer(
          (_) async => checklist.meta.copyWith(
            updatedAt: testDate,
          ),
        );
        when(
          () => mockPersistenceLogic.updateDbEntity(any()),
        ).thenAnswer((_) async => true);

        // Act
        final result = await repository.addItemToChecklist(
          checklistId: checklistId,
          title: title,
          isChecked: isChecked,
          categoryId: categoryId,
        );

        // Assert
        expect(result, isNotNull);
        expect(result!.data.title, equals(title));
        expect(result.data.isChecked, equals(isChecked));

        // Verify that the checklist was updated with the new item
        final capturedChecklist =
            verify(
                  () => mockPersistenceLogic.updateDbEntity(captureAny()),
                ).captured.first
                as Checklist;

        expect(
          capturedChecklist.data.linkedChecklistItems,
          equals(['existing-item-1', 'existing-item-2', 'new-item-id']),
        );
      },
    );

    // Stubs metadata/db-entity creation for the path-terminates-early error
    // cases; only the entity returned for the checklist lookup varies.
    void stubCreateItem({
      required String checklistId,
      required JournalEntity? lookedUpEntity,
    }) {
      final meta = Metadata(
        id: 'new-item-id',
        categoryId: 'category-id',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
        starred: false,
        private: false,
        utcOffset: 0,
        vectorClock: const VectorClock({}),
      );
      when(
        () => mockPersistenceLogic.createMetadata(),
      ).thenAnswer((_) async => meta);
      when(
        () => mockPersistenceLogic.createDbEntity(any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockJournalDb.journalEntityById(checklistId),
      ).thenAnswer((_) async => lookedUpEntity);
    }

    Task buildNonChecklistEntity(String id) => Task(
      meta: Metadata(
        id: id,
        categoryId: 'category-id',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
        starred: false,
        private: false,
        utcOffset: 0,
        vectorClock: const VectorClock({}),
      ),
      data: TaskData(
        status: TaskStatus.open(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
        title: 'Test Task',
        statusHistory: [],
        dateFrom: testDate,
        dateTo: testDate,
      ),
    );

    for (final (description, lookedUpFor) in [
      ('returns null when checklist not found', null),
      ('returns null when entity is not a checklist', 'task'),
    ]) {
      test(description, () async {
        const checklistId = 'lookup-id';
        stubCreateItem(
          checklistId: checklistId,
          lookedUpEntity: lookedUpFor == null
              ? null
              : buildNonChecklistEntity(checklistId),
        );

        final result = await repository.addItemToChecklist(
          checklistId: checklistId,
          title: 'New Item',
          isChecked: false,
          categoryId: 'category-id',
        );

        expect(result, isNull);
        verify(
          () => mockDomainLogger.error(
            LogDomain.persistence,
            'Entity is not a checklist',
            subDomain: 'addItemToChecklist',
          ),
        ).called(1);
      });
    }

    test(
      'successfully creates item and updates checklist atomically',
      () async {
        // Arrange
        const checklistId = 'checklist-id';
        const title = 'New Item';
        const isChecked = false;
        const categoryId = 'category-id';

        final checklist = Checklist(
          meta: Metadata(
            id: checklistId,
            categoryId: categoryId,
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
            starred: false,
            private: false,
            utcOffset: 0,
            vectorClock: const VectorClock({}),
          ),
          data: const ChecklistData(
            title: 'Test Checklist',
            linkedChecklistItems: ['existing-item-1', 'existing-item-2'],
            linkedTasks: ['task-1'],
          ),
        );

        final newItem = ChecklistItem(
          meta: Metadata(
            id: 'new-item-id',
            categoryId: categoryId,
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
            starred: false,
            private: false,
            utcOffset: 0,
            vectorClock: const VectorClock({}),
          ),
          data: const ChecklistItemData(
            title: title,
            isChecked: isChecked,
            linkedChecklists: [checklistId],
          ),
        );

        when(
          () => mockPersistenceLogic.createMetadata(),
        ).thenAnswer((_) async => newItem.meta);
        when(
          () => mockPersistenceLogic.createDbEntity(any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockJournalDb.journalEntityById(checklistId),
        ).thenAnswer((_) async => checklist);
        when(() => mockPersistenceLogic.updateMetadata(any())).thenAnswer(
          (_) async => checklist.meta.copyWith(
            updatedAt: testDate,
          ),
        );
        when(
          () => mockPersistenceLogic.updateDbEntity(any()),
        ).thenAnswer((_) async => true);

        // Act
        final result = await repository.addItemToChecklist(
          checklistId: checklistId,
          title: title,
          isChecked: isChecked,
          categoryId: categoryId,
        );

        // Assert
        expect(result, isNotNull);
        expect(result!.data.title, equals(title));
        expect(result.data.isChecked, equals(isChecked));

        // Verify that the checklist was updated with the new item
        final capturedChecklist =
            verify(
                  () => mockPersistenceLogic.updateDbEntity(captureAny()),
                ).captured.first
                as Checklist;

        expect(
          capturedChecklist.data.linkedChecklistItems,
          equals(['existing-item-1', 'existing-item-2', 'new-item-id']),
        );
      },
    );

    test('handles exceptions gracefully', () async {
      // Arrange
      const checklistId = 'checklist-id';
      const title = 'New Item';
      const isChecked = false;
      const categoryId = 'category-id';

      final exception = Exception('Test exception');

      when(() => mockPersistenceLogic.createMetadata()).thenThrow(exception);

      // Act
      final result = await repository.addItemToChecklist(
        checklistId: checklistId,
        title: title,
        isChecked: isChecked,
        categoryId: categoryId,
      );

      // Assert
      expect(result, isNull);
      verify(
        () => mockDomainLogger.error(
          LogDomain.persistence,
          exception,
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'createChecklistEntry',
        ),
      ).called(1);
    });
  });

  group('getChecklistItemsForTask', () {
    // Verifies the post-558ms-slow-query rewrite: the function used to
    // scan every ChecklistItem in the journal and filter in Dart. The
    // new shape issues two indexed bulk-by-id lookups: first the
    // parent Checklists, then their `linkedChecklistItems` ids.
    final taskMeta = Metadata(
      id: 'task-1',
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate,
    );

    Task buildTaskWithChecklists(List<String> checklistIds) => Task(
      meta: taskMeta,
      data: TaskData(
        status: TaskStatus.open(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
        title: 'Task',
        statusHistory: const [],
        dateFrom: testDate,
        dateTo: testDate,
        checklistIds: checklistIds,
      ),
    );

    Checklist buildChecklist(String id, List<String> linkedItemIds) =>
        Checklist(
          meta: Metadata(
            id: id,
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
          ),
          data: ChecklistData(
            title: 'cl-$id',
            linkedChecklistItems: linkedItemIds,
            linkedTasks: const [],
          ),
        );

    ChecklistItem buildItem({
      required String id,
      required DateTime dateFrom,
      DateTime? deletedAt,
      List<String> linkedChecklists = const ['checklist-1'],
    }) {
      return ChecklistItem(
        meta: Metadata(
          id: id,
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: dateFrom,
          dateTo: dateFrom,
          deletedAt: deletedAt,
        ),
        data: ChecklistItemData(
          title: 'item-$id',
          isChecked: false,
          linkedChecklists: linkedChecklists,
        ),
      );
    }

    void stubByIds(Map<String, JournalEntity> byId) {
      when(
        () => mockJournalDb.journalEntitiesByIdsUnorderedAllPrivate(any()),
      ).thenAnswer((invocation) {
        final ids = invocation.positionalArguments.first as List<String>;
        final rows = ids
            .map((id) => byId[id])
            .whereType<JournalEntity>()
            .map(toDbEntity)
            .toList();
        return MockSelectable<JournalDbEntity>(rows);
      });
    }

    test('returns empty list when the task has no checklist ids', () async {
      final task = buildTaskWithChecklists(const []);

      final result = await repository.getChecklistItemsForTask(task: task);

      expect(result, isEmpty);
      verifyNever(
        () => mockJournalDb.journalEntitiesByIdsUnorderedAllPrivate(any()),
      );
    });

    test(
      'fetches parent checklists then their items via two bulk lookups, '
      'filtering soft-deleted items and sorting by dateFrom desc',
      () async {
        final checklist = buildChecklist('checklist-1', [
          'item-old',
          'item-new',
          'item-deleted',
        ]);
        final newer = buildItem(
          id: 'item-new',
          dateFrom: DateTime(2024, 6, 15),
        );
        final older = buildItem(
          id: 'item-old',
          dateFrom: DateTime(2024, 1, 15),
        );
        final deleted = buildItem(
          id: 'item-deleted',
          dateFrom: DateTime(2024, 5, 15),
          deletedAt: DateTime(2024, 5, 16),
        );
        stubByIds({
          'checklist-1': checklist,
          'item-new': newer,
          'item-old': older,
          'item-deleted': deleted,
        });

        final task = buildTaskWithChecklists(const ['checklist-1']);
        final result = await repository.getChecklistItemsForTask(task: task);

        expect(result.map((i) => i.meta.id), ['item-new', 'item-old']);
        // Two indexed bulk-by-id lookups (parent checklists, then
        // their items) — the prior shape did one global type-scan.
        verify(
          () => mockJournalDb.journalEntitiesByIdsUnorderedAllPrivate(any()),
        ).called(2);
      },
    );

    test(
      'returns empty list when none of the parent checklists are found',
      () async {
        stubByIds(const <String, JournalEntity>{});
        final task = buildTaskWithChecklists(const ['missing-checklist']);

        final result = await repository.getChecklistItemsForTask(task: task);

        expect(result, isEmpty);
        // Only the parent checklists were looked up — without item
        // ids to fetch, the second bulk read is skipped.
        verify(
          () => mockJournalDb.journalEntitiesByIdsUnorderedAllPrivate(any()),
        ).called(1);
      },
    );

    test(
      'logs and skips a parent checklist row whose serialized JSON is '
      'malformed instead of propagating the throw — a corrupt persisted '
      'row should not poison the entire fetch',
      () async {
        final corruptRow = JournalDbEntity(
          id: 'checklist-corrupt',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
          deleted: false,
          starred: false,
          private: false,
          task: false,
          flag: 0,
          type: 'Checklist',
          serialized: 'this is not json',
          schemaVersion: 0,
          category: '',
        );
        when(
          () => mockJournalDb.journalEntitiesByIdsUnorderedAllPrivate(any()),
        ).thenAnswer((_) {
          return MockSelectable<JournalDbEntity>([corruptRow]);
        });

        final task = buildTaskWithChecklists(const ['checklist-corrupt']);
        final result = await repository.getChecklistItemsForTask(task: task);

        expect(result, isEmpty);
        verify(
          () => mockDomainLogger.error(
            any<LogDomain>(),
            any(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'getChecklistItemsForTask',
          ),
        ).called(1);
        // No items recovered means the second bulk read is skipped.
        verify(
          () => mockJournalDb.journalEntitiesByIdsUnorderedAllPrivate(any()),
        ).called(1);
      },
    );

    test(
      'logs and skips a corrupt ITEM row from the second bulk read while '
      'still returning the intact items',
      () async {
        final checklist = buildChecklist('cl-1', const [
          'item-good',
          'item-corrupt',
        ]);
        final goodItem = ChecklistItem(
          meta: Metadata(
            id: 'item-good',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
          ),
          data: const ChecklistItemData(
            title: 'Good item',
            isChecked: false,
            linkedChecklists: ['cl-1'],
          ),
        );
        final corruptItemRow = JournalDbEntity(
          id: 'item-corrupt',
          createdAt: testDate,
          updatedAt: testDate,
          dateFrom: testDate,
          dateTo: testDate,
          deleted: false,
          starred: false,
          private: false,
          task: false,
          flag: 0,
          type: 'ChecklistItem',
          serialized: '{not valid json either',
          schemaVersion: 0,
          category: '',
        );

        when(
          () => mockJournalDb.journalEntitiesByIdsUnorderedAllPrivate(any()),
        ).thenAnswer((invocation) {
          final ids = invocation.positionalArguments.first as List<String>;
          if (ids.contains('cl-1')) {
            return MockSelectable<JournalDbEntity>([toDbEntity(checklist)]);
          }
          return MockSelectable<JournalDbEntity>([
            toDbEntity(goodItem),
            corruptItemRow,
          ]);
        });

        final task = buildTaskWithChecklists(const ['cl-1']);
        final result = await repository.getChecklistItemsForTask(task: task);

        // The corrupt row is skipped and logged; the intact item survives.
        expect(result.map((i) => i.meta.id), ['item-good']);
        verify(
          () => mockDomainLogger.error(
            any<LogDomain>(),
            any(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'getChecklistItemsForTask',
          ),
        ).called(1);
      },
    );
  });
}
