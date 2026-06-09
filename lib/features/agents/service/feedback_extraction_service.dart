import 'dart:developer' as developer show log;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/classified_feedback.dart';
import 'package:lotti/features/agents/model/improver_slot_keys.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/service/soul_document_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/util/text_utils.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:meta/meta.dart';

part 'feedback_extraction_classifiers.dart';

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
    this.soulDocumentService,
  });

  final AgentRepository agentRepository;
  final AgentTemplateService templateService;
  final SoulDocumentService? soulDocumentService;

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
        'Failed to fetch change sets (errorType=${e.runtimeType})',
        name: 'FeedbackExtractionService',
        error: e.runtimeType,
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
            'Failed to fetch payload ${DomainLogger.sanitizeId(id)}',
            name: 'FeedbackExtractionService',
            error: e.runtimeType,
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
      // Agent-autonomous retractions are not user feedback; they carry no
      // sentiment signal about proposal quality.
      ChangeDecisionVerdict.retracted => FeedbackSentiment.neutral,
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
    return argsContainExplanatoryContext(decision.args);
  }

  @visibleForTesting
  static bool argsContainExplanatoryContext(Map<String, dynamic>? args) {
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

    // Normalize keys by lowercasing and stripping separators so that
    // variants like `rejection_reason`, `rejection-reason`, and
    // `rejectionReason` all match the allowlist entry `rejectionreason`.
    String normalizeKey(String key) =>
        key.toLowerCase().replaceAll(RegExp('[_-]'), '');

    bool containsContext(Object? value, {String? key}) {
      final isExplanatoryKey =
          key != null && explanatoryKeys.contains(normalizeKey(key));
      if (value is String) {
        return isExplanatoryKey && _isMeaningfulSignalText(value);
      }
      if (value is Map) {
        return value.entries.any(
          (entry) {
            final entryKey = entry.key.toString();
            // If the parent key is explanatory, propagate it so nested
            // string values are still recognized as having explanatory
            // context (e.g. {'feedback': {'text': 'too early'}}).
            final effectiveKey =
                explanatoryKeys.contains(normalizeKey(entryKey))
                ? entryKey
                : (isExplanatoryKey ? key : entryKey);
            return containsContext(entry.value, key: effectiveKey);
          },
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
            ObservationCategory.operational => classifyTextSentiment(detail),
          }
        : classifyTextSentiment(detail);

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
  @visibleForTesting
  static FeedbackSentiment classifyTextSentiment(String text) {
    final lower = text.toLowerCase();

    var positiveScore = 0;
    var negativeScore = 0;

    for (final keyword in positiveSentimentKeywords) {
      if (lower.contains(keyword)) positiveScore++;
    }
    for (final keyword in negativeSentimentKeywords) {
      if (lower.contains(keyword)) negativeScore++;
    }

    if (positiveScore > negativeScore) return FeedbackSentiment.positive;
    if (negativeScore > positiveScore) return FeedbackSentiment.negative;
    return FeedbackSentiment.neutral;
  }

  @visibleForTesting
  static const positiveSentimentKeywords = [
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

  @visibleForTesting
  static const negativeSentimentKeywords = [
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

  /// Map a numeric rating to a sentiment.
  ///
  /// Shared by wake-run and evolution-session classification.
  static FeedbackSentiment _sentimentFromRating(double rating) => rating >= 4.0
      ? FeedbackSentiment.positive
      : rating <= 2.0
      ? FeedbackSentiment.negative
      : FeedbackSentiment.neutral;
}
