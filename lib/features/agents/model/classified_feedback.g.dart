// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'classified_feedback.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$ClassifiedFeedbackItemToJson(
  _ClassifiedFeedbackItem instance,
) => <String, dynamic>{
  'sentiment': _$FeedbackSentimentEnumMap[instance.sentiment]!,
  'category': _$FeedbackCategoryEnumMap[instance.category]!,
  'source': instance.source,
  'detail': instance.detail,
  'agentId': instance.agentId,
  'sourceEntityId': instance.sourceEntityId,
  'confidence': instance.confidence,
  'observationPriority':
      _$ObservationPriorityEnumMap[instance.observationPriority],
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

const _$ObservationPriorityEnumMap = {
  ObservationPriority.routine: 'routine',
  ObservationPriority.notable: 'notable',
  ObservationPriority.critical: 'critical',
};
