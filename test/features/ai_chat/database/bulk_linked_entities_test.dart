import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/state/consts.dart';

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

        for (var i = 0; i < 50; i++) {
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

          for (var j = 0; j < linkedCount; j++) {
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

        for (var i = 0; i < 10; i++) {
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

        // Bulk should be at most 150% of individual time (allowing for overhead)
        expect(bulkTime, lessThan(individualTime * 1.5 + 50)); // +50ms buffer
      });
    });

    group('deduplication and sorting', () {
      test('deduplicates entities when multiple links point to same target',
          () async {
        // Arrange - Create two tasks and one shared journal entry
        // This tests that when fetching bulk linked entities for multiple parents,
        // if they both link to the same entity, it's not duplicated in individual results
        final task1 = JournalEntity.task(
          meta: Metadata(
            id: 'task-dedup-1',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
          ),
          data: TaskData(
            title: 'Test Task 1',
            status: TaskStatus.open(
                id: 'status-1', createdAt: testDate, utcOffset: 0),
            dateFrom: testDate,
            dateTo: testDate,
            statusHistory: [],
          ),
        );

        final task2 = JournalEntity.task(
          meta: Metadata(
            id: 'task-dedup-2',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
          ),
          data: TaskData(
            title: 'Test Task 2',
            status: TaskStatus.done(
                id: 'status-2', createdAt: testDate, utcOffset: 0),
            dateFrom: testDate,
            dateTo: testDate,
            statusHistory: [],
          ),
        );

        final sharedEntry = JournalEntity.journalEntry(
          meta: Metadata(
            id: 'shared-entry',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate.add(const Duration(hours: 1)),
          ),
          entryText: const EntryText(plainText: 'Shared journal entry'),
        );

        // Both tasks link to the same entry
        final link1 = EntryLink.basic(
          id: 'link-dedup-1',
          fromId: task1.meta.id,
          toId: sharedEntry.meta.id,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );

        final link2 = EntryLink.basic(
          id: 'link-dedup-2',
          fromId: task2.meta.id,
          toId: sharedEntry.meta.id,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );

        // Save entities and links
        await journalDb.upsertJournalDbEntity(toDbEntity(task1));
        await journalDb.upsertJournalDbEntity(toDbEntity(task2));
        await journalDb.upsertJournalDbEntity(toDbEntity(sharedEntry));
        await journalDb.upsertEntryLink(link1);
        await journalDb.upsertEntryLink(link2);

        // Act
        final result = await journalDb
            .getBulkLinkedEntities({task1.meta.id, task2.meta.id});

        // Assert - Each task should have the shared entry once (not duplicated per task)
        expect(result, hasLength(2));
        expect(result[task1.meta.id], hasLength(1));
        expect(result[task2.meta.id], hasLength(1));
        expect(result[task1.meta.id]!.first.meta.id, sharedEntry.meta.id);
        expect(result[task2.meta.id]!.first.meta.id, sharedEntry.meta.id);

        // Verify they're the same entity instance (testing deduplication works)
        final entity1 = result[task1.meta.id]!.first;
        final entity2 = result[task2.meta.id]!.first;
        expect(entity1.meta.id, equals(entity2.meta.id));
      });

      test('sorts linked entities by dateFrom in descending order', () async {
        // Arrange - Create task and three journal entries with different dates
        final task = JournalEntity.task(
          meta: Metadata(
            id: 'task-sort-test',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
          ),
          data: TaskData(
            title: 'Test Task',
            status: TaskStatus.open(
                id: 'status-1', createdAt: testDate, utcOffset: 0),
            dateFrom: testDate,
            dateTo: testDate,
            statusHistory: [],
          ),
        );

        // Create entries with different dates (newest to oldest creation order)
        final newestEntry = JournalEntity.journalEntry(
          meta: Metadata(
            id: 'newest-entry',
            createdAt: testDate.add(const Duration(days: 3)),
            updatedAt: testDate.add(const Duration(days: 3)),
            dateFrom: testDate.add(const Duration(days: 3)), // Newest
            dateTo: testDate.add(const Duration(days: 3, hours: 1)),
          ),
          entryText: const EntryText(plainText: 'Newest entry'),
        );

        final middleEntry = JournalEntity.journalEntry(
          meta: Metadata(
            id: 'middle-entry',
            createdAt: testDate.add(const Duration(days: 2)),
            updatedAt: testDate.add(const Duration(days: 2)),
            dateFrom: testDate.add(const Duration(days: 2)), // Middle
            dateTo: testDate.add(const Duration(days: 2, hours: 1)),
          ),
          entryText: const EntryText(plainText: 'Middle entry'),
        );

        final oldestEntry = JournalEntity.journalEntry(
          meta: Metadata(
            id: 'oldest-entry',
            createdAt: testDate.add(const Duration(days: 1)),
            updatedAt: testDate.add(const Duration(days: 1)),
            dateFrom: testDate.add(const Duration(days: 1)), // Oldest
            dateTo: testDate.add(const Duration(days: 1, hours: 1)),
          ),
          entryText: const EntryText(plainText: 'Oldest entry'),
        );

        // Create links in non-chronological order to test sorting
        final linkToOldest = EntryLink.basic(
          id: 'link-to-oldest',
          fromId: task.meta.id,
          toId: oldestEntry.meta.id,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );

        final linkToNewest = EntryLink.basic(
          id: 'link-to-newest',
          fromId: task.meta.id,
          toId: newestEntry.meta.id,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );

        final linkToMiddle = EntryLink.basic(
          id: 'link-to-middle',
          fromId: task.meta.id,
          toId: middleEntry.meta.id,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );

        // Save entities and links
        await journalDb.upsertJournalDbEntity(toDbEntity(task));
        await journalDb.upsertJournalDbEntity(toDbEntity(newestEntry));
        await journalDb.upsertJournalDbEntity(toDbEntity(middleEntry));
        await journalDb.upsertJournalDbEntity(toDbEntity(oldestEntry));
        await journalDb.upsertEntryLink(linkToOldest);
        await journalDb.upsertEntryLink(linkToNewest);
        await journalDb.upsertEntryLink(linkToMiddle);

        // Act
        final result = await journalDb.getBulkLinkedEntities({task.meta.id});

        // Assert - Should be sorted by dateFrom descending (newest first)
        expect(result, hasLength(1));
        expect(result[task.meta.id], hasLength(3));

        final linkedEntries = result[task.meta.id]!;
        expect(linkedEntries[0].meta.id, newestEntry.meta.id); // First = newest
        expect(
            linkedEntries[1].meta.id, middleEntry.meta.id); // Second = middle
        expect(linkedEntries[2].meta.id, oldestEntry.meta.id); // Third = oldest

        // Double-check dates are actually in descending order
        expect(
          linkedEntries[0]
              .meta
              .dateFrom
              .isAfter(linkedEntries[1].meta.dateFrom),
          isTrue,
        );
        expect(
          linkedEntries[1]
              .meta
              .dateFrom
              .isAfter(linkedEntries[2].meta.dateFrom),
          isTrue,
        );
      });
    });
  });
}
