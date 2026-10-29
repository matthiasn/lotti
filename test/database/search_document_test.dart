import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_data.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/search_document.dart';
import 'package:research_package/model.dart';

import '../features/github/pull_request_fixtures.dart';
import '../test_data/test_data.dart';

void main() {
  SearchDocument documentOf(
    JournalEntity entity, {
    Map<String, MeasurableDataType> dataTypes = const {},
  }) => searchDocumentFor(
    entity,
    measurableDataType: (id) => dataTypes[id],
  );

  final meta = testTextEntry.meta.copyWith(id: 'entity-1');

  JournalEntity goal({String? snapshotOf}) => JournalEntity.goal(
    meta: meta,
    data: GoalData(
      title: 'Waddle more',
      statement: 'Waddle to the ice shelf five days a week.',
      criteria: const GoalCriterion.habit(
        criterionId: 'waddle-daily',
        habitId: 'habit-waddle',
        targetCount: 5,
        window: GoalWindow.rollingDays(count: 7),
      ),
      specVersion: 1,
      specVersionId: 'goal-1:spec-v1',
      snapshotOf: snapshotOf,
    ),
  );

  test('a task is found by its title first, then by its description', () {
    final document = documentOf(testTask);

    expect(document.title, testTask.data.title);
    expect(document.body, testTask.entryText!.plainText);
  });

  test('an entry contributes its text', () {
    expect(
      documentOf(testTextEntry),
      SearchDocument(
        title: '',
        body: testTextEntry.entryText!.plainText,
        extra: '',
      ),
    );
  });

  test('titled kinds put their name in the title', () {
    final item = JournalEntity.checklistItem(
      meta: meta,
      data: const ChecklistItemData(
        title: 'Count the chicks',
        isChecked: false,
        linkedChecklists: [],
      ),
    );
    final waddle = goal();

    expect(documentOf(item).title, 'Count the chicks');
    expect(documentOf(waddle).title, 'Waddle more');
    expect(
      documentOf(waddle).body,
      'Waddle to the ice shelf five days a week.',
    );
  });

  test('a person is found by their name', () {
    expect(documentOf(testRelationship).title, testRelationship.data.title);
  });

  test('a goal spec snapshot contributes nothing: its goal is found '
      'instead', () {
    final snapshot = goal(snapshotOf: 'goal-1');

    expect(documentOf(snapshot).isEmpty, isTrue);
  });

  test('a recording contributes its edited text, else its last '
      'transcript', () {
    expect(
      documentOf(testAudioEntryWithTranscripts).body,
      testAudioEntryWithTranscripts.entryText!.plainText,
    );
    final untouched = testAudioEntryWithTranscripts.copyWith(entryText: null);
    expect(documentOf(untouched).body, 'transcript');
  });

  test('a pull request is found by its title, its description and its '
      'key', () {
    final document = documentOf(
      prEntry(clock: {'a': 1}, snapshot: prSnapshot()),
    );

    expect(document.title, 'Track pull requests');
    expect(document.extra, 'matthiasn/lotti#42');
  });

  // ADR 0139: a check-in is found by its topics and its notes for next
  // time, not only by the note it was logged with.
  test('a check-in is found by its topics and next-time notes', () {
    final checkIn = JournalEntity.checkIn(
      meta: meta,
      entryText: const EntryText(plainText: 'Walked the launch window.'),
      data: const CheckInData(
        relationshipId: 'pip',
        interactionType: CheckInInteractionType.call,
        topics: ['krill logistics'],
        payAttentionTo: 'The contract deadline',
        avoid: 'Pad three',
      ),
    );

    final document = documentOf(checkIn);
    expect(document.title, 'krill logistics The contract deadline Pad three');
    expect(document.body, 'Walked the launch window.');
  });

  test('a survey is found by its identifier and its scores', () {
    final survey = SurveyEntry(
      meta: meta,
      data: SurveyData(
        taskResult: RPTaskResult(identifier: 'panasSurveyTask'),
        scoreDefinitions: const {
          'Positive Affect': {'q1'},
        },
        calculatedScores: const {'Positive Affect': 10},
      ),
    );

    expect(documentOf(survey).title, 'panasSurveyTask');
    expect(documentOf(survey).extra, 'Positive Affect: 10');
  });

  group('measurements read their labels from the definition', () {
    test('a number keeps its name, value and unit', () {
      final document = documentOf(
        testMeasurementChocolateEntry,
        dataTypes: {measurableChocolate.id: measurableChocolate},
      );
      expect(document.extra, 'Chocolate 100 g');
    });

    test('a choice indexes its title, not the occurrence count', () {
      final document = documentOf(
        testMeasurementHydrationEntry,
        dataTypes: {measurableHydration.id: measurableHydration},
      );
      expect(document.extra, contains(hydrationClear.title));
      expect(document.extra, isNot(contains('1')));
    });

    test('a measurement whose definition is gone keeps its number', () {
      expect(
        documentOf(testMeasurementChocolateEntry).extra,
        '${testMeasurementChocolateEntry.data.value}',
      );
    });
  });

  test('a health reading keeps its value, unit and name', () {
    final document = documentOf(testWeightEntry);
    expect(document.extra, contains('Weight'));
    expect(document.extra, contains('${testWeightEntry.data.value}'));
  });

  test('blank text makes an empty document', () {
    expect(
      const SearchDocument(title: ' ', body: '\n', extra: '').isEmpty,
      isTrue,
    );
    expect(
      documentOf(testTextEntry.copyWith(entryText: null)).isEmpty,
      isTrue,
    );
  });
}
