import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/classified_feedback.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';

/// Extracts and classifies feedback from agent observations and decisions.
///
/// Uses a hybrid classification strategy (per ADR 0011):
/// - Rule-based fast path for decisions and report confidence
/// - Placeholder heuristic classifier for observation text (to be replaced
///   by LLM classification in Phase 4)
class FeedbackExtractionService {
  FeedbackExtractionService({
    required this.agentRepository,
    required this.templateService,
  });

  final AgentRepository agentRepository;
  final AgentTemplateService templateService;

  /// Extract and classify feedback for a template within a time window.
  ///
  /// Scans observations, decisions, and reports from all instances of
  /// [templateId] that fall within `[since, until]`.
  Future<ClassifiedFeedback> extract({
    required String templateId,
    required DateTime since,
    DateTime? until,
  }) async {
    final effectiveUntil = until ?? DateTime.now();
    final items = <ClassifiedFeedbackItem>[];

    // 1. Classify decisions
    final agents = await templateService.getAgentsForTemplate(templateId);
    var totalDecisionsScanned = 0;
    for (final agent in agents) {
      final decisions = await agentRepository.getRecentDecisions(
        agent.agentId,
        limit: 100,
      );
      final windowDecisions = decisions.where(
        (d) =>
            !d.createdAt.isBefore(since) &&
            !d.createdAt.isAfter(effectiveUntil),
      );
      totalDecisionsScanned += windowDecisions.length;

      for (final decision in windowDecisions) {
        items.add(_classifyDecision(decision));
      }
    }

    // 2. Classify observations (heuristic)
    final observations = await templateService.getRecentInstanceObservations(
      templateId,
      limit: 100,
    );
    final windowObservations = observations.where(
      (o) =>
          !o.createdAt.isBefore(since) && !o.createdAt.isAfter(effectiveUntil),
    );

    for (final observation in windowObservations) {
      final classified = _classifyObservation(observation);
      if (classified != null) {
        items.add(classified);
      }
    }

    // 3. Classify reports by confidence
    final reports = await templateService.getRecentInstanceReports(
      templateId,
      limit: 50,
    );
    final windowReports = reports.where(
      (r) =>
          !r.createdAt.isBefore(since) && !r.createdAt.isAfter(effectiveUntil),
    );
    for (final report in windowReports) {
      final classified = _classifyReport(report);
      if (classified != null) {
        items.add(classified);
      }
    }

    // 4. Classify wake run ratings
    final wakeRuns = await agentRepository.getWakeRunsForTemplate(
      templateId,
      limit: 200,
    );
    final windowRuns = wakeRuns.where(
      (r) =>
          !r.createdAt.isBefore(since) && !r.createdAt.isAfter(effectiveUntil),
    );
    for (final run in windowRuns) {
      final classified = _classifyWakeRunRating(run);
      if (classified != null) {
        items.add(classified);
      }
    }

    return ClassifiedFeedback(
      items: items,
      windowStart: since,
      windowEnd: effectiveUntil,
      totalObservationsScanned: windowObservations.length,
      totalDecisionsScanned: totalDecisionsScanned,
    );
  }

  /// Rule-based classification for decisions.
  ClassifiedFeedbackItem _classifyDecision(ChangeDecisionEntity decision) {
    final sentiment = switch (decision.verdict) {
      ChangeDecisionVerdict.confirmed => FeedbackSentiment.positive,
      ChangeDecisionVerdict.rejected => FeedbackSentiment.negative,
      ChangeDecisionVerdict.deferred => FeedbackSentiment.neutral,
    };

    return ClassifiedFeedbackItem(
      sentiment: sentiment,
      category: FeedbackCategory.accuracy,
      source: 'decision',
      detail: '${decision.verdict.name} change: ${decision.toolName}',
      agentId: decision.agentId,
      sourceEntityId: decision.id,
      confidence: 1,
    );
  }

  /// Placeholder classification for observations.
  ///
  /// This is a temporary stub that will be replaced by LLM classification
  /// in Phase 4. Currently always emits a neutral observation signal because
  /// the observation text lives in a linked payload entity that is not
  /// loaded here.
  ClassifiedFeedbackItem? _classifyObservation(
    AgentMessageEntity observation,
  ) {
    // Observations don't have inline text content — their text lives in
    // a linked AgentMessagePayloadEntity. Without loading the payload we
    // can only record a neutral observation-count signal.
    return ClassifiedFeedbackItem(
      sentiment: FeedbackSentiment.neutral,
      category: FeedbackCategory.general,
      source: 'observation',
      detail: 'Observation recorded',
      agentId: observation.agentId,
      sourceEntityId: observation.id,
    );
  }

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
      source: 'metric',
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

    final sentiment = rating >= 4.0
        ? FeedbackSentiment.positive
        : rating <= 2.0
            ? FeedbackSentiment.negative
            : FeedbackSentiment.neutral;

    return ClassifiedFeedbackItem(
      sentiment: sentiment,
      category: FeedbackCategory.general,
      source: 'rating',
      detail: 'Wake run rated ${rating.toStringAsFixed(1)}',
      agentId: wakeRun.agentId,
      confidence: 1,
    );
  }
}
