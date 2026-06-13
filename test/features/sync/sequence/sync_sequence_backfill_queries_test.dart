import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_backfill_queries.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_backfill_responder.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_cache.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_gap_materializer.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_missing_notifier.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_receiver.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_tracer.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(LogDomain.sync);
    registerFallbackValue(SyncSequencePayloadType.journalEntity);
    registerFallbackValue(Duration.zero);
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
  late MockVectorClockService vc;
  late MockDomainLogger logging;
  late SyncSequenceCache cache;
  late SyncSequenceReceiver receiver;
  late SyncSequenceBackfillQueries queries;

  const myHost = 'my-host';
  const alice = 'alice';

  setUp(() {
    db = MockSyncDatabase();
    vc = MockVectorClockService();
    logging = MockDomainLogger();
    when(
      () => logging.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);
    when(vc.getHost).thenAnswer((_) async => myHost);
    when(() => db.recordSequenceEntry(any())).thenAnswer((_) async => 1);
    when(() => db.batchInsertSequenceEntries(any())).thenAnswer((_) async {});
    cache = SyncSequenceCache(db);
    final tracer = SyncSequenceTracer(loggingService: logging);
    receiver = SyncSequenceReceiver(
      syncDatabase: db,
      vectorClockService: vc,
      cache: cache,
      gapMaterializer: SyncSequenceGapMaterializer(
        syncDatabase: db,
        cache: cache,
        tracer: tracer,
      ),
      backfillResponder: SyncSequenceBackfillResponder(
        syncDatabase: db,
        cache: cache,
        tracer: tracer,
      ),
      missingNotifier: SyncSequenceMissingNotifier(tracer: tracer),
      tracer: tracer,
    );
    queries = SyncSequenceBackfillQueries(
      syncDatabase: db,
      cache: cache,
      receiver: receiver,
      tracer: tracer,
    );
  });

  group('retire paths clear the shared cache when rows are retired', () {
    test(
      'retireExhaustedRequestedEntries clears watermark and materialized bound',
      () async {
        cache.setMaterializedUpperBound(alice, 42);
        when(() => db.getLastCounterForHost(alice)).thenAnswer((_) async => 4);
        await cache.getCachedLastCounterForHost(alice);
        when(
          () => db.retireExhaustedRequestedEntries(
            maxRequestCount: any(named: 'maxRequestCount'),
            grace: any(named: 'grace'),
          ),
        ).thenAnswer((_) async => 2);

        final count = await queries.retireExhaustedRequestedEntries();

        expect(count, 2);
        expect(cache.containsLastCounter(alice), isFalse);
        expect(cache.getMaterializedUpperBound(alice), isNull);
      },
    );

    test(
      'retireAgedOutRequestedEntries leaves the cache alone when nothing retires',
      () async {
        cache.setMaterializedUpperBound(alice, 42);
        when(
          () => db.retireAgedOutRequestedEntries(
            amnestyWindow: any(named: 'amnestyWindow'),
          ),
        ).thenAnswer((_) async => 0);

        final count = await queries.retireAgedOutRequestedEntries();

        expect(count, 0);
        expect(cache.getMaterializedUpperBound(alice), 42);
      },
    );
  });

  group('read-only query delegation', () {
    test('getBackfillStats returns the database stats', () async {
      final stats = BackfillStats.fromHostStats(const [
        BackfillHostStats(
          receivedCount: 1,
          missingCount: 1,
          requestedCount: 1,
          backfilledCount: 0,
          deletedCount: 0,
          unresolvableCount: 0,
          burnedCount: 0,
        ),
      ]);
      when(db.getBackfillStats).thenAnswer((_) async => stats);

      expect(await queries.getBackfillStats(), same(stats));
    });

    test('getNearestCoveringEntry forwards hostId and counter', () async {
      when(
        () => db.getNearestCoveringEntry(alice, 7),
      ).thenAnswer((_) async => null);

      expect(await queries.getNearestCoveringEntry(alice, 7), isNull);
      verify(() => db.getNearestCoveringEntry(alice, 7)).called(1);
    });
  });

  group('recordReceivedEntryLink', () {
    test('delegates to the receiver with the entryLink payload type', () async {
      when(
        () => db.updateHostActivity(any(), any()),
      ).thenAnswer((_) async => 1);
      when(
        () => db.getHostLastSeen(alice),
      ).thenAnswer((_) async => DateTime(2024));
      when(() => db.getLastCounterForHost(alice)).thenAnswer((_) async => 0);
      when(
        () => db.getEntryByHostAndCounter(alice, 1),
      ).thenAnswer((_) async => null);
      when(
        () => db.getPendingEntriesByPayloadId(
          payloadType: any(named: 'payloadType'),
          payloadId: any(named: 'payloadId'),
        ),
      ).thenAnswer((_) async => []);

      await queries.recordReceivedEntryLink(
        linkId: 'link-1',
        vectorClock: const VectorClock({alice: 1}),
        originatingHostId: alice,
      );

      final captured =
          verify(
                () => db.recordSequenceEntry(captureAny()),
              ).captured.single
              as SyncSequenceLogCompanion;
      expect(captured.entryId.value, 'link-1');
      expect(
        captured.payloadType.value,
        SyncSequencePayloadType.entryLink.index,
      );
    });
  });

  group('populateFromJournal', () {
    test(
      'inserts one row per new (host, counter) and dedups within a run',
      () async {
        when(
          () => db.getCountersForHost(alice),
        ).thenAnswer((_) async => <int>{});

        final populated = await queries.populateFromJournal(
          entryStream: Stream.fromIterable([
            [
              (id: 'j1', vectorClock: {alice: 1}),
              // Same (alice,1) again within the run → deduped.
              (id: 'j2', vectorClock: {alice: 1}),
              (id: 'j3', vectorClock: {alice: 2}),
            ],
          ]),
          getTotalCount: () async => 3,
        );

        expect(populated, 2);
        final inserted =
            verify(
                  () => db.batchInsertSequenceEntries(captureAny()),
                ).captured.single
                as List<SyncSequenceLogCompanion>;
        expect(inserted.map((c) => c.counter.value).toList(), [1, 2]);
        expect(
          inserted.every(
            (c) =>
                c.payloadType.value ==
                SyncSequencePayloadType.journalEntity.index,
          ),
          isTrue,
        );
      },
    );
  });
}
