import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/goals/logic/goal_checkin_compaction_strategy.dart';
import 'package:lotti/features/goals/model/goal_checkin_weight.dart';

import '../../../test_data/entity_factories.dart';
import 'support/goal_compaction_facts.dart';
import 'support/goal_compaction_fixtures.dart';
import 'support/goal_compaction_journal_fixtures.dart';

/// Offline self-test of the journaling fixtures: like the step goals', the
/// key must be a key to the history actually generated, and the status it
/// predicts the one production derives.
void main() {
  test('the catalog is the two journals, generated deterministically', () {
    expect(goalCompactionJournalFixtures.map((f) => f.id), [
      'journal_colony_move',
      'journal_night_shift',
    ]);
    final again = buildGoalCompactionJournalFixtures();
    for (final (index, fixture) in goalCompactionJournalFixtures.indexed) {
      expect(
        [for (final c in again[index].checkIns) (c.id, c.whatHappened)],
        [for (final c in fixture.checkIns) (c.id, c.whatHappened)],
      );
    }
  });

  for (final fixture in goalCompactionJournalFixtures) {
    group(fixture.id, () {
      test('is a journal: about eleven months, five evenings a week', () {
        final span = fixture.checkIns.last.recordedAt.difference(
          fixture.checkIns.first.recordedAt,
        );
        expect(span.inDays, inInclusiveRange(300, 340));
        // Five a week, give or take the needles and the partial weeks.
        expect(
          fixture.checkIns.length,
          inInclusiveRange(span.inDays * 4 ~/ 7, span.inDays * 6 ~/ 7),
        );
        expect(
          fixture.checkIns.last.recordedAt.isBefore(
            goalCompactionEvalReference,
          ),
          isTrue,
        );
        for (var i = 1; i < fixture.checkIns.length; i++) {
          expect(
            fixture.checkIns[i].recordedAt.isAfter(
              fixture.checkIns[i - 1].recordedAt,
            ),
            isTrue,
          );
        }
      });

      test('the full arm still fits a context window, and the shipped tail '
          'reaches back about a month', () async {
        final full = await const FullContextCheckInCompaction().build(
          fixture.checkIns,
          reference: goalCompactionEvalReference,
        );
        expect(full.estimatedTokens, lessThan(40000));
        final tail = await const TruncatingCheckInCompaction().build(
          fixture.checkIns,
          reference: goalCompactionEvalReference,
        );
        final wide = await const TruncatingCheckInCompaction(
          budget: 3600,
        ).build(fixture.checkIns, reference: goalCompactionEvalReference);
        // Five entries a week: the shipped tail reaches back about a month at
        // most, and the widest arm about three times as far. That gap is
        // what the budget arms measure.
        expect(tail.verbatimCount, inInclusiveRange(10, 26));
        expect(
          wide.verbatimCount,
          inInclusiveRange(tail.verbatimCount * 5 ~/ 2, tail.verbatimCount * 4),
        );
      });

      test('is a goal whose check-ins are its substance', () {
        expect(
          GoalCheckInWeight.of(
            makeTestGoalSpecVersion(criteria: fixture.criteria),
          ),
          GoalCheckInWeight.substance,
        );
      });

      test('the deterministic tier derives the predicted status as a '
          'transition, so every wake owes a report', () {
        final derivation = deriveGoalCompactionFacts(fixture);
        expect(derivation.status, fixture.truth.expectedStatus);
        expect(derivation.facts.previousStatus, fixture.transitionFrom);
        expect(derivation.facts.statusTransitioned, isTrue);
      });

      test('every dated probe is answered by a check-in on its date', () {
        for (final probe in fixture.truth.probes) {
          if (probe.isPattern) continue;
          final onDay = fixture.checkIns.where(
            (c) =>
                c.recordedAt.year == probe.factDate.year &&
                c.recordedAt.month == probe.factDate.month &&
                c.recordedAt.day == probe.factDate.day,
          );
          expect(onDay, hasLength(1), reason: probe.id);
        }
      });

      test('the probes span every age the layers lose things at', () {
        final ages = {
          for (final probe in fixture.truth.probes)
            probe.age(goalCompactionEvalReference),
        };
        expect(ages, GoalCompactionFactAge.values.toSet());
      });
    });
  }
}
