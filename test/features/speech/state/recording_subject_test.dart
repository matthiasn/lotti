import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_data.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/speech/state/recording_subject.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../projects/test_utils.dart';

final _goal = GoalEntry(
  meta: Metadata(
    id: 'goal-row',
    createdAt: DateTime(2026, 8),
    updatedAt: DateTime(2026, 8),
    dateFrom: DateTime(2026, 8),
    dateTo: DateTime(2026, 8),
  ),
  data: const GoalData(
    title: '  Daily journal  ',
    statement: 'Reflect every day.',
    criteria: GoalCriterion.checkInTime(
      criterionId: 'reflect',
      window: GoalWindow.day(),
      aggregation: GoalAggregation.sum,
      targetMinutes: 3,
    ),
    specVersion: 1,
    specVersionId: 'agent-1:spec-v1',
  ),
);

final ProjectEntry _project = makeTestProject(
  id: 'project-1',
  title: 'Orbital habitat',
);

void main() {
  group('recordingSubjectTitle', () {
    final meta = testTextEntry.meta;
    for (final (name, subject, expected) in <(String, JournalEntity?, String?)>[
      ('a task is its title', testTask, testTask.data.title),
      ('a project is its title', _project, 'Orbital habitat'),
      ('a goal is its title, trimmed', _goal, 'Daily journal'),
      ('a person is their name', testRelationship, 'Anna'),
      (
        'an entry is its words, trimmed',
        JournalEntity.journalEntry(
          meta: meta,
          entryText: const EntryText(plainText: '  Call the vet  '),
        ),
        'Call the vet',
      ),
      (
        'an entry with no words is nothing',
        JournalEntity.journalEntry(
          meta: meta,
          entryText: const EntryText(plainText: '   '),
        ),
        null,
      ),
      (
        'an entry with no text at all is nothing',
        JournalEntry(meta: meta),
        null,
      ),
      ('no subject is nothing', null, null),
    ]) {
      test(name, () => expect(recordingSubjectTitle(subject), expected));
    }
  });

  group('recordingSubjectRoute', () {
    for (final (name, subject, expected) in <(String, JournalEntity, String?)>[
      ('a task is its task page', testTask, '/tasks/${testTask.id}'),
      ('a project is its project page', _project, '/projects/project-1'),
      (
        'a person is their page',
        testRelationship,
        '/people/${testRelationship.id}',
      ),
      ('a goal has no page by its entry id', _goal, null),
      (
        'anything else is its logbook entry',
        testTextEntry,
        '/journal/${testTextEntry.id}',
      ),
    ]) {
      test(name, () => expect(recordingSubjectRoute(subject), expected));
    }
  });

  group('recordingSubjectProvider', () {
    late MockJournalDb db;
    late ProviderContainer container;

    setUp(() {
      db = MockJournalDb();
      container = ProviderContainer(
        overrides: [journalDbProvider.overrideWithValue(db)],
      );
    });
    tearDown(() => container.dispose());

    test('reads the subject by id', () async {
      when(
        () => db.journalEntityById('task-1'),
      ).thenAnswer((_) async => testTask);
      expect(
        await container.read(recordingSubjectProvider('task-1').future),
        testTask,
      );
    });

    test('a deleted subject is null', () async {
      when(() => db.journalEntityById('gone')).thenAnswer((_) async => null);
      expect(
        await container.read(recordingSubjectProvider('gone').future),
        isNull,
      );
    });

    test('a subject that cannot be read is null, like a deleted one', () async {
      when(
        () => db.journalEntityById('broken'),
      ).thenThrow(StateError('database closed'));
      expect(
        await container.read(recordingSubjectProvider('broken').future),
        isNull,
      );
    });
  });
}
