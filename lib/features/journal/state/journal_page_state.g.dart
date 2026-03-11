// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_page_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TasksFilter _$TasksFilterFromJson(Map<String, dynamic> json) => _TasksFilter(
  selectedCategoryIds:
      (json['selectedCategoryIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toSet() ??
      const <String>{},
  selectedTaskStatuses:
      (json['selectedTaskStatuses'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toSet() ??
      const <String>{},
  selectedLabelIds:
      (json['selectedLabelIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toSet() ??
      const <String>{},
  selectedPriorities:
      (json['selectedPriorities'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toSet() ??
      const <String>{},
  sortOption:
      $enumDecodeNullable(_$TaskSortOptionEnumMap, json['sortOption']) ??
      TaskSortOption.byPriority,
  showCreationDate: json['showCreationDate'] as bool? ?? false,
  showDueDate: json['showDueDate'] as bool? ?? true,
  showCoverArt: json['showCoverArt'] as bool? ?? true,
  showDistances: json['showDistances'] as bool? ?? false,
  agentAssignmentFilter:
      $enumDecodeNullable(
        _$AgentAssignmentFilterEnumMap,
        json['agentAssignmentFilter'],
      ) ??
      AgentAssignmentFilter.all,
);

Map<String, dynamic> _$TasksFilterToJson(_TasksFilter instance) =>
    <String, dynamic>{
      'selectedCategoryIds': instance.selectedCategoryIds.toList(),
      'selectedTaskStatuses': instance.selectedTaskStatuses.toList(),
      'selectedLabelIds': instance.selectedLabelIds.toList(),
      'selectedPriorities': instance.selectedPriorities.toList(),
      'sortOption': _$TaskSortOptionEnumMap[instance.sortOption]!,
      'showCreationDate': instance.showCreationDate,
      'showDueDate': instance.showDueDate,
      'showCoverArt': instance.showCoverArt,
      'showDistances': instance.showDistances,
      'agentAssignmentFilter':
          _$AgentAssignmentFilterEnumMap[instance.agentAssignmentFilter]!,
    };

const _$TaskSortOptionEnumMap = {
  TaskSortOption.byPriority: 'byPriority',
  TaskSortOption.byDate: 'byDate',
  TaskSortOption.byDueDate: 'byDueDate',
};

const _$AgentAssignmentFilterEnumMap = {
  AgentAssignmentFilter.all: 'all',
  AgentAssignmentFilter.hasAgent: 'hasAgent',
  AgentAssignmentFilter.noAgent: 'noAgent',
};
