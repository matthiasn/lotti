// ignore_for_file: prefer_const_constructors

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;
import 'package:lotti/features/ai/repository/task_summary_resolver.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai_chat/models/task_summary_tool.dart';
import 'package:lotti/features/ai_chat/repository/task_summary_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

// Local generic selectable mock — the central [MockSelectable] requires a
// list of values up front, but these tests stub `get()` per-test instead.
class MockSelectable<T> extends Mock implements Selectable<T> {}

class _NoAgentResolver extends TaskSummaryResolver {
  _NoAgentResolver() : super(_EmptyAgentRepository());
}

/// An [AgentRepository] that always returns empty results, simulating the
/// case where no agent is assigned to a task (so the resolver falls back to
/// legacy AI response entries).
class _EmptyAgentRepository extends Fake implements AgentRepository {
  @override
  Future<List<model.AgentLink>> getLinksTo(String toId, {String? type}) async =>
      [];

  @override
  Future<Map<String, AgentReportEntity>> getLatestTaskReportsForTaskIds(
    List<String> taskIds,
  ) async => {};
}

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
      dateTo: testDate.add(
        const Duration(seconds: 5),
      ), // 5 seconds - still included
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
        dateTo: testDate.add(
          const Duration(minutes: 30),
        ), // 30 minutes duration
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
        // ignore: deprecated_member_use_from_same_package
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
        // ignore: deprecated_member_use_from_same_package
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

      repository = TaskSummaryRepository(
        journalDb: mockJournalDb,
        taskSummaryResolver: _NoAgentResolver(),
      );
    });

    tearDown(getIt.reset);

    group('getTaskSummaries', () {
      test('returns task summaries with AI responses in happy path', () async {
        // Arrange
        final request = TaskSummaryRequest(
          startDate: testStartDate.ymd,
          endDate: testEndDate.ymd,
        );

        // Mock the new database-level filtering method
        final mockWorkEntriesSelectable = MockSelectable<JournalDbEntity>();
        final expectedStartUtc = DateTime(
          testStartDate.year,
          testStartDate.month,
          testStartDate.day,
        ).toUtc();
        final expectedEndUtc = DateTime(
          testEndDate.year,
          testEndDate.month,
          testEndDate.day,
          23,
          59,
          59,
          999,
        ).toUtc();
        when(
          () => mockJournalDb.workEntriesInDateRange(
            ['JournalEntry', 'JournalAudio'],
            [testCategoryId],
            expectedStartUtc,
            expectedEndUtc,
          ),
        ).thenReturn(mockWorkEntriesSelectable);
        when(
          mockWorkEntriesSelectable.get,
        ).thenAnswer((_) async => [testJournalDbEntry, testJournalDbAudio]);

        when(
          () => mockJournalDb.linksForEntryIds({
            testJournalDbEntry.id,
            testJournalDbAudio.id,
          }),
        ).thenAnswer((_) async => [testLink]);

        when(
          () => mockJournalDb.getJournalEntitiesForIdsUnordered({
            testTask.meta.id,
          }),
        ).thenAnswer((_) async => [testTask]);

        // Mock the bulk linked entities method
        when(
          () => mockJournalDb.getBulkLinkedEntities({testTask.meta.id}),
        ).thenAnswer(
          (_) async => {
            testTask.meta.id: [testAiResponse],
          },
        );

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
      });

      test('filters out journal entries with duration < 15 seconds', () async {
        // Arrange
        final request = TaskSummaryRequest(
          startDate: testStartDate.ymd,
          endDate: testEndDate.ymd,
        );

        // Mock database query - should only return audio entry since short text entry is filtered out
        final mockWorkEntriesSelectable = MockSelectable<JournalDbEntity>();
        final expectedStartUtc = DateTime(
          testStartDate.year,
          testStartDate.month,
          testStartDate.day,
        ).toUtc();
        final expectedEndUtc = DateTime(
          testEndDate.year,
          testEndDate.month,
          testEndDate.day,
          23,
          59,
          59,
          999,
        ).toUtc();
        when(
          () => mockJournalDb.workEntriesInDateRange(
            ['JournalEntry', 'JournalAudio'],
            [testCategoryId],
            expectedStartUtc,
            expectedEndUtc,
          ),
        ).thenReturn(mockWorkEntriesSelectable);
        when(mockWorkEntriesSelectable.get).thenAnswer(
          (_) async => [testJournalDbAudio],
        ); // Only audio, short entry filtered out

        when(
          () => mockJournalDb.linksForEntryIds({testJournalDbAudio.id}),
        ).thenAnswer((_) async => []);

        // Act
        final result = await repository.getTaskSummaries(
          categoryId: testCategoryId,
          request: request,
        );

        // Assert
        expect(result, isEmpty);

        // Verify that only the audio entry ID was used for links query
        verify(
          () => mockJournalDb.linksForEntryIds({testJournalDbAudio.id}),
        ).called(1);
      });

      test('includes all audio entries regardless of duration', () async {
        // Arrange
        final request = TaskSummaryRequest(
          startDate: testStartDate.ymd,
          endDate: testEndDate.ymd,
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
        final expectedStartUtc = DateTime(
          testStartDate.year,
          testStartDate.month,
          testStartDate.day,
        ).toUtc();
        final expectedEndUtc = DateTime(
          testEndDate.year,
          testEndDate.month,
          testEndDate.day,
          23,
          59,
          59,
          999,
        ).toUtc();
        when(
          () => mockJournalDb.workEntriesInDateRange(
            ['JournalEntry', 'JournalAudio'],
            [testCategoryId],
            expectedStartUtc,
            expectedEndUtc,
          ),
        ).thenReturn(mockWorkEntriesSelectable);
        when(
          mockWorkEntriesSelectable.get,
        ).thenAnswer((_) async => [testJournalDbAudioShort]);

        when(
          () => mockJournalDb.linksForEntryIds({testJournalDbAudioShort.id}),
        ).thenAnswer((_) async => [audioLink]);

        when(
          () => mockJournalDb.getJournalEntitiesForIdsUnordered({
            testTask.meta.id,
          }),
        ).thenAnswer((_) async => [testTask]);

        // Mock the bulk linked entities method
        when(
          () => mockJournalDb.getBulkLinkedEntities({testTask.meta.id}),
        ).thenAnswer(
          (_) async => {
            testTask.meta.id: [testAiResponse],
          },
        );

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
          startDate: testStartDate.ymd,
          endDate: testEndDate.ymd,
        );

        final mockWorkEntriesSelectable = MockSelectable<JournalDbEntity>();
        final expectedStartUtc = DateTime(
          testStartDate.year,
          testStartDate.month,
          testStartDate.day,
        ).toUtc();
        final expectedEndUtc = DateTime(
          testEndDate.year,
          testEndDate.month,
          testEndDate.day,
          23,
          59,
          59,
          999,
        ).toUtc();
        when(
          () => mockJournalDb.workEntriesInDateRange(
            ['JournalEntry', 'JournalAudio'],
            [testCategoryId],
            expectedStartUtc,
            expectedEndUtc,
          ),
        ).thenReturn(mockWorkEntriesSelectable);
        when(
          mockWorkEntriesSelectable.get,
        ).thenAnswer((_) async => [testJournalDbEntry]); // Only entry in range

        when(
          () => mockJournalDb.linksForEntryIds({testJournalDbEntry.id}),
        ).thenAnswer((_) async => []);

        // Act
        final result = await repository.getTaskSummaries(
          categoryId: testCategoryId,
          request: request,
        );

        // Assert
        expect(result, isEmpty);

        // Verify only the entry within range was considered for links
        verify(
          () => mockJournalDb.linksForEntryIds({testJournalDbEntry.id}),
        ).called(1);
      });

      test('returns empty list when no work entries found', () async {
        // Arrange
        final request = TaskSummaryRequest(
          startDate: testStartDate.ymd,
          endDate: testEndDate.ymd,
        );

        final mockWorkEntriesSelectable = MockSelectable<JournalDbEntity>();
        final expectedStartUtc = DateTime(
          testStartDate.year,
          testStartDate.month,
          testStartDate.day,
        ).toUtc();
        final expectedEndUtc = DateTime(
          testEndDate.year,
          testEndDate.month,
          testEndDate.day,
          23,
          59,
          59,
          999,
        ).toUtc();
        when(
          () => mockJournalDb.workEntriesInDateRange(
            ['JournalEntry', 'JournalAudio'],
            [testCategoryId],
            expectedStartUtc,
            expectedEndUtc,
          ),
        ).thenReturn(mockWorkEntriesSelectable);
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
        verifyNever(
          () => mockJournalDb.getJournalEntitiesForIdsUnordered(any()),
        );
      });

      test('returns empty list when no linked tasks found', () async {
        // Arrange
        final request = TaskSummaryRequest(
          startDate: testStartDate.ymd,
          endDate: testEndDate.ymd,
        );

        final mockWorkEntriesSelectable = MockSelectable<JournalDbEntity>();
        final expectedStartUtc = DateTime(
          testStartDate.year,
          testStartDate.month,
          testStartDate.day,
        ).toUtc();
        final expectedEndUtc = DateTime(
          testEndDate.year,
          testEndDate.month,
          testEndDate.day,
          23,
          59,
          59,
          999,
        ).toUtc();
        when(
          () => mockJournalDb.workEntriesInDateRange(
            ['JournalEntry', 'JournalAudio'],
            [testCategoryId],
            expectedStartUtc,
            expectedEndUtc,
          ),
        ).thenReturn(mockWorkEntriesSelectable);
        when(
          mockWorkEntriesSelectable.get,
        ).thenAnswer((_) async => [testJournalDbEntry]);

        when(
          () => mockJournalDb.linksForEntryIds({testJournalDbEntry.id}),
        ).thenAnswer((_) async => []);

        // Act
        final result = await repository.getTaskSummaries(
          categoryId: testCategoryId,
          request: request,
        );

        // Assert
        expect(result, isEmpty);

        // Should not call getJournalEntitiesForIds
        verifyNever(
          () => mockJournalDb.getJournalEntitiesForIdsUnordered(any()),
        );
      });

      test('filters out non-task entities from linked results', () async {
        // Arrange
        final request = TaskSummaryRequest(
          startDate: testStartDate.ymd,
          endDate: testEndDate.ymd,
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
        final expectedStartUtc = DateTime(
          testStartDate.year,
          testStartDate.month,
          testStartDate.day,
        ).toUtc();
        final expectedEndUtc = DateTime(
          testEndDate.year,
          testEndDate.month,
          testEndDate.day,
          23,
          59,
          59,
          999,
        ).toUtc();
        when(
          () => mockJournalDb.workEntriesInDateRange(
            ['JournalEntry', 'JournalAudio'],
            [testCategoryId],
            expectedStartUtc,
            expectedEndUtc,
          ),
        ).thenReturn(mockWorkEntriesSelectable);
        when(
          mockWorkEntriesSelectable.get,
        ).thenAnswer((_) async => [testJournalDbEntry]);

        when(
          () => mockJournalDb.linksForEntryIds({testJournalDbEntry.id}),
        ).thenAnswer((_) async => [testLink]);

        when(
          () => mockJournalDb.getJournalEntitiesForIdsUnordered({
            testTask.meta.id,
          }),
        ).thenAnswer((_) async => [testTask, nonTaskEntity]);

        // Mock the bulk linked entities method
        when(
          () => mockJournalDb.getBulkLinkedEntities({testTask.meta.id}),
        ).thenAnswer(
          (_) async => {
            testTask.meta.id: [testAiResponse],
          },
        );

        // Act
        final result = await repository.getTaskSummaries(
          categoryId: testCategoryId,
          request: request,
        );

        // Assert
        expect(result.length, 1);
        expect(result.first.taskId, testTask.meta.id);
      });

      test(
        'returns empty list when linked entities contain no tasks',
        () async {
          // Links exist (so linkedTaskIds is non-empty), but every linked
          // entity resolves to a non-task. This drives actualTasks (and thus
          // tasksToProcess) to empty, exercising the early return after the
          // whereType<Task>() filter without short-circuiting earlier.
          final request = TaskSummaryRequest(
            startDate: testStartDate.ymd,
            endDate: testEndDate.ymd,
          );

          final nonTaskA = JournalEntity.journalEntry(
            meta: Metadata(
              id: 'non-task-a',
              createdAt: testDate,
              updatedAt: testDate,
              dateFrom: testDate,
              dateTo: testDate,
            ),
            entryText: const EntryText(plainText: 'Not a task A'),
          );
          final nonTaskB = JournalEntity.journalEntry(
            meta: Metadata(
              id: 'non-task-b',
              createdAt: testDate,
              updatedAt: testDate,
              dateFrom: testDate,
              dateTo: testDate,
            ),
            entryText: const EntryText(plainText: 'Not a task B'),
          );

          final linkToNonTaskA = EntryLink.basic(
            id: 'link-non-task-a',
            fromId: nonTaskA.meta.id,
            toId: testJournalDbEntry.id,
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          );
          final linkToNonTaskB = EntryLink.basic(
            id: 'link-non-task-b',
            fromId: nonTaskB.meta.id,
            toId: testJournalDbEntry.id,
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          );

          final mockWorkEntriesSelectable = MockSelectable<JournalDbEntity>();
          when(
            () => mockJournalDb.workEntriesInDateRange(
              any(),
              any(),
              any(),
              any(),
            ),
          ).thenReturn(mockWorkEntriesSelectable);
          when(
            mockWorkEntriesSelectable.get,
          ).thenAnswer((_) async => [testJournalDbEntry]);

          when(
            () => mockJournalDb.linksForEntryIds({testJournalDbEntry.id}),
          ).thenAnswer((_) async => [linkToNonTaskA, linkToNonTaskB]);

          when(
            () => mockJournalDb.getJournalEntitiesForIdsUnordered({
              nonTaskA.meta.id,
              nonTaskB.meta.id,
            }),
          ).thenAnswer((_) async => [nonTaskA, nonTaskB]);

          // Act
          final result = await repository.getTaskSummaries(
            categoryId: testCategoryId,
            request: request,
          );

          // Assert: empty result, and the pipeline stopped before bulk
          // linked-entity resolution because there were no tasks to process.
          expect(result, isEmpty);
          verifyNever(() => mockJournalDb.getBulkLinkedEntities(any()));
        },
      );

      test(
        'returns task without AI summary when no AI responses found',
        () async {
          // Arrange
          final request = TaskSummaryRequest(
            startDate: testStartDate.ymd,
            endDate: testEndDate.ymd,
          );

          final mockWorkEntriesSelectable = MockSelectable<JournalDbEntity>();
          final expectedStartUtc = DateTime(
            testStartDate.year,
            testStartDate.month,
            testStartDate.day,
          ).toUtc();
          final expectedEndUtc = DateTime(
            testEndDate.year,
            testEndDate.month,
            testEndDate.day,
            23,
            59,
            59,
            999,
          ).toUtc();
          when(
            () => mockJournalDb.workEntriesInDateRange(
              ['JournalEntry', 'JournalAudio'],
              [testCategoryId],
              expectedStartUtc,
              expectedEndUtc,
            ),
          ).thenReturn(mockWorkEntriesSelectable);
          when(
            mockWorkEntriesSelectable.get,
          ).thenAnswer((_) async => [testJournalDbEntry]);

          when(
            () => mockJournalDb.linksForEntryIds({testJournalDbEntry.id}),
          ).thenAnswer((_) async => [testLink]);

          when(
            () => mockJournalDb.getJournalEntitiesForIdsUnordered({
              testTask.meta.id,
            }),
          ).thenAnswer((_) async => [testTask]);

          // Mock the bulk linked entities method
          when(
            () => mockJournalDb.getBulkLinkedEntities({testTask.meta.id}),
          ).thenAnswer((_) async => {testTask.meta.id: <JournalEntity>[]});

          // Act
          final result = await repository.getTaskSummaries(
            categoryId: testCategoryId,
            request: request,
          );

          // Assert
          expect(result.length, 1);
          expect(result.first.taskId, testTask.meta.id);
          expect(
            result.first.summary,
            'No AI summary available for this task.',
          );
          expect(result.first.metadata, isNull);
        },
      );

      test('returns latest AI response when multiple exist', () async {
        // Arrange
        final request = TaskSummaryRequest(
          startDate: testStartDate.ymd,
          endDate: testEndDate.ymd,
        );

        final mockWorkEntriesSelectable = MockSelectable<JournalDbEntity>();
        final expectedStartUtc = DateTime(
          testStartDate.year,
          testStartDate.month,
          testStartDate.day,
        ).toUtc();
        final expectedEndUtc = DateTime(
          testEndDate.year,
          testEndDate.month,
          testEndDate.day,
          23,
          59,
          59,
          999,
        ).toUtc();
        when(
          () => mockJournalDb.workEntriesInDateRange(
            ['JournalEntry', 'JournalAudio'],
            [testCategoryId],
            expectedStartUtc,
            expectedEndUtc,
          ),
        ).thenReturn(mockWorkEntriesSelectable);
        when(
          mockWorkEntriesSelectable.get,
        ).thenAnswer((_) async => [testJournalDbEntry]);

        when(
          () => mockJournalDb.linksForEntryIds({testJournalDbEntry.id}),
        ).thenAnswer((_) async => [testLink]);

        when(
          () => mockJournalDb.getJournalEntitiesForIdsUnordered({
            testTask.meta.id,
          }),
        ).thenAnswer((_) async => [testTask]);

        // Mock the bulk linked entities method
        when(
          () => mockJournalDb.getBulkLinkedEntities({testTask.meta.id}),
        ).thenAnswer(
          (_) async => {
            testTask.meta.id: [testAiResponse, testOlderAiResponse],
          },
        );

        // Act
        final result = await repository.getTaskSummaries(
          categoryId: testCategoryId,
          request: request,
        );

        // Assert
        expect(result.length, 1);
        expect(
          result.first.summary,
          'AI generated task summary',
        ); // Latest, not older
      });

      test('respects limit parameter', () async {
        // Arrange
        final request = TaskSummaryRequest(
          startDate: testStartDate.ymd,
          endDate: testEndDate.ymd,
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
        final expectedStartUtc = DateTime(
          testStartDate.year,
          testStartDate.month,
          testStartDate.day,
        ).toUtc();
        final expectedEndUtc = DateTime(
          testEndDate.year,
          testEndDate.month,
          testEndDate.day,
          23,
          59,
          59,
          999,
        ).toUtc();
        when(
          () => mockJournalDb.workEntriesInDateRange(
            ['JournalEntry', 'JournalAudio'],
            [testCategoryId],
            expectedStartUtc,
            expectedEndUtc,
          ),
        ).thenReturn(mockWorkEntriesSelectable);
        when(
          mockWorkEntriesSelectable.get,
        ).thenAnswer((_) async => [testJournalDbEntry]);

        when(
          () => mockJournalDb.linksForEntryIds({testJournalDbEntry.id}),
        ).thenAnswer((_) async => [testLink, link2]);

        when(
          () => mockJournalDb.getJournalEntitiesForIdsUnordered({
            testTask.meta.id,
            testTaskDone.meta.id,
          }),
        ).thenAnswer((_) async => [testTask, testTaskDone]);

        // Mock the bulk linked entities method
        when(
          () => mockJournalDb.getBulkLinkedEntities({testTask.meta.id}),
        ).thenAnswer(
          (_) async => {
            testTask.meta.id: [testAiResponse],
          },
        );

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
              id: 'status-open',
              createdAt: testDate,
              utcOffset: 0,
            ),
            'OPEN',
          ),
          (
            TaskStatus.inProgress(
              id: 'status-progress',
              createdAt: testDate,
              utcOffset: 0,
            ),
            'IN PROGRESS',
          ),
          (
            TaskStatus.groomed(
              id: 'status-groomed',
              createdAt: testDate,
              utcOffset: 0,
            ),
            'GROOMED',
          ),
          (
            TaskStatus.blocked(
              id: 'status-blocked',
              createdAt: testDate,
              utcOffset: 0,
              reason: 'Test block',
            ),
            'BLOCKED',
          ),
          (
            TaskStatus.onHold(
              id: 'status-hold',
              createdAt: testDate,
              utcOffset: 0,
              reason: 'Test hold',
            ),
            'ON HOLD',
          ),
          (
            TaskStatus.done(
              id: 'status-done',
              createdAt: testDate,
              utcOffset: 0,
            ),
            'DONE',
          ),
          (
            TaskStatus.rejected(
              id: 'status-rejected',
              createdAt: testDate,
              utcOffset: 0,
            ),
            'REJECTED',
          ),
        ];

        for (final (status, expectedName) in statusTests) {
          // Arrange
          final request = TaskSummaryRequest(
            startDate: testStartDate.ymd,
            endDate: testEndDate.ymd,
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
          final expectedStartUtc = DateTime(
            testStartDate.year,
            testStartDate.month,
            testStartDate.day,
          ).toUtc();
          final expectedEndUtc = DateTime(
            testEndDate.year,
            testEndDate.month,
            testEndDate.day,
            23,
            59,
            59,
            999,
          ).toUtc();
          when(
            () => mockJournalDb.workEntriesInDateRange(
              ['JournalEntry', 'JournalAudio'],
              [testCategoryId],
              expectedStartUtc,
              expectedEndUtc,
            ),
          ).thenReturn(mockWorkEntriesSelectable);
          when(
            mockWorkEntriesSelectable.get,
          ).thenAnswer((_) async => [testJournalDbEntry]);

          when(
            () => mockJournalDb.linksForEntryIds({testJournalDbEntry.id}),
          ).thenAnswer(
            (_) async => [
              EntryLink.basic(
                id: 'status-test-link',
                fromId: taskWithStatus.meta.id,
                toId: testJournalDbEntry.id,
                createdAt: testDate,
                updatedAt: testDate,
                vectorClock: null,
              ),
            ],
          );

          when(
            () => mockJournalDb.getJournalEntitiesForIdsUnordered({
              taskWithStatus.meta.id,
            }),
          ).thenAnswer((_) async => [taskWithStatus]);

          // Mock the bulk linked entities method
          when(
            () => mockJournalDb.getBulkLinkedEntities({taskWithStatus.meta.id}),
          ).thenAnswer(
            (_) async => {taskWithStatus.meta.id: <JournalEntity>[]},
          );

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
          startDate: testStartDate.ymd,
          endDate: testEndDate.ymd,
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
        final expectedStartUtc = DateTime(
          testStartDate.year,
          testStartDate.month,
          testStartDate.day,
        ).toUtc();
        final expectedEndUtc = DateTime(
          testEndDate.year,
          testEndDate.month,
          testEndDate.day,
          23,
          59,
          59,
          999,
        ).toUtc();
        when(
          () => mockJournalDb.workEntriesInDateRange(
            ['JournalEntry', 'JournalAudio'],
            [testCategoryId],
            expectedStartUtc,
            expectedEndUtc,
          ),
        ).thenReturn(mockWorkEntriesSelectable);
        when(
          mockWorkEntriesSelectable.get,
        ).thenAnswer((_) async => [testJournalDbEntry]);

        when(
          () => mockJournalDb.linksForEntryIds({testJournalDbEntry.id}),
        ).thenAnswer((_) async => [testLink]);

        when(
          () => mockJournalDb.getJournalEntitiesForIdsUnordered({
            testTask.meta.id,
          }),
        ).thenAnswer((_) async => [testTask]);

        // Mock the bulk linked entities method
        when(
          () => mockJournalDb.getBulkLinkedEntities({testTask.meta.id}),
        ).thenAnswer(
          (_) async => {
            testTask.meta.id: [nonTaskSummaryAiResponse],
          },
        );

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
          startDate: testStartDate.ymd,
          endDate: testEndDate.ymd,
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
            // ignore: deprecated_member_use_from_same_package
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
        final expectedStartUtc = DateTime(
          testStartDate.year,
          testStartDate.month,
          testStartDate.day,
        ).toUtc();
        final expectedEndUtc = DateTime(
          testEndDate.year,
          testEndDate.month,
          testEndDate.day,
          23,
          59,
          59,
          999,
        ).toUtc();
        when(
          () => mockJournalDb.workEntriesInDateRange(
            ['JournalEntry', 'JournalAudio'],
            [testCategoryId],
            expectedStartUtc,
            expectedEndUtc,
          ),
        ).thenReturn(mockWorkEntriesSelectable);
        when(
          mockWorkEntriesSelectable.get,
        ).thenAnswer((_) async => [testJournalDbEntry, testJournalDbAudio2]);

        when(
          () => mockJournalDb.linksForEntryIds({
            testJournalDbEntry.id,
            testJournalDbAudio2.id,
          }),
        ).thenAnswer((_) async => [link1, link2]);

        when(
          () => mockJournalDb.getJournalEntitiesForIdsUnordered({
            testTask.meta.id,
            testTaskDone.meta.id,
          }),
        ).thenAnswer((_) async => [testTask, testTaskDone]);

        // Mock the bulk linked entities method for both tasks
        when(
          () => mockJournalDb.getBulkLinkedEntities({
            testTask.meta.id,
            testTaskDone.meta.id,
          }),
        ).thenAnswer(
          (_) async => {
            testTask.meta.id: [testAiResponse],
            testTaskDone.meta.id: [task2AiResponse],
          },
        );

        // Act
        final result = await repository.getTaskSummaries(
          categoryId: testCategoryId,
          request: request,
        );

        // Assert
        expect(result.length, 2);

        // Find results by task ID
        final task1Result = result.firstWhere(
          (r) => r.taskId == testTask.meta.id,
        );
        final task2Result = result.firstWhere(
          (r) => r.taskId == testTaskDone.meta.id,
        );

        expect(task1Result.summary, 'AI generated task summary');
        expect(task1Result.status, 'IN PROGRESS');

        expect(task2Result.summary, 'Second task summary');
        expect(task2Result.status, 'DONE');
      });
    });

    group('edge cases', () {
      test('throws when endDate is before startDate', () async {
        // Arrange
        final request = TaskSummaryRequest(
          startDate: '2024-01-15', // Later date
          endDate: '2024-01-10', // Earlier date - invalid
          limit: 10,
        );

        // Act & Assert
        expect(
          () => repository.getTaskSummaries(
            categoryId: testCategoryId,
            request: request,
          ),
          throwsA(isA<FormatException>()),
        );
      });

      test(
        'throws on invalid calendar date in start_date (e.g., 2024-02-31)',
        () async {
          final request = TaskSummaryRequest(
            startDate: '2024-02-31',
            endDate: '2024-03-01',
          );

          expect(
            () => repository.getTaskSummaries(
              categoryId: testCategoryId,
              request: request,
            ),
            throwsA(isA<FormatException>()),
          );
        },
      );

      test(
        'throws on invalid calendar date in end_date (e.g., 2024-02-31)',
        () async {
          final request = TaskSummaryRequest(
            startDate: '2024-03-01',
            endDate: '2024-02-31',
          );

          expect(
            () => repository.getTaskSummaries(
              categoryId: testCategoryId,
              request: request,
            ),
            throwsA(isA<FormatException>()),
          );
        },
      );

      test('throws on invalid date format (regex) in start_date', () async {
        final request = TaskSummaryRequest(
          startDate: '2024-2-01', // missing zero padding for month
          endDate: '2024-02-02',
        );

        expect(
          () => repository.getTaskSummaries(
            categoryId: testCategoryId,
            request: request,
          ),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws on invalid date format (regex) in end_date', () async {
        final request = TaskSummaryRequest(
          startDate: '2024-02-01',
          endDate: '2024-02-1', // missing zero padding for day
        );

        expect(
          () => repository.getTaskSummaries(
            categoryId: testCategoryId,
            request: request,
          ),
          throwsA(isA<FormatException>()),
        );
      });

      test('clamps limit to reasonable bounds - negative values', () async {
        // Arrange
        final request = TaskSummaryRequest(
          startDate: '2024-01-10',
          endDate: '2024-01-15',
          limit: -5, // Negative limit
        );

        final mockWorkEntriesSelectable = MockSelectable<JournalDbEntity>();
        when(
          () => mockJournalDb.workEntriesInDateRange(
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenReturn(mockWorkEntriesSelectable);
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
          startDate: '2024-01-10',
          endDate: '2024-01-15',
          limit: 99999, // Very large limit
        );

        final mockWorkEntriesSelectable = MockSelectable<JournalDbEntity>();
        when(
          () => mockJournalDb.workEntriesInDateRange(
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenReturn(mockWorkEntriesSelectable);
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

  group('taskSummaryRepository provider', () {
    late MockJournalDb providerJournalDb;

    setUp(() {
      providerJournalDb = MockJournalDb();
      if (getIt.isRegistered<JournalDb>()) {
        getIt.unregister<JournalDb>();
      }
      getIt.registerSingleton<JournalDb>(providerJournalDb);
    });

    tearDown(getIt.reset);

    /// Stubs [providerJournalDb] so that an end-to-end call resolves to a
    /// single task summary, proving the provider-built repository is wired to
    /// the GetIt-registered [JournalDb] and runs the full pipeline.
    void stubSingleTaskPipeline() {
      final workEntry = JournalDbEntity(
        id: 'provider-entry',
        createdAt: DateTime(2024, 1, 15),
        updatedAt: DateTime(2024, 1, 15),
        dateFrom: DateTime(2024, 1, 15),
        dateTo: DateTime(2024, 1, 15, 0, 0, 30),
        deleted: false,
        starred: false,
        private: false,
        task: false,
        flag: 0,
        type: 'JournalEntry',
        serialized: '{}',
        schemaVersion: 1,
        plainText: 'Work',
        category: 'cat-provider',
      );
      final task = JournalEntity.task(
        meta: Metadata(
          id: 'provider-task',
          createdAt: DateTime(2024, 1, 15),
          updatedAt: DateTime(2024, 1, 15),
          dateFrom: DateTime(2024, 1, 15),
          dateTo: DateTime(2024, 1, 15),
        ),
        data: TaskData(
          title: 'Provider Task',
          status: TaskStatus.open(
            id: 'provider-status',
            createdAt: DateTime(2024, 1, 15),
            utcOffset: 0,
          ),
          dateFrom: DateTime(2024, 1, 15),
          dateTo: DateTime(2024, 1, 15),
          statusHistory: const [],
        ),
      );
      final selectable = MockSelectable<JournalDbEntity>();
      when(
        () => providerJournalDb.workEntriesInDateRange(
          any(),
          any(),
          any(),
          any(),
        ),
      ).thenReturn(selectable);
      when(selectable.get).thenAnswer((_) async => [workEntry]);
      when(
        () => providerJournalDb.linksForEntryIds({workEntry.id}),
      ).thenAnswer(
        (_) async => [
          EntryLink.basic(
            id: 'provider-link',
            fromId: task.meta.id,
            toId: workEntry.id,
            createdAt: DateTime(2024, 1, 15),
            updatedAt: DateTime(2024, 1, 15),
            vectorClock: null,
          ),
        ],
      );
      when(
        () => providerJournalDb.getJournalEntitiesForIdsUnordered({
          task.meta.id,
        }),
      ).thenAnswer((_) async => [task]);
      when(
        () => providerJournalDb.getBulkLinkedEntities({task.meta.id}),
      ).thenAnswer((_) async => {task.meta.id: <JournalEntity>[]});
    }

    test(
      'builds a working repository wired to the GetIt JournalDb without '
      'an AgentDatabase registered',
      () async {
        expect(getIt.isRegistered<AgentDatabase>(), isFalse);
        stubSingleTaskPipeline();

        final container = ProviderContainer();
        addTearDown(container.dispose);

        final repo = container.read(taskSummaryRepositoryProvider);

        // Wired to the GetIt-registered JournalDb instance.
        expect(identical(repo.journalDb, providerJournalDb), isTrue);

        // Resolver was constructed without an agent repository (null branch),
        // so resolveMany never touches an agent DB and falls back to legacy.
        final summaries = await repo.taskSummaryResolver.resolveMany(
          {'provider-task'},
        );
        expect(summaries, isEmpty);

        // Full pipeline runs against the provided JournalDb.
        final results = await repo.getTaskSummaries(
          categoryId: 'cat-provider',
          request: const TaskSummaryRequest(
            startDate: '2024-01-01',
            endDate: '2024-01-31',
          ),
        );
        expect(results.length, 1);
        expect(results.first.taskId, 'provider-task');
        expect(
          results.first.summary,
          'No AI summary available for this task.',
        );
      },
    );

    test(
      'builds a repository with an AgentRepository-backed resolver when an '
      'AgentDatabase is registered',
      () async {
        final agentDb = MockAgentDatabase();
        getIt.registerSingleton<AgentDatabase>(agentDb);
        expect(getIt.isRegistered<AgentDatabase>(), isTrue);
        stubSingleTaskPipeline();

        final container = ProviderContainer();
        addTearDown(container.dispose);

        final repo = container.read(taskSummaryRepositoryProvider);

        expect(identical(repo.journalDb, providerJournalDb), isTrue);

        // The pipeline still completes end-to-end: the agent lookup against the
        // unstubbed mock fails inside resolveMany and is caught, falling back
        // to the legacy (here empty) summary. Reaching this result proves the
        // AgentRepository branch was taken at provider-build time.
        final results = await repo.getTaskSummaries(
          categoryId: 'cat-provider',
          request: const TaskSummaryRequest(
            startDate: '2024-01-01',
            endDate: '2024-01-31',
          ),
        );
        expect(results.length, 1);
        expect(results.first.taskId, 'provider-task');
        expect(
          results.first.summary,
          'No AI summary available for this task.',
        );
      },
    );
  });
}
