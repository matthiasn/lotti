// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'classified_feedback.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ClassifiedFeedbackItem _$ClassifiedFeedbackItemFromJson(
        Map<String, dynamic> json) =>
    _ClassifiedFeedbackItem(
      sentiment: $enumDecode(_$FeedbackSentimentEnumMap, json['sentiment']),
      category: $enumDecode(_$FeedbackCategoryEnumMap, json['category']),
      source: json['source'] as String,
      detail: json['detail'] as String,
      agentId: json['agentId'] as String,
      sourceEntityId: json['sourceEntityId'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$ClassifiedFeedbackItemToJson(
        _ClassifiedFeedbackItem instance) =>
    <String, dynamic>{
      'sentiment': _$FeedbackSentimentEnumMap[instance.sentiment]!,
      'category': _$FeedbackCategoryEnumMap[instance.category]!,
      'source': instance.source,
      'detail': instance.detail,
      'agentId': instance.agentId,
      'sourceEntityId': instance.sourceEntityId,
      'confidence': instance.confidence,
    };

const _$FeedbackSentimentEnumMap = {
  FeedbackSentiment.positive: 'positive',
  FeedbackSentiment.negative: 'negative',
  FeedbackSentiment.neutral: 'neutral',
};

const _$FeedbackCategoryEnumMap = {
  FeedbackCategory.accuracy: 'accuracy',
  FeedbackCategory.communication: 'communication',
  FeedbackCategory.prioritization: 'prioritization',
  FeedbackCategory.tooling: 'tooling',
  FeedbackCategory.timeliness: 'timeliness',
  FeedbackCategory.general: 'general',
};

_ClassifiedFeedback _$ClassifiedFeedbackFromJson(Map<String, dynamic> json) =>
    _ClassifiedFeedback(
      items: (json['items'] as List<dynamic>)
          .map(
              (e) => ClassifiedFeedbackItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      windowStart: DateTime.parse(json['windowStart'] as String),
      windowEnd: DateTime.parse(json['windowEnd'] as String),
      totalObservationsScanned:
          (json['totalObservationsScanned'] as num).toInt(),
      totalDecisionsScanned: (json['totalDecisionsScanned'] as num).toInt(),
    );

Map<String, dynamic> _$ClassifiedFeedbackToJson(_ClassifiedFeedback instance) =>
    <String, dynamic>{
      'items': instance.items,
      'windowStart': instance.windowStart.toIso8601String(),
      'windowEnd': instance.windowEnd.toIso8601String(),
      'totalObservationsScanned': instance.totalObservationsScanned,
      'totalDecisionsScanned': instance.totalDecisionsScanned,
    };
