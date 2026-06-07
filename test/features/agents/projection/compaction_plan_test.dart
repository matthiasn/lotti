import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/projection/compaction_plan.dart';

extension _AnyCompaction on glados.Any {
  /// 0..10 per-entry token costs in `[0, 50)`.
  glados.Generator<List<int>> get tokenCosts => glados.ListAnys(
    this,
  ).listWithLengthInRange(0, 10, glados.IntAnys(this).intInRange(0, 50));

  /// A token budget in `[0, 120)`.
  glados.Generator<int> get budget => glados.IntAnys(this).intInRange(0, 120);
}

List<TailEntry> _tail(List<int> tokens) => [
  for (var i = 0; i < tokens.length; i++)
    TailEntry(id: 'e$i', tokens: tokens[i]),
];

int _sumKept(List<TailEntry> tail, CompactionPlan plan) => tail
    .where((e) => plan.keepIds.contains(e.id))
    .fold(0, (sum, e) => sum + e.tokens);

void main() {
  group('planCompaction', () {
    // ── generative properties ────────────────────────────────────────────────

    glados.Glados2(
      glados.any.tokenCosts,
      glados.any.budget,
      glados.ExploreConfig(numRuns: 200),
    ).test('fold prefix ++ keep suffix is exactly the tail, in order', (
      tokens,
      budget,
    ) {
      final tail = _tail(tokens);
      final plan = planCompaction(tail: tail, budget: budget);
      expect([
        ...plan.foldIds,
        ...plan.keepIds,
      ], tail.map((e) => e.id).toList());
    }, tags: 'glados');

    glados.Glados2(
      glados.any.tokenCosts,
      glados.any.budget,
      glados.ExploreConfig(numRuns: 200),
    ).test('the kept suffix fits the budget once it holds 2+ entries', (
      tokens,
      budget,
    ) {
      final tail = _tail(tokens);
      final plan = planCompaction(tail: tail, budget: budget);
      if (plan.keepIds.length >= 2) {
        expect(_sumKept(tail, plan), lessThanOrEqualTo(budget));
      }
    }, tags: 'glados');

    glados.Glados2(
      glados.any.tokenCosts,
      glados.any.budget,
      glados.ExploreConfig(numRuns: 200),
    ).test('a tail within budget is never folded', (tokens, budget) {
      final tail = _tail(tokens);
      final plan = planCompaction(tail: tail, budget: budget);
      if (tokens.fold<int>(0, (s, t) => s + t) <= budget) {
        expect(plan.foldIds, isEmpty);
      }
    }, tags: 'glados');

    glados.Glados2(
      glados.any.tokenCosts,
      glados.any.budget,
      glados.ExploreConfig(numRuns: 200),
    ).test(
      'keeps at least the most-recent entry when the tail is non-empty',
      (
        tokens,
        budget,
      ) {
        final tail = _tail(tokens);
        final plan = planCompaction(tail: tail, budget: budget);
        if (tail.isNotEmpty) {
          expect(plan.keepIds, isNotEmpty);
          expect(plan.keepIds.last, tail.last.id); // suffix ends at the newest
        }
      },
      tags: 'glados',
    );

    glados.Glados3(
      glados.any.tokenCosts,
      glados.any.budget,
      glados.any.budget,
      glados.ExploreConfig(numRuns: 200),
    ).test('a larger budget never folds more (monotonic)', (
      tokens,
      budgetA,
      budgetB,
    ) {
      final tail = _tail(tokens);
      final small = budgetA < budgetB ? budgetA : budgetB;
      final large = budgetA < budgetB ? budgetB : budgetA;
      final foldSmall = planCompaction(
        tail: tail,
        budget: small,
      ).foldIds.length;
      final foldLarge = planCompaction(
        tail: tail,
        budget: large,
      ).foldIds.length;
      expect(foldLarge, lessThanOrEqualTo(foldSmall));
    }, tags: 'glados');

    // ── examples ─────────────────────────────────────────────────────────────

    test('rejects a negative token estimate', () {
      expect(
        () => planCompaction(tail: _tail([5, -1]), budget: 10),
        throwsArgumentError,
      );
    });

    test('empty tail yields an empty plan', () {
      final plan = planCompaction(tail: const [], budget: 100);
      expect(plan.shouldCompact, isFalse);
      expect(plan.keepIds, isEmpty);
    });

    test('a tail under budget keeps everything', () {
      final plan = planCompaction(
        tail: _tail([10, 20, 30]),
        budget: 100,
      );
      expect(plan.shouldCompact, isFalse);
      expect(plan.keepIds, ['e0', 'e1', 'e2']);
    });

    test('folds the oldest entries until the recent suffix fits', () {
      // budget 50 keeps the most-recent entries summing <= 50: e3(30)+e2(15)=45.
      final plan = planCompaction(
        tail: _tail([40, 40, 15, 30]),
        budget: 50,
      );
      expect(plan.foldIds, ['e0', 'e1']);
      expect(plan.keepIds, ['e2', 'e3']);
    });

    test('keeps a single most-recent entry even if it exceeds the budget', () {
      final plan = planCompaction(
        tail: _tail([10, 999]),
        budget: 50,
      );
      expect(plan.foldIds, ['e0']);
      expect(plan.keepIds, ['e1']);
    });

    test('value equality follows fields (TailEntry, CompactionPlan)', () {
      // Built from runtime args (not const literals) so Equatable compares
      // props rather than short-circuiting on identity.
      TailEntry entry(String id, int tokens) =>
          TailEntry(id: id, tokens: tokens);
      expect(entry('e1', 3), entry('e1', 3));
      expect(entry('e1', 3), isNot(entry('e1', 4)));

      final tail = _tail([40, 40, 15, 30]);
      expect(
        planCompaction(tail: tail, budget: 50),
        planCompaction(tail: tail, budget: 50),
      );
      expect(
        planCompaction(tail: tail, budget: 50),
        isNot(planCompaction(tail: tail, budget: 200)),
      );
    });
  });
}
