import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/features/relationships/repository/person_timeline_repository.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../database/test_utils.dart';
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

void main() {
  final at = DateTime(2026, 8, 14, 20);

  late JournalDb db;
  late MockJournalRepository journalRepository;
  late MockPersistenceLogic persistence;
  late PersonTimelineRepository repository;

  Metadata meta(String id, {bool private = false, bool? starred}) => Metadata(
    id: id,
    createdAt: at,
    updatedAt: at,
    dateFrom: at,
    dateTo: at,
    categoryId: 'cat-1',
    private: private,
    starred: starred,
  );

  final person = testRelationship.copyWith(
    meta: meta('person', private: true),
  );

  Future<void> link(
    String from,
    String to, {
    bool relationship = true,
    DateTime? deletedAt,
  }) => db.upsertEntryLink(
    relationship
        ? EntryLink.relationship(
            id: '$from=>$to',
            fromId: from,
            toId: to,
            createdAt: at,
            updatedAt: at,
            vectorClock: null,
            deletedAt: deletedAt,
          )
        : EntryLink.basic(
            id: '$from->$to',
            fromId: from,
            toId: to,
            createdAt: at,
            updatedAt: at,
            vectorClock: null,
          ),
  );

  setUpAll(() {
    registerAllFallbackValues();
    db = JournalDb(inMemoryDatabase: true);
  });
  tearDownAll(() => db.close());

  setUp(() async {
    await clearAllTables(db);
    await initConfigFlags(db, inMemoryDatabase: true);
    journalRepository = MockJournalRepository();
    persistence = MockPersistenceLogic();
    repository = PersonTimelineRepository(
      journalDb: db,
      journalRepository: journalRepository,
      persistenceLogic: persistence,
    );
  });

  Future<void> showPrivate({required bool shown}) => db.upsertConfigFlag(
    ConfigFlag(
      name: privateFlag,
      description: 'Show private entries?',
      status: shown,
    ),
  );

  group('getTimelineEntries', () {
    setUp(() async {
      final entities = <JournalEntity>[
        JournalEntity.journalEntry(
          meta: meta('note'),
          entryText: const EntryText(plainText: 'Hates calls before 10.'),
        ),
        testAudioEntry.copyWith(meta: meta('voice-note')),
        testImageEntry.copyWith(meta: meta('photo')),
        testImageEntry.copyWith(meta: meta('avatar')),
        testImageEntry.copyWith(meta: meta('private-photo', private: true)),
        JournalEntity.journalEntry(meta: meta('unlinked-note')),
        JournalEntity.journalEntry(meta: meta('removed-note')),
        JournalEntity.event(
          meta: meta('meeting'),
          data: const EventData(
            title: 'Coffee',
            stars: 0,
            status: EventStatus.planned,
          ),
        ),
      ];
      for (final entity in entities) {
        await db.updateJournalEntity(entity);
      }
      for (final id in [
        'note',
        'voice-note',
        'photo',
        'private-photo',
        'meeting',
      ]) {
        await link('person', id);
      }
      // The avatar rides a BasicLink: a picture of the person, not something
      // put on their timeline.
      await link('person', 'avatar', relationship: false);
      await link('person', 'removed-note', deletedAt: at);
      // A link pointing *at* the person is not one of theirs to show.
      await link('unlinked-note', 'person');
    });

    test(
      'returns what RelationshipLinks from the person point at, of the '
      'timeline kinds only, hiding private entries while they are hidden',
      () async {
        await showPrivate(shown: false);

        final entries = await repository.getTimelineEntries('person');

        expect(entries.map((e) => e.id).toSet(), {
          'note',
          'voice-note',
          'photo',
          'meeting',
        });
      },
    );

    test('shows private entries once private entries are shown', () async {
      await showPrivate(shown: true);

      final entries = await repository.getTimelineEntries('person');

      expect(entries.map((e) => e.id), contains('private-photo'));
    });

    test(
      'leaves out check-ins and tasks, which have reads of their own',
      () async {
        await db.updateJournalEntity(
          testTask.copyWith(meta: meta('task')),
        );
        await link('person', 'task');

        final entries = await repository.getTimelineEntries('person');

        expect(entries.map((e) => e.id), isNot(contains('task')));
      },
    );
  });

  group('createNote', () {
    setUp(() {
      when(
        () => persistence.createMetadata(
          dateFrom: any(named: 'dateFrom'),
          categoryId: any(named: 'categoryId'),
          private: any(named: 'private'),
          starred: any(named: 'starred'),
        ),
      ).thenAnswer(
        (call) async =>
            meta(
              'new-note',
              private: call.namedArguments[#private] as bool? ?? false,
              starred: call.namedArguments[#starred] as bool?,
            ).copyWith(
              categoryId: call.namedArguments[#categoryId] as String?,
            ),
      );
      when(
        () => persistence.createDbEntity(any()),
      ).thenAnswer((_) async => true);
      when(
        () => persistence.createLink(
          fromId: any(named: 'fromId'),
          toId: any(named: 'toId'),
          linkType: any(named: 'linkType'),
        ),
      ).thenAnswer((_) async => true);
    });

    test("writes a trimmed note in the person's category and privacy and "
        'puts it on their timeline', () async {
      final note = await withClock(
        Clock.fixed(at),
        () => repository.createNote(
          person: person,
          text: '  Met at the ice summit.  ',
          pinned: true,
        ),
      );

      expect(note?.entryText?.plainText, 'Met at the ice summit.');
      expect(note?.meta.categoryId, 'cat-1');
      expect(note?.meta.private, isTrue);
      expect(note?.meta.starred, isTrue);
      verify(
        () => persistence.createLink(
          fromId: 'person',
          toId: 'new-note',
          linkType: EntryLinkType.relationship,
        ),
      ).called(1);
    });

    test('writes nothing for blank words', () async {
      expect(
        await repository.createNote(person: person, text: '   '),
        isNull,
      );
      verifyNever(() => persistence.createDbEntity(any()));
    });

    test('a note that could not be written is none', () async {
      when(
        () => persistence.createDbEntity(any()),
      ).thenAnswer((_) async => false);

      expect(
        await repository.createNote(person: person, text: 'Gift: a scarf'),
        isNull,
      );
      verifyNever(
        () => persistence.createLink(
          fromId: any(named: 'fromId'),
          toId: any(named: 'toId'),
          linkType: any(named: 'linkType'),
        ),
      );
    });

    test('a link write that throws is a failed link: the note is removed '
        'again, so a retry cannot write a second copy', () async {
      when(
        () => persistence.createLink(
          fromId: any(named: 'fromId'),
          toId: any(named: 'toId'),
          linkType: any(named: 'linkType'),
        ),
      ).thenThrow(Exception('database locked'));
      when(
        () => persistence.updateMetadata(
          any(),
          deletedAt: any(named: 'deletedAt'),
        ),
      ).thenAnswer(
        (call) async => (call.positionalArguments.first as Metadata).copyWith(
          deletedAt: call.namedArguments[#deletedAt] as DateTime?,
        ),
      );
      when(
        () => persistence.updateDbEntity(any()),
      ).thenAnswer((_) async => true);

      expect(
        await repository.createNote(person: person, text: 'Gift: a scarf'),
        isNull,
      );
      final removed =
          verify(
                () => persistence.updateDbEntity(captureAny()),
              ).captured.single
              as JournalEntity;
      expect(removed.meta.deletedAt, isNotNull);
    });

    test('a note whose timeline link fails is removed again, so nothing '
        'about the person is left where their page cannot reach it', () async {
      when(
        () => persistence.createLink(
          fromId: any(named: 'fromId'),
          toId: any(named: 'toId'),
          linkType: any(named: 'linkType'),
        ),
      ).thenAnswer((_) async => false);
      when(
        () => persistence.updateMetadata(
          any(),
          deletedAt: any(named: 'deletedAt'),
        ),
      ).thenAnswer(
        (call) async => (call.positionalArguments.first as Metadata).copyWith(
          deletedAt: call.namedArguments[#deletedAt] as DateTime?,
        ),
      );
      when(
        () => persistence.updateDbEntity(any()),
      ).thenAnswer((_) async => true);

      expect(
        await repository.createNote(person: person, text: 'Gift: a scarf'),
        isNull,
      );
      final removed =
          verify(
                () => persistence.updateDbEntity(captureAny()),
              ).captured.single
              as JournalEntity;
      expect(removed.id, 'new-note');
      expect(removed.meta.deletedAt, isNotNull);
    });
  });

  group('createMeeting', () {
    final start = DateTime(2026, 8, 16, 15);

    setUp(() {
      when(
        () => persistence.createMetadata(
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
          categoryId: any(named: 'categoryId'),
          private: any(named: 'private'),
        ),
      ).thenAnswer(
        (call) async =>
            meta(
              'new-meeting',
              private: call.namedArguments[#private] as bool? ?? false,
            ).copyWith(
              dateFrom: call.namedArguments[#dateFrom] as DateTime,
              dateTo: call.namedArguments[#dateTo] as DateTime,
              categoryId: call.namedArguments[#categoryId] as String?,
            ),
      );
      when(
        () => persistence.createDbEntity(any()),
      ).thenAnswer((_) async => true);
      when(
        () => persistence.createLink(
          fromId: any(named: 'fromId'),
          toId: any(named: 'toId'),
          linkType: any(named: 'linkType'),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => persistence.updateMetadata(
          any(),
          deletedAt: any(named: 'deletedAt'),
        ),
      ).thenAnswer(
        (call) async => (call.positionalArguments.first as Metadata).copyWith(
          deletedAt: call.namedArguments[#deletedAt] as DateTime?,
        ),
      );
      when(
        () => persistence.updateDbEntity(any()),
      ).thenAnswer((_) async => true);
    });

    test("writes a planned event over the slot, in the person's category "
        'and privacy, and puts it on their timeline', () async {
      final meeting = await repository.createMeeting(
        person: person,
        title: '  Coffee with Pip  ',
        start: start,
        duration: const Duration(minutes: 90),
      );

      expect(meeting?.data.title, 'Coffee with Pip');
      expect(meeting?.data.status, EventStatus.planned);
      expect(meeting?.meta.dateFrom, start);
      expect(meeting?.meta.dateTo, DateTime(2026, 8, 16, 16, 30));
      expect(meeting?.meta.categoryId, 'cat-1');
      expect(meeting?.meta.private, isTrue);
      final written =
          verify(
                () => persistence.createDbEntity(captureAny()),
              ).captured.single
              as JournalEntity;
      expect(written, isA<JournalEvent>());
      verify(
        () => persistence.createLink(
          fromId: 'person',
          toId: 'new-meeting',
          linkType: EntryLinkType.relationship,
        ),
      ).called(1);
    });

    test('writes nothing for a blank title or a slot of no length', () async {
      for (final (title, duration) in [
        ('   ', const Duration(hours: 1)),
        ('Coffee', Duration.zero),
        ('Coffee', const Duration(minutes: -5)),
      ]) {
        expect(
          await repository.createMeeting(
            person: person,
            title: title,
            start: start,
            duration: duration,
          ),
          isNull,
          reason: '$title / $duration',
        );
      }
      verifyNever(() => persistence.createDbEntity(any()));
    });

    test('a meeting that could not be written is none, and is never '
        'linked', () async {
      when(
        () => persistence.createDbEntity(any()),
      ).thenAnswer((_) async => null);

      expect(
        await repository.createMeeting(
          person: person,
          title: 'Coffee',
          start: start,
          duration: const Duration(hours: 1),
        ),
        isNull,
      );
      verifyNever(
        () => persistence.createLink(
          fromId: any(named: 'fromId'),
          toId: any(named: 'toId'),
          linkType: any(named: 'linkType'),
        ),
      );
    });

    test('a meeting whose timeline link fails is removed again', () async {
      when(
        () => persistence.createLink(
          fromId: any(named: 'fromId'),
          toId: any(named: 'toId'),
          linkType: any(named: 'linkType'),
        ),
      ).thenAnswer((_) async => false);

      expect(
        await repository.createMeeting(
          person: person,
          title: 'Coffee',
          start: start,
          duration: const Duration(hours: 1),
        ),
        isNull,
      );
      final removed =
          verify(
                () => persistence.updateDbEntity(captureAny()),
              ).captured.single
              as JournalEntity;
      expect(removed, isA<JournalEvent>());
      expect(removed.id, 'new-meeting');
      expect(removed.meta.deletedAt, isNotNull);
    });
  });

  group('deleteNote', () {
    test('saves the note again, stamped deleted, and answers whether it was '
        'saved', () async {
      when(
        () => persistence.updateMetadata(
          any(),
          deletedAt: any(named: 'deletedAt'),
        ),
      ).thenAnswer(
        (call) async => (call.positionalArguments.first as Metadata).copyWith(
          deletedAt: call.namedArguments[#deletedAt] as DateTime?,
        ),
      );
      when(
        () => persistence.updateDbEntity(any()),
      ).thenAnswer((_) async => null);
      final note =
          JournalEntity.journalEntry(
                meta: meta('note-1'),
                entryText: const EntryText(plainText: 'Gift: a scarf'),
              )
              as JournalEntry;

      final deleted = await withClock(
        Clock.fixed(at),
        () => repository.deleteNote(note),
      );

      expect(deleted, isFalse, reason: 'a save that answers nothing failed');
      final saved =
          verify(
                () => persistence.updateDbEntity(captureAny()),
              ).captured.single
              as JournalEntity;
      expect(saved.id, 'note-1');
      expect(saved.meta.deletedAt, at);
    });
  });

  group('personTimelineLinksChangedAt', () {
    Future<void> linkAt(String to, DateTime updatedAt, {DateTime? deletedAt}) =>
        db.upsertEntryLink(
          EntryLink.relationship(
            id: 'person=>$to',
            fromId: 'person',
            toId: to,
            createdAt: at,
            updatedAt: updatedAt,
            vectorClock: null,
            deletedAt: deletedAt,
          ),
        );

    test('is null for a person with no timeline links', () async {
      expect(await personTimelineLinksChangedAt(db, 'person'), isNull);
    });

    test("is the newest write to the person's own links, a tombstone "
        'included — taking an entry off is a change too', () async {
      final added = DateTime(2026, 8, 15, 9);
      final removed = DateTime(2026, 8, 16, 18);
      await linkAt('note', added);
      await linkAt('photo', removed, deletedAt: removed);
      // A link pointing at the person is not theirs, however new.
      await db.upsertEntryLink(
        EntryLink.relationship(
          id: 'other=>person',
          fromId: 'other',
          toId: 'person',
          createdAt: at,
          updatedAt: DateTime(2026, 9),
          vectorClock: null,
        ),
      );

      expect(await personTimelineLinksChangedAt(db, 'person'), removed);
    });
  });

  group('touch', () {
    test('saves the entry again so its updatedAt advances', () async {
      final photo = testImageEntry.copyWith(meta: meta('photo'));
      await db.updateJournalEntity(photo);
      final later = DateTime(2026, 8, 20, 8);
      when(() => persistence.updateMetadata(any())).thenAnswer(
        (call) async => (call.positionalArguments.first as Metadata).copyWith(
          updatedAt: later,
        ),
      );
      when(
        () => persistence.updateDbEntity(any()),
      ).thenAnswer((_) async => true);

      expect(await repository.touch('photo'), isTrue);

      final saved =
          verify(
                () => persistence.updateDbEntity(captureAny()),
              ).captured.single
              as JournalEntity;
      expect(saved.id, 'photo');
      expect(saved.meta.updatedAt, later);
    });

    test('touches nothing that is gone', () async {
      expect(await repository.touch('missing'), isFalse);
      verifyNever(() => persistence.updateDbEntity(any()));
    });
  });

  group('setPinned', () {
    test('stars or unstars the note and saves it', () async {
      // A note always has words: one emptied in its sheet is deleted there.
      final note =
          JournalEntity.journalEntry(
                meta: meta('note', starred: false),
                entryText: const EntryText(plainText: 'Loves krill.'),
              )
              as JournalEntry;
      when(() => persistence.updateMetadata(any())).thenAnswer(
        (call) async => call.positionalArguments.first as Metadata,
      );
      when(
        () => persistence.updateDbEntity(any()),
      ).thenAnswer((_) async => true);

      expect(await repository.setPinned(note, pinned: true), isTrue);

      final saved =
          verify(
                () => persistence.updateDbEntity(captureAny()),
              ).captured.single
              as JournalEntity;
      expect(saved.meta.starred, isTrue);
      expect(saved.entryText?.plainText, 'Loves krill.');
    });
  });

  group('removeFromTimeline', () {
    test('tombstones the RelationshipLinks between the person and the entry '
        'in either direction, and no other link', () async {
      await link('person', 'note');
      await link('note', 'person');
      await link('person', 'note', relationship: false);
      when(
        () => journalRepository.updateLink(any()),
      ).thenAnswer((_) async => true);

      expect(
        await repository.removeFromTimeline(
          personId: 'person',
          entryId: 'note',
        ),
        isTrue,
      );

      final tombstones = verify(
        () => journalRepository.updateLink(captureAny()),
      ).captured.cast<EntryLink>();
      expect(tombstones.map((l) => l.id).toSet(), {
        'person=>note',
        'note=>person',
      });
      expect(tombstones.every((l) => l.deletedAt != null), isTrue);
      expect(tombstones.every((l) => l.hidden ?? false), isTrue);
    });

    test('answers false when the entry is not on the timeline', () async {
      expect(
        await repository.removeFromTimeline(personId: 'person', entryId: 'x'),
        isFalse,
      );
      verifyNever(() => journalRepository.updateLink(any()));
    });

    test('answers false when a tombstone is rejected', () async {
      await link('person', 'note');
      when(
        () => journalRepository.updateLink(any()),
      ).thenAnswer((_) async => false);

      expect(
        await repository.removeFromTimeline(
          personId: 'person',
          entryId: 'note',
        ),
        isFalse,
      );
    });
  });
}
