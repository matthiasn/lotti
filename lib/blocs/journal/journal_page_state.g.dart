// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_page_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TasksFilterImpl _$$TasksFilterImplFromJson(Map<String, dynamic> json) =>
    _$TasksFilterImpl(
      selectedCategoryIds: (json['selectedCategoryIds'] as List<dynamic>)
          .map((e) => e as String)
          .toSet(),
      selectedTaskStatuses: (json['selectedTaskStatuses'] as List<dynamic>)
          .map((e) => e as String)
          .toSet(),
    );

Map<String, dynamic> _$$TasksFilterImplToJson(_$TasksFilterImpl instance) =>
    <String, dynamic>{
      'selectedCategoryIds': instance.selectedCategoryIds.toList(),
      'selectedTaskStatuses': instance.selectedTaskStatuses.toList(),
    };
