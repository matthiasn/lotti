import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/sync_sequence_payload_type.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/sequence/purged_entry_guard.dart';

void main() {
  late SyncDatabase db;
  late Directory documents;
  final now = DateTime(2024, 3, 15);

  setUp(() async {
    db = SyncDatabase(inMemoryDatabase: true);
    documents = await Directory.systemTemp.createTemp('purged_guard');
  });

  tearDown(() async {
    await db.close();
    await documents.delete(recursive: true);
  });

  Future<void> held(String host, int counter) => db.recordSequenceEntry(
    SyncSequenceLogCompanion(
      hostId: Value(host),
      counter: Value(counter),
      entryId: const Value('entry'),
      payloadType: Value(SyncSequencePayloadType.journalEntity.index),
      status: Value(SyncSequenceStatus.received.index),
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
  );

  PurgedEntryGuard guard() =>
      PurgedEntryGuard(syncDatabase: db, documentsDirectory: documents);

  Future<bool> stale(VectorClock? incoming) =>
      guard().isStaleCopyOfPurged(entryId: 'entry', incoming: incoming);

  test('a copy no newer than a version held here is stale; a newer or '
      'concurrent one is not', () async {
    await held('a', 3);
    await held('b', 1);

    expect(await stale(const VectorClock({'a': 2, 'b': 1})), isTrue);
    expect(await stale(const VectorClock({'a': 3, 'b': 1})), isTrue);
    expect(await stale(null), isTrue);
    expect(await stale(const VectorClock({'a': 4, 'b': 1})), isFalse);
    expect(await stale(const VectorClock({'a': 2, 'c': 1})), isFalse);
  });

  test('an entry this device never held is never stale', () async {
    expect(await stale(const VectorClock({'a': 1})), isFalse);
    expect(await stale(null), isFalse);
  });

  test('stands down when the journal was ever restored: a kept corrupt copy '
      'or the restore marker lies beside it', () async {
    await held('a', 3);
    File('${documents.path}/db.sqlite.corrupt-20240101-000000').createSync();
    expect(await stale(const VectorClock({'a': 2})), isFalse);

    await documents.delete(recursive: true);
    await documents.create();
    File('${documents.path}/db.sqlite.restored').createSync();
    final restored = guard();
    expect(restored.journalWasRestored, isTrue);
    expect(
      await restored.isStaleCopyOfPurged(
        entryId: 'entry',
        incoming: const VectorClock({'a': 2}),
      ),
      isFalse,
    );
  });

  test('another store restored beside the journal does not stand it down', () {
    File('${documents.path}/sync.sqlite.corrupt-20240101-000000').createSync();

    expect(guard().journalWasRestored, isFalse);
  });

  test('a documents directory that does not exist reads as never restored', () {
    final missing = PurgedEntryGuard(
      syncDatabase: db,
      documentsDirectory: Directory('${documents.path}/missing'),
    );

    expect(missing.journalWasRestored, isFalse);
  });
}
