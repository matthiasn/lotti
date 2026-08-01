import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';

import 'sync_db_test_utils.dart';

/// Read-pool behaviour for [SyncDatabase].
///
/// `sync.sqlite` runs with `readPool: 2`, so reads outside a transaction are
/// served by read-only isolates while writes stay on the single write executor.
/// That removes the head-of-line block behind the outbox writer, but it also
/// means a read can land on a *different* connection than the write that
/// preceded it — so the properties worth pinning are the ones a second
/// connection could plausibly break.
///
/// These tests must run **file-backed with `background: true`**: the read pool
/// only takes effect for `NativeDatabase.createInBackground`, and
/// `inMemoryDatabase: true` bypasses it entirely (see `openDbConnection`).
/// An in-memory test here would pass without exercising a pool at all.
void main() {
  late Directory tempDir;
  late SyncDatabase db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lotti_sync_read_pool_');
    db = SyncDatabase(
      overriddenFilename: 'sync_read_pool_test.sqlite',
      documentsDirectoryProvider: () async => tempDir,
      tempDirectoryProvider: () async => tempDir,
    );
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('a read sees a write that committed before it', () async {
    // Read-your-writes across the connection boundary. In WAL a reader on
    // another connection sees every committed transaction, but this is the
    // assumption the whole change rests on, so assert it rather than trust it.
    await db
        .into(db.outbox)
        .insert(
          buildOutboxCompanion(
            status: OutboxStatus.pending,
            createdAt: DateTime(2026, 3, 15),
            subject: 'first',
          ),
        );

    final rows = await db.select(db.outbox).get();

    expect(rows, hasLength(1));
    expect(rows.single.subject, 'first');
  });

  test('sequential write/read pairs never observe a stale snapshot', () async {
    // A pool connection that held on to an old read snapshot would start
    // returning short counts here. Interleaved rather than batched, because
    // that is the pattern the outbox pipeline actually uses.
    for (var i = 0; i < 12; i++) {
      await db
          .into(db.outbox)
          .insert(
            buildOutboxCompanion(
              status: OutboxStatus.pending,
              createdAt: DateTime(2026, 3, 15).add(Duration(minutes: i)),
              subject: 'row-$i',
            ),
          );

      final count = await db.outbox.count().getSingle();
      expect(
        count,
        i + 1,
        reason: 'read after write $i must observe every prior commit',
      );
    }
  });

  test('concurrent reads all observe the same committed state', () async {
    for (var i = 0; i < 5; i++) {
      await db
          .into(db.outbox)
          .insert(
            buildOutboxCompanion(
              status: OutboxStatus.pending,
              createdAt: DateTime(2026, 3, 15).add(Duration(minutes: i)),
              subject: 'row-$i',
            ),
          );
    }

    // Fanned out so they spread across both pool isolates.
    final counts = await Future.wait([
      for (var i = 0; i < 8; i++) db.outbox.count().getSingle(),
    ]);

    expect(
      counts,
      everyElement(5),
      reason: 'no pool isolate may serve a stale or partial snapshot',
    );
  });

  test('a transaction still reads its own uncommitted writes', () async {
    // Drift keeps transactions on the write executor. If a read inside one were
    // routed to the pool it would miss the uncommitted row.
    await db.transaction(() async {
      await db
          .into(db.outbox)
          .insert(
            buildOutboxCompanion(
              status: OutboxStatus.pending,
              createdAt: DateTime(2026, 3, 15),
              subject: 'in-txn',
            ),
          );

      final inside = await db.select(db.outbox).get();
      expect(
        inside,
        hasLength(1),
        reason: 'the transaction must see its own uncommitted insert',
      );
    });

    expect(await db.outbox.count().getSingle(), 1);
  });

  test('a rolled-back transaction leaves nothing visible to readers', () async {
    await expectLater(
      db.transaction(() async {
        await db
            .into(db.outbox)
            .insert(
              buildOutboxCompanion(
                status: OutboxStatus.pending,
                createdAt: DateTime(2026, 3, 15),
                subject: 'doomed',
              ),
            );
        throw StateError('abort');
      }),
      throwsA(isA<StateError>()),
    );

    expect(
      await db.outbox.count().getSingle(),
      0,
      reason: 'a pool reader must not surface a rolled-back row',
    );
  });
}
