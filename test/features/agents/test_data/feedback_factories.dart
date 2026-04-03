import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/classified_feedback.dart';

import 'constants.dart';

// ── Feedback entity factories ──────────────────────────────────────────────

ClassifiedFeedbackItem makeTestClassifiedFeedbackItem({
  FeedbackSentiment sentiment = FeedbackSentiment.positive,
  FeedbackCategory category = FeedbackCategory.accuracy,
  String source = 'decision',
  String detail = 'Test feedback item',
  String agentId = kTestAgentId,
  String? sourceEntityId,
  double? confidence,
  ObservationPriority? observationPriority,
}) {
  return ClassifiedFeedbackItem(
    sentiment: sentiment,
    category: category,
    source: source,
    detail: detail,
    agentId: agentId,
    sourceEntityId: sourceEntityId,
    confidence: confidence,
    observationPriority: observationPriority,
  );
}

ClassifiedFeedback makeTestClassifiedFeedback({
  List<ClassifiedFeedbackItem>? items,
  DateTime? windowStart,
  DateTime? windowEnd,
  int totalObservationsScanned = 0,
  int totalDecisionsScanned = 0,
}) {
  return ClassifiedFeedback(
    items: items ?? [],
    windowStart: windowStart ?? kAgentTestDate,
    windowEnd: windowEnd ?? kAgentTestDate.add(const Duration(days: 7)),
    totalObservationsScanned: totalObservationsScanned,
    totalDecisionsScanned: totalDecisionsScanned,
  );
}
