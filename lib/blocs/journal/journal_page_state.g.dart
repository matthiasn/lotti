// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_page_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TasksFilter _$TasksFilterFromJson(Map<String, dynamic> json) => _TasksFilter(
      selectedCategoryIds: (json['selectedCategoryIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          const <String>{},
      selectedTaskStatuses: (json['selectedTaskStatuses'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          const <String>{},
      selectedLabelIds: (json['selectedLabelIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          const <String>{},
      selectedPriorities: (json['selectedPriorities'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          const <String>{},
      sortOption:
          $enumDecodeNullable(_$TaskSortOptionEnumMap, json['sortOption']) ??
              TaskSortOption.byPriority,
      showCreationDate: json['showCreationDate'] as bool? ?? false,
    );

Map<String, dynamic> _$TasksFilterToJson(_TasksFilter instance) =>
    <String, dynamic>{
      'selectedCategoryIds': instance.selectedCategoryIds.toList(),
      'selectedTaskStatuses': instance.selectedTaskStatuses.toList(),
      'selectedLabelIds': instance.selectedLabelIds.toList(),
      'selectedPriorities': instance.selectedPriorities.toList(),
      'sortOption': _$TaskSortOptionEnumMap[instance.sortOption]!,
      'showCreationDate': instance.showCreationDate,
    };

const _$TaskSortOptionEnumMap = {
  TaskSortOption.byPriority: 'byPriority',
  TaskSortOption.byDate: 'byDate',
};
