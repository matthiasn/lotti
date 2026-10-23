import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';

import 'support/front_agent_routing_scenarios.dart';

/// Fixture honesty: a scenario that expects an id the index does not list,
/// or that asks for a lookup budget the contract cannot grant, would score
/// every model wrong for the harness's mistake rather than the model's.
void main() {
  test('every expected and candidate id is listed in the index', () {
    for (final scenario in frontEvalScenarios) {
      for (final segment in scenario.expectedSegments) {
        if (segment.id case final id?) {
          expect(
            frontEvalIndex.contains(segment.kind, id),
            isTrue,
            reason: '${scenario.id}: ${segment.kind.wireName}:$id',
          );
        } else {
          expect(segment.kind.needsId, isFalse, reason: scenario.id);
        }
      }
      for (final id in scenario.askCandidates) {
        expect(
          frontEvalIndex.rows.any((row) => row.id == id),
          isTrue,
          reason: '${scenario.id}: candidate $id',
        );
      }
    }
  });

  test('scenario ids are unique and every scenario says why it exists', () {
    final ids = frontEvalScenarios.map((s) => s.id).toSet();
    expect(ids, hasLength(frontEvalScenarios.length));
    expect(frontEvalScenarios.every((s) => s.note.isNotEmpty), isTrue);
  });

  test('an ask scenario names at least two candidates; a dispatch scenario '
      'names at least one segment', () {
    for (final scenario in frontEvalScenarios) {
      switch (scenario.outcome) {
        case FrontEvalOutcome.ask:
          expect(
            scenario.askCandidates.length,
            greaterThan(1),
            reason: scenario.id,
          );
        case FrontEvalOutcome.dispatch:
          expect(scenario.expectedSegments, isNotEmpty, reason: scenario.id);
        case FrontEvalOutcome.reply:
          expect(scenario.expectedSegments, isEmpty, reason: scenario.id);
      }
    }
  });

  test('the closed sensor task is not a destination anywhere', () {
    expect(
      frontEvalIndex.rows.any((row) => row.title.contains('sensor')),
      isFalse,
    );
  });

  test('the near-candidate pair really is a pair on the same words', () {
    final bayC = frontEvalIndex.tasks.where((t) => t.title.contains('Bay C'));
    expect(bayC.map((t) => t.id), {'task-bay-c-seam', 'task-bay-c-lighting'});
    expect(
      frontEvalScenarios
          .firstWhere((s) => s.id == 'two_near_candidates')
          .askCandidates,
      bayC.map((t) => t.id).toSet(),
    );
  });

  test('no lookup budget exceeds what the contract allows', () {
    for (final scenario in frontEvalScenarios) {
      expect(scenario.maxLookups, inInclusiveRange(0, 2), reason: scenario.id);
    }
  });

  test('"new" expectations never carry an id', () {
    final newSegments = frontEvalScenarios
        .expand((s) => s.expectedSegments)
        .where((seg) => seg.kind == FrontDestinationKind.newThing);
    expect(newSegments, isNotEmpty);
    expect(newSegments.every((seg) => seg.id == null), isTrue);
  });
}
