// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_document_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TaskDocumentData _$TaskDocumentDataFromJson(Map<String, dynamic> json) =>
    _TaskDocumentData(
      title: json['title'] as String,
      current: json['current'] == null
          ? null
          : TaskDocumentVersionRef.fromJson(
              json['current'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$TaskDocumentDataToJson(_TaskDocumentData instance) =>
    <String, dynamic>{'title': instance.title, 'current': instance.current};

_TaskDocumentVersionRef _$TaskDocumentVersionRefFromJson(
  Map<String, dynamic> json,
) => _TaskDocumentVersionRef(
  id: json['id'] as String,
  number: (json['number'] as num).toInt(),
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$TaskDocumentVersionRefToJson(
  _TaskDocumentVersionRef instance,
) => <String, dynamic>{
  'id': instance.id,
  'number': instance.number,
  'createdAt': instance.createdAt.toIso8601String(),
};

_TaskDocumentVersionData _$TaskDocumentVersionDataFromJson(
  Map<String, dynamic> json,
) => _TaskDocumentVersionData(
  documentId: json['documentId'] as String,
  number: (json['number'] as num).toInt(),
  markdown: json['markdown'] as String,
  author: $enumDecode(
    _$TaskDocumentAuthorEnumMap,
    json['author'],
    unknownValue: TaskDocumentAuthor.user,
  ),
  baseVersionId: json['baseVersionId'] as String?,
  changeSummary: json['changeSummary'] as String?,
  changeEffectKey: json['changeEffectKey'] as String?,
  restoredFromVersionId: json['restoredFromVersionId'] as String?,
);

Map<String, dynamic> _$TaskDocumentVersionDataToJson(
  _TaskDocumentVersionData instance,
) => <String, dynamic>{
  'documentId': instance.documentId,
  'number': instance.number,
  'markdown': instance.markdown,
  'author': _$TaskDocumentAuthorEnumMap[instance.author]!,
  'baseVersionId': instance.baseVersionId,
  'changeSummary': instance.changeSummary,
  'changeEffectKey': instance.changeEffectKey,
  'restoredFromVersionId': instance.restoredFromVersionId,
};

const _$TaskDocumentAuthorEnumMap = {
  TaskDocumentAuthor.user: 'user',
  TaskDocumentAuthor.agent: 'agent',
};
