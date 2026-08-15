// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nudge_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NudgeBrief _$NudgeBriefFromJson(Map<String, dynamic> json) => _NudgeBrief(
  headline: json['headline'] as String,
  tone: $enumDecode(_$NudgeToneEnumMap, json['tone']),
  animation: $enumDecode(_$NudgeBannerAnimationEnumMap, json['animation']),
  accent:
      $enumDecodeNullable(_$NudgeBannerAccentEnumMap, json['accent']) ??
      NudgeBannerAccent.calm,
  tagline: json['tagline'] as String?,
  cta: json['cta'] as String?,
);

Map<String, dynamic> _$NudgeBriefToJson(_NudgeBrief instance) =>
    <String, dynamic>{
      'headline': instance.headline,
      'tone': _$NudgeToneEnumMap[instance.tone]!,
      'animation': _$NudgeBannerAnimationEnumMap[instance.animation]!,
      'accent': _$NudgeBannerAccentEnumMap[instance.accent]!,
      'tagline': instance.tagline,
      'cta': instance.cta,
    };

const _$NudgeToneEnumMap = {
  NudgeTone.encourage: 'encourage',
  NudgeTone.nudge: 'nudge',
  NudgeTone.celebrate: 'celebrate',
  NudgeTone.roast: 'roast',
};

const _$NudgeBannerAnimationEnumMap = {
  NudgeBannerAnimation.steady: 'steady',
  NudgeBannerAnimation.typewriter: 'typewriter',
  NudgeBannerAnimation.pulse: 'pulse',
  NudgeBannerAnimation.wave: 'wave',
  NudgeBannerAnimation.marquee: 'marquee',
  NudgeBannerAnimation.glitch: 'glitch',
};

const _$NudgeBannerAccentEnumMap = {
  NudgeBannerAccent.calm: 'calm',
  NudgeBannerAccent.ember: 'ember',
  NudgeBannerAccent.tide: 'tide',
  NudgeBannerAccent.neon: 'neon',
  NudgeBannerAccent.aurora: 'aurora',
};

_NudgeRating _$NudgeRatingFromJson(Map<String, dynamic> json) => _NudgeRating(
  activation: _decodeActivation(json['activation']),
  ratedAt: DateTime.parse(json['ratedAt'] as String),
  rating: _decodeRating(json['rating']),
  skipped: json['skipped'] as bool? ?? false,
);

Map<String, dynamic> _$NudgeRatingToJson(_NudgeRating instance) =>
    <String, dynamic>{
      'activation': instance.activation,
      'ratedAt': instance.ratedAt.toIso8601String(),
      'rating': instance.rating,
      'skipped': instance.skipped,
    };

_NudgeSnooze _$NudgeSnoozeFromJson(Map<String, dynamic> json) => _NudgeSnooze(
  id: json['id'] as String,
  activation: _decodeActivation(json['activation']),
  snoozedAt: DateTime.parse(json['snoozedAt'] as String),
  snoozedUntil: DateTime.parse(json['snoozedUntil'] as String),
  duration: $enumDecode(_$NudgeBannerSnoozeDurationEnumMap, json['duration']),
  durationMinutes: _decodePositiveMinutes(json['durationMinutes']),
  utcOffsetMinutes: _decodeUtcOffsetMinutes(json['utcOffsetMinutes']),
  returnUtcOffsetMinutes: _decodeOptionalUtcOffsetMinutes(
    json['returnUtcOffsetMinutes'],
  ),
);

Map<String, dynamic> _$NudgeSnoozeToJson(_NudgeSnooze instance) =>
    <String, dynamic>{
      'id': instance.id,
      'activation': instance.activation,
      'snoozedAt': instance.snoozedAt.toIso8601String(),
      'snoozedUntil': instance.snoozedUntil.toIso8601String(),
      'duration': _$NudgeBannerSnoozeDurationEnumMap[instance.duration]!,
      'durationMinutes': instance.durationMinutes,
      'utcOffsetMinutes': instance.utcOffsetMinutes,
      'returnUtcOffsetMinutes': instance.returnUtcOffsetMinutes,
    };

const _$NudgeBannerSnoozeDurationEnumMap = {
  NudgeBannerSnoozeDuration.oneHour: 'oneHour',
  NudgeBannerSnoozeDuration.threeHours: 'threeHours',
  NudgeBannerSnoozeDuration.sixHours: 'sixHours',
  NudgeBannerSnoozeDuration.eightHours: 'eightHours',
  NudgeBannerSnoozeDuration.custom: 'custom',
};

_NudgeDayDismissal _$NudgeDayDismissalFromJson(Map<String, dynamic> json) =>
    _NudgeDayDismissal(
      id: json['id'] as String,
      activation: _decodeActivation(json['activation']),
      dismissedAt: DateTime.parse(json['dismissedAt'] as String),
      dismissedUntil: DateTime.parse(json['dismissedUntil'] as String),
      utcOffsetMinutes: _decodeUtcOffsetMinutes(json['utcOffsetMinutes']),
    );

Map<String, dynamic> _$NudgeDayDismissalToJson(_NudgeDayDismissal instance) =>
    <String, dynamic>{
      'id': instance.id,
      'activation': instance.activation,
      'dismissedAt': instance.dismissedAt.toIso8601String(),
      'dismissedUntil': instance.dismissedUntil.toIso8601String(),
      'utcOffsetMinutes': instance.utcOffsetMinutes,
    };
