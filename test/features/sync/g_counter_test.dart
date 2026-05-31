import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/g_counter.dart';

/// Number of distinct hosts the generators draw from — small enough that hosts
/// collide (exercising within-host max) yet varied enough to exercise the join.
const _hostCount = 4;

extension _AnyGCounter on glados.Any {
  /// An arbitrary G-counter over hosts `h0..h{n-1}` with small counts.
  glados.Generator<GCounter> get gCounter => glados.ListAnys(this)
      .listWithLengthInRange(
        0,
        6,
        glados.CombinableAny(this).combine2(
          glados.IntAnys(this).intInRange(0, _hostCount),
          glados.IntAnys(this).intInRange(0, 30),
          (int host, int count) => MapEntry('h$host', count),
        ),
      )
      .map((entries) {
        final byHost = <String, int>{};
        for (final entry in entries) {
          byHost[entry.key] = (byHost[entry.key] ?? 0) + entry.value;
        }
        return GCounter(byHost);
      });

  /// A list of replica indices (`0..{_hostCount-1}`) — one entry per increment,
  /// naming which replica made it. Models N increments spread across devices.
  glados.Generator<List<int>> get incrementPlan =>
      glados.ListAnys(
        this,
      ).listWithLengthInRange(
        0,
        25,
        glados.IntAnys(this).intInRange(0, _hostCount),
      );

  glados.Generator<int> get shuffleSeed =>
      glados.IntAnys(this).intInRange(0, 1 << 30);
}

void main() {
  group('GCounter', () {
    test('empty counter has value 0', () {
      expect(const GCounter.empty().value, 0);
      expect(const GCounter.empty().byHost, isEmpty);
    });

    test(
      'increment bumps only the named host and raises value by the delta',
      () {
        final counter = const GCounter.empty()
            .increment('a')
            .increment('a')
            .increment('b', 3);

        expect(counter.byHost, {'a': 2, 'b': 3});
        expect(counter.value, 5);
      },
    );

    test('merge of disjoint hosts sums; shared hosts take the max', () {
      const a = GCounter({'h0': 5, 'h1': 2});
      const b = GCounter({'h1': 7, 'h2': 1});

      expect(a.merge(b).byHost, {'h0': 5, 'h1': 7, 'h2': 1});
      expect(a.merge(b).value, 13); // 5 + max(2,7) + 1
    });
  });

  group('GCounter — algebraic laws (CRDT join)', () {
    glados.Glados2(
      glados.any.gCounter,
      glados.any.gCounter,
      glados.ExploreConfig(numRuns: 200),
    ).test('merge is commutative', (a, b) {
      expect(a.merge(b), b.merge(a), reason: '$a vs $b');
    }, tags: 'glados');

    glados.Glados3(
      glados.any.gCounter,
      glados.any.gCounter,
      glados.any.gCounter,
      glados.ExploreConfig(numRuns: 200),
    ).test('merge is associative', (a, b, c) {
      expect(a.merge(b).merge(c), a.merge(b.merge(c)), reason: '$a $b $c');
    }, tags: 'glados');

    glados.Glados(
      glados.any.gCounter,
      glados.ExploreConfig(numRuns: 200),
    ).test('merge is idempotent', (a) {
      expect(a.merge(a), a, reason: '$a');
    }, tags: 'glados');

    glados.Glados2(
      glados.any.gCounter,
      glados.any.gCounter,
      glados.ExploreConfig(numRuns: 200),
    ).test('merge is a least-upper-bound — never below either input', (a, b) {
      final merged = a.merge(b);
      // Dominates per-host (the lattice order) ...
      for (final host in {...a.byHost.keys, ...b.byHost.keys}) {
        expect(
          merged.byHost[host] ?? 0,
          max(a.byHost[host] ?? 0, b.byHost[host] ?? 0),
          reason: 'host $host: $a ⊔ $b',
        );
      }
      // ... and therefore the value is at least either side's.
      expect(merged.value, greaterThanOrEqualTo(a.value));
      expect(merged.value, greaterThanOrEqualTo(b.value));
    }, tags: 'glados');

    glados.Glados(
      glados.any.gCounter,
      glados.ExploreConfig(numRuns: 200),
    ).test('value equals the sum of per-host counts', (a) {
      expect(a.value, a.byHost.values.fold<int>(0, (s, c) => s + c));
    }, tags: 'glados');

    glados.Glados(
      glados.any.gCounter,
      glados.ExploreConfig(numRuns: 200),
    ).test('JSON round-trips by value', (a) {
      expect(GCounter.fromJson(a.toJson()), a, reason: '$a');
    }, tags: 'glados');
  });

  group('GCounter — convergence (no lost increments)', () {
    glados.Glados2(
      glados.any.incrementPlan,
      glados.any.shuffleSeed,
      glados.ExploreConfig(numRuns: 250),
    ).test(
      'N per-host increments across replicas converge to exactly N, in any '
      'merge order',
      (plan, seed) {
        // Each replica increments ONLY its own host (the real-world invariant),
        // so increments are disjoint across hosts and none can be lost.
        final replicas = <GCounter>[];
        for (var replica = 0; replica < _hostCount; replica++) {
          final n = plan.where((r) => r == replica).length;
          var counter = const GCounter.empty();
          for (var i = 0; i < n; i++) {
            counter = counter.increment('h$replica');
          }
          replicas.add(counter);
        }

        GCounter foldMerge(List<GCounter> cs) =>
            cs.fold(const GCounter.empty(), (acc, c) => acc.merge(c));

        // Merge in build order and in a shuffled order — both must equal the
        // total number of increments (the convergence guarantee).
        final inOrder = foldMerge(replicas);
        final shuffled = foldMerge([...replicas]..shuffle(Random(seed)));

        expect(inOrder.value, plan.length, reason: 'plan=$plan');
        expect(shuffled, inOrder, reason: 'seed=$seed plan=$plan');
      },
      tags: 'glados',
    );
  });
}
