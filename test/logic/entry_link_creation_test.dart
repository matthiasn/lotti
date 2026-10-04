import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/logic/entry_link_creation.dart';
import 'package:lotti/logic/services/metadata_service.dart';

import '../helpers/test_get_it.dart';

void main() {
  late JournalDb db;

  setUp(() async {
    await setUpTestGetIt();
    db = JournalDb(inMemoryDatabase: true);
  });

  tearDown(() async {
    await db.close();
    await tearDownTestGetIt();
  });

  final at = DateTime(2024, 3, 15);

  EntryLink stored(
    String id, {
    EntryLinkType type = EntryLinkType.basic,
    String fromId = 'from',
    String toId = 'to',
    bool hidden = false,
    bool removed = false,
  }) => type.buildLink(
    id: id,
    fromId: fromId,
    toId: toId,
    createdAt: at,
    updatedAt: at,
    vectorClock: const VectorClock({'peer': 3}),
    hidden: hidden || removed,
    deletedAt: removed ? at : null,
  );

  Future<LinkCreationBase?> base({String type = 'BasicLink'}) =>
      linkCreationBase(db, fromId: 'from', toId: 'to', type: type);

  group('entryLinkId', () {
    test('is the uuid v5 of the natural key, the same on every device', () {
      expect(
        entryLinkId(fromId: 'from', toId: 'to', type: 'BasicLink'),
        MetadataService.deterministicId('entry-link|BasicLink|from|to'),
      );
    });

    test('differs by type and by direction', () {
      final ids = {
        entryLinkId(fromId: 'from', toId: 'to', type: 'BasicLink'),
        entryLinkId(fromId: 'from', toId: 'to', type: 'BlocksLink'),
        entryLinkId(fromId: 'to', toId: 'from', type: 'BasicLink'),
      };
      expect(ids, hasLength(3));
    });
  });

  group('linkCreationBase', () {
    test('a link never stored here takes the derived id', () async {
      expect(
        await base(),
        (
          id: entryLinkId(fromId: 'from', toId: 'to', type: 'BasicLink'),
          predecessor: null,
        ),
      );
    });

    test(
      'a removed link is revived: its id, succeeding the tombstone',
      () async {
        final tombstone = stored('random-id', removed: true);
        await db.upsertEntryLink(tombstone);

        expect(await base(), (id: 'random-id', predecessor: tombstone));
      },
    );

    test('a hidden link is succeeded under its own id too', () async {
      final hidden = stored('random-id', hidden: true);
      await db.upsertEntryLink(hidden);

      expect(await base(), (id: 'random-id', predecessor: hidden));
    });

    test('a live, visible link is not created again', () async {
      await db.upsertEntryLink(stored('random-id'));

      expect(await base(), isNull);
      // Another type between the same pair is another link.
      expect(await base(type: 'BlocksLink'), isNotNull);
    });

    test(
      'a derived id that a retyped link carries elsewhere is not reused: '
      'the new link takes a random id',
      () async {
        final derived = entryLinkId(
          fromId: 'from',
          toId: 'to',
          type: 'BasicLink',
        );
        // Created as a basic link, then retyped to blocks under the same id.
        await db.upsertEntryLink(
          stored(derived, type: EntryLinkType.blocks),
        );

        final created = await base();
        expect(created!.predecessor, isNull);
        expect(created.id, isNot(derived));
        expect(created.id, isNotEmpty);
      },
    );
  });
}
