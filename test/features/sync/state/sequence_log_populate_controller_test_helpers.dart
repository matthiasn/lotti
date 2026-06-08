import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/state/sequence_log_populate_controller.dart';
import 'package:mocktail/mocktail.dart';


// Fake types for mocktail fallback
class FakeEntryStream extends Fake
    implements Stream<List<({String id, Map<String, int>? vectorClock})>> {}

enum GeneratedSequenceFailureTarget {
  none,
  journal,
  links,
  agentEntities,
  agentLinks,
}

const generatedPopulatePhases = <SequenceLogPopulatePhase>[
  SequenceLogPopulatePhase.populatingJournal,
  SequenceLogPopulatePhase.populatingLinks,
  SequenceLogPopulatePhase.populatingAgentEntities,
  SequenceLogPopulatePhase.populatingAgentLinks,
];

class GeneratedSequenceLogScenario {
  const GeneratedSequenceLogScenario({
    required this.counts,
    required this.progressSlots,
    required this.failureTarget,
  });

  final List<int> counts;
  final List<int> progressSlots;
  final GeneratedSequenceFailureTarget failureTarget;

  SequenceLogPopulatePhase? get failurePhase {
    switch (failureTarget) {
      case GeneratedSequenceFailureTarget.none:
        return null;
      case GeneratedSequenceFailureTarget.journal:
        return SequenceLogPopulatePhase.populatingJournal;
      case GeneratedSequenceFailureTarget.links:
        return SequenceLogPopulatePhase.populatingLinks;
      case GeneratedSequenceFailureTarget.agentEntities:
        return SequenceLogPopulatePhase.populatingAgentEntities;
      case GeneratedSequenceFailureTarget.agentLinks:
        return SequenceLogPopulatePhase.populatingAgentLinks;
    }
  }

  int countFor(SequenceLogPopulatePhase phase) => counts[phaseIndex(phase)];

  double progressFor(SequenceLogPopulatePhase phase) =>
      progressSlots[phaseIndex(phase)] / 100;

  double weightedProgressFor(SequenceLogPopulatePhase phase) {
    final index = phaseIndex(phase);
    return (index * 0.25) + (progressFor(phase) * 0.25);
  }

  List<SequenceLogPopulatePhase> get expectedCalls {
    final failure = failurePhase;
    if (failure == null) return generatedPopulatePhases;
    return generatedPopulatePhases.take(phaseIndex(failure) + 1).toList();
  }

  bool completed(SequenceLogPopulatePhase phase) {
    final failure = failurePhase;
    if (failure == null) return true;
    return phaseIndex(phase) < phaseIndex(failure);
  }

  int phaseIndex(SequenceLogPopulatePhase phase) {
    switch (phase) {
      case SequenceLogPopulatePhase.populatingJournal:
        return 0;
      case SequenceLogPopulatePhase.populatingLinks:
        return 1;
      case SequenceLogPopulatePhase.populatingAgentEntities:
        return 2;
      case SequenceLogPopulatePhase.populatingAgentLinks:
        return 3;
      case SequenceLogPopulatePhase.idle:
      case SequenceLogPopulatePhase.done:
        throw ArgumentError.value(phase, 'phase', 'not a populate phase');
    }
  }

  @override
  String toString() {
    return 'GeneratedSequenceLogScenario('
        'counts: $counts, '
        'progressSlots: $progressSlots, '
        'failureTarget: $failureTarget'
        ')';
  }
}

extension AnyGeneratedSequenceLogScenario on glados.Any {
  glados.Generator<GeneratedSequenceFailureTarget> get sequenceFailureTarget =>
      glados.AnyUtils(this).choose(GeneratedSequenceFailureTarget.values);

  glados.Generator<GeneratedSequenceLogScenario> get sequenceLogScenario =>
      glados.CombinableAny(this).combine3(
        glados.ListAnys(this).listWithLengthInRange(
          generatedPopulatePhases.length,
          generatedPopulatePhases.length,
          glados.IntAnys(this).intInRange(0, 21),
        ),
        glados.ListAnys(this).listWithLengthInRange(
          generatedPopulatePhases.length,
          generatedPopulatePhases.length,
          glados.IntAnys(this).intInRange(0, 101),
        ),
        sequenceFailureTarget,
        (
          List<int> counts,
          List<int> progressSlots,
          GeneratedSequenceFailureTarget failureTarget,
        ) => GeneratedSequenceLogScenario(
          counts: counts,
          progressSlots: progressSlots,
          failureTarget: failureTarget,
        ),
      );
}
