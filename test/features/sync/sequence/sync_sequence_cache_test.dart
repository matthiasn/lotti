import 'dart:collection';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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

  group('sent bindings', () {
    void remember(int counter) => cache.rememberSentBinding(
      hostId: hostId,
      counter: counter,
      entryId: 'entry-$counter',
      payloadType: 1,
    );
    bool contains(int counter) => cache.containsSentBinding(
      hostId: hostId,
      counter: counter,
      entryId: 'entry-$counter',
      payloadType: 1,
    );

    test('matches only the exact binding and expires after the TTL', () {
      var now = DateTime(2024, 3, 15, 10);
      withClock(Clock(() => now), () {
        remember(1);
        expect(contains(1), isTrue);
        expect(
          cache.containsSentBinding(
            hostId: hostId,
            counter: 1,
            entryId: 'entry-1',
            payloadType: 2,
          ),
          isFalse,
          reason: 'a different payload type is a different binding',
        );

        now = now.add(
          SyncSequenceCache.sentBindingCacheTtl + const Duration(seconds: 1),
        );
        expect(contains(1), isFalse);
      });
    });

    test('evicts the least recently used binding past capacity; a lookup '
        'refreshes recency', () {
      withClock(Clock.fixed(DateTime(2024, 3, 15, 10)), () {
        const capacity = SyncSequenceCache.sentBindingCacheCapacity;
        for (var i = 0; i < capacity; i++) {
          remember(i);
        }
        // Touch the oldest so the second-oldest becomes the eviction victim.
        expect(contains(0), isTrue);

        remember(capacity);

        expect(contains(1), isFalse);
        expect(contains(0), isTrue);
        expect(contains(capacity), isTrue);
      });
    });
  });

  group('model-based properties', () {
    // One step: 0 touch/remember a small-pool key, 1 look it up, 2 advance
    // the clock by some minutes, 3 flood with fresh keys to force eviction.
    final step = glados.any.combine2(
      glados.any.intInRange(0, 4),
      glados.any.intInRange(0, 12),
      (int kind, int arg) => (kind: kind, arg: arg),
    );
    final start = DateTime(2024, 3, 15, 10);

    glados.Glados(
      glados.any.listWithLengthInRange(0, 30, step),
      glados.ExploreConfig(numRuns: 80),
    ).test(
      'a remembered binding is found within its TTL and capacity, not after',
      (steps) {
        const capacity = SyncSequenceCache.sentBindingCacheCapacity;
        const ttl = SyncSequenceCache.sentBindingCacheTtl;
        final cache = SyncSequenceCache(MockSyncDatabase());
        // Oldest first. Flood keys are always new, so only pool keys move.
        final order = ListQueue<String>();
        final recordedAt = <String, DateTime>{};
        var now = start;
        var fresh = 0;

        void remember(String entryId, {bool isNew = false}) {
          withClock(Clock.fixed(now), () {
            cache.rememberSentBinding(
              hostId: 'host-a',
              counter: 1,
              entryId: entryId,
              payloadType: 0,
            );
          });
          if (!isNew) order.remove(entryId);
          order.add(entryId);
          recordedAt[entryId] = now;
          while (order.length > capacity) {
            final evicted = order.removeFirst();
            recordedAt.remove(evicted);
            // The cache evicted the same binding the model did; a miss has
            // no side effect on recency.
            withClock(Clock.fixed(now), () {
              expect(
                cache.containsSentBinding(
                  hostId: 'host-a',
                  counter: 1,
                  entryId: evicted,
                  payloadType: 0,
                ),
                isFalse,
                reason: evicted,
              );
            });
          }
        }

        for (final s in steps) {
          final entryId = 'entry-${s.arg}';
          switch (s.kind) {
            case 0:
              remember(entryId);
            case 1:
              final at = recordedAt[entryId];
              final expected = at != null && now.difference(at) <= ttl;
              // A lookup drops an expired binding; one in force moves to the
              // most recent end.
              order.remove(entryId);
              if (expected) {
                order.add(entryId);
              } else {
                recordedAt.remove(entryId);
              }
              final found = withClock(
                Clock.fixed(now),
                () => cache.containsSentBinding(
                  hostId: 'host-a',
                  counter: 1,
                  entryId: entryId,
                  payloadType: 0,
                ),
              );
              expect(found, expected, reason: '$entryId at $now');
            case 2:
              now = now.add(Duration(minutes: s.arg));
            default:
              for (var i = 0; i < capacity ~/ 4 * s.arg ~/ 3; i++) {
                remember('flood-${fresh++}', isNew: true);
              }
          }
        }
      },
      tags: 'glados',
    );
  });
}
