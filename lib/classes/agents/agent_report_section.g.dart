// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_report_section.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AgentReportSection _$AgentReportSectionFromJson(Map<String, dynamic> json) =>
    _AgentReportSection(
      kind: $enumDecode(_$AgentReportSectionKindEnumMap, json['kind']),
      title: json['title'] as String? ?? '',
      text: json['text'] as String? ?? '',
      items:
          (json['items'] as List<dynamic>?)
              ?.map(
                (e) =>
                    AgentReportSectionItem.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const <AgentReportSectionItem>[],
    );

Map<String, dynamic> _$AgentReportSectionToJson(_AgentReportSection instance) =>
    <String, dynamic>{
      'kind': _$AgentReportSectionKindEnumMap[instance.kind]!,
      'title': instance.title,
      'text': instance.text,
      'items': instance.items.map((e) => e.toJson()).toList(),
    };

const _$AgentReportSectionKindEnumMap = {
  AgentReportSectionKind.points: 'points',
  AgentReportSectionKind.checklist: 'checklist',
  AgentReportSectionKind.text: 'text',
};

_AgentReportSectionItem _$AgentReportSectionItemFromJson(
  Map<String, dynamic> json,
) => _AgentReportSectionItem(
  text: json['text'] as String,
  done: json['done'] as bool? ?? false,
);

Map<String, dynamic> _$AgentReportSectionItemToJson(
  _AgentReportSectionItem instance,
) => <String, dynamic>{'text': instance.text, 'done': instance.done};
