import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/classes/sync_sequence_payload_type.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/deep_backfill/definition_deep_backfill_store.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

void main() {
  late JournalDb db;
  late MockOutboxService outbox;
  late DefinitionDeepBackfillStore store;

  // Ids sort across the tables: the store reads them as one table.
  final category = categoryMindfulness.copyWith(
    id: 'b-category',
    vectorClock: const VectorClock({'h': 1}),
    deletedAt: DateTime(2024),
  );
  final label = testLabelDefinition1.copyWith(
    id: 'a-label',
    vectorClock: const VectorClock({'h': 2}),
  );
  final habit = habitFlossing.copyWith(id: 'c-habit', vectorClock: null);
  final measurable = measurableWater.copyWith(
    id: 'd-measurable',
    vectorClock: const VectorClock({'h': 4}),
  );

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    db = JournalDb(inMemoryDatabase: true);
    for (final definition in <EntityDefinition>[
      category,
      label,
      habit,
      measurable,
    ]) {
      await db.upsertEntityDefinition(definition);
    }
    outbox = MockOutboxService();
    when(() => outbox.enqueueMessage(any())).thenAnswer((_) async {});
    store = DefinitionDeepBackfillStore(journalDb: db, outboxService: outbox);
  });

  tearDown(() => db.close());

  test('counts every definition table, deletions included', () async {
    expect(store.payloadType, SyncSequencePayloadType.entityDefinition);
    expect(await store.count(), 4);
  });

  test('pages through all tables in id order', () async {
    final first = await store.page(after: null, limit: 3);
    expect(first.map((row) => row.id), ['a-label', 'b-category', 'c-habit']);
    expect(first.map((row) => row.clock), [
      const VectorClock({'h': 2}),
      const VectorClock({'h': 1}),
      null,
    ]);

    final rest = await store.page(after: 'c-habit', limit: 3);
    expect(rest.map((row) => row.id), ['d-measurable']);
  });

  test('reads a range from every table', () async {
    expect(await store.range(start: 'b', end: 'd'), {
      'b-category': const VectorClock({'h': 1}),
      'c-habit': null,
    });
  });

  test(
    'resends each requested definition, deletions included, as a '
    'definition message',
    () async {
      expect(
        await store.enqueueCurrent(
          {'b-category', 'd-measurable', 'unknown'},
          withMedia: {},
        ),
        2,
      );

      final sent = verify(
        () => outbox.enqueueMessage(captureAny()),
      ).captured.cast<SyncEntityDefinition>();
      expect(sent.map((message) => message.entityDefinition).toSet(), {
        category,
        measurable,
      });
      expect(await store.enqueueCurrent({}, withMedia: {}), 0);
    },
  );

  test('a write to any definition table is reported', () async {
    var changes = 0;
    final subscription = store.changes.listen((_) => changes++);
    addTearDown(subscription.cancel);

    await db.upsertEntityDefinition(
      label.copyWith(vectorClock: const VectorClock({'h': 9})),
    );
    await pumpEventQueue();
    await db.upsertEntityDefinition(
      habit.copyWith(name: 'Renamed', updatedAt: DateTime(2030)),
    );
    await pumpEventQueue();

    expect(changes, 2);
  });
}
