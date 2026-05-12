import 'package:glados/glados.dart';
import 'package:lotti/features/sync/matrix/journal_entity_dedup_cache.dart';
import 'package:lotti/features/sync/vector_clock.dart';

extension _AnyDedup on Any {
  /// Random VectorClock over a small fixed key alphabet so collisions and
  /// repeats are likely — exercises the dedup paths instead of always
  /// producing fresh clocks.
  Generator<VectorClock> get dedupVc => any.combine4(
    any.intInRange(0, 8),
    any.intInRange(0, 8),
    any.intInRange(0, 8),
    any.intInRange(0, 8),
    (int a, int b, int c, int d) => VectorClock({
      'h1': a,
      'h2': b,
      'h3': c,
      'h4': d,
    }),
  );

  /// Entry id drawn from a small alphabet so the same id recurs across the
  /// generated sequence — required to actually exercise dedup hits.
  Generator<String> get dedupEntryId =>
      any.intInRange(0, 32).map((int n) => 'entry-$n');

  Generator<(String, VectorClock)> get dedupPair => any.combine2(
    any.dedupEntryId,
    any.dedupVc,
    (
      String id,
      VectorClock vc,
    ) => (id, vc),
  );
}

void main() {
  group('JournalEntityDedupCache - example-based', () {
    test('null vector clock is never a duplicate', () {
      final cache = JournalEntityDedupCache();
      expect(cache.isDuplicate('e1', null), isFalse);
      cache.markProcessed('e1', null);
      expect(cache.size, 0);
      expect(cache.isDuplicate('e1', null), isFalse);
    });

    test('mark then check returns true for same pair', () {
      final cache = JournalEntityDedupCache();
      const vc = VectorClock({'h': 1});
      cache.markProcessed('e1', vc);
      expect(cache.isDuplicate('e1', vc), isTrue);
    });

    test('same id with different vc is not a duplicate', () {
      final cache = JournalEntityDedupCache()
        ..markProcessed('e1', const VectorClock({'h': 1}));
      expect(cache.isDuplicate('e1', const VectorClock({'h': 2})), isFalse);
    });

    test('fresh pair is not a duplicate', () {
      final cache = JournalEntityDedupCache();
      expect(cache.isDuplicate('e1', const VectorClock({'h': 1})), isFalse);
    });

    test('capacity defaults to 500', () {
      expect(JournalEntityDedupCache().capacity, 500);
    });

    test('rejects non-positive capacity', () {
      expect(() => JournalEntityDedupCache(capacity: 0), throwsA(isA<Error>()));
      expect(
        () => JournalEntityDedupCache(capacity: -1),
        throwsA(isA<Error>()),
      );
    });
  });

  group('JournalEntityDedupCache.fingerprintOf', () {
    Glados2<int, int>(
      any.intInRange(0, 100),
      any.intInRange(0, 100),
    ).test('is insertion-order independent for equal maps', (int a, int b) {
      final fp1 = JournalEntityDedupCache.fingerprintOf(
        VectorClock({'x': a, 'y': b}),
      );
      final fp2 = JournalEntityDedupCache.fingerprintOf(
        VectorClock({'y': b, 'x': a}),
      );
      expect(fp1, equals(fp2));
    }, tags: 'glados');

    Glados2<int, int>(
      any.intInRange(0, 100),
      any.intInRange(0, 100),
    ).test('distinguishes clocks that differ at any node', (int a, int b) {
      // Skip the degenerate equal case — the property is about *different*
      // clocks producing different fingerprints.
      if (a == b) return;
      final fp1 = JournalEntityDedupCache.fingerprintOf(
        VectorClock({'h': a}),
      );
      final fp2 = JournalEntityDedupCache.fingerprintOf(
        VectorClock({'h': b}),
      );
      expect(fp1, isNot(equals(fp2)));
    }, tags: 'glados');
  });

  group('JournalEntityDedupCache - LRU invariants (Glados)', () {
    Glados<List<(String, VectorClock)>>(
      any.list(any.dedupPair),
      ExploreConfig(numRuns: 120),
    ).test('size never exceeds capacity', (List<(String, VectorClock)> ops) {
      final cache = JournalEntityDedupCache(capacity: 8);
      for (final (id, vc) in ops) {
        cache.markProcessed(id, vc);
        expect(
          cache.size,
          lessThanOrEqualTo(cache.capacity),
          reason: 'capacity breached after marking ($id, ${vc.vclock})',
        );
      }
    }, tags: 'glados');

    Glados<List<(String, VectorClock)>>(
      any.list(any.dedupPair),
      ExploreConfig(numRuns: 120),
    ).test('every marked pair is a duplicate immediately after marking', (
      List<(String, VectorClock)> ops,
    ) {
      final cache = JournalEntityDedupCache(capacity: 32);
      for (final (id, vc) in ops) {
        cache.markProcessed(id, vc);
        expect(
          cache.isDuplicate(id, vc),
          isTrue,
          reason: 'just-marked pair ($id, ${vc.vclock}) reported as fresh',
        );
      }
    }, tags: 'glados');

    Glados<List<(String, VectorClock)>>(
      any.list(any.dedupPair),
      ExploreConfig(numRuns: 120),
    ).test(
      'after capacity overflow, only the most recent capacity unique ids remain',
      (List<(String, VectorClock)> ops) {
        const capacity = 4;
        final cache = JournalEntityDedupCache(capacity: capacity);
        // Track the LRU order of *unique* ids using insertion-order semantics:
        // each mark moves its id to MRU, evictions drop the LRU id.
        final expectedOrder = <String>[];
        for (final (id, vc) in ops) {
          expectedOrder
            ..remove(id)
            ..add(id);
          if (expectedOrder.length > capacity) {
            expectedOrder.removeAt(0);
          }
          cache.markProcessed(id, vc);
        }
        expect(cache.orderedKeys, equals(expectedOrder));
      },
      tags: 'glados',
    );

    Glados<List<(String, VectorClock)>>(
      any.list(any.dedupPair),
      ExploreConfig(numRuns: 120),
    ).test('isDuplicate hit moves entry to MRU position', (
      List<(String, VectorClock)> ops,
    ) {
      if (ops.isEmpty) return;
      final cache = JournalEntityDedupCache(capacity: 16);
      for (final (id, vc) in ops) {
        cache.markProcessed(id, vc);
      }
      // Pick the first marked pair (oldest survivor, if any). Confirm a
      // duplicate hit promotes it to MRU.
      final (firstId, firstVc) = ops.first;
      if (!cache.isDuplicate(firstId, firstVc)) return; // evicted, skip
      expect(cache.orderedKeys.last, equals(firstId));
    }, tags: 'glados');
  });
}
