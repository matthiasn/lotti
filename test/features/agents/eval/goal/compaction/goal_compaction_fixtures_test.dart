import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/features/goals/logic/goal_checkin_compaction_strategy.dart';
import 'package:lotti/features/goals/logic/goal_user_voice.dart';

import 'support/goal_compaction_facts.dart';
import 'support/goal_compaction_fixtures.dart';

/// Offline self-test of the compaction fixtures: the answer key must be a
/// key to the history that is actually generated, and the status it
/// predicts must be the one production derives.
void main() {
  test('catalog covers the five archetypes exactly once', () {
    expect(goalCompactionFixtures.map((f) => f.id), [
      'steady_then_stall',
      'regress_recover',
      'redefined',
      'abandoned_revived',
      'completed',
    ]);
  });

  test('generation is deterministic — a re-run reads the same history', () {
    final again = buildGoalCompactionFixtures();
    for (final (index, fixture) in goalCompactionFixtures.indexed) {
      final other = again[index];
      expect(other.checkIns.length, fixture.checkIns.length);
      for (final (i, checkIn) in fixture.checkIns.indexed) {
        expect(other.checkIns[i].id, checkIn.id);
        expect(other.checkIns[i].recordedAt, checkIn.recordedAt);
        expect(other.checkIns[i].whatHappened, checkIn.whatHappened);
        expect(other.checkIns[i].committedTo, checkIn.committedTo);
      }
    }
  });

  for (final fixture in goalCompactionFixtures) {
    group(fixture.id, () {
      test('is a long-running goal: many check-ins over about two years', () {
        expect(fixture.checkIns.length, greaterThanOrEqualTo(120));
        final span = fixture.checkIns.last.recordedAt.difference(
          fixture.checkIns.first.recordedAt,
        );
        expect(span.inDays, greaterThan(600));
        expect(
          fixture.checkIns.last.recordedAt.isBefore(
            goalCompactionEvalReference,
          ),
          isTrue,
        );
      });

      test('check-ins are chronological with unique ids and one per day', () {
        final ids = fixture.checkIns.map((c) => c.id).toSet();
        expect(ids.length, fixture.checkIns.length);
        for (var i = 1; i < fixture.checkIns.length; i++) {
          expect(
            fixture.checkIns[i].recordedAt.isAfter(
              fixture.checkIns[i - 1].recordedAt,
            ),
            isTrue,
          );
        }
      });

      test('every check-in has something to say', () {
        for (final checkIn in fixture.checkIns) {
          expect(checkIn.whatHappened.trim(), isNotEmpty);
          expect(checkIn.whatHappened, isNot(contains('{steps}')));
          expect(checkIn.committedTo ?? '', isNot(contains('{steps}')));
        }
      });

      test('the deterministic tier derives the status the key predicts', () {
        final derivation = deriveGoalCompactionFacts(fixture);
        expect(derivation.status, fixture.truth.expectedStatus);
        expect(derivation.facts.evaluation.dataCoverage, greaterThan(0.5));
        // A same-status wake is a no-op by contract; every eval wake must
        // owe a report.
        expect(derivation.facts.previousStatus, fixture.transitionFrom);
        expect(fixture.transitionFrom, isNot(fixture.truth.expectedStatus));
        expect(derivation.facts.statusTransitioned, isTrue);
      });

      test('every probe points at a check-in that exists', () {
        for (final probe in fixture.truth.probes) {
          final near = fixture.checkIns.where(
            (c) => c.recordedAt.difference(probe.factDate).inDays.abs() <= 7,
          );
          expect(
            near,
            isNotEmpty,
            reason: '${probe.id} has no check-in within a week of its fact',
          );
          expect(probe.referenceAnswer.trim(), isNotEmpty);
        }
      });

      test('probes span every age stratum', () {
        final ages = fixture.truth.probes
            .map((p) => p.age(goalCompactionEvalReference))
            .toSet();
        expect(ages, containsAll(GoalCompactionFactAge.values));
      });

      test('needle facts are recorded on their dates, not just templated', () {
        // A needle is the one check-in on its day, so any probe whose fact
        // date has a check-in that day should find its own words there.
        final byDay = {
          for (final c in fixture.checkIns)
            c.recordedAt.toIso8601String().substring(0, 10): c,
        };
        final needleProbes = fixture.truth.probes.where((p) => !p.isPattern);
        expect(needleProbes, isNotEmpty);
        for (final probe in needleProbes) {
          final checkIn =
              byDay[probe.factDate.toIso8601String().substring(0, 10)];
          expect(checkIn, isNotNull, reason: '${probe.id} has no needle');
          // Needles are hand-written and long; templates are one line.
          expect(
            checkIn!.whatHappened.length,
            greaterThan(90),
            reason: '${probe.id}: ${checkIn.whatHappened}',
          );
        }
      });

      test('the shipped truncation drops all but the newest check-ins', () {
        final kept = goalUserVoiceEntries(fixture.checkIns);
        // Realistically sized summaries: the 1,200-token slice holds about
        // three months of a two-year history.
        expect(kept.length, lessThan(fixture.checkIns.length ~/ 4));
        final oldestKept = DateTime.parse(
          kept.first['recordedAtLocal']! as String,
        );
        expect(
          goalCompactionEvalReference.difference(oldestKept).inDays,
          lessThan(150),
        );
        expect(
          kept.last['sourceEntryId'],
          fixture.checkIns.last.sourceEntryId,
        );
        // Which is the whole problem: every old-stratum probe fact is gone.
        final keptIds = kept.map((e) => e['sourceEntryId']).toSet();
        for (final probe in fixture.truth.probes) {
          if (probe.age(goalCompactionEvalReference) !=
              GoalCompactionFactAge.old) {
            continue;
          }
          final carriers = fixture.checkIns.where(
            (c) => c.recordedAt.difference(probe.factDate).inDays.abs() <= 7,
          );
          expect(
            carriers.any((c) => keptIds.contains(c.sourceEntryId)),
            isFalse,
            reason: '${probe.id} should be beyond the truncation slice',
          );
        }
      });

      test('growth-curve horizons are nested prefixes of the history', () {
        var previous = 0;
        for (final months in const [3, 6, 12, 18, 24]) {
          final prefix = fixture.upTo(months);
          expect(prefix.length, greaterThanOrEqualTo(previous));
          expect(prefix, fixture.checkIns.sublist(0, prefix.length));
          previous = prefix.length;
        }
        expect(fixture.upTo(24).length, greaterThan(fixture.upTo(12).length));
      });

      test('renders through the production FACTS renderer', () async {
        final derivation = deriveGoalCompactionFacts(fixture);
        final voice = await const FullContextCheckInCompaction().build(
          fixture.checkIns,
          reference: goalCompactionEvalReference,
        );
        final facts = renderGoalCompactionFacts(
          fixture,
          derivation,
          userVoice: voice.entries,
        );
        expect(
          facts,
          contains('"trackStatus": "${fixture.truth.expectedStatus.name}"'),
        );
        expect(facts, contains('"userVoice"'));
        expect(facts, contains(fixture.checkIns.first.whatHappened));
        expect(facts, contains(fixture.checkIns.last.whatHappened));
        expect(facts, contains(fixture.statement));
        expect(facts, contains('"materialChangeSinceLastReport": true'));
        expect(facts, contains(goalCompactionEvalUserMessage));
      });
    });
  }

  test('the abandoned goal has a five-month silence and nothing else does', () {
    String month(DateTime d) => d.toIso8601String().substring(0, 7);
    for (final fixture in goalCompactionFixtures) {
      final months = fixture.checkIns.map((c) => month(c.recordedAt)).toSet();
      final silent = [
        for (var m = 0; m < 24; m++)
          if (!months.contains(
            month(
              DateTime.utc(fixture.startDate.year, fixture.startDate.month + m),
            ),
          ))
            month(
              DateTime.utc(fixture.startDate.year, fixture.startDate.month + m),
            ),
      ];
      if (fixture.id == 'abandoned_revived') {
        expect(silent, ['2025-07', '2025-08', '2025-09', '2025-10', '2025-11']);
      } else {
        expect(silent, isEmpty, reason: fixture.id);
      }
    }
  });

  test('statuses are the non-trivial spread the evaluation needs', () {
    expect(
      goalCompactionFixtures.map((f) => f.truth.expectedStatus).toSet(),
      {
        GoalTrackStatus.offTrack,
        GoalTrackStatus.onTrack,
        GoalTrackStatus.atRisk,
        GoalTrackStatus.achieved,
      },
    );
  });
}
