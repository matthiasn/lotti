import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/services/auto_checklist_service.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

class MockChecklistRepository extends Mock implements ChecklistRepository {}

class MockLoggingService extends Mock implements LoggingService {}

class FakeChecklistItemData extends Fake implements ChecklistItemData {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Exception('Fallback exception'));
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(FakeChecklistItemData());
  });

  group('AutoChecklistService Tests', () {
    late AutoChecklistService service;
    late MockChecklistRepository mockChecklistRepository;
    late MockLoggingService mockLoggingService;
    late MockJournalDb mockJournalDb;

    setUp(() {
      mockChecklistRepository = MockChecklistRepository();
      mockLoggingService = MockLoggingService();
      mockJournalDb = MockJournalDb();

      // Register mock services with GetIt
      getIt
        ..reset()
        ..registerSingleton<ChecklistRepository>(mockChecklistRepository)
        ..registerSingleton<LoggingService>(mockLoggingService)
        ..registerSingleton<JournalDb>(mockJournalDb);

      service = AutoChecklistService(
        journalDb: mockJournalDb,
        loggingService: mockLoggingService,
        checklistRepository: mockChecklistRepository,
      );
    });

    group('shouldAutoCreate', () {
      test('returns true when task has no existing checklists', () async {
        // Arrange
        final task = testTask;
        when(() => mockJournalDb.journalEntityById(task.meta.id))
            .thenAnswer((_) async => task);

        // Act
        final result = await service.shouldAutoCreate(taskId: task.meta.id);

        // Assert
        expect(result, isTrue);
      });

      test('returns false when entity is not a task', () async {
        // Arrange
        final entry = testTextEntry;
        when(() => mockJournalDb.journalEntityById(entry.meta.id))
            .thenAnswer((_) async => entry);

        // Act
        final result = await service.shouldAutoCreate(taskId: entry.meta.id);

        // Assert
        expect(result, isFalse);
      });

      test('returns false and logs error when exception occurs', () async {
        // Arrange
        const taskId = 'test-task-id';
        when(() => mockJournalDb.journalEntityById(taskId))
            .thenThrow(Exception('Database error'));

        // Act
        final result = await service.shouldAutoCreate(taskId: taskId);

        // Assert
        expect(result, isFalse);
        verify(() => mockLoggingService.captureException(
              any<Exception>(),
              domain: 'auto_checklist_service',
              subDomain: 'shouldAutoCreate',
              stackTrace: any<StackTrace>(named: 'stackTrace'),
            )).called(1);
      });
    });

    group('autoCreateChecklist', () {
      test('fails when no suggestions provided', () async {
        // Arrange
        const taskId = 'test-task-id';
        final suggestions = <ChecklistItemData>[];

        // Act
        final result = await service.autoCreateChecklist(
          taskId: taskId,
          suggestions: suggestions,
        );

        // Assert
        expect(result.success, isFalse);
        expect(result.checklistId, isNull);
        expect(result.createdItems, isNull);
        expect(result.error, equals('No suggestions provided'));
      });

      test(
          'succeeds when checklist is created correctly when shouldAutoCreate is true',
          () async {
        // Arrange
        const taskId = 'test-task-id';
        final task = testTask.copyWith(
          data: testTask.data.copyWith(checklistIds: []),
        );
        final suggestions = [
          const ChecklistItemData(
            title: 'Review code',
            isChecked: false,
            linkedChecklists: [],
          ),
          const ChecklistItemData(
            title: 'Write tests',
            isChecked: true,
            linkedChecklists: [],
          ),
        ];
        final createdChecklist = JournalEntity.checklist(
          meta: Metadata(
            id: 'checklist-123',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            starred: false,
            flag: EntryFlag.none,
          ),
          data: const ChecklistData(
            title: 'TODOs',
            linkedChecklistItems: ['item-1', 'item-2'],
            linkedTasks: [taskId],
          ),
        );

        when(() => mockJournalDb.journalEntityById(taskId))
            .thenAnswer((_) async => task);
        when(() => mockChecklistRepository.createChecklist(
              taskId: taskId,
              items: any(named: 'items'),
              title: 'TODOs',
            )).thenAnswer((_) async => (
              checklist: createdChecklist,
              createdItems: [
                (id: 'item-1', title: 'Review code', isChecked: false),
                (id: 'item-2', title: 'Write tests', isChecked: true),
              ],
            ));

        // Act
        final result = await service.autoCreateChecklist(
          taskId: taskId,
          suggestions: suggestions,
        );

        // Assert
        expect(result.success, isTrue);
        expect(result.checklistId, equals('checklist-123'));
        expect(result.createdItems?.length, equals(2));
        expect(result.createdItems?[0].title, equals('Review code'));
        expect(result.createdItems?[1].title, equals('Write tests'));
        expect(result.error, isNull);
        verify(() => mockChecklistRepository.createChecklist(
              taskId: taskId,
              items: suggestions,
              title: 'TODOs',
            )).called(1);
        verify(() => mockLoggingService.captureEvent(
              'auto_checklist_created: taskId=$taskId, checklistId=checklist-123, itemCount=2',
              domain: 'auto_checklist_service',
              subDomain: 'autoCreateChecklist',
            )).called(1);
      });

      test(
          'fails when shouldAutoCreate returns false (i.e., checklists already exist)',
          () async {
        // Arrange
        const taskId = 'test-task-id';
        final task = testTask.copyWith(
          data: testTask.data.copyWith(checklistIds: ['existing-checklist']),
        );
        final suggestions = [
          const ChecklistItemData(
            title: 'Review code',
            isChecked: false,
            linkedChecklists: [],
          ),
        ];

        when(() => mockJournalDb.journalEntityById(taskId))
            .thenAnswer((_) async => task);

        // Act
        final result = await service.autoCreateChecklist(
          taskId: taskId,
          suggestions: suggestions,
        );

        // Assert
        expect(result.success, isFalse);
        expect(result.checklistId, isNull);
        expect(result.createdItems, isNull);
        expect(result.error, equals('Checklists already exist'));
        verifyNever(() => mockChecklistRepository.createChecklist(
              taskId: any(named: 'taskId'),
              items: any(named: 'items'),
              title: any(named: 'title'),
            ));
      });

      test(
          'fails when _checklistRepository.createChecklist returns null (failure to create)',
          () async {
        // Arrange
        const taskId = 'test-task-id';
        final task = testTask.copyWith(
          data: testTask.data.copyWith(checklistIds: []),
        );
        final suggestions = [
          const ChecklistItemData(
            title: 'Review code',
            isChecked: false,
            linkedChecklists: [],
          ),
        ];

        when(() => mockJournalDb.journalEntityById(taskId))
            .thenAnswer((_) async => task);
        when(() => mockChecklistRepository.createChecklist(
              taskId: taskId,
              items: any(named: 'items'),
              title: 'TODOs',
            )).thenAnswer((_) async => (
              checklist: null,
              createdItems: <({String id, String title, bool isChecked})>[],
            ));

        // Act
        final result = await service.autoCreateChecklist(
          taskId: taskId,
          suggestions: suggestions,
        );

        // Assert
        expect(result.success, isFalse);
        expect(result.checklistId, isNull);
        expect(result.createdItems, isNull);
        expect(result.error, equals('Failed to create checklist'));
        verify(() => mockChecklistRepository.createChecklist(
              taskId: taskId,
              items: suggestions,
              title: 'TODOs',
            )).called(1);
      });

      test(
          'fails when _checklistRepository.createChecklist throws an exception',
          () async {
        // Arrange
        const taskId = 'test-task-id';
        final task = testTask.copyWith(
          data: testTask.data.copyWith(checklistIds: []),
        );
        final suggestions = [
          const ChecklistItemData(
            title: 'Review code',
            isChecked: false,
            linkedChecklists: [],
          ),
        ];
        final exception = Exception('Database connection failed');

        when(() => mockJournalDb.journalEntityById(taskId))
            .thenAnswer((_) async => task);
        when(() => mockChecklistRepository.createChecklist(
              taskId: taskId,
              items: any(named: 'items'),
              title: 'TODOs',
            )).thenThrow(exception);

        // Act
        final result = await service.autoCreateChecklist(
          taskId: taskId,
          suggestions: suggestions,
        );

        // Assert
        expect(result.success, isFalse);
        expect(result.checklistId, isNull);
        expect(result.error, equals('Exception: Database connection failed'));
        verify(() => mockChecklistRepository.createChecklist(
              taskId: taskId,
              items: suggestions,
              title: 'TODOs',
            )).called(1);
        verify(() => mockLoggingService.captureException(
              exception,
              domain: 'auto_checklist_service',
              subDomain: 'autoCreateChecklist',
              stackTrace: any<StackTrace>(named: 'stackTrace'),
            )).called(1);
      });

      test('calls shouldAutoCreate to check if auto-creation is allowed',
          () async {
        // Arrange
        const taskId = 'test-task-id';
        final task = testTask.copyWith(
          data: testTask.data.copyWith(checklistIds: ['existing-checklist']),
        );
        final suggestions = [
          const ChecklistItemData(
            title: 'Review code',
            isChecked: false,
            linkedChecklists: [],
          ),
        ];

        when(() => mockJournalDb.journalEntityById(taskId))
            .thenAnswer((_) async => task);

        // Act
        final result = await service.autoCreateChecklist(
          taskId: taskId,
          suggestions: suggestions,
        );

        // Assert
        expect(result.success, isFalse);
        expect(result.error, equals('Checklists already exist'));

        // Verify that shouldAutoCreate was called (line 58 in the source)
        // This happens implicitly through the internal call but verifies the flow
        verify(() => mockJournalDb.journalEntityById(taskId)).called(1);
      });

      test('succeeds with custom title and logs success event', () async {
        // Arrange
        const taskId = 'test-task-id';
        const customTitle = 'Custom Checklist Title';
        final task = testTask.copyWith(
          data: testTask.data.copyWith(checklistIds: []),
        );
        final suggestions = [
          const ChecklistItemData(
            title: 'Review code',
            isChecked: false,
            linkedChecklists: [],
          ),
          const ChecklistItemData(
            title: 'Write tests',
            isChecked: true,
            linkedChecklists: [],
          ),
        ];
        final createdChecklist = JournalEntity.checklist(
          meta: Metadata(
            id: 'checklist-456',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            starred: false,
            flag: EntryFlag.none,
          ),
          data: const ChecklistData(
            title: customTitle,
            linkedChecklistItems: ['item-1', 'item-2'],
            linkedTasks: [taskId],
          ),
        );

        when(() => mockJournalDb.journalEntityById(taskId))
            .thenAnswer((_) async => task);
        when(() => mockChecklistRepository.createChecklist(
              taskId: taskId,
              items: any(named: 'items'),
              title: customTitle,
            )).thenAnswer((invocation) async {
          final items = (invocation.namedArguments[#items] as List)
              .cast<ChecklistItemData>();
          final created = <({String id, String title, bool isChecked})>[
            if (items.isNotEmpty)
              (
                id: 'item-1',
                title: items[0].title,
                isChecked: items[0].isChecked
              ),
            if (items.length > 1)
              (
                id: 'item-2',
                title: items[1].title,
                isChecked: items[1].isChecked
              ),
          ];
          return (checklist: createdChecklist, createdItems: created);
        });

        // Act
        final result = await service.autoCreateChecklist(
          taskId: taskId,
          suggestions: suggestions,
          title: customTitle,
        );

        // Assert
        expect(result.success, isTrue);
        expect(result.checklistId, equals('checklist-456'));
        expect(result.createdItems?.length, equals(2));
        expect(result.createdItems?[0].title, equals('Review code'));
        expect(result.createdItems?[1].title, equals('Write tests'));
        expect(result.error, isNull);

        // Verify checklist creation with custom title
        verify(() => mockChecklistRepository.createChecklist(
              taskId: taskId,
              items: suggestions,
              title: customTitle,
            )).called(1);

        // Verify success logging (lines 81-85 in source)
        verify(() => mockLoggingService.captureEvent(
              'auto_checklist_created: taskId=$taskId, checklistId=checklist-456, itemCount=2',
              domain: 'auto_checklist_service',
              subDomain: 'autoCreateChecklist',
            )).called(1);

        // Verify success return (line 87 in source)
        expect(result.success, isTrue);
        expect(result.checklistId, equals('checklist-456'));
        expect(result.error, isNull);
      });

      test(
          'succeeds with shouldAutoCreate parameter set to true (optimized path)',
          () async {
        // Arrange
        const taskId = 'test-task-id';
        final suggestions = [
          const ChecklistItemData(
            title: 'Review code',
            isChecked: false,
            linkedChecklists: [],
          ),
        ];
        final createdChecklist = JournalEntity.checklist(
          meta: Metadata(
            id: 'checklist-optimized',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            starred: false,
            flag: EntryFlag.none,
          ),
          data: const ChecklistData(
            title: 'TODOs',
            linkedChecklistItems: ['item-1'],
            linkedTasks: [taskId],
          ),
        );

        when(() => mockChecklistRepository.createChecklist(
              taskId: taskId,
              items: any(named: 'items'),
              title: 'TODOs',
            )).thenAnswer((invocation) async {
          final items = (invocation.namedArguments[#items] as List)
              .cast<ChecklistItemData>();
          final created = <({String id, String title, bool isChecked})>[
            if (items.isNotEmpty)
              (
                id: 'item-1',
                title: items[0].title,
                isChecked: items[0].isChecked
              ),
          ];
          return (checklist: createdChecklist, createdItems: created);
        });

        // Act - pass shouldAutoCreate as true to skip database lookup
        final result = await service.autoCreateChecklist(
          taskId: taskId,
          suggestions: suggestions,
          shouldAutoCreate: true,
        );

        // Assert
        expect(result.success, isTrue);
        expect(result.checklistId, equals('checklist-optimized'));
        expect(result.error, isNull);

        // Verify that journalEntityById was NOT called (optimized path)
        verifyNever(() => mockJournalDb.journalEntityById(taskId));

        // Verify checklist creation was called
        verify(() => mockChecklistRepository.createChecklist(
              taskId: taskId,
              items: suggestions,
              title: 'TODOs',
            )).called(1);
      });

      test('fails when shouldAutoCreate parameter is false', () async {
        // Arrange
        const taskId = 'test-task-id';
        final suggestions = [
          const ChecklistItemData(
            title: 'Review code',
            isChecked: false,
            linkedChecklists: [],
          ),
        ];

        // Act - pass shouldAutoCreate as false
        final result = await service.autoCreateChecklist(
          taskId: taskId,
          suggestions: suggestions,
          shouldAutoCreate: false,
        );

        // Assert
        expect(result.success, isFalse);
        expect(result.checklistId, isNull);
        expect(result.createdItems, isNull);
        expect(result.error, equals('Checklists already exist'));

        // Verify that journalEntityById was NOT called (optimized path)
        verifyNever(() => mockJournalDb.journalEntityById(taskId));

        // Verify checklist creation was NOT called
        verifyNever(() => mockChecklistRepository.createChecklist(
              taskId: any(named: 'taskId'),
              items: any(named: 'items'),
              title: any(named: 'title'),
            ));
      });

      test(
          'verifies item ordering is preserved and items are returned with IDs',
          () async {
        // This test verifies that:
        // 1. Items are created in the exact order they are provided
        // 2. The created items are returned with their generated IDs
        //
        // With the new robust solution, LottiBatchChecklistHandler no longer
        // needs to rely on fragile index-based mapping. Instead, it directly
        // uses the returned items with their IDs.

        // Arrange
        const taskId = 'test-task-id';
        final task = testTask.copyWith(
          data: testTask.data.copyWith(checklistIds: []),
        );

        // Create items with specific ordering to verify preservation
        final orderedSuggestions = [
          const ChecklistItemData(
            title: 'First item - should be at index 0',
            isChecked: false,
            linkedChecklists: [],
          ),
          const ChecklistItemData(
            title: 'Second item - should be at index 1',
            isChecked: true,
            linkedChecklists: [],
          ),
          const ChecklistItemData(
            title: 'Third item - should be at index 2',
            isChecked: false,
            linkedChecklists: [],
          ),
          const ChecklistItemData(
            title: 'Fourth item - should be at index 3',
            isChecked: true,
            linkedChecklists: [],
          ),
        ];

        final createdChecklist = JournalEntity.checklist(
          meta: Metadata(
            id: 'checklist-ordered',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            starred: false,
            flag: EntryFlag.none,
          ),
          data: const ChecklistData(
            title: 'TODOs',
            // Critical: These IDs must be in the exact order of creation
            linkedChecklistItems: ['item-0', 'item-1', 'item-2', 'item-3'],
            linkedTasks: [taskId],
          ),
        );

        when(() => mockJournalDb.journalEntityById(taskId))
            .thenAnswer((_) async => task);
        when(() => mockChecklistRepository.createChecklist(
              taskId: taskId,
              items: any(named: 'items'),
              title: 'TODOs',
            )).thenAnswer((invocation) async {
          final items = (invocation.namedArguments[#items] as List)
              .cast<ChecklistItemData>();
          // Critical: Return items in the exact order they were provided
          final created = <({String id, String title, bool isChecked})>[];
          for (var i = 0; i < items.length; i++) {
            created.add((
              id: 'item-$i',
              title: items[i].title,
              isChecked: items[i].isChecked,
            ));
          }
          return (checklist: createdChecklist, createdItems: created);
        });

        // Act
        final result = await service.autoCreateChecklist(
          taskId: taskId,
          suggestions: orderedSuggestions,
        );

        // Assert
        expect(result.success, isTrue);
        expect(result.checklistId, equals('checklist-ordered'));

        // NEW: Verify the robust solution returns items with IDs directly
        expect(result.createdItems?.length, equals(4));
        expect(result.createdItems?[0].id, equals('item-0'));
        expect(result.createdItems?[0].title,
            equals('First item - should be at index 0'));
        expect(result.createdItems?[1].id, equals('item-1'));
        expect(result.createdItems?[1].title,
            equals('Second item - should be at index 1'));
        expect(result.createdItems?[2].id, equals('item-2'));
        expect(result.createdItems?[2].title,
            equals('Third item - should be at index 2'));
        expect(result.createdItems?[3].id, equals('item-3'));
        expect(result.createdItems?[3].title,
            equals('Fourth item - should be at index 3'));

        // Verify the items were passed in the correct order
        final captured = verify(() => mockChecklistRepository.createChecklist(
              taskId: taskId,
              items: captureAny(named: 'items'),
              title: 'TODOs',
            )).captured;

        final capturedItems = captured.first as List<ChecklistItemData>;
        expect(capturedItems.length, equals(4));

        // Critical assertions: verify ordering is preserved
        expect(capturedItems[0].title,
            equals('First item - should be at index 0'));
        expect(capturedItems[1].title,
            equals('Second item - should be at index 1'));
        expect(capturedItems[2].title,
            equals('Third item - should be at index 2'));
        expect(capturedItems[3].title,
            equals('Fourth item - should be at index 3'));

        // Verify isChecked values are also preserved
        expect(capturedItems[0].isChecked, false);
        expect(capturedItems[1].isChecked, true);
        expect(capturedItems[2].isChecked, false);
        expect(capturedItems[3].isChecked, true);

        // The created checklist should have IDs in the same order
        // This is what LottiBatchChecklistHandler depends on
        final checklist = createdChecklist as Checklist;
        expect(
          checklist.data.linkedChecklistItems.length,
          equals(orderedSuggestions.length),
        );
        expect(checklist.data.linkedChecklistItems[0], equals('item-0'));
        expect(checklist.data.linkedChecklistItems[1], equals('item-1'));
        expect(checklist.data.linkedChecklistItems[2], equals('item-2'));
        expect(checklist.data.linkedChecklistItems[3], equals('item-3'));
      });
    });
  });
}
