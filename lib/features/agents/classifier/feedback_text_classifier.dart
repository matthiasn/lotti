import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

/// Pure, stateless text/decision classification helpers extracted from
/// `FeedbackExtractionService`.
///
/// These functions perform no I/O and depend on no service state, repositories,
/// or database access. They are kept in a standalone library so they can be
/// imported and unit-tested directly without mocks or `getIt` setup.

/// Inclusive date-range check: returns `true` when [dt] lies within the closed
/// interval `[since, until]`.
///
/// Shared by all feedback extraction stages to decide whether an entity falls
/// inside the feedback window.
bool isInWindow(DateTime dt, DateTime since, DateTime until) =>
    !dt.isBefore(since) && !dt.isAfter(until);

/// Whether [toolName] is one of the checklist-mutating task agent tools.
bool isChecklistTool(String toolName) => switch (toolName) {
  TaskAgentToolNames.addChecklistItem ||
  TaskAgentToolNames.addMultipleChecklistItems ||
  TaskAgentToolNames.updateChecklistItem ||
  TaskAgentToolNames.updateChecklistItems ||
  TaskAgentToolNames.migrateChecklistItem ||
  TaskAgentToolNames.migrateChecklistItems => true,
  _ => false,
};

/// Whether [decision] carries a meaningful explanation for its verdict.
///
/// A decision has explanatory context when its `rejectionReason` is a
/// meaningful signal (see [isMeaningfulSignalText]) or when its `args` contain
/// a meaningful value under a recognized explanatory key (see
/// [argsContainExplanatoryContext]).
bool decisionHasExplanatoryContext(ChangeDecisionEntity decision) {
  if (isMeaningfulSignalText(decision.rejectionReason)) return true;
  return argsContainExplanatoryContext(decision.args);
}

/// Whether [args] contain a meaningful explanatory value.
///
/// Recursively scans the map for string values stored under a recognized
/// explanatory key (e.g. `reason`, `rejection_reason`, `note`, `feedback`).
/// Keys are normalized by lowercasing and stripping `_`/`-` separators so that
/// `rejection_reason`, `rejection-reason`, and `rejectionReason` all match the
/// allowlist entry `rejectionreason`. When a parent key is explanatory, the
/// context propagates so nested string values are still recognized
/// (e.g. `{'feedback': {'text': 'too early'}}`).
bool argsContainExplanatoryContext(Map<String, dynamic>? args) {
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
      return isExplanatoryKey && isMeaningfulSignalText(value);
    }
    if (value is Map) {
      return value.entries.any(
        (entry) {
          final entryKey = entry.key.toString();
          // If the parent key is explanatory, propagate it so nested
          // string values are still recognized as having explanatory
          // context (e.g. {'feedback': {'text': 'too early'}}).
          final effectiveKey = explanatoryKeys.contains(normalizeKey(entryKey))
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

/// Whether [value] is a non-empty, non-trivial signal string.
///
/// Returns `true` only when [value] is non-null and, after trimming, contains
/// at least 4 characters. Shorter values (e.g. `ok`, `no`) carry no meaningful
/// signal.
bool isMeaningfulSignalText(String? value) {
  if (value == null) return false;
  final normalized = value.trim();
  return normalized.isNotEmpty && normalized.length >= 4;
}

/// Keyword-based heuristic for classifying text sentiment.
///
/// Scans the lowercase text for positive and negative indicator words/phrases
/// and returns the dominant sentiment. Returns [FeedbackSentiment.neutral]
/// when signals are balanced or absent.
FeedbackSentiment classifyTextSentiment(String text) {
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

/// Indicator words/phrases that contribute to a positive sentiment score in
/// [classifyTextSentiment].
const positiveSentimentKeywords = [
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

/// Indicator words/phrases that contribute to a negative sentiment score in
/// [classifyTextSentiment].
const negativeSentimentKeywords = [
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
