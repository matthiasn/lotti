import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_item_data.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Exception('Fallback exception'));
    registerFallbackValue(StackTrace.empty);
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
    });

    group('getExistingChecklistCount', () {
      test('returns 0 for task with no checklists', () async {
        // Arrange
        final task = testTask;
        when(() => mockJournalDb.journalEntityById(task.meta.id))
            .thenAnswer((_) async => task);

        // Act
        final result = await service.getExistingChecklistCount(taskId: task.meta.id);

        // Assert
        expect(result, equals(0));
      });

      test('returns 0 when entity is not a task', () async {
        // Arrange
        final entry = testTextEntry;
        when(() => mockJournalDb.journalEntityById(entry.meta.id))
            .thenAnswer((_) async => entry);

        // Act
        final result = await service.getExistingChecklistCount(taskId: entry.meta.id);

        // Assert
        expect(result, equals(0));
      });
    });
  });
}
