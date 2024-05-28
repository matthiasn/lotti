// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$EventDataImpl _$$EventDataImplFromJson(Map<String, dynamic> json) =>
    _$EventDataImpl(
      title: json['title'] as String,
      stars: (json['stars'] as num).toInt(),
      status: $enumDecode(_$EventStatusEnumMap, json['status']),
    );

Map<String, dynamic> _$$EventDataImplToJson(_$EventDataImpl instance) =>
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
