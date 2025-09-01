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

void main() {
  group('TaskSummaryRepository', () {
    late TaskSummaryRepository repository;
    late MockJournalDb mockJournalDb;

    const testCategoryId = 'test-category-123';
    final testDate = DateTime(2024, 1, 15);
    final testStartDate = DateTime(2024);
    final testEndDate = DateTime(2024, 1, 31);

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

    final testJournalEntryShort = JournalEntity.journalEntry(
      meta: Metadata(
        id: 'journal-entry-short',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo:
            testDate.add(const Duration(seconds: 10)), // 10 seconds - too short
        categoryId: testCategoryId,
      ),
      entryText: const EntryText(plainText: 'Quick note'),
    );

    final testJournalAudio = JournalEntity.journalAudio(
      meta: Metadata(
        id: 'journal-audio-1',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate.add(const Duration(minutes: 5)),
        categoryId: testCategoryId,
      ),
      data: AudioData(
        dateFrom: testDate,
        dateTo: testDate.add(const Duration(minutes: 5)),
        audioFile: 'test.mp3',
        audioDirectory: '/audio/',
        duration: const Duration(minutes: 5),
      ),
      entryText: const EntryText(plainText: 'Meeting notes'),
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

        when(() => mockJournalDb.getJournalEntities(
              types: ['JournalEntry', 'JournalAudio'],
              starredStatuses: [true, false],
              privateStatuses: [true, false],
              flaggedStatuses: [0, 1, 2, 3],
              ids: null,
              categoryIds: {testCategoryId},
              limit: 10000,
            )).thenAnswer((_) async => [testJournalEntry, testJournalAudio]);

        when(() => mockJournalDb.linksForEntryIds({
              testJournalEntry.meta.id,
              testJournalAudio.meta.id,
            })).thenAnswer((_) async => [testLink]);

        when(() => mockJournalDb.getJournalEntitiesForIds({testTask.meta.id}))
            .thenAnswer((_) async => [testTask]);

        when(() => mockJournalDb.getLinkedEntities(testTask.meta.id))
            .thenAnswer((_) async => [testAiResponse]);

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

        when(() => mockJournalDb.getJournalEntities(
                  types: ['JournalEntry', 'JournalAudio'],
                  starredStatuses: [true, false],
                  privateStatuses: [true, false],
                  flaggedStatuses: [0, 1, 2, 3],
                  ids: null,
                  categoryIds: {testCategoryId},
                  limit: 10000,
                ))
            .thenAnswer((_) async => [testJournalEntryShort, testJournalAudio]);

        when(() => mockJournalDb.linksForEntryIds({testJournalAudio.meta.id}))
            .thenAnswer((_) async => []);

        // Act
        final result = await repository.getTaskSummaries(
          categoryId: testCategoryId,
          request: request,
        );

        // Assert
        expect(result, isEmpty);

        // Verify that only the audio entry ID was used for links query
        verify(() => mockJournalDb.linksForEntryIds({testJournalAudio.meta.id}))
            .called(1);
      });

      test('includes all audio entries regardless of duration', () async {
        // Arrange
        final request = TaskSummaryRequest(
          startDate: testStartDate,
          endDate: testEndDate,
        );

        final testShortAudio = JournalEntity.journalAudio(
          meta: Metadata(
            id: 'audio-short',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate.add(const Duration(seconds: 5)), // Very short
            categoryId: testCategoryId,
          ),
          data: AudioData(
            dateFrom: testDate,
            dateTo: testDate.add(const Duration(seconds: 5)),
            audioFile: 'short.mp3',
            audioDirectory: '/audio/',
            duration: const Duration(seconds: 5),
          ),
          entryText: const EntryText(plainText: 'Short'),
        );

        final audioLink = EntryLink.basic(
          id: 'audio-link',
          fromId: testTask.meta.id,
          toId: testShortAudio.meta.id,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );

        when(() => mockJournalDb.getJournalEntities(
              types: ['JournalEntry', 'JournalAudio'],
              starredStatuses: [true, false],
              privateStatuses: [true, false],
              flaggedStatuses: [0, 1, 2, 3],
              ids: null,
              categoryIds: {testCategoryId},
              limit: 10000,
            )).thenAnswer((_) async => [testShortAudio]);

        when(() => mockJournalDb.linksForEntryIds({testShortAudio.meta.id}))
            .thenAnswer((_) async => [audioLink]);

        when(() => mockJournalDb.getJournalEntitiesForIds({testTask.meta.id}))
            .thenAnswer((_) async => [testTask]);

        when(() => mockJournalDb.getLinkedEntities(testTask.meta.id))
            .thenAnswer((_) async => [testAiResponse]);

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

        final entryOutsideRange = JournalEntity.journalEntry(
          meta: Metadata(
            id: 'outside-range',
            createdAt: DateTime(2023, 12, 15), // Before range
            updatedAt: DateTime(2023, 12, 15),
            dateFrom: DateTime(2023, 12, 15),
            dateTo: DateTime(2023, 12, 15).add(const Duration(hours: 1)),
            categoryId: testCategoryId,
          ),
          entryText: const EntryText(plainText: 'Outside range'),
        );

        when(() => mockJournalDb.getJournalEntities(
              types: ['JournalEntry', 'JournalAudio'],
              starredStatuses: [true, false],
              privateStatuses: [true, false],
              flaggedStatuses: [0, 1, 2, 3],
              ids: null,
              categoryIds: {testCategoryId},
              limit: 10000,
            )).thenAnswer((_) async => [testJournalEntry, entryOutsideRange]);

        when(() => mockJournalDb.linksForEntryIds({testJournalEntry.meta.id}))
            .thenAnswer((_) async => []);

        // Act
        final result = await repository.getTaskSummaries(
          categoryId: testCategoryId,
          request: request,
        );

        // Assert
        expect(result, isEmpty);

        // Verify only the entry within range was considered for links
        verify(() => mockJournalDb.linksForEntryIds({testJournalEntry.meta.id}))
            .called(1);
      });

      test('returns empty list when no work entries found', () async {
        // Arrange
        final request = TaskSummaryRequest(
          startDate: testStartDate,
          endDate: testEndDate,
        );

        when(() => mockJournalDb.getJournalEntities(
              types: ['JournalEntry', 'JournalAudio'],
              starredStatuses: [true, false],
              privateStatuses: [true, false],
              flaggedStatuses: [0, 1, 2, 3],
              ids: null,
              categoryIds: {testCategoryId},
              limit: 10000,
            )).thenAnswer((_) async => []);

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

        when(() => mockJournalDb.getJournalEntities(
              types: ['JournalEntry', 'JournalAudio'],
              starredStatuses: [true, false],
              privateStatuses: [true, false],
              flaggedStatuses: [0, 1, 2, 3],
              ids: null,
              categoryIds: {testCategoryId},
              limit: 10000,
            )).thenAnswer((_) async => [testJournalEntry]);

        when(() => mockJournalDb.linksForEntryIds({testJournalEntry.meta.id}))
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

        when(() => mockJournalDb.getJournalEntities(
              types: ['JournalEntry', 'JournalAudio'],
              starredStatuses: [true, false],
              privateStatuses: [true, false],
              flaggedStatuses: [0, 1, 2, 3],
              ids: null,
              categoryIds: {testCategoryId},
              limit: 10000,
            )).thenAnswer((_) async => [testJournalEntry]);

        when(() => mockJournalDb.linksForEntryIds({testJournalEntry.meta.id}))
            .thenAnswer((_) async => [testLink]);

        when(() => mockJournalDb.getJournalEntitiesForIds({testTask.meta.id}))
            .thenAnswer((_) async => [testTask, nonTaskEntity]);

        when(() => mockJournalDb.getLinkedEntities(testTask.meta.id))
            .thenAnswer((_) async => [testAiResponse]);

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

        when(() => mockJournalDb.getJournalEntities(
              types: ['JournalEntry', 'JournalAudio'],
              starredStatuses: [true, false],
              privateStatuses: [true, false],
              flaggedStatuses: [0, 1, 2, 3],
              ids: null,
              categoryIds: {testCategoryId},
              limit: 10000,
            )).thenAnswer((_) async => [testJournalEntry]);

        when(() => mockJournalDb.linksForEntryIds({testJournalEntry.meta.id}))
            .thenAnswer((_) async => [testLink]);

        when(() => mockJournalDb.getJournalEntitiesForIds({testTask.meta.id}))
            .thenAnswer((_) async => [testTask]);

        when(() => mockJournalDb.getLinkedEntities(testTask.meta.id))
            .thenAnswer((_) async => []);

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

        when(() => mockJournalDb.getJournalEntities(
              types: ['JournalEntry', 'JournalAudio'],
              starredStatuses: [true, false],
              privateStatuses: [true, false],
              flaggedStatuses: [0, 1, 2, 3],
              ids: null,
              categoryIds: {testCategoryId},
              limit: 10000,
            )).thenAnswer((_) async => [testJournalEntry]);

        when(() => mockJournalDb.linksForEntryIds({testJournalEntry.meta.id}))
            .thenAnswer((_) async => [testLink]);

        when(() => mockJournalDb.getJournalEntitiesForIds({testTask.meta.id}))
            .thenAnswer((_) async => [testTask]);

        when(() => mockJournalDb.getLinkedEntities(testTask.meta.id))
            .thenAnswer((_) async => [testAiResponse, testOlderAiResponse]);

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

        when(() => mockJournalDb.getJournalEntities(
              types: ['JournalEntry', 'JournalAudio'],
              starredStatuses: [true, false],
              privateStatuses: [true, false],
              flaggedStatuses: [0, 1, 2, 3],
              ids: null,
              categoryIds: {testCategoryId},
              limit: 10000,
            )).thenAnswer((_) async => [testJournalEntry]);

        when(() => mockJournalDb.linksForEntryIds({testJournalEntry.meta.id}))
            .thenAnswer((_) async => [testLink, link2]);

        when(() => mockJournalDb.getJournalEntitiesForIds(
                {testTask.meta.id, testTaskDone.meta.id}))
            .thenAnswer((_) async => [testTask, testTaskDone]);

        when(() => mockJournalDb.getLinkedEntities(testTask.meta.id))
            .thenAnswer((_) async => [testAiResponse]);

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

          when(() => mockJournalDb.getJournalEntities(
                types: ['JournalEntry', 'JournalAudio'],
                starredStatuses: [true, false],
                privateStatuses: [true, false],
                flaggedStatuses: [0, 1, 2, 3],
                ids: null,
                categoryIds: {testCategoryId},
                limit: 10000,
              )).thenAnswer((_) async => [testJournalEntry]);

          when(() => mockJournalDb.linksForEntryIds({testJournalEntry.meta.id}))
              .thenAnswer((_) async => [
                    EntryLink.basic(
                      id: 'status-test-link',
                      fromId: taskWithStatus.meta.id,
                      toId: testJournalEntry.meta.id,
                      createdAt: testDate,
                      updatedAt: testDate,
                      vectorClock: null,
                    ),
                  ]);

          when(() => mockJournalDb
                  .getJournalEntitiesForIds({taskWithStatus.meta.id}))
              .thenAnswer((_) async => [taskWithStatus]);

          when(() => mockJournalDb.getLinkedEntities(taskWithStatus.meta.id))
              .thenAnswer((_) async => []);

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

        when(() => mockJournalDb.getJournalEntities(
              types: ['JournalEntry', 'JournalAudio'],
              starredStatuses: [true, false],
              privateStatuses: [true, false],
              flaggedStatuses: [0, 1, 2, 3],
              ids: null,
              categoryIds: {testCategoryId},
              limit: 10000,
            )).thenAnswer((_) async => [testJournalEntry]);

        when(() => mockJournalDb.linksForEntryIds({testJournalEntry.meta.id}))
            .thenAnswer((_) async => [testLink]);

        when(() => mockJournalDb.getJournalEntitiesForIds({testTask.meta.id}))
            .thenAnswer((_) async => [testTask]);

        when(() => mockJournalDb.getLinkedEntities(testTask.meta.id))
            .thenAnswer((_) async => [nonTaskSummaryAiResponse]);

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

        final workEntry2 = JournalEntity.journalAudio(
          meta: Metadata(
            id: 'audio-2',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate.add(const Duration(minutes: 10)),
            categoryId: testCategoryId,
          ),
          data: AudioData(
            dateFrom: testDate,
            dateTo: testDate.add(const Duration(minutes: 10)),
            audioFile: 'work2.mp3',
            audioDirectory: '/audio/',
            duration: const Duration(minutes: 10),
          ),
          entryText: const EntryText(plainText: 'More work'),
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
          toId: testJournalEntry.meta.id,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );

        final link2 = EntryLink.basic(
          id: 'complex-link-2',
          fromId: testTaskDone.meta.id,
          toId: workEntry2.meta.id,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );

        when(() => mockJournalDb.getJournalEntities(
              types: ['JournalEntry', 'JournalAudio'],
              starredStatuses: [true, false],
              privateStatuses: [true, false],
              flaggedStatuses: [0, 1, 2, 3],
              ids: null,
              categoryIds: {testCategoryId},
              limit: 10000,
            )).thenAnswer((_) async => [testJournalEntry, workEntry2]);

        when(() => mockJournalDb.linksForEntryIds({
              testJournalEntry.meta.id,
              workEntry2.meta.id,
            })).thenAnswer((_) async => [link1, link2]);

        when(() => mockJournalDb.getJournalEntitiesForIds(
                {testTask.meta.id, testTaskDone.meta.id}))
            .thenAnswer((_) async => [testTask, testTaskDone]);

        when(() => mockJournalDb.getLinkedEntities(testTask.meta.id))
            .thenAnswer((_) async => [testAiResponse]);

        when(() => mockJournalDb.getLinkedEntities(testTaskDone.meta.id))
            .thenAnswer((_) async => [task2AiResponse]);

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
  });
}
