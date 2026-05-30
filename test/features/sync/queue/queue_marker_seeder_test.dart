import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/queue/queue_marker_seeder.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

enum _GeneratedExistingMarkerMode { absent, present }

enum _GeneratedLegacyEventMode { absent, serverAssigned, localPlaceholder }

enum _GeneratedLegacyTsMode { absent, valid, malformed }

class _GeneratedQueueMarkerSeedScenario {
  const _GeneratedQueueMarkerSeedScenario({
    required this.existingMode,
    required this.legacyEventMode,
    required this.legacyTsMode,
    required this.slot,
    required this.calls,
  });

  final _GeneratedExistingMarkerMode existingMode;
  final _GeneratedLegacyEventMode legacyEventMode;
  final _GeneratedLegacyTsMode legacyTsMode;
  final int slot;
  final int calls;

  bool get hasExisting => existingMode == _GeneratedExistingMarkerMode.present;

  String? get legacyEventId {
    switch (legacyEventMode) {
      case _GeneratedLegacyEventMode.absent:
        return null;
      case _GeneratedLegacyEventMode.serverAssigned:
        return r'$legacy-'
            '$slot';
      case _GeneratedLegacyEventMode.localPlaceholder:
        return 'lotti-$slot';
    }
  }

  String? get legacyTsSetting {
    switch (legacyTsMode) {
      case _GeneratedLegacyTsMode.absent:
        return null;
      case _GeneratedLegacyTsMode.valid:
        return '${1000 + slot}';
      case _GeneratedLegacyTsMode.malformed:
        return 'not-a-timestamp-$slot';
    }
  }

  int? get parsedLegacyTs =>
      legacyTsMode == _GeneratedLegacyTsMode.valid ? 1000 + slot : null;

  String? get existingEventId => hasExisting
      ? r'$existing-'
            '$slot'
      : null;

  int get existingTs => 9000 + slot;

  bool get shouldSeed =>
      !hasExisting && (legacyEventId != null || parsedLegacyTs != null);

  List<bool> expectedResults() => [
    for (var index = 0; index < calls; index++)
      if (index == 0 && shouldSeed) true else false,
  ];

  String? get expectedEventId => hasExisting
      ? existingEventId
      : shouldSeed
      ? legacyEventId
      : null;

  int? get expectedTs => hasExisting
      ? existingTs
      : shouldSeed
      ? parsedLegacyTs ?? 0
      : null;

  @override
  String toString() {
    return '_GeneratedQueueMarkerSeedScenario('
        'existingMode: $existingMode, '
        'legacyEventMode: $legacyEventMode, '
        'legacyTsMode: $legacyTsMode, '
        'slot: $slot, '
        'calls: $calls'
        ')';
  }
}

extension _AnyQueueMarkerSeedScenario on glados.Any {
  glados.Generator<_GeneratedExistingMarkerMode> get existingMarkerMode =>
      glados.AnyUtils(this).choose(_GeneratedExistingMarkerMode.values);

  glados.Generator<_GeneratedLegacyEventMode> get legacyEventMode =>
      glados.AnyUtils(this).choose(_GeneratedLegacyEventMode.values);

  glados.Generator<_GeneratedLegacyTsMode> get legacyTsMode =>
      glados.AnyUtils(this).choose(_GeneratedLegacyTsMode.values);

  glados.Generator<_GeneratedQueueMarkerSeedScenario>
  get queueMarkerSeedScenario => glados.CombinableAny(this).combine5(
    existingMarkerMode,
    legacyEventMode,
    legacyTsMode,
    glados.IntAnys(this).intInRange(0, 8),
    glados.IntAnys(this).intInRange(1, 4),
    (
      _GeneratedExistingMarkerMode existingMode,
      _GeneratedLegacyEventMode legacyEventMode,
      _GeneratedLegacyTsMode legacyTsMode,
      int slot,
      int calls,
    ) => _GeneratedQueueMarkerSeedScenario(
      existingMode: existingMode,
      legacyEventMode: legacyEventMode,
      legacyTsMode: legacyTsMode,
      slot: slot,
      calls: calls,
    ),
  );
}

void main() {
  late SyncDatabase syncDb;
  late MockSettingsDb settingsDb;
  late MockDomainLogger logging;
  const roomId = '!roomA:example.org';

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  setUp(() {
    syncDb = SyncDatabase(inMemoryDatabase: true);
    settingsDb = MockSettingsDb();
    logging = MockDomainLogger();
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

  glados.Glados(
    glados.any.queueMarkerSeedScenario,
    glados.ExploreConfig(numRuns: 120),
  ).test(
    'generated legacy marker combinations seed once without regressing rows',
    (scenario) async {
      final generatedDb = SyncDatabase(inMemoryDatabase: true);
      final generatedSettingsDb = MockSettingsDb();
      final generatedLogging = MockDomainLogger();
      when(
        () => generatedSettingsDb.itemByKey(lastReadMatrixEventId),
      ).thenAnswer((_) async => scenario.legacyEventId);
      when(
        () => generatedSettingsDb.itemByKey(lastReadMatrixEventTs),
      ).thenAnswer((_) async => scenario.legacyTsSetting);

      try {
        if (scenario.hasExisting) {
          await generatedDb
              .into(generatedDb.queueMarkers)
              .insert(
                QueueMarkersCompanion.insert(
                  roomId: roomId,
                  lastAppliedEventId: Value(scenario.existingEventId),
                  lastAppliedTs: Value(scenario.existingTs),
                ),
              );
        }

        final seeder = QueueMarkerSeeder(
          syncDb: generatedDb,
          settingsDb: generatedSettingsDb,
          logging: generatedLogging,
        );
        final results = <bool>[];
        for (var index = 0; index < scenario.calls; index++) {
          results.add(await seeder.seedIfAbsent(roomId));
        }

        expect(results, scenario.expectedResults(), reason: '$scenario');

        final rows = await (generatedDb.select(
          generatedDb.queueMarkers,
        )..where((t) => t.roomId.equals(roomId))).get();
        if (scenario.expectedTs == null) {
          expect(rows, isEmpty, reason: '$scenario');
        } else {
          expect(rows, hasLength(1), reason: '$scenario');
          expect(rows.single.lastAppliedEventId, scenario.expectedEventId);
          expect(rows.single.lastAppliedTs, scenario.expectedTs);
        }
      } finally {
        await generatedDb.close();
      }
    },
    tags: 'glados',
  );
}
