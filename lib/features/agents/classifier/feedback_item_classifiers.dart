import 'package:lotti/features/agents/database/agent_database.dart'
    show WakeRunLogData;
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/classified_feedback.dart';
import 'package:lotti/features/agents/util/text_utils.dart';

/// Rule-based classification for reports by confidence score.
ClassifiedFeedbackItem? classifyReport(AgentReportEntity report) {
  final confidence = report.confidence;
  if (confidence == null) return null;

  final sentiment = confidence > 0.7
      ? FeedbackSentiment.positive
      : confidence < 0.3
      ? FeedbackSentiment.negative
      : FeedbackSentiment.neutral;

  return ClassifiedFeedbackItem(
    sentiment: sentiment,
    category: FeedbackCategory.accuracy,
    source: FeedbackSources.metric,
    detail: 'Report confidence: ${confidence.toStringAsFixed(2)}',
    agentId: report.agentId,
    sourceEntityId: report.id,
    confidence: confidence,
  );
}

/// Classify wake run user ratings.
ClassifiedFeedbackItem? classifyWakeRunRating(WakeRunLogData wakeRun) {
  final rating = wakeRun.userRating;
  if (rating == null) return null;

  final sentiment = sentimentFromRating(rating);

  return ClassifiedFeedbackItem(
    sentiment: sentiment,
    category: FeedbackCategory.general,
    source: FeedbackSources.rating,
    detail: 'Wake run rated ${rating.toStringAsFixed(1)}',
    agentId: wakeRun.agentId,
    confidence: 1,
  );
}

/// Classify a single evolution session into a feedback item.
ClassifiedFeedbackItem classifyEvolutionSession(
  EvolutionSessionEntity session,
  String targetTemplateId,
) {
  final rating = session.userRating;

  if (session.status == EvolutionSessionStatus.abandoned) {
    return ClassifiedFeedbackItem(
      sentiment: FeedbackSentiment.negative,
      category: FeedbackCategory.general,
      source: FeedbackSources.evolutionSession,
      detail:
          'Evolution session #${session.sessionNumber} for '
          'template $targetTemplateId was abandoned',
      agentId: session.agentId,
      sourceEntityId: session.id,
      confidence: 1,
    );
  }

  if (session.status == EvolutionSessionStatus.completed && rating != null) {
    final sentiment = sentimentFromRating(rating);

    return ClassifiedFeedbackItem(
      sentiment: sentiment,
      category: FeedbackCategory.general,
      source: FeedbackSources.evolutionSession,
      detail:
          'Evolution session #${session.sessionNumber} for '
          'template $targetTemplateId completed with rating '
          '${rating.toStringAsFixed(1)}',
      agentId: session.agentId,
      sourceEntityId: session.id,
      confidence: 1,
    );
  }

  // Completed without rating or still active.
  return ClassifiedFeedbackItem(
    sentiment: FeedbackSentiment.neutral,
    category: FeedbackCategory.general,
    source: FeedbackSources.evolutionSession,
    detail:
        'Evolution session #${session.sessionNumber} for '
        'template $targetTemplateId: ${session.status.name}',
    agentId: session.agentId,
    sourceEntityId: session.id,
  );
}

/// Extract a displayable detail string from an observation payload.
String observationDetailText(AgentMessagePayloadEntity? payload) {
  if (payload == null) return 'Observation recorded';
  final text = payload.content['text'];
  if (text is String && text.trim().isNotEmpty) {
    return truncateAgentText(text, 200);
  }
  return 'Observation recorded';
}

/// Map a numeric rating to a sentiment.
///
/// Shared by wake-run and evolution-session classification.
FeedbackSentiment sentimentFromRating(double rating) => rating >= 4.0
    ? FeedbackSentiment.positive
    : rating <= 2.0
    ? FeedbackSentiment.negative
    : FeedbackSentiment.neutral;
