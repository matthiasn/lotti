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
            )).thenAnswer((_) async => createdChecklist);

        // Act
        final result = await service.autoCreateChecklist(
          taskId: taskId,
          suggestions: suggestions,
        );

        // Assert
        expect(result.success, isTrue);
        expect(result.checklistId, equals('checklist-123'));
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
            )).thenAnswer((_) async => null);

        // Act
        final result = await service.autoCreateChecklist(
          taskId: taskId,
          suggestions: suggestions,
        );

        // Assert
        expect(result.success, isFalse);
        expect(result.checklistId, isNull);
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
    });

    group('getExistingChecklistCount', () {
      test('returns 0 for task with no checklists', () async {
        // Arrange
        final task = testTask;
        when(() => mockJournalDb.journalEntityById(task.meta.id))
            .thenAnswer((_) async => task);

        // Act
        final result =
            await service.getExistingChecklistCount(taskId: task.meta.id);

        // Assert
        expect(result, equals(0));
      });

      test('returns 0 when entity is not a task', () async {
        // Arrange
        final entry = testTextEntry;
        when(() => mockJournalDb.journalEntityById(entry.meta.id))
            .thenAnswer((_) async => entry);

        // Act
        final result =
            await service.getExistingChecklistCount(taskId: entry.meta.id);

        // Assert
        expect(result, equals(0));
      });
    });
  });
}
