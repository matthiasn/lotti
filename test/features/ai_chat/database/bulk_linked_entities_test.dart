import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:mocktail/mocktail.dart';

// Mock implementations for focused testing
class MockJournalDb extends Mock implements JournalDb {}

void main() {
  group('JournalDb getBulkLinkedEntities', () {
    late JournalDb journalDb;
    final testDate = DateTime(2024, 1, 15);

    setUp(() {
      journalDb = JournalDb(inMemoryDatabase: true);
    });

    tearDown(() async {
      await journalDb.close();
    });

    group('basic functionality', () {
      test('returns empty map for empty input set', () async {
        // Act
        final result = await journalDb.getBulkLinkedEntities({});

        // Assert
        expect(result, isEmpty);
      });

      test('returns empty lists for IDs with no links', () async {
        // Arrange
        const taskId1 = 'task-1';
        const taskId2 = 'task-2';

        // Act
        final result =
            await journalDb.getBulkLinkedEntities({taskId1, taskId2});

        // Assert
        expect(result, hasLength(2));
        expect(result[taskId1], isEmpty);
        expect(result[taskId2], isEmpty);
      });

      test('integration test with real data', () async {
        // Arrange
        final task = JournalEntity.task(
          meta: Metadata(
            id: 'task-1',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
            categoryId: 'category-1',
          ),
          data: TaskData(
            title: 'Test Task',
            status: TaskStatus.open(
              id: 'status-1',
              createdAt: testDate,
              utcOffset: 0,
            ),
            dateFrom: testDate,
            dateTo: testDate,
            statusHistory: [],
          ),
          entryText: const EntryText(plainText: 'Task description'),
        );

        final aiResponse = JournalEntity.aiResponse(
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
            response: 'AI generated summary',
            promptId: 'prompt-123',
            type: AiResponseType.taskSummary,
          ),
          entryText: const EntryText(plainText: 'AI Response'),
        );

        final link = EntryLink.basic(
          id: 'link-1',
          fromId: task.meta.id,
          toId: aiResponse.meta.id,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );

        // Insert test data
        await journalDb.upsertJournalDbEntity(toDbEntity(task));
        await journalDb.upsertJournalDbEntity(toDbEntity(aiResponse));
        await journalDb.upsertEntryLink(link);

        // Act
        final result = await journalDb.getBulkLinkedEntities({task.meta.id});

        // Assert
        expect(result, hasLength(1));
        expect(result[task.meta.id], hasLength(1));
        expect(result[task.meta.id]!.first.meta.id, equals(aiResponse.meta.id));
        expect(result[task.meta.id]!.first.runtimeType.toString(),
            contains('AiResponseEntry'));
      });

      test('fetches linked entities for multiple parent IDs', () async {
        // Arrange
        final task1 = JournalEntity.task(
          meta: Metadata(
            id: 'task-1',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
            categoryId: 'category-1',
          ),
          data: TaskData(
            title: 'Test Task 1',
            status: TaskStatus.open(
              id: 'status-1',
              createdAt: testDate,
              utcOffset: 0,
            ),
            dateFrom: testDate,
            dateTo: testDate,
            statusHistory: [],
          ),
          entryText: const EntryText(plainText: 'Task 1 description'),
        );

        final task2 = JournalEntity.task(
          meta: Metadata(
            id: 'task-2',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
            categoryId: 'category-1',
          ),
          data: TaskData(
            title: 'Test Task 2',
            status: TaskStatus.done(
              id: 'status-2',
              createdAt: testDate,
              utcOffset: 0,
            ),
            dateFrom: testDate,
            dateTo: testDate,
            statusHistory: [],
          ),
          entryText: const EntryText(plainText: 'Task 2 description'),
        );

        final aiResponse1 = JournalEntity.aiResponse(
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
            response: 'AI summary for task 1',
            promptId: 'prompt-123',
            type: AiResponseType.taskSummary,
          ),
          entryText: const EntryText(plainText: 'AI Response 1'),
        );

        final aiResponse2 = JournalEntity.aiResponse(
          meta: Metadata(
            id: 'ai-response-2',
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
            response: 'AI summary for task 2',
            promptId: 'prompt-123',
            type: AiResponseType.taskSummary,
          ),
          entryText: const EntryText(plainText: 'AI Response 2'),
        );

        final link1 = EntryLink.basic(
          id: 'link-1',
          fromId: task1.meta.id,
          toId: aiResponse1.meta.id,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );

        final link2 = EntryLink.basic(
          id: 'link-2',
          fromId: task2.meta.id,
          toId: aiResponse2.meta.id,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );

        // Insert test data
        await journalDb.upsertJournalDbEntity(toDbEntity(task1));
        await journalDb.upsertJournalDbEntity(toDbEntity(task2));
        await journalDb.upsertJournalDbEntity(toDbEntity(aiResponse1));
        await journalDb.upsertJournalDbEntity(toDbEntity(aiResponse2));
        await journalDb.upsertEntryLink(link1);
        await journalDb.upsertEntryLink(link2);

        // Act
        final result = await journalDb
            .getBulkLinkedEntities({task1.meta.id, task2.meta.id});

        // Assert
        expect(result, hasLength(2));
        expect(result[task1.meta.id], hasLength(1));
        expect(result[task2.meta.id], hasLength(1));
        expect(
            result[task1.meta.id]!.first.meta.id, equals(aiResponse1.meta.id));
        expect(
            result[task2.meta.id]!.first.meta.id, equals(aiResponse2.meta.id));
      });

      test('handles multiple linked entities per parent ID', () async {
        // Arrange
        final task = JournalEntity.task(
          meta: Metadata(
            id: 'task-1',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
            categoryId: 'category-1',
          ),
          data: TaskData(
            title: 'Test Task',
            status: TaskStatus.open(
              id: 'status-1',
              createdAt: testDate,
              utcOffset: 0,
            ),
            dateFrom: testDate,
            dateTo: testDate,
            statusHistory: [],
          ),
          entryText: const EntryText(plainText: 'Task description'),
        );

        final aiResponse1 = JournalEntity.aiResponse(
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
            response: 'First AI summary',
            promptId: 'prompt-123',
            type: AiResponseType.taskSummary,
          ),
          entryText: const EntryText(plainText: 'AI Response 1'),
        );

        final aiResponse2 = JournalEntity.aiResponse(
          meta: Metadata(
            id: 'ai-response-2',
            createdAt: testDate.add(const Duration(hours: 1)),
            updatedAt: testDate.add(const Duration(hours: 1)),
            dateFrom: testDate.add(const Duration(hours: 1)),
            dateTo: testDate.add(const Duration(hours: 1)),
          ),
          data: const AiResponseData(
            model: 'gpt-4',
            systemMessage: 'You are a helpful assistant',
            prompt: 'Summarize this task',
            thoughts: 'User wants task summary',
            response: 'Second AI summary',
            promptId: 'prompt-123',
            type: AiResponseType.taskSummary,
          ),
          entryText: const EntryText(plainText: 'AI Response 2'),
        );

        final link1 = EntryLink.basic(
          id: 'link-1',
          fromId: task.meta.id,
          toId: aiResponse1.meta.id,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );

        final link2 = EntryLink.basic(
          id: 'link-2',
          fromId: task.meta.id,
          toId: aiResponse2.meta.id,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );

        // Insert test data
        await journalDb.upsertJournalDbEntity(toDbEntity(task));
        await journalDb.upsertJournalDbEntity(toDbEntity(aiResponse1));
        await journalDb.upsertJournalDbEntity(toDbEntity(aiResponse2));
        await journalDb.upsertEntryLink(link1);
        await journalDb.upsertEntryLink(link2);

        // Act
        final result = await journalDb.getBulkLinkedEntities({task.meta.id});

        // Assert
        expect(result, hasLength(1));
        expect(result[task.meta.id], hasLength(2));
        final linkedIds = result[task.meta.id]!.map((e) => e.meta.id).toSet();
        expect(
            linkedIds, containsAll([aiResponse1.meta.id, aiResponse2.meta.id]));
      });
    });

    group('edge cases and error handling', () {
      test('handles broken links gracefully', () async {
        // Arrange - create a link pointing to non-existent entity
        final task = JournalEntity.task(
          meta: Metadata(
            id: 'task-1',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
            categoryId: 'category-1',
          ),
          data: TaskData(
            title: 'Test Task',
            status: TaskStatus.open(
              id: 'status-1',
              createdAt: testDate,
              utcOffset: 0,
            ),
            dateFrom: testDate,
            dateTo: testDate,
            statusHistory: [],
          ),
          entryText: const EntryText(plainText: 'Task description'),
        );

        final brokenLink = EntryLink.basic(
          id: 'broken-link',
          fromId: task.meta.id,
          toId: 'non-existent-entity',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );

        // Insert only task and broken link (no target entity)
        await journalDb.upsertJournalDbEntity(toDbEntity(task));
        await journalDb.upsertEntryLink(brokenLink);

        // Act
        final result = await journalDb.getBulkLinkedEntities({task.meta.id});

        // Assert - should handle broken link gracefully
        expect(result, hasLength(1));
        expect(result[task.meta.id], isEmpty); // Broken link should be ignored
      });

      test('handles mix of valid and invalid parent IDs', () async {
        // Arrange
        final task = JournalEntity.task(
          meta: Metadata(
            id: 'task-1',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
            categoryId: 'category-1',
          ),
          data: TaskData(
            title: 'Test Task',
            status: TaskStatus.open(
              id: 'status-1',
              createdAt: testDate,
              utcOffset: 0,
            ),
            dateFrom: testDate,
            dateTo: testDate,
            statusHistory: [],
          ),
          entryText: const EntryText(plainText: 'Task description'),
        );

        final aiResponse = JournalEntity.aiResponse(
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
            response: 'AI summary',
            promptId: 'prompt-123',
            type: AiResponseType.taskSummary,
          ),
          entryText: const EntryText(plainText: 'AI Response'),
        );

        final link = EntryLink.basic(
          id: 'link-1',
          fromId: task.meta.id,
          toId: aiResponse.meta.id,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );

        // Insert test data
        await journalDb.upsertJournalDbEntity(toDbEntity(task));
        await journalDb.upsertJournalDbEntity(toDbEntity(aiResponse));
        await journalDb.upsertEntryLink(link);

        // Act - include valid and invalid parent IDs
        final result = await journalDb
            .getBulkLinkedEntities({task.meta.id, 'non-existent-parent'});

        // Assert
        expect(result, hasLength(2));
        expect(result[task.meta.id], hasLength(1));
        expect(result['non-existent-parent'], isEmpty);
      });

      test('handles large number of parent IDs efficiently', () async {
        // Arrange - create 50 tasks with linked entities
        final taskIds = <String>{};
        final expectedLinkedCount = <String, int>{};

        for (int i = 0; i < 50; i++) {
          final taskId = 'task-$i';
          taskIds.add(taskId);

          final task = JournalEntity.task(
            meta: Metadata(
              id: taskId,
              createdAt: testDate,
              updatedAt: testDate,
              dateFrom: testDate,
              dateTo: testDate,
              categoryId: 'category-1',
            ),
            data: TaskData(
              title: 'Test Task $i',
              status: TaskStatus.open(
                id: 'status-$i',
                createdAt: testDate,
                utcOffset: 0,
              ),
              dateFrom: testDate,
              dateTo: testDate,
              statusHistory: [],
            ),
            entryText: EntryText(plainText: 'Task $i description'),
          );

          await journalDb.upsertJournalDbEntity(toDbEntity(task));

          // Create 1-3 linked entities per task
          final linkedCount = (i % 3) + 1;
          expectedLinkedCount[taskId] = linkedCount;

          for (int j = 0; j < linkedCount; j++) {
            final responseId = 'ai-response-$i-$j';
            final aiResponse = JournalEntity.aiResponse(
              meta: Metadata(
                id: responseId,
                createdAt: testDate,
                updatedAt: testDate,
                dateFrom: testDate,
                dateTo: testDate,
              ),
              data: AiResponseData(
                model: 'gpt-4',
                systemMessage: 'You are a helpful assistant',
                prompt: 'Summarize this task',
                thoughts: 'User wants task summary',
                response: 'AI summary $i-$j',
                promptId: 'prompt-123',
                type: AiResponseType.taskSummary,
              ),
              entryText: EntryText(plainText: 'AI Response $i-$j'),
            );

            final link = EntryLink.basic(
              id: 'link-$i-$j',
              fromId: taskId,
              toId: responseId,
              createdAt: testDate,
              updatedAt: testDate,
              vectorClock: null,
            );

            await journalDb.upsertJournalDbEntity(toDbEntity(aiResponse));
            await journalDb.upsertEntryLink(link);
          }
        }

        // Act
        final stopwatch = Stopwatch()..start();
        final result = await journalDb.getBulkLinkedEntities(taskIds);
        stopwatch.stop();

        // Assert
        expect(result, hasLength(50));
        expect(stopwatch.elapsedMilliseconds,
            lessThan(1000)); // Should complete in < 1 second

        // Verify each task has the expected number of linked entities
        for (final taskId in taskIds) {
          expect(result[taskId], hasLength(expectedLinkedCount[taskId]));
        }
      });
    });

    group('performance comparison', () {
      test('bulk method is faster than individual calls for multiple entities',
          () async {
        // Arrange - create 10 tasks with linked entities
        final taskIds = <String>{};

        for (int i = 0; i < 10; i++) {
          final taskId = 'task-$i';
          taskIds.add(taskId);

          final task = JournalEntity.task(
            meta: Metadata(
              id: taskId,
              createdAt: testDate,
              updatedAt: testDate,
              dateFrom: testDate,
              dateTo: testDate,
              categoryId: 'category-1',
            ),
            data: TaskData(
              title: 'Test Task $i',
              status: TaskStatus.open(
                id: 'status-$i',
                createdAt: testDate,
                utcOffset: 0,
              ),
              dateFrom: testDate,
              dateTo: testDate,
              statusHistory: [],
            ),
            entryText: EntryText(plainText: 'Task $i description'),
          );

          final aiResponse = JournalEntity.aiResponse(
            meta: Metadata(
              id: 'ai-response-$i',
              createdAt: testDate,
              updatedAt: testDate,
              dateFrom: testDate,
              dateTo: testDate,
            ),
            data: AiResponseData(
              model: 'gpt-4',
              systemMessage: 'You are a helpful assistant',
              prompt: 'Summarize this task',
              thoughts: 'User wants task summary',
              response: 'AI summary $i',
              promptId: 'prompt-123',
              type: AiResponseType.taskSummary,
            ),
            entryText: EntryText(plainText: 'AI Response $i'),
          );

          final link = EntryLink.basic(
            id: 'link-$i',
            fromId: taskId,
            toId: 'ai-response-$i',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          );

          await journalDb.upsertJournalDbEntity(toDbEntity(task));
          await journalDb.upsertJournalDbEntity(toDbEntity(aiResponse));
          await journalDb.upsertEntryLink(link);
        }

        // Act - measure bulk method
        final bulkStopwatch = Stopwatch()..start();
        final bulkResult = await journalDb.getBulkLinkedEntities(taskIds);
        bulkStopwatch.stop();

        // Act - measure individual calls
        final individualStopwatch = Stopwatch()..start();
        final individualResults = <String, List<JournalEntity>>{};
        for (final taskId in taskIds) {
          individualResults[taskId] = await journalDb.getLinkedEntities(taskId);
        }
        individualStopwatch.stop();

        // Assert - results should be equivalent
        expect(bulkResult.length, equals(individualResults.length));
        for (final taskId in taskIds) {
          expect(bulkResult[taskId]?.length,
              equals(individualResults[taskId]?.length));
        }

        // Assert - bulk should be faster or comparable
        // Note: In memory databases might not show significant difference,
        // but bulk should never be significantly slower
        final bulkTime = bulkStopwatch.elapsedMilliseconds;
        final individualTime = individualStopwatch.elapsedMilliseconds;

        print('Bulk method: ${bulkTime}ms');
        print('Individual calls: ${individualTime}ms');

        // Bulk should be at most 150% of individual time (allowing for overhead)
        expect(bulkTime, lessThan(individualTime * 1.5 + 50)); // +50ms buffer
      });
    });
  });
}
