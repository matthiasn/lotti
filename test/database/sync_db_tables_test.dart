// Schema-shape tests for the drift table declarations
// (`lib/database/sync_db_tables.dart`).
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:glados/glados.dart';
import 'package:lotti/database/sync_db.dart';

import 'sync_db_test_utils.dart';

void main() {
  group('InboundEventQueue and QueueMarkers table schema -', () {
    // These tests directly insert into and query from the InboundEventQueue
    // and QueueMarkers tables (lines 483-596 in sync_db.dart). Because all
    // business logic that touches these tables lives in separate feature
    // classes, no existing test exercised the table column declarations;
    // inserting and reading back rows via the generated Drift API is the
    // lightest-weight way to reach those declaration lines.
    late SyncDatabase database;

    // The migration ladder runs once for the group; each test starts clean
    // via clearAllSyncTables.
    setUpAll(() async {
      database = SyncDatabase(inMemoryDatabase: true);
    });
    setUp(() async {
      await clearAllSyncTables(database);
    });
    tearDownAll(() async {
      await database.close();
    });

    test('can insert and retrieve an InboundEventQueue row', () async {
      const eventId = 'event-schema-test-1';
      const roomId = '!room-schema:example.org';
      const originTs = 1_700_000_000_000;
      const enqueuedAt = 1_700_000_001_000;

      await database
          .into(database.inboundEventQueue)
          .insert(
            InboundEventQueueCompanion.insert(
              eventId: eventId,
              roomId: roomId,
              originTs: originTs,
              producer: 'liveStream',
              rawJson: '{"type":"m.room.message"}',
              enqueuedAt: enqueuedAt,
            ),
          );

      final rows = await database.select(database.inboundEventQueue).get();
      expect(rows, hasLength(1));
      final row = rows.first;
      expect(row.eventId, eventId);
      expect(row.roomId, roomId);
      expect(row.originTs, originTs);
      expect(row.producer, 'liveStream');
      expect(row.rawJson, '{"type":"m.room.message"}');
      expect(row.enqueuedAt, enqueuedAt);
      expect(row.attempts, 0);
      expect(row.nextDueAt, 0);
      expect(row.leaseUntil, 0);
      expect(row.status, 'enqueued');
      expect(row.committedAt, isNull);
      expect(row.abandonedAt, isNull);
      expect(row.lastErrorReason, isNull);
      expect(row.resurrectionCount, 0);
      expect(row.jsonPath, isNull);
    });

    test('enforces UNIQUE constraint on eventId', () async {
      const eventId = 'event-unique-test';
      final insert = InboundEventQueueCompanion.insert(
        eventId: eventId,
        roomId: '!room:example.org',
        originTs: 1_700_000_000_000,
        producer: 'bootstrap',
        rawJson: '{}',
        enqueuedAt: 1_700_000_000_000,
      );

      await database.into(database.inboundEventQueue).insert(insert);

      // A second insert with the same eventId must fail.
      await expectLater(
        () => database.into(database.inboundEventQueue).insert(insert),
        throwsA(anything),
      );

      final rows = await database.select(database.inboundEventQueue).get();
      expect(rows, hasLength(1));
    });

    test(
      'stores nullable columns (committedAt, abandonedAt, lastErrorReason, '
      'jsonPath) and reads them back correctly',
      () async {
        const enqueuedAt = 1_700_000_000_000;
        await database
            .into(database.inboundEventQueue)
            .insert(
              InboundEventQueueCompanion.insert(
                eventId: 'event-nullable-cols',
                roomId: '!room:example.org',
                originTs: enqueuedAt,
                producer: 'limitedSync',
                rawJson: '{}',
                enqueuedAt: enqueuedAt,
                committedAt: const Value(1_700_000_005_000),
                lastErrorReason: const Value('transient'),
                jsonPath: const Value('journals/abc.json'),
              ),
            );

        final row = await (database.select(
          database.inboundEventQueue,
        )..where((t) => t.eventId.equals('event-nullable-cols'))).getSingle();

        expect(row.committedAt, 1_700_000_005_000);
        expect(row.abandonedAt, isNull);
        expect(row.lastErrorReason, 'transient');
        expect(row.jsonPath, 'journals/abc.json');
      },
    );

    test('can insert and retrieve a QueueMarkers row', () async {
      const roomId = '!marker-room:example.org';

      await database
          .into(database.queueMarkers)
          .insert(
            QueueMarkersCompanion.insert(roomId: roomId),
          );

      final rows = await database.select(database.queueMarkers).get();
      expect(rows, hasLength(1));
      final row = rows.first;
      expect(row.roomId, roomId);
      expect(row.lastAppliedEventId, isNull);
      expect(row.lastAppliedTs, 0);
      expect(row.lastAppliedCommitSeq, 0);
    });

    test('QueueMarkers upserts advance the marker monotonically', () async {
      const roomId = '!upsert-room:example.org';

      await database
          .into(database.queueMarkers)
          .insert(
            QueueMarkersCompanion.insert(roomId: roomId),
          );

      // Advance the marker.
      await (database.update(
        database.queueMarkers,
      )..where((t) => t.roomId.equals(roomId))).write(
        const QueueMarkersCompanion(
          lastAppliedEventId: Value(r'$event-42'),
          lastAppliedTs: Value(1_700_000_042_000),
          lastAppliedCommitSeq: Value(1),
        ),
      );

      final row = await (database.select(
        database.queueMarkers,
      )..where((t) => t.roomId.equals(roomId))).getSingle();
      expect(row.lastAppliedEventId, r'$event-42');
      expect(row.lastAppliedTs, 1_700_000_042_000);
      expect(row.lastAppliedCommitSeq, 1);
    });
  });
}
