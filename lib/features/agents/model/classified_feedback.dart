import 'package:collection/collection.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';

part 'classified_feedback.freezed.dart';
part 'classified_feedback.g.dart';

/// A single classified feedback item extracted from agent data.
@freezed
abstract class ClassifiedFeedbackItem with _$ClassifiedFeedbackItem {
  const factory ClassifiedFeedbackItem({
    required FeedbackSentiment sentiment,
    required FeedbackCategory category,

    /// Source type: 'observation', 'decision', 'metric', or 'rating'.
    required String source,

    /// Human-readable detail about this feedback signal.
    required String detail,

    /// The agent instance this feedback relates to.
    required String agentId,

    /// ID of the source entity (e.g., change decision ID).
    String? sourceEntityId,

    /// Classification confidence (0.0–1.0) for LLM-classified items.
    double? confidence,
  }) = _ClassifiedFeedbackItem;

  factory ClassifiedFeedbackItem.fromJson(Map<String, dynamic> json) =>
      _$ClassifiedFeedbackItemFromJson(json);
}

/// Aggregated feedback for a time window.
@freezed
abstract class ClassifiedFeedback with _$ClassifiedFeedback {
  const factory ClassifiedFeedback({
    required List<ClassifiedFeedbackItem> items,
    required DateTime windowStart,
    required DateTime windowEnd,
    required int totalObservationsScanned,
    required int totalDecisionsScanned,
  }) = _ClassifiedFeedback;

  factory ClassifiedFeedback.fromJson(Map<String, dynamic> json) =>
      _$ClassifiedFeedbackFromJson(json);
}

/// Extension methods for filtering and grouping feedback.
extension ClassifiedFeedbackX on ClassifiedFeedback {
  /// All items with positive sentiment.
  List<ClassifiedFeedbackItem> get positive =>
      items.where((i) => i.sentiment == FeedbackSentiment.positive).toList();

  /// All items with negative sentiment.
  List<ClassifiedFeedbackItem> get negative =>
      items.where((i) => i.sentiment == FeedbackSentiment.negative).toList();

  /// Group items by category.
  Map<FeedbackCategory, List<ClassifiedFeedbackItem>> get byCategory =>
      items.groupListsBy((i) => i.category);
}
