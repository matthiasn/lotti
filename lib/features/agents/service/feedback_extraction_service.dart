import 'dart:developer' as developer show log;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/classified_feedback.dart';
import 'package:lotti/features/agents/model/improver_slot_keys.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/util/text_utils.dart';

/// Well-known feedback source identifiers.
abstract final class FeedbackSources {
  static const decision = 'decision';
  static const observation = 'observation';
  static const metric = 'metric';
  static const rating = 'rating';
  static const evolutionSession = 'evolution_session';
  static const directiveChurn = 'directive_churn';
}

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

  /// Inclusive date-range check shared by all extraction stages.
  static bool _isInWindow(DateTime dt, DateTime since, DateTime until) =>
      !dt.isBefore(since) && !dt.isAfter(until);

  /// Extract and classify feedback for a template within a time window.
  ///
  /// Scans observations, decisions, and reports from all instances of
  /// [templateId] that fall within `[since, until]`.
  Future<ClassifiedFeedback> extract({
    required String templateId,
    required DateTime since,
    DateTime? until,
  }) async {
    final effectiveUntil = until ?? clock.now();
    if (effectiveUntil.isBefore(since)) {
      throw ArgumentError(
        'until ($effectiveUntil) must not be before since ($since)',
      );
    }
    final items = <ClassifiedFeedbackItem>[];

    bool inWindow(DateTime dt) => _isInWindow(dt, since, effectiveUntil);

    // 1. Classify decisions (single template-level query with SQL filter).
    final allDecisions = await agentRepository.getRecentDecisionsForTemplate(
      templateId,
      since: since,
    );
    final windowDecisions = allDecisions
        .where((d) => inWindow(d.createdAt))
        .toList();
    final totalDecisionsScanned = windowDecisions.length;

    // Bulk-fetch change sets for decisions missing humanSummary.
    final missingIds = windowDecisions
        .where((d) => d.humanSummary == null)
        .map((d) => d.changeSetId)
        .toSet();
    var changeSetMap = <String, ChangeSetEntity>{};
    try {
      final changeSetEntities = await Future.wait(
        missingIds.map(agentRepository.getEntity),
      );
      changeSetMap = {
        for (final entity in changeSetEntities.whereType<ChangeSetEntity>())
          entity.id: entity,
      };
    } catch (e) {
      developer.log(
        'Failed to fetch change sets: $e',
        name: 'FeedbackExtractionService',
      );
    }

    var suppressedChecklistRejectionCount = 0;
    for (final decision in windowDecisions) {
      if (_shouldSuppressRejectedChecklistDecision(decision)) {
        suppressedChecklistRejectionCount += 1;
        continue;
      }
      items.add(
        _classifyDecision(decision, changeSetMap: changeSetMap),
      );
    }

    if (suppressedChecklistRejectionCount >= 2) {
      items.add(
        ClassifiedFeedbackItem(
          sentiment: FeedbackSentiment.negative,
          category: FeedbackCategory.prioritization,
          source: FeedbackSources.decision,
          detail:
              'Repeated rejected checklist proposals: '
              '$suppressedChecklistRejectionCount checklist changes were '
              'rejected without explanation in this feedback window. This '
              'suggests the agent may be proposing checklist updates too '
              'aggressively or too early.',
          agentId: templateId,
          confidence: 1,
        ),
      );
    }

    // 2–4: Observations, reports, and wake runs are independent — fetch
    // them concurrently.
    final results = await Future.wait([
      templateService.getRecentInstanceObservations(templateId, limit: 100),
      templateService.getRecentInstanceReports(templateId, limit: 50),
      agentRepository.getWakeRunsForTemplate(templateId, limit: 200),
    ]);

    final observations = results[0] as List<AgentMessageEntity>;
    final reports = results[1] as List<AgentReportEntity>;
    final wakeRuns = results[2] as List<WakeRunLogData>;

    // 2. Classify observations (heuristic), enriched with payload text.
    final windowObservations = observations
        .where((o) => inWindow(o.createdAt))
        .toList();

    // Bulk-fetch observation payloads for richer detail text.
    // Per-ID error handling so one failure doesn't abort the whole run.
    final payloadIds = windowObservations
        .map((obs) => obs.contentEntryId)
        .whereType<String>()
        .toSet();
    final payloadEntries = await Future.wait(
      payloadIds.map((id) async {
        try {
          final entity = await agentRepository.getEntity(id);
          if (entity is AgentMessagePayloadEntity) {
            return MapEntry(id, entity);
          }
        } catch (e, s) {
          developer.log(
            'Failed to fetch payload $id',
            name: 'FeedbackExtractionService',
            error: e,
            stackTrace: s,
          );
        }
        return null;
      }),
    );
    final payloadMap = <String, AgentMessagePayloadEntity>{
      for (final entry
          in payloadEntries
              .whereType<MapEntry<String, AgentMessagePayloadEntity>>())
        entry.key: entry.value,
    };

    for (final observation in windowObservations) {
      final payload = observation.contentEntryId != null
          ? payloadMap[observation.contentEntryId]
          : null;
      final classified = _classifyObservation(observation, payload: payload);
      if (classified != null) {
        items.add(classified);
      }
    }

    // 3. Classify reports by confidence
    final windowReports = reports.where((r) => inWindow(r.createdAt));
    for (final report in windowReports) {
      final classified = _classifyReport(report);
      if (classified != null) {
        items.add(classified);
      }
    }

    // 4. Classify wake run ratings
    final windowRuns = wakeRuns.where((r) => inWindow(r.createdAt));
    for (final run in windowRuns) {
      final classified = _classifyWakeRunRating(run);
      if (classified != null) {
        items.add(classified);
      }
    }

    // 5. Extract evolution session feedback for improver templates.
    // Only relevant when the template governs improver agents — skip entirely
    // for task agent templates to avoid unnecessary DB queries.
    final template = await templateService.getTemplate(templateId);
    if (template?.kind == AgentTemplateKind.templateImprover) {
      final evolutionItems = await _extractEvolutionSessionFeedback(
        templateId: templateId,
        since: since,
        until: effectiveUntil,
      );
      items.addAll(evolutionItems);
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
  ///
  /// When [changeSetMap] is provided, looks up the parent change set to extract
  /// the item's `humanSummary` for decisions that lack one.
  ClassifiedFeedbackItem _classifyDecision(
    ChangeDecisionEntity decision, {
    Map<String, ChangeSetEntity> changeSetMap = const {},
  }) {
    final sentiment = switch (decision.verdict) {
      ChangeDecisionVerdict.confirmed => FeedbackSentiment.positive,
      ChangeDecisionVerdict.rejected => FeedbackSentiment.negative,
      ChangeDecisionVerdict.deferred => FeedbackSentiment.neutral,
    };

    final detail = _decisionDetailText(decision, changeSetMap);

    return ClassifiedFeedbackItem(
      sentiment: sentiment,
      category: FeedbackCategory.accuracy,
      source: FeedbackSources.decision,
      detail: detail,
      agentId: decision.agentId,
      sourceEntityId: decision.id,
      confidence: 1,
    );
  }

  static bool _shouldSuppressRejectedChecklistDecision(
    ChangeDecisionEntity decision,
  ) =>
      decision.verdict == ChangeDecisionVerdict.rejected &&
      _isChecklistTool(decision.toolName) &&
      !_decisionHasExplanatoryContext(decision);

  static bool _isChecklistTool(String toolName) => switch (toolName) {
    TaskAgentToolNames.addChecklistItem ||
    TaskAgentToolNames.addMultipleChecklistItems ||
    TaskAgentToolNames.updateChecklistItem ||
    TaskAgentToolNames.updateChecklistItems ||
    TaskAgentToolNames.migrateChecklistItem ||
    TaskAgentToolNames.migrateChecklistItems => true,
    _ => false,
  };

  static bool _decisionHasExplanatoryContext(ChangeDecisionEntity decision) {
    if (_isMeaningfulSignalText(decision.rejectionReason)) return true;
    return _argsContainExplanatoryContext(decision.args);
  }

  static bool _argsContainExplanatoryContext(Map<String, dynamic>? args) {
    if (args == null || args.isEmpty) return false;

    const explanatoryKeys = {
      'reason',
      'rejectionreason',
      'note',
      'notes',
      'comment',
      'comments',
      'feedback',
      'explanation',
      'why',
    };

    bool containsContext(Object? value, {String? key}) {
      if (value is String) {
        return key != null &&
            explanatoryKeys.contains(key.toLowerCase()) &&
            _isMeaningfulSignalText(value);
      }
      if (value is Map) {
        return value.entries.any(
          (entry) => containsContext(entry.value, key: entry.key.toString()),
        );
      }
      if (value is Iterable) {
        return value.any((entry) => containsContext(entry, key: key));
      }
      return false;
    }

    return args.entries.any(
      (entry) => containsContext(entry.value, key: entry.key),
    );
  }

  static bool _isMeaningfulSignalText(String? value) {
    if (value == null) return false;
    final normalized = value.trim();
    return normalized.isNotEmpty && normalized.length >= 4;
  }

  /// Build a human-readable detail string for a decision.
  ///
  /// Prefers `humanSummary` on the decision entity, falls back to the change
  /// item's summary from the parent change set, and finally to the tool name.
  static String _decisionDetailText(
    ChangeDecisionEntity decision,
    Map<String, ChangeSetEntity> changeSetMap,
  ) {
    final summary =
        decision.humanSummary ?? _changeItemSummary(decision, changeSetMap);

    final prefix = decision.verdict.name;
    final suffix = decision.rejectionReason != null
        ? ' — ${decision.rejectionReason}'
        : '';

    return '$prefix: $summary$suffix';
  }

  /// Retrieve the humanSummary from the change set item, or fall back to
  /// the tool name.
  static String _changeItemSummary(
    ChangeDecisionEntity decision,
    Map<String, ChangeSetEntity> changeSetMap,
  ) {
    final changeSet = changeSetMap[decision.changeSetId];
    if (changeSet != null &&
        decision.itemIndex >= 0 &&
        decision.itemIndex < changeSet.items.length) {
      return changeSet.items[decision.itemIndex].humanSummary;
    }
    return decision.toolName;
  }

  /// Classification for observations.
  ///
  /// For structured observations (with priority/category in the payload),
  /// uses the encoded fields directly. For legacy bare-string observations,
  /// falls back to keyword-based sentiment analysis.
  ClassifiedFeedbackItem? _classifyObservation(
    AgentMessageEntity observation, {
    AgentMessagePayloadEntity? payload,
  }) {
    final detail = _observationDetailText(payload);
    final priority = _extractObservationPriority(payload);
    final obsCategory = _extractObservationCategory(payload);

    // For critical observations with an explicit category, derive sentiment
    // directly: excellence → positive, grievance/templateImprovement → negative.
    // When the category is operational (default for missing/invalid category),
    // fall back to text heuristics to avoid misclassifying praise as negative.
    final sentiment = priority == ObservationPriority.critical
        ? switch (obsCategory) {
            ObservationCategory.excellence => FeedbackSentiment.positive,
            ObservationCategory.grievance => FeedbackSentiment.negative,
            ObservationCategory.templateImprovement =>
              FeedbackSentiment.negative,
            ObservationCategory.operational => _classifyTextSentiment(detail),
          }
        : _classifyTextSentiment(detail);

    return ClassifiedFeedbackItem(
      sentiment: sentiment,
      category: _mapObservationToFeedbackCategory(obsCategory),
      source: FeedbackSources.observation,
      detail: detail,
      agentId: observation.agentId,
      sourceEntityId: observation.id,
      confidence: priority == ObservationPriority.critical ? 1.0 : null,
      observationPriority: priority,
    );
  }

  /// Extracts [ObservationPriority] from a structured payload, defaulting
  /// to [ObservationPriority.routine] for legacy payloads.
  static ObservationPriority _extractObservationPriority(
    AgentMessagePayloadEntity? payload,
  ) {
    if (payload == null) return ObservationPriority.routine;
    final raw = payload.content['priority'];
    if (raw is String) {
      return parseEnumByName(ObservationPriority.values, raw) ??
          ObservationPriority.routine;
    }
    return ObservationPriority.routine;
  }

  /// Extracts [ObservationCategory] from a structured payload, defaulting
  /// to [ObservationCategory.operational] for legacy payloads.
  static ObservationCategory _extractObservationCategory(
    AgentMessagePayloadEntity? payload,
  ) {
    if (payload == null) return ObservationCategory.operational;
    final raw = payload.content['category'];
    if (raw is String) {
      return parseEnumByName(ObservationCategory.values, raw) ??
          ObservationCategory.operational;
    }
    return ObservationCategory.operational;
  }

  /// Maps an observation category to the appropriate feedback category.
  static FeedbackCategory _mapObservationToFeedbackCategory(
    ObservationCategory obsCategory,
  ) {
    return switch (obsCategory) {
      ObservationCategory.grievance => FeedbackCategory.prioritization,
      ObservationCategory.excellence => FeedbackCategory.general,
      ObservationCategory.templateImprovement => FeedbackCategory.general,
      ObservationCategory.operational => FeedbackCategory.general,
    };
  }

  /// Keyword-based heuristic for classifying text sentiment.
  ///
  /// Scans the lowercase text for positive and negative indicator words/phrases
  /// and returns the dominant sentiment. Returns [FeedbackSentiment.neutral]
  /// when signals are balanced or absent.
  static FeedbackSentiment _classifyTextSentiment(String text) {
    final lower = text.toLowerCase();

    var positiveScore = 0;
    var negativeScore = 0;

    for (final keyword in _positiveKeywords) {
      if (lower.contains(keyword)) positiveScore++;
    }
    for (final keyword in _negativeKeywords) {
      if (lower.contains(keyword)) negativeScore++;
    }

    if (positiveScore > negativeScore) return FeedbackSentiment.positive;
    if (negativeScore > positiveScore) return FeedbackSentiment.negative;
    return FeedbackSentiment.neutral;
  }

  static const _positiveKeywords = [
    'success',
    'completed',
    'approved',
    'confirmed',
    'improved',
    'resolved',
    'fixed',
    'accomplished',
    'achieved',
    'excellent',
    'good',
    'great',
    'well done',
    'on track',
    'progress',
    'ahead of schedule',
    'passed',
    'accepted',
    'positive',
    'helpful',
    'efficient',
    'effective',
    'reliable',
    'consistent',
    'satisfied',
    'exceeded',
    'upgraded',
    'optimized',
    'stable',
  ];

  static const _negativeKeywords = [
    'fail',
    'error',
    'issue',
    'problem',
    'bug',
    'crash',
    'reject',
    'declined',
    'timeout',
    'timed out',
    'slow',
    'degraded',
    'broken',
    'missing',
    'incorrect',
    'wrong',
    'bad',
    'poor',
    'unstable',
    'regression',
    'overdue',
    'behind schedule',
    'abandoned',
    'blocked',
    'stale',
    'negative',
    'inconsistent',
    'unreliable',
    'warning',
    'critical',
    'severe',
  ];

  /// Extract a displayable detail string from an observation payload.
  static String _observationDetailText(AgentMessagePayloadEntity? payload) {
    if (payload == null) return 'Observation recorded';
    final text = payload.content['text'];
    if (text is String && text.trim().isNotEmpty) {
      return truncateAgentText(text, 200);
    }
    return 'Observation recorded';
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
      source: FeedbackSources.metric,
      detail: 'Report confidence: ${confidence.toStringAsFixed(2)}',
      agentId: report.agentId,
      sourceEntityId: report.id,
      confidence: confidence,
    );
  }

  /// Map a numeric rating to a sentiment.
  ///
  /// Shared by wake-run and evolution-session classification.
  static FeedbackSentiment _sentimentFromRating(double rating) => rating >= 4.0
      ? FeedbackSentiment.positive
      : rating <= 2.0
      ? FeedbackSentiment.negative
      : FeedbackSentiment.neutral;

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
        (s) => _isInWindow(s.createdAt, since, until),
      );

      for (final session in windowSessions) {
        items.add(_classifyEvolutionSession(session, result.targetId));
      }

      // Directive churn detection: count template versions created in window.
      final windowVersions = result.versions.where(
        (v) => _isInWindow(v.createdAt, since, until),
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
