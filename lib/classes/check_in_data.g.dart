// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'check_in_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CheckInData _$CheckInDataFromJson(Map<String, dynamic> json) => _CheckInData(
  relationshipId: json['relationshipId'] as String,
  interactionType: $enumDecode(
    _$CheckInInteractionTypeEnumMap,
    json['interactionType'],
  ),
  sentiment: $enumDecodeNullable(_$CheckInSentimentEnumMap, json['sentiment']),
  topics:
      (json['topics'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  payAttentionTo: json['payAttentionTo'] as String?,
  avoid: json['avoid'] as String?,
);

Map<String, dynamic> _$CheckInDataToJson(
  _CheckInData instance,
) => <String, dynamic>{
  'relationshipId': instance.relationshipId,
  'interactionType': _$CheckInInteractionTypeEnumMap[instance.interactionType]!,
  'sentiment': _$CheckInSentimentEnumMap[instance.sentiment],
  'topics': instance.topics,
  'payAttentionTo': instance.payAttentionTo,
  'avoid': instance.avoid,
};

const _$CheckInInteractionTypeEnumMap = {
  CheckInInteractionType.inPerson: 'inPerson',
  CheckInInteractionType.call: 'call',
  CheckInInteractionType.videoCall: 'videoCall',
  CheckInInteractionType.message: 'message',
  CheckInInteractionType.other: 'other',
};

const _$CheckInSentimentEnumMap = {
  CheckInSentiment.delightful: 'delightful',
  CheckInSentiment.good: 'good',
  CheckInSentiment.neutral: 'neutral',
  CheckInSentiment.strained: 'strained',
  CheckInSentiment.difficult: 'difficult',
};
