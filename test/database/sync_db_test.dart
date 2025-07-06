import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/database/sync_db.dart';

void main() {
  SyncDatabase? db;

  group('Sync Database Tests - ', () {
    setUp(() async {
      db = SyncDatabase(inMemoryDatabase: true);
    });
    tearDown(() async {
      await db?.close();
    });

    test(
      'empty database',
      () async {
        expect(
          await db?.watchOutboxCount().first,
          0,
        );

        expect(
          await db?.watchOutboxItems().first,
          <OutboxItem>[],
        );

        expect(
          await db?.oldestOutboxItems(100),
          <OutboxItem>[],
        );
      },
    );

    test(
      'add items to database',
      () async {
        final outboxItem1 = OutboxCompanion(
          status: Value(OutboxStatus.sent.index),
          subject: const Value('subject'),
          message: const Value('jsonString'),
          createdAt: Value(DateTime(2022, 7, 7, 13)),
          updatedAt: Value(DateTime(2022, 7, 7, 13)),
          retries: const Value(2),
        );

        final outboxItem2 = OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          subject: const Value('subject'),
          message: const Value('jsonString'),
          createdAt: Value(DateTime(2022, 7, 7, 14)),
          updatedAt: Value(DateTime(2022, 7, 7, 14)),
          retries: const Value(0),
        );

        await db?.addOutboxItem(outboxItem1);
        await db?.addOutboxItem(outboxItem2);

        expect(
          await db?.watchOutboxCount().first,
          1,
        );

        expect(
          await db?.watchOutboxItems(statuses: [OutboxStatus.pending]).first,
          <OutboxItem>[
            OutboxItem(
              id: 2,
              createdAt: DateTime(2022, 7, 7, 14),
              updatedAt: DateTime(2022, 7, 7, 14),
              status: OutboxStatus.pending.index,
              retries: 0,
              message: 'jsonString',
              subject: 'subject',
            ),
          ],
        );

        expect(
          await db?.oldestOutboxItems(100),
          <OutboxItem>[
            OutboxItem(
              id: 2,
              createdAt: DateTime(2022, 7, 7, 14),
              updatedAt: DateTime(2022, 7, 7, 14),
              status: OutboxStatus.pending.index,
              retries: 0,
              message: 'jsonString',
              subject: 'subject',
            ),
          ],
        );
      },
    );

    test(
      'update item in database',
      () async {
        final outboxItem = OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          subject: const Value('subject'),
          message: const Value('jsonString'),
          createdAt: Value(DateTime(2022, 7, 7, 14)),
          updatedAt: Value(DateTime(2022, 7, 7, 14)),
          retries: const Value(0),
        );

        await db?.addOutboxItem(outboxItem);

        expect(
          await db?.watchOutboxCount().first,
          1,
        );

        expect(
          await db?.watchOutboxItems(statuses: [OutboxStatus.pending]).first,
          <OutboxItem>[
            OutboxItem(
              id: 1,
              createdAt: DateTime(2022, 7, 7, 14),
              updatedAt: DateTime(2022, 7, 7, 14),
              status: OutboxStatus.pending.index,
              retries: 0,
              message: 'jsonString',
              subject: 'subject',
            ),
          ],
        );

        expect(
          await db?.oldestOutboxItems(100),
          <OutboxItem>[
            OutboxItem(
              id: 1,
              createdAt: DateTime(2022, 7, 7, 14),
              updatedAt: DateTime(2022, 7, 7, 14),
              status: OutboxStatus.pending.index,
              retries: 0,
              message: 'jsonString',
              subject: 'subject',
            ),
          ],
        );

        await db?.updateOutboxItem(
          const OutboxCompanion(
            id: Value(1),
            retries: Value(1),
          ),
        );

        expect(
          await db?.oldestOutboxItems(100),
          <OutboxItem>[
            OutboxItem(
              id: 1,
              createdAt: DateTime(2022, 7, 7, 14),
              updatedAt: DateTime(2022, 7, 7, 14),
              status: OutboxStatus.pending.index,
              retries: 1,
              message: 'jsonString',
              subject: 'subject',
            ),
          ],
        );

        await db?.updateOutboxItem(
          OutboxCompanion(
            id: const Value(1),
            status: Value(OutboxStatus.sent.index),
          ),
        );

        expect(
          await db?.watchOutboxCount().first,
          0,
        );

        expect(
          await db?.oldestOutboxItems(100),
          <OutboxItem>[],
        );
      },
    );
  });
}
