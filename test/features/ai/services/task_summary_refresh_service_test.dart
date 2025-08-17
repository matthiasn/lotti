import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/services/task_summary_refresh_service.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalRepository extends Mock implements JournalRepository {}

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  late ProviderContainer container;
  late MockJournalRepository mockJournalRepository;
  late MockLoggingService mockLoggingService;

  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(StackTrace.current);
  });

  setUp(() {
    mockJournalRepository = MockJournalRepository();
    mockLoggingService = MockLoggingService();

    // Register mock in GetIt
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    getIt.registerSingleton<LoggingService>(mockLoggingService);

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
  });

  group('TaskSummaryRefreshService', () {
    test('should handle checklist with linked tasks', () async {
      final service = container.read(taskSummaryRefreshServiceProvider);

      final mockChecklist = Checklist(
        meta: Metadata(
          id: 'checklist-1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: const ChecklistData(
          title: 'Test Checklist',
          linkedChecklistItems: [],
          linkedTasks: ['task-1', 'task-2', 'task-3'],
        ),
      );

      when(() => mockJournalRepository.getJournalEntityById('checklist-1'))
          .thenAnswer((_) async => mockChecklist);

      // Should complete without errors
      await expectLater(
        service.triggerTaskSummaryRefreshForChecklist(
          checklistId: 'checklist-1',
          callingDomain: 'TestDomain',
        ),
        completes,
      );

      // Verify that the repository was called
      verify(() => mockJournalRepository.getJournalEntityById('checklist-1'))
          .called(1);
    });

    test('should handle non-checklist entities gracefully', () async {
      final service = container.read(taskSummaryRefreshServiceProvider);

      // Return a non-checklist entity
      final mockTask = Task(
        meta: Metadata(
          id: 'task-1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: TaskData(
          title: 'Test Task',
          status: TaskStatus.open(
            createdAt: DateTime.now(),
            id: 'status-1',
            utcOffset: 0,
          ),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          statusHistory: const [],
        ),
      );

      when(() => mockJournalRepository.getJournalEntityById('checklist-1'))
          .thenAnswer((_) async => mockTask);

      await expectLater(
        service.triggerTaskSummaryRefreshForChecklist(
          checklistId: 'checklist-1',
          callingDomain: 'TestDomain',
        ),
        completes,
      );
    });

    test('should handle null entity gracefully', () async {
      final service = container.read(taskSummaryRefreshServiceProvider);

      when(() => mockJournalRepository.getJournalEntityById('checklist-1'))
          .thenAnswer((_) async => null);

      await expectLater(
        service.triggerTaskSummaryRefreshForChecklist(
          checklistId: 'checklist-1',
          callingDomain: 'TestDomain',
        ),
        completes,
      );
    });

    test('should handle exceptions and log them', () async {
      final service = container.read(taskSummaryRefreshServiceProvider);

      final testException = Exception('Test error');

      when(() => mockJournalRepository.getJournalEntityById('checklist-1'))
          .thenThrow(testException);

      when(() => mockLoggingService.captureException(
            any<dynamic>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          )).thenAnswer((_) {});

      // Should not throw
      await expectLater(
        service.triggerTaskSummaryRefreshForChecklist(
          checklistId: 'checklist-1',
          callingDomain: 'TestDomain',
        ),
        completes,
      );

      // Verify error was logged
      verify(() => mockLoggingService.captureException(
            testException,
            domain: 'TestDomain',
            subDomain: 'triggerTaskSummaryRefreshForChecklist',
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          )).called(1);
    });

    test('should handle empty linked tasks list', () async {
      final service = container.read(taskSummaryRefreshServiceProvider);

      final mockChecklist = Checklist(
        meta: Metadata(
          id: 'checklist-1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: const ChecklistData(
          title: 'Test Checklist',
          linkedChecklistItems: [],
          linkedTasks: [], // Empty list
        ),
      );

      when(() => mockJournalRepository.getJournalEntityById('checklist-1'))
          .thenAnswer((_) async => mockChecklist);

      await expectLater(
        service.triggerTaskSummaryRefreshForChecklist(
          checklistId: 'checklist-1',
          callingDomain: 'TestDomain',
        ),
        completes,
      );
    });
  });
}
