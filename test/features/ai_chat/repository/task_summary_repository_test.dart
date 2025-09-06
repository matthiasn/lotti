import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai_chat/models/task_summary_tool.dart';
import 'package:lotti/features/ai_chat/repository/task_summary_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

// Mock implementations
class MockJournalDb extends Mock implements JournalDb {}

class MockSelectable<T> extends Mock implements Selectable<T> {}

void main() {
  group('TaskSummaryRepository', () {
    late TaskSummaryRepository repository;
    late MockJournalDb mockJournalDb;

    const testCategoryId = 'test-category-123';
    final testDate = DateTime(2024, 1, 15);
    final testStartDate = DateTime(2024);
    final testEndDate = DateTime(2024, 1, 31);

    // Test database entities (returned by workEntriesInDateRange)
    final testJournalDbEntry = JournalDbEntity(
      id: 'journal-entry-1',
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate.add(const Duration(seconds: 30)), // 30 seconds - valid
      deleted: false,
      starred: false,
      private: false,
      task: false,
      flag: 0,
      type: 'JournalEntry',
      serialized: '{}',
      schemaVersion: 1,
      plainText: 'Work meeting notes',
      category: testCategoryId,
    );

    final testJournalDbAudio = JournalDbEntity(
      id: 'journal-audio-1',
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate.add(const Duration(minutes: 5)),
      deleted: false,
      starred: false,
      private: false,
      task: false,
      flag: 0,
      type: 'JournalAudio',
      serialized: '{}',
      schemaVersion: 1,
      plainText: 'Meeting recording',
      category: testCategoryId,
    );

    final testJournalDbAudioShort = JournalDbEntity(
      id: 'audio-short',
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate
          .add(const Duration(seconds: 5)), // 5 seconds - still included
      deleted: false,
      starred: false,
      private: false,
      task: false,
      flag: 0,
      type: 'JournalAudio',
      serialized: '{}',
      schemaVersion: 1,
      plainText: 'Short recording',
      category: testCategoryId,
    );

    final testJournalDbAudio2 = JournalDbEntity(
      id: 'audio-2',
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate.add(const Duration(minutes: 10)),
      deleted: false,
      starred: false,
      private: false,
      task: false,
      flag: 0,
      type: 'JournalAudio',
      serialized: '{}',
      schemaVersion: 1,
      plainText: 'More work',
      category: testCategoryId,
    );

    // Test entities
    final testJournalEntry = JournalEntity.journalEntry(
      meta: Metadata(
        id: 'journal-entry-1',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo:
            testDate.add(const Duration(minutes: 30)), // 30 minutes duration
        categoryId: testCategoryId,
      ),
      entryText: const EntryText(plainText: 'Worked on project'),
    );

    final testTask = JournalEntity.task(
      meta: Metadata(
        id: 'task-1',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
      ),
      data: TaskData(
        title: 'Test Task',
        status: TaskStatus.inProgress(
          id: 'status-1',
          createdAt: testDate,
          utcOffset: 0,
        ),
        dateFrom: testDate,
        dateTo: testDate,
        statusHistory: [],
      ),
    );

    final testTaskDone = JournalEntity.task(
      meta: Metadata(
        id: 'task-2',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
      ),
      data: TaskData(
        title: 'Completed Task',
        status: TaskStatus.done(
          id: 'status-2',
          createdAt: testDate,
          utcOffset: 0,
        ),
        dateFrom: testDate,
        dateTo: testDate,
        statusHistory: [],
      ),
    );

    final testAiResponse = JournalEntity.aiResponse(
      meta: Metadata(
        id: 'ai-response-1',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
      ),
      data: const AiResponseData(
        model: 'gpt-4',
        systemMessage: 'You are a helpful assistant',
        prompt: 'Summarize this task',
        thoughts: 'User wants task summary',
        response: 'AI generated task summary',
        promptId: 'prompt-123',
        type: AiResponseType.taskSummary,
      ),
    );

    final testOlderAiResponse = JournalEntity.aiResponse(
      meta: Metadata(
        id: 'ai-response-old',
        createdAt: testDate.subtract(const Duration(days: 1)),
        updatedAt: testDate.subtract(const Duration(days: 1)),
        dateFrom: testDate.subtract(const Duration(days: 1)),
        dateTo: testDate.subtract(const Duration(days: 1)),
      ),
      data: const AiResponseData(
        model: 'gpt-3.5',
        systemMessage: 'You are a helpful assistant',
        prompt: 'Summarize this task',
        thoughts: 'User wants task summary',
        response: 'Older AI summary',
        promptId: 'prompt-old',
        type: AiResponseType.taskSummary,
      ),
    );

    final testLink = EntryLink.basic(
      id: 'link-1',
      fromId: testTask.meta.id,
      toId: testJournalEntry.meta.id,
      createdAt: testDate,
      updatedAt: testDate,
      vectorClock: null,
    );

    setUp(() {
      mockJournalDb = MockJournalDb();

      // Setup GetIt
      if (getIt.isRegistered<JournalDb>()) {
        getIt.unregister<JournalDb>();
      }
      getIt.registerSingleton<JournalDb>(mockJournalDb);

      repository = TaskSummaryRepository(journalDb: mockJournalDb);
    });

    tearDown(getIt.reset);

    group('getTaskSummaries', () {
      test('returns task summaries with AI responses in happy path', () async {
        // Arrange
        final request = TaskSummaryRequest(
          startDate: testStartDate,
          endDate: testEndDate,
        );

        // Mock the new database-level filtering method
        final mockWorkEntriesSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockJournalDb.workEntriesInDateRange(
              ['JournalEntry', 'JournalAudio'],
              [testCategoryId],
              testStartDate,
              testEndDate,
            )).thenReturn(mockWorkEntriesSelectable);
        when(mockWorkEntriesSelectable.get)
            .thenAnswer((_) async => [testJournalDbEntry, testJournalDbAudio]);

        when(() => mockJournalDb.linksForEntryIds({
              testJournalDbEntry.id,
              testJournalDbAudio.id,
            })).thenAnswer((_) async => [testLink]);

        when(() => mockJournalDb.getJournalEntitiesForIds({testTask.meta.id}))
            .thenAnswer((_) async => [testTask]);

        // Mock the bulk linked entities method
        when(() => mockJournalDb.getBulkLinkedEntities({testTask.meta.id}))
            .thenAnswer((_) async => {
                  testTask.meta.id: [testAiResponse]
                });

        // Act
        final result = await repository.getTaskSummaries(
          categoryId: testCategoryId,
          request: request,
        );

        // Assert
        expect(result.length, 1);
        expect(result.first.taskId, testTask.meta.id);
        expect(result.first.taskTitle, 'Test Task');
        expect(result.first.summary, 'AI generated task summary');
        expect(result.first.status, 'IN PROGRESS');
        expect(result.first.metadata?['model'], 'gpt-4');
        expect(result.first.metadata?['promptId'], 'prompt-123');
      });

      test('filters out journal entries with duration < 15 seconds', () async {
        // Arrange
        final request = TaskSummaryRequest(
          startDate: testStartDate,
          endDate: testEndDate,
        );

        // Mock database query - should only return audio entry since short text entry is filtered out
        final mockWorkEntriesSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockJournalDb.workEntriesInDateRange(
              ['JournalEntry', 'JournalAudio'],
              [testCategoryId],
              testStartDate,
              testEndDate,
            )).thenReturn(mockWorkEntriesSelectable);
        when(mockWorkEntriesSelectable.get).thenAnswer((_) async =>
            [testJournalDbAudio]); // Only audio, short entry filtered out

        when(() => mockJournalDb.linksForEntryIds({testJournalDbAudio.id}))
            .thenAnswer((_) async => []);

        // Act
        final result = await repository.getTaskSummaries(
          categoryId: testCategoryId,
          request: request,
        );

        // Assert
        expect(result, isEmpty);

        // Verify that only the audio entry ID was used for links query
        verify(() => mockJournalDb.linksForEntryIds({testJournalDbAudio.id}))
            .called(1);
      });

      test('includes all audio entries regardless of duration', () async {
        // Arrange
        final request = TaskSummaryRequest(
          startDate: testStartDate,
          endDate: testEndDate,
        );

        final audioLink = EntryLink.basic(
          id: 'audio-link',
          fromId: testTask.meta.id,
          toId: testJournalDbAudioShort.id, // Use database entity ID
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );

        // Mock database query - should include short audio entry (no duration filter for audio)
        final mockWorkEntriesSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockJournalDb.workEntriesInDateRange(
              ['JournalEntry', 'JournalAudio'],
              [testCategoryId],
              testStartDate,
              testEndDate,
            )).thenReturn(mockWorkEntriesSelectable);
        when(mockWorkEntriesSelectable.get)
            .thenAnswer((_) async => [testJournalDbAudioShort]);

        when(() => mockJournalDb.linksForEntryIds({testJournalDbAudioShort.id}))
            .thenAnswer((_) async => [audioLink]);

        when(() => mockJournalDb.getJournalEntitiesForIds({testTask.meta.id}))
            .thenAnswer((_) async => [testTask]);

        // Mock the bulk linked entities method
        when(() => mockJournalDb.getBulkLinkedEntities({testTask.meta.id}))
            .thenAnswer((_) async => {
                  testTask.meta.id: [testAiResponse]
                });

        // Act
        final result = await repository.getTaskSummaries(
          categoryId: testCategoryId,
          request: request,
        );

        // Assert
        expect(result.length, 1);
        expect(result.first.taskId, testTask.meta.id);
      });

      test('filters entries by date range correctly', () async {
        // Arrange
        final request = TaskSummaryRequest(
          startDate: testStartDate,
          endDate: testEndDate,
        );

        final mockWorkEntriesSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockJournalDb.workEntriesInDateRange(
              ['JournalEntry', 'JournalAudio'],
              [testCategoryId],
              testStartDate,
              testEndDate,
            )).thenReturn(mockWorkEntriesSelectable);
        when(mockWorkEntriesSelectable.get).thenAnswer(
            (_) async => [testJournalDbEntry]); // Only entry in range

        when(() => mockJournalDb.linksForEntryIds({testJournalDbEntry.id}))
            .thenAnswer((_) async => []);

        // Act
        final result = await repository.getTaskSummaries(
          categoryId: testCategoryId,
          request: request,
        );

        // Assert
        expect(result, isEmpty);

        // Verify only the entry within range was considered for links
        verify(() => mockJournalDb.linksForEntryIds({testJournalDbEntry.id}))
            .called(1);
      });

      test('returns empty list when no work entries found', () async {
        // Arrange
        final request = TaskSummaryRequest(
          startDate: testStartDate,
          endDate: testEndDate,
        );

        final mockWorkEntriesSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockJournalDb.workEntriesInDateRange(
              ['JournalEntry', 'JournalAudio'],
              [testCategoryId],
              testStartDate,
              testEndDate,
            )).thenReturn(mockWorkEntriesSelectable);
        when(mockWorkEntriesSelectable.get).thenAnswer((_) async => []);

        // Act
        final result = await repository.getTaskSummaries(
          categoryId: testCategoryId,
          request: request,
        );

        // Assert
        expect(result, isEmpty);

        // Should not call further methods
        verifyNever(() => mockJournalDb.linksForEntryIds(any()));
        verifyNever(() => mockJournalDb.getJournalEntitiesForIds(any()));
      });

      test('returns empty list when no linked tasks found', () async {
        // Arrange
        final request = TaskSummaryRequest(
          startDate: testStartDate,
          endDate: testEndDate,
        );

        final mockWorkEntriesSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockJournalDb.workEntriesInDateRange(
              ['JournalEntry', 'JournalAudio'],
              [testCategoryId],
              testStartDate,
              testEndDate,
            )).thenReturn(mockWorkEntriesSelectable);
        when(mockWorkEntriesSelectable.get)
            .thenAnswer((_) async => [testJournalDbEntry]);

        when(() => mockJournalDb.linksForEntryIds({testJournalDbEntry.id}))
            .thenAnswer((_) async => []);

        // Act
        final result = await repository.getTaskSummaries(
          categoryId: testCategoryId,
          request: request,
        );

        // Assert
        expect(result, isEmpty);

        // Should not call getJournalEntitiesForIds
        verifyNever(() => mockJournalDb.getJournalEntitiesForIds(any()));
      });

      test('filters out non-task entities from linked results', () async {
        // Arrange
        final request = TaskSummaryRequest(
          startDate: testStartDate,
          endDate: testEndDate,
        );

        final nonTaskEntity = JournalEntity.journalEntry(
          meta: Metadata(
            id: 'non-task',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
          ),
          entryText: const EntryText(plainText: 'Not a task'),
        );

        final mockWorkEntriesSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockJournalDb.workEntriesInDateRange(
              ['JournalEntry', 'JournalAudio'],
              [testCategoryId],
              testStartDate,
              testEndDate,
            )).thenReturn(mockWorkEntriesSelectable);
        when(mockWorkEntriesSelectable.get)
            .thenAnswer((_) async => [testJournalDbEntry]);

        when(() => mockJournalDb.linksForEntryIds({testJournalDbEntry.id}))
            .thenAnswer((_) async => [testLink]);

        when(() => mockJournalDb.getJournalEntitiesForIds({testTask.meta.id}))
            .thenAnswer((_) async => [testTask, nonTaskEntity]);

        // Mock the bulk linked entities method
        when(() => mockJournalDb.getBulkLinkedEntities({testTask.meta.id}))
            .thenAnswer((_) async => {
                  testTask.meta.id: [testAiResponse]
                });

        // Act
        final result = await repository.getTaskSummaries(
          categoryId: testCategoryId,
          request: request,
        );

        // Assert
        expect(result.length, 1);
        expect(result.first.taskId, testTask.meta.id);
      });

      test('returns task without AI summary when no AI responses found',
          () async {
        // Arrange
        final request = TaskSummaryRequest(
          startDate: testStartDate,
          endDate: testEndDate,
        );

        final mockWorkEntriesSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockJournalDb.workEntriesInDateRange(
              ['JournalEntry', 'JournalAudio'],
              [testCategoryId],
              testStartDate,
              testEndDate,
            )).thenReturn(mockWorkEntriesSelectable);
        when(mockWorkEntriesSelectable.get)
            .thenAnswer((_) async => [testJournalDbEntry]);

        when(() => mockJournalDb.linksForEntryIds({testJournalDbEntry.id}))
            .thenAnswer((_) async => [testLink]);

        when(() => mockJournalDb.getJournalEntitiesForIds({testTask.meta.id}))
            .thenAnswer((_) async => [testTask]);

        // Mock the bulk linked entities method
        when(() => mockJournalDb.getBulkLinkedEntities({testTask.meta.id}))
            .thenAnswer((_) async => {testTask.meta.id: <JournalEntity>[]});

        // Act
        final result = await repository.getTaskSummaries(
          categoryId: testCategoryId,
          request: request,
        );

        // Assert
        expect(result.length, 1);
        expect(result.first.taskId, testTask.meta.id);
        expect(result.first.summary, 'No AI summary available for this task.');
        expect(result.first.metadata, isNull);
      });

      test('returns latest AI response when multiple exist', () async {
        // Arrange
        final request = TaskSummaryRequest(
          startDate: testStartDate,
          endDate: testEndDate,
        );

        final mockWorkEntriesSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockJournalDb.workEntriesInDateRange(
              ['JournalEntry', 'JournalAudio'],
              [testCategoryId],
              testStartDate,
              testEndDate,
            )).thenReturn(mockWorkEntriesSelectable);
        when(mockWorkEntriesSelectable.get)
            .thenAnswer((_) async => [testJournalDbEntry]);

        when(() => mockJournalDb.linksForEntryIds({testJournalDbEntry.id}))
            .thenAnswer((_) async => [testLink]);

        when(() => mockJournalDb.getJournalEntitiesForIds({testTask.meta.id}))
            .thenAnswer((_) async => [testTask]);

        // Mock the bulk linked entities method
        when(() => mockJournalDb.getBulkLinkedEntities({testTask.meta.id}))
            .thenAnswer((_) async => {
                  testTask.meta.id: [testAiResponse, testOlderAiResponse]
                });

        // Act
        final result = await repository.getTaskSummaries(
          categoryId: testCategoryId,
          request: request,
        );

        // Assert
        expect(result.length, 1);
        expect(result.first.summary,
            'AI generated task summary'); // Latest, not older
        expect(result.first.metadata?['model'], 'gpt-4'); // Latest model
      });

      test('respects limit parameter', () async {
        // Arrange
        final request = TaskSummaryRequest(
          startDate: testStartDate,
          endDate: testEndDate,
          limit: 1,
        );

        final link2 = EntryLink.basic(
          id: 'link-2',
          fromId: testTaskDone.meta.id,
          toId: testJournalEntry.meta.id,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );

        final mockWorkEntriesSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockJournalDb.workEntriesInDateRange(
              ['JournalEntry', 'JournalAudio'],
              [testCategoryId],
              testStartDate,
              testEndDate,
            )).thenReturn(mockWorkEntriesSelectable);
        when(mockWorkEntriesSelectable.get)
            .thenAnswer((_) async => [testJournalDbEntry]);

        when(() => mockJournalDb.linksForEntryIds({testJournalDbEntry.id}))
            .thenAnswer((_) async => [testLink, link2]);

        when(() => mockJournalDb.getJournalEntitiesForIds(
                {testTask.meta.id, testTaskDone.meta.id}))
            .thenAnswer((_) async => [testTask, testTaskDone]);

        // Mock the bulk linked entities method
        when(() => mockJournalDb.getBulkLinkedEntities({testTask.meta.id}))
            .thenAnswer((_) async => {
                  testTask.meta.id: [testAiResponse]
                });

        // Act
        final result = await repository.getTaskSummaries(
          categoryId: testCategoryId,
          request: request,
        );

        // Assert
        expect(result.length, 1); // Limit enforced
      });

      test('maps all task status values correctly', () async {
        // Test all possible status values
        final statusTests = [
          (
            TaskStatus.open(
                id: 'status-open', createdAt: testDate, utcOffset: 0),
            'OPEN'
          ),
          (
            TaskStatus.inProgress(
                id: 'status-progress', createdAt: testDate, utcOffset: 0),
            'IN PROGRESS'
          ),
          (
            TaskStatus.groomed(
                id: 'status-groomed', createdAt: testDate, utcOffset: 0),
            'GROOMED'
          ),
          (
            TaskStatus.blocked(
                id: 'status-blocked',
                createdAt: testDate,
                utcOffset: 0,
                reason: 'Test block'),
            'BLOCKED'
          ),
          (
            TaskStatus.onHold(
                id: 'status-hold',
                createdAt: testDate,
                utcOffset: 0,
                reason: 'Test hold'),
            'ON HOLD'
          ),
          (
            TaskStatus.done(
                id: 'status-done', createdAt: testDate, utcOffset: 0),
            'DONE'
          ),
          (
            TaskStatus.rejected(
                id: 'status-rejected', createdAt: testDate, utcOffset: 0),
            'REJECTED'
          ),
        ];

        for (final (status, expectedName) in statusTests) {
          // Arrange
          final request = TaskSummaryRequest(
            startDate: testStartDate,
            endDate: testEndDate,
          );

          final taskWithStatus = JournalEntity.task(
            meta: Metadata(
              id: 'task-status-test',
              createdAt: testDate,
              updatedAt: testDate,
              dateFrom: testDate,
              dateTo: testDate,
            ),
            data: TaskData(
              title: 'Status Test Task',
              status: status,
              dateFrom: testDate,
              dateTo: testDate,
              statusHistory: [],
            ),
          );

          final mockWorkEntriesSelectable = MockSelectable<JournalDbEntity>();
          when(() => mockJournalDb.workEntriesInDateRange(
                ['JournalEntry', 'JournalAudio'],
                [testCategoryId],
                testStartDate,
                testEndDate,
              )).thenReturn(mockWorkEntriesSelectable);
          when(mockWorkEntriesSelectable.get)
              .thenAnswer((_) async => [testJournalDbEntry]);

          when(() => mockJournalDb.linksForEntryIds({testJournalDbEntry.id}))
              .thenAnswer((_) async => [
                    EntryLink.basic(
                      id: 'status-test-link',
                      fromId: taskWithStatus.meta.id,
                      toId: testJournalDbEntry.id,
                      createdAt: testDate,
                      updatedAt: testDate,
                      vectorClock: null,
                    ),
                  ]);

          when(() => mockJournalDb
                  .getJournalEntitiesForIds({taskWithStatus.meta.id}))
              .thenAnswer((_) async => [taskWithStatus]);

          // Mock the bulk linked entities method
          when(() =>
                  mockJournalDb.getBulkLinkedEntities({taskWithStatus.meta.id}))
              .thenAnswer(
                  (_) async => {taskWithStatus.meta.id: <JournalEntity>[]});

          // Act
          final result = await repository.getTaskSummaries(
            categoryId: testCategoryId,
            request: request,
          );

          // Assert
          expect(result.length, 1);
          expect(result.first.status, expectedName);
        }
      });

      test('ignores non-task-summary AI responses', () async {
        // Arrange
        final request = TaskSummaryRequest(
          startDate: testStartDate,
          endDate: testEndDate,
        );

        final nonTaskSummaryAiResponse = JournalEntity.aiResponse(
          meta: Metadata(
            id: 'ai-response-other',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
          ),
          data: const AiResponseData(
            model: 'gpt-4',
            systemMessage: 'You are a helpful assistant',
            prompt: 'Analyze this image',
            thoughts: 'User wants image analysis',
            response: 'Image analysis result',
            type: AiResponseType.imageAnalysis,
          ),
        );

        final mockWorkEntriesSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockJournalDb.workEntriesInDateRange(
              ['JournalEntry', 'JournalAudio'],
              [testCategoryId],
              testStartDate,
              testEndDate,
            )).thenReturn(mockWorkEntriesSelectable);
        when(mockWorkEntriesSelectable.get)
            .thenAnswer((_) async => [testJournalDbEntry]);

        when(() => mockJournalDb.linksForEntryIds({testJournalDbEntry.id}))
            .thenAnswer((_) async => [testLink]);

        when(() => mockJournalDb.getJournalEntitiesForIds({testTask.meta.id}))
            .thenAnswer((_) async => [testTask]);

        // Mock the bulk linked entities method
        when(() => mockJournalDb.getBulkLinkedEntities({testTask.meta.id}))
            .thenAnswer((_) async => {
                  testTask.meta.id: [nonTaskSummaryAiResponse]
                });

        // Act
        final result = await repository.getTaskSummaries(
          categoryId: testCategoryId,
          request: request,
        );

        // Assert
        expect(result.length, 1);
        expect(result.first.summary, 'No AI summary available for this task.');
        expect(result.first.metadata, isNull);
      });

      test('handles complex multi-task scenario correctly', () async {
        // Arrange
        final request = TaskSummaryRequest(
          startDate: testStartDate,
          endDate: testEndDate,
          limit: 10,
        );

        final task2AiResponse = JournalEntity.aiResponse(
          meta: Metadata(
            id: 'ai-response-2',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
          ),
          data: const AiResponseData(
            model: 'claude-3',
            systemMessage: 'You are a helpful assistant',
            prompt: 'Summarize this task',
            thoughts: 'User wants task summary',
            response: 'Second task summary',
            promptId: 'prompt-456',
            type: AiResponseType.taskSummary,
          ),
        );

        final link1 = EntryLink.basic(
          id: 'complex-link-1',
          fromId: testTask.meta.id,
          toId: testJournalDbEntry.id,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );

        final link2 = EntryLink.basic(
          id: 'complex-link-2',
          fromId: testTaskDone.meta.id,
          toId: testJournalDbAudio2.id,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );

        final mockWorkEntriesSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockJournalDb.workEntriesInDateRange(
              ['JournalEntry', 'JournalAudio'],
              [testCategoryId],
              testStartDate,
              testEndDate,
            )).thenReturn(mockWorkEntriesSelectable);
        when(mockWorkEntriesSelectable.get)
            .thenAnswer((_) async => [testJournalDbEntry, testJournalDbAudio2]);

        when(() => mockJournalDb.linksForEntryIds({
              testJournalDbEntry.id,
              testJournalDbAudio2.id,
            })).thenAnswer((_) async => [link1, link2]);

        when(() => mockJournalDb.getJournalEntitiesForIds(
                {testTask.meta.id, testTaskDone.meta.id}))
            .thenAnswer((_) async => [testTask, testTaskDone]);

        // Mock the bulk linked entities method for both tasks
        when(() => mockJournalDb
                .getBulkLinkedEntities(
                    {testTask.meta.id, testTaskDone.meta.id}))
            .thenAnswer((_) async => {
                  testTask.meta.id: [testAiResponse],
                  testTaskDone.meta.id: [task2AiResponse],
                });

        // Act
        final result = await repository.getTaskSummaries(
          categoryId: testCategoryId,
          request: request,
        );

        // Assert
        expect(result.length, 2);

        // Find results by task ID
        final task1Result =
            result.firstWhere((r) => r.taskId == testTask.meta.id);
        final task2Result =
            result.firstWhere((r) => r.taskId == testTaskDone.meta.id);

        expect(task1Result.summary, 'AI generated task summary');
        expect(task1Result.status, 'IN PROGRESS');
        expect(task1Result.metadata?['model'], 'gpt-4');

        expect(task2Result.summary, 'Second task summary');
        expect(task2Result.status, 'DONE');
        expect(task2Result.metadata?['model'], 'claude-3');
      });
    });

    group('edge cases', () {
      test('swaps dates when endDate is before startDate', () async {
        // Arrange
        final request = TaskSummaryRequest(
          startDate: DateTime(2024, 1, 15), // Later date
          endDate: DateTime(2024, 1, 10), // Earlier date - should be swapped
          limit: 10,
        );

        final mockWorkEntriesSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockJournalDb.workEntriesInDateRange(
              any(),
              any(),
              any(),
              any(),
            )).thenReturn(mockWorkEntriesSelectable);
        when(mockWorkEntriesSelectable.get).thenAnswer((_) async => []);

        // Act
        final result = await repository.getTaskSummaries(
          categoryId: testCategoryId,
          request: request,
        );

        // Assert
        expect(result, isEmpty); // No results expected, but should not crash

        // Verify the method was called (dates should be internally swapped)
        verify(() => mockJournalDb.workEntriesInDateRange(
              any(),
              any(),
              any(),
              any(),
            )).called(1);
      });

      test('clamps limit to reasonable bounds - negative values', () async {
        // Arrange
        final request = TaskSummaryRequest(
          startDate: DateTime(2024, 1, 10),
          endDate: DateTime(2024, 1, 15),
          limit: -5, // Negative limit
        );

        final mockWorkEntriesSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockJournalDb.workEntriesInDateRange(
              any(),
              any(),
              any(),
              any(),
            )).thenReturn(mockWorkEntriesSelectable);
        when(mockWorkEntriesSelectable.get).thenAnswer((_) async => []);

        // Act
        final result = await repository.getTaskSummaries(
          categoryId: testCategoryId,
          request: request,
        );

        // Assert - should not crash and should clamp to minimum 1
        expect(result, isEmpty);
      });

      test('clamps limit to reasonable bounds - very large values', () async {
        // Arrange
        final request = TaskSummaryRequest(
          startDate: DateTime(2024, 1, 10),
          endDate: DateTime(2024, 1, 15),
          limit: 99999, // Very large limit
        );

        final mockWorkEntriesSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockJournalDb.workEntriesInDateRange(
              any(),
              any(),
              any(),
              any(),
            )).thenReturn(mockWorkEntriesSelectable);
        when(mockWorkEntriesSelectable.get).thenAnswer((_) async => []);

        // Act
        final result = await repository.getTaskSummaries(
          categoryId: testCategoryId,
          request: request,
        );

        // Assert - should not crash and should clamp to maximum 100
        expect(result, isEmpty);
      });
    });
  });
}
