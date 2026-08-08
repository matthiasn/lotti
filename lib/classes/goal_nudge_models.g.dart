// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'goal_nudge_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GoalNudgeBrief _$GoalNudgeBriefFromJson(Map<String, dynamic> json) =>
    _GoalNudgeBrief(
      sceneConcept: json['sceneConcept'] as String,
      headline: json['headline'] as String,
      altText: json['altText'] as String,
      tone: $enumDecode(_$GoalNudgeToneEnumMap, json['tone']),
      cta: json['cta'] as String?,
      mood: json['mood'] as String?,
      stylePreset: json['stylePreset'] as String?,
    );

Map<String, dynamic> _$GoalNudgeBriefToJson(_GoalNudgeBrief instance) =>
    <String, dynamic>{
      'sceneConcept': instance.sceneConcept,
      'headline': instance.headline,
      'altText': instance.altText,
      'tone': _$GoalNudgeToneEnumMap[instance.tone]!,
      'cta': instance.cta,
      'mood': instance.mood,
      'stylePreset': instance.stylePreset,
    };

const _$GoalNudgeToneEnumMap = {
  GoalNudgeTone.encourage: 'encourage',
  GoalNudgeTone.nudge: 'nudge',
  GoalNudgeTone.celebrate: 'celebrate',
  GoalNudgeTone.roast: 'roast',
};

_GoalNudgeRating _$GoalNudgeRatingFromJson(Map<String, dynamic> json) =>
    _GoalNudgeRating(
      rating: (json['rating'] as num).toInt(),
      ratedAt: DateTime.parse(json['ratedAt'] as String),
    );

Map<String, dynamic> _$GoalNudgeRatingToJson(_GoalNudgeRating instance) =>
    <String, dynamic>{
      'rating': instance.rating,
      'ratedAt': instance.ratedAt.toIso8601String(),
    };
