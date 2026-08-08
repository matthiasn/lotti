// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'goal_nudge_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GoalNudgeBrief _$GoalNudgeBriefFromJson(Map<String, dynamic> json) =>
    _GoalNudgeBrief(
      headline: json['headline'] as String,
      tone: $enumDecode(_$GoalNudgeToneEnumMap, json['tone']),
      animation: $enumDecode(_$GoalBannerAnimationEnumMap, json['animation']),
      accent:
          $enumDecodeNullable(_$GoalBannerAccentEnumMap, json['accent']) ??
          GoalBannerAccent.calm,
      tagline: json['tagline'] as String?,
      cta: json['cta'] as String?,
    );

Map<String, dynamic> _$GoalNudgeBriefToJson(_GoalNudgeBrief instance) =>
    <String, dynamic>{
      'headline': instance.headline,
      'tone': _$GoalNudgeToneEnumMap[instance.tone]!,
      'animation': _$GoalBannerAnimationEnumMap[instance.animation]!,
      'accent': _$GoalBannerAccentEnumMap[instance.accent]!,
      'tagline': instance.tagline,
      'cta': instance.cta,
    };

const _$GoalNudgeToneEnumMap = {
  GoalNudgeTone.encourage: 'encourage',
  GoalNudgeTone.nudge: 'nudge',
  GoalNudgeTone.celebrate: 'celebrate',
  GoalNudgeTone.roast: 'roast',
};

const _$GoalBannerAnimationEnumMap = {
  GoalBannerAnimation.steady: 'steady',
  GoalBannerAnimation.typewriter: 'typewriter',
  GoalBannerAnimation.pulse: 'pulse',
  GoalBannerAnimation.wave: 'wave',
  GoalBannerAnimation.marquee: 'marquee',
  GoalBannerAnimation.glitch: 'glitch',
};

const _$GoalBannerAccentEnumMap = {
  GoalBannerAccent.calm: 'calm',
  GoalBannerAccent.ember: 'ember',
  GoalBannerAccent.tide: 'tide',
  GoalBannerAccent.neon: 'neon',
  GoalBannerAccent.aurora: 'aurora',
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
