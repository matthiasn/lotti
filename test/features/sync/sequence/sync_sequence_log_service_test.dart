// ignore_for_file: avoid_redundant_argument_values

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'sync_sequence_log_service_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSyncDatabase mockDb;
  late MockVectorClockService mockVcService;
  late MockDomainLogger mockLogging;
  late SyncSequenceLogService service;

  const myHostId = 'my-host-uuid';
  const aliceHostId = 'alice-host-uuid';
  const bobHostId = 'bob-host-uuid';

  setUpAll(registerSyncSequenceLogFallbackValues);

  setUp(() {
    final bench = SyncSequenceLogServiceTestBench.create(
      myHostId: myHostId,
      aliceHostId: aliceHostId,
      bobHostId: bobHostId,
    );
    mockDb = bench.mockDb;
    mockVcService = bench.mockVcService;
    mockLogging = bench.mockLogging;
    service = bench.service;
  });

  group('recordSentEntry', () {
    test('records sent entry for own host', () async {
      const vectorClock = VectorClock({myHostId: 10});
      const entryId = 'my-entry';

      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.recordSentEntry(entryId: entryId, vectorClock: vectorClock);

      verify(() => mockDb.recordSequenceEntry(any())).called(1);
    });

    test('ignores other hosts in sent entry', () async {
      // When sending, we only care about our own counter
      const vectorClock = VectorClock({myHostId: 5, aliceHostId: 10});
      const entryId = 'my-entry';

      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.recordSentEntry(entryId: entryId, vectorClock: vectorClock);

      // Should only record our own host
      verify(() => mockDb.recordSequenceEntry(any())).called(1);
    });
  });

  group('markAsRequested', () {
    test('delegates to batchIncrementRequestCounts', () async {
      final entries = [
        (hostId: aliceHostId, counter: 1),
        (hostId: aliceHostId, counter: 2),
        (hostId: bobHostId, counter: 1),
      ];
      when(
        () => mockDb.batchIncrementRequestCounts(any()),
      ).thenAnswer((_) async {});

      await service.markAsRequested(entries);

      verify(() => mockDb.batchIncrementRequestCounts(entries)).called(1);
    });

    test('handles empty list', () async {
      when(
        () => mockDb.batchIncrementRequestCounts(any()),
      ).thenAnswer((_) async {});

      await service.markAsRequested([]);

      verify(() => mockDb.batchIncrementRequestCounts([])).called(1);
    });
  });

  group('getMissingEntries', () {
    // Stubs and verifies must mirror the exact parameter shape of the
    // service's call site (which passes limit/maxRequestCount/offset/minAge
    // explicitly and omits `now`): noSuchMethod forwarders for mixin-declared
    // methods do not reliably fill in omitted optional parameters, so a stub
    // that omits a parameter the production call passes never matches.
    test('delegates to database with default parameters', () async {
      when(
        () => mockDb.getMissingEntries(
          limit: any(named: 'limit'),
          maxRequestCount: any(named: 'maxRequestCount'),
          offset: any(named: 'offset'),
          minAge: any(named: 'minAge'),
        ),
      ).thenAnswer((_) async => []);

      await service.getMissingEntries();

      verify(
        () => mockDb.getMissingEntries(
          limit: 50,
          maxRequestCount: 10,
          offset: 0,
          minAge: Duration.zero,
        ),
      ).called(1);
    });

    test('passes custom parameters', () async {
      when(
        () => mockDb.getMissingEntries(
          limit: any(named: 'limit'),
          maxRequestCount: any(named: 'maxRequestCount'),
          offset: any(named: 'offset'),
          minAge: any(named: 'minAge'),
        ),
      ).thenAnswer((_) async => []);

      await service.getMissingEntries(limit: 25, maxRequestCount: 8);

      verify(
        () => mockDb.getMissingEntries(
          limit: 25,
          maxRequestCount: 8,
          offset: 0,
          minAge: Duration.zero,
        ),
      ).called(1);
    });
  });

  group('host activity cache', () {
    test('caches getHostLastSeen and reuses on subsequent calls', () async {
      // Set up stubs for both hosts
      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 9);
      when(
        () => mockDb.getLastCounterForHost(bobHostId),
      ).thenAnswer((_) async => 5);
      when(
        () => mockDb.getEntryByHostAndCounter(any(), any()),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      // Process entry from alice with bob in the VC
      await service.recordReceivedEntry(
        entryId: 'entry-1',
        vectorClock: const VectorClock({aliceHostId: 10, bobHostId: 6}),
        originatingHostId: aliceHostId,
      );

      // Bob (non-originator) should have getHostLastSeen called via cache
      verify(() => mockDb.getHostLastSeen(bobHostId)).called(1);

      // Alice is originator — host activity is set directly via
      // updateHostActivity, not via getHostLastSeen
      verifyNever(() => mockDb.getHostLastSeen(aliceHostId));

      // Process a second entry — bob's getHostLastSeen should be served
      // from cache (no additional DB call) since cache is still valid.
      // Note: getLastCounterForHost for bob gets invalidated per-host
      // after writes, but getHostLastSeen stays cached.
      when(
        () => mockDb.getLastCounterForHost(bobHostId),
      ).thenAnswer((_) async => 6);

      await service.recordReceivedEntry(
        entryId: 'entry-2',
        vectorClock: const VectorClock({aliceHostId: 11, bobHostId: 6}),
        originatingHostId: aliceHostId,
      );

      // Bob's getHostLastSeen was NOT called again — served from cache
      verifyNever(() => mockDb.getHostLastSeen(bobHostId));
    });

    test('clears cache after expiry and re-queries DB', () async {
      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 9);
      when(
        () => mockDb.getLastCounterForHost(bobHostId),
      ).thenAnswer((_) async => 5);
      when(
        () => mockDb.getEntryByHostAndCounter(any(), any()),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      // First call — populates cache for bob
      await service.recordReceivedEntry(
        entryId: 'entry-1',
        vectorClock: const VectorClock({aliceHostId: 10, bobHostId: 6}),
        originatingHostId: aliceHostId,
      );

      verify(() => mockDb.getHostLastSeen(bobHostId)).called(1);

      // Force expire the cache
      service.expireCacheForTesting();

      // Second call — cache is expired, should re-query DB
      when(
        () => mockDb.getLastCounterForHost(bobHostId),
      ).thenAnswer((_) async => 6);

      await service.recordReceivedEntry(
        entryId: 'entry-2',
        vectorClock: const VectorClock({aliceHostId: 11, bobHostId: 7}),
        originatingHostId: aliceHostId,
      );

      // Bob's host last seen should be queried again after cache expiry
      verify(() => mockDb.getHostLastSeen(bobHostId)).called(1);
    });

    test('per-host TTL evicts only the expired host on natural wall-clock '
        'expiry — a second host queried within its own window stays cached '
        'and does not re-hit the DB', () async {
      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 9);
      when(
        () => mockDb.getLastCounterForHost(bobHostId),
      ).thenAnswer((_) async => 5);
      when(
        () => mockDb.getEntryByHostAndCounter(any(), any()),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      final t0 = DateTime(2026, 5, 10, 12);
      // T0 — populate the cache for bob.
      await withClock(Clock.fixed(t0), () async {
        await service.recordReceivedEntry(
          entryId: 'entry-1',
          vectorClock: const VectorClock({aliceHostId: 10, bobHostId: 6}),
          originatingHostId: aliceHostId,
        );
      });
      verify(() => mockDb.getHostLastSeen(bobHostId)).called(1);

      // T0 + 6 min — bob's per-host expiry has elapsed. The next
      // record routed through bob must trigger `_evictHost(bob)` and
      // re-query the DB. Carol is queried for the first time at the
      // same moment and must hit the DB once (cold cache).
      when(
        () => mockDb.getLastCounterForHost('carol'),
      ).thenAnswer((_) async => 1);
      when(() => mockDb.getHostLastSeen('carol')).thenAnswer((_) async => t0);
      when(
        () => mockDb.getLastCounterForHost(bobHostId),
      ).thenAnswer((_) async => 6);

      await withClock(
        Clock.fixed(t0.add(const Duration(minutes: 6))),
        () async {
          await service.recordReceivedEntry(
            entryId: 'entry-2',
            vectorClock: const VectorClock({
              aliceHostId: 11,
              bobHostId: 7,
              'carol': 1,
            }),
            originatingHostId: aliceHostId,
          );
        },
      );
      verify(() => mockDb.getHostLastSeen(bobHostId)).called(1);
      verify(() => mockDb.getHostLastSeen('carol')).called(1);

      // T0 + 8 min — carol is still inside her freshly opened window
      // (refreshed on the previous miss). Recording another entry
      // that touches carol must not re-hit the DB; bob's freshly
      // refreshed window also keeps him cached.
      await withClock(
        Clock.fixed(t0.add(const Duration(minutes: 8))),
        () async {
          await service.recordReceivedEntry(
            entryId: 'entry-3',
            vectorClock: const VectorClock({
              aliceHostId: 12,
              bobHostId: 8,
              'carol': 2,
            }),
            originatingHostId: aliceHostId,
          );
        },
      );
      verifyNever(() => mockDb.getHostLastSeen('carol'));
      verifyNever(() => mockDb.getHostLastSeen(bobHostId));
    });

    test('advances the last-counter cache incrementally on contiguous '
        'records instead of re-querying the slow watermark CTE — under '
        'heavy backfill (50 children per outbox bundle from one host), '
        'the old per-record invalidation forced the next child to re-run '
        '`getLastCounterForHost`, which dominated the iOS slow-query log. '
        'A strict +1 advance preserves correctness (under-reports are '
        'safe; over-reports are not — and this helper never advances by '
        'more than 1) while collapsing 50 cache misses to 1 lookup.', () async {
      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 9);
      when(
        () => mockDb.getLastCounterForHost(bobHostId),
      ).thenAnswer((_) async => 5);
      when(
        () => mockDb.getEntryByHostAndCounter(any(), any()),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      // First entry: bob counter at 6, contiguous with cached 5. The
      // gap-detection path reads `getLastCounterForHost(bob)` once,
      // then the recorded counter advances the cache from 5 to 6.
      await service.recordReceivedEntry(
        entryId: 'entry-1',
        vectorClock: const VectorClock({aliceHostId: 10, bobHostId: 6}),
        originatingHostId: aliceHostId,
      );

      verify(() => mockDb.getLastCounterForHost(bobHostId)).called(1);

      // Second entry: bob counter at 7, contiguous with the now-cached
      // 6. The cached watermark is still correct without a DB
      // round-trip, so the slow CTE must NOT fire again.
      await service.recordReceivedEntry(
        entryId: 'entry-2',
        vectorClock: const VectorClock({aliceHostId: 11, bobHostId: 7}),
        originatingHostId: aliceHostId,
      );

      verifyNever(() => mockDb.getLastCounterForHost(bobHostId));
    });
  });

  group('getLastSentVectorClockForEntry', () {
    test('returns null when host is not available', () async {
      when(() => mockVcService.getHost()).thenAnswer((_) async => null);

      final result = await service.getLastSentVectorClockForEntry('entry-1');
      expect(result, isNull);
    });

    test('returns null when no sent counter exists for the entry', () async {
      when(
        () => mockDb.getLastSentCounterForEntry(myHostId, 'entry-1'),
      ).thenAnswer((_) async => null);

      final result = await service.getLastSentVectorClockForEntry('entry-1');
      expect(result, isNull);
    });

    test('returns vector clock with the last sent counter', () async {
      when(
        () => mockDb.getLastSentCounterForEntry(myHostId, 'entry-1'),
      ).thenAnswer((_) async => 42);

      final result = await service.getLastSentVectorClockForEntry('entry-1');
      expect(result, isNotNull);
      expect(result!.vclock, {myHostId: 42});
    });

    test('caches the DB result so repeat lookups for the same entry do not '
        're-query sync.sqlite', () async {
      when(
        () => mockDb.getLastSentCounterForEntry(myHostId, 'entry-42'),
      ).thenAnswer((_) async => 99);

      final first = await service.getLastSentVectorClockForEntry('entry-42');
      final second = await service.getLastSentVectorClockForEntry('entry-42');
      final third = await service.getLastSentVectorClockForEntry('entry-42');

      expect(first!.vclock, {myHostId: 99});
      expect(second!.vclock, {myHostId: 99});
      expect(third!.vclock, {myHostId: 99});
      verify(
        () => mockDb.getLastSentCounterForEntry(myHostId, 'entry-42'),
      ).called(1);
    });

    test('caches a null result so entries that have never been sent do not '
        'thrash the DB on every outbox enqueue', () async {
      when(
        () => mockDb.getLastSentCounterForEntry(myHostId, 'never-sent'),
      ).thenAnswer((_) async => null);

      await service.getLastSentVectorClockForEntry('never-sent');
      await service.getLastSentVectorClockForEntry('never-sent');

      verify(
        () => mockDb.getLastSentCounterForEntry(myHostId, 'never-sent'),
      ).called(1);
    });

    test('recordSentEntry refreshes the cache so a follow-up outbox lookup '
        'reflects the just-sent counter without a DB round-trip', () async {
      // First lookup: seed the cache at 50.
      when(
        () => mockDb.getLastSentCounterForEntry(myHostId, 'entry-seed'),
      ).thenAnswer((_) async => 50);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      final seeded = await service.getLastSentVectorClockForEntry('entry-seed');
      expect(seeded!.vclock, {myHostId: 50});

      // Record a newer sent counter.
      await service.recordSentEntry(
        entryId: 'entry-seed',
        vectorClock: const VectorClock({myHostId: 57}),
      );

      // Subsequent lookup must see 57 from the cache — no extra DB call.
      final refreshed = await service.getLastSentVectorClockForEntry(
        'entry-seed',
      );
      expect(refreshed!.vclock, {myHostId: 57});
      verify(
        () => mockDb.getLastSentCounterForEntry(myHostId, 'entry-seed'),
      ).called(1);
    });

    test(
      'cache honors the TTL window shared with the other host caches',
      () async {
        when(
          () => mockDb.getLastSentCounterForEntry(myHostId, 'entry-ttl'),
        ).thenAnswer((_) async => 7);

        await service.getLastSentVectorClockForEntry('entry-ttl');
        service.expireCacheForTesting();
        await service.getLastSentVectorClockForEntry('entry-ttl');

        verify(
          () => mockDb.getLastSentCounterForEntry(myHostId, 'entry-ttl'),
        ).called(2);
      },
    );

    test(
      'last-sent cache wipes the entry-keyed LRU when the wall-clock TTL '
      'elapses naturally — second call after >5 min re-queries the DB',
      () async {
        when(
          () => mockDb.getLastSentCounterForEntry(myHostId, 'entry-natural'),
        ).thenAnswer((_) async => 9);

        final start = DateTime(2026, 5, 10, 12);
        await withClock(Clock.fixed(start), () async {
          await service.getLastSentVectorClockForEntry('entry-natural');
        });
        // Step the clock past _cacheTtl (5 minutes) so the next call's
        // `_invalidateLastSentCacheIfExpired` clears the LRU and the
        // subsequent `_ensureLastSentCacheWindow` opens a fresh window.
        await withClock(
          Clock.fixed(start.add(const Duration(minutes: 6))),
          () async {
            await service.getLastSentVectorClockForEntry('entry-natural');
          },
        );

        verify(
          () => mockDb.getLastSentCounterForEntry(myHostId, 'entry-natural'),
        ).called(2);
      },
    );

    test(
      'recordSentEntry does not downgrade the cached counter when a lower '
      'counter is re-recorded (superseded by a newer send in flight)',
      () async {
        when(
          () => mockDb.getLastSentCounterForEntry(myHostId, 'entry-nodown'),
        ).thenAnswer((_) async => 100);
        when(
          () => mockDb.recordSequenceEntry(any()),
        ).thenAnswer((_) async => 1);

        // Seed the cache at 100.
        final seeded = await service.getLastSentVectorClockForEntry(
          'entry-nodown',
        );
        expect(seeded!.vclock[myHostId], 100);

        // Record a LOWER counter — must not downgrade the cache.
        await service.recordSentEntry(
          entryId: 'entry-nodown',
          vectorClock: const VectorClock({myHostId: 50}),
        );

        final afterLower = await service.getLastSentVectorClockForEntry(
          'entry-nodown',
        );
        expect(afterLower!.vclock[myHostId], 100);
        // Still only the one DB call from the initial seed.
        verify(
          () => mockDb.getLastSentCounterForEntry(myHostId, 'entry-nodown'),
        ).called(1);
      },
    );
  });

  group('cache invalidation after marking covered counters', () {
    test('covered counters invalidate watermark cache so gap detection '
        'sees updated watermark on second call', () async {
      // Scenario: Two consecutive recordReceivedEntry calls from alice.
      // 1st call: counter=2 → populates cache with watermark=2
      // 2nd call: counter=5 with covered VC {alice: 3}
      //   - covered VC marks counter 3 as received and invalidates cache
      //   - gap detection re-queries DB → watermark=3
      //   - only counter 4 is detected as gap (not 3)

      // First call: alice counter 2, sequential, no gaps
      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 1);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 2),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      await service.recordReceivedEntry(
        entryId: 'entry-2',
        vectorClock: const VectorClock({aliceHostId: 2}),
        originatingHostId: aliceHostId,
      );

      // Cache is now populated with watermark=2 for alice (invalidated
      // and then re-populated during gap detection).
      // Reset mock to return 3 on next DB query (simulating that
      // counter 3 was marked as received by covered VC processing).
      reset(mockDb);
      when(
        () => mockDb.updateHostActivity(any(), any()),
      ).thenAnswer((_) async => 1);
      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 3);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 3),
      ).thenAnswer((_) async => null);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, 5),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);
      when(
        () => mockDb.getCountersForHostInRange(any(), any(), any()),
      ).thenAnswer((_) async => <int>{});
      when(
        () => mockDb.batchInsertSequenceEntries(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockDb.getPendingEntriesByPayloadId(
          payloadType: any(named: 'payloadType'),
          payloadId: any(named: 'payloadId'),
        ),
      ).thenAnswer((_) async => []);

      final gaps = await service.recordReceivedEntry(
        entryId: 'entry-5',
        vectorClock: const VectorClock({aliceHostId: 5}),
        originatingHostId: aliceHostId,
        coveredVectorClocks: const [
          VectorClock({aliceHostId: 3}),
        ],
      );

      // Without cache invalidation, the stale cache (watermark=2 from
      // the first call) would cause gap detection to see counters 3-4
      // as missing. With invalidation, the DB is re-queried (returns 3),
      // so only counter 4 is detected as a gap.
      verify(() => mockDb.getLastCounterForHost(aliceHostId)).called(1);
      expect(gaps.length, 1);
      expect(gaps[0], (hostId: aliceHostId, counter: 4));
    });

    test(
      'without covered VCs, stale cache causes wider gap detection',
      () async {
        // Control test: same scenario but WITHOUT covered VCs.
        // Cache is stale (watermark=2), so gap detection sees 3-4 as missing.

        // First call: populates cache with watermark=1 → becomes 2 after
        when(
          () => mockDb.getLastCounterForHost(aliceHostId),
        ).thenAnswer((_) async => 1);
        when(
          () => mockDb.getEntryByHostAndCounter(aliceHostId, 2),
        ).thenAnswer((_) async => null);
        when(
          () => mockDb.recordSequenceEntry(any()),
        ).thenAnswer((_) async => 1);

        await service.recordReceivedEntry(
          entryId: 'entry-2',
          vectorClock: const VectorClock({aliceHostId: 2}),
          originatingHostId: aliceHostId,
        );

        // Don't reset the mock — cache stays at watermark=2
        // (invalidation happened at end of first call, but the cache
        // was NOT re-populated since we didn't query again)
        // On next call, cache miss → re-queries DB
        // But this time mock returns 2 (no covered VC to advance it)
        reset(mockDb);
        when(
          () => mockDb.updateHostActivity(any(), any()),
        ).thenAnswer((_) async => 1);
        when(
          () => mockDb.getLastCounterForHost(aliceHostId),
        ).thenAnswer((_) async => 2);
        when(
          () => mockDb.getEntryByHostAndCounter(aliceHostId, 5),
        ).thenAnswer((_) async => null);
        when(
          () => mockDb.recordSequenceEntry(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => mockDb.getCountersForHostInRange(any(), any(), any()),
        ).thenAnswer((_) async => <int>{});
        when(
          () => mockDb.batchInsertSequenceEntries(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockDb.getPendingEntriesByPayloadId(
            payloadType: any(named: 'payloadType'),
            payloadId: any(named: 'payloadId'),
          ),
        ).thenAnswer((_) async => []);

        final gaps = await service.recordReceivedEntry(
          entryId: 'entry-5',
          vectorClock: const VectorClock({aliceHostId: 5}),
          originatingHostId: aliceHostId,
          // No covered VCs — watermark stays at 2
        );

        // Without covered VCs, both counters 3 and 4 are gaps
        expect(gaps.length, 2);
        expect(gaps[0], (hostId: aliceHostId, counter: 3));
        expect(gaps[1], (hostId: aliceHostId, counter: 4));
      },
    );
  });

  group('markOwnCounterUnresolvable', () {
    test(
      'delegates own-counter burns to the database-level guarded write',
      () async {
        when(
          () => mockDb.recordOwnUnresolvableSequenceCounter(
            hostId: aliceHostId,
            counter: 42,
            payloadType: SyncSequencePayloadType.journalEntity,
          ),
        ).thenAnswer((_) async => true);

        await service.markOwnCounterUnresolvable(
          hostId: aliceHostId,
          counter: 42,
        );

        verify(
          () => mockDb.recordOwnUnresolvableSequenceCounter(
            hostId: aliceHostId,
            counter: 42,
            payloadType: SyncSequencePayloadType.journalEntity,
          ),
        ).called(1);
      },
    );

    test(
      'logs skipped when the database-level guard preserves an authoritative '
      'payload mapping',
      () async {
        for (final status in [
          SyncSequenceStatus.received,
          SyncSequenceStatus.backfilled,
          SyncSequenceStatus.deleted,
        ]) {
          final counter = 100 + status.index;
          when(
            () => mockDb.recordOwnUnresolvableSequenceCounter(
              hostId: aliceHostId,
              counter: counter,
              payloadType: SyncSequencePayloadType.journalEntity,
            ),
          ).thenAnswer((_) async => false);

          await service.markOwnCounterUnresolvable(
            hostId: aliceHostId,
            counter: counter,
          );
        }

        verify(
          () => mockLogging.log(
            LogDomain.sync,
            any<String>(that: contains('markOwnCounterUnresolvable skipped')),
            subDomain: 'sequence.ownUnresolvable',
          ),
        ).called(3);
      },
    );
  });

  group('own-host reservation queries', () {
    test('returns and logs non-empty reserved counters', () async {
      when(
        () => mockDb.reservedSequenceCountersForHost(hostId: aliceHostId),
      ).thenAnswer((_) async => [4, 9]);

      final counters = await service.reservedCountersForHost(
        hostId: aliceHostId,
      );

      expect(counters, [4, 9]);
      verify(
        () => mockLogging.log(
          LogDomain.sync,
          any<String>(
            that: allOf(
              contains('reservedCountersForHost hostId=$aliceHostId'),
              contains('count=2'),
              contains('counters=[4, 9]'),
            ),
          ),
          subDomain: 'sequence.reservedCounters',
        ),
      ).called(1);
    });

    test('returns and logs non-empty burn-pending counters', () async {
      when(
        () => mockDb.burnPendingSequenceCountersForHost(hostId: aliceHostId),
      ).thenAnswer((_) async => [7, 12]);

      final counters = await service.burnPendingCountersForHost(
        hostId: aliceHostId,
      );

      expect(counters, [7, 12]);
      verify(
        () => mockLogging.log(
          LogDomain.sync,
          any<String>(
            that: allOf(
              contains('burnPendingCountersForHost hostId=$aliceHostId'),
              contains('count=2'),
              contains('counters=[7, 12]'),
            ),
          ),
          subDomain: 'sequence.burnPendingCounters',
        ),
      ).called(1);
    });
  });

  group('_trace routing', () {
    test('routes through DomainLogger when one is injected and skips the '
        'direct captureEvent fallback', () async {
      final mockDomainLogger = MockDomainLogger();
      when(
        () => mockDomainLogger.log(
          any<LogDomain>(),
          any<String>(),
          subDomain: any<String>(named: 'subDomain'),
          level: any<InsightLevel>(named: 'level'),
        ),
      ).thenReturn(null);

      final svc = SyncSequenceLogService(
        syncDatabase: mockDb,
        vectorClockService: mockVcService,
        loggingService: mockLogging,
        domainLogger: mockDomainLogger,
      );

      when(
        () => mockDb.resetUnresolvableWithKnownPayload(),
      ).thenAnswer((_) async => 3);

      // resetUnresolvableEntries emits exactly one _trace when count > 0.
      await svc.resetUnresolvableEntries();

      verify(
        () => mockDomainLogger.log(
          LogDomain.sync,
          any<String>(
            that: contains('resetUnresolvableEntries: reset 3 entries'),
          ),
          subDomain: 'sequence.resetUnresolvable',
        ),
      ).called(1);
      verifyNever(
        () => mockLogging.log(
          LogDomain.sync,
          any<String>(
            that: contains('resetUnresolvableEntries: reset 3 entries'),
          ),
          subDomain: 'sequence.resetUnresolvable',
        ),
      );
    });
  });

  group('recordSentEntryLink', () {
    test(
      'delegates to recordSentEntry with the entryLink payload type and linkId',
      () async {
        const vectorClock = VectorClock({myHostId: 7});
        const linkId = 'sent-link-7';
        when(
          () => mockDb.recordSequenceEntry(any()),
        ).thenAnswer((_) async => 1);

        await service.recordSentEntryLink(
          linkId: linkId,
          vectorClock: vectorClock,
        );

        final captured = verify(
          () => mockDb.recordSequenceEntry(captureAny()),
        ).captured;
        expect(captured.length, 1);
        final companion = captured.single as SyncSequenceLogCompanion;
        expect(companion.hostId.value, myHostId);
        expect(companion.counter.value, 7);
        expect(companion.entryId.value, linkId);
        expect(
          companion.payloadType.value,
          SyncSequencePayloadType.entryLink.index,
        );
        expect(companion.originatingHostId.value, myHostId);
      },
    );

    test(
      'only records the own-host counter from a multi-host link VC',
      () async {
        const vectorClock = VectorClock({myHostId: 4, aliceHostId: 9});
        const linkId = 'sent-link-multi';
        when(
          () => mockDb.recordSequenceEntry(any()),
        ).thenAnswer((_) async => 1);

        await service.recordSentEntryLink(
          linkId: linkId,
          vectorClock: vectorClock,
        );

        final captured = verify(
          () => mockDb.recordSequenceEntry(captureAny()),
        ).captured;
        expect(captured.length, 1);
        final companion = captured.single as SyncSequenceLogCompanion;
        // Only our own host's counter is recorded when sending.
        expect(companion.hostId.value, myHostId);
        expect(companion.counter.value, 4);
        expect(
          companion.payloadType.value,
          SyncSequencePayloadType.entryLink.index,
        );
      },
    );
  });

  group('hasActionableEntries', () {
    test('delegates to the database and returns its boolean result', () async {
      when(() => mockDb.hasActionableEntries()).thenAnswer((_) async => true);

      final result = await service.hasActionableEntries();

      expect(result, isTrue);
      verify(() => mockDb.hasActionableEntries()).called(1);
    });

    test('propagates a false result with no actionable rows', () async {
      when(() => mockDb.hasActionableEntries()).thenAnswer((_) async => false);

      final result = await service.hasActionableEntries();

      expect(result, isFalse);
      verify(() => mockDb.hasActionableEntries()).called(1);
    });
  });

  group('missing-entries callback error handling', () {
    test('logs and swallows an exception thrown by onMissingEntriesDetected so '
        'gap recording still returns the detected gaps', () async {
      final thrown = StateError('callback boom');
      service.onMissingEntriesDetected = () => throw thrown;
      when(
        () => mockLogging.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});

      const vectorClock = VectorClock({aliceHostId: 5});
      when(
        () => mockDb.getLastCounterForHost(aliceHostId),
      ).thenAnswer((_) async => 2);
      when(
        () => mockDb.getEntryByHostAndCounter(aliceHostId, any()),
      ).thenAnswer((_) async => null);
      when(() => mockDb.recordSequenceEntry(any())).thenAnswer((_) async => 1);

      // Must not rethrow even though the callback throws.
      final gaps = await service.recordReceivedEntry(
        entryId: 'entry-5',
        vectorClock: vectorClock,
        originatingHostId: aliceHostId,
      );

      expect(gaps, [
        (hostId: aliceHostId, counter: 3),
        (hostId: aliceHostId, counter: 4),
      ]);
      // The thrown error is routed to the logging service's error sink.
      verify(
        () => mockLogging.error(
          LogDomain.sync,
          thrown,
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'missingEntriesDetected',
        ),
      ).called(1);
    });
  });

  group('last-sent counter cache LRU eviction', () {
    test(
      'evicts the oldest entry once the cache exceeds its capacity, forcing a '
      'DB re-query for the evicted key while the newest stays cached',
      () async {
        const capacity = 2048;
        when(
          () => mockDb.recordSequenceEntry(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => mockDb.getLastSentCounterForEntry(myHostId, any()),
        ).thenAnswer((_) async => null);

        // Record capacity + 1 distinct own-host entries. Each recordSentEntry
        // touches the LRU cache; crossing the capacity must evict the first
        // (oldest) key inserted.
        for (var i = 0; i <= capacity; i++) {
          await service.recordSentEntry(
            entryId: 'lru-entry-$i',
            vectorClock: VectorClock({myHostId: i + 1}),
          );
        }

        // The newest key is still resident: getLastSentVectorClockForEntry
        // returns the cached counter without hitting the DB.
        final newest = await service.getLastSentVectorClockForEntry(
          'lru-entry-$capacity',
        );
        expect(newest?.vclock[myHostId], capacity + 1);
        verifyNever(
          () => mockDb.getLastSentCounterForEntry(
            myHostId,
            'lru-entry-$capacity',
          ),
        );

        // The oldest key (index 0) was evicted, so it re-queries the DB.
        await service.getLastSentVectorClockForEntry('lru-entry-0');
        verify(
          () => mockDb.getLastSentCounterForEntry(myHostId, 'lru-entry-0'),
        ).called(1);
      },
    );
  });
}
