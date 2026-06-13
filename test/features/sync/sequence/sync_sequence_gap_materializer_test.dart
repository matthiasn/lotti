import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_cache.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_gap_materializer.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_tracer.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

SyncSequenceLogItem _logItem({
  required String hostId,
  required int counter,
  required int status,
  String? entryId,
}) => SyncSequenceLogItem(
  hostId: hostId,
  counter: counter,
  entryId: entryId,
  payloadType: SyncSequencePayloadType.journalEntity.index,
  originatingHostId: hostId,
  status: status,
  createdAt: DateTime(2024, 3, 15, 10),
  updatedAt: DateTime(2024, 3, 15, 10),
  requestCount: 0,
);

void main() {
  setUpAll(() {
    registerFallbackValue(LogDomain.sync);
    registerFallbackValue(
      SyncSequenceLogCompanion(
        hostId: const Value(''),
        counter: const Value(0),
        status: const Value(0),
        createdAt: Value(DateTime(2024)),
        updatedAt: Value(DateTime(2024)),
      ),
    );
  });

  late MockSyncDatabase db;
  late MockDomainLogger logging;
  late SyncSequenceCache cache;
  late SyncSequenceGapMaterializer materializer;

  const hostId = 'host-a';

  setUp(() {
    db = MockSyncDatabase();
    logging = MockDomainLogger();
    when(
      () => logging.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);
    cache = SyncSequenceCache(db);
    materializer = SyncSequenceGapMaterializer(
      syncDatabase: db,
      cache: cache,
      tracer: SyncSequenceTracer(loggingService: logging),
    );
  });

  group('materializeLargeGap', () {
    test('inserts only the counters absent from the range', () async {
      when(
        () => db.getCountersForHostInRange(hostId, 1, 4),
      ).thenAnswer((_) async => {2});
      when(
        () => db.batchInsertSequenceEntries(any()),
      ).thenAnswer((_) async {});

      final inserted = await materializer.materializeLargeGap(
        hostId: hostId,
        startCounter: 1,
        endCounter: 4,
        gapSize: 4,
        originatingHostId: hostId,
        now: DateTime(2024, 3, 15, 10),
      );

      // 1, 3, 4 missing (2 already present).
      expect(inserted, 3);
      final captured =
          verify(
                () => db.batchInsertSequenceEntries(captureAny()),
              ).captured.single
              as List<SyncSequenceLogCompanion>;
      expect(
        captured.map((c) => c.counter.value).toList(),
        [1, 3, 4],
      );
      expect(
        captured.every(
          (c) => c.status.value == SyncSequenceStatus.missing.index,
        ),
        isTrue,
      );
    });

    test(
      'returns zero and skips the insert when the range is fully present',
      () async {
        when(
          () => db.getCountersForHostInRange(hostId, 1, 3),
        ).thenAnswer((_) async => {1, 2, 3});

        final inserted = await materializer.materializeLargeGap(
          hostId: hostId,
          startCounter: 1,
          endCounter: 3,
          gapSize: 3,
          originatingHostId: hostId,
          now: DateTime(2024, 3, 15, 10),
        );

        expect(inserted, 0);
        verifyNever(() => db.batchInsertSequenceEntries(any()));
      },
    );
  });

  group('filterCoveredVectorClocks', () {
    test('drops the clock equal to current and keeps superseded ones', () {
      const current = VectorClock({hostId: 5});
      const superseded = VectorClock({hostId: 3});

      final filtered = materializer.filterCoveredVectorClocks(
        [superseded, current],
        current,
      );

      expect(filtered, [superseded]);
    });

    test('returns an empty list for null or empty input', () {
      expect(
        materializer.filterCoveredVectorClocks(null, const VectorClock({})),
        isEmpty,
      );
      expect(
        materializer.filterCoveredVectorClocks([], const VectorClock({})),
        isEmpty,
      );
    });
  });

  group('markCoveredCountersAsReceived', () {
    test(
      'inserts received rows and invalidates the shared watermark cache for affected hosts',
      () async {
        // Warm the watermark cache so we can prove invalidation happens.
        when(() => db.getLastCounterForHost(hostId)).thenAnswer((_) async => 4);
        await cache.getCachedLastCounterForHost(hostId);
        expect(cache.containsLastCounter(hostId), isTrue);

        when(
          () => db.getEntryByHostAndCounter(hostId, 7),
        ).thenAnswer((_) async => null);
        when(
          () => db.recordSequenceEntry(any()),
        ).thenAnswer((_) async => 1);

        await materializer.markCoveredCountersAsReceived(
          coveredVectorClocks: [
            const VectorClock({hostId: 7}),
          ],
          entryId: 'e1',
          payloadType: SyncSequencePayloadType.journalEntity,
          myHost: 'my-host',
        );

        final captured =
            verify(
                  () => db.recordSequenceEntry(captureAny()),
                ).captured.single
                as SyncSequenceLogCompanion;
        expect(captured.counter.value, 7);
        expect(captured.status.value, SyncSequenceStatus.received.index);
        // The watermark cache for the affected host was invalidated.
        expect(cache.containsLastCounter(hostId), isFalse);
      },
    );

    test(
      'skips our own host and never downgrades already-received rows',
      () async {
        when(
          () => db.getEntryByHostAndCounter(hostId, 2),
        ).thenAnswer(
          (_) async => _logItem(
            hostId: hostId,
            counter: 2,
            status: SyncSequenceStatus.received.index,
          ),
        );

        await materializer.markCoveredCountersAsReceived(
          coveredVectorClocks: [
            const VectorClock({'my-host': 9, hostId: 2}),
          ],
          entryId: 'e1',
          payloadType: SyncSequencePayloadType.journalEntity,
          myHost: 'my-host',
        );

        // Own-host counter skipped; already-received foreign counter not rewritten.
        verifyNever(() => db.recordSequenceEntry(any()));
        verifyNever(() => db.getEntryByHostAndCounter('my-host', 9));
      },
    );

    test(
      'upgrades a requested row to received and traces the resolution',
      () async {
        when(
          () => db.getEntryByHostAndCounter(hostId, 3),
        ).thenAnswer(
          (_) async => _logItem(
            hostId: hostId,
            counter: 3,
            status: SyncSequenceStatus.requested.index,
          ),
        );
        when(() => db.recordSequenceEntry(any())).thenAnswer((_) async => 1);

        await materializer.markCoveredCountersAsReceived(
          coveredVectorClocks: [
            const VectorClock({hostId: 3}),
          ],
          entryId: 'e1',
          payloadType: SyncSequencePayloadType.journalEntity,
          myHost: 'my-host',
        );

        final captured =
            verify(
                  () => db.recordSequenceEntry(captureAny()),
                ).captured.single
                as SyncSequenceLogCompanion;
        expect(captured.status.value, SyncSequenceStatus.received.index);
      },
    );
  });
}
