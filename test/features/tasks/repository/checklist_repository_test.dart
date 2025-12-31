// ignore_for_file: inference_failure_on_function_invocation

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/services/task_summary_refresh_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

class MockLoggingService extends Mock implements LoggingService {}

class MockTaskSummaryRefreshService extends Mock
    implements TaskSummaryRefreshService {}

class _MockSelectable<T> extends Mock implements Selectable<T> {}

/// Provider to capture a real Ref for testing.
/// In Riverpod 3.x, Ref is sealed and cannot be mocked directly.
final testRefProvider = Provider<Ref>((ref) => ref);

void main() {
  late ChecklistRepository repository;
  late MockJournalDb mockJournalDb;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockLoggingService mockLoggingService;
  late MockTaskSummaryRefreshService mockTaskSummaryRefreshService;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(fallbackJournalEntity);
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
    mockLoggingService = MockLoggingService();
    mockTaskSummaryRefreshService = MockTaskSummaryRefreshService();

    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<LoggingService>(mockLoggingService);

    // Set up default behavior for the triggerTaskSummaryRefreshForChecklist method
    when(() =>
        mockTaskSummaryRefreshService.triggerTaskSummaryRefreshForChecklist(
          checklistId: any(named: 'checklistId'),
          callingDomain: any(named: 'callingDomain'),
        )).thenAnswer((_) async => {});

    // Create ProviderContainer with the mock service override
    container = ProviderContainer(
      overrides: [
        taskSummaryRefreshServiceProvider
            .overrideWithValue(mockTaskSummaryRefreshService),
      ],
    );
    final ref = container.read(testRefProvider);
    repository = ChecklistRepository(ref);
  });

  tearDown(() {
    container.dispose();
    getIt.reset();
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
      when(() => mockJournalDb.journalEntityById(taskId))
          .thenAnswer((_) async => null);

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
      when(() => mockJournalDb.journalEntityById(entryId))
          .thenAnswer((_) async => testTextEntry);

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
      expect(result.checklist, isNotNull);
      expect(result.checklist!.meta.id, equals(metadata.id));
      final checklist = result.checklist! as Checklist;
      expect(checklist.data.title, equals('TODOs'));
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
      expect(result.checklist, isNotNull);
      expect(result.createdItems, hasLength(items.length));
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
        () => mockLoggingService.captureException(
          any(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).thenAnswer((_) async => true);

      // Act
      final result = await repository.createChecklist(
        taskId: taskId,
        items: items,
      );

      // Assert
      expect(result.checklist, isNotNull);
      // Verify that the exception was caught
      verify(
        () => mockLoggingService.captureException(
          any(),
          domain: 'persistence_logic',
          subDomain: 'createChecklistEntry',
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);

      // The checklist was still created even though the items failed
      final createdChecklist = result.checklist;
      expect(createdChecklist, isNotNull);
      expect(
          (createdChecklist! as Checklist).data.linkedChecklistItems, isEmpty);
      expect(result.createdItems, isEmpty);
    });

    test('handles exceptions gracefully', () async {
      // Arrange
      final taskId = testTask.id;
      final exception = Exception('Test exception');

      when(() => mockJournalDb.journalEntityById(taskId)).thenThrow(exception);
      when(
        () => mockLoggingService.captureException(
          any(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).thenAnswer((_) async => true);

      // Act
      final result = await repository.createChecklist(taskId: taskId);

      // Assert
      expect(result.checklist, isNull);
      expect(result.createdItems, isEmpty);
      verify(
        () => mockLoggingService.captureException(
          exception,
          domain: 'persistence_logic',
          subDomain: 'createChecklistEntry',
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });

  group('completeChecklistItemsForTask', () {
    late ChecklistItem checklistItem;

    setUp(() {
      checklistItem = ChecklistItem(
        meta: testTask.meta.copyWith(id: 'item-1'),
        data: const ChecklistItemData(
          title: 'Item 1',
          isChecked: false,
          linkedChecklists: ['checklist-1'],
        ),
      );

      when(() => mockJournalDb.entriesForIds(any())).thenAnswer((invocation) {
        final ids = invocation.positionalArguments.first as List<String>;
        final rows = ids
            .map((id) {
              if (id == 'item-1') {
                return toDbEntity(checklistItem);
              }
              return null;
            })
            .whereType<JournalDbEntity>()
            .toList();

        // Create a mock Selectable that returns the rows when .get() is called
        final mockSelectable = _MockSelectable<JournalDbEntity>();
        when(mockSelectable.get).thenAnswer((_) async => rows);
        return mockSelectable;
      });
      when(() => mockJournalDb.journalEntityById(any())).thenAnswer(
        (invocation) async => invocation.positionalArguments.first == 'item-1'
            ? checklistItem
            : null,
      );

      when(() => mockPersistenceLogic.updateMetadata(any())).thenAnswer(
          (invocation) async => invocation.positionalArguments[0] as Metadata);
      when(() => mockPersistenceLogic.updateDbEntity(
            any(),
            linkedId: any(named: 'linkedId'),
          )).thenAnswer((_) async => true);
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

    test('handles task summary refresh errors gracefully', () async {
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

      // Configure the task summary refresh to throw an exception
      when(() =>
          mockTaskSummaryRefreshService.triggerTaskSummaryRefreshForChecklist(
            checklistId: checklistId,
            callingDomain: 'ChecklistRepository',
          )).thenThrow(Exception('Task summary refresh failed'));

      when(
        () => mockLoggingService.captureException(
          any(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
          stackTrace: any(named: 'stackTrace'),
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
      expect(result, isNotNull);
      expect(result!.meta.id, equals(metadata.id));
      expect(result.data.title, equals(title));
      expect(result.data.isChecked, equals(isChecked));
      expect(result.data.linkedChecklists, contains(checklistId));

      // Verify that the error was logged but the operation succeeded
      verify(
        () => mockLoggingService.captureException(
          any(that: isA<Exception>()),
          domain: 'ChecklistRepository',
          subDomain: '_triggerTaskSummaryRefresh',
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);

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
        () => mockLoggingService.captureException(
          any(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
          stackTrace: any(named: 'stackTrace'),
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
        () => mockLoggingService.captureException(
          exception,
          domain: 'persistence_logic',
          subDomain: 'createChecklistEntry',
          stackTrace: any(named: 'stackTrace'),
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
        () => mockLoggingService.captureException(
          any(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
          stackTrace: any(named: 'stackTrace'),
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
        () => mockLoggingService.captureException(
          'not a checklist',
          domain: 'persistence_logic',
          subDomain: 'updateChecklist',
          stackTrace: any(named: 'stackTrace'),
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
        () => mockLoggingService.captureException(
          any(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).thenAnswer((_) async => true);

      // Act
      final result = await repository.updateChecklist(
        checklistId: checklistId,
        data: data,
      );

      // Assert
      expect(result, isTrue);
      verify(
        () => mockLoggingService.captureException(
          exception,
          domain: 'persistence_logic',
          subDomain: 'updateChecklist',
          stackTrace: any(named: 'stackTrace'),
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

      when(() => mockJournalDb.journalEntityById(checklistItemId))
          .thenAnswer((_) async => null);

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
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: const ChecklistItemData(
          title: 'Original Item',
          isChecked: false,
          linkedChecklists: ['checklist-id'],
        ),
      );

      when(() => mockJournalDb.journalEntityById(checklistItemId))
          .thenAnswer((_) async => checklistItem);
      when(() => mockPersistenceLogic.updateMetadata(any()))
          .thenAnswer((_) async => checklistItem.meta);
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
      verify(() => mockPersistenceLogic.updateMetadata(checklistItem.meta))
          .called(1);
      verify(
        () => mockPersistenceLogic.updateDbEntity(any(), linkedId: 'task-id'),
      ).called(1);
    });

    test('handles task summary refresh errors during update', () async {
      // Arrange
      const checklistItemId = 'checklist-item-id';
      const oldChecklistId = 'old-checklist-id';
      const newChecklistId = 'new-checklist-id';
      const data = ChecklistItemData(
        title: 'Updated Item',
        isChecked: true,
        linkedChecklists: [newChecklistId],
      );

      final checklistItem = ChecklistItem(
        meta: Metadata(
          id: checklistItemId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: const ChecklistItemData(
          title: 'Original Item',
          isChecked: false,
          linkedChecklists: [oldChecklistId],
        ),
      );

      when(() => mockJournalDb.journalEntityById(checklistItemId))
          .thenAnswer((_) async => checklistItem);
      when(() => mockPersistenceLogic.updateMetadata(any()))
          .thenAnswer((_) async => checklistItem.meta);
      when(
        () => mockPersistenceLogic.updateDbEntity(
          any(),
          linkedId: any(named: 'linkedId'),
        ),
      ).thenAnswer((_) async => true);

      // Configure the task summary refresh to throw an exception
      when(() =>
          mockTaskSummaryRefreshService.triggerTaskSummaryRefreshForChecklist(
            checklistId: any(named: 'checklistId'),
            callingDomain: 'ChecklistRepository',
          )).thenThrow(Exception('Task summary refresh failed'));

      when(
        () => mockLoggingService.captureException(
          any(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
          stackTrace: any(named: 'stackTrace'),
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

      // Verify that the update succeeded despite the task summary refresh failure
      verify(() => mockJournalDb.journalEntityById(checklistItemId)).called(1);
      verify(() => mockPersistenceLogic.updateMetadata(checklistItem.meta))
          .called(1);
      verify(
        () => mockPersistenceLogic.updateDbEntity(any(), linkedId: 'task-id'),
      ).called(1);

      // Verify that errors were logged for both checklists
      verify(
        () => mockLoggingService.captureException(
          any(that: isA<Exception>()),
          domain: 'ChecklistRepository',
          subDomain: '_triggerTaskSummaryRefresh',
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(2); // Called for both old and new checklist IDs
    });

    test('handles non-checklist-item entity', () async {
      // Arrange
      final entryId = testTextEntry.id;
      const data = ChecklistItemData(
        title: 'Updated Item',
        isChecked: true,
        linkedChecklists: [],
      );

      when(() => mockJournalDb.journalEntityById(entryId))
          .thenAnswer((_) async => testTextEntry);
      when(
        () => mockLoggingService.captureException(
          any(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).thenAnswer((_) async => true);

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
        () => mockLoggingService.captureException(
          'not a checklist item',
          domain: 'persistence_logic',
          subDomain: 'updateChecklistItem',
          stackTrace: any(named: 'stackTrace'),
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

      when(() => mockJournalDb.journalEntityById(checklistItemId))
          .thenThrow(exception);
      when(
        () => mockLoggingService.captureException(
          any(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).thenAnswer((_) async => true);

      // Act
      final result = await repository.updateChecklistItem(
        checklistItemId: checklistItemId,
        data: data,
        taskId: null,
      );

      // Assert
      expect(result, isTrue);
      verify(
        () => mockLoggingService.captureException(
          exception,
          domain: 'persistence_logic',
          subDomain: 'updateChecklistItem',
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });

  group('addItemToChecklist', () {
    test('successfully creates item and updates checklist atomically',
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
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
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
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
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

      when(() => mockPersistenceLogic.createMetadata())
          .thenAnswer((_) async => newItem.meta);
      when(() => mockPersistenceLogic.createDbEntity(any()))
          .thenAnswer((_) async => true);
      when(() => mockJournalDb.journalEntityById(checklistId))
          .thenAnswer((_) async => checklist);
      when(() => mockPersistenceLogic.updateMetadata(any()))
          .thenAnswer((_) async => checklist.meta.copyWith(
                updatedAt: DateTime.now(),
              ));
      when(() => mockPersistenceLogic.updateDbEntity(any()))
          .thenAnswer((_) async => true);

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
      final capturedChecklist = verify(
        () => mockPersistenceLogic.updateDbEntity(captureAny()),
      ).captured.first as Checklist;

      expect(
        capturedChecklist.data.linkedChecklistItems,
        equals(['existing-item-1', 'existing-item-2', 'new-item-id']),
      );
    });

    test('handles task summary refresh errors in addItemToChecklist', () async {
      // Arrange
      const checklistId = 'checklist-id';
      const title = 'New Item';
      const isChecked = false;
      const categoryId = 'category-id';

      final checklist = Checklist(
        meta: Metadata(
          id: checklistId,
          categoryId: categoryId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          starred: false,
          private: false,
          utcOffset: 0,
          vectorClock: const VectorClock({}),
        ),
        data: const ChecklistData(
          title: 'Test Checklist',
          linkedChecklistItems: [],
          linkedTasks: ['task-1'],
        ),
      );

      final newItem = ChecklistItem(
        meta: Metadata(
          id: 'new-item-id',
          categoryId: categoryId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
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

      when(() => mockPersistenceLogic.createMetadata())
          .thenAnswer((_) async => newItem.meta);
      when(() => mockPersistenceLogic.createDbEntity(any()))
          .thenAnswer((_) async => true);
      when(() => mockJournalDb.journalEntityById(checklistId))
          .thenAnswer((_) async => checklist);
      when(() => mockPersistenceLogic.updateMetadata(any()))
          .thenAnswer((_) async => checklist.meta.copyWith(
                updatedAt: DateTime.now(),
              ));
      when(() => mockPersistenceLogic.updateDbEntity(any()))
          .thenAnswer((_) async => true);

      // Configure the task summary refresh to throw an exception
      when(() =>
          mockTaskSummaryRefreshService.triggerTaskSummaryRefreshForChecklist(
            checklistId: checklistId,
            callingDomain: 'ChecklistRepository',
          )).thenThrow(Exception('Task summary refresh failed'));

      when(
        () => mockLoggingService.captureException(
          any(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
          stackTrace: any(named: 'stackTrace'),
        ),
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

      // Verify that the error was logged but the operation succeeded
      verify(
        () => mockLoggingService.captureException(
          any(that: isA<Exception>()),
          domain: 'ChecklistRepository',
          subDomain: '_triggerTaskSummaryRefresh',
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(
          2); // Called twice: once in createChecklistItem and once in addItemToChecklist

      // Verify that all persistence operations succeeded
      verify(() => mockPersistenceLogic.createDbEntity(any())).called(1);
      verify(() => mockPersistenceLogic.updateDbEntity(any())).called(1);
    });

    test('returns null when checklist not found', () async {
      // Arrange
      const checklistId = 'non-existent-checklist-id';
      const title = 'New Item';
      const isChecked = false;
      const categoryId = 'category-id';

      final newItem = ChecklistItem(
        meta: Metadata(
          id: 'new-item-id',
          categoryId: categoryId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
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

      when(() => mockPersistenceLogic.createMetadata())
          .thenAnswer((_) async => newItem.meta);
      when(() => mockPersistenceLogic.createDbEntity(any()))
          .thenAnswer((_) async => true);
      when(() => mockJournalDb.journalEntityById(checklistId))
          .thenAnswer((_) async => null);
      when(
        () => mockLoggingService.captureException(
          any(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).thenAnswer((_) async => true);

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
        () => mockLoggingService.captureException(
          'Entity is not a checklist',
          domain: 'persistence_logic',
          subDomain: 'addItemToChecklist',
        ),
      ).called(1);
    });

    test('returns null when entity is not a checklist', () async {
      // Arrange
      const checklistId = 'task-id';
      const title = 'New Item';
      const isChecked = false;
      const categoryId = 'category-id';

      final task = Task(
        meta: Metadata(
          id: checklistId,
          categoryId: categoryId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          starred: false,
          private: false,
          utcOffset: 0,
          vectorClock: const VectorClock({}),
        ),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
      );

      final newItem = ChecklistItem(
        meta: Metadata(
          id: 'new-item-id',
          categoryId: categoryId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
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

      when(() => mockPersistenceLogic.createMetadata())
          .thenAnswer((_) async => newItem.meta);
      when(() => mockPersistenceLogic.createDbEntity(any()))
          .thenAnswer((_) async => true);
      when(() => mockJournalDb.journalEntityById(checklistId))
          .thenAnswer((_) async => task);
      when(
        () => mockLoggingService.captureException(
          any(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).thenAnswer((_) async => true);

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
        () => mockLoggingService.captureException(
          'Entity is not a checklist',
          domain: 'persistence_logic',
          subDomain: 'addItemToChecklist',
        ),
      ).called(1);
    });

    test('handles exceptions gracefully', () async {
      // Arrange
      const checklistId = 'checklist-id';
      const title = 'New Item';
      const isChecked = false;
      const categoryId = 'category-id';

      final exception = Exception('Test exception');

      when(() => mockPersistenceLogic.createMetadata()).thenThrow(exception);
      when(
        () => mockLoggingService.captureException(
          any(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).thenAnswer((_) async => true);

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
        () => mockLoggingService.captureException(
          exception,
          domain: 'persistence_logic',
          subDomain: 'createChecklistEntry',
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });
}
