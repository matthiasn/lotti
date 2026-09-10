import 'package:freezed_annotation/freezed_annotation.dart';

part 'query_chat_models.freezed.dart';
part 'query_chat_models.g.dart';

enum QueryScopeKind { task, project, category }

enum QuerySourceKind { text, recording, task, project, checklist }

/// Stable home association. Category and visibility are resolved afresh.
@freezed
abstract class QueryScope with _$QueryScope {
  const factory QueryScope({
    required QueryScopeKind kind,
    required String id,
  }) = _QueryScope;

  factory QueryScope.fromJson(Map<String, dynamic> json) =>
      _$QueryScopeFromJson(json);
}

/// Visibility provenance survives source deletion. Current source metadata
/// takes precedence whenever it is available.
@freezed
abstract class QuerySourceRef with _$QuerySourceRef {
  const factory QuerySourceRef({
    required String id,
    required bool private,
    required bool categoryPrivate,
    String? categoryId,
  }) = _QuerySourceRef;

  factory QuerySourceRef.fromJson(Map<String, dynamic> json) =>
      _$QuerySourceRefFromJson(json);
}

/// A verified contiguous passage in one identified stored text version.
/// Offsets are Dart string offsets; they are never audio timestamps.
@freezed
abstract class QueryEvidence with _$QueryEvidence {
  const factory QueryEvidence({
    required QuerySourceRef source,
    required QuerySourceKind kind,
    required String label,
    required DateTime sourceDate,
    required String textVersion,
    required String fingerprint,
    required String sourceText,
    required int start,
    required int end,
    required String summary,
    @Default([]) List<String> affiliations,
    @Default(false) bool outsideHome,
    @Default('') String relevance,
  }) = _QueryEvidence;

  const QueryEvidence._();

  factory QueryEvidence.fromJson(Map<String, dynamic> json) =>
      _$QueryEvidenceFromJson(json);

  bool get hasValidPassage =>
      start >= 0 && end > start && end <= sourceText.length;

  String get quote => hasValidPassage ? sourceText.substring(start, end) : '';
}

@freezed
abstract class QueryCoverage with _$QueryCoverage {
  const factory QueryCoverage({
    @Default(0) int checked,
    @Default(0) int missingTranscripts,
    @Default(false) bool incomplete,
    @Default(false) bool expanded,
  }) = _QueryCoverage;

  factory QueryCoverage.fromJson(Map<String, dynamic> json) =>
      _$QueryCoverageFromJson(json);
}

/// Immutable chat events. Keeping them outside the agent's working-message
/// DAG prevents a crawler's rejected candidates or another chat's history
/// from becoming the task-summary workflow's context.
@freezed
sealed class QueryChatEventData with _$QueryChatEventData {
  const factory QueryChatEventData.created({
    required QueryScope scope,
    required String title,
    @Default(false) bool private,
  }) = QueryChatCreated;

  const factory QueryChatEventData.renamed({
    required String title,
    @Default(false) bool private,
  }) = QueryChatRenamed;

  const factory QueryChatEventData.archived({required bool archived}) =
      QueryChatArchived;

  const factory QueryChatEventData.deleted({required bool forget}) =
      QueryChatDeleted;

  const factory QueryChatEventData.read({required String throughEventId}) =
      QueryChatRead;

  const factory QueryChatEventData.question({
    required String text,
    @Default(false) bool private,
    @Default([]) List<QuerySourceRef> dependencies,
  }) = QueryChatQuestion;

  const factory QueryChatEventData.answer({
    required String questionId,
    required String text,
    required QueryCoverage coverage,
    @Default(false) bool private,
    @Default([]) List<QueryEvidence> evidence,
    @Default([]) List<QuerySourceRef> dependencies,
    @Default([]) List<String> recalledMemoryIds,
  }) = QueryChatAnswer;

  const factory QueryChatEventData.failed({required String questionId}) =
      QueryChatFailed;

  const factory QueryChatEventData.cancelled({required String questionId}) =
      QueryChatCancelled;

  const factory QueryChatEventData.memory({
    required String questionId,
    required String text,
    @Default(false) bool private,
    @Default([]) List<QuerySourceRef> dependencies,
    @Default([]) List<String> recalledMemoryIds,
  }) = QueryChatMemory;

  factory QueryChatEventData.fromJson(Map<String, dynamic> json) =>
      _$QueryChatEventDataFromJson(json);
}
