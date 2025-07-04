// ignore_for_file: inference_failure_on_function_invocation

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/lotti_logger.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

class MockLottiLogger extends Mock implements LottiLogger {}

void main() {
  late ChecklistRepository repository;
  late MockJournalDb mockJournalDb;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockLottiLogger mockLottiLogger;

  setUpAll(() {
    registerFallbackValue(FakeJournalEntity());
    registerFallbackValue(FakeMetadata());
    registerFallbackValue(FakeTaskData());
    registerFallbackValue(
      Checklist(
        meta: Metadata(
          id: 'test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: const ChecklistData(
          title: 'Test Checklist',
          linkedChecklistItems: [],
          linkedTasks: [],
        ),
      ),
    );
    registerFallbackValue(
      ChecklistItem(
        meta: Metadata(
          id: 'test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: const ChecklistItemData(
          title: 'Test Item',
          isChecked: false,
          linkedChecklists: [],
        ),
      ),
    );
  });

  setUp(() {
    mockJournalDb = MockJournalDb();
    mockPersistenceLogic = MockPersistenceLogic();
    mockLottiLogger = MockLottiLogger();

    if (getIt.isRegistered<LottiLogger>()) {
      getIt.unregister<LottiLogger>();
    }
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
    if (getIt.isRegistered<PersistenceLogic>()) {
      getIt.unregister<PersistenceLogic>();
    }
    
    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<LottiLogger>(mockLottiLogger);

    repository = ChecklistRepository();
  });

  tearDown(() {
    if (getIt.isRegistered<LottiLogger>()) {
      getIt.unregister<LottiLogger>();
    }
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
    if (getIt.isRegistered<PersistenceLogic>()) {
      getIt.unregister<PersistenceLogic>();
    }
  });

  group('createChecklist', () {
    test('returns null when taskId is null', () async {
      // Act
      final result = await repository.createChecklist(taskId: null);

      // Assert
      expect(result, isNull);
      verifyNever(() => mockJournalDb.journalEntityById(any()));
    });

    test('returns null when task not found', () async {
      // Arrange
      const taskId = 'non-existent-task-id';
      when(() => mockJournalDb.journalEntityById(taskId))
          .thenAnswer((_) async => null);

      // Act
      final result = await repository.createChecklist(taskId: taskId);

      // Assert
      expect(result, isNull);
      verify(() => mockJournalDb.journalEntityById(taskId)).called(1);
    });

    test('returns null when entity is not a Task', () async {
      // Arrange
      final entryId = testTextEntry.id;
      when(() => mockJournalDb.journalEntityById(entryId))
          .thenAnswer((_) async => testTextEntry);

      // Act
      final result = await repository.createChecklist(taskId: entryId);

      // Assert
      expect(result, isNull);
      verify(() => mockJournalDb.journalEntityById(entryId)).called(1);
    });

    test('creates checklist successfully', () async {
      // Arrange
      final taskId = testTask.id;
      final metadata = testTask.meta.copyWith(id: 'new-checklist-id');

      when(() => mockJournalDb.journalEntityById(taskId))
          .thenAnswer((_) async => testTask);
      when(() => mockPersistenceLogic.createMetadata())
          .thenAnswer((_) async => metadata);
      when(() => mockPersistenceLogic.createDbEntity(any()))
          .thenAnswer((_) async => true);
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
      expect(result!.meta.id, equals(metadata.id));
      expect((result as Checklist).data.title, equals('TODOs'));
      expect(result.data.linkedTasks, contains(taskId));

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
      final checklistItemMetadata =
          testTask.meta.copyWith(id: 'checklist-item-id');
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

      when(() => mockJournalDb.journalEntityById(taskId))
          .thenAnswer((_) async => testTask);
      when(() => mockPersistenceLogic.createMetadata())
          .thenAnswer((_) async => metadata);
      when(() => mockPersistenceLogic.createDbEntity(any()))
          .thenAnswer((_) async => true);
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
      when(() => mockPersistenceLogic.createMetadata())
          .thenAnswer((_) async => checklistItemMetadata);

      // Mock the call to updateChecklist
      when(() => mockJournalDb.journalEntityById(metadata.id))
          .thenAnswer((_) async => checklist);

      // Act
      final result = await repository.createChecklist(
        taskId: taskId,
        items: items,
      );

      // Assert
      expect(result, isNotNull);
      verify(() => mockPersistenceLogic.createDbEntity(any()))
          .called(greaterThan(1));
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

      when(() => mockJournalDb.journalEntityById(taskId))
          .thenAnswer((_) async => testTask);

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

      when(() => mockPersistenceLogic.createDbEntity(any()))
          .thenAnswer((_) async => true);
      when(
        () => mockPersistenceLogic.updateTask(
          journalEntityId: taskId,
          entryText: testTask.entryText,
          taskData: any(named: 'taskData'),
        ),
      ).thenAnswer((_) async => true);

      when(() => mockJournalDb.journalEntityById(metadata.id))
          .thenAnswer((_) async => checklist);

      when(
        () => mockLottiLogger.exception(
          any(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).thenAnswer((_) async => true);

      // Act
      final result = await repository.createChecklist(
        taskId: taskId,
        items: items,
      );

      // Assert
      expect(result, isNotNull);
      // Verify that the exception was caught
      verify(
        () => mockLottiLogger.exception(
          any(),
          domain: 'persistence_logic',
          subDomain: 'createChecklistEntry',
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).called(1);

      // The checklist was still created even though the items failed
      expect((result as Checklist?)?.data.linkedChecklistItems, isEmpty);
    });

    test('handles exceptions gracefully', () async {
      // Arrange
      final taskId = testTask.id;
      final exception = Exception('Test exception');

      when(() => mockJournalDb.journalEntityById(taskId)).thenThrow(exception);
      when(
        () => mockLottiLogger.exception(
          any(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).thenAnswer((_) async => true);

      // Act
      final result = await repository.createChecklist(taskId: taskId);

      // Assert
      expect(result, isNull);
      verify(
        () => mockLottiLogger.exception(
          exception,
          domain: 'persistence_logic',
          subDomain: 'createChecklistEntry',
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
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
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        categoryId: categoryId,
        dateFrom: DateTime.now(),
        dateTo: DateTime.now(),
      );

      when(() => mockPersistenceLogic.createMetadata())
          .thenAnswer((_) async => metadata);
      when(() => mockPersistenceLogic.createDbEntity(any()))
          .thenAnswer((_) async => true);

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
      when(
        () => mockLottiLogger.exception(
          any(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).thenAnswer((_) async => true);

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
        () => mockLottiLogger.exception(
          exception,
          domain: 'persistence_logic',
          subDomain: 'createChecklistEntry',
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).called(1);
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

      when(() => mockJournalDb.journalEntityById(checklistId))
          .thenAnswer((_) async => null);

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
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: const ChecklistData(
          title: 'Original Title',
          linkedChecklistItems: [],
          linkedTasks: [],
        ),
      );

      when(() => mockJournalDb.journalEntityById(checklistId))
          .thenAnswer((_) async => checklist);
      when(() => mockPersistenceLogic.updateMetadata(any()))
          .thenAnswer((_) async => checklist.meta);
      when(() => mockPersistenceLogic.updateDbEntity(any()))
          .thenAnswer((_) async => true);

      // Act
      final result = await repository.updateChecklist(
        checklistId: checklistId,
        data: data,
      );

      // Assert
      expect(result, isTrue);
      verify(() => mockJournalDb.journalEntityById(checklistId)).called(1);
      verify(() => mockPersistenceLogic.updateMetadata(checklist.meta))
          .called(1);
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

      when(() => mockJournalDb.journalEntityById(entryId))
          .thenAnswer((_) async => testTextEntry);
      when(
        () => mockLottiLogger.exception(
          any(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).thenAnswer((_) async => true);

      // Act
      final result = await repository.updateChecklist(
        checklistId: entryId,
        data: data,
      );

      // Assert
      expect(result, isTrue);
      verify(() => mockJournalDb.journalEntityById(entryId)).called(1);
      verify(
        () => mockLottiLogger.exception(
          'not a checklist',
          domain: 'persistence_logic',
          subDomain: 'updateChecklist',
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
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

      when(() => mockJournalDb.journalEntityById(checklistId))
          .thenThrow(exception);
      when(
        () => mockLottiLogger.exception(
          any(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).thenAnswer((_) async => true);

      // Act
      final result = await repository.updateChecklist(
        checklistId: checklistId,
        data: data,
      );

      // Assert
      expect(result, isFalse);
      verify(
        () => mockLottiLogger.exception(
          exception,
          domain: 'persistence_logic',
          subDomain: 'updateChecklist',
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });
}
