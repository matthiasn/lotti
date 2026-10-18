import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_data.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/goals/model/goal_entry_ids.dart';
import 'package:lotti/features/goals/repository/goal_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

void main() {
  final testDate = DateTime(2026, 8, 18, 10, 30);

  const criteria = GoalCriterion.habit(
    criterionId: 'walk-daily',
    habitId: 'habit-walk',
    targetCount: 5,
    window: GoalWindow.rollingDays(count: 7),
  );

  late MockJournalDb mockDb;
  late MockPersistenceLogic mockPersistence;
  late MockMetadataService mockMetadata;
  late GoalRepository repository;

  Metadata meta(String id) => Metadata(
    id: id,
    createdAt: testDate,
    updatedAt: testDate,
    dateFrom: testDate,
    dateTo: testDate,
  );

  GoalEntry goalEntry({
    required String id,
    String title = 'Walk more',
    int specVersion = 1,
    String specVersionId = 'agent-1:spec-v1',
    String? snapshotOf,
  }) => GoalEntry(
    meta: meta(id),
    data: GoalData(
      title: title,
      statement: 'Walk on five days a week.',
      criteria: criteria,
      specVersion: specVersion,
      specVersionId: specVersionId,
      snapshotOf: snapshotOf,
    ),
  );

  JournalAudio audio(String id, {String? transcript, DateTime? deletedAt}) =>
      JournalAudio(
        meta: meta(id).copyWith(deletedAt: deletedAt),
        data: AudioData(
          dateFrom: testDate,
          dateTo: testDate,
          audioFile: '$id.m4a',
          audioDirectory: '/audio/',
          duration: const Duration(seconds: 30),
        ),
        entryText: transcript == null ? null : EntryText(plainText: transcript),
      );

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(goalEntry(id: 'fallback'));
    registerFallbackValue(meta('fallback'));
  });

  setUp(() {
    mockDb = MockJournalDb();
    mockPersistence = MockPersistenceLogic();
    mockMetadata = MockMetadataService();
    repository = GoalRepository(
      journalDb: mockDb,
      persistenceLogic: mockPersistence,
      metadataService: mockMetadata,
    );

    // Mirrors MetadataService.generateId closely enough to distinguish the
    // two id families without reimplementing UUID v5.
    when(
      () => mockMetadata.generateId(uuidV5Input: any(named: 'uuidV5Input')),
    ).thenAnswer(
      (invocation) =>
          'derived:${invocation.namedArguments[#uuidV5Input] as String}',
    );
  });

  group('getGoalForAgent', () {
    test('resolves the goal through the derived id', () async {
      final expectedId = 'derived:${goalEntryUuidV5Input('agent-1')}';
      final entry = goalEntry(id: expectedId);
      when(
        () => mockDb.journalEntityById(expectedId),
      ).thenAnswer((_) async => entry);

      expect(await repository.getGoalForAgent('agent-1'), entry);
      verify(() => mockDb.journalEntityById(expectedId)).called(1);
    });

    test('returns null for a soft-deleted goal', () async {
      final expectedId = 'derived:${goalEntryUuidV5Input('agent-1')}';
      final deleted = GoalEntry(
        meta: meta(expectedId).copyWith(deletedAt: testDate),
        data: goalEntry(id: expectedId).data,
      );
      when(
        () => mockDb.journalEntityById(expectedId),
      ).thenAnswer((_) async => deleted);

      expect(await repository.getGoalForAgent('agent-1'), isNull);
    });
  });

  group('list reads', () {
    test('getGoals delegates to the indexed goal query', () async {
      final entry = goalEntry(id: 'goal-1');
      when(() => mockDb.getGoals()).thenAnswer((_) async => [entry]);

      expect(await repository.getGoals(), [entry]);
      verify(() => mockDb.getGoals()).called(1);
    });

    test('getSpecSnapshots reads the version history of one goal', () async {
      final snapshot = goalEntry(id: 'snap-1', snapshotOf: 'goal-1');
      when(
        () => mockDb.getSpecSnapshotsForGoal('goal-1'),
      ).thenAnswer((_) async => [snapshot]);

      expect(await repository.getSpecSnapshots('goal-1'), [snapshot]);
      // Scoped to the goal: the snapshots ride the subtype index, so an
      // unscoped read would return every goal's history.
      verify(() => mockDb.getSpecSnapshotsForGoal('goal-1')).called(1);
    });
  });

  group('criterionNames', () {
    test('names the habits and measurables it can find and leaves the rest '
        'out', () async {
      when(
        () => mockDb.getHabitById(habitFlossing.id),
      ).thenAnswer((_) async => habitFlossing);
      when(
        () => mockDb.getHabitById('missing-habit'),
      ).thenAnswer((_) async => null);
      when(
        () => mockDb.getMeasurableDataTypeById(measurableWater.id),
      ).thenAnswer((_) async => measurableWater);

      final names = await repository.criterionNames((
        habitIds: {habitFlossing.id, 'missing-habit'},
        dataTypeIds: {measurableWater.id},
      ));

      expect(names, {
        habitFlossing.id: habitFlossing.name,
        measurableWater.id: measurableWater.displayName,
      });
    });

    test('empty id sets touch the database not at all', () async {
      expect(
        await repository.criterionNames((habitIds: {}, dataTypeIds: {})),
        isEmpty,
      );
      verifyNever(() => mockDb.getHabitById(any()));
      verifyNever(() => mockDb.getMeasurableDataTypeById(any()));
    });
  });

  group('checkInSources', () {
    LinkedDbEntry link(String toId) => LinkedDbEntry(
      id: 'link-$toId',
      fromId: 'goal-1',
      toId: toId,
      serialized: '{}',
      type: 'BasicLink',
      hidden: false,
    );

    test('a goal with no links reads nothing', () async {
      when(
        () => mockDb.linksFromIds(any()),
      ).thenReturn(MockSelectable<LinkedDbEntry>([]));

      expect(await repository.checkInSources('agent-1'), isEmpty);
      verifyNever(() => mockDb.getJournalEntitiesForIds(any()));
    });

    test('offers only the check-ins that carry words', () async {
      when(() => mockDb.linksFromIds(any())).thenReturn(
        MockSelectable<LinkedDbEntry>([
          link('with-words'),
          link('still-transcribing'),
          link('deleted'),
          link('not-a-checkin'),
        ]),
      );
      when(() => mockDb.getJournalEntitiesForIds(any())).thenAnswer(
        (_) async => [
          audio('with-words', transcript: 'Skipped the lunch walk.'),
          // Saved but not yet transcribed: compacting silence would produce a
          // summary of nothing.
          audio('still-transcribing'),
          audio('deleted', transcript: 'gone', deletedAt: testDate),
          goalEntry(id: 'not-a-checkin'),
        ],
      );

      final sources = await repository.checkInSources('agent-1');

      expect(sources.map((s) => s.entryId), ['with-words']);
      expect(sources.single.text, 'Skipped the lunch walk.');
      // The moment the user spoke, not the moment this was read.
      expect(sources.single.recordedAt, testDate);
    });
  });

  group('charter entries', () {
    final goalId = 'derived:${goalEntryUuidV5Input('agent-1')}';

    EntryLink charterLink(String fromId) => EntryLink.charter(
      id: 'charter-$fromId',
      fromId: fromId,
      toId: goalId,
      createdAt: testDate,
      updatedAt: testDate,
      vectorClock: null,
    );

    JournalEntry note(
      String id, {
      String text = 'Ask me one guided question each morning.',
      DateTime? at,
      DateTime? deletedAt,
    }) => JournalEntry(
      meta: meta(id).copyWith(dateFrom: at ?? testDate, deletedAt: deletedAt),
      entryText: EntryText(plainText: text),
    );

    void stubGoal({String? categoryId, bool? private}) =>
        when(
          () => mockDb.journalEntityById(goalId),
        ).thenAnswer(
          (_) async => goalEntry(id: goalId).copyWith(
            meta: meta(
              goalId,
            ).copyWith(categoryId: categoryId, private: private),
          ),
        );

    void stubCreateMetadata() => when(
      () => mockPersistence.createMetadata(
        dateFrom: any(named: 'dateFrom'),
        categoryId: any(named: 'categoryId'),
        private: any(named: 'private'),
      ),
    ).thenAnswer((_) async => meta('charter-1'));

    void stubCreateLink(Future<bool> Function() answer) => when(
      () => mockPersistence.createLink(
        fromId: any(named: 'fromId'),
        toId: any(named: 'toId'),
        linkType: any(named: 'linkType'),
      ),
    ).thenAnswer((_) => answer());

    void stubUpdate() {
      when(
        () => mockPersistence.updateMetadata(
          any(),
          deletedAt: any(named: 'deletedAt'),
        ),
      ).thenAnswer(
        (invocation) async =>
            (invocation.positionalArguments.first as Metadata).copyWith(
              deletedAt: invocation.namedArguments[#deletedAt] as DateTime?,
            ),
      );
      when(
        () => mockPersistence.updateDbEntity(
          any(),
          linkedId: any(named: 'linkedId'),
        ),
      ).thenAnswer((_) async => true);
    }

    test('reads the live text entries linked into the goal, in the order '
        'they were written', () async {
      when(() => mockDb.charterLinksToGoal(goalId)).thenAnswer(
        (_) async => [
          charterLink('later'),
          charterLink('first'),
          charterLink('deleted'),
          charterLink('blank'),
          charterLink('not-a-note'),
        ],
      );
      when(() => mockDb.getJournalEntitiesForIds(any())).thenAnswer(
        (_) async => [
          note('later', text: 'Coach me gently.', at: DateTime(2026, 8, 3)),
          note('first', text: 'This goal is my journal.', at: DateTime(2026)),
          note('deleted', deletedAt: testDate),
          note('blank', text: '   '),
          goalEntry(id: 'not-a-note'),
        ],
      );

      final entries = await repository.charterEntries('agent-1');

      expect(entries.map((e) => e.meta.id), ['first', 'later']);
      verify(
        () => mockDb.getJournalEntitiesForIds({
          'later',
          'first',
          'deleted',
          'blank',
          'not-a-note',
        }),
      ).called(1);
    });

    test('the workflow reads the charter as plain trimmed text with the '
        'moment it was written', () async {
      when(
        () => mockDb.charterLinksToGoal(goalId),
      ).thenAnswer((_) async => [charterLink('about')]);
      when(() => mockDb.getJournalEntitiesForIds(any())).thenAnswer(
        (_) async => [
          note('about', text: '  Coach me gently.\n', at: DateTime(2026, 8)),
        ],
      );

      final charter = await repository.charter('agent-1');

      expect(charter.single.entryId, 'about');
      expect(charter.single.text, 'Coach me gently.');
      expect(charter.single.writtenAt, DateTime(2026, 8));
    });

    test('a recording belongs to the charter with or without its words, '
        'but reaches the agent only once it has them', () async {
      when(() => mockDb.charterLinksToGoal(goalId)).thenAnswer(
        (_) async => [
          charterLink('spoken'),
          charterLink('still-transcribing'),
          charterLink('deleted-recording'),
        ],
      );
      when(() => mockDb.getJournalEntitiesForIds(any())).thenAnswer(
        (_) async => [
          audio('spoken', transcript: '  Coach me gently.  '),
          audio('still-transcribing'),
          audio('deleted-recording', transcript: 'gone', deletedAt: testDate),
        ],
      );

      final entries = await repository.charterEntries('agent-1');
      expect(entries.map((e) => e.meta.id).toSet(), {
        'spoken',
        'still-transcribing',
      });
      expect(entries.every((e) => e is JournalAudio), isTrue);

      final charter = await repository.charter('agent-1');
      expect(charter.single.entryId, 'spoken');
      expect(charter.single.text, 'Coach me gently.');
    });

    test('a goal without a charter reads no entries at all', () async {
      when(
        () => mockDb.charterLinksToGoal(goalId),
      ).thenAnswer((_) async => []);

      expect(await repository.charterEntries('agent-1'), isEmpty);
      verifyNever(() => mockDb.getJournalEntitiesForIds(any()));
    });

    test("a new entry is written in the goal's category and privacy, then "
        'linked from the entry into the goal', () async {
      stubGoal(categoryId: 'cat-journal', private: true);
      stubCreateMetadata();
      when(
        () => mockPersistence.createDbEntity(any()),
      ).thenAnswer((_) async => true);
      stubCreateLink(() async => true);

      final created = await withClock(
        Clock.fixed(testDate),
        () => repository.createCharterEntry(
          agentId: 'agent-1',
          text: '  This goal is my journal.  ',
        ),
      );

      expect(created!.entryText!.plainText, 'This goal is my journal.');
      verify(
        () => mockPersistence.createMetadata(
          dateFrom: testDate,
          categoryId: 'cat-journal',
          private: true,
        ),
      ).called(1);
      // Never through `createDbEntity(linkedId:)`: that links FROM the goal,
      // which is what makes an entry a check-in.
      final written = verify(
        () => mockPersistence.createDbEntity(captureAny()),
      ).captured;
      expect(written.single, isA<JournalEntry>());
      verify(
        () => mockPersistence.createLink(
          fromId: 'charter-1',
          toId: goalId,
          linkType: EntryLinkType.charter,
        ),
      ).called(1);
    });

    test('blank words and a goal with no journal row write nothing', () async {
      expect(
        await repository.createCharterEntry(agentId: 'agent-1', text: '  '),
        isNull,
      );
      when(
        () => mockDb.journalEntityById(goalId),
      ).thenAnswer((_) async => null);
      expect(
        await repository.createCharterEntry(agentId: 'agent-1', text: 'Hi'),
        isNull,
      );
      verifyNever(() => mockPersistence.createDbEntity(any()));
    });

    test('a refused entry write is not linked', () async {
      stubGoal();
      stubCreateMetadata();
      when(
        () => mockPersistence.createDbEntity(any()),
      ).thenAnswer((_) async => false);

      expect(
        await repository.createCharterEntry(agentId: 'agent-1', text: 'Hi'),
        isNull,
      );
      verifyNever(
        () => mockPersistence.createLink(
          fromId: any(named: 'fromId'),
          toId: any(named: 'toId'),
          linkType: any(named: 'linkType'),
        ),
      );
    });

    for (final failure in ['refused', 'throws']) {
      test('an entry whose charter link $failure is deleted again', () async {
        stubGoal();
        stubCreateMetadata();
        stubUpdate();
        when(
          () => mockPersistence.createDbEntity(any()),
        ).thenAnswer((_) async => true);
        stubCreateLink(
          () async =>
              failure == 'throws' ? throw StateError('link write') : false,
        );

        final created = await withClock(
          Clock.fixed(testDate),
          () => repository.createCharterEntry(agentId: 'agent-1', text: 'Hi'),
        );

        expect(created, isNull);
        final deleted = verify(
          () => mockPersistence.updateDbEntity(
            captureAny(),
            linkedId: goalId,
          ),
        ).captured;
        final entity = deleted.single as JournalEntry;
        expect(entity.meta.id, 'charter-1');
        expect(entity.meta.deletedAt, testDate);
      });
    }

    group('attachCharterRecording', () {
      test('links a saved recording INTO the goal — never from it', () async {
        stubGoal();
        when(
          () => mockDb.journalEntityById('audio-1'),
        ).thenAnswer((_) async => audio('audio-1'));
        stubCreateLink(() async => true);

        expect(
          await repository.attachCharterRecording(
            agentId: 'agent-1',
            audioId: 'audio-1',
          ),
          isTrue,
        );
        verify(
          () => mockPersistence.createLink(
            fromId: 'audio-1',
            toId: goalId,
            linkType: EntryLinkType.charter,
          ),
        ).called(1);
      });

      test('a recording whose link is refused is deleted again', () async {
        stubGoal();
        stubUpdate();
        when(
          () => mockDb.journalEntityById('audio-1'),
        ).thenAnswer((_) async => audio('audio-1'));
        stubCreateLink(() async => false);

        final attached = await withClock(
          Clock.fixed(testDate),
          () => repository.attachCharterRecording(
            agentId: 'agent-1',
            audioId: 'audio-1',
          ),
        );

        expect(attached, isFalse);
        final deleted = verify(
          () => mockPersistence.updateDbEntity(captureAny(), linkedId: goalId),
        ).captured;
        expect((deleted.single as JournalAudio).meta.deletedAt, testDate);
      });

      test('a recording for a goal with no journal row is deleted rather '
          'than left where no page shows it', () async {
        stubUpdate();
        when(
          () => mockDb.journalEntityById(goalId),
        ).thenAnswer((_) async => null);
        when(
          () => mockDb.journalEntityById('audio-1'),
        ).thenAnswer((_) async => audio('audio-1'));

        final attached = await withClock(
          Clock.fixed(testDate),
          () => repository.attachCharterRecording(
            agentId: 'agent-1',
            audioId: 'audio-1',
          ),
        );

        expect(attached, isFalse);
        verify(
          () => mockPersistence.updateDbEntity(any(), linkedId: goalId),
        ).called(1);
      });

      test('only a live recording can join the charter', () async {
        stubGoal();
        when(
          () => mockDb.journalEntityById('not-audio'),
        ).thenAnswer((_) async => note('not-audio'));
        when(() => mockDb.journalEntityById('deleted')).thenAnswer(
          (_) async => audio('deleted', deletedAt: testDate),
        );

        for (final id in ['not-audio', 'deleted']) {
          expect(
            await repository.attachCharterRecording(
              agentId: 'agent-1',
              audioId: id,
            ),
            isFalse,
            reason: id,
          );
        }
        verifyNever(
          () => mockPersistence.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
            linkType: any(named: 'linkType'),
          ),
        );
      });
    });

    test(
      "correcting a recording's transcript saves it on the recording",
      () async {
        stubUpdate();

        final saved = await repository.updateCharterEntry(
          audio('audio-1', transcript: 'Coach me gentle.'),
          agentId: 'agent-1',
          text: 'Coach me gently.',
        );

        expect(saved, isTrue);
        final written = verify(
          () => mockPersistence.updateDbEntity(captureAny(), linkedId: goalId),
        ).captured;
        final recording = written.single as JournalAudio;
        expect(recording.entryText!.plainText, 'Coach me gently.');
        // Still the same recording, file and all.
        expect(recording.data.audioFile, 'audio-1.m4a');
      },
    );

    test(
      'an entry that is neither a note nor a recording is not edited',
      () async {
        stubUpdate();

        expect(
          await repository.updateCharterEntry(
            goalEntry(id: 'not-a-charter-kind'),
            agentId: 'agent-1',
            text: 'Words.',
          ),
          isFalse,
        );
        verifyNever(
          () => mockPersistence.updateDbEntity(
            any(),
            linkedId: any(named: 'linkedId'),
          ),
        );
      },
    );

    test('an edit saves the new words and notifies the goal it does not '
        'descend from', () async {
      stubUpdate();

      final saved = await repository.updateCharterEntry(
        note('charter-1', text: 'Old words.'),
        agentId: 'agent-1',
        text: ' New words. ',
      );

      expect(saved, isTrue);
      final written = verify(
        () => mockPersistence.updateDbEntity(captureAny(), linkedId: goalId),
      ).captured;
      expect(
        (written.single as JournalEntry).entryText!.plainText,
        'New words.',
      );
    });

    test('an edit to blank words is refused without a write', () async {
      expect(
        await repository.updateCharterEntry(
          note('charter-1'),
          agentId: 'agent-1',
          text: ' ',
        ),
        isFalse,
      );
      verifyNever(
        () => mockPersistence.updateDbEntity(
          any(),
          linkedId: any(named: 'linkedId'),
        ),
      );
    });

    test('deleting an entry stamps it deleted and notifies the goal', () async {
      stubUpdate();

      final deleted = await withClock(
        Clock.fixed(testDate),
        () => repository.deleteCharterEntry(
          note('charter-1'),
          agentId: 'agent-1',
        ),
      );

      expect(deleted, isTrue);
      final written = verify(
        () => mockPersistence.updateDbEntity(captureAny(), linkedId: goalId),
      ).captured;
      expect((written.single as JournalEntry).meta.deletedAt, testDate);
    });
  });

  group('upsertGoal', () {
    test('creates the goal when no row exists yet', () async {
      when(() => mockDb.journalEntityById(any())).thenAnswer((_) async => null);
      when(
        () => mockPersistence.createMetadata(
          uuidV5Input: any(named: 'uuidV5Input'),
          categoryId: any(named: 'categoryId'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      ).thenAnswer((_) async => meta('new-goal'));
      when(() => mockPersistence.createDbEntity(any())).thenAnswer(
        (_) async => true,
      );

      final created = await repository.upsertGoal(
        agentId: 'agent-1',
        title: 'Walk more',
        statement: 'Walk on five days a week.',
        criteria: criteria,
        specVersion: 1,
        specVersionId: 'agent-1:spec-v1',
      );

      expect(created, isNotNull);
      expect(created!.data.title, 'Walk more');
      expect(
        created.data.snapshotOf,
        isNull,
        reason: 'a goal is not a snapshot',
      );
      verify(() => mockPersistence.createDbEntity(any())).called(1);
      verifyNever(() => mockPersistence.updateDbEntity(any()));
    });

    test('updates in place rather than duplicating an existing goal', () async {
      // The backfill runs on every device, every launch. A second run must
      // refresh the row it already wrote, never append another goal.
      final existingId = 'derived:${goalEntryUuidV5Input('agent-1')}';
      when(
        () => mockDb.journalEntityById(existingId),
      ).thenAnswer((_) async => goalEntry(id: existingId, title: 'Old title'));
      when(
        () => mockPersistence.updateMetadata(any()),
      ).thenAnswer((_) async => meta(existingId));
      when(() => mockPersistence.updateDbEntity(any())).thenAnswer(
        (_) async => true,
      );

      final updated = await repository.upsertGoal(
        agentId: 'agent-1',
        title: 'New title',
        statement: 'Walk on five days a week.',
        criteria: criteria,
        specVersion: 2,
        specVersionId: 'agent-1:spec-v2',
      );

      expect(updated!.meta.id, existingId, reason: 'identity must not move');
      expect(updated.data.title, 'New title');
      expect(updated.data.specVersion, 2);
      verify(() => mockPersistence.updateDbEntity(any())).called(1);
      // Creating metadata reserves AND commits a vector-clock counter, so the
      // refresh path must never touch it.
      verifyNever(
        () => mockPersistence.createMetadata(
          uuidV5Input: any(named: 'uuidV5Input'),
          categoryId: any(named: 'categoryId'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      );
    });

    test('returns null when the write fails', () async {
      when(() => mockDb.journalEntityById(any())).thenAnswer((_) async => null);
      when(
        () => mockPersistence.createMetadata(
          uuidV5Input: any(named: 'uuidV5Input'),
          categoryId: any(named: 'categoryId'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      ).thenAnswer((_) async => meta('new-goal'));
      when(
        () => mockPersistence.createDbEntity(any()),
      ).thenAnswer((_) async => false);

      expect(
        await repository.upsertGoal(
          agentId: 'agent-1',
          title: 'Walk more',
          statement: 'Walk on five days a week.',
          criteria: criteria,
          specVersion: 1,
          specVersionId: 'agent-1:spec-v1',
        ),
        isNull,
      );
    });
  });

  group('ensureSpecSnapshot', () {
    test('never rewrites a snapshot that already exists', () async {
      // A spec version is immutable, and registers and reflections are pinned
      // to it. Refreshing one would rewrite history they point at.
      final snapshotId =
          'derived:${goalSpecSnapshotUuidV5Input('agent-1:spec-v1')}';
      final existing = goalEntry(id: snapshotId, snapshotOf: 'goal-1');
      when(
        () => mockDb.journalEntityById(snapshotId),
      ).thenAnswer((_) async => existing);

      final result = await repository.ensureSpecSnapshot(
        goalId: 'goal-1',
        specVersionId: 'agent-1:spec-v1',
        title: 'Rewritten title',
        statement: 'Rewritten statement.',
        criteria: criteria,
        specVersion: 1,
        createdAt: testDate,
      );

      expect(result, existing);
      verifyNever(() => mockPersistence.updateDbEntity(any()));
      verifyNever(() => mockPersistence.createDbEntity(any()));
    });

    test('writes a snapshot that names its goal', () async {
      when(() => mockDb.journalEntityById(any())).thenAnswer((_) async => null);
      when(
        () => mockPersistence.createMetadata(
          uuidV5Input: any(named: 'uuidV5Input'),
          categoryId: any(named: 'categoryId'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      ).thenAnswer((_) async => meta('snapshot-1'));
      when(() => mockPersistence.createDbEntity(any())).thenAnswer(
        (_) async => true,
      );

      final snapshot = await repository.ensureSpecSnapshot(
        goalId: 'goal-1',
        specVersionId: 'agent-1:spec-v1',
        title: 'Walk more',
        statement: 'Walk on five days a week.',
        criteria: criteria,
        specVersion: 1,
        createdAt: testDate,
      );

      // `snapshotOf` is what the subtype column carries, which is what makes
      // version history an indexed lookup and keeps snapshots out of the goal
      // list.
      expect(snapshot!.data.snapshotOf, 'goal-1');
      expect(snapshot.data.isSpecSnapshot, isTrue);
    });
  });
}
