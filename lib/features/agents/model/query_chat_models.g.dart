// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'query_chat_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_QueryScope _$QueryScopeFromJson(Map<String, dynamic> json) => _QueryScope(
  kind: $enumDecode(_$QueryScopeKindEnumMap, json['kind']),
  id: json['id'] as String,
);

Map<String, dynamic> _$QueryScopeToJson(_QueryScope instance) =>
    <String, dynamic>{
      'kind': _$QueryScopeKindEnumMap[instance.kind]!,
      'id': instance.id,
    };

const _$QueryScopeKindEnumMap = {
  QueryScopeKind.task: 'task',
  QueryScopeKind.project: 'project',
  QueryScopeKind.category: 'category',
};

_QuerySourceRef _$QuerySourceRefFromJson(Map<String, dynamic> json) =>
    _QuerySourceRef(
      id: json['id'] as String,
      private: json['private'] as bool,
      categoryPrivate: json['categoryPrivate'] as bool,
      categoryId: json['categoryId'] as String?,
    );

Map<String, dynamic> _$QuerySourceRefToJson(_QuerySourceRef instance) =>
    <String, dynamic>{
      'id': instance.id,
      'private': instance.private,
      'categoryPrivate': instance.categoryPrivate,
      'categoryId': instance.categoryId,
    };

_QueryEvidence _$QueryEvidenceFromJson(Map<String, dynamic> json) =>
    _QueryEvidence(
      source: QuerySourceRef.fromJson(json['source'] as Map<String, dynamic>),
      kind: $enumDecode(_$QuerySourceKindEnumMap, json['kind']),
      label: json['label'] as String,
      sourceDate: DateTime.parse(json['sourceDate'] as String),
      textVersion: json['textVersion'] as String,
      fingerprint: json['fingerprint'] as String,
      sourceText: json['sourceText'] as String,
      start: (json['start'] as num).toInt(),
      end: (json['end'] as num).toInt(),
      summary: json['summary'] as String,
      textVersionDate: json['textVersionDate'] == null
          ? null
          : DateTime.parse(json['textVersionDate'] as String),
      affiliations:
          (json['affiliations'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      outsideHome: json['outsideHome'] as bool? ?? false,
      relevance: json['relevance'] as String? ?? '',
    );

Map<String, dynamic> _$QueryEvidenceToJson(_QueryEvidence instance) =>
    <String, dynamic>{
      'source': instance.source,
      'kind': _$QuerySourceKindEnumMap[instance.kind]!,
      'label': instance.label,
      'sourceDate': instance.sourceDate.toIso8601String(),
      'textVersion': instance.textVersion,
      'fingerprint': instance.fingerprint,
      'sourceText': instance.sourceText,
      'start': instance.start,
      'end': instance.end,
      'summary': instance.summary,
      'textVersionDate': instance.textVersionDate?.toIso8601String(),
      'affiliations': instance.affiliations,
      'outsideHome': instance.outsideHome,
      'relevance': instance.relevance,
    };

const _$QuerySourceKindEnumMap = {
  QuerySourceKind.text: 'text',
  QuerySourceKind.recording: 'recording',
  QuerySourceKind.task: 'task',
  QuerySourceKind.project: 'project',
  QuerySourceKind.checklist: 'checklist',
};

_QueryCoverage _$QueryCoverageFromJson(Map<String, dynamic> json) =>
    _QueryCoverage(
      checked: (json['checked'] as num?)?.toInt() ?? 0,
      missingTranscripts: (json['missingTranscripts'] as num?)?.toInt() ?? 0,
      incomplete: json['incomplete'] as bool? ?? false,
      expanded: json['expanded'] as bool? ?? false,
      homeChecked: (json['homeChecked'] as num?)?.toInt(),
      categoryChecked: (json['categoryChecked'] as num?)?.toInt(),
      unreadableSources:
          (json['unreadableSources'] as List<dynamic>?)
              ?.map((e) => QuerySourceRef.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$QueryCoverageToJson(_QueryCoverage instance) =>
    <String, dynamic>{
      'checked': instance.checked,
      'missingTranscripts': instance.missingTranscripts,
      'incomplete': instance.incomplete,
      'expanded': instance.expanded,
      'homeChecked': instance.homeChecked,
      'categoryChecked': instance.categoryChecked,
      'unreadableSources': instance.unreadableSources,
    };

QueryChatCreated _$QueryChatCreatedFromJson(Map<String, dynamic> json) =>
    QueryChatCreated(
      scope: QueryScope.fromJson(json['scope'] as Map<String, dynamic>),
      title: json['title'] as String,
      private: json['private'] as bool? ?? false,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$QueryChatCreatedToJson(QueryChatCreated instance) =>
    <String, dynamic>{
      'scope': instance.scope,
      'title': instance.title,
      'private': instance.private,
      'runtimeType': instance.$type,
    };

QueryChatRenamed _$QueryChatRenamedFromJson(Map<String, dynamic> json) =>
    QueryChatRenamed(
      title: json['title'] as String,
      private: json['private'] as bool? ?? false,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$QueryChatRenamedToJson(QueryChatRenamed instance) =>
    <String, dynamic>{
      'title': instance.title,
      'private': instance.private,
      'runtimeType': instance.$type,
    };

QueryChatArchived _$QueryChatArchivedFromJson(Map<String, dynamic> json) =>
    QueryChatArchived(
      archived: json['archived'] as bool,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$QueryChatArchivedToJson(QueryChatArchived instance) =>
    <String, dynamic>{
      'archived': instance.archived,
      'runtimeType': instance.$type,
    };

QueryChatDeleted _$QueryChatDeletedFromJson(Map<String, dynamic> json) =>
    QueryChatDeleted(
      forget: json['forget'] as bool,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$QueryChatDeletedToJson(QueryChatDeleted instance) =>
    <String, dynamic>{'forget': instance.forget, 'runtimeType': instance.$type};

QueryChatRead _$QueryChatReadFromJson(Map<String, dynamic> json) =>
    QueryChatRead(
      throughEventId: json['throughEventId'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$QueryChatReadToJson(QueryChatRead instance) =>
    <String, dynamic>{
      'throughEventId': instance.throughEventId,
      'runtimeType': instance.$type,
    };

QueryChatQuestion _$QueryChatQuestionFromJson(Map<String, dynamic> json) =>
    QueryChatQuestion(
      text: json['text'] as String,
      private: json['private'] as bool? ?? false,
      dependencies:
          (json['dependencies'] as List<dynamic>?)
              ?.map((e) => QuerySourceRef.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$QueryChatQuestionToJson(QueryChatQuestion instance) =>
    <String, dynamic>{
      'text': instance.text,
      'private': instance.private,
      'dependencies': instance.dependencies,
      'runtimeType': instance.$type,
    };

QueryChatAnswer _$QueryChatAnswerFromJson(Map<String, dynamic> json) =>
    QueryChatAnswer(
      questionId: json['questionId'] as String,
      text: json['text'] as String,
      coverage: QueryCoverage.fromJson(
        json['coverage'] as Map<String, dynamic>,
      ),
      summaryBased: json['summaryBased'] as bool? ?? false,
      private: json['private'] as bool? ?? false,
      evidence:
          (json['evidence'] as List<dynamic>?)
              ?.map((e) => QueryEvidence.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      dependencies:
          (json['dependencies'] as List<dynamic>?)
              ?.map((e) => QuerySourceRef.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      recalledMemoryIds:
          (json['recalledMemoryIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$QueryChatAnswerToJson(QueryChatAnswer instance) =>
    <String, dynamic>{
      'questionId': instance.questionId,
      'text': instance.text,
      'coverage': instance.coverage,
      'summaryBased': instance.summaryBased,
      'private': instance.private,
      'evidence': instance.evidence,
      'dependencies': instance.dependencies,
      'recalledMemoryIds': instance.recalledMemoryIds,
      'runtimeType': instance.$type,
    };

QueryChatFailed _$QueryChatFailedFromJson(Map<String, dynamic> json) =>
    QueryChatFailed(
      questionId: json['questionId'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$QueryChatFailedToJson(QueryChatFailed instance) =>
    <String, dynamic>{
      'questionId': instance.questionId,
      'runtimeType': instance.$type,
    };

QueryChatCancelled _$QueryChatCancelledFromJson(Map<String, dynamic> json) =>
    QueryChatCancelled(
      questionId: json['questionId'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$QueryChatCancelledToJson(QueryChatCancelled instance) =>
    <String, dynamic>{
      'questionId': instance.questionId,
      'runtimeType': instance.$type,
    };

QueryChatMemory _$QueryChatMemoryFromJson(Map<String, dynamic> json) =>
    QueryChatMemory(
      questionId: json['questionId'] as String,
      text: json['text'] as String,
      private: json['private'] as bool? ?? false,
      dependencies:
          (json['dependencies'] as List<dynamic>?)
              ?.map((e) => QuerySourceRef.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      recalledMemoryIds:
          (json['recalledMemoryIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$QueryChatMemoryToJson(QueryChatMemory instance) =>
    <String, dynamic>{
      'questionId': instance.questionId,
      'text': instance.text,
      'private': instance.private,
      'dependencies': instance.dependencies,
      'recalledMemoryIds': instance.recalledMemoryIds,
      'runtimeType': instance.$type,
    };
