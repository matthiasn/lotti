import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_cache.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockSyncDatabase db;
  late SyncSequenceCache cache;

  const hostId = 'host-a';

  setUp(() {
    db = MockSyncDatabase();
    cache = SyncSequenceCache(db);
  });

  group('getCachedHostLastSeen', () {
    test(
      'queries the DB once and serves subsequent reads from cache',
      () async {
        final seen = DateTime(2024, 3, 15, 10);
        when(() => db.getHostLastSeen(hostId)).thenAnswer((_) async => seen);

        final first = await cache.getCachedHostLastSeen(hostId);
        final second = await cache.getCachedHostLastSeen(hostId);

        expect(first, seen);
        expect(second, seen);
        verify(() => db.getHostLastSeen(hostId)).called(1);
      },
    );

    test('re-queries the DB after the per-host TTL elapses', () async {
      final start = DateTime(2024, 3, 15, 10);
      when(
        () => db.getHostLastSeen(hostId),
      ).thenAnswer((_) async => DateTime(2024, 3, 15, 9));

      await withClock(Clock.fixed(start), () async {
        await cache.getCachedHostLastSeen(hostId);
      });
      // Past the 5-minute window.
      await withClock(
        Clock.fixed(
          start.add(SyncSequenceCache.cacheTtl + const Duration(minutes: 1)),
        ),
        () async {
          await cache.getCachedHostLastSeen(hostId);
        },
      );

      verify(() => db.getHostLastSeen(hostId)).called(2);
    });
  });

  group('getCachedLastCounterForHost', () {
    test(
      'caches the watermark so repeat reads do not re-run the CTE',
      () async {
        when(() => db.getLastCounterForHost(hostId)).thenAnswer((_) async => 7);

        expect(await cache.getCachedLastCounterForHost(hostId), 7);
        expect(await cache.getCachedLastCounterForHost(hostId), 7);

        verify(() => db.getLastCounterForHost(hostId)).called(1);
      },
    );

    test(
      'caches a null watermark (cold host) without thrashing the DB',
      () async {
        when(
          () => db.getLastCounterForHost(hostId),
        ).thenAnswer((_) async => null);

        expect(await cache.getCachedLastCounterForHost(hostId), isNull);
        expect(await cache.getCachedLastCounterForHost(hostId), isNull);

        verify(() => db.getLastCounterForHost(hostId)).called(1);
      },
    );
  });

  group('advanceLastCounterCache', () {
    test('leaves a cold slot cold so the next read computes via SQL', () async {
      when(() => db.getLastCounterForHost(hostId)).thenAnswer((_) async => 3);

      cache.advanceLastCounterCache(hostId, 4);

      // Slot was never populated, so the advance is a no-op and the read still
      // hits the DB.
      expect(await cache.getCachedLastCounterForHost(hostId), 3);
      verify(() => db.getLastCounterForHost(hostId)).called(1);
    });

    test(
      'advances by exactly +1 and serves the advanced value from cache',
      () async {
        when(() => db.getLastCounterForHost(hostId)).thenAnswer((_) async => 5);
        // Warm the slot.
        await cache.getCachedLastCounterForHost(hostId);

        cache.advanceLastCounterCache(hostId, 6);

        expect(cache.getLastCounter(hostId), 6);
        // No second DB hit — the advanced value is served from cache.
        expect(await cache.getCachedLastCounterForHost(hostId), 6);
        verify(() => db.getLastCounterForHost(hostId)).called(1);
      },
    );

    test('does not advance across a gap (counter > current + 1)', () async {
      when(() => db.getLastCounterForHost(hostId)).thenAnswer((_) async => 5);
      await cache.getCachedLastCounterForHost(hostId);

      cache.advanceLastCounterCache(hostId, 9);

      expect(cache.getLastCounter(hostId), 5);
    });

    test('promotes a null watermark to 1 only when counter is 1', () async {
      when(
        () => db.getLastCounterForHost(hostId),
      ).thenAnswer((_) async => null);
      await cache.getCachedLastCounterForHost(hostId);

      cache.advanceLastCounterCache(hostId, 2);
      expect(cache.getLastCounter(hostId), isNull);

      cache.advanceLastCounterCache(hostId, 1);
      expect(cache.getLastCounter(hostId), 1);
    });
  });

  test(
    'invalidateCacheForHost drops the watermark but keeps host activity',
    () async {
      when(
        () => db.getHostLastSeen(hostId),
      ).thenAnswer((_) async => DateTime(2024));
      when(() => db.getLastCounterForHost(hostId)).thenAnswer((_) async => 4);
      await cache.getCachedHostLastSeen(hostId);
      await cache.getCachedLastCounterForHost(hostId);

      cache.invalidateCacheForHost(hostId);

      // Watermark re-queried, host activity still cached.
      await cache.getCachedLastCounterForHost(hostId);
      await cache.getCachedHostLastSeen(hostId);
      verify(() => db.getLastCounterForHost(hostId)).called(2);
      verify(() => db.getHostLastSeen(hostId)).called(1);
    },
  );

  test(
    'clearLastCounterCache and clearMaterializedUpperBound reset shared state',
    () async {
      when(() => db.getLastCounterForHost(hostId)).thenAnswer((_) async => 4);
      await cache.getCachedLastCounterForHost(hostId);

      cache
        ..setMaterializedUpperBound(hostId, 42)
        ..clearLastCounterCache()
        ..clearMaterializedUpperBound();

      expect(cache.getMaterializedUpperBound(hostId), isNull);
      await cache.getCachedLastCounterForHost(hostId);
      verify(() => db.getLastCounterForHost(hostId)).called(2);
    },
  );

  group('materialized upper bound', () {
    test('round-trips the highest materialized bound per host', () {
      expect(cache.getMaterializedUpperBound(hostId), isNull);
      cache.setMaterializedUpperBound(hostId, 100);
      expect(cache.getMaterializedUpperBound(hostId), 100);
    });
  });

  group('last-sent LRU', () {
    test('touch refreshes recency and evicts the oldest past capacity', () {
      // Fill to capacity.
      for (var i = 0; i < SyncSequenceCache.lastSentCounterCacheCapacity; i++) {
        cache.touchLastSentCache('k$i', i);
      }
      cache
        // Refresh the oldest key so it is no longer the eviction target.
        ..touchLastSentCache('k0', 0)
        // One more key triggers eviction of the now-oldest (k1).
        ..touchLastSentCache('overflow', 999);

      expect(cache.containsLastSent('k0'), isTrue);
      expect(cache.containsLastSent('k1'), isFalse);
      expect(cache.containsLastSent('overflow'), isTrue);
    });

    test('expireCacheForTesting wipes the LRU and the last-sent window', () {
      cache
        ..ensureLastSentCacheWindow()
        ..touchLastSentCache('k', 1);
      expect(cache.containsLastSent('k'), isTrue);

      cache.expireCacheForTesting();

      expect(cache.containsLastSent('k'), isFalse);
    });

    test(
      'invalidateLastSentCacheIfExpired clears the LRU once the window passes',
      () {
        final start = DateTime(2024, 3, 15, 10);
        withClock(Clock.fixed(start), () {
          cache
            ..ensureLastSentCacheWindow()
            ..touchLastSentCache('k', 1);
        });

        withClock(
          Clock.fixed(
            start.add(SyncSequenceCache.cacheTtl + const Duration(minutes: 1)),
          ),
          () {
            cache.invalidateLastSentCacheIfExpired();
          },
        );

        expect(cache.containsLastSent('k'), isFalse);
      },
    );

    test('lastSentCacheKey namespaces by host and entry', () {
      expect(cache.lastSentCacheKey('h', 'e'), 'h::e');
    });
  });
}
