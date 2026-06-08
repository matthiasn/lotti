import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/projection/content_digest.dart';
import 'package:lotti/features/agents/projection/join_plan.dart';

import 'capture_test_fixtures.dart';

extension _AnyJoin on glados.Any {
  /// 0..6 head ids drawn from a small pool, so duplicates and reorderings of
  /// the *same* logical head set arise naturally — exercising the sort+dedup
  /// the join id relies on.
  glados.Generator<List<String>> get headIds =>
      glados.ListAnys(this).listWithLengthInRange(
        0,
        6,
        glados.AnyUtils(this).choose(<String>['h1', 'h2', 'h3', 'h4', 'h5']),
      );
}

Set<String> _unique(List<String> ids) => ids.toSet();

void main() {
  group('computeJoinId', () {
    // ── generative properties ────────────────────────────────────────────────

    glados.Glados2(
      glados.any.headIds,
      glados.any.shuffleSeed,
      glados.ExploreConfig(numRuns: 180),
    ).test('depends only on the head set, not order or duplicates', (
      heads,
      seed,
    ) {
      final reordered = shuffledBySeed(heads, seed);
      expect(computeJoinId(heads), computeJoinId(reordered));
      // Duplicating every head changes neither the set nor the id.
      expect(computeJoinId(heads), computeJoinId([...heads, ...heads]));
    }, tags: 'glados');

    glados.Glados(
      glados.any.headIds,
      glados.ExploreConfig(numRuns: 180),
    ).test('is domain-tagged and versioned (cannot collide with a frontier '
        'digest over the same ids)', (heads) {
      final sorted = _unique(heads).toList()..sort();
      // The `join-v1` tag is inside the hashed content, so the join id differs
      // from both an untagged digest and a differently-tagged one over the
      // identical id set — it can never be confused with another
      // content-addressed digest kind.
      expect(
        computeJoinId(heads),
        isNot(ContentDigest.of({'parents': sorted})),
      );
      expect(
        computeJoinId(heads),
        isNot(ContentDigest.of({'_tag': 'frontier-v1', 'parents': sorted})),
      );
      expect(computeJoinId(heads), startsWith('${ContentDigest.version}:'));
    }, tags: 'glados');
  });

  group('planJoin', () {
    // ── generative properties ────────────────────────────────────────────────

    glados.Glados(
      glados.any.headIds,
      glados.ExploreConfig(numRuns: 180),
    ).test('emits iff there are ≥2 heads and the view is complete', (heads) {
      final plan = planJoin(headIds: heads, viewComplete: true);
      if (_unique(heads).length >= 2) {
        expect(plan, isNotNull);
        // Heals exactly the (sorted, de-duplicated) head set, and its id is the
        // content digest over precisely those parents.
        expect(plan!.parentIds, _unique(heads).toList()..sort());
        expect(plan.joinId, computeJoinId(heads));
        expect(computeJoinId(plan.parentIds), plan.joinId);
      } else {
        expect(plan, isNull);
      }
    }, tags: 'glados');

    glados.Glados(
      glados.any.headIds,
      glados.ExploreConfig(numRuns: 180),
    ).test('never emits while the local view is incomplete', (heads) {
      // Even with ≥2 heads, a dangling-parent (unsettled) view defers — healing
      // on it could mint a join over a non-tip.
      expect(planJoin(headIds: heads, viewComplete: false), isNull);
    }, tags: 'glados');

    glados.Glados2(
      glados.any.headIds,
      glados.any.shuffleSeed,
      glados.ExploreConfig(numRuns: 180),
    ).test('the plan depends only on the head set, not arrival order', (
      heads,
      seed,
    ) {
      expect(
        planJoin(headIds: heads, viewComplete: true),
        planJoin(headIds: shuffledBySeed(heads, seed), viewComplete: true),
      );
    }, tags: 'glados');

    // ── examples ─────────────────────────────────────────────────────────────

    test('heals a two-head fork observed at wake start', () {
      final plan = planJoin(headIds: ['h2', 'h1'], viewComplete: true);
      expect(plan, isNotNull);
      expect(plan!.parentIds, ['h1', 'h2']); // sorted
      expect(plan.joinId, computeJoinId(['h1', 'h2']));
    });

    test('defers while a parent edge has not synced yet (incomplete view)', () {
      expect(planJoin(headIds: ['h1', 'h2'], viewComplete: false), isNull);
    });

    test('does not heal a single head', () {
      expect(planJoin(headIds: ['h1'], viewComplete: true), isNull);
    });

    test('does not heal an empty head set', () {
      expect(planJoin(headIds: const [], viewComplete: true), isNull);
    });

    test('duplicate ids collapse to one head and do not heal', () {
      expect(planJoin(headIds: ['h1', 'h1'], viewComplete: true), isNull);
    });

    test('JoinPlan value equality follows its fields', () {
      JoinPlan make(List<String> heads) =>
          planJoin(headIds: heads, viewComplete: true)!;
      expect(make(['h1', 'h2']), make(['h2', 'h1'])); // order-independent
      expect(make(['h1', 'h2']), isNot(make(['h1', 'h3'])));
    });
  });
}
