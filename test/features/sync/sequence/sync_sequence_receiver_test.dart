// ignore_for_file: avoid_redundant_argument_values

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_backfill_responder.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_cache.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_gap_materializer.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_missing_notifier.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_receiver.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_tracer.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(LogDomain.sync);
    registerFallbackValue(SyncSequencePayloadType.journalEntity);
    registerFallbackValue(StackTrace.empty);
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
  late SyncSequenceMissingNotifier notifier;
  late SyncSequenceReceiver receiver;

  const myHost = 'my-host';
  const alice = 'alice';

  SyncSequenceReceiver build() {
    final tracer = SyncSequenceTracer(loggingService: logging);
    return SyncSequenceReceiver(
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
      missingNotifier: notifier,
      tracer: tracer,
    );
  }

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
    when(
      () => logging.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenAnswer((_) async {});
    when(vc.getHost).thenAnswer((_) async => myHost);
    when(() => db.updateHostActivity(any(), any())).thenAnswer((_) async => 1);
    when(() => db.recordSequenceEntry(any())).thenAnswer((_) async => 1);
    when(() => db.batchInsertSequenceEntries(any())).thenAnswer((_) async {});
    when(
      () => db.getPendingEntriesByPayloadId(
        payloadType: any(named: 'payloadType'),
        payloadId: any(named: 'payloadId'),
      ),
    ).thenAnswer((_) async => []);
    cache = SyncSequenceCache(db);
    final tracer = SyncSequenceTracer(loggingService: logging);
    notifier = SyncSequenceMissingNotifier(tracer: tracer);
    receiver = build();
  });

  group('getLastSentVectorClockForEntry', () {
    test('returns null when the host is unavailable', () async {
      when(vc.getHost).thenAnswer((_) async => null);

      expect(await receiver.getLastSentVectorClockForEntry('e1'), isNull);
    });

    test('caches the DB result so repeated lookups do not re-query', () async {
      when(
        () => db.getLastSentCounterForEntry(myHost, 'e1'),
      ).thenAnswer((_) async => 4);

      final first = await receiver.getLastSentVectorClockForEntry('e1');
      final second = await receiver.getLastSentVectorClockForEntry('e1');

      expect(first?.vclock, {myHost: 4});
      expect(second?.vclock, {myHost: 4});
      verify(() => db.getLastSentCounterForEntry(myHost, 'e1')).called(1);
    });
  });

  group('recordReceivedEntry gap detection', () {
    test('records the originator counter and detects a small gap', () async {
      // Alice is online with watermark 1; we observe counter 4 → gap 2,3.
      when(
        () => db.getHostLastSeen(alice),
      ).thenAnswer((_) async => DateTime(2024));
      when(() => db.getLastCounterForHost(alice)).thenAnswer((_) async => 1);
      when(
        () => db.getCountersForHostInRange(alice, 2, 3),
      ).thenAnswer((_) async => <int>{});
      when(
        () => db.getEntryByHostAndCounter(alice, 4),
      ).thenAnswer((_) async => null);

      final gaps = await receiver.recordReceivedEntry(
        entryId: 'e1',
        vectorClock: const VectorClock({alice: 4}),
        originatingHostId: alice,
      );

      expect(
        gaps.map((g) => g.counter).toList(),
        [2, 3],
      );
      // The missing counters were batch-inserted.
      final inserted =
          verify(
                () => db.batchInsertSequenceEntries(captureAny()),
              ).captured.single
              as List<SyncSequenceLogCompanion>;
      expect(inserted.map((c) => c.counter.value).toList(), [2, 3]);
    });

    test(
      'flags the missing notifier so the backfill nudge fires once',
      () async {
        var nudges = 0;
        notifier.onMissingEntriesDetected = () => nudges++;
        when(
          () => db.getHostLastSeen(alice),
        ).thenAnswer((_) async => DateTime(2024));
        when(() => db.getLastCounterForHost(alice)).thenAnswer((_) async => 1);
        when(
          () => db.getCountersForHostInRange(alice, 2, 3),
        ).thenAnswer((_) async => <int>{});
        when(
          () => db.getEntryByHostAndCounter(alice, 4),
        ).thenAnswer((_) async => null);

        await receiver.recordReceivedEntry(
          entryId: 'e1',
          vectorClock: const VectorClock({alice: 4}),
          originatingHostId: alice,
        );

        expect(nudges, 1);
      },
    );

    test('defers the nudge inside runWithDeferredMissingEntries', () async {
      var nudges = 0;
      notifier.onMissingEntriesDetected = () => nudges++;
      when(
        () => db.getHostLastSeen(alice),
      ).thenAnswer((_) async => DateTime(2024));
      when(() => db.getLastCounterForHost(alice)).thenAnswer((_) async => 1);
      when(
        () => db.getCountersForHostInRange(alice, 2, 3),
      ).thenAnswer((_) async => <int>{});
      when(
        () => db.getEntryByHostAndCounter(alice, 4),
      ).thenAnswer((_) async => null);

      await notifier.runWithDeferredMissingEntries(() async {
        await receiver.recordReceivedEntry(
          entryId: 'e1',
          vectorClock: const VectorClock({alice: 4}),
          originatingHostId: alice,
        );
        // Still deferred.
        expect(nudges, 0);
      });

      expect(nudges, 1);
    });

    test('skips our own host in the VC', () async {
      when(
        () => db.getEntryByHostAndCounter(alice, 2),
      ).thenAnswer((_) async => null);
      when(
        () => db.getHostLastSeen(alice),
      ).thenAnswer((_) async => DateTime(2024));
      when(() => db.getLastCounterForHost(alice)).thenAnswer((_) async => 1);

      await receiver.recordReceivedEntry(
        entryId: 'e1',
        vectorClock: const VectorClock({myHost: 9, alice: 2}),
        originatingHostId: alice,
      );

      // Our own host counter is never looked up or recorded.
      verifyNever(() => db.getEntryByHostAndCounter(myHost, 9));
    });
  });

  group('delegated query passthroughs', () {
    test('hasActionableEntries returns the database result', () async {
      when(db.hasActionableEntries).thenAnswer((_) async => true);
      expect(await receiver.hasActionableEntries(), isTrue);
    });

    test(
      'markOwnCounterUnresolvable delegates to the guarded DB write',
      () async {
        when(
          () => db.recordOwnUnresolvableSequenceCounter(
            hostId: any(named: 'hostId'),
            counter: any(named: 'counter'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenAnswer((_) async => true);

        await receiver.markOwnCounterUnresolvable(hostId: myHost, counter: 5);

        verify(
          () => db.recordOwnUnresolvableSequenceCounter(
            hostId: myHost,
            counter: 5,
            payloadType: SyncSequencePayloadType.journalEntity,
          ),
        ).called(1);
      },
    );
  });
}
