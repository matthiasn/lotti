// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_page_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TasksFilter _$TasksFilterFromJson(Map<String, dynamic> json) => _TasksFilter(
      selectedCategoryIds: (json['selectedCategoryIds'] as List<dynamic>)
          .map((e) => e as String)
          .toSet(),
      selectedTaskStatuses: (json['selectedTaskStatuses'] as List<dynamic>)
          .map((e) => e as String)
          .toSet(),
    );

Map<String, dynamic> _$TasksFilterToJson(_TasksFilter instance) =>
    <String, dynamic>{
      'selectedCategoryIds': instance.selectedCategoryIds.toList(),
      'selectedTaskStatuses': instance.selectedTaskStatuses.toList(),
    };
