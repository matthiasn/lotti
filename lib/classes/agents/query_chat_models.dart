import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/agents/change_set.dart';

part 'query_chat_models.freezed.dart';
part 'query_chat_models.g.dart';

/// What a query conversation is about.
///
/// [journal] spans the page's category selection, or every category the
/// reader may see without one; it has no home entry.
/// [unknown] is what a kind added by a newer build decodes to: such a chat is
/// unavailable rather than undecodable, so a synced chat of a future kind is
/// never skipped for good.
enum QueryScopeKind { task, project, category, journal, unknown }

enum QuerySourceKind { text, recording, task, project, checklist }

/// Stable home association. Category and visibility are resolved afresh.
@freezed
abstract class QueryScope with _$QueryScope {
  const factory QueryScope({
    @JsonKey(unknownEnumValue: QueryScopeKind.unknown)
    required QueryScopeKind kind,
    required String id,
  }) = _QueryScope;

  const QueryScope._();

  factory QueryScope.fromJson(Map<String, dynamic> json) =>
      _$QueryScopeFromJson(json);

  /// The journal-wide scope over the categories [categoryIds] — the page's
  /// category selection, where `''` is the uncategorized bucket — or over
  /// every visible category when the selection is empty. The selection is
  /// part of the id, so each selection keeps its own chats.
  factory QueryScope.journalIn(Set<String> categoryIds) => categoryIds.isEmpty
      ? journal
      : QueryScope(
          kind: QueryScopeKind.journal,
          id: '${journal.id}:${(categoryIds.toList()..sort()).join(',')}',
        );

  /// The journal-wide conversation scope over every category the reader may
  /// see.
  static const journal = QueryScope(
    kind: QueryScopeKind.journal,
    id: 'journal',
  );

  /// Whether the scope is anchored on a home entry (a task or a project).
  bool get hasHome =>
      kind == QueryScopeKind.task || kind == QueryScopeKind.project;

  /// Whether the scope reaches past a single category: the journal, over
  /// the page's category selection or every visible category.
  bool get spansCategories => kind == QueryScopeKind.journal;

  /// For a journal-wide scope narrowed to a category selection, that
  /// selection (`''` for uncategorized); null for every other scope, and for
  /// the journal over every visible category.
  Set<String>? get journalCategoryIds {
    if (!spansCategories) return null;
    final prefix = '${journal.id}:';
    return id.startsWith(prefix)
        ? id.substring(prefix.length).split(',').toSet()
        : null;
  }
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
/// Offsets address [sourceText], the saved surrounding text window, using Dart
/// string offsets. They are neither whole-document offsets nor audio timestamps.
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
    DateTime? textVersionDate,
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
    // Null denotes historical answers that did not record scope-layer counts.
    int? homeChecked,
    int? categoryChecked,
    @Default([]) List<QuerySourceRef> unreadableSources,
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
    // Summary owners stay live and in scope after save, sync, and reload.
    @Default(false) bool summaryBased,
    // Validated answer attributions, distinct from broader privacy dependencies.
    @Default([]) List<String> summaryOwnerIds,
    @Default(false) bool private,
    @Default([]) List<QueryEvidence> evidence,
    @Default([]) List<QuerySourceRef> dependencies,
    @Default([]) List<String> recalledMemoryIds,
    // Draft tool arguments belong to this chat; no executable change set
    // exists until the user accepts the inline review.
    @Default([]) List<ChangeItem> proposedActions,
  }) = QueryChatAnswer;

  const factory QueryChatEventData.actionDecision({
    required String questionId,
    required bool approved,
  }) = QueryChatActionDecision;

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
