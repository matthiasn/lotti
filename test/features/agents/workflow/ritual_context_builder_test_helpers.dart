import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/classified_feedback.dart';
import 'package:lotti/features/agents/workflow/ritual_context_builder.dart';

import '../test_utils.dart';

class GeneratedRitualFeedbackScenario {
  const GeneratedRitualFeedbackScenario({
    required this.criticalNegativeCount,
    required this.criticalPositiveCount,
    required this.nonCriticalCount,
    required this.nonCriticalSentiment,
  });

  final int criticalNegativeCount;
  final int criticalPositiveCount;
  final int nonCriticalCount;
  final FeedbackSentiment nonCriticalSentiment;

  int get highPriorityCount => criticalNegativeCount + criticalPositiveCount;

  int get expectedShownNonCriticalCount {
    final remainingSlots =
        RitualContextBuilder.maxFeedbackItems - highPriorityCount;
    if (remainingSlots <= 0) return 0;
    return nonCriticalCount > remainingSlots
        ? remainingSlots
        : nonCriticalCount;
  }

  List<ClassifiedFeedbackItem> get items => [
    for (var i = 0; i < criticalNegativeCount; i++)
      makeTestClassifiedFeedbackItem(
        sentiment: FeedbackSentiment.negative,
        detail: 'Generated critical grievance $i',
        source: 'observation',
        observationPriority: ObservationPriority.critical,
      ),
    for (var i = 0; i < criticalPositiveCount; i++)
      makeTestClassifiedFeedbackItem(
        // ignore: avoid_redundant_argument_values
        sentiment: FeedbackSentiment.positive,
        detail: 'Generated critical excellence $i',
        source: 'observation',
        observationPriority: ObservationPriority.critical,
      ),
    for (var i = 0; i < nonCriticalCount; i++)
      makeTestClassifiedFeedbackItem(
        sentiment: nonCriticalSentiment,
        detail: 'Generated regular feedback $i',
      ),
  ];

  String get sentimentHeading => switch (nonCriticalSentiment) {
    FeedbackSentiment.negative => 'Negative Signals',
    FeedbackSentiment.positive => 'Positive Signals',
    FeedbackSentiment.neutral => 'Neutral Signals',
  };

  @override
  String toString() {
    return 'GeneratedRitualFeedbackScenario('
        'criticalNegativeCount: $criticalNegativeCount, '
        'criticalPositiveCount: $criticalPositiveCount, '
        'nonCriticalCount: $nonCriticalCount, '
        'nonCriticalSentiment: $nonCriticalSentiment)';
  }
}

extension AnyGeneratedRitualFeedbackScenario on glados.Any {
  glados.Generator<FeedbackSentiment> get feedbackSentiment =>
      glados.AnyUtils(this).choose(FeedbackSentiment.values);

  glados.Generator<GeneratedRitualFeedbackScenario>
  get ritualFeedbackScenario => glados.CombinableAny(this).combine4(
    glados.IntAnys(this).intInRange(0, 6),
    glados.IntAnys(this).intInRange(0, 6),
    glados.IntAnys(this).intInRange(
      0,
      RitualContextBuilder.maxFeedbackItems + 12,
    ),
    feedbackSentiment,
    (
      int criticalNegativeCount,
      int criticalPositiveCount,
      int nonCriticalCount,
      FeedbackSentiment nonCriticalSentiment,
    ) => GeneratedRitualFeedbackScenario(
      criticalNegativeCount: criticalNegativeCount,
      criticalPositiveCount: criticalPositiveCount,
      nonCriticalCount: nonCriticalCount,
      nonCriticalSentiment: nonCriticalSentiment,
    ),
  );
}
