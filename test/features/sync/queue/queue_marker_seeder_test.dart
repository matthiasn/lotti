import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/queue/queue_marker_seeder.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late SyncDatabase syncDb;
  late MockSettingsDb settingsDb;
  late MockLoggingService logging;
  const roomId = '!roomA:example.org';

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  setUp(() {
    syncDb = SyncDatabase(inMemoryDatabase: true);
    settingsDb = MockSettingsDb();
    logging = MockLoggingService();
  });

  tearDown(() async {
    await syncDb.close();
  });

  QueueMarkerSeeder newSeeder() => QueueMarkerSeeder(
    syncDb: syncDb,
    settingsDb: settingsDb,
    logging: logging,
  );

  test('seeds queue_markers from legacy settings on first enable', () async {
    when(
      () => settingsDb.itemByKey(lastReadMatrixEventId),
    ).thenAnswer((_) async => r'$anchor');
    when(
      () => settingsDb.itemByKey(lastReadMatrixEventTs),
    ).thenAnswer((_) async => '5000');
    final seeder = newSeeder();

    final seeded = await seeder.seedIfAbsent(roomId);
    expect(seeded, isTrue);

    final marker = await (syncDb.select(
      syncDb.queueMarkers,
    )..where((t) => t.roomId.equals(roomId))).getSingle();
    expect(marker.lastAppliedEventId, r'$anchor');
    expect(marker.lastAppliedTs, 5000);
  });

  test('idempotent — a second call is a no-op', () async {
    when(
      () => settingsDb.itemByKey(lastReadMatrixEventId),
    ).thenAnswer((_) async => r'$anchor');
    when(
      () => settingsDb.itemByKey(lastReadMatrixEventTs),
    ).thenAnswer((_) async => '5000');
    final seeder = newSeeder();

    await seeder.seedIfAbsent(roomId);
    final secondRun = await seeder.seedIfAbsent(roomId);
    expect(secondRun, isFalse);
  });

  test('returns false when no legacy marker is stored', () async {
    when(
      () => settingsDb.itemByKey(lastReadMatrixEventId),
    ).thenAnswer((_) async => null);
    when(
      () => settingsDb.itemByKey(lastReadMatrixEventTs),
    ).thenAnswer((_) async => null);
    final seeded = await newSeeder().seedIfAbsent(roomId);
    expect(seeded, isFalse);
    final count = await syncDb
        .select(syncDb.queueMarkers)
        .get()
        .then((rows) => rows.length);
    expect(count, 0);
  });

  test('does not overwrite an existing queue_markers row', () async {
    await syncDb
        .into(syncDb.queueMarkers)
        .insert(
          QueueMarkersCompanion.insert(
            roomId: roomId,
            lastAppliedEventId: const Value(r'$existing'),
            lastAppliedTs: const Value(9000),
          ),
        );
    when(
      () => settingsDb.itemByKey(lastReadMatrixEventId),
    ).thenAnswer((_) async => r'$stale');
    when(
      () => settingsDb.itemByKey(lastReadMatrixEventTs),
    ).thenAnswer((_) async => '1000');

    final seeded = await newSeeder().seedIfAbsent(roomId);
    expect(seeded, isFalse);

    final marker = await (syncDb.select(
      syncDb.queueMarkers,
    )..where((t) => t.roomId.equals(roomId))).getSingle();
    expect(marker.lastAppliedEventId, r'$existing');
    expect(marker.lastAppliedTs, 9000);
  });
}
