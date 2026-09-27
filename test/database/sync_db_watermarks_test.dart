// Tests for the per-host contiguous watermarks
// (`lib/database/sync_db_watermarks.dart`).
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';

void main() {
  late SyncDatabase database;

  setUp(() => database = SyncDatabase(inMemoryDatabase: true));
  tearDown(() => database.close());

  Future<void> record(String host, int counter, SyncSequenceStatus status) =>
      database.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: Value(host),
          counter: Value(counter),
          status: Value(status.index),
          createdAt: Value(DateTime.utc(2024, 3, 15)),
          updatedAt: Value(DateTime.utc(2024, 3, 15)),
        ),
      );

  group('contiguousWatermarks', () {
    test('stops each host at its first unresolved counter, and names every '
        'known host whether asked for or not', () async {
      await record('host-a', 1, SyncSequenceStatus.received);
      await record('host-a', 2, SyncSequenceStatus.backfilled);
      // Counter 3 never arrived: 4 does not count.
      await record('host-a', 4, SyncSequenceStatus.received);
      await record('host-b', 1, SyncSequenceStatus.missing);
      await record('host-b', 2, SyncSequenceStatus.received);

      expect(await database.contiguousWatermarks({'host-a'}), {
        'host-a': 2,
        'host-b': 0,
      });
    });

    test('leaves out a host this device has never heard of', () async {
      await record('host-a', 1, SyncSequenceStatus.received);

      expect(await database.contiguousWatermarks({'host-unknown'}), {
        'host-a': 1,
      });
    });

    test('is empty on a fresh database', () async {
      expect(await database.contiguousWatermarks({}), isEmpty);
      expect(await database.contiguousWatermarks({''}), isEmpty);
    });
  });
}
