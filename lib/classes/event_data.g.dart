// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EventData _$EventDataFromJson(Map<String, dynamic> json) => _EventData(
      title: json['title'] as String,
      stars: (json['stars'] as num).toDouble(),
      status: $enumDecode(_$EventStatusEnumMap, json['status']),
    );

Map<String, dynamic> _$EventDataToJson(_EventData instance) =>
    <String, dynamic>{
      'title': instance.title,
      'stars': instance.stars,
      'status': _$EventStatusEnumMap[instance.status]!,
    };

const _$EventStatusEnumMap = {
  EventStatus.tentative: 'tentative',
  EventStatus.planned: 'planned',
  EventStatus.ongoing: 'ongoing',
  EventStatus.completed: 'completed',
  EventStatus.cancelled: 'cancelled',
  EventStatus.postponed: 'postponed',
  EventStatus.rescheduled: 'rescheduled',
  EventStatus.missed: 'missed',
};
