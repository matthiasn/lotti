// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'goal_nudge_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GoalNudgeBrief {

 String get headline; GoalNudgeTone get tone; GoalBannerAnimation get animation; GoalBannerAccent get accent; String? get tagline; String? get cta;
/// Create a copy of GoalNudgeBrief
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoalNudgeBriefCopyWith<GoalNudgeBrief> get copyWith => _$GoalNudgeBriefCopyWithImpl<GoalNudgeBrief>(this as GoalNudgeBrief, _$identity);

  /// Serializes this GoalNudgeBrief to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoalNudgeBrief&&(identical(other.headline, headline) || other.headline == headline)&&(identical(other.tone, tone) || other.tone == tone)&&(identical(other.animation, animation) || other.animation == animation)&&(identical(other.accent, accent) || other.accent == accent)&&(identical(other.tagline, tagline) || other.tagline == tagline)&&(identical(other.cta, cta) || other.cta == cta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,headline,tone,animation,accent,tagline,cta);

@override
String toString() {
  return 'GoalNudgeBrief(headline: $headline, tone: $tone, animation: $animation, accent: $accent, tagline: $tagline, cta: $cta)';
}


}

/// @nodoc
abstract mixin class $GoalNudgeBriefCopyWith<$Res>  {
  factory $GoalNudgeBriefCopyWith(GoalNudgeBrief value, $Res Function(GoalNudgeBrief) _then) = _$GoalNudgeBriefCopyWithImpl;
@useResult
$Res call({
 String headline, GoalNudgeTone tone, GoalBannerAnimation animation, GoalBannerAccent accent, String? tagline, String? cta
});




}
/// @nodoc
class _$GoalNudgeBriefCopyWithImpl<$Res>
    implements $GoalNudgeBriefCopyWith<$Res> {
  _$GoalNudgeBriefCopyWithImpl(this._self, this._then);

  final GoalNudgeBrief _self;
  final $Res Function(GoalNudgeBrief) _then;

/// Create a copy of GoalNudgeBrief
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? headline = null,Object? tone = null,Object? animation = null,Object? accent = null,Object? tagline = freezed,Object? cta = freezed,}) {
  return _then(_self.copyWith(
headline: null == headline ? _self.headline : headline // ignore: cast_nullable_to_non_nullable
as String,tone: null == tone ? _self.tone : tone // ignore: cast_nullable_to_non_nullable
as GoalNudgeTone,animation: null == animation ? _self.animation : animation // ignore: cast_nullable_to_non_nullable
as GoalBannerAnimation,accent: null == accent ? _self.accent : accent // ignore: cast_nullable_to_non_nullable
as GoalBannerAccent,tagline: freezed == tagline ? _self.tagline : tagline // ignore: cast_nullable_to_non_nullable
as String?,cta: freezed == cta ? _self.cta : cta // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [GoalNudgeBrief].
extension GoalNudgeBriefPatterns on GoalNudgeBrief {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GoalNudgeBrief value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GoalNudgeBrief() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GoalNudgeBrief value)  $default,){
final _that = this;
switch (_that) {
case _GoalNudgeBrief():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GoalNudgeBrief value)?  $default,){
final _that = this;
switch (_that) {
case _GoalNudgeBrief() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String headline,  GoalNudgeTone tone,  GoalBannerAnimation animation,  GoalBannerAccent accent,  String? tagline,  String? cta)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GoalNudgeBrief() when $default != null:
return $default(_that.headline,_that.tone,_that.animation,_that.accent,_that.tagline,_that.cta);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String headline,  GoalNudgeTone tone,  GoalBannerAnimation animation,  GoalBannerAccent accent,  String? tagline,  String? cta)  $default,) {final _that = this;
switch (_that) {
case _GoalNudgeBrief():
return $default(_that.headline,_that.tone,_that.animation,_that.accent,_that.tagline,_that.cta);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String headline,  GoalNudgeTone tone,  GoalBannerAnimation animation,  GoalBannerAccent accent,  String? tagline,  String? cta)?  $default,) {final _that = this;
switch (_that) {
case _GoalNudgeBrief() when $default != null:
return $default(_that.headline,_that.tone,_that.animation,_that.accent,_that.tagline,_that.cta);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GoalNudgeBrief implements GoalNudgeBrief {
  const _GoalNudgeBrief({required this.headline, required this.tone, required this.animation, this.accent = GoalBannerAccent.calm, this.tagline, this.cta});
  factory _GoalNudgeBrief.fromJson(Map<String, dynamic> json) => _$GoalNudgeBriefFromJson(json);

@override final  String headline;
@override final  GoalNudgeTone tone;
@override final  GoalBannerAnimation animation;
@override@JsonKey() final  GoalBannerAccent accent;
@override final  String? tagline;
@override final  String? cta;

/// Create a copy of GoalNudgeBrief
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GoalNudgeBriefCopyWith<_GoalNudgeBrief> get copyWith => __$GoalNudgeBriefCopyWithImpl<_GoalNudgeBrief>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoalNudgeBriefToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GoalNudgeBrief&&(identical(other.headline, headline) || other.headline == headline)&&(identical(other.tone, tone) || other.tone == tone)&&(identical(other.animation, animation) || other.animation == animation)&&(identical(other.accent, accent) || other.accent == accent)&&(identical(other.tagline, tagline) || other.tagline == tagline)&&(identical(other.cta, cta) || other.cta == cta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,headline,tone,animation,accent,tagline,cta);

@override
String toString() {
  return 'GoalNudgeBrief(headline: $headline, tone: $tone, animation: $animation, accent: $accent, tagline: $tagline, cta: $cta)';
}


}

/// @nodoc
abstract mixin class _$GoalNudgeBriefCopyWith<$Res> implements $GoalNudgeBriefCopyWith<$Res> {
  factory _$GoalNudgeBriefCopyWith(_GoalNudgeBrief value, $Res Function(_GoalNudgeBrief) _then) = __$GoalNudgeBriefCopyWithImpl;
@override @useResult
$Res call({
 String headline, GoalNudgeTone tone, GoalBannerAnimation animation, GoalBannerAccent accent, String? tagline, String? cta
});




}
/// @nodoc
class __$GoalNudgeBriefCopyWithImpl<$Res>
    implements _$GoalNudgeBriefCopyWith<$Res> {
  __$GoalNudgeBriefCopyWithImpl(this._self, this._then);

  final _GoalNudgeBrief _self;
  final $Res Function(_GoalNudgeBrief) _then;

/// Create a copy of GoalNudgeBrief
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? headline = null,Object? tone = null,Object? animation = null,Object? accent = null,Object? tagline = freezed,Object? cta = freezed,}) {
  return _then(_GoalNudgeBrief(
headline: null == headline ? _self.headline : headline // ignore: cast_nullable_to_non_nullable
as String,tone: null == tone ? _self.tone : tone // ignore: cast_nullable_to_non_nullable
as GoalNudgeTone,animation: null == animation ? _self.animation : animation // ignore: cast_nullable_to_non_nullable
as GoalBannerAnimation,accent: null == accent ? _self.accent : accent // ignore: cast_nullable_to_non_nullable
as GoalBannerAccent,tagline: freezed == tagline ? _self.tagline : tagline // ignore: cast_nullable_to_non_nullable
as String?,cta: freezed == cta ? _self.cta : cta // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$GoalNudgeRating {

/// Which run of this ad the outcome belongs to (1-based).
@JsonKey(fromJson: _decodeActivation) int get activation; DateTime get ratedAt;/// 1 (useless) .. 5 (loved it); null iff [skipped].
@JsonKey(fromJson: _decodeRating) int? get rating; bool get skipped;
/// Create a copy of GoalNudgeRating
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoalNudgeRatingCopyWith<GoalNudgeRating> get copyWith => _$GoalNudgeRatingCopyWithImpl<GoalNudgeRating>(this as GoalNudgeRating, _$identity);

  /// Serializes this GoalNudgeRating to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoalNudgeRating&&(identical(other.activation, activation) || other.activation == activation)&&(identical(other.ratedAt, ratedAt) || other.ratedAt == ratedAt)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.skipped, skipped) || other.skipped == skipped));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,activation,ratedAt,rating,skipped);

@override
String toString() {
  return 'GoalNudgeRating(activation: $activation, ratedAt: $ratedAt, rating: $rating, skipped: $skipped)';
}


}

/// @nodoc
abstract mixin class $GoalNudgeRatingCopyWith<$Res>  {
  factory $GoalNudgeRatingCopyWith(GoalNudgeRating value, $Res Function(GoalNudgeRating) _then) = _$GoalNudgeRatingCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _decodeActivation) int activation, DateTime ratedAt,@JsonKey(fromJson: _decodeRating) int? rating, bool skipped
});




}
/// @nodoc
class _$GoalNudgeRatingCopyWithImpl<$Res>
    implements $GoalNudgeRatingCopyWith<$Res> {
  _$GoalNudgeRatingCopyWithImpl(this._self, this._then);

  final GoalNudgeRating _self;
  final $Res Function(GoalNudgeRating) _then;

/// Create a copy of GoalNudgeRating
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? activation = null,Object? ratedAt = null,Object? rating = freezed,Object? skipped = null,}) {
  return _then(_self.copyWith(
activation: null == activation ? _self.activation : activation // ignore: cast_nullable_to_non_nullable
as int,ratedAt: null == ratedAt ? _self.ratedAt : ratedAt // ignore: cast_nullable_to_non_nullable
as DateTime,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as int?,skipped: null == skipped ? _self.skipped : skipped // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [GoalNudgeRating].
extension GoalNudgeRatingPatterns on GoalNudgeRating {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GoalNudgeRating value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GoalNudgeRating() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GoalNudgeRating value)  $default,){
final _that = this;
switch (_that) {
case _GoalNudgeRating():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GoalNudgeRating value)?  $default,){
final _that = this;
switch (_that) {
case _GoalNudgeRating() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _decodeActivation)  int activation,  DateTime ratedAt, @JsonKey(fromJson: _decodeRating)  int? rating,  bool skipped)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GoalNudgeRating() when $default != null:
return $default(_that.activation,_that.ratedAt,_that.rating,_that.skipped);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _decodeActivation)  int activation,  DateTime ratedAt, @JsonKey(fromJson: _decodeRating)  int? rating,  bool skipped)  $default,) {final _that = this;
switch (_that) {
case _GoalNudgeRating():
return $default(_that.activation,_that.ratedAt,_that.rating,_that.skipped);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _decodeActivation)  int activation,  DateTime ratedAt, @JsonKey(fromJson: _decodeRating)  int? rating,  bool skipped)?  $default,) {final _that = this;
switch (_that) {
case _GoalNudgeRating() when $default != null:
return $default(_that.activation,_that.ratedAt,_that.rating,_that.skipped);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GoalNudgeRating implements GoalNudgeRating {
  const _GoalNudgeRating({@JsonKey(fromJson: _decodeActivation) required this.activation, required this.ratedAt, @JsonKey(fromJson: _decodeRating) this.rating, this.skipped = false});
  factory _GoalNudgeRating.fromJson(Map<String, dynamic> json) => _$GoalNudgeRatingFromJson(json);

/// Which run of this ad the outcome belongs to (1-based).
@override@JsonKey(fromJson: _decodeActivation) final  int activation;
@override final  DateTime ratedAt;
/// 1 (useless) .. 5 (loved it); null iff [skipped].
@override@JsonKey(fromJson: _decodeRating) final  int? rating;
@override@JsonKey() final  bool skipped;

/// Create a copy of GoalNudgeRating
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GoalNudgeRatingCopyWith<_GoalNudgeRating> get copyWith => __$GoalNudgeRatingCopyWithImpl<_GoalNudgeRating>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoalNudgeRatingToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GoalNudgeRating&&(identical(other.activation, activation) || other.activation == activation)&&(identical(other.ratedAt, ratedAt) || other.ratedAt == ratedAt)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.skipped, skipped) || other.skipped == skipped));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,activation,ratedAt,rating,skipped);

@override
String toString() {
  return 'GoalNudgeRating(activation: $activation, ratedAt: $ratedAt, rating: $rating, skipped: $skipped)';
}


}

/// @nodoc
abstract mixin class _$GoalNudgeRatingCopyWith<$Res> implements $GoalNudgeRatingCopyWith<$Res> {
  factory _$GoalNudgeRatingCopyWith(_GoalNudgeRating value, $Res Function(_GoalNudgeRating) _then) = __$GoalNudgeRatingCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _decodeActivation) int activation, DateTime ratedAt,@JsonKey(fromJson: _decodeRating) int? rating, bool skipped
});




}
/// @nodoc
class __$GoalNudgeRatingCopyWithImpl<$Res>
    implements _$GoalNudgeRatingCopyWith<$Res> {
  __$GoalNudgeRatingCopyWithImpl(this._self, this._then);

  final _GoalNudgeRating _self;
  final $Res Function(_GoalNudgeRating) _then;

/// Create a copy of GoalNudgeRating
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? activation = null,Object? ratedAt = null,Object? rating = freezed,Object? skipped = null,}) {
  return _then(_GoalNudgeRating(
activation: null == activation ? _self.activation : activation // ignore: cast_nullable_to_non_nullable
as int,ratedAt: null == ratedAt ? _self.ratedAt : ratedAt // ignore: cast_nullable_to_non_nullable
as DateTime,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as int?,skipped: null == skipped ? _self.skipped : skipped // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$GoalNudgeSnooze {

 String get id;@JsonKey(fromJson: _decodeActivation) int get activation; DateTime get snoozedAt; DateTime get snoozedUntil; GoalBannerSnoozeDuration get duration;@JsonKey(fromJson: _decodePositiveMinutes) int get durationMinutes;@JsonKey(fromJson: _decodeUtcOffsetMinutes) int get utcOffsetMinutes;@JsonKey(fromJson: _decodeOptionalUtcOffsetMinutes) int? get returnUtcOffsetMinutes;
/// Create a copy of GoalNudgeSnooze
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoalNudgeSnoozeCopyWith<GoalNudgeSnooze> get copyWith => _$GoalNudgeSnoozeCopyWithImpl<GoalNudgeSnooze>(this as GoalNudgeSnooze, _$identity);

  /// Serializes this GoalNudgeSnooze to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoalNudgeSnooze&&(identical(other.id, id) || other.id == id)&&(identical(other.activation, activation) || other.activation == activation)&&(identical(other.snoozedAt, snoozedAt) || other.snoozedAt == snoozedAt)&&(identical(other.snoozedUntil, snoozedUntil) || other.snoozedUntil == snoozedUntil)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.durationMinutes, durationMinutes) || other.durationMinutes == durationMinutes)&&(identical(other.utcOffsetMinutes, utcOffsetMinutes) || other.utcOffsetMinutes == utcOffsetMinutes)&&(identical(other.returnUtcOffsetMinutes, returnUtcOffsetMinutes) || other.returnUtcOffsetMinutes == returnUtcOffsetMinutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,activation,snoozedAt,snoozedUntil,duration,durationMinutes,utcOffsetMinutes,returnUtcOffsetMinutes);

@override
String toString() {
  return 'GoalNudgeSnooze(id: $id, activation: $activation, snoozedAt: $snoozedAt, snoozedUntil: $snoozedUntil, duration: $duration, durationMinutes: $durationMinutes, utcOffsetMinutes: $utcOffsetMinutes, returnUtcOffsetMinutes: $returnUtcOffsetMinutes)';
}


}

/// @nodoc
abstract mixin class $GoalNudgeSnoozeCopyWith<$Res>  {
  factory $GoalNudgeSnoozeCopyWith(GoalNudgeSnooze value, $Res Function(GoalNudgeSnooze) _then) = _$GoalNudgeSnoozeCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(fromJson: _decodeActivation) int activation, DateTime snoozedAt, DateTime snoozedUntil, GoalBannerSnoozeDuration duration,@JsonKey(fromJson: _decodePositiveMinutes) int durationMinutes,@JsonKey(fromJson: _decodeUtcOffsetMinutes) int utcOffsetMinutes,@JsonKey(fromJson: _decodeOptionalUtcOffsetMinutes) int? returnUtcOffsetMinutes
});




}
/// @nodoc
class _$GoalNudgeSnoozeCopyWithImpl<$Res>
    implements $GoalNudgeSnoozeCopyWith<$Res> {
  _$GoalNudgeSnoozeCopyWithImpl(this._self, this._then);

  final GoalNudgeSnooze _self;
  final $Res Function(GoalNudgeSnooze) _then;

/// Create a copy of GoalNudgeSnooze
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? activation = null,Object? snoozedAt = null,Object? snoozedUntil = null,Object? duration = null,Object? durationMinutes = null,Object? utcOffsetMinutes = null,Object? returnUtcOffsetMinutes = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,activation: null == activation ? _self.activation : activation // ignore: cast_nullable_to_non_nullable
as int,snoozedAt: null == snoozedAt ? _self.snoozedAt : snoozedAt // ignore: cast_nullable_to_non_nullable
as DateTime,snoozedUntil: null == snoozedUntil ? _self.snoozedUntil : snoozedUntil // ignore: cast_nullable_to_non_nullable
as DateTime,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as GoalBannerSnoozeDuration,durationMinutes: null == durationMinutes ? _self.durationMinutes : durationMinutes // ignore: cast_nullable_to_non_nullable
as int,utcOffsetMinutes: null == utcOffsetMinutes ? _self.utcOffsetMinutes : utcOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int,returnUtcOffsetMinutes: freezed == returnUtcOffsetMinutes ? _self.returnUtcOffsetMinutes : returnUtcOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [GoalNudgeSnooze].
extension GoalNudgeSnoozePatterns on GoalNudgeSnooze {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GoalNudgeSnooze value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GoalNudgeSnooze() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GoalNudgeSnooze value)  $default,){
final _that = this;
switch (_that) {
case _GoalNudgeSnooze():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GoalNudgeSnooze value)?  $default,){
final _that = this;
switch (_that) {
case _GoalNudgeSnooze() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(fromJson: _decodeActivation)  int activation,  DateTime snoozedAt,  DateTime snoozedUntil,  GoalBannerSnoozeDuration duration, @JsonKey(fromJson: _decodePositiveMinutes)  int durationMinutes, @JsonKey(fromJson: _decodeUtcOffsetMinutes)  int utcOffsetMinutes, @JsonKey(fromJson: _decodeOptionalUtcOffsetMinutes)  int? returnUtcOffsetMinutes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GoalNudgeSnooze() when $default != null:
return $default(_that.id,_that.activation,_that.snoozedAt,_that.snoozedUntil,_that.duration,_that.durationMinutes,_that.utcOffsetMinutes,_that.returnUtcOffsetMinutes);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(fromJson: _decodeActivation)  int activation,  DateTime snoozedAt,  DateTime snoozedUntil,  GoalBannerSnoozeDuration duration, @JsonKey(fromJson: _decodePositiveMinutes)  int durationMinutes, @JsonKey(fromJson: _decodeUtcOffsetMinutes)  int utcOffsetMinutes, @JsonKey(fromJson: _decodeOptionalUtcOffsetMinutes)  int? returnUtcOffsetMinutes)  $default,) {final _that = this;
switch (_that) {
case _GoalNudgeSnooze():
return $default(_that.id,_that.activation,_that.snoozedAt,_that.snoozedUntil,_that.duration,_that.durationMinutes,_that.utcOffsetMinutes,_that.returnUtcOffsetMinutes);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(fromJson: _decodeActivation)  int activation,  DateTime snoozedAt,  DateTime snoozedUntil,  GoalBannerSnoozeDuration duration, @JsonKey(fromJson: _decodePositiveMinutes)  int durationMinutes, @JsonKey(fromJson: _decodeUtcOffsetMinutes)  int utcOffsetMinutes, @JsonKey(fromJson: _decodeOptionalUtcOffsetMinutes)  int? returnUtcOffsetMinutes)?  $default,) {final _that = this;
switch (_that) {
case _GoalNudgeSnooze() when $default != null:
return $default(_that.id,_that.activation,_that.snoozedAt,_that.snoozedUntil,_that.duration,_that.durationMinutes,_that.utcOffsetMinutes,_that.returnUtcOffsetMinutes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GoalNudgeSnooze extends GoalNudgeSnooze {
  const _GoalNudgeSnooze({required this.id, @JsonKey(fromJson: _decodeActivation) required this.activation, required this.snoozedAt, required this.snoozedUntil, required this.duration, @JsonKey(fromJson: _decodePositiveMinutes) required this.durationMinutes, @JsonKey(fromJson: _decodeUtcOffsetMinutes) required this.utcOffsetMinutes, @JsonKey(fromJson: _decodeOptionalUtcOffsetMinutes) this.returnUtcOffsetMinutes}): super._();
  factory _GoalNudgeSnooze.fromJson(Map<String, dynamic> json) => _$GoalNudgeSnoozeFromJson(json);

@override final  String id;
@override@JsonKey(fromJson: _decodeActivation) final  int activation;
@override final  DateTime snoozedAt;
@override final  DateTime snoozedUntil;
@override final  GoalBannerSnoozeDuration duration;
@override@JsonKey(fromJson: _decodePositiveMinutes) final  int durationMinutes;
@override@JsonKey(fromJson: _decodeUtcOffsetMinutes) final  int utcOffsetMinutes;
@override@JsonKey(fromJson: _decodeOptionalUtcOffsetMinutes) final  int? returnUtcOffsetMinutes;

/// Create a copy of GoalNudgeSnooze
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GoalNudgeSnoozeCopyWith<_GoalNudgeSnooze> get copyWith => __$GoalNudgeSnoozeCopyWithImpl<_GoalNudgeSnooze>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoalNudgeSnoozeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GoalNudgeSnooze&&(identical(other.id, id) || other.id == id)&&(identical(other.activation, activation) || other.activation == activation)&&(identical(other.snoozedAt, snoozedAt) || other.snoozedAt == snoozedAt)&&(identical(other.snoozedUntil, snoozedUntil) || other.snoozedUntil == snoozedUntil)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.durationMinutes, durationMinutes) || other.durationMinutes == durationMinutes)&&(identical(other.utcOffsetMinutes, utcOffsetMinutes) || other.utcOffsetMinutes == utcOffsetMinutes)&&(identical(other.returnUtcOffsetMinutes, returnUtcOffsetMinutes) || other.returnUtcOffsetMinutes == returnUtcOffsetMinutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,activation,snoozedAt,snoozedUntil,duration,durationMinutes,utcOffsetMinutes,returnUtcOffsetMinutes);

@override
String toString() {
  return 'GoalNudgeSnooze(id: $id, activation: $activation, snoozedAt: $snoozedAt, snoozedUntil: $snoozedUntil, duration: $duration, durationMinutes: $durationMinutes, utcOffsetMinutes: $utcOffsetMinutes, returnUtcOffsetMinutes: $returnUtcOffsetMinutes)';
}


}

/// @nodoc
abstract mixin class _$GoalNudgeSnoozeCopyWith<$Res> implements $GoalNudgeSnoozeCopyWith<$Res> {
  factory _$GoalNudgeSnoozeCopyWith(_GoalNudgeSnooze value, $Res Function(_GoalNudgeSnooze) _then) = __$GoalNudgeSnoozeCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(fromJson: _decodeActivation) int activation, DateTime snoozedAt, DateTime snoozedUntil, GoalBannerSnoozeDuration duration,@JsonKey(fromJson: _decodePositiveMinutes) int durationMinutes,@JsonKey(fromJson: _decodeUtcOffsetMinutes) int utcOffsetMinutes,@JsonKey(fromJson: _decodeOptionalUtcOffsetMinutes) int? returnUtcOffsetMinutes
});




}
/// @nodoc
class __$GoalNudgeSnoozeCopyWithImpl<$Res>
    implements _$GoalNudgeSnoozeCopyWith<$Res> {
  __$GoalNudgeSnoozeCopyWithImpl(this._self, this._then);

  final _GoalNudgeSnooze _self;
  final $Res Function(_GoalNudgeSnooze) _then;

/// Create a copy of GoalNudgeSnooze
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? activation = null,Object? snoozedAt = null,Object? snoozedUntil = null,Object? duration = null,Object? durationMinutes = null,Object? utcOffsetMinutes = null,Object? returnUtcOffsetMinutes = freezed,}) {
  return _then(_GoalNudgeSnooze(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,activation: null == activation ? _self.activation : activation // ignore: cast_nullable_to_non_nullable
as int,snoozedAt: null == snoozedAt ? _self.snoozedAt : snoozedAt // ignore: cast_nullable_to_non_nullable
as DateTime,snoozedUntil: null == snoozedUntil ? _self.snoozedUntil : snoozedUntil // ignore: cast_nullable_to_non_nullable
as DateTime,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as GoalBannerSnoozeDuration,durationMinutes: null == durationMinutes ? _self.durationMinutes : durationMinutes // ignore: cast_nullable_to_non_nullable
as int,utcOffsetMinutes: null == utcOffsetMinutes ? _self.utcOffsetMinutes : utcOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int,returnUtcOffsetMinutes: freezed == returnUtcOffsetMinutes ? _self.returnUtcOffsetMinutes : returnUtcOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$GoalNudgeDayDismissal {

 String get id;@JsonKey(fromJson: _decodeActivation) int get activation; DateTime get dismissedAt; DateTime get dismissedUntil;@JsonKey(fromJson: _decodeUtcOffsetMinutes) int get utcOffsetMinutes;
/// Create a copy of GoalNudgeDayDismissal
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoalNudgeDayDismissalCopyWith<GoalNudgeDayDismissal> get copyWith => _$GoalNudgeDayDismissalCopyWithImpl<GoalNudgeDayDismissal>(this as GoalNudgeDayDismissal, _$identity);

  /// Serializes this GoalNudgeDayDismissal to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoalNudgeDayDismissal&&(identical(other.id, id) || other.id == id)&&(identical(other.activation, activation) || other.activation == activation)&&(identical(other.dismissedAt, dismissedAt) || other.dismissedAt == dismissedAt)&&(identical(other.dismissedUntil, dismissedUntil) || other.dismissedUntil == dismissedUntil)&&(identical(other.utcOffsetMinutes, utcOffsetMinutes) || other.utcOffsetMinutes == utcOffsetMinutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,activation,dismissedAt,dismissedUntil,utcOffsetMinutes);

@override
String toString() {
  return 'GoalNudgeDayDismissal(id: $id, activation: $activation, dismissedAt: $dismissedAt, dismissedUntil: $dismissedUntil, utcOffsetMinutes: $utcOffsetMinutes)';
}


}

/// @nodoc
abstract mixin class $GoalNudgeDayDismissalCopyWith<$Res>  {
  factory $GoalNudgeDayDismissalCopyWith(GoalNudgeDayDismissal value, $Res Function(GoalNudgeDayDismissal) _then) = _$GoalNudgeDayDismissalCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(fromJson: _decodeActivation) int activation, DateTime dismissedAt, DateTime dismissedUntil,@JsonKey(fromJson: _decodeUtcOffsetMinutes) int utcOffsetMinutes
});




}
/// @nodoc
class _$GoalNudgeDayDismissalCopyWithImpl<$Res>
    implements $GoalNudgeDayDismissalCopyWith<$Res> {
  _$GoalNudgeDayDismissalCopyWithImpl(this._self, this._then);

  final GoalNudgeDayDismissal _self;
  final $Res Function(GoalNudgeDayDismissal) _then;

/// Create a copy of GoalNudgeDayDismissal
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? activation = null,Object? dismissedAt = null,Object? dismissedUntil = null,Object? utcOffsetMinutes = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,activation: null == activation ? _self.activation : activation // ignore: cast_nullable_to_non_nullable
as int,dismissedAt: null == dismissedAt ? _self.dismissedAt : dismissedAt // ignore: cast_nullable_to_non_nullable
as DateTime,dismissedUntil: null == dismissedUntil ? _self.dismissedUntil : dismissedUntil // ignore: cast_nullable_to_non_nullable
as DateTime,utcOffsetMinutes: null == utcOffsetMinutes ? _self.utcOffsetMinutes : utcOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [GoalNudgeDayDismissal].
extension GoalNudgeDayDismissalPatterns on GoalNudgeDayDismissal {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GoalNudgeDayDismissal value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GoalNudgeDayDismissal() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GoalNudgeDayDismissal value)  $default,){
final _that = this;
switch (_that) {
case _GoalNudgeDayDismissal():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GoalNudgeDayDismissal value)?  $default,){
final _that = this;
switch (_that) {
case _GoalNudgeDayDismissal() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(fromJson: _decodeActivation)  int activation,  DateTime dismissedAt,  DateTime dismissedUntil, @JsonKey(fromJson: _decodeUtcOffsetMinutes)  int utcOffsetMinutes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GoalNudgeDayDismissal() when $default != null:
return $default(_that.id,_that.activation,_that.dismissedAt,_that.dismissedUntil,_that.utcOffsetMinutes);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(fromJson: _decodeActivation)  int activation,  DateTime dismissedAt,  DateTime dismissedUntil, @JsonKey(fromJson: _decodeUtcOffsetMinutes)  int utcOffsetMinutes)  $default,) {final _that = this;
switch (_that) {
case _GoalNudgeDayDismissal():
return $default(_that.id,_that.activation,_that.dismissedAt,_that.dismissedUntil,_that.utcOffsetMinutes);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(fromJson: _decodeActivation)  int activation,  DateTime dismissedAt,  DateTime dismissedUntil, @JsonKey(fromJson: _decodeUtcOffsetMinutes)  int utcOffsetMinutes)?  $default,) {final _that = this;
switch (_that) {
case _GoalNudgeDayDismissal() when $default != null:
return $default(_that.id,_that.activation,_that.dismissedAt,_that.dismissedUntil,_that.utcOffsetMinutes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GoalNudgeDayDismissal extends GoalNudgeDayDismissal {
  const _GoalNudgeDayDismissal({required this.id, @JsonKey(fromJson: _decodeActivation) required this.activation, required this.dismissedAt, required this.dismissedUntil, @JsonKey(fromJson: _decodeUtcOffsetMinutes) required this.utcOffsetMinutes}): super._();
  factory _GoalNudgeDayDismissal.fromJson(Map<String, dynamic> json) => _$GoalNudgeDayDismissalFromJson(json);

@override final  String id;
@override@JsonKey(fromJson: _decodeActivation) final  int activation;
@override final  DateTime dismissedAt;
@override final  DateTime dismissedUntil;
@override@JsonKey(fromJson: _decodeUtcOffsetMinutes) final  int utcOffsetMinutes;

/// Create a copy of GoalNudgeDayDismissal
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GoalNudgeDayDismissalCopyWith<_GoalNudgeDayDismissal> get copyWith => __$GoalNudgeDayDismissalCopyWithImpl<_GoalNudgeDayDismissal>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoalNudgeDayDismissalToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GoalNudgeDayDismissal&&(identical(other.id, id) || other.id == id)&&(identical(other.activation, activation) || other.activation == activation)&&(identical(other.dismissedAt, dismissedAt) || other.dismissedAt == dismissedAt)&&(identical(other.dismissedUntil, dismissedUntil) || other.dismissedUntil == dismissedUntil)&&(identical(other.utcOffsetMinutes, utcOffsetMinutes) || other.utcOffsetMinutes == utcOffsetMinutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,activation,dismissedAt,dismissedUntil,utcOffsetMinutes);

@override
String toString() {
  return 'GoalNudgeDayDismissal(id: $id, activation: $activation, dismissedAt: $dismissedAt, dismissedUntil: $dismissedUntil, utcOffsetMinutes: $utcOffsetMinutes)';
}


}

/// @nodoc
abstract mixin class _$GoalNudgeDayDismissalCopyWith<$Res> implements $GoalNudgeDayDismissalCopyWith<$Res> {
  factory _$GoalNudgeDayDismissalCopyWith(_GoalNudgeDayDismissal value, $Res Function(_GoalNudgeDayDismissal) _then) = __$GoalNudgeDayDismissalCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(fromJson: _decodeActivation) int activation, DateTime dismissedAt, DateTime dismissedUntil,@JsonKey(fromJson: _decodeUtcOffsetMinutes) int utcOffsetMinutes
});




}
/// @nodoc
class __$GoalNudgeDayDismissalCopyWithImpl<$Res>
    implements _$GoalNudgeDayDismissalCopyWith<$Res> {
  __$GoalNudgeDayDismissalCopyWithImpl(this._self, this._then);

  final _GoalNudgeDayDismissal _self;
  final $Res Function(_GoalNudgeDayDismissal) _then;

/// Create a copy of GoalNudgeDayDismissal
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? activation = null,Object? dismissedAt = null,Object? dismissedUntil = null,Object? utcOffsetMinutes = null,}) {
  return _then(_GoalNudgeDayDismissal(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,activation: null == activation ? _self.activation : activation // ignore: cast_nullable_to_non_nullable
as int,dismissedAt: null == dismissedAt ? _self.dismissedAt : dismissedAt // ignore: cast_nullable_to_non_nullable
as DateTime,dismissedUntil: null == dismissedUntil ? _self.dismissedUntil : dismissedUntil // ignore: cast_nullable_to_non_nullable
as DateTime,utcOffsetMinutes: null == utcOffsetMinutes ? _self.utcOffsetMinutes : utcOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
