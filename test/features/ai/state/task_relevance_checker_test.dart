import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/state/task_relevance_checker.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';
import 'package:research_package/model.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockSelectable<T> extends Mock implements Selectable<T> {}

void main() {
  late TaskRelevanceChecker checker;
  late MockJournalDb mockDb;
  const testTaskId = 'test-task-1';

  setUp(() {
    mockDb = MockJournalDb();
    getIt.registerSingleton<JournalDb>(mockDb);
    checker = TaskRelevanceChecker(taskId: testTaskId);
  });

  tearDown(getIt.reset);

  group('TaskRelevanceChecker', () {
    group('shouldSkipNotification', () {
      test('returns true when only AI response notification is present', () {
        expect(
          checker.shouldSkipNotification({aiResponseNotification}),
          isTrue,
        );
      });

      test(
          'returns false when AI response notification is bundled with other IDs',
          () {
        expect(
          checker.shouldSkipNotification({aiResponseNotification, 'other-id'}),
          isFalse,
        );
      });

      test('returns false when AI response notification is not present', () {
        expect(
          checker.shouldSkipNotification({'some-id', 'other-id'}),
          isFalse,
        );
      });

      test('returns false for empty set', () {
        expect(
          checker.shouldSkipNotification({}),
          isFalse,
        );
      });
    });

    group('isUpdateRelevantToTask', () {
      test('returns true when task ID is in affected IDs', () async {
        final result =
            await checker.isUpdateRelevantToTask({testTaskId, 'other-id'});
        expect(result, isTrue);
      });

      test('returns false when only notification constants are present',
          () async {
        final result = await checker.isUpdateRelevantToTask({
          'SOME_NOTIFICATION',
          'OTHER_NOTIFICATION',
          aiResponseNotification,
        });
        expect(result, isFalse);
      });

      test('returns false when no entities are found', () async {
        when(() => mockDb.journalEntityById(any()))
            .thenAnswer((_) async => null);

        final result =
            await checker.isUpdateRelevantToTask({'entity-1', 'entity-2'});
        expect(result, isFalse);
      });
    });

    group('isChecklistItemRelevant', () {
      test('returns true when task ID is in affected IDs', () async {
        final item = _createChecklistItem('item-1', []);
        final result = await checker.isChecklistItemRelevant(
          item,
          {testTaskId, 'item-1'},
        );
        expect(result, isTrue);
      });

      test('returns false when item has no linked checklists', () async {
        final item = _createChecklistItem('item-1', []);
        final result = await checker.isChecklistItemRelevant(
          item,
          {'item-1'},
        );
        expect(result, isFalse);
      });

      test('returns true when item is linked through a checklist to the task',
          () async {
        final item = _createChecklistItem('item-1', ['checklist-1']);
        final checklist = _createChecklist('checklist-1', [testTaskId]);

        when(() => mockDb.journalEntityById('checklist-1'))
            .thenAnswer((_) async => checklist);

        final result = await checker.isChecklistItemRelevant(
          item,
          {'item-1'},
        );
        expect(result, isTrue);
      });

      test('returns false when linked checklist does not contain the task',
          () async {
        final item = _createChecklistItem('item-1', ['checklist-1']);
        final checklist = _createChecklist('checklist-1', ['other-task']);

        when(() => mockDb.journalEntityById('checklist-1'))
            .thenAnswer((_) async => checklist);

        final result = await checker.isChecklistItemRelevant(
          item,
          {'item-1'},
        );
        expect(result, isFalse);
      });
    });

    group('isChecklistRelevant', () {
      test('returns true when checklist contains the task', () {
        final checklist = _createChecklist('checklist-1', [testTaskId]);
        expect(checker.isChecklistRelevant(checklist), isTrue);
      });

      test('returns false when checklist does not contain the task', () {
        final checklist = _createChecklist('checklist-1', ['other-task']);
        expect(checker.isChecklistRelevant(checklist), isFalse);
      });

      test('returns false when checklist has no linked tasks', () {
        final checklist = _createChecklist('checklist-1', []);
        expect(checker.isChecklistRelevant(checklist), isFalse);
      });
    });

    group('isJournalEntryRelevant', () {
      test('returns false when entry has no text', () async {
        final entry = _createJournalEntry('entry-1', null);
        final result = await checker.isJournalEntryRelevant(entry);
        expect(result, isFalse);
      });

      test('returns false when entry has empty text', () async {
        final entry = _createJournalEntry('entry-1', '   ');
        final result = await checker.isJournalEntryRelevant(entry);
        expect(result, isFalse);
      });

      test('returns true when entry is linked to the task', () async {
        final entry = _createJournalEntry('entry-1', 'Some text');
        final link = _createLink('link-1', 'entry-1', testTaskId);
        final mockSelectable = MockSelectable<LinkedDbEntry>();

        when(() => mockDb.linksFromId('entry-1', [false]))
            .thenReturn(mockSelectable);
        when(mockSelectable.get).thenAnswer((_) async => [link]);

        final result = await checker.isJournalEntryRelevant(entry);
        expect(result, isTrue);
      });

      test('returns false when entry is not linked to the task', () async {
        final entry = _createJournalEntry('entry-1', 'Some text');
        final link = _createLink('link-1', 'entry-1', 'other-task');
        final mockSelectable = MockSelectable<LinkedDbEntry>();

        when(() => mockDb.linksFromId('entry-1', [false]))
            .thenReturn(mockSelectable);
        when(mockSelectable.get).thenAnswer((_) async => [link]);

        final result = await checker.isJournalEntryRelevant(entry);
        expect(result, isFalse);
      });
    });

    group('isEntityRelevantToTask', () {
      test('handles ChecklistItem correctly', () async {
        final item = _createChecklistItem('item-1', []);
        final result = await checker.isEntityRelevantToTask(
          item,
          {testTaskId, 'item-1'},
        );
        expect(result, isTrue);
      });

      test('handles Checklist correctly', () async {
        final checklist = _createChecklist('checklist-1', [testTaskId]);
        final result = await checker.isEntityRelevantToTask(
          checklist,
          {'checklist-1'},
        );
        expect(result, isTrue);
      });

      test('handles JournalEntry correctly', () async {
        final entry = _createJournalEntry('entry-1', null);
        final result = await checker.isEntityRelevantToTask(
          entry,
          {'entry-1'},
        );
        expect(result, isFalse);
      });

      test('returns false for survey entities', () async {
        // Create a survey entity which is not handled
        final surveyEntity = JournalEntity.survey(
          meta: Metadata(
            id: 'survey-1',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          data: SurveyData(
            taskResult: RPTaskResult(identifier: 'test'),
            scoreDefinitions: const {},
            calculatedScores: const {},
          ),
        );
        final result = await checker.isEntityRelevantToTask(
          surveyEntity,
          {'survey-1'},
        );
        expect(result, isFalse);
      });
    });

    group('edge cases', () {
      test('handles null entities gracefully', () async {
        when(() => mockDb.journalEntityById(any()))
            .thenAnswer((_) async => null);

        final result = await checker.isUpdateRelevantToTask({'entity-1'});
        expect(result, isFalse);
      });

      test('handles mixed entity types in batch', () async {
        final item = _createChecklistItem('item-1', ['checklist-1']);
        final checklist = _createChecklist('checklist-1', [testTaskId]);
        final entry = _createJournalEntry('entry-1', 'Text');

        when(() => mockDb.journalEntityById('item-1'))
            .thenAnswer((_) async => item);
        when(() => mockDb.journalEntityById('checklist-1'))
            .thenAnswer((_) async => checklist);
        when(() => mockDb.journalEntityById('entry-1'))
            .thenAnswer((_) async => entry);

        final mockSelectable = MockSelectable<LinkedDbEntry>();
        when(() => mockDb.linksFromId('entry-1', [false]))
            .thenReturn(mockSelectable);
        when(mockSelectable.get).thenAnswer((_) async => <LinkedDbEntry>[]);

        final result = await checker.isUpdateRelevantToTask({
          'item-1',
          'checklist-1',
          'entry-1',
        });
        expect(result, isTrue); // Because checklist is linked to task
      });

      test('handles deeply nested checklist relationships', () async {
        // Item -> Checklist1 -> No task
        // Item -> Checklist2 -> Has task
        final item =
            _createChecklistItem('item-1', ['checklist-1', 'checklist-2']);
        final checklist1 = _createChecklist('checklist-1', ['other-task']);
        final checklist2 =
            _createChecklist('checklist-2', [testTaskId, 'other-task']);

        when(() => mockDb.journalEntityById('item-1'))
            .thenAnswer((_) async => item);
        when(() => mockDb.journalEntityById('checklist-1'))
            .thenAnswer((_) async => checklist1);
        when(() => mockDb.journalEntityById('checklist-2'))
            .thenAnswer((_) async => checklist2);

        final result = await checker.isChecklistItemRelevant(item, {'item-1'});
        expect(result, isTrue);
      });
    });
  });
}

// Helper functions to create test entities
ChecklistItem _createChecklistItem(String id, List<String> linkedChecklists) {
  return ChecklistItem(
    meta: Metadata(
      id: id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      dateFrom: DateTime.now(),
      dateTo: DateTime.now(),
    ),
    data: ChecklistItemData(
      title: 'Test item',
      isChecked: false,
      linkedChecklists: linkedChecklists,
    ),
  );
}

Checklist _createChecklist(String id, List<String> linkedTasks) {
  return Checklist(
    meta: Metadata(
      id: id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      dateFrom: DateTime.now(),
      dateTo: DateTime.now(),
    ),
    data: ChecklistData(
      title: 'Test checklist',
      linkedChecklistItems: [],
      linkedTasks: linkedTasks,
    ),
  );
}

JournalEntry _createJournalEntry(String id, String? text) {
  return JournalEntry(
    meta: Metadata(
      id: id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      dateFrom: DateTime.now(),
      dateTo: DateTime.now(),
    ),
    entryText: text != null
        ? EntryText(
            plainText: text,
            markdown: text,
          )
        : null,
  );
}

LinkedDbEntry _createLink(String id, String fromId, String toId) {
  return LinkedDbEntry(
    id: id,
    fromId: fromId,
    toId: toId,
    type: 'link',
    serialized: '',
    hidden: false,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}
