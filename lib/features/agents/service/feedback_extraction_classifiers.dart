part of 'feedback_extraction_service.dart';

/// Per-source feedback classifiers for [FeedbackExtractionService]: reports,
/// wake-run ratings, and evolution-session outcomes. Split from the main file
/// for size.
extension FeedbackExtractionClassifiers on FeedbackExtractionService {
  /// Rule-based classification for reports by confidence score.
  ClassifiedFeedbackItem? _classifyReport(AgentReportEntity report) {
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
  ClassifiedFeedbackItem? _classifyWakeRunRating(WakeRunLogData wakeRun) {
    final rating = wakeRun.userRating;
    if (rating == null) return null;

    final sentiment = _sentimentFromRating(rating);

    return ClassifiedFeedbackItem(
      sentiment: sentiment,
      category: FeedbackCategory.general,
      source: FeedbackSources.rating,
      detail: 'Wake run rated ${rating.toStringAsFixed(1)}',
      agentId: wakeRun.agentId,
      confidence: 1,
    );
  }

  /// Extract feedback from evolution sessions created by improver agents
  /// governed by [templateId].
  ///
  /// This is the meta-feedback layer: when the target is an improver template,
  /// the most meaningful signals come from how well those improver agents
  /// performed their rituals (evolution session outcomes).
  Future<List<ClassifiedFeedbackItem>> _extractEvolutionSessionFeedback({
    required String templateId,
    required DateTime since,
    required DateTime until,
  }) async {
    // Get all agent instances governed by this template.
    final agents = await templateService.getAgentsForTemplate(templateId);
    if (agents.isEmpty) return [];

    // Resolve each agent's target template ID (the template it improves).
    final states = await Future.wait(
      agents.map((agent) => agentRepository.getAgentState(agent.agentId)),
    );
    final targetTemplateIds = states
        .map((state) => state?.slots.activeTemplateId)
        .whereType<String>()
        .toSet();
    if (targetTemplateIds.isEmpty) return [];

    // Query evolution sessions and versions for all target templates in
    // parallel.
    final results = await Future.wait(
      targetTemplateIds.map((targetId) async {
        final (sessions, versions) = await (
          templateService.getEvolutionSessions(targetId, limit: 50),
          templateService.getVersionHistory(targetId),
        ).wait;
        return (
          targetId: targetId,
          sessions: sessions,
          versions: versions,
        );
      }),
    );

    final items = <ClassifiedFeedbackItem>[];

    for (final result in results) {
      final windowSessions = result.sessions.where(
        (s) => isInWindow(s.createdAt, since, until),
      );

      for (final session in windowSessions) {
        items.add(_classifyEvolutionSession(session, result.targetId));
      }

      // Directive churn detection: count template versions created in window.
      final windowVersions = result.versions.where(
        (v) => isInWindow(v.createdAt, since, until),
      );
      final versionCount = windowVersions.length;
      if (versionCount > ImproverSlotDefaults.maxDirectiveChurnVersions) {
        items.add(
          ClassifiedFeedbackItem(
            sentiment: FeedbackSentiment.negative,
            category: FeedbackCategory.general,
            source: FeedbackSources.directiveChurn,
            detail:
                'Excessive directive churn: $versionCount versions '
                'created for template ${result.targetId} in feedback window '
                '(threshold: '
                '${ImproverSlotDefaults.maxDirectiveChurnVersions})',
            agentId: templateId,
            confidence: 1,
          ),
        );
      }
    }

    return items;
  }

  /// Classify a single evolution session into a feedback item.
  ClassifiedFeedbackItem _classifyEvolutionSession(
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
      final sentiment = _sentimentFromRating(rating);

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
}

// Pure helpers (de-statified):
/// Extract a displayable detail string from an observation payload.
String _observationDetailText(AgentMessagePayloadEntity? payload) {
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
FeedbackSentiment _sentimentFromRating(double rating) => rating >= 4.0
    ? FeedbackSentiment.positive
    : rating <= 2.0
    ? FeedbackSentiment.negative
    : FeedbackSentiment.neutral;
